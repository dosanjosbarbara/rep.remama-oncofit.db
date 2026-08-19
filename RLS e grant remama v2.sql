-- =====================================================
-- 8. ATIVAÇÃO DO RLS NAS TABELAS SENSÍVEIS
-- =====================================================

ALTER TABLE participante ENABLE ROW LEVEL SECURITY;
ALTER TABLE endereco ENABLE ROW LEVEL SECURITY;
ALTER TABLE contato ENABLE ROW LEVEL SECURITY;
ALTER TABLE dados_antropometricos ENABLE ROW LEVEL SECURITY;
ALTER TABLE avaliacao ENABLE ROW LEVEL SECURITY;
ALTER TABLE ficha_medica ENABLE ROW LEVEL SECURITY;
ALTER TABLE comorbidade ENABLE ROW LEVEL SECURITY;
ALTER TABLE treinamento ENABLE ROW LEVEL SECURITY;
ALTER TABLE evento ENABLE ROW LEVEL SECURITY;
ALTER TABLE inscricao_programa ENABLE ROW LEVEL SECURITY;
ALTER TABLE registro_frequencia ENABLE ROW LEVEL SECURITY;
ALTER TABLE auditoria_sistema ENABLE ROW LEVEL SECURITY;


-- =====================================================
-- 9. POLÍTICAS DE RLS
-- =====================================================

-- PARTICIPANTE
CREATE POLICY admin_acesso_total_participante ON participante
    FOR ALL USING (app_nivel_acesso() = 'admin');

CREATE POLICY voluntaria_ve_proprio_participante ON participante
    FOR SELECT USING (
        app_nivel_acesso() = 'voluntario' AND id_participante = app_participante_id()
    );

-- pesquisador NÃO recebe policy aqui de propósito — acesso só via view anonimizada (seção 10)

-- ENDEREÇO
CREATE POLICY admin_acesso_total_endereco ON endereco
    FOR ALL USING (app_nivel_acesso() = 'admin');

CREATE POLICY voluntaria_ve_proprio_endereco ON endereco
    FOR SELECT USING (
        app_nivel_acesso() = 'voluntario' AND id_participante = app_participante_id()
    );

-- CONTATO
CREATE POLICY admin_acesso_total_contato ON contato
    FOR ALL USING (app_nivel_acesso() = 'admin');

CREATE POLICY voluntaria_ve_proprio_contato ON contato
    FOR SELECT USING (
        app_nivel_acesso() = 'voluntario' AND id_participante = app_participante_id()
    );

-- DADOS ANTROPOMÉTRICOS
CREATE POLICY admin_acesso_total_antropometricos ON dados_antropometricos
    FOR ALL USING (app_nivel_acesso() = 'admin');

CREATE POLICY voluntaria_ve_proprio_antropometrico ON dados_antropometricos
    FOR SELECT USING (
        app_nivel_acesso() = 'voluntario' AND id_participante = app_participante_id()
    );

CREATE POLICY pesquisador_le_antropometrico ON dados_antropometricos
    FOR SELECT USING (app_nivel_acesso() = 'pesquisador');

-- AVALIAÇÃO
CREATE POLICY admin_acesso_total_avaliacao ON avaliacao
    FOR ALL USING (app_nivel_acesso() = 'admin');

CREATE POLICY voluntaria_ve_propria_avaliacao ON avaliacao
    FOR SELECT USING (
        app_nivel_acesso() = 'voluntario' AND id_participante = app_participante_id()
    );

CREATE POLICY pesquisador_le_avaliacao ON avaliacao
    FOR SELECT USING (app_nivel_acesso() = 'pesquisador');

-- FICHA MÉDICA (mais sensível — só admin e a própria voluntária)
CREATE POLICY admin_acesso_total_ficha_medica ON ficha_medica
    FOR ALL USING (app_nivel_acesso() = 'admin');

CREATE POLICY voluntaria_ve_propria_ficha ON ficha_medica
    FOR SELECT USING (
        app_nivel_acesso() = 'voluntario' AND id_participante = app_participante_id()
    );

-- COMORBIDADE (mesma sensibilidade da ficha médica)
CREATE POLICY admin_acesso_total_comorbidade ON comorbidade
    FOR ALL USING (app_nivel_acesso() = 'admin');

CREATE POLICY voluntaria_ve_propria_comorbidade ON comorbidade
    FOR SELECT USING (
        app_nivel_acesso() = 'voluntario' AND id_participante = app_participante_id()
    );

-- TREINAMENTO
CREATE POLICY admin_acesso_total_treinamento ON treinamento
    FOR ALL USING (app_nivel_acesso() = 'admin');

CREATE POLICY voluntaria_ve_proprio_treinamento ON treinamento
    FOR SELECT USING (
        app_nivel_acesso() = 'voluntario' AND id_participante = app_participante_id()
    );

-- EVENTO
CREATE POLICY admin_acesso_total_evento ON evento
    FOR ALL USING (app_nivel_acesso() = 'admin');

CREATE POLICY voluntaria_ve_proprio_evento ON evento
    FOR SELECT USING (
        app_nivel_acesso() = 'voluntario' AND id_participante = app_participante_id()
    );

-- INSCRIÇÃO EM PROGRAMA
CREATE POLICY admin_acesso_total_inscricao ON inscricao_programa
    FOR ALL USING (app_nivel_acesso() = 'admin');

CREATE POLICY voluntaria_ve_propria_inscricao ON inscricao_programa
    FOR SELECT USING (
        app_nivel_acesso() = 'voluntario' AND id_participante = app_participante_id()
    );

-- REGISTRO DE FREQUÊNCIA
CREATE POLICY admin_acesso_total_frequencia ON registro_frequencia
    FOR ALL USING (app_nivel_acesso() = 'admin');

CREATE POLICY voluntaria_ve_propria_frequencia ON registro_frequencia
    FOR SELECT USING (
        app_nivel_acesso() = 'voluntario' AND id_participante = app_participante_id()
    );

CREATE POLICY pesquisador_le_frequencia ON registro_frequencia
    FOR SELECT USING (app_nivel_acesso() = 'pesquisador');

-- AUDITORIA (só admin, ninguém mais enxerga)
CREATE POLICY admin_acesso_total_auditoria ON auditoria_sistema
    FOR ALL USING (app_nivel_acesso() = 'admin');


-- =====================================================
-- 10. VIEW ANONIMIZADA PARA O PESQUISADOR (LGPD)
-- =====================================================

CREATE VIEW vw_pesquisa_participante AS
SELECT
    id_participante,
    EXTRACT(YEAR FROM AGE(data_nascimento))::INT AS idade,
    sexo,
    id_estado_civil,
    possui_filhos,
    renda_familiar_faixa
FROM participante;

GRANT SELECT ON vw_pesquisa_participante TO app_backend;


-- =====================================================
-- 11. ROLE DE APLICAÇÃO (usado pelo backend, nunca pelo admin do banco)
-- =====================================================

CREATE ROLE app_backend LOGIN PASSWORD 'defina_via_secret_manager';
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO app_backend;
-- IMPORTANTE: confirmar que app_backend NÃO tem BYPASSRLS nem é superuser