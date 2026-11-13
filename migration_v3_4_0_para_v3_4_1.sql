-- =====================================================
-- MIGRAÇÃO v3.4.0 → v3.4.1  REMAMA / ONcoFITT
-- Executar com o banco v3.4.0 em produção / teste SEM derrubá-lo.
-- Requer: PostgreSQL 16, conexão como proprietário do schema.
-- Ordem: cada bloco é atômico; em caso de erro, o bloco inteiro é revertido.
-- =====================================================

BEGIN;

-- -----------------------------------------------------
-- 1. funcionarios: expandir para dados completos do coordenador
-- -----------------------------------------------------
ALTER TABLE funcionarios
    ADD COLUMN IF NOT EXISTS cpf           CHAR(11),
    ADD COLUMN IF NOT EXISTS data_nascimento DATE,
    ADD COLUMN IF NOT EXISTS telefone      VARCHAR(15),
    ADD COLUMN IF NOT EXISTS cep           CHAR(8),
    ADD COLUMN IF NOT EXISTS logradouro    VARCHAR(150),
    ADD COLUMN IF NOT EXISTS numero        VARCHAR(10),
    ADD COLUMN IF NOT EXISTS complemento   VARCHAR(100),
    ADD COLUMN IF NOT EXISTS bairro        VARCHAR(50),
    ADD COLUMN IF NOT EXISTS cidade        VARCHAR(50),
    ADD COLUMN IF NOT EXISTS uf            CHAR(2) CHECK (uf IN (
        'AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG',
        'PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO'
    ));

-- CPF único quando preenchido
CREATE UNIQUE INDEX IF NOT EXISTS uq_funcionario_cpf
    ON funcionarios (cpf) WHERE cpf IS NOT NULL;

COMMENT ON COLUMN funcionarios.cpf             IS 'CPF do funcionário (opcional para registros legados)';
COMMENT ON COLUMN funcionarios.data_nascimento IS 'Data de nascimento';
COMMENT ON COLUMN funcionarios.telefone        IS 'Telefone de contato';

-- -----------------------------------------------------
-- 2. ficha_medica: renomear tratamentos_realizados → obs_tratamentos
-- -----------------------------------------------------
-- Renomear preserva o dado existente; os campos realizou_* (v3.4.0) são os oficiais.
ALTER TABLE ficha_medica
    RENAME COLUMN tratamentos_realizados TO obs_tratamentos;

COMMENT ON COLUMN ficha_medica.obs_tratamentos IS
    'Observação livre sobre tratamentos (texto complementar). '
    'Dado oficial: realizou_cirurgia / realizou_quimioterapia / realizou_radioterapia.';

-- -----------------------------------------------------
-- 3. avaliacao: rastreabilidade — quem registrou a avaliação
-- -----------------------------------------------------
ALTER TABLE avaliacao
    ADD COLUMN IF NOT EXISTS id_usuario_avaliador INT
        REFERENCES usuario_acesso(id_usuario);

-- Preenchimento automático por trigger (igual a atestado_medico e justificativa_falta)
CREATE OR REPLACE FUNCTION fn_definir_avaliador() RETURNS TRIGGER AS $$
BEGIN
    IF app_usuario_id() IS NULL THEN
        RAISE EXCEPTION 'Usuário autenticado obrigatório para registrar avaliação';
    END IF;
    NEW.id_usuario_avaliador := app_usuario_id();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_avaliador_avaliacao ON avaliacao;
CREATE TRIGGER trg_avaliador_avaliacao
BEFORE INSERT ON avaliacao
FOR EACH ROW EXECUTE FUNCTION fn_definir_avaliador();

GRANT UPDATE (id_usuario_avaliador) ON avaliacao TO app_gestao_1, app_gestao_2;

-- -----------------------------------------------------
-- 4. Autenticação: Supabase Auth exclusivo
--    senha_hash removido; auth_user_id obrigatório
-- -----------------------------------------------------
-- 4a. Garantir que nenhuma linha existente ficará sem auth_user_id após NOT NULL
--     (em banco de teste, ajustar antes de executar se houver registros sem o campo)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM usuario_acesso
        WHERE auth_user_id IS NULL
        LIMIT 1
    ) THEN
        RAISE EXCEPTION
            'Existem registros em usuario_acesso com auth_user_id NULL. '
            'Preencha o campo antes de executar esta migração.';
    END IF;
