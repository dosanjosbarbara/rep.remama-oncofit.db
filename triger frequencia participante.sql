-- Esta trigger atualiza o status para 'Inativa' se a participante faltar 5 vezes seguidas
-- (é um exemplo conceitual; a implementação real exige mais lógica)
CREATE OR REPLACE FUNCTION atualizar_status_por_frequencia()
RETURNS TRIGGER AS $$
BEGIN
    -- Lógica para contar faltas consecutivas e atualizar status
    IF (SELECT COUNT(*) FROM registro_frequencia 
        WHERE id_participante = NEW.id_participante 
        AND id_status_presenca = 2  -- código para 'Falta'
        AND data_registro > CURRENT_DATE - INTERVAL '30 days') >= 5 THEN
        
        UPDATE participante SET status_id = 2  -- 'Inativa'
        WHERE id_participante = NEW.id_participante;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_atualizar_status
AFTER INSERT ON registro_frequencia
FOR EACH ROW
EXECUTE FUNCTION atualizar_status_por_frequencia();