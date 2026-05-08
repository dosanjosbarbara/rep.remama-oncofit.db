-- Trigger para novo participante
-- Necessária pois ao inserir um novo participante na tabela participante ele entra automaticamente com status ativo, não havendo necessidade de inserir um registro na tabela status_participante e linkar a chave primaria id_status com a inserção do novo participante
CREATE OR REPLACE FUNCTION definir_status_inicial()
RETURNS TRIGGER AS $$
BEGIN
    -- Novo participante sempre começa como ATIVO
    NEW.status_ativo := TRUE;
    -- ou se usar status_id: NEW.status_id := 1;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_novo_participante_ativo
BEFORE INSERT ON participante
FOR EACH ROW
EXECUTE FUNCTION definir_status_inicial();