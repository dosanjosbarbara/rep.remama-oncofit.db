-- =====================================================
-- BANCO DE DADOS REMAMA / ONCOFIT - VERSÃO CORRIGIDA
-- PARA SUPABASE (POSTGRESQL)
-- =====================================================

-- 1. TABELAS INDEPENDENTES -- 
CREATE TABLE status_participante (  
    id_status INT PRIMARY KEY, 
    nome_status VARCHAR(20) NOT NULL,
    situacao BOOLEAN NOT NULL DEFAULT TRUE  -- TRUE = 1 (ativo), FALSE = 0 (inativo)
);

CREATE TABLE estado_civil (
    id_estado_civil INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    descricao VARCHAR(20) NOT NULL
);

-- 1 = remama / 2 = oncofit / 3 = ambos 
CREATE TABLE programa ( 
    id_programa INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome_programa VARCHAR(50) NOT NULL,
    dias_semana VARCHAR(100),
    horario TIME
);

CREATE TABLE tipo_comorbidade (
    id_tipo_comorbidade INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome_comorbidade VARCHAR(100) NOT NULL
);

CREATE TABLE tipo_treinamento (
    id_tipo_treinamento INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome_treinamento VARCHAR(50) NOT NULL
);

CREATE TABLE status_presenca (
    id_status_presenca INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sigla CHAR(1) NOT NULL,
    descricao VARCHAR(20) NOT NULL
);

-- 1 = Aluna / 2 = Gerente / 3 = Capitã / 4 = dragonete
CREATE TABLE cargo_participante ( 
    id_cargo INT PRIMARY KEY, 
    nome_cargo VARCHAR(30) NOT NULL
);

CREATE TABLE funcoes (
    id_funcao INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome_funcao VARCHAR(100) NOT NULL
);

-- 2. TABELA PRINCIPAL (participante)
CREATE TABLE participante (
    id_participante INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cpf CHAR(11) UNIQUE NOT NULL,
    numero_carteirinha VARCHAR(20) UNIQUE,
    id_status INT REFERENCES status_participante(id_status),
    data_inscricao TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    nome_completo VARCHAR(150),
    nome_social VARCHAR(150),
    data_nascimento DATE NOT NULL,
    sexo CHAR(1) DEFAULT 'F',
    id_estado_civil INT REFERENCES estado_civil(id_estado_civil),
    possui_filhos BOOLEAN DEFAULT FALSE,
    quantidade_filhos SMALLINT DEFAULT 0,
    profissao VARCHAR(100),
    trabalha_atualmente BOOLEAN,
    renda_familiar_faixa VARCHAR(20) CHECK (renda_familiar_faixa IN ('Até 1 SM', '1-3 SM', 'Mais de 3 SM')),
    foto_url VARCHAR(500),
    observacoes TEXT
);

-- 3. TABELAS QUE DEPENDEM DE participante
CREATE TABLE endereco (
    id_endereco INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_participante INT NOT NULL REFERENCES participante(id_participante),
    cep CHAR(8) NOT NULL,
    logradouro VARCHAR(150) NOT NULL,
    numero VARCHAR(10) NOT NULL,
    complemento VARCHAR(100),
    bairro VARCHAR(50) NOT NULL,
    cidade VARCHAR(50) NOT NULL,
    uf CHAR(2) NOT NULL
);

CREATE TABLE contato (
    id_contato INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_participante INT NOT NULL REFERENCES participante(id_participante),
    telefone_fixo VARCHAR(14),
    celular VARCHAR(15) NOT NULL,
    contato_emergencia_nome VARCHAR(100) NOT NULL,
    contato_emergencia_tel VARCHAR(15) NOT NULL,
    contato_emergencia_parentesco VARCHAR(30)
);

CREATE TABLE dados_antropometricos (
    id_antropometrico INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_participante INT NOT NULL REFERENCES participante(id_participante),
    data_medicao TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    peso_kg DECIMAL(5,2) NOT NULL,
    altura_m DECIMAL(3,2) NOT NULL,
    cintura_cm DECIMAL(5,2),
    quadril_cm DECIMAL(5,2)
);