END $$;

ALTER TABLE usuario_acesso
    ALTER COLUMN auth_user_id SET NOT NULL,
    DROP COLUMN IF EXISTS senha_hash;

-- Remover referência à senha_hash na fn_auditar_alteracao (já usa exclusão genérica)
-- A função já exclui 'senha_hash' do JSONB via (to_jsonb(NEW) - 'senha_hash');
-- como a coluna não existe mais, a expressão retorna o registro completo sem efeito
-- colateral — nenhuma alteração necessária na função de auditoria.

COMMENT ON COLUMN usuario_acesso.auth_user_id IS
    'ID do usuário no Supabase Auth. Único caminho de autenticação (v3.4.1).';

-- -----------------------------------------------------
-- 5. turma: nova tabela de cadastro
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS turma (
    id_turma      INT  GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_programa   INT  NOT NULL REFERENCES programa(id_programa),
    -- Barco fixo na turma; exclusivo do REMAMA (id_programa = 1).
    id_barco      INT  REFERENCES barco(id_barco),
    nome          VARCHAR(100) NOT NULL CHECK (btrim(nome) <> ''),
    horario_inicio TIME NOT NULL,
    horario_fim    TIME NOT NULL,
    situacao       VARCHAR(10) NOT NULL DEFAULT 'ativa'
        CHECK (situacao IN ('ativa', 'inativa')),
    data_inicio    DATE NOT NULL,
    CONSTRAINT ck_turma_horario  CHECK (horario_fim > horario_inicio),
    CONSTRAINT ck_turma_barco    CHECK (id_barco IS NULL OR id_programa = 1)
);
CREATE UNIQUE INDEX IF NOT EXISTS uq_turma_nome
    ON turma (id_programa, lower(btrim(nome)));

COMMENT ON TABLE  turma                IS 'Cadastro de turmas por programa. Barco fixo somente no REMAMA.';
COMMENT ON COLUMN turma.id_barco       IS 'Barco fixo da turma (NULL para ONcoFITT).';
COMMENT ON COLUMN turma.horario_inicio IS 'Horário de início da aula (referência); início/fim real fica em aula.';
COMMENT ON COLUMN turma.horario_fim    IS 'Horário de fim da aula (referência).';

-- RLS para turma
ALTER TABLE turma ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS turma_leitura      ON turma;
DROP POLICY IF EXISTS turma_gestao_gravar ON turma;

CREATE POLICY turma_leitura ON turma
FOR SELECT TO app_participante, app_gestao_1, app_gestao_2
USING (true);

CREATE POLICY turma_gestao_gravar ON turma
FOR ALL TO app_gestao_1, app_gestao_2
USING (
    (current_user = 'app_gestao_1' AND app_nivel_usuario() = 'gestao_1')
    OR (current_user = 'app_gestao_2' AND app_nivel_usuario() = 'gestao_2')
)
WITH CHECK (
    (current_user = 'app_gestao_1' AND app_nivel_usuario() = 'gestao_1')
    OR (current_user = 'app_gestao_2' AND app_nivel_usuario() = 'gestao_2')
);

GRANT SELECT ON turma TO app_participante, app_gestao_1, app_gestao_2;
GRANT INSERT, UPDATE, DELETE ON turma TO app_gestao_1, app_gestao_2;

-- -----------------------------------------------------
-- 6. aula: responsável por aula + vínculo com turma
-- -----------------------------------------------------
-- Responsável da aula: funcionário que conduz aquela sessão específica.
-- Flexível: pode ser diferente a cada aula, sem coordenadora fixa na turma.
ALTER TABLE aula
    ADD COLUMN IF NOT EXISTS id_turma              INT REFERENCES turma(id_turma),
    ADD COLUMN IF NOT EXISTS id_funcionario_resp   INT REFERENCES funcionarios(id_funcionario),
    -- id_barco na aula: redundante com turma.id_barco para facilitar consultas
    -- sem JOIN extra (somente REMAMA; derivado de turma).
    ADD COLUMN IF NOT EXISTS id_barco              INT REFERENCES barco(id_barco);

