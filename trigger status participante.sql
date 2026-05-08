-- Trigger para novo participante
-- Necessária pois ao inserir um novo participante na tabela participante ele entra automaticamente com status ativo, não havendo necessidade de inserir um registro na tabela status_participante e linkar a chave primaria id_status com a inserção do novo participante
-- Trigger para novo participante (atualizado para usar situacao da tabela status_participante)
CREATE OR REPLACE FUNCTION definir_status_inicial()
RETURNS TRIGGER AS $$
DECLARE
    status_ativo_id INT;
BEGIN
    -- Buscar o id_status onde situacao = TRUE (Ativo)
    SELECT id_status INTO status_ativo_id
    FROM status_participante
    WHERE situacao = TRUE
    LIMIT 1;
    
    -- Atribuir o status encontrado ao novo participante
    NEW.status_id := status_ativo_id;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_novo_participante_ativo
BEFORE INSERT ON participante
FOR EACH ROW
EXECUTE FUNCTION definir_status_inicial();