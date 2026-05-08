-- =====================================================
-- DADOS FICTÍCIOS PARA REMAMA/ONCOFIT
-- VERSÃO COMPLETA PARA ANÁLISE
-- =====================================================

-- 1. TABELAS DE DOMÍNIO (se já existirem, não duplica)
INSERT INTO status_participante (nome_status) VALUES 
    ('Ativa'), ('Inativa'), ('Suspensa'), ('Falecida')
ON CONFLICT (id_status) DO NOTHING;

INSERT INTO estado_civil (descricao) VALUES 
    ('Solteira'), ('Casada'), ('Divorciada'), ('Viúva'), ('União Estável')
ON CONFLICT (id_estado_civil) DO NOTHING;

INSERT INTO programa (nome_programa) VALUES 
    ('Remama'), ('Oncofit')
ON CONFLICT (id_programa) DO NOTHING;

INSERT INTO cargo_participante (nome_cargo) VALUES 
    ('Aluna'), ('Gerente'), ('Capitã'), ('Dragonete')
ON CONFLICT (id_cargo) DO NOTHING;

INSERT INTO status_presenca (sigla, descricao) VALUES 
    ('P', 'Presente'), ('F', 'Falta'), ('J', 'Justificada')
ON CONFLICT (id_status_presenca) DO NOTHING;

INSERT INTO funcoes (nome_funcao) VALUES 
    ('Coordenador'), ('Professor'), ('Voluntário'), ('Pesquisador')
ON CONFLICT (id_funcao) DO NOTHING;

INSERT INTO tipo_comorbidade (nome_comorbidade) VALUES 
    ('Hipertensão'), ('Diabetes tipo 2'), ('Asma'), ('Cardiopatia'), 
    ('Obesidade'), ('Ansiedade'), ('Depressão'), ('Hipotireoidismo')
ON CONFLICT (id_tipo_comorbidade) DO NOTHING;

INSERT INTO tipo_treinamento (nome_treinamento) VALUES 
    ('Acolhimento'), ('Natação'), ('Tambor'), ('Leme'), ('Primeiros Socorros')
ON CONFLICT (id_tipo_treinamento) DO NOTHING;

-- 2. PARTICIPANTES (50 participantes)
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

