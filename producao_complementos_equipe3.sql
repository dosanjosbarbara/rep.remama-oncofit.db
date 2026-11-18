-- =====================================================
-- PRODUÇÃO — Complementos Equipe 3 para banco REMAMA/ONcoFITT
-- Consolida: 007_onboarding, 008_pse_campos_extras,
--            009_estado_civil_permissao_aluna, dores_e_limitacoes
-- Aplica sobre DDL v3.4.x no Supabase.
-- Idempotente — pode ser rodado mais de uma vez sem erro.
-- Ordem obrigatória: 1 → 2 → 3 → 4
-- Executar como superusuário (postgres) no SQL Editor do Supabase.
-- =====================================================

BEGIN;

-- =====================================================
-- 1. TABELA participante_onboarding + função de login
--    Complemento 007 — CRÍTICO
--    Sem isso o login sempre redireciona para /onboarding
--    mesmo depois do onboarding concluído.
-- =====================================================

CREATE TABLE IF NOT EXISTS participante_onboarding (
    id_participante      INT PRIMARY KEY
        REFERENCES participante(id_participante),
    consentimento_lgpd_em TIMESTAMPTZ NOT NULL,
    concluido_em         TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    linfedema            VARCHAR(50),
    neuropatia           TEXT[]      NOT NULL DEFAULT '{}',
    dores_recorrentes    TEXT[]      NOT NULL DEFAULT '{}'
);

COMMENT ON TABLE participante_onboarding IS
    'Registra a conclusão do onboarding e o consentimento LGPD da aluna. '
    'Uma linha por participante; PK = id_participante.';
COMMENT ON COLUMN participante_onboarding.consentimento_lgpd_em IS
    'Momento exato do aceite LGPD — base legal do tratamento de dados (art. 7 LGPD).';

-- RLS
ALTER TABLE participante_onboarding ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS aluna_ler_participante_onboarding  ON participante_onboarding;
DROP POLICY IF EXISTS equipe_participante_onboarding     ON participante_onboarding;

CREATE POLICY aluna_ler_participante_onboarding ON participante_onboarding
FOR SELECT TO app_participante
USING (id_participante = app_participante_id());

CREATE POLICY equipe_participante_onboarding ON participante_onboarding
FOR ALL TO app_gestao_1, app_gestao_2
USING (
    (current_user = 'app_gestao_1' AND app_nivel_usuario() = 'gestao_1')
    OR (current_user = 'app_gestao_2' AND app_nivel_usuario() = 'gestao_2')
)
WITH CHECK (
    (current_user = 'app_gestao_1' AND app_nivel_usuario() = 'gestao_1')
    OR (current_user = 'app_gestao_2' AND app_nivel_usuario() = 'gestao_2')
);

-- GRANTs
GRANT SELECT, INSERT, UPDATE ON participante_onboarding TO app_gestao_1, app_gestao_2;
GRANT SELECT, INSERT, UPDATE ON participante_onboarding TO app_participante;

-- Revoga acesso da Data API do Supabase
DO $$
DECLARE v_papel TEXT;
BEGIN
    FOREACH v_papel IN ARRAY ARRAY['anon', 'authenticated', 'service_role'] LOOP
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = v_papel) THEN
            EXECUTE format('REVOKE ALL ON TABLE participante_onboarding FROM %I', v_papel);
        END IF;
    END LOOP;
END $$;

-- Função de login atualizada com onboarding_concluido
CREATE OR REPLACE FUNCTION auth_usuario_por_auth_id(p_auth UUID)
RETURNS TABLE (
    id_usuario          INT,
    email               TEXT,
    nivel               TEXT,
    id_participante     INT,
    id_funcionario      INT,
    nome                TEXT,
    ativo               BOOLEAN,
    id_status           INT,
    onboarding_concluido BOOLEAN
)
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp AS $$
    SELECT
        u.id_usuario,
        u.email::TEXT,
        n.nome_nivel::TEXT,
        u.id_participante,
        u.id_funcionario,
        COALESCE(p.nome_social, p.nome_completo, f.nome_funcionario)::TEXT,
        u.ativo,
        p.id_status,
        (o.id_participante IS NOT NULL)
    FROM public.usuario_acesso u
    JOIN public.nivel_acesso n
        ON n.id_nivel_acesso = u.id_nivel_acesso
    LEFT JOIN public.participante p
        ON p.id_participante = u.id_participante
    LEFT JOIN public.funcionarios f
        ON f.id_funcionario = u.id_funcionario
    LEFT JOIN public.participante_onboarding o
        ON o.id_participante = u.id_participante
    WHERE u.auth_user_id = p_auth