-- Consistência: barco da aula deve ser o barco da turma quando ambos preenchidos
ALTER TABLE aula
    ADD CONSTRAINT ck_aula_barco_programa
        CHECK (id_barco IS NULL OR id_programa = 1),
    ADD CONSTRAINT ck_aula_turma_programa
        CHECK (id_turma IS NULL OR TRUE); -- validação via trigger abaixo

CREATE OR REPLACE FUNCTION fn_validar_aula_turma() RETURNS TRIGGER AS $$
DECLARE
    v_turma turma%ROWTYPE;
BEGIN
    IF NEW.id_turma IS NULL THEN RETURN NEW; END IF;
    SELECT * INTO v_turma FROM turma WHERE id_turma = NEW.id_turma;
    -- Programa da aula deve bater com o programa da turma
    IF v_turma.id_programa <> NEW.id_programa THEN
        RAISE EXCEPTION 'A turma pertence a um programa diferente da aula';
    END IF;
    -- Barco da aula deve ser o barco da turma (quando turma tem barco)
    IF v_turma.id_barco IS NOT NULL AND
       NEW.id_barco IS DISTINCT FROM v_turma.id_barco THEN
        RAISE EXCEPTION 'O barco da aula deve ser o mesmo barco da turma';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_validar_aula_turma ON aula;
CREATE TRIGGER trg_validar_aula_turma
BEFORE INSERT OR UPDATE OF id_turma, id_barco, id_programa
ON aula FOR EACH ROW
EXECUTE FUNCTION fn_validar_aula_turma();

-- -----------------------------------------------------
-- 7. inscricao_programa: substituir texto turma por id_turma
-- -----------------------------------------------------
ALTER TABLE inscricao_programa
    ADD COLUMN IF NOT EXISTS id_turma INT REFERENCES turma(id_turma);

-- Manter coluna turma VARCHAR por ora para não perder dados legados;
-- o Grupo 3 migra os valores para id_turma e então a coluna é removida.
COMMENT ON COLUMN inscricao_programa.turma    IS
    'LEGADO (v3.4.0): turma como texto. Substituído por id_turma (v3.4.1). '
    'Remover após migração de dados pelo Grupo 3.';
COMMENT ON COLUMN inscricao_programa.id_turma IS
    'Turma da inscrição (substitui coluna turma VARCHAR).';

-- -----------------------------------------------------
-- 8. guarnicao_aula: função de cada aluna por aula
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS guarnicao_aula (
    id_guarnicao    INT  GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_aula         INT  NOT NULL REFERENCES aula(id_aula),
    id_participante INT  NOT NULL REFERENCES participante(id_participante),
    id_cargo        INT  NOT NULL REFERENCES cargo_participante(id_cargo),
    -- Especializações opcionais: só atribuídas se a aluna tiver na inscrição
    id_especializacao_leme   BOOLEAN NOT NULL DEFAULT FALSE,
    id_especializacao_tambor BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT uq_guarnicao_aula_participante
        UNIQUE (id_aula, id_participante)
);

-- 1 Capitã (id_cargo = 3) por aula — equivalente ao uq_capita_por_barco na inscrição
CREATE UNIQUE INDEX IF NOT EXISTS uq_capita_por_aula
    ON guarnicao_aula (id_aula)
    WHERE id_cargo = 3;

-- Validação: leme/tambor só se a aluna tiver a especialização na inscrição
CREATE OR REPLACE FUNCTION fn_validar_guarnicao() RETURNS TRIGGER AS $$
DECLARE
    v_programa       INT;
    v_leme_inscricao BOOLEAN;
    v_tambor_inscricao BOOLEAN;
    v_cargo_inscricao  INT;
