-- =====================================================
-- SCRIPT DE LIMPEZA E RECRIAÇÃO DOS DADOS
-- =====================================================

-- 1. DESATIVAR TRIGGERS TEMPORARIAMENTE
ALTER TABLE participante DISABLE TRIGGER trigger_novo_participante_ativo;

-- 2. LIMPAR TABELAS NA ORDEM CORRETA (respeitando FK)
TRUNCATE TABLE auditoria_sistema CASCADE;
TRUNCATE TABLE evento CASCADE;
TRUNCATE TABLE avaliacao CASCADE;
TRUNCATE TABLE treinamento CASCADE;
TRUNCATE TABLE comorbidade CASCADE;
TRUNCATE TABLE dados_antropometricos CASCADE;
TRUNCATE TABLE ficha_medica CASCADE;
TRUNCATE TABLE inscricao_programa CASCADE;
TRUNCATE TABLE contato CASCADE;
TRUNCATE TABLE endereco CASCADE;
TRUNCATE TABLE registro_frequencia CASCADE;
TRUNCATE TABLE participante CASCADE;

-- 3. REINICIAR SEQUÊNCIAS (se usar SERIAL/IDENTITY)
ALTER SEQUENCE IF EXISTS status_participante_id_status_seq RESTART WITH 1;
ALTER SEQUENCE IF EXISTS participante_id_participante_seq RESTART WITH 1;

-- 4. RECRIAR TABELAS DE DOMÍNIO COM A NOVA ESTRUTURA
DROP TABLE IF EXISTS status_participante CASCADE;
CREATE TABLE status_participante (
    id_status INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome_status VARCHAR(20) NOT NULL,
    situacao BOOLEAN NOT NULL DEFAULT TRUE  -- TRUE=Ativo, FALSE=Inativo
);

-- 5. INSERIR STATUS CORRETOS
INSERT INTO status_participante (nome_status, situacao) VALUES 
    ('Ativa', TRUE),      -- id_status = 1
    ('Inativa', FALSE),   -- id_status = 2
    ('Suspensa', FALSE),  -- id_status = 3
    ('Falecida', FALSE);  -- id_status = 4

-- 6. RECRIAR AS DEMAIS TABELAS DE DOMÍNIO
DROP TABLE IF EXISTS estado_civil CASCADE;
CREATE TABLE estado_civil (
    id_estado_civil INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    descricao VARCHAR(30) NOT NULL
);

INSERT INTO estado_civil (descricao) VALUES 
    ('Solteira'), ('Casada'), ('Divorciada'), ('Viúva'), ('União Estável');

DROP TABLE IF EXISTS programa CASCADE;
CREATE TABLE programa (
    id_programa INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome_programa VARCHAR(30) NOT NULL
);

INSERT INTO programa (nome_programa) VALUES 
    ('Remama'), ('Oncofit');

DROP TABLE IF EXISTS cargo_participante CASCADE;
CREATE TABLE cargo_participante (
    id_cargo INT PRIMARY KEY,
    nome_cargo VARCHAR(30) NOT NULL
);

INSERT INTO cargo_participante (id_cargo, nome_cargo) VALUES (1, 'Aluna'), (2, 'Gerente'), (3, 'Capitã'), (4, 'Dragonete');

DROP TABLE IF EXISTS status_presenca CASCADE;
CREATE TABLE status_presenca (
    id_status_presenca INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sigla CHAR(1) NOT NULL,
    descricao VARCHAR(20) NOT NULL
);

INSERT INTO status_presenca (sigla, descricao) VALUES 
    ('P', 'Presente'), ('F', 'Falta'), ('J', 'Justificada');

DROP TABLE IF EXISTS funcoes CASCADE;
CREATE TABLE funcoes (
    id_funcao INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome_funcao VARCHAR(30) NOT NULL
);

INSERT INTO funcoes (nome_funcao) VALUES 
    ('Coordenador'), ('Professor'), ('Voluntário'), ('Pesquisador');

DROP TABLE IF EXISTS tipo_comorbidade CASCADE;
CREATE TABLE tipo_comorbidade (
    id_tipo_comorbidade INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome_comorbidade VARCHAR(40) NOT NULL
);

INSERT INTO tipo_comorbidade (nome_comorbidade) VALUES 
    ('Hipertensão'), ('Diabetes tipo 2'), ('Asma'), ('Cardiopatia'), 
    ('Obesidade'), ('Ansiedade'), ('Depressão'), ('Hipotireoidismo');

DROP TABLE IF EXISTS tipo_treinamento CASCADE;
CREATE TABLE tipo_treinamento (
    id_tipo_treinamento INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome_treinamento VARCHAR(30) NOT NULL
);

INSERT INTO tipo_treinamento (nome_treinamento) VALUES 
    ('Acolhimento'), ('Natação'), ('Tambor'), ('Leme'), ('Primeiros Socorros');

-- 7. RECRIAR TABELA PARTICIPANTE COM STATUS CORRETO
DROP TABLE IF EXISTS participante CASCADE;
CREATE TABLE participante (
    id_participante INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cpf CHAR(11) UNIQUE NOT NULL,
    numero_carteirinha VARCHAR(20) UNIQUE,
    status_id INT REFERENCES status_participante(id_status) DEFAULT 1,
    nome_completo VARCHAR(100) NOT NULL,
    nome_social VARCHAR(100),
    data_nascimento DATE NOT NULL,
    sexo CHAR(1) CHECK (sexo IN ('F', 'M')),
    id_estado_civil INT REFERENCES estado_civil(id_estado_civil),
    possui_filhos BOOLEAN DEFAULT FALSE,
    quantidade_filhos INT DEFAULT 0,
    profissao VARCHAR(60),
    trabalha_atualmente BOOLEAN,
    renda_familiar_faixa VARCHAR(20),
    observacoes TEXT
);

-- 8. RECRIAR TRIGGER DE STATUS INICIAL
CREATE OR REPLACE FUNCTION definir_status_inicial()
RETURNS TRIGGER AS $$
BEGIN
    -- Define status como Ativo (situacao = TRUE)
    IF NEW.status_id IS NULL THEN
        SELECT id_status INTO NEW.status_id
        FROM status_participante
        WHERE situacao = TRUE
        LIMIT 1;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_novo_participante_ativo
BEFORE INSERT ON participante
FOR EACH ROW
EXECUTE FUNCTION definir_status_inicial();

-- 9. INSERIR PARTICIPANTES COM STATUS CORRETO
INSERT INTO participante (cpf, numero_carteirinha, status_id, nome_completo, nome_social, data_nascimento, sexo, id_estado_civil, possui_filhos, quantidade_filhos, profissao, trabalha_atualmente, renda_familiar_faixa, observacoes) VALUES
('11111111111', 'CART001', 1, 'Ana Paula Silva', NULL, '1985-03-15', 'F', 2, TRUE, 2, 'Professora', TRUE, '1-3 SM', 'Diagnosticada em 2022'),
('22222222222', 'CART002', 1, 'Maria Fernanda Santos', 'Mari', '1990-07-22', 'F', 1, FALSE, 0, 'Analista de RH', TRUE, 'Mais de 3 SM', NULL),
('33333333333', 'CART003', 1, 'Carla Beatriz Souza', NULL, '1978-11-10', 'F', 3, TRUE, 1, 'Do lar', FALSE, 'Até 1 SM', 'Em tratamento desde 2023'),
('44444444444', 'CART004', 2, 'Juliana Costa Lima', 'Ju', '1982-05-05', 'F', 2, TRUE, 3, 'Enfermeira', TRUE, '1-3 SM', 'Afastada por recidiva'),
('55555555555', 'CART005', 1, 'Patrícia Oliveira Rocha', NULL, '1995-09-18', 'F', 1, FALSE, 0, 'Estudante', FALSE, 'Até 1 SM', NULL),
('66666666666', 'CART006', 1, 'Fernanda Alves Mendes', 'Nanda', '1988-12-01', 'F', 4, TRUE, 2, 'Arquiteta', TRUE, 'Mais de 3 SM', NULL),
('77777777777', 'CART007', 3, 'Ricardo Jose Martins', NULL, '1970-04-25', 'M', 2, TRUE, 2, 'Aposentado', FALSE, 'Até 1 SM', 'Pouca adesão'),
('88888888888', 'CART008', 1, 'Tatiane Ferreira Gomes', 'Tati', '1992-08-30', 'F', 1, FALSE, 0, 'Vendedora', TRUE, '1-3 SM', NULL),
('99999999999', 'CART009', 1, 'Simone Aparecida Nunes', NULL, '1980-02-14', 'F', 3, TRUE, 1, 'Cabelereira', TRUE, '1-3 SM', NULL),
('10101010101', 'CART010', 4, 'Luciana Mara Dias', 'Lu', '1965-06-20', 'F', 4, TRUE, 2, 'Aposentada', FALSE, 'Até 1 SM', 'Falecida em 2025'),
('11111111112', 'CART011', 1, 'Camila Rodrigues Alves', NULL, '1998-10-05', 'F', 1, FALSE, 0, 'Estagiária', TRUE, 'Até 1 SM', NULL),
('11111111113', 'CART012', 1, 'Vanessa Cristina Lima', 'Vane', '1987-03-28', 'F', 2, TRUE, 2, 'Gerente de Vendas', TRUE, 'Mais de 3 SM', NULL),
('11111111114', 'CART013', 1, 'Roberta Almeida Santos', 'Berta', '1993-12-12', 'F', 1, FALSE, 0, 'Designer', TRUE, '1-3 SM', NULL),
('11111111115', 'CART014', 2, 'Andrea Pereira Gomes', NULL, '1975-09-09', 'F', 3, TRUE, 2, 'Advogada', TRUE, 'Mais de 3 SM', 'Licença médica'),
('11111111116', 'CART015', 1, 'Michele Souza Costa', 'Mimi', '2000-01-20', 'F', 1, FALSE, 0, 'Universitária', TRUE, 'Até 1 SM', NULL),
('11111111117', 'CART016', 1, 'Claudia Regina Martins', NULL, '1982-07-07', 'F', 2, TRUE, 1, 'Contadora', TRUE, '1-3 SM', NULL),
('11111111118', 'CART017', 1, 'Fabiana Lima Rocha', 'Fabbi', '1991-04-18', 'F', 1, TRUE, 1, 'Psicóloga', TRUE, 'Mais de 3 SM', NULL),
('11111111119', 'CART018', 3, 'Tatiane Oliveira Nunes', NULL, '1984-11-11', 'F', 2, TRUE, 3, 'Do lar', FALSE, 'Até 1 SM', 'Desistiu do programa'),
('11111111120', 'CART019', 1, 'Gisele Santos Almeida', NULL, '1997-06-25', 'F', 1, FALSE, 0, 'Farmacêutica', TRUE, '1-3 SM', NULL),
('11111111121', 'CART020', 1, 'Renata Pereira Lima', 'Renatinha', '1989-08-14', 'F', 2, TRUE, 2, 'Empresária', TRUE, 'Mais de 3 SM', NULL),
('11111111122', 'CART021', 1, 'Simone Costa Rocha', NULL, '1994-02-28', 'F', 1, FALSE, 0, 'Publicitária', TRUE, '1-3 SM', NULL),
('11111111123', 'CART022', 1, 'Luciana Alves Mendes', 'Lu', '1986-10-10', 'F', 3, TRUE, 1, 'Cozinheira', TRUE, 'Até 1 SM', NULL),
('11111111124', 'CART023', 1, 'Patrícia Souza Lima', NULL, '1999-05-05', 'F', 1, FALSE, 0, 'Bióloga', TRUE, '1-3 SM', NULL),
('11111111125', 'CART024', 2, 'Mariana Oliveira Santos', 'Mari', '1983-12-25', 'F', 2, TRUE, 2, 'Professora', TRUE, '1-3 SM', 'Afastada por cirurgia'),
('11111111126', 'CART025', 1, 'Aline Cristina Pereira', NULL, '1996-03-03', 'F', 1, FALSE, 0, 'Analista de TI', TRUE, 'Mais de 3 SM', NULL),
('11111111127', 'CART026', 1, 'Carla Regina Alves', 'Cah', '1981-09-09', 'F', 2, TRUE, 1, 'Enfermeira', TRUE, '1-3 SM', NULL),
('11111111128', 'CART027', 1, 'Fernanda Lima Souza', 'Fê', '1990-11-15', 'F', 1, FALSE, 0, 'Jornalista', TRUE, '1-3 SM', NULL),
('11111111129', 'CART028', 1, 'Vivian Rocha Almeida', NULL, '1987-04-22', 'F', 2, TRUE, 3, 'Do lar', FALSE, 'Até 1 SM', NULL),
('11111111130', 'CART029', 1, 'Tatiane Cristina Santos', 'Tata', '1995-08-08', 'F', 1, FALSE, 0, 'Esteticista', TRUE, '1-3 SM', NULL),
('11111111131', 'CART030', 1, 'Juliana Alves Pereira', NULL, '1984-01-01', 'F', 3, TRUE, 2, 'Gerente', TRUE, 'Mais de 3 SM', NULL),
('11111111132', 'CART031', 1, 'Ana Lucia Costa', NULL, '1992-07-17', 'F', 2, TRUE, 1, 'Vendedora', TRUE, '1-3 SM', NULL),
('11111111133', 'CART032', 1, 'Cristina Oliveira Lima', 'Cris', '1988-10-30', 'F', 1, FALSE, 0, 'Advogada', TRUE, 'Mais de 3 SM', NULL),
('11111111134', 'CART033', 1, 'Patrícia Alves Rocha', NULL, '1993-05-20', 'F', 2, TRUE, 2, 'Professora', TRUE, '1-3 SM', NULL),
('11111111135', 'CART034', 1, 'Simone Lima Santos', NULL, '1980-12-12', 'F', 4, TRUE, 1, 'Aposentada', FALSE, 'Até 1 SM', NULL),
('11111111136', 'CART035', 1, 'Michele Alves Costa', 'Mi', '1997-02-02', 'F', 1, FALSE, 0, 'Estagiária', TRUE, 'Até 1 SM', NULL),
('11111111137', 'CART036', 1, 'Roberta Cristina Lima', NULL, '1986-06-06', 'F', 2, TRUE, 2, 'Cabeleireira', TRUE, '1-3 SM', NULL),
('11111111138', 'CART037', 1, 'Vanessa Oliveira Santos', 'Vane', '1991-11-11', 'F', 1, FALSE, 0, 'Fisioterapeuta', TRUE, 'Mais de 3 SM', NULL),
('11111111139', 'CART038', 1, 'Claudia Almeida Rocha', NULL, '1985-03-25', 'F', 3, TRUE, 1, 'Do lar', FALSE, 'Até 1 SM', NULL),
('11111111140', 'CART039', 1, 'Andrea Cristina Souza', 'Dedé', '1994-09-19', 'F', 1, FALSE, 0, 'Designer', TRUE, '1-3 SM', NULL),
('11111111141', 'CART040', 1, 'Gisele Lima Alves', NULL, '1989-04-04', 'F', 2, TRUE, 2, 'Enfermeira', TRUE, '1-3 SM', NULL),
('11111111142', 'CART041', 1, 'Luciana Cristina Santos', 'Lu', '1998-12-01', 'F', 1, FALSE, 0, 'Universitária', TRUE, 'Até 1 SM', NULL),
('11111111143', 'CART042', 1, 'Renata Almeida Costa', NULL, '1982-08-08', 'F', 2, TRUE, 3, 'Professora', TRUE, '1-3 SM', NULL),
('11111111144', 'CART043', 1, 'Fabiana Oliveira Lima', 'Fabi', '1996-03-15', 'F', 1, FALSE, 0, 'Analista de Marketing', TRUE, '1-3 SM', NULL),
('11111111145', 'CART044', 1, 'Aline Cristina Rocha', NULL, '1987-07-27', 'F', 3, TRUE, 1, 'Advogada', TRUE, 'Mais de 3 SM', NULL),
('11111111146', 'CART045', 1, 'Mariana Alves Souza', 'Mari', '1995-01-01', 'F', 1, FALSE, 0, 'Psicóloga', TRUE, '1-3 SM', NULL),
('11111111147', 'CART046', 1, 'Carla Cristina Lima', NULL, '1983-10-10', 'F', 2, TRUE, 2, 'Do lar', FALSE, 'Até 1 SM', NULL),
('11111111148', 'CART047', 1, 'Juliana Alves Costa', 'Ju', '1999-05-25', 'F', 1, FALSE, 0, 'Estagiária', TRUE, 'Até 1 SM', NULL),
('11111111149', 'CART048', 1, 'Simone Cristina Alves', NULL, '1981-02-18', 'F', 4, TRUE, 2, 'Aposentada', FALSE, 'Até 1 SM', NULL),
('11111111150', 'CART049', 1, 'Tatiane Oliveira Lima', 'Tati', '1990-06-30', 'F', 2, TRUE, 1, 'Vendedora', TRUE, '1-3 SM', NULL);

-- REATIVAR TRIGGERS
ALTER TABLE participante ENABLE TRIGGER trigger_novo_participante_ativo;

-- 10. INSERIR DEMAIS DADOS (endereços, contatos, frequência, etc)
-- Continuar com as tabelas restantes do arquivo original mantendo os IDs corretos
-- ... (endereco, contato, inscricao_programa, ficha_medica, etc)

-- =====================================================
-- TESTE DA TRIGGER
-- =====================================================

-- Teste 1: Verificar status inicial de novo participante
INSERT INTO participante (cpf, numero_carteirinha, nome_completo, data_nascimento, sexo) 
VALUES ('99999999999', 'TEST001', 'Maria Teste', '1990-01-01', 'F');

SELECT id_participante, nome_completo, status_id, 
       (SELECT situacao FROM status_participante WHERE id_status = participante.status_id) as situacao
FROM participante 
WHERE cpf = '99999999999';

-- Teste 2: Verificar trigger de frequência (faltas consecutivas)
-- Simular 5 faltas para desativar participante
DO $$
DECLARE
    v_participante_id INT;
    v_status_antes INT;
    v_status_depois INT;
BEGIN
    -- Criar um participante de teste
    INSERT INTO participante (cpf, numero_carteirinha, nome_completo, data_nascimento, sexo) 
    VALUES ('88888888888', 'TEST002', 'João Teste', '1985-01-01', 'M')
    RETURNING id_participante INTO v_participante_id;
    
    -- Verificar status inicial
    SELECT status_id INTO v_status_antes FROM participante WHERE id_participante = v_participante_id;
    RAISE NOTICE 'Status inicial do participante %: %', v_participante_id, v_status_antes;
    
    -- Inserir 5 faltas
    FOR i IN 1..5 LOOP
        INSERT INTO registro_frequencia (id_participante, id_status_presenca, data_registro, pse)
        VALUES (v_participante_id, 2, CURRENT_DATE - (i || ' days')::INTERVAL, NULL);
    END LOOP;
    
    -- Verificar status após faltas
    SELECT status_id INTO v_status_depois FROM participante WHERE id_participante = v_participante_id;
    RAISE NOTICE 'Status após 5 faltas do participante %: %', v_participante_id, v_status_depois;
END $$;

-- Limpar dados de teste
DELETE FROM participante WHERE cpf IN ('99999999999', '88888888888');

-- =====================================================
-- CONSULTAS PARA VALIDAÇÃO
-- =====================================================

-- 1. Participantes ativos vs inativos
SELECT 
    sp.nome_status,
    sp.situacao,
    COUNT(p.id_participante) as quantidade
FROM status_participante sp
LEFT JOIN participante p ON p.status_id = sp.id_status
GROUP BY sp.id_status, sp.nome_status, sp.situacao
ORDER BY sp.id_status;

-- 2. Participantes com mais de 3 faltas (últimos 30 dias)
SELECT 
    p.id_participante,
    p.nome_completo,
    COUNT(rf.id_registro) as faltas_30dias
FROM participante p
JOIN registro_frequencia rf ON rf.id_participante = p.id_participante
WHERE rf.id_status_presenca = 2  -- Falta
  AND rf.data_registro > CURRENT_DATE - INTERVAL '30 days'
GROUP BY p.id_participante, p.nome_completo
HAVING COUNT(rf.id_registro) >= 3
ORDER BY faltas_30dias DESC;