CREATE TABLE avaliacao (
    id_avaliacao INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_participante INT NOT NULL REFERENCES participante(id_participante),
    numero_avaliacao INT NOT NULL,
    ano INT NOT NULL,
    data_avaliacao TIMESTAMPTZ NOT NULL,
    sentar_levantar_reps INT,
    mmss_ld_kg DECIMAL(5,2),
    mmss_le_kg DECIMAL(5,2),
    mmss_ld_dominante BOOLEAN,
    mmss_le_dominante BOOLEAN,
    marcha_passadas INT,
    classificacao_flexibilidade VARCHAR(50),
    amplitude_braco_cm DECIMAL(5,2),
    movimentacao_tronco TEXT,
    equilibrio TEXT,
    cond_aerobico TEXT,
    forca TEXT
);

CREATE TABLE ficha_medica (
    id_ficha INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_participante INT NOT NULL UNIQUE REFERENCES participante(id_participante),
    atestado_medico_url VARCHAR(500),
    doc_oncologico_url VARCHAR(500),
    data_diagnostico TIMESTAMPTZ,
    pos_menopausa BOOLEAN,
    tipo_cancer VARCHAR(100),
    mamas_afetadas VARCHAR(5) CHECK (mamas_afetadas IN ('LD', 'LE', 'Ambas')),
    recidiva BOOLEAN DEFAULT FALSE,
    data_recidiva TIMESTAMPTZ,
    locais_afetados TEXT,
    tratamentos_realizados TEXT
);

CREATE TABLE comorbidade (
    id_comorbidade INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_participante INT NOT NULL REFERENCES participante(id_participante),
    id_tipo_comorbidade INT REFERENCES tipo_comorbidade(id_tipo_comorbidade),
    toma_medicamento BOOLEAN,
    qual_medicamento TEXT
);

CREATE TABLE treinamento (
    id_treinamento INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_participante INT NOT NULL REFERENCES participante(id_participante),
    id_tipo_treinamento INT NOT NULL REFERENCES tipo_treinamento(id_tipo_treinamento),
    data_conclusao TIMESTAMPTZ
);

CREATE TABLE evento (
    id_evento INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_participante INT NOT NULL REFERENCES participante(id_participante),
    nome_evento VARCHAR(150) NOT NULL,
    data_evento TIMESTAMPTZ NOT NULL,
    resultado TEXT
);

CREATE TABLE inscricao_programa (
    id_inscricao INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_participante INT NOT NULL REFERENCES participante(id_participante),
    id_programa INT NOT NULL REFERENCES programa(id_programa),
    id_cargo INT REFERENCES cargo_participante(id_cargo),
    turma VARCHAR(20),
    data_inscricao TIMESTAMPTZ DEFAULT CURRENT_DATE,
    especializacao_leme BOOLEAN DEFAULT FALSE,
    especializacao_tambor BOOLEAN DEFAULT FALSE,
    data_desligamento DATE NULL
);

-- 4. TABELA DE FREQUÊNCIA
CREATE TABLE registro_frequencia (
    id_frequencia INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_participante INT NOT NULL REFERENCES participante(id_participante),
    id_status_presenca INT NOT NULL REFERENCES status_presenca(id_status_presenca),
    id_treinamento INT NULL REFERENCES treinamento(id_treinamento),
    id_evento INT NULL REFERENCES evento(id_evento),
    data_registro DATE NOT NULL DEFAULT CURRENT_DATE,
    justificativa_url VARCHAR(500),
    pse INT,
    fc_antes INT,
    fc_depois INT
);

-- 5. TABELAS DE FUNCIONÁRIOS E AUDITORIA
CREATE TABLE funcionarios (
    id_funcionario INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome_funcionario VARCHAR(150) NOT NULL,
    id_funcao INT NOT NULL REFERENCES funcoes(id_funcao),
    email VARCHAR(100) UNIQUE NOT NULL,
    senha_hash VARCHAR(255) NOT NULL
);

CREATE TABLE auditoria_sistema (
    id_audit BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    data_evento TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    id_funcionario INT NOT NULL REFERENCES funcionarios(id_funcionario),
    tabela_afetada VARCHAR(50) NOT NULL,
    registro_id INT NOT NULL,
    acao VARCHAR(10) NOT NULL,
    dados_antigos JSONB,
    dados_novos JSONB,
    ip_origem VARCHAR(45)
);