$$;

REVOKE ALL ON FUNCTION auth_usuario_por_auth_id(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION auth_usuario_por_auth_id(UUID) TO app_autenticacao;

DO $$
DECLARE v_papel TEXT;
BEGIN
    FOREACH v_papel IN ARRAY ARRAY['anon', 'authenticated', 'service_role'] LOOP
        IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = v_papel) THEN
            EXECUTE format(
                'REVOKE ALL ON FUNCTION auth_usuario_por_auth_id(UUID) FROM %I',
                v_papel
            );
        END IF;
    END LOOP;
END $$;

-- =====================================================
-- 2. COLUNAS EXTRAS DE PSE em registro_frequencia
--    Complemento 008 — MÉDIO
--    Tela /aluna/pse coleta 4 campos além do PSE principal;
--    sem isso os dados eram descartados silenciosamente.
-- =====================================================

ALTER TABLE registro_frequencia
    ADD COLUMN IF NOT EXISTS pse_antes       INT  CHECK (pse_antes BETWEEN 0 AND 10),
    ADD COLUMN IF NOT EXISTS pse_dificuldade TEXT,
    ADD COLUMN IF NOT EXISTS pse_dor         TEXT,
    ADD COLUMN IF NOT EXISTS pse_comentarios TEXT;

COMMENT ON COLUMN registro_frequencia.pse_antes       IS 'PSE informado pela aluna antes da aula (escala 0–10).';
COMMENT ON COLUMN registro_frequencia.pse_dificuldade IS 'Descrição da dificuldade sentida na aula.';
COMMENT ON COLUMN registro_frequencia.pse_dor         IS 'Descrição de dor sentida na aula.';
COMMENT ON COLUMN registro_frequencia.pse_comentarios IS 'Comentários livres da aluna sobre a aula.';

-- app_participante já tem GRANT UPDATE (pse) no DDL v3.4.x;
-- estende para os 4 novos campos.
GRANT UPDATE (pse_antes, pse_dificuldade, pse_dor, pse_comentarios)
    ON registro_frequencia TO app_participante;

-- =====================================================
-- 3. PERMISSÕES DA ALUNA: estado civil + dados socioeconômicos
--    Complemento 009 — MÉDIO
--    Dropdown de estado civil aparecia vazio; aluna não
--    conseguia salvar estado civil, filhos e quantidade_filhos.
-- =====================================================

-- Policy de leitura do catálogo para app_participante
DROP POLICY IF EXISTS aluna_ler_estado_civil ON estado_civil;
CREATE POLICY aluna_ler_estado_civil ON estado_civil
FOR SELECT TO app_participante USING (true);

-- GRANT das colunas que faltavam
GRANT UPDATE (id_estado_civil, possui_filhos, quantidade_filhos)
    ON participante TO app_participante;

-- =====================================================
-- 4. TABELAS registro_dor e limitacao_fisica
--    Complemento dores_e_limitacoes — BAIXO
--    Backend já tem as rotas; sem as tabelas nenhum dado
--    de dores ou limitações era persistido no Supabase.
-- =====================================================

CREATE TABLE IF NOT EXISTS registro_dor (
    id_dor          BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_participante INT    NOT NULL REFERENCES participante(id_participante),
    local_dor       VARCHAR(100) NOT NULL CHECK (btrim(local_dor) <> ''),
    intensidade     SMALLINT NOT NULL CHECK (intensidade BETWEEN 0 AND 10),
    registrado_em   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    detalhes        TEXT
);