BEGIN
    -- Guardar o programa da aula
    SELECT id_programa INTO v_programa FROM aula WHERE id_aula = NEW.id_aula;
    -- Guarnição é exclusiva do REMAMA (programa 1)
    IF v_programa <> 1 THEN
        RAISE EXCEPTION 'Guarnição de aula é exclusiva do REMAMA';
    END IF;

    -- Buscar especialização e cargo da inscrição ativa da aluna no REMAMA
    SELECT especializacao_leme, especializacao_tambor, id_cargo
    INTO v_leme_inscricao, v_tambor_inscricao, v_cargo_inscricao
    FROM inscricao_programa
    WHERE id_participante = NEW.id_participante
      AND id_programa = 1
      AND data_desligamento IS NULL;

    -- Leme só se tiver especialização
    IF NEW.id_especializacao_leme AND NOT COALESCE(v_leme_inscricao, FALSE) THEN
        RAISE EXCEPTION 'Aluna não tem especialização de Leme na inscrição';
    END IF;
    -- Tambor só se tiver especialização
    IF NEW.id_especializacao_tambor AND NOT COALESCE(v_tambor_inscricao, FALSE) THEN
        RAISE EXCEPTION 'Aluna não tem especialização de Tambor na inscrição';
    END IF;

    -- Capitã na guarnição: aluna deve ter cargo Capitã (id=3) na inscrição OU
    -- estar sendo designada pela gestão para aquela aula
    -- (a gestão pode designar qualquer aluna com cargo Capitã como capitã da aula;
    -- uma aluna Capitã pode participar como Remadora — a guarnição é o dado oficial)
    IF NEW.id_cargo = 3 AND COALESCE(v_cargo_inscricao, 0) <> 3 THEN
        RAISE EXCEPTION 'Somente aluna com cargo Capitã na inscrição pode ser Capitã na guarnição';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_validar_guarnicao ON guarnicao_aula;
CREATE TRIGGER trg_validar_guarnicao
BEFORE INSERT OR UPDATE ON guarnicao_aula
FOR EACH ROW EXECUTE FUNCTION fn_validar_guarnicao();

-- RLS: gestão grava/lê; aluna lê própria guarnição
ALTER TABLE guarnicao_aula ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS guarnicao_gestao  ON guarnicao_aula;
DROP POLICY IF EXISTS guarnicao_aluna   ON guarnicao_aula;

CREATE POLICY guarnicao_gestao ON guarnicao_aula
FOR ALL TO app_gestao_1, app_gestao_2
USING (
    (current_user = 'app_gestao_1' AND app_nivel_usuario() = 'gestao_1')
    OR (current_user = 'app_gestao_2' AND app_nivel_usuario() = 'gestao_2')
)
WITH CHECK (
    (current_user = 'app_gestao_1' AND app_nivel_usuario() = 'gestao_1')
    OR (current_user = 'app_gestao_2' AND app_nivel_usuario() = 'gestao_2')
);

CREATE POLICY guarnicao_aluna ON guarnicao_aula
FOR SELECT TO app_participante
USING (id_participante = app_participante_id());

GRANT SELECT ON guarnicao_aula TO app_participante, app_gestao_1, app_gestao_2;
GRANT INSERT, UPDATE, DELETE ON guarnicao_aula TO app_gestao_1, app_gestao_2;

-- -----------------------------------------------------
-- 9. registro_frequencia: liberar correção em 72h pelo professor
-- -----------------------------------------------------
-- Remove o bloqueio absoluto após PSE; substitui por janela de 72h para gestao_2
-- corrigir status de presença E PSE. A auditoria já registra automaticamente.
CREATE OR REPLACE FUNCTION fn_validar_frequencia_pse() RETURNS TRIGGER AS $$
DECLARE
    v_nivel       TEXT;
    v_id_programa INT;
    v_fim         TIMESTAMPTZ;
    v_sigla       VARCHAR(5);
    v_prazo       TIMESTAMPTZ;