-- 3. ENDEREÇOS (para os 50 participantes)
INSERT INTO endereco (id_participante, cep, logradouro, numero, complemento, bairro, cidade, uf) VALUES
(1, '01234000', 'Rua das Flores', '100', 'Apto 101', 'Jardim Paulista', 'São Paulo', 'SP'),
(2, '01311000', 'Avenida Paulista', '1500', 'Conj 42', 'Bela Vista', 'São Paulo', 'SP'),
(3, '01414000', 'Rua Augusta', '200', NULL, 'Consolação', 'São Paulo', 'SP'),
(4, '05010000', 'Rua Cardeal Arcoverde', '300', 'Bloco B', 'Pinheiros', 'São Paulo', 'SP'),
(5, '05424000', 'Rua Teodoro Sampaio', '400', NULL, 'Pinheiros', 'São Paulo', 'SP'),
(6, '04116000', 'Rua Domingos de Morais', '500', 'Casa 2', 'Vila Mariana', 'São Paulo', 'SP'),
(7, '03155000', 'Rua do Oratório', '600', NULL, 'Mooca', 'São Paulo', 'SP'),
(8, '04826000', 'Estrada do M\Boi Mirim', '700', 'Casa', 'Jardim Ângela', 'São Paulo', 'SP'),
(9, '06401000', 'Avenida Engenheiro Eusébio Stevaux', '800', 'Apto 303', 'Parque Continental', 'Barueri', 'SP'),
(10, '06690000', 'Rua Salvador', '900', NULL, 'Centro', 'Itapevi', 'SP'),
(11, '07010000', 'Rua General Osório', '110', 'Casa', 'Centro', 'Guarulhos', 'SP'),
(12, '08020000', 'Avenida São João', '120', 'Apto 15', 'Vila Ré', 'São Paulo', 'SP'),
(13, '09030000', 'Rua Santo André', '130', NULL, 'Centro', 'Santo André', 'SP'),
(14, '09140000', 'Avenida Portugal', '140', 'Bloco C', 'Vila Assis', 'Santo André', 'SP'),
(15, '09250000', 'Rua Rio Branco', '150', 'Casa', 'Centro', 'São Bernardo', 'SP'),
(16, '09360000', 'Avenida Kennedy', '160', 'Apto 202', 'Planalto', 'São Caetano', 'SP'),
(17, '09470000', 'Rua Amazonas', '170', NULL, 'Vila São José', 'Diadema', 'SP'),
(18, '09580000', 'Avenida Brasil', '180', 'Casa', 'Centro', 'Mauá', 'SP'),
(19, '09690000', 'Rua Uruguai', '190', 'Apto 45', 'Vila Nova', 'Ribeirão Pires', 'SP'),
(20, '09700000', 'Avenida Rio Grande', '200', NULL, 'Centro', 'Rio Grande da Serra', 'SP'),
(21, '09810000', 'Rua Chile', '210', 'Casa', 'Vila Suíça', 'São Bernardo', 'SP'),
(22, '09920000', 'Avenida Argentina', '220', 'Bloco D', 'Jardim do Mar', 'São Vicente', 'SP'),
(23, '10030000', 'Rua Peru', '230', NULL, 'Centro', 'Santos', 'SP'),
(24, '10140000', 'Avenida Colômbia', '240', 'Apto 88', 'Boqueirão', 'Praia Grande', 'SP'),
(25, '10250000', 'Rua Equador', '250', 'Casa', 'Vila Mirim', 'São Vicente', 'SP'),
(26, '10360000', 'Avenida Venezuela', '260', NULL, 'Centro', 'Santos', 'SP'),
(27, '10470000', 'Rua Bolívia', '270', 'Apto 31', 'Ponta da Praia', 'Santos', 'SP'),
(28, '10580000', 'Avenida Paraguai', '280', 'Casa', 'Jardim São Paulo', 'São Bernardo', 'SP'),
(29, '10690000', 'Rua Uruguai', '290', NULL, 'Centro', 'São Caetano', 'SP'),
(30, '10700000', 'Avenida Guiana', '300', 'Bloco E', 'Vila Barcelona', 'Santo André', 'SP'),
(31, '10810000', 'Rua Suriname', '310', 'Apto 12', 'Centro', 'Diadema', 'SP'),
(32, '10920000', 'Avenida França', '320', 'Casa', 'Vila Rica', 'Mauá', 'SP'),
(33, '11030000', 'Rua Inglaterra', '330', NULL, 'Centro', 'Ribeirão Pires', 'SP'),
(34, '11140000', 'Avenida Alemanha', '340', 'Apto 77', 'Vila Nova', 'Rio Grande da Serra', 'SP'),
(35, '11250000', 'Rua Itália', '350', 'Casa', 'Centro', 'São Bernardo', 'SP'),
(36, '11360000', 'Avenida Espanha', '360', NULL, 'Vila Suzana', 'Santo André', 'SP'),
(37, '11470000', 'Rua Portugal', '370', 'Bloco F', 'Centro', 'São Caetano', 'SP'),
(38, '11580000', 'Avenida Holanda', '380', 'Apto 54', 'Vila Palmares', 'Diadema', 'SP'),
(39, '11690000', 'Rua Bélgica', '390', 'Casa', 'Centro', 'Mauá', 'SP'),
(40, '11700000', 'Avenida Suécia', '400', NULL, 'Vila Esperança', 'Ribeirão Pires', 'SP'),
(41, '11810000', 'Rua Noruega', '410', 'Apto 23', 'Centro', 'São Bernardo', 'SP'),
(42, '11920000', 'Avenida Dinamarca', '420', 'Casa', 'Vila São Pedro', 'Santo André', 'SP'),
(43, '12030000', 'Rua Finlândia', '430', NULL, 'Centro', 'São Caetano', 'SP'),
(44, '12140000', 'Avenida Islândia', '440', 'Bloco G', 'Vila Boa Vista', 'Diadema', 'SP'),
(45, '12250000', 'Rua Irlanda', '450', 'Apto 99', 'Centro', 'Mauá', 'SP'),
(46, '12360000', 'Avenida Escócia', '460', 'Casa', 'Vila Progresso', 'Ribeirão Pires', 'SP'),
(47, '12470000', 'Rua País de Gales', '470', NULL, 'Centro', 'São Bernardo', 'SP'),
(48, '12580000', 'Avenida Canadá', '480', 'Bloco H', 'Vila América', 'Santo André', 'SP'),
(49, '12690000', 'Rua Austrália', '490', 'Apto 66', 'Centro', 'São Caetano', 'SP'),
(50, '12700000', 'Avenida Nova Zelândia', '500', 'Casa', 'Vila Ouro', 'Diadema', 'SP');

-- 4. CONTATOS (para os 50 participantes)
INSERT INTO contato (id_participante, celular, contato_emergencia_nome, contato_emergencia_tel, contato_emergencia_parentesco) VALUES
(1, '11999991111', 'Carlos Silva', '11988887777', 'Filho'),
(2, '11999992222', 'João Santos', '11988886666', 'Marido'),
(3, '11999993333', 'Marcos Souza', '11988885555', 'Filho'),
(4, '11999994444', 'Ana Lima', '11988884444', 'Filha'),
(5, '11999995555', 'Paulo Rocha', '11988883333', 'Pai'),
(6, '11999996666', 'Roberto Mendes', '11988882222', 'Marido'),
(7, '11999997777', 'Maria Martins', '11988881111', 'Esposa'),
(8, '11999998888', 'José Ferreira', '11988880000', 'Pai'),
(9, '11999999999', 'Carla Nunes', '11988889999', 'Irmã'),
(10, '11999990000', 'Luciana Dias', '11988887788', 'Irmã'),
(11, '11999991112', 'Ricardo Alves', '11988881234', 'Namorado'),
(12, '11999992223', 'Fernanda Lima', '11988882345', 'Mãe'),
(13, '11999993334', 'Carlos Costa', '11988883456', 'Pai'),
(14, '11999994445', 'Juliana Rocha', '11988884567', 'Irmã'),
(15, '11999995556', 'Marcelo Souza', '11988885678', 'Marido'),
(16, '11999996667', 'Patrícia Alves', '11988886789', 'Filha'),
(17, '11999997778', 'Roberto Lima', '11988887890', 'Pai'),
(18, '11999998889', 'Cristina Santos', '11988888901', 'Mãe'),
(19, '11999999990', 'André Costa', '11988889012', 'Marido'),
(20, '11999990001', 'Vanessa Rocha', '11988880123', 'Irmã'),
(21, '11999991113', 'Fernando Alves', '11988881234', 'Pai'),
(22, '11999992224', 'Simone Lima', '11988882345', 'Mãe'),
(23, '11999993335', 'Gustavo Santos', '11988883456', 'Marido'),
(24, '11999994446', 'Aline Costa', '11988884567', 'Filha'),
(25, '11999995557', 'Ricardo Almeida', '11988885678', 'Pai'),
(26, '11999996668', 'Tatiane Rocha', '11988886789', 'Irmã'),
(27, '11999997779', 'Luciano Lima', '11988887890', 'Marido'),
(28, '11999998880', 'Claudia Santos', '11988888901', 'Mãe'),
(29, '11999999991', 'Marcelo Alves', '11988889012', 'Pai'),
(30, '11999990002', 'Juliana Costa', '11988880123', 'Filha'),
(31, '11999991114', 'Roberto Almeida', '11988881234', 'Marido'),
(32, '11999992225', 'Fernanda Lima', '11988882345', 'Mãe'),
(33, '11999993336', 'Carlos Santos', '11988883456', 'Pai'),
(34, '11999994447', 'Patrícia Rocha', '11988884567', 'Irmã'),
(35, '11999995558', 'André Alves', '11988885678', 'Marido'),
(36, '11999996669', 'Simone Costa', '11988886789', 'Filha'),
(37, '11999997770', 'Gustavo Lima', '11988887890', 'Pai'),
(38, '11999998881', 'Aline Santos', '11988888901', 'Mãe'),
(39, '11999999992', 'Ricardo Almeida', '11988889012', 'Marido'),
(40, '11999990003', 'Tatiane Rocha', '11988880123', 'Irmã'),
(41, '11999991115', 'Luciano Lima', '11988881234', 'Marido'),
(42, '11999992226', 'Claudia Santos', '11988882345', 'Mãe'),
(43, '11999993337', 'Marcelo Alves', '11988883456', 'Pai'),
(44, '11999994448', 'Juliana Costa', '11988884567', 'Filha'),
(45, '11999995559', 'Roberto Almeida', '11988885678', 'Marido'),
(46, '11999996660', 'Fernanda Lima', '11988886789', 'Mãe'),
(47, '11999997771', 'Carlos Santos', '11988887890', 'Pai'),
(48, '11999998882', 'Patrícia Rocha', '11988888901', 'Irmã'),
(49, '11999999993', 'André Alves', '11988889012', 'Marido'),
(50, '11999990004', 'Simone Costa', '11988880123', 'Filha');

-- 5. INSCRIÇÕES NOS PROGRAMAS
INSERT INTO inscricao_programa (id_participante, id_programa, id_cargo, turma, data_inscricao, especializacao_leme, especializacao_tambor) VALUES
(1, 1, 1, 'Turma A', '2025-01-10', FALSE, FALSE),
(2, 1, 1, 'Turma A', '2025-01-10', FALSE, FALSE),
(3, 1, 2, 'Turma A', '2025-01-10', TRUE, FALSE),
(4, 2, 1, 'Turma B', '2025-02-15', FALSE, FALSE),
(5, 2, 1, 'Turma B', '2025-02-15', FALSE, FALSE),
(6, 1, 3, 'Turma A', '2025-01-10', FALSE, TRUE),
(7, 2, 4, 'Turma B', '2025-02-15', FALSE, FALSE),
(8, 1, 1, 'Turma A', '2025-01-10', FALSE, FALSE),
(9, 2, 1, 'Turma B', '2025-02-15', FALSE, FALSE),
(10, 1, 1, 'Turma A', '2025-01-10', FALSE, FALSE),
(11, 1, 1, 'Turma A', '2025-01-15', FALSE, FALSE),
(12, 2, 2, 'Turma B', '2025-02-20', TRUE, FALSE),
(13, 1, 1, 'Turma A', '2025-01-20', FALSE, FALSE),
(14, 2, 1, 'Turma B', '2025-02-25', FALSE, FALSE),
(15, 1, 3, 'Turma A', '2025-01-25', FALSE, TRUE),
(16, 2, 1, 'Turma B', '2025-03-01', FALSE, FALSE),
(17, 1, 1, 'Turma A', '2025-02-01', FALSE, FALSE),
(18, 2, 4, 'Turma B', '2025-03-05', FALSE, FALSE),
(19, 1, 2, 'Turma A', '2025-02-05', TRUE, FALSE),
(20, 2, 1, 'Turma B', '2025-03-10', FALSE, FALSE),
(21, 1, 1, 'Turma A', '2025-02-10', FALSE, FALSE),
(22, 2, 1, 'Turma B', '2025-03-15', FALSE, FALSE),
(23, 1, 1, 'Turma A', '2025-02-15', FALSE, FALSE),
(24, 2, 2, 'Turma B', '2025-03-20', TRUE, FALSE),
(25, 1, 1, 'Turma A', '2025-02-20', FALSE, FALSE),
(26, 2, 1, 'Turma B', '2025-03-25', FALSE, FALSE),
(27, 1, 3, 'Turma A', '2025-02-25', FALSE, TRUE),
(28, 2, 1, 'Turma B', '2025-03-30', FALSE, FALSE),
(29, 1, 1, 'Turma A', '2025-03-01', FALSE, FALSE),
(30, 2, 4, 'Turma B', '2025-04-05', FALSE, FALSE),
(31, 1, 1, 'Turma A', '2025-03-05', FALSE, FALSE),
(32, 2, 1, 'Turma B', '2025-04-10', FALSE, FALSE),
(33, 1, 2, 'Turma A', '2025-03-10', TRUE, FALSE),
(34, 2, 1, 'Turma B', '2025-04-15', FALSE, FALSE),
(35, 1, 1, 'Turma A', '2025-03-15', FALSE, FALSE),
(36, 2, 1, 'Turma B', '2025-04-20', FALSE, FALSE),
(37, 1, 1, 'Turma A', '2025-03-20', FALSE, FALSE),
(38, 2, 2, 'Turma B', '2025-04-25', TRUE, FALSE),
(39, 1, 1, 'Turma A', '2025-03-25', FALSE, FALSE),
(40, 2, 1, 'Turma B', '2025-04-30', FALSE, FALSE),
(41, 1, 3, 'Turma A', '2025-03-30', FALSE, TRUE),
(42, 2, 1, 'Turma B', '2025-05-05', FALSE, FALSE),
(43, 1, 1, 'Turma A', '2025-04-05', FALSE, FALSE),
(44, 2, 4, 'Turma B', '2025-05-10', FALSE, FALSE),
(45, 1, 1, 'Turma A', '2025-04-10', FALSE, FALSE),
(46, 2, 1, 'Turma B', '2025-05-15', FALSE, FALSE),
(47, 1, 2, 'Turma A', '2025-04-15', TRUE, FALSE),
(48, 2, 1, 'Turma B', '2025-05-20', FALSE, FALSE)

-- 6. FICHAS MÉDICAS (apenas para participantes com diagnóstico)
INSERT INTO ficha_medica (id_participante, atestado_medico_url, doc_oncologico_url, data_diagnostico, tipo_cancer, mamas_afetadas, recidiva, tratamentos_realizados) VALUES
(1, 'https://storage.supabase.co/atestado1.pdf', 'https://storage.supabase.co/onco1.pdf', '2022-03-15', 'Câncer de Mama', 'LE', FALSE, 'Quimioterapia e Radioterapia'),
(3, 'https://storage.supabase.co/atestado3.pdf', 'https://storage.supabase.co/onco3.pdf', '2023-01-10', 'Câncer de Mama', 'LD', FALSE, 'Cirurgia e Quimioterapia'),
(4, 'https://storage.supabase.co/atestado4.pdf', 'https://storage.supabase.co/onco4.pdf', '2021-08-20', 'Câncer de Mama', 'Ambas', TRUE, 'Quimioterapia, Cirurgia, Radioterapia'),
(6, 'https://storage.supabase.co/atestado6.pdf', 'https://storage.supabase.co/onco6.pdf', '2022-11-05', 'Câncer de Ovário', NULL, FALSE, 'Cirurgia'),
(8, 'https://storage.supabase.co/atestado8.pdf', 'https://storage.supabase.co/onco8.pdf', '2023-06-30', 'Câncer de Mama', 'LE', FALSE, 'Quimioterapia'),
(10, 'https://storage.supabase.co/atestado10.pdf', 'https://storage.supabase.co/onco10.pdf', '2020-02-10', 'Câncer de Mama', 'LD', TRUE, 'Quimioterapia, Cirurgia'),
(12, 'https://storage.supabase.co/atestado12.pdf', 'https://storage.supabase.co/onco12.pdf', '2023-09-12', 'Câncer de Colo de Útero', NULL, FALSE, 'Radioterapia'),
(15, 'https://storage.supabase.co/atestado15.pdf', 'https://storage.supabase.co/onco15.pdf', '2022-12-01', 'Câncer de Mama', 'LE', FALSE, 'Cirurgia'),
(18, 'https://storage.supabase.co/atestado18.pdf', 'https://storage.supabase.co/onco18.pdf', '2023-04-18', 'Câncer de Mama', 'Ambas', FALSE, 'Quimioterapia'),
(20, 'https://storage.supabase.co/atestado20.pdf', 'https://storage.supabase.co/onco20.pdf', '2021-10-25', 'Câncer de Ovário', NULL, FALSE, 'Cirurgia e Quimioterapia'),
(22, 'https://storage.supabase.co/atestado22.pdf', 'https://storage.supabase.co/onco22.pdf', '2023-07-07', 'Câncer de Mama', 'LD', FALSE, 'Radioterapia'),
(25, 'https://storage.supabase.co/atestado25.pdf', 'https://storage.supabase.co/onco25.pdf', '2022-05-15', 'Câncer de Mama', 'LE', FALSE, 'Quimioterapia'),
(28, 'https://storage.supabase.co/atestado28.pdf', 'https://storage.supabase.co/onco28.pdf', '2023-02-28', 'Câncer de Colo de Útero', NULL, FALSE, 'Cirurgia'),
(30, 'https://storage.supabase.co/atestado30.pdf', 'https://storage.supabase.co/onco30.pdf', '2021-12-03', 'Câncer de Mama', 'Ambas', FALSE, 'Quimioterapia e Radioterapia'),
(33, 'https://storage.supabase.co/atestado33.pdf', 'https://storage.supabase.co/onco33.pdf', '2023-10-10', 'Câncer de Mama', 'LD', FALSE, 'Cirurgia'),
(36, 'https://storage.supabase.co/atestado36.pdf', 'https://storage.supabase.co/onco36.pdf', '2022-08-22', 'Câncer de Ovário', NULL, FALSE, 'Quimioterapia'),
(39, 'https://storage.supabase.co/atestado39.pdf', 'https://storage.supabase.co/onco39.pdf', '2023-03-15', 'Câncer de Mama', 'LE', FALSE, 'Radioterapia'),
(42, 'https://storage.supabase.co/atestado42.pdf', 'https://storage.supabase.co/onco42.pdf', '2021-06-01', 'Câncer de Mama', 'LD', TRUE, 'Quimioterapia, Cirurgia'),
(45, 'https://storage.supabase.co/atestado45.pdf', 'https://storage.supabase.co/onco45.pdf', '2023-05-20', 'Câncer de Colo de Útero', NULL, FALSE, 'Cirurgia'),
(48, 'https://storage.supabase.co/atestado48.pdf', 'https://storage.supabase.co/onco48.pdf', '2022-09-09', 'Câncer de Mama', 'Ambas', FALSE, 'Quimioterapia');

-- 7. DADOS ANTROPOMÉTRICOS (múltiplas medições por participante)
INSERT INTO dados_antropometricos (id_participante, data_medicao, peso_kg, altura_m, cintura_cm, quadril_cm) VALUES
(1, '2025-01-15', 72.5, 1.65, 88.0, 98.0),
(1, '2025-03-15', 70.2, 1.65, 85.0, 96.0