CREATE TABLE IF NOT EXISTS limitacao_fisica (
    id_limitacao    BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_participante INT    NOT NULL REFERENCES participante(id_participante),
    tipo            VARCHAR(100) NOT NULL CHECK (btrim(tipo) <> ''),
    carga_maxima_kg DECIMAL(5,1) CHECK (carga_maxima_kg IS NULL OR carga_maxima_kg >= 0),
    descricao       TEXT NOT NULL CHECK (btrim(descricao) <> ''),
    registrado_em   TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

COMMENT ON TABLE registro_dor     IS 'Dores recorrentes relatadas pela participante.';
COMMENT ON TABLE limitacao_fisica IS 'Limitações físicas da participante (carga máxima, tipo, descrição).';

-- RLS
ALTER TABLE registro_dor     ENABLE ROW LEVEL SECURITY;
ALTER TABLE limitacao_fisica ENABLE ROW LEVEL SECURITY;

-- Aluna lê só as próprias linhas
DROP POLICY IF EXISTS aluna_ler_registro_dor      ON registro_dor;
DROP POLICY IF EXISTS aluna_ler_limitacao_fisica   ON limitacao_fisica;

CREATE POLICY aluna_ler_registro_dor ON registro_dor
FOR SELECT TO app_participante
USING (id_participante = app_participante_id());

CREATE POLICY aluna_ler_limitacao_fisica ON limitacao_fisica
FOR SELECT TO app_participante
USING (id_participante = app_participante_id());

-- Gestão lê e escreve tudo
DROP POLICY IF EXISTS equipe_registro_dor     ON registro_dor;
DROP POLICY IF EXISTS equipe_limitacao_fisica ON limitacao_fisica;

CREATE POLICY equipe_registro_dor ON registro_dor
FOR ALL TO app_gestao_1, app_gestao_2
USING (
    (current_user = 'app_gestao_1' AND app_nivel_usuario() = 'gestao_1')
    OR (current_user = 'app_gestao_2' AND app_nivel_usuario() = 'gestao_2')
)
WITH CHECK (
    (current_user = 'app_gestao_1' AND app_nivel_usuario() = 'gestao_1')
    OR (current_user = 'app_gestao_2' AND app_nivel_usuario() = 'gestao_2')
);

CREATE POLICY equipe_limitacao_fisica ON limitacao_fisica
FOR ALL TO app_gestao_1, app_gestao_2
USING (
    (current_user = 'app_gestao_1' AND app_nivel_usuario() = 'gestao_1')
    OR (current_user = 'app_gestao_2' AND app_nivel_usuario() = 'gestao_2')
)
WITH CHECK (
    (current_user = 'app_gestao_1' AND app_nivel_usuario() = 'gestao_1')
    OR (current_user = 'app_gestao_2' AND app_nivel_usuario() = 'gestao_2')
);

-- Aluna insere e edita só as próprias linhas (sem DELETE)
DROP POLICY IF EXISTS aluna_inserir_registro_dor      ON registro_dor;
DROP POLICY IF EXISTS aluna_atualizar_registro_dor    ON registro_dor;
DROP POLICY IF EXISTS aluna_inserir_limitacao_fisica  ON limitacao_fisica;
DROP POLICY IF EXISTS aluna_atualizar_limitacao_fisica ON limitacao_fisica;

CREATE POLICY aluna_inserir_registro_dor ON registro_dor
FOR INSERT TO app_participante
WITH CHECK (id_participante = app_participante_id());

CREATE POLICY aluna_atualizar_registro_dor ON registro_dor
FOR UPDATE TO app_participante
USING  (id_participante = app_participante_id())
WITH CHECK (id_participante = app_participante_id());

CREATE POLICY aluna_inserir_limitacao_fisica ON limitacao_fisica
FOR INSERT TO app_participante
WITH CHECK (id_participante = app_participante_id());

CREATE POLICY aluna_atualizar_limitacao_fisica ON limitacao_fisica
FOR UPDATE TO app_participante
USING  (id_participante = app_participante_id())
WITH CHECK (id_participante = app_participante_id());

-- GRANTs
GRANT SELECT, INSERT, UPDATE ON registro_dor, limitacao_fisica
    TO app_gestao_1, app_gestao_2;
GRANT SELECT, INSERT, UPDATE ON registro_dor, limitacao_fisica
    TO app_participante;

COMMIT;

-- =====================================================
-- VERIFICAÇÃO PÓS-EXECUÇÃO (rodar separado, fora do BEGIN/COMMIT)
-- =====================================================
-- 1. Tabelas criadas
-- SELECT table_name FROM information_schema.tables
-- WHERE table_schema = 'public'
--   AND table_name IN (
--       'participante_onboarding', 'registro_dor', 'limitacao_fisica'
--   );
--
-- 2. RLS habilitado nas novas tabelas
-- SELECT relname, relrowsecurity FROM pg_class
-- WHERE relname IN (
--     'participante_onboarding', 'registro_dor', 'limitacao_fisica'
-- );
-- Esperado: relrowsecurity = t nas três linhas
--
-- 3. Colunas de PSE criadas
-- SELECT column_name FROM information_schema.columns
-- WHERE table_name = 'registro_frequencia'
--   AND column_name IN ('pse_antes','pse_dificuldade','pse_dor','pse_comentarios');
--
-- 4. Função retorna onboarding_concluido
-- SELECT column_name FROM information_schema.columns
-- WHERE table_name = 'auth_usuario_por_auth_id';
-- Deve incluir: onboarding_concluido
--
-- 5. Policies existem
-- SELECT tablename, policyname FROM pg_policies
-- WHERE tablename IN (
--     'participante_onboarding','registro_dor','limitacao_fisica','estado_civil'
-- );
-- =====================================================