BEGIN
    v_nivel := app_nivel_usuario();

    -- Correção pós-PSE pelo professor: janela de 72h após aula.fim
    IF TG_OP = 'UPDATE' AND OLD.pse IS NOT NULL THEN
        IF NEW.pse IS DISTINCT FROM OLD.pse
           OR NEW.id_status_presenca IS DISTINCT FROM OLD.id_status_presenca THEN

            -- Somente gestao_2 pode corrigir
            IF current_user <> 'app_gestao_2' OR v_nivel <> 'gestao_2' THEN
                RAISE EXCEPTION
                    'Presença e PSE só podem ser corrigidos pelo professor (gestao_2)';
            END IF;

            -- Verificar prazo de 72h
            SELECT fim INTO v_fim FROM aula WHERE id_aula = NEW.id_aula;
            IF v_fim IS NULL THEN
                RAISE EXCEPTION 'Registro sem aula vinculada não pode ter PSE corrigido';
            END IF;
            v_prazo := v_fim + INTERVAL '72 hours';
            IF CURRENT_TIMESTAMP > v_prazo THEN
                RAISE EXCEPTION
                    'Prazo de 72 horas para correção da chamada encerrado (fim da aula: %)',
                    v_fim;
            END IF;
        END IF;
    END IF;

    -- Regras de registro inicial do PSE (inalteradas)
    IF NEW.pse IS NOT NULL AND (TG_OP = 'INSERT' OR OLD.pse IS NULL) THEN
        IF NEW.id_aula IS NULL THEN
            RAISE EXCEPTION 'PSE só pode ser registrado para frequência vinculada a aula';
        END IF;
        SELECT sigla INTO v_sigla FROM status_presenca
        WHERE id_status_presenca = NEW.id_status_presenca;
        IF v_sigla <> 'P' THEN
            RAISE EXCEPTION 'PSE só pode ser registrado para presença confirmada';
        END IF;
        SELECT id_programa, fim INTO v_id_programa, v_fim
        FROM aula WHERE id_aula = NEW.id_aula;
        IF v_id_programa = 1 THEN
            IF current_user <> 'app_gestao_2' OR v_nivel <> 'gestao_2' THEN
                RAISE EXCEPTION 'No REMAMA, somente o professor (gestao_2) registra o PSE';
            END IF;
        ELSIF v_id_programa = 2 THEN
            IF current_user = 'app_gestao_2' AND v_nivel = 'gestao_2' THEN
                NULL;
            ELSIF current_user = 'app_participante' AND v_nivel = 'participante'
                  AND app_participante_id() IS NOT DISTINCT FROM NEW.id_participante THEN
                IF CURRENT_TIMESTAMP > v_fim + INTERVAL '24 hours' THEN
                    RAISE EXCEPTION 'Prazo de 24 horas para responder ao PSE encerrado';
                END IF;
            ELSE
                RAISE EXCEPTION
                    'No ONcoFITT, o PSE é registrado pelo professor (gestao_2) '
                    'ou pela própria participante';
            END IF;
        ELSE
            RAISE EXCEPTION 'Programa da aula inválido para registro de PSE';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- O trigger já existe; a função foi substituída acima via CREATE OR REPLACE.
-- Nenhum DROP/CREATE de trigger necessário.

-- -----------------------------------------------------
-- 10. nome_completo: bloquear nomes com apenas espaços
-- -----------------------------------------------------
ALTER TABLE participante
    ADD CONSTRAINT ck_nome_completo_nao_vazio
        CHECK (btrim(nome_completo) <> '');

-- -----------------------------------------------------
-- 11. policy_RLS.txt incorporado ao DDL (ponto de atenção 2.1 nº 4)
--     Adicionar RLS nas 12 tabelas que ficavam sem política se só o DDL fosse executado
-- -----------------------------------------------------
ALTER TABLE programa            ENABLE ROW LEVEL SECURITY;
ALTER TABLE nivel_acesso        ENABLE ROW LEVEL SECURITY;
ALTER TABLE tipo_cancer         ENABLE ROW LEVEL SECURITY;
ALTER TABLE estado_civil        ENABLE ROW LEVEL SECURITY;
ALTER TABLE cargo_participante  ENABLE ROW LEVEL SECURITY;
ALTER TABLE status_participante ENABLE ROW LEVEL SECURITY;
ALTER TABLE status_presenca     ENABLE ROW LEVEL SECURITY;
ALTER TABLE tipo_comorbidade    ENABLE ROW LEVEL SECURITY;
ALTER TABLE variacao_comorbidade ENABLE ROW LEVEL SECURITY;
ALTER TABLE tipo_treinamento    ENABLE ROW LEVEL SECURITY;
ALTER TABLE barco               ENABLE ROW LEVEL SECURITY;
ALTER TABLE auditoria_sistema   ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS programa_leitura             ON programa;
DROP POLICY IF EXISTS nivel_acesso_leitura         ON nivel_acesso;
DROP POLICY IF EXISTS tipo_cancer_leitura          ON tipo_cancer;
DROP POLICY IF EXISTS estado_civil_leitura         ON estado_civil;
DROP POLICY IF EXISTS cargo_participante_leitura   ON cargo_participante;
DROP POLICY IF EXISTS status_participante_leitura  ON status_participante;
DROP POLICY IF EXISTS status_presenca_leitura      ON status_presenca;
DROP POLICY IF EXISTS tipo_comorbidade_leitura     ON tipo_comorbidade;
DROP POLICY IF EXISTS variacao_comorbidade_leitura ON variacao_comorbidade;
DROP POLICY IF EXISTS tipo_treinamento_leitura     ON tipo_treinamento;
DROP POLICY IF EXISTS barco_leitura                ON barco;
DROP POLICY IF EXISTS barco_inserir_gestao         ON barco;
DROP POLICY IF EXISTS barco_atualizar_gestao       ON barco;
DROP POLICY IF EXISTS auditoria_leitura_gestao     ON auditoria_sistema;

CREATE POLICY programa_leitura ON programa
FOR SELECT TO app_participante, app_gestao_1, app_gestao_2 USING (true);
CREATE POLICY nivel_acesso_leitura ON nivel_acesso
FOR SELECT TO app_participante, app_gestao_1, app_gestao_2 USING (true);
CREATE POLICY tipo_cancer_leitura ON tipo_cancer
FOR SELECT TO app_participante, app_gestao_1, app_gestao_2 USING (true);
CREATE POLICY estado_civil_leitura ON estado_civil
FOR SELECT TO app_participante, app_gestao_1, app_gestao_2 USING (true);
CREATE POLICY cargo_participante_leitura ON cargo_participante
FOR SELECT TO app_participante, app_gestao_1, app_gestao_2 USING (true);
CREATE POLICY status_participante_leitura ON status_participante
FOR SELECT TO app_participante, app_gestao_1, app_gestao_2 USING (true);
CREATE POLICY status_presenca_leitura ON status_presenca
FOR SELECT TO app_participante, app_gestao_1, app_gestao_2 USING (true);
CREATE POLICY tipo_comorbidade_leitura ON tipo_comorbidade
FOR SELECT TO app_participante, app_gestao_1, app_gestao_2 USING (true);
CREATE POLICY variacao_comorbidade_leitura ON variacao_comorbidade
FOR SELECT TO app_participante, app_gestao_1, app_gestao_2 USING (true);
CREATE POLICY tipo_treinamento_leitura ON tipo_treinamento
FOR SELECT TO app_participante, app_gestao_1, app_gestao_2 USING (true);
CREATE POLICY barco_leitura ON barco
FOR SELECT TO app_participante, app_gestao_1, app_gestao_2 USING (true);
CREATE POLICY barco_inserir_gestao ON barco
FOR INSERT TO app_gestao_1, app_gestao_2
WITH CHECK (
    (current_user = 'app_gestao_1' AND app_nivel_usuario() = 'gestao_1')
    OR (current_user = 'app_gestao_2' AND app_nivel_usuario() = 'gestao_2')
);
CREATE POLICY barco_atualizar_gestao ON barco
FOR UPDATE TO app_gestao_1, app_gestao_2
USING (
    (current_user = 'app_gestao_1' AND app_nivel_usuario() = 'gestao_1')
    OR (current_user = 'app_gestao_2' AND app_nivel_usuario() = 'gestao_2')
)
WITH CHECK (
    (current_user = 'app_gestao_1' AND app_nivel_usuario() = 'gestao_1')
    OR (current_user = 'app_gestao_2' AND app_nivel_usuario() = 'gestao_2')
);
CREATE POLICY auditoria_leitura_gestao ON auditoria_sistema
FOR SELECT TO app_gestao_1, app_gestao_2
USING (
    (current_user = 'app_gestao_1' AND app_nivel_usuario() = 'gestao_1')
    OR (current_user = 'app_gestao_2' AND app_nivel_usuario() = 'gestao_2')
);

COMMIT;

-- =====================================================
-- VERIFICAÇÕES PÓS-MIGRAÇÃO (executar separado, fora do BEGIN/COMMIT)
-- =====================================================
-- SELECT column_name FROM information_schema.columns
--   WHERE table_name = 'funcionarios' ORDER BY ordinal_position;
-- SELECT column_name FROM information_schema.columns
--   WHERE table_name = 'ficha_medica' AND column_name IN ('obs_tratamentos','tratamentos_realizados');
-- SELECT column_name FROM information_schema.columns
--   WHERE table_name = 'usuario_acesso';
-- SELECT table_name FROM information_schema.tables
--   WHERE table_name IN ('turma','guarnicao_aula') AND table_schema = 'public';
-- SELECT conname FROM pg_constraint WHERE conrelid = 'participante'::regclass;
-- =====================================================
