-- =====================================================
-- Fix final: observacao_aluna e observacao_analise
-- em atestado_medico. Aplica em v3.4.1 sem derrubada.
-- =====================================================

BEGIN;

-- 1. Renomeia observacao → observacao_aluna
ALTER TABLE atestado_medico
    RENAME COLUMN observacao TO observacao_aluna;

-- 2. Adiciona observacao_analise (unifica motivo_recusa)
ALTER TABLE atestado_medico
    ADD COLUMN IF NOT EXISTS observacao_analise TEXT;

-- 3. Migra dados existentes de motivo_recusa
UPDATE atestado_medico
SET observacao_analise = motivo_recusa
WHERE motivo_recusa IS NOT NULL;

-- 4. Remove motivo_recusa e sua constraint
ALTER TABLE atestado_medico
    DROP CONSTRAINT IF EXISTS ck_atestado_motivo_recusa,
    DROP COLUMN IF EXISTS motivo_recusa;

-- 5. Constraint: observacao_analise obrigatoria ao rejeitar
ALTER TABLE atestado_medico
    ADD CONSTRAINT ck_atestado_observacao_analise CHECK (
        status_validacao <> 'rejeitado'
        OR NULLIF(btrim(observacao_analise), '') IS NOT NULL
    );

COMMENT ON COLUMN atestado_medico.observacao_aluna   IS 'Observação enviada pela aluna junto ao atestado.';
COMMENT ON COLUMN atestado_medico.observacao_analise IS 'Observação da coordenação ao analisar o atestado. Obrigatória ao rejeitar; opcional ao aprovar.';

-- 6. GRANTs
GRANT UPDATE (observacao_analise)
    ON atestado_medico TO app_gestao_1, app_gestao_2;

COMMIT;
