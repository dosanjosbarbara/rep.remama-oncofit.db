-- =====================================================
-- BANCO DE DADOS REMAMA / ONCOFIT - PostgreSQL - V3 - GESTAO SIMPLES
-- Estrutura, integridade e politicas de acesso. Executar em banco novo.
-- Requer PostgreSQL 15+ para views SECURITY_INVOKER.
-- O backend autentica o usuario e configura app.id_usuario por transacao.
-- =====================================================

-- =====================================================
-- 1. TABELAS INDEPENDENTES
-- =====================================================

CREATE TABLE status_participante (
    id_status INT PRIMARY KEY,
    nome_status VARCHAR(20) NOT NULL,
    situacao BOOLEAN NOT NULL DEFAULT TRUE  -- TRUE = ativo, FALSE = inativo
);

CREATE TABLE estado_civil (
    id_estado_civil INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    descricao VARCHAR(20) NOT NULL
);

-- 1 = Remama / 2 = OncoFit. Inscricao simultanea = dois registros.
CREATE TABLE programa (
    id_programa INT PRIMARY KEY CHECK (id_programa IN (1, 2)),
    nome_programa VARCHAR(50) NOT NULL,
    dias_semana VARCHAR(100),
    horario TIME
);

CREATE TABLE tipo_comorbidade (
    id_tipo_comorbidade INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome_comorbidade VARCHAR(100) NOT NULL UNIQUE,
    exige_variacao BOOLEAN NOT NULL DEFAULT FALSE,
    -- Substitui a comparação por nome fixo na trigger de validação:
    -- renomear/corrigir este nome_comorbidade no futuro não quebra
    -- mais a exigência de descrição livre.
    exige_descricao BOOLEAN NOT NULL DEFAULT FALSE
);

-- Variacoes do radar fornecido pelo cliente (quando houver).
CREATE TABLE variacao_comorbidade (
    id_variacao INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_tipo_comorbidade INT NOT NULL REFERENCES tipo_comorbidade(id_tipo_comorbidade),
    nome_variacao VARCHAR(100) NOT NULL,
    UNIQUE (id_tipo_comorbidade, nome_variacao),
    UNIQUE (id_tipo_comorbidade, id_variacao)
);

CREATE TABLE tipo_treinamento (
    id_tipo_treinamento INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome_treinamento VARCHAR(50) NOT NULL
);

CREATE TABLE status_presenca (
    id_status_presenca INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sigla CHAR(1) NOT NULL UNIQUE,
    descricao VARCHAR(20) NOT NULL
);

-- 1 = Aluna / 2 = Gerente / 3 = Capitã / 4 = Dragonete
CREATE TABLE cargo_participante (
    id_cargo INT PRIMARY KEY,
    nome_cargo VARCHAR(30) NOT NULL
);

CREATE TABLE tipo_cancer (
    id_tipo_cancer INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome_cancer VARCHAR(100) NOT NULL,
    cid_o VARCHAR(10)  -- opcional: código CID-O, se a Remama quiser rastreabilidade clínica
);

-- =====================================================
-- 2. TABELA PRINCIPAL (participante)
-- =====================================================

CREATE TABLE participante (
    id_participante INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cpf CHAR(11) UNIQUE NOT NULL,
    numero_carteirinha VARCHAR(20) UNIQUE,
    id_status INT NOT NULL DEFAULT 4 REFERENCES status_participante(id_status),
    data_inscricao TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    nome_completo VARCHAR(150),
    nome_social VARCHAR(150),
    data_nascimento DATE NOT NULL,
    sexo CHAR(1) DEFAULT 'F' CHECK (sexo IN ('F', 'M')),
    id_estado_civil INT REFERENCES estado_civil(id_estado_civil),
    possui_filhos BOOLEAN DEFAULT FALSE,
    quantidade_filhos SMALLINT DEFAULT 0,
    profissao VARCHAR(100),
    trabalha_atualmente BOOLEAN,
    renda_familiar_faixa VARCHAR(20) CHECK (renda_familiar_faixa IN ('Até 1 SM', '1-3 SM', 'Mais de 3 SM')),
    foto_url VARCHAR(500),
    observacoes TEXT
);

-- =====================================================
-- 3. TABELAS QUE DEPENDEM DE participante
-- =====================================================

CREATE TABLE endereco (
    id_endereco INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_participante INT NOT NULL REFERENCES participante(id_participante),
    cep CHAR(8) NOT NULL,
    logradouro VARCHAR(150) NOT NULL,
    numero VARCHAR(10) NOT NULL,
    complemento VARCHAR(100),
    bairro VARCHAR(50) NOT NULL,
    cidade VARCHAR(50) NOT NULL,
    uf CHAR(2) NOT NULL CHECK (uf IN (
        'AC','AL','AP','AM','BA','CE','DF','ES','GO','MA','MT','MS','MG',
        'PA','PB','PR','PE','PI','RJ','RN','RS','RO','RR','SC','SP','SE','TO'
    ))
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
    quadril_cm DECIMAL(5,2),
    CONSTRAINT ck_medidas_positivas CHECK (peso_kg > 0 AND altura_m > 0)
);

CREATE TABLE avaliacao (
    id_avaliacao INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_participante INT NOT NULL REFERENCES participante(id_participante),
    -- Cada avaliacao (inclusive seu PSE) pertence a uma inscricao/programa.
    id_inscricao INT NOT NULL,
    numero_avaliacao INT NOT NULL,
    ano INT NOT NULL,
    data_avaliacao TIMESTAMPTZ NOT NULL,
    fc_repouso INT CHECK (fc_repouso BETWEEN 30 AND 220),
    obs_avaliacao TEXT,
    sentar_levantar_reps INT CHECK (sentar_levantar_reps BETWEEN 0 AND 200),
    mmss_ld_reps INT CHECK (mmss_ld_reps BETWEEN 0 AND 200),
    mmss_le_reps INT CHECK (mmss_le_reps BETWEEN 0 AND 200),
    mmss_ld_dominante BOOLEAN,
    mmss_le_dominante BOOLEAN,
    marcha_passadas INT CHECK (marcha_passadas BETWEEN 0 AND 300),
    classificacao_flexibilidade VARCHAR(50) CHECK (classificacao_flexibilidade IN ('Excelente', 'Boa', 'Regular', 'Fraca')),
    amplitude_braco_cm DECIMAL(5,2),
    movimentacao_tronco TEXT,
    equilibrio TEXT,
    cond_aerobico TEXT,
    forca TEXT,
    pse INT CHECK (pse BETWEEN 0 AND 10),  -- Escala de Borg CR-10
    CONSTRAINT uq_avaliacao_programa UNIQUE (id_inscricao, ano, numero_avaliacao)
);

CREATE TABLE ficha_medica (
    id_ficha INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_participante INT NOT NULL UNIQUE REFERENCES participante(id_participante),
    doc_oncologico_url VARCHAR(500),
    data_diagnostico TIMESTAMPTZ,
    pos_menopausa BOOLEAN,
    id_tipo_cancer INT REFERENCES tipo_cancer(id_tipo_cancer),
    mamas_afetadas VARCHAR(5) CHECK (mamas_afetadas IN ('LD', 'LE', 'Ambas')),
    recidiva BOOLEAN DEFAULT FALSE,
    data_recidiva TIMESTAMPTZ,
    locais_afetados TEXT,
    tratamentos_realizados TEXT
);

CREATE TABLE comorbidade (
    id_comorbidade INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_participante INT NOT NULL REFERENCES participante(id_participante),
    id_tipo_comorbidade INT NOT NULL REFERENCES tipo_comorbidade(id_tipo_comorbidade),
    id_variacao INT,
    descricao_outras TEXT,
    toma_medicamento BOOLEAN,
    qual_medicamento TEXT,
    FOREIGN KEY (id_tipo_comorbidade, id_variacao)
        REFERENCES variacao_comorbidade(id_tipo_comorbidade, id_variacao)
);

-- A ficha atual permanece 1:1; documentos historicos sao 1:N.
CREATE TABLE atestado_medico (
    id_atestado BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_participante INT NOT NULL REFERENCES participante(id_participante),
    arquivo_url TEXT NOT NULL CHECK (btrim(arquivo_url) <> ''),
    observacao TEXT,
    data_documento DATE,
    anexado_em TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_usuario_autor INT NOT NULL
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
    resultado TEXT,
    CONSTRAINT uq_evento_participante UNIQUE (id_evento, id_participante)
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
    data_desligamento DATE NULL,
    CONSTRAINT uq_inscricao_identidade UNIQUE (id_inscricao, id_participante, id_programa),
    CONSTRAINT uq_inscricao_participante UNIQUE (id_inscricao, id_participante),
    CONSTRAINT ck_inscricao_periodo CHECK
        (data_desligamento IS NULL OR data_desligamento >= data_inscricao::date)
);

-- Uma inscricao ativa por participante e programa; inscricoes historicas permanecem.
CREATE UNIQUE INDEX uq_inscricao_ativa
    ON inscricao_programa (id_participante, id_programa)
    WHERE data_desligamento IS NULL;

ALTER TABLE avaliacao ADD CONSTRAINT fk_avaliacao_inscricao
    FOREIGN KEY (id_inscricao, id_participante)
    REFERENCES inscricao_programa (id_inscricao, id_participante);

-- Aula/atividade agendada: uma linha por ocorrencia, data e horario.
-- O calendario pode consultar esta tabela por programa e inicio.
CREATE TABLE aula (
    id_aula INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_programa INT NOT NULL REFERENCES programa(id_programa),
    titulo VARCHAR(150) NOT NULL,
    inicio TIMESTAMPTZ NOT NULL,
    fim TIMESTAMPTZ NOT NULL,
    local_aula VARCHAR(150),
    descricao TEXT,
    cancelada BOOLEAN NOT NULL DEFAULT FALSE,
    motivo_cancelamento TEXT,
    cancelada_em TIMESTAMPTZ,
    CONSTRAINT ck_aula_cancelamento CHECK (
        (cancelada = FALSE AND motivo_cancelamento IS NULL AND cancelada_em IS NULL)
        OR (cancelada = TRUE AND motivo_cancelamento IS NOT NULL
            AND btrim(motivo_cancelamento) <> '' AND cancelada_em IS NOT NULL)
    ),
    CONSTRAINT ck_aula_periodo CHECK (fim > inicio),
    CONSTRAINT uq_aula_programa UNIQUE (id_aula, id_programa)
);

CREATE INDEX idx_aula_calendario ON aula (id_programa, inicio)
    WHERE cancelada = FALSE;

-- Cancelar nao apaga chamadas anteriores. O motivo e obrigatorio e a data
-- e fixada pelo servidor; uma aula ja cancelada nao pode ser reativada.
CREATE OR REPLACE FUNCTION fn_cancelar_aula() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'UPDATE' AND OLD.cancelada AND NOT NEW.cancelada THEN
        RAISE EXCEPTION 'Cancelamento historico: crie uma nova aula para reagendar';
    END IF;
    IF NEW.cancelada THEN
        IF NEW.motivo_cancelamento IS NULL OR btrim(NEW.motivo_cancelamento) = '' THEN
            RAISE EXCEPTION 'Informe o motivo do cancelamento';
        END IF;
        IF TG_OP = 'INSERT' OR NOT OLD.cancelada THEN
            NEW.cancelada_em := CURRENT_TIMESTAMP;
        ELSIF NEW.cancelada_em IS DISTINCT FROM OLD.cancelada_em THEN
            RAISE EXCEPTION 'A data de cancelamento nao pode ser alterada';
        END IF;
    ELSE
        NEW.motivo_cancelamento := NULL;
        NEW.cancelada_em := NULL;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_cancelar_aula BEFORE INSERT OR UPDATE ON aula
FOR EACH ROW EXECUTE FUNCTION fn_cancelar_aula();

-- =====================================================
-- 4. TABELA DE FREQUÊNCIA
-- =====================================================

CREATE TABLE registro_frequencia (
    id_frequencia INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_participante INT NOT NULL REFERENCES participante(id_participante),
    id_status_presenca INT NOT NULL REFERENCES status_presenca(id_status_presenca),
    id_inscricao INT,
    id_programa INT,
    id_aula INT,
    id_evento INT,
    data_registro DATE NOT NULL DEFAULT CURRENT_DATE,
    fc_antes INT CHECK (fc_antes BETWEEN 30 AND 220),
    fc_depois INT CHECK (fc_depois BETWEEN 30 AND 220),
    -- PSE desta participante nesta aula, separado do PSE da avaliacao.
    pse INT CHECK (pse BETWEEN 0 AND 10),
    CONSTRAINT ck_frequencia_origem CHECK (
        (id_aula IS NOT NULL AND id_evento IS NULL
         AND id_inscricao IS NOT NULL AND id_programa IS NOT NULL)
        OR
        (id_aula IS NULL AND id_evento IS NOT NULL
         AND id_inscricao IS NULL AND id_programa IS NULL)
    ),
    CONSTRAINT fk_frequencia_inscricao
        FOREIGN KEY (id_inscricao, id_participante, id_programa)
        REFERENCES inscricao_programa (id_inscricao, id_participante, id_programa),
    CONSTRAINT fk_frequencia_aula
        FOREIGN KEY (id_aula, id_programa)
        REFERENCES aula (id_aula, id_programa),
    CONSTRAINT fk_frequencia_evento_participante
        FOREIGN KEY (id_evento, id_participante)
        REFERENCES evento (id_evento, id_participante),
    CONSTRAINT uq_frequencia_participante UNIQUE (id_frequencia, id_participante)
);

-- Uma justificativa documental imutavel por falta. Corrigir/suplementar
-- anexos no futuro exigira uma tabela de versoes, sem apagar este arquivo.
CREATE TABLE justificativa_falta (
    id_justificativa BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_frequencia INT NOT NULL UNIQUE REFERENCES registro_frequencia(id_frequencia),
    id_participante INT NOT NULL,
    motivo TEXT NOT NULL CHECK (btrim(motivo) <> ''),
    arquivo_url TEXT NOT NULL CHECK (btrim(arquivo_url) <> ''),
    registrado_em TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_usuario_autor INT NOT NULL,
    FOREIGN KEY (id_frequencia, id_participante)
        REFERENCES registro_frequencia(id_frequencia, id_participante),
    UNIQUE (id_justificativa, id_participante)
);

-- O arquivo_url acima e a primeira versao. Cada substituicao e uma nova
-- linha, com o motivo da troca. Nem a primeira versao nem as seguintes
-- recebem UPDATE/DELETE dos papeis operacionais.
CREATE TABLE justificativa_arquivo_versao (
    id_versao BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_justificativa BIGINT NOT NULL,
    id_participante INT NOT NULL,
    numero_versao INT NOT NULL CHECK (numero_versao >= 2),
    arquivo_url TEXT NOT NULL CHECK (btrim(arquivo_url) <> ''),
    motivo_substituicao TEXT NOT NULL CHECK (btrim(motivo_substituicao) <> ''),
    registrado_em TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_usuario_autor INT NOT NULL,
    FOREIGN KEY (id_justificativa, id_participante)
        REFERENCES justificativa_falta(id_justificativa, id_participante),
    UNIQUE (id_justificativa, numero_versao)
);

-- Uma chamada por participante em cada aula ou registro de evento.
CREATE UNIQUE INDEX uq_frequencia_aula ON registro_frequencia (id_participante, id_aula)
    WHERE id_aula IS NOT NULL;
CREATE UNIQUE INDEX uq_frequencia_evento ON registro_frequencia (id_participante, id_evento)
    WHERE id_evento IS NOT NULL;

-- Impede presenca em aula cancelada ou fora do periodo de inscricao.
CREATE OR REPLACE FUNCTION fn_validar_frequencia_aula()
RETURNS TRIGGER AS $$
DECLARE
    v_inicio TIMESTAMPTZ;
    v_cancelada BOOLEAN;
    v_inscricao TIMESTAMPTZ;
    v_desligamento DATE;
BEGIN
    IF NEW.id_aula IS NULL THEN RETURN NEW; END IF;
    SELECT inicio, cancelada INTO v_inicio, v_cancelada
    FROM aula WHERE id_aula = NEW.id_aula;
    SELECT data_inscricao, data_desligamento INTO v_inscricao, v_desligamento
    FROM inscricao_programa WHERE id_inscricao = NEW.id_inscricao;
    IF v_cancelada OR v_inicio < v_inscricao
       OR (v_desligamento IS NOT NULL AND v_inicio::date > v_desligamento) THEN
        RAISE EXCEPTION 'Aula cancelada ou fora do periodo de inscricao';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validar_frequencia_aula
BEFORE INSERT OR UPDATE OF id_aula, id_inscricao, id_programa, id_participante
ON registro_frequencia FOR EACH ROW
EXECUTE FUNCTION fn_validar_frequencia_aula();

-- =====================================================
-- 5. TABELAS DE FUNCIONÁRIOS E AUDITORIA
-- =====================================================

CREATE TABLE funcionarios (
    id_funcionario INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome_funcionario VARCHAR(150) NOT NULL,
    email VARCHAR(100) NOT NULL,
    CONSTRAINT ck_funcionario_email CHECK (btrim(email) <> '')
);

-- Normalizado (case/whitespace-insensitive), no mesmo padrão de
-- usuario_acesso.email: evita dois funcionarios com o "mesmo" email
-- em caixa diferente colidindo só na hora de criar a conta de acesso.
CREATE UNIQUE INDEX uq_funcionario_email ON funcionarios (lower(btrim(email)));

-- =====================================================
-- 6. AUTENTICAÇÃO E CONTROLE DE ACESSO
-- Autenticacao e verificacao de senha/hash ocorrem no backend.
-- A RLS protege as linhas e as permissoes SQL protegem as colunas.
-- 'Excluir aluna' significa inativar a INSCRICAO (data_desligamento),
-- preservando historico do Remama e OncoFit; nunca DELETE da participante.
-- Nenhum perfil deriva automaticamente de id_programa.
-- =====================================================

CREATE TABLE nivel_acesso (
    id_nivel_acesso INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome_nivel VARCHAR(30) NOT NULL UNIQUE
        CHECK (nome_nivel IN ('participante','gestao_1','gestao_2')),
    pode_acessar_gestao BOOLEAN NOT NULL,
    pode_inativar_aluna BOOLEAN NOT NULL,
    CHECK (NOT pode_inativar_aluna OR pode_acessar_gestao)
);

CREATE TABLE usuario_acesso (
    id_usuario INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email VARCHAR(150) NOT NULL CHECK (btrim(email) <> ''),
    senha_hash VARCHAR(255) NOT NULL CHECK (btrim(senha_hash) <> ''),
    id_nivel_acesso INT NOT NULL REFERENCES nivel_acesso(id_nivel_acesso),
    id_participante INT UNIQUE REFERENCES participante(id_participante),
    id_funcionario INT UNIQUE REFERENCES funcionarios(id_funcionario),
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ultimo_login TIMESTAMPTZ,
    CONSTRAINT ck_usuario_vinculo CHECK (
        (id_participante IS NOT NULL AND id_funcionario IS NULL)
        OR (id_participante IS NULL AND id_funcionario IS NOT NULL)
    )
);
CREATE UNIQUE INDEX uq_usuario_email ON usuario_acesso (lower(btrim(email)));

-- A conta da participante deve usar o perfil participante;
-- as contas da equipe devem usar gestao_1 ou gestao_2.
CREATE OR REPLACE FUNCTION fn_validar_tipo_usuario() RETURNS TRIGGER AS $$
DECLARE v_perfil VARCHAR(30);
BEGIN
    SELECT nome_nivel INTO v_perfil
    FROM nivel_acesso WHERE id_nivel_acesso = NEW.id_nivel_acesso;
    IF (NEW.id_participante IS NOT NULL) <> (v_perfil = 'participante') THEN
        RAISE EXCEPTION 'Nivel de acesso incompatível com participante/gestão';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_validar_tipo_usuario
BEFORE INSERT OR UPDATE OF id_nivel_acesso,id_participante,id_funcionario
ON usuario_acesso FOR EACH ROW EXECUTE FUNCTION fn_validar_tipo_usuario();

CREATE VIEW vw_poder_usuario WITH (security_invoker = true) AS
SELECT u.id_usuario, n.pode_acessar_gestao, n.pode_inativar_aluna
FROM usuario_acesso u
JOIN nivel_acesso n ON n.id_nivel_acesso = u.id_nivel_acesso
WHERE u.ativo = TRUE;

-- gestao_1: todos os dados e inativacao de inscricao de aluna.
-- gestao_2: todos os dados, sem inativacao de inscricao de aluna.
-- participante: somente os proprios dados (politicas RLS definidas abaixo).
-- A permissao exclusiva da gestao_1 e reforcada adiante por GRANT e trigger.

CREATE TABLE auditoria_sistema (
    id_audit BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    data_evento TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_usuario INT REFERENCES usuario_acesso(id_usuario),
    origem VARCHAR(20) NOT NULL DEFAULT 'SISTEMA'
        CHECK (origem IN ('USUARIO', 'SISTEMA', 'MIGRACAO')),
    tabela_afetada VARCHAR(50) NOT NULL,
    registro_id BIGINT NOT NULL,
    acao VARCHAR(10) NOT NULL CHECK (acao IN ('INSERT', 'UPDATE', 'DELETE')),
    dados_antigos JSONB,
    dados_novos JSONB,
    ip_origem VARCHAR(45),
    CHECK (origem <> 'USUARIO' OR id_usuario IS NOT NULL)
);

-- O autor e sempre uma conta autenticada. A aluna pode escrever anotacoes
-- proprias; as anotacoes profissionais sao internas.
CREATE TABLE observacao_clinica (
    id_observacao BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_participante INT NOT NULL REFERENCES participante(id_participante),
    id_usuario_autor INT NOT NULL REFERENCES usuario_acesso(id_usuario),
    observacao TEXT NOT NULL CHECK (btrim(observacao) <> ''),
    criado_em TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE ocorrencia (
    id_ocorrencia BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_participante INT NOT NULL REFERENCES participante(id_participante),
    id_usuario_autor INT NOT NULL REFERENCES usuario_acesso(id_usuario),
    titulo VARCHAR(150) NOT NULL CHECK (btrim(titulo) <> ''),
    ocorrencia TEXT NOT NULL CHECK (btrim(ocorrencia) <> ''),
    criado_em TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

ALTER TABLE atestado_medico ADD CONSTRAINT fk_atestado_autor
    FOREIGN KEY (id_usuario_autor) REFERENCES usuario_acesso(id_usuario);
ALTER TABLE justificativa_falta ADD CONSTRAINT fk_justificativa_autor
    FOREIGN KEY (id_usuario_autor) REFERENCES usuario_acesso(id_usuario);
ALTER TABLE justificativa_arquivo_versao ADD CONSTRAINT fk_versao_autor
    FOREIGN KEY (id_usuario_autor) REFERENCES usuario_acesso(id_usuario);

-- A tabela sozinha nao audita nada: triggers/aplicacao devem gravar eventos.
-- Nao criar auditoria automatica sem definir tabelas, usuario da sessao,
-- protecao dos dados clinicos e politica de retencao.

-- =====================================================
-- 7. DADOS DE REFERÊNCIA (SEED DE PADRONIZAÇÃO)
-- =====================================================

INSERT INTO status_participante (id_status, nome_status, situacao) VALUES
    (1, 'Ativa', TRUE),
    (2, 'Inativa', FALSE),
    (3, 'Afastada', FALSE),
    (4, 'Desligada', FALSE);

INSERT INTO estado_civil (descricao) VALUES
    ('Solteira'),
    ('Casada'),
    ('Divorciada'),
    ('Viúva'),
    ('União estável');

INSERT INTO programa (id_programa, nome_programa) VALUES
    (1, 'Remama'),
    (2, 'OncoFit');

INSERT INTO cargo_participante (id_cargo, nome_cargo) VALUES
    (1, 'Aluna'),
    (2, 'Gerente'),
    (3, 'Capitã'),
    (4, 'Dragonete');

INSERT INTO status_presenca (sigla, descricao) VALUES
    ('P', 'Presente'),
    ('F', 'Falta'),
    ('J', 'Justificada');

INSERT INTO nivel_acesso
    (nome_nivel,pode_acessar_gestao,pode_inativar_aluna) VALUES
    ('participante',FALSE,FALSE),
    ('gestao_1',TRUE,TRUE),
    ('gestao_2',TRUE,FALSE);

-- Radar de comorbidades e restricoes do mapa fornecido pelo cliente.
-- exige_descricao so e TRUE para a linha de texto livre: quem decide
-- daqui pra frente e esta coluna, nao o nome cadastrado abaixo.
INSERT INTO tipo_comorbidade (nome_comorbidade, exige_variacao, exige_descricao) VALUES
    ('Doenças Cardiovasculares', TRUE, FALSE),
    ('Hipertensão', TRUE, FALSE),
    ('Diabetes', TRUE, FALSE),
    ('Dislipidemia', FALSE, FALSE),
    ('Musculo-esqueléticas', TRUE, FALSE),
    ('Depressão', FALSE, FALSE),
    ('Ansiedade', FALSE, FALSE),
    ('Epilepsia', FALSE, FALSE),
    ('Anemia', FALSE, FALSE),
    ('Outras Comorbidades ou outras Dores', FALSE, TRUE);

INSERT INTO variacao_comorbidade (id_tipo_comorbidade, nome_variacao)
SELECT t.id_tipo_comorbidade, v.nome_variacao FROM (VALUES
    ('Doenças Cardiovasculares','AVC'),
    ('Doenças Cardiovasculares','DAC'),
    ('Doenças Cardiovasculares','DAP'),
    ('Doenças Cardiovasculares','IC'),
    ('Doenças Cardiovasculares','Arritmias e Valvopatias'),
    ('Hipertensão','Pré-Hipertensão'),
    ('Hipertensão','Grau 1'),
    ('Hipertensão','Grau 2'),
    ('Diabetes','Tipo 1'),
    ('Diabetes','Tipo 2'),
    ('Musculo-esqueléticas','Osteoporose'),
    ('Musculo-esqueléticas','Síndrome Patelofemural'),
    ('Musculo-esqueléticas','Cervicalgia'),
    ('Musculo-esqueléticas','Lombalgia'),
    ('Musculo-esqueléticas','Atralgia'),
    ('Musculo-esqueléticas','Fibromialgia'),
    ('Musculo-esqueléticas','Neuropatia')
) AS v(nome_tipo, nome_variacao)
JOIN tipo_comorbidade t ON t.nome_comorbidade = v.nome_tipo;

-- SUGESTÃO — confirmar lista definitiva com a administração do Remama
INSERT INTO tipo_treinamento (nome_treinamento) VALUES
    ('Remada em barco-dragão'),
    ('Treinamento funcional'),
    ('Alongamento e mobilidade'),
    ('Treino de força (OncoFit)'),
    ('Condicionamento aeróbico');

-- SUGESTÃO — confirmar lista definitiva com a administração/equipe clínica do Remama
INSERT INTO tipo_cancer (nome_cancer) VALUES
    ('Carcinoma ductal invasivo'),
    ('Carcinoma lobular invasivo'),
    ('Carcinoma ductal in situ'),
    ('Câncer de mama triplo negativo'),
    ('Outro');

-- =====================================================
-- 8. TRIGGER DE INTEGRIDADE
-- status_participante (global) <-> inscricao_programa.data_desligamento (por programa)
-- =====================================================

CREATE OR REPLACE FUNCTION fn_atualiza_status_participante()
RETURNS TRIGGER AS $$
DECLARE
    v_id_participante INT;
    v_tem_inscricao_ativa BOOLEAN;
    v_status_atual INT;
BEGIN
    v_id_participante := COALESCE(NEW.id_participante, OLD.id_participante);

    -- Trava a linha da participante primeiro: outra transacao alterando
    -- o status desta mesma pessoa (ex.: desligando Remama e OncoFit quase
    -- ao mesmo tempo) espera aqui, em vez de ler um snapshot desatualizado.
    -- Mesmo padrao ja usado em fn_numerar_versao_justificativa.
    PERFORM 1 FROM participante
    WHERE id_participante = v_id_participante FOR UPDATE;

    SELECT EXISTS (
        SELECT 1 FROM inscricao_programa
        WHERE id_participante = v_id_participante
          AND data_desligamento IS NULL
    ) INTO v_tem_inscricao_ativa;

    SELECT id_status INTO v_status_atual
    FROM participante WHERE id_participante = v_id_participante;

    IF v_tem_inscricao_ativa AND v_status_atual = 4 THEN
        -- tinha sido marcada Desligada, e agora tem inscrição ativa de novo
        UPDATE participante SET id_status = 1 WHERE id_participante = v_id_participante;

    ELSIF NOT v_tem_inscricao_ativa AND v_status_atual = 1 THEN
        -- estava Ativa, e agora não tem mais nenhuma inscrição ativa
        UPDATE participante SET id_status = 4 WHERE id_participante = v_id_participante;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public, pg_temp;

CREATE TRIGGER trg_atualiza_status_participante
AFTER INSERT OR UPDATE OF data_desligamento OR DELETE ON inscricao_programa
FOR EACH ROW
EXECUTE FUNCTION fn_atualiza_status_participante();

-- Em reingressos, uma inscricao encerrada permanece encerrada: criar nova linha.
-- O proprietario reservado para migracoes pode importar historicos antigos;
-- papeis operacionais seguem as restricoes abaixo.
CREATE OR REPLACE FUNCTION fn_proteger_historico_inscricao() RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.data_desligamento IS NOT NULL AND
           (current_user IN ('app_gestao_2','app_participante') OR
            (current_user = 'app_gestao_1' AND app_nivel_usuario() <> 'gestao_1')) THEN
            RAISE EXCEPTION 'Somente gestao_1 pode criar inscricao ja encerrada';
        END IF;
        RETURN NEW;
    END IF;
    IF TG_OP = 'UPDATE' THEN
        IF OLD.data_desligamento IS NOT NULL AND
           (NEW.data_desligamento IS DISTINCT FROM OLD.data_desligamento OR
            NEW.id_participante IS DISTINCT FROM OLD.id_participante OR
            NEW.id_programa IS DISTINCT FROM OLD.id_programa OR
            NEW.data_inscricao IS DISTINCT FROM OLD.data_inscricao) THEN
            RAISE EXCEPTION 'Inscricao encerrada e historica: crie nova inscricao para o retorno';
        END IF;
        IF OLD.data_desligamento IS NULL AND NEW.data_desligamento IS NOT NULL
           AND (current_user IN ('app_gestao_2','app_participante') OR
                (current_user = 'app_gestao_1' AND app_nivel_usuario() <> 'gestao_1')) THEN
            RAISE EXCEPTION 'Somente gestao_1 pode encerrar inscricoes';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- A funcao app_nivel_usuario e definida no bloco de seguranca abaixo.
CREATE TRIGGER trg_proteger_historico_inscricao
BEFORE INSERT OR UPDATE ON inscricao_programa FOR EACH ROW
EXECUTE FUNCTION fn_proteger_historico_inscricao();

-- Rastreabilidade por programa, inclusive datas distintas de inscricao.
CREATE VIEW vw_inscricoes_participante WITH (security_invoker = true) AS
SELECT p.id_participante,
       i.id_inscricao,
       i.id_programa,
       pr.nome_programa,
       i.data_inscricao,
       i.data_desligamento,
       (i.data_desligamento IS NULL) AS inscricao_ativa
FROM participante p
JOIN inscricao_programa i ON i.id_participante = p.id_participante
JOIN programa pr ON pr.id_programa = i.id_programa;

-- Agenda de aulas a publicar no frontend; acesso por perfil e inscricao
-- precisa ser autorizado na API/RLS antes de disponibilizar os dados.
CREATE VIEW vw_calendario_aulas WITH (security_invoker = true) AS
SELECT a.id_aula, a.id_programa, p.nome_programa,
       a.titulo, a.inicio, a.fim, a.local_aula, a.descricao
FROM aula a
JOIN programa p ON p.id_programa = a.id_programa
WHERE a.cancelada = FALSE;

-- Historico da presenca e do PSE por participante e programa.
-- Eventos sem programa definido nao entram nesta visao.
CREATE VIEW vw_frequencia_programa WITH (security_invoker = true) AS
SELECT f.id_frequencia, f.id_participante, f.id_inscricao,
       f.id_programa, p.nome_programa, f.id_aula,
       a.inicio AS inicio_aula, f.data_registro,
       s.sigla AS status_registrado,
       CASE WHEN a.cancelada THEN 'Aula cancelada' ELSE s.descricao END AS situacao_exibida,
       a.cancelada, a.motivo_cancelamento, a.cancelada_em,
       (NOT a.cancelada) AS conta_indicadores_presenca,
       f.pse, f.fc_antes, f.fc_depois
FROM registro_frequencia f
JOIN aula a ON a.id_aula = f.id_aula
JOIN programa p ON p.id_programa = f.id_programa
JOIN status_presenca s ON s.id_status_presenca = f.id_status_presenca;

-- Pesquisador: uma avaliacao por linha; peso/altura mais recentes na data
-- da avaliacao. Medidas antropometricas sao da pessoa, nao de um programa:
-- se houver duas inscricoes simultaneas, nao atribuir a medicao a apenas uma.
CREATE VIEW vw_pesquisador_evolucao WITH (security_invoker = true) AS
SELECT av.id_avaliacao, av.id_participante, i.id_inscricao,
       i.id_programa, pr.nome_programa, i.data_inscricao,
       i.data_desligamento, av.data_avaliacao, av.numero_avaliacao,
       av.ano, av.fc_repouso, av.pse, av.sentar_levantar_reps,
       av.mmss_ld_reps, av.mmss_le_reps,
       av.mmss_ld_dominante, av.mmss_le_dominante,
       av.marcha_passadas, av.classificacao_flexibilidade,
       av.amplitude_braco_cm, av.movimentacao_tronco,
       av.equilibrio, av.cond_aerobico, av.forca, av.obs_avaliacao,
       m.data_medicao, m.peso_kg, m.altura_m, m.cintura_cm, m.quadril_cm,
       ROUND(m.peso_kg / NULLIF(m.altura_m * m.altura_m, 0), 2) AS imc
FROM avaliacao av
JOIN inscricao_programa i ON i.id_inscricao = av.id_inscricao
  AND i.id_participante = av.id_participante
JOIN programa pr ON pr.id_programa = i.id_programa
LEFT JOIN LATERAL (
    SELECT d.data_medicao, d.peso_kg, d.altura_m, d.cintura_cm, d.quadril_cm
    FROM dados_antropometricos d
    WHERE d.id_participante = av.id_participante
      AND d.data_medicao <= av.data_avaliacao
    ORDER BY d.data_medicao DESC, d.id_antropometrico DESC LIMIT 1
) m ON TRUE;

-- Professor: chamadas e presencas por aula; as chamadas de uma aula
-- cancelada continuam visiveis como historico, mas nao somam rendimento.
CREATE VIEW vw_professor_aulas WITH (security_invoker = true) AS
SELECT a.id_aula, a.id_programa, pr.nome_programa,
       a.titulo, a.inicio, a.fim, a.cancelada,
       a.motivo_cancelamento, a.cancelada_em,
       COUNT(f.id_frequencia) AS chamadas_registradas,
       COUNT(f.id_frequencia) FILTER (WHERE NOT a.cancelada AND sp.sigla = 'P') AS presentes_validos,
       COUNT(f.id_frequencia) FILTER (WHERE NOT a.cancelada AND sp.sigla = 'F') AS faltas_validas,
       COUNT(f.id_frequencia) FILTER (WHERE NOT a.cancelada AND sp.sigla = 'J') AS justificadas_validas
FROM aula a
JOIN programa pr ON pr.id_programa = a.id_programa
LEFT JOIN registro_frequencia f ON f.id_aula = a.id_aula
LEFT JOIN status_presenca sp ON sp.id_status_presenca = f.id_status_presenca
GROUP BY a.id_aula, pr.nome_programa;

-- A aluna consulta somente suas inscricoes e avaliacoes devido ao RLS das
-- tabelas de origem; nao expoe observacoes internas nem dados de outra aluna.
CREATE VIEW vw_participante_acompanhamento WITH (security_invoker = true) AS
SELECT i.id_participante, i.id_inscricao, i.id_programa,
       pr.nome_programa, i.data_inscricao, i.data_desligamento,
       av.id_avaliacao, av.numero_avaliacao, av.data_avaliacao,
       av.fc_repouso, av.pse, av.obs_avaliacao,
       av.sentar_levantar_reps, av.mmss_ld_reps, av.mmss_le_reps,
       av.marcha_passadas, av.classificacao_flexibilidade
FROM inscricao_programa i
JOIN programa pr ON pr.id_programa = i.id_programa
LEFT JOIN avaliacao av ON av.id_inscricao = i.id_inscricao
  AND av.id_participante = i.id_participante;

-- =====================================================
-- 9. REGRAS DE REGISTRO CLINICO E JUSTIFICATIVAS
-- =====================================================

CREATE OR REPLACE FUNCTION fn_validar_comorbidade() RETURNS TRIGGER AS $$
DECLARE v_nome TEXT; v_exige_variacao BOOLEAN; v_exige_descricao BOOLEAN;
BEGIN
    SELECT nome_comorbidade, exige_variacao, exige_descricao
    INTO v_nome, v_exige_variacao, v_exige_descricao
    FROM tipo_comorbidade WHERE id_tipo_comorbidade = NEW.id_tipo_comorbidade;
    IF v_exige_variacao AND NEW.id_variacao IS NULL THEN
        RAISE EXCEPTION 'Selecione a variacao de %', v_nome;
    END IF;
    IF NOT v_exige_variacao AND NEW.id_variacao IS NOT NULL THEN
        RAISE EXCEPTION 'Este tipo nao possui variacoes';
    END IF;
    -- exige_descricao substitui a antiga comparacao por nome fixo:
    -- renomear o cadastro nao desliga mais a regra por acidente.
    IF v_exige_descricao AND NULLIF(btrim(NEW.descricao_outras), '') IS NULL THEN
        RAISE EXCEPTION 'Descreva a outra comorbidade ou dor';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_validar_comorbidade BEFORE INSERT OR UPDATE ON comorbidade
FOR EACH ROW EXECUTE FUNCTION fn_validar_comorbidade();

-- O arquivo de falta justificada e obrigatorio. A chamada passa de F para J
-- na mesma transacao em que a justificativa e gravada.
CREATE OR REPLACE FUNCTION fn_validar_justificativa_falta() RETURNS TRIGGER AS $$
DECLARE v_sigla CHAR(1);
BEGIN
    PERFORM 1 FROM registro_frequencia WHERE id_frequencia = NEW.id_frequencia FOR UPDATE;
    SELECT s.sigla INTO v_sigla
    FROM registro_frequencia f JOIN status_presenca s
      ON s.id_status_presenca = f.id_status_presenca
    WHERE f.id_frequencia = NEW.id_frequencia;
    IF v_sigla <> 'F' THEN
        RAISE EXCEPTION 'A justificativa so pode ser anexada a uma falta';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public, pg_temp;
CREATE TRIGGER trg_validar_justificativa_falta
BEFORE INSERT ON justificativa_falta FOR EACH ROW
EXECUTE FUNCTION fn_validar_justificativa_falta();

CREATE OR REPLACE FUNCTION fn_marcar_falta_justificada() RETURNS TRIGGER AS $$
BEGIN
    UPDATE registro_frequencia
    SET id_status_presenca = (SELECT id_status_presenca FROM status_presenca WHERE sigla = 'J')
    WHERE id_frequencia = NEW.id_frequencia
      AND id_status_presenca = (SELECT id_status_presenca FROM status_presenca WHERE sigla = 'F');
    IF NOT FOUND THEN RAISE EXCEPTION 'A falta foi alterada durante o anexo'; END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public, pg_temp;
CREATE TRIGGER trg_marcar_falta_justificada
AFTER INSERT ON justificativa_falta FOR EACH ROW
EXECUTE FUNCTION fn_marcar_falta_justificada();

CREATE OR REPLACE FUNCTION fn_conferir_status_justificativa() RETURNS TRIGGER AS $$
DECLARE v_sigla CHAR(1); v_existe BOOLEAN;
BEGIN
    SELECT sigla INTO v_sigla FROM status_presenca
    WHERE id_status_presenca = NEW.id_status_presenca;
    SELECT EXISTS (SELECT 1 FROM justificativa_falta
                   WHERE id_frequencia = NEW.id_frequencia) INTO v_existe;
    IF (v_sigla = 'J') IS DISTINCT FROM v_existe THEN
        RAISE EXCEPTION 'Status J requer documento; comprovante vinculado requer status J';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_conferir_status_justificativa
BEFORE INSERT OR UPDATE OF id_status_presenca ON registro_frequencia
FOR EACH ROW EXECUTE FUNCTION fn_conferir_status_justificativa();

-- =====================================================
-- 10. RLS: backend deve usar papeis NAO proprietarios/sem BYPASSRLS.
-- Executar DDL como proprietario separado dos logins de aplicacao.
-- A aplicacao autentica id_usuario e faz BEGIN; SET LOCAL app.id_usuario;
-- ... consultas ...; COMMIT. Nunca aceitar SQL livre do usuario final.
-- Cada login de backend deve ter somente UM papel correspondente ao nivel;
-- conceder esses papeis a logins segregados em provisionamento externo.
-- Exemplo operacional (NAO executar sem criar os logins segregados):
-- BEGIN;
-- SET LOCAL ROLE app_participante; -- ou app_gestao_1 / app_gestao_2
-- SELECT set_config('app.id_usuario', :id_usuario_validado_pela_api, true);
-- ... consultas e alteracoes ...;
-- COMMIT;
-- Nao usar login proprietario das tabelas, BYPASSRLS nem um unico login
-- membro de ambos os papeis de gestao. Nunca confiar em id enviado pelo cliente.
-- =====================================================

-- Impede que papeis operacionais criem objetos no schema consultado por
-- funcoes privilegiadas (relevante tambem em instalacoes PostgreSQL 14).
REVOKE CREATE ON SCHEMA public FROM PUBLIC;

DO $$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='app_participante') THEN
        CREATE ROLE app_participante NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='app_gestao_1') THEN
        CREATE ROLE app_gestao_1 NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='app_gestao_2') THEN
        CREATE ROLE app_gestao_2 NOLOGIN;
    END IF;
END $$;

CREATE OR REPLACE FUNCTION app_usuario_id() RETURNS INT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, public, pg_temp AS $$
    SELECT u.id_usuario FROM public.usuario_acesso u
    WHERE u.id_usuario = NULLIF(current_setting('app.id_usuario', true), '')::INT
      AND u.ativo = TRUE
$$;
CREATE OR REPLACE FUNCTION app_nivel_usuario() RETURNS TEXT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, public, pg_temp AS $$
    SELECT n.nome_nivel::TEXT FROM public.usuario_acesso u
    JOIN public.nivel_acesso n ON n.id_nivel_acesso = u.id_nivel_acesso
    WHERE u.id_usuario = NULLIF(current_setting('app.id_usuario', true), '')::INT
      AND u.ativo = TRUE
$$;
CREATE OR REPLACE FUNCTION app_participante_id() RETURNS INT
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, public, pg_temp AS $$
    SELECT u.id_participante FROM public.usuario_acesso u
    JOIN public.nivel_acesso n ON n.id_nivel_acesso = u.id_nivel_acesso
    WHERE u.id_usuario = NULLIF(current_setting('app.id_usuario', true), '')::INT
      AND u.ativo = TRUE AND n.nome_nivel = 'participante'
$$;
REVOKE ALL ON FUNCTION app_usuario_id(), app_nivel_usuario(), app_participante_id() FROM PUBLIC;
GRANT EXECUTE ON FUNCTION app_usuario_id(), app_nivel_usuario(), app_participante_id()
TO app_participante, app_gestao_1, app_gestao_2;

-- Nenhuma conta de aplicacao pode ser proprietaria do schema/tabelas nem ter
-- BYPASSRLS. Todas as views acessiveis usam security_invoker (PG 15+) para
-- submeter suas tabelas de origem aos GRANTs e ao RLS do perfil invocador.
GRANT USAGE ON SCHEMA public TO app_participante, app_gestao_1, app_gestao_2;

-- Somente dados de referencia nao pessoais.
GRANT SELECT ON status_participante, estado_civil, programa,
    tipo_comorbidade, variacao_comorbidade, tipo_treinamento,
    status_presenca, cargo_participante, tipo_cancer
TO app_participante, app_gestao_1, app_gestao_2;

-- Permissoes operacionais da equipe; DELETE fisico e TRUNCATE nao concedidos.
GRANT SELECT, INSERT ON participante TO app_gestao_1, app_gestao_2;
-- Status geral so e atualizado pela trigger privilegiada de inscricao.
GRANT UPDATE (cpf, numero_carteirinha, nome_completo, nome_social,
    data_nascimento, sexo, id_estado_civil, possui_filhos, quantidade_filhos,
    profissao, trabalha_atualmente, renda_familiar_faixa, foto_url,
    observacoes) ON participante TO app_gestao_1, app_gestao_2;
GRANT SELECT, INSERT, UPDATE ON endereco, contato,
    dados_antropometricos, avaliacao, ficha_medica, comorbidade,
    treinamento, evento, aula, registro_frequencia
TO app_gestao_1, app_gestao_2;
GRANT SELECT, INSERT ON observacao_clinica, ocorrencia,
    atestado_medico, justificativa_falta, justificativa_arquivo_versao
TO app_gestao_1, app_gestao_2;
GRANT SELECT, INSERT ON inscricao_programa TO app_gestao_1, app_gestao_2;
GRANT UPDATE (id_cargo, turma, especializacao_leme, especializacao_tambor)
ON inscricao_programa TO app_gestao_1, app_gestao_2;
GRANT UPDATE (data_desligamento) ON inscricao_programa TO app_gestao_1;
GRANT SELECT (id_usuario, email, id_nivel_acesso, id_participante,
    id_funcionario, ativo, criado_em, ultimo_login)
ON usuario_acesso TO app_gestao_1, app_gestao_2;
GRANT SELECT ON funcionarios TO app_gestao_1, app_gestao_2;
GRANT SELECT ON auditoria_sistema TO app_gestao_1, app_gestao_2;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO app_gestao_1, app_gestao_2;

-- A aluna recebe colunas de cadastro sem observacoes gerais internas;
-- as observacoes clinicas da equipe ficam ocultas por RLS especifica.
GRANT SELECT (id_participante, cpf, numero_carteirinha, id_status,
    data_inscricao, nome_completo, nome_social, data_nascimento, sexo,
    id_estado_civil, possui_filhos, quantidade_filhos, profissao,
    trabalha_atualmente, renda_familiar_faixa, foto_url)
ON participante TO app_participante;
GRANT SELECT ON endereco, contato, dados_antropometricos, avaliacao,
    ficha_medica, comorbidade, treinamento, evento, inscricao_programa,
    aula, registro_frequencia, observacao_clinica, ocorrencia,
    atestado_medico, justificativa_falta, justificativa_arquivo_versao
TO app_participante;
GRANT INSERT ON observacao_clinica, ocorrencia, justificativa_falta,
    justificativa_arquivo_versao
TO app_participante;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO app_participante;

GRANT SELECT ON vw_inscricoes_participante, vw_calendario_aulas,
    vw_frequencia_programa, vw_participante_acompanhamento
TO app_participante;
GRANT SELECT ON vw_poder_usuario, vw_inscricoes_participante,
    vw_calendario_aulas, vw_frequencia_programa,
    vw_pesquisador_evolucao, vw_professor_aulas,
    vw_participante_acompanhamento
TO app_gestao_1, app_gestao_2;

-- Pessoais: isolamento de linha para participante; equipe atua apenas
-- quando o nivel autenticado coincide com o papel SQL da conexao.
DO $$
DECLARE v_tabela TEXT;
BEGIN
    FOREACH v_tabela IN ARRAY ARRAY[
        'participante','endereco','contato','dados_antropometricos',
        'avaliacao','ficha_medica','comorbidade','atestado_medico',
        'treinamento','evento','inscricao_programa','registro_frequencia',
        'justificativa_falta','observacao_clinica','ocorrencia',
        'justificativa_arquivo_versao'
    ] LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', v_tabela);
        EXECUTE format(
            'CREATE POLICY %I ON %I FOR SELECT TO app_participante '
            || 'USING (id_participante = app_participante_id())',
            'aluna_ler_' || v_tabela, v_tabela);
        EXECUTE format(
            'CREATE POLICY %I ON %I FOR ALL TO app_gestao_1, app_gestao_2 '
            || 'USING ((current_user = ''app_gestao_1'' AND app_nivel_usuario() = ''gestao_1'') '
            || 'OR (current_user = ''app_gestao_2'' AND app_nivel_usuario() = ''gestao_2'')) '
            || 'WITH CHECK ((current_user = ''app_gestao_1'' AND app_nivel_usuario() = ''gestao_1'') '
            || 'OR (current_user = ''app_gestao_2'' AND app_nivel_usuario() = ''gestao_2''))',
            'equipe_' || v_tabela, v_tabela);
    END LOOP;
END $$;

-- Selecao de notas da aluna: apenas as que ela propria escreveu.
DROP POLICY aluna_ler_observacao_clinica ON observacao_clinica;
CREATE POLICY aluna_ler_observacao_clinica ON observacao_clinica
FOR SELECT TO app_participante
USING (id_participante = app_participante_id()
       AND id_usuario_autor = app_usuario_id());
DROP POLICY aluna_ler_ocorrencia ON ocorrencia;
CREATE POLICY aluna_ler_ocorrencia ON ocorrencia
FOR SELECT TO app_participante
USING (id_participante = app_participante_id()
       AND id_usuario_autor = app_usuario_id());

-- A aluna cria somente suas notas e ocorrencias; nao edita nem apaga.
CREATE POLICY aluna_criar_observacao ON observacao_clinica
FOR INSERT TO app_participante
WITH CHECK (id_participante = app_participante_id()
            AND id_usuario_autor = app_usuario_id());
CREATE POLICY aluna_criar_ocorrencia ON ocorrencia
FOR INSERT TO app_participante
WITH CHECK (id_participante = app_participante_id()
            AND id_usuario_autor = app_usuario_id());
CREATE POLICY aluna_enviar_justificativa ON justificativa_falta
FOR INSERT TO app_participante
WITH CHECK (id_participante = app_participante_id()
            AND id_usuario_autor = app_usuario_id());
CREATE POLICY aluna_enviar_versao ON justificativa_arquivo_versao
FOR INSERT TO app_participante
WITH CHECK (id_participante = app_participante_id()
            AND id_usuario_autor = app_usuario_id());

-- Agenda da aluna: aulas somente dos programas com inscricao em aberto.
ALTER TABLE aula ENABLE ROW LEVEL SECURITY;
CREATE POLICY aluna_aula ON aula FOR SELECT TO app_participante
USING (EXISTS (
    SELECT 1 FROM inscricao_programa i
    WHERE i.id_programa = aula.id_programa
      AND i.id_participante = app_participante_id()
      AND i.data_desligamento IS NULL
) AND cancelada = FALSE
OR (cancelada = TRUE AND EXISTS (
    SELECT 1 FROM registro_frequencia f
    WHERE f.id_aula = aula.id_aula
      AND f.id_participante = app_participante_id()
)));
CREATE POLICY equipe_aula ON aula FOR ALL TO app_gestao_1, app_gestao_2
USING ((current_user='app_gestao_1' AND app_nivel_usuario()='gestao_1')
       OR (current_user='app_gestao_2' AND app_nivel_usuario()='gestao_2'))
WITH CHECK ((current_user='app_gestao_1' AND app_nivel_usuario()='gestao_1')
       OR (current_user='app_gestao_2' AND app_nivel_usuario()='gestao_2'));

-- Usuario e perfil nao podem ser alterados por gestores para promover a si
-- mesmos. Provisionamento de contas utiliza processo administrativo separado.
ALTER TABLE usuario_acesso ENABLE ROW LEVEL SECURITY;
ALTER TABLE funcionarios ENABLE ROW LEVEL SECURITY;
CREATE POLICY equipe_usuarios ON usuario_acesso FOR SELECT
TO app_gestao_1, app_gestao_2
USING ((current_user='app_gestao_1' AND app_nivel_usuario()='gestao_1')
       OR (current_user='app_gestao_2' AND app_nivel_usuario()='gestao_2'));
CREATE POLICY equipe_funcionarios ON funcionarios FOR SELECT
TO app_gestao_1, app_gestao_2
USING ((current_user='app_gestao_1' AND app_nivel_usuario()='gestao_1')
       OR (current_user='app_gestao_2' AND app_nivel_usuario()='gestao_2'));

-- Registro explicito do autor; protege contra enviar id_usuario alheio.
CREATE OR REPLACE FUNCTION fn_definir_autor() RETURNS TRIGGER AS $$
BEGIN
    IF app_usuario_id() IS NULL THEN
        RAISE EXCEPTION 'Usuario autenticado obrigatorio';
    END IF;
    NEW.id_usuario_autor := app_usuario_id();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_autor_observacao BEFORE INSERT ON observacao_clinica
FOR EACH ROW EXECUTE FUNCTION fn_definir_autor();
CREATE TRIGGER trg_autor_ocorrencia BEFORE INSERT ON ocorrencia
FOR EACH ROW EXECUTE FUNCTION fn_definir_autor();
CREATE TRIGGER trg_autor_atestado BEFORE INSERT ON atestado_medico
FOR EACH ROW EXECUTE FUNCTION fn_definir_autor();
CREATE TRIGGER trg_autor_justificativa BEFORE INSERT ON justificativa_falta
FOR EACH ROW EXECUTE FUNCTION fn_definir_autor();
CREATE TRIGGER trg_autor_versao BEFORE INSERT ON justificativa_arquivo_versao
FOR EACH ROW EXECUTE FUNCTION fn_definir_autor();

CREATE OR REPLACE FUNCTION fn_numerar_versao_justificativa() RETURNS TRIGGER AS $$
BEGIN
    -- Serializa novas versoes da mesma justificativa e nao confia na numeracao
    -- enviada pelo frontend.
    PERFORM 1 FROM justificativa_falta
    WHERE id_justificativa = NEW.id_justificativa
      AND id_participante = NEW.id_participante FOR UPDATE;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Justificativa nao encontrada para esta participante';
    END IF;
    SELECT COALESCE(MAX(numero_versao), 1) + 1 INTO NEW.numero_versao
    FROM justificativa_arquivo_versao
    WHERE id_justificativa = NEW.id_justificativa;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public, pg_temp;
REVOKE ALL ON FUNCTION fn_numerar_versao_justificativa() FROM PUBLIC;
CREATE TRIGGER trg_numerar_versao_justificativa
BEFORE INSERT ON justificativa_arquivo_versao FOR EACH ROW
EXECUTE FUNCTION fn_numerar_versao_justificativa();

-- Auditoria automatica em todas as tabelas de negocio e catalogos, exceto
-- na propria auditoria para impedir recursao. Nunca copia o hash de senha.
-- Escrita feita por funcao privilegiada; papeis da aplicacao so leem o log.
CREATE OR REPLACE FUNCTION fn_auditar_alteracao() RETURNS TRIGGER AS $$
DECLARE
    v_antes JSONB;
    v_depois JSONB;
    v_linha JSONB;
    v_usuario INT;
    v_origem VARCHAR(20);
BEGIN
    IF TG_OP <> 'INSERT' THEN v_antes := to_jsonb(OLD) - 'senha_hash'; END IF;
    IF TG_OP <> 'DELETE' THEN v_depois := to_jsonb(NEW) - 'senha_hash'; END IF;
    IF TG_OP = 'UPDATE' AND v_antes = v_depois THEN RETURN NULL; END IF;

    v_linha := COALESCE(v_depois, v_antes);
    v_usuario := public.app_usuario_id();
    v_origem := CASE WHEN v_usuario IS NOT NULL THEN 'USUARIO'
                     WHEN current_setting('app.origem_auditoria', true) = 'MIGRACAO'
                          THEN 'MIGRACAO' ELSE 'SISTEMA' END;
    INSERT INTO public.auditoria_sistema
        (id_usuario, origem, tabela_afetada, registro_id, acao,
         dados_antigos, dados_novos, ip_origem)
    VALUES (v_usuario, v_origem, TG_TABLE_NAME,
            (v_linha ->> TG_ARGV[0])::BIGINT, TG_OP,
            v_antes, v_depois, inet_client_addr()::TEXT);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public, pg_temp;
REVOKE ALL ON FUNCTION fn_auditar_alteracao() FROM PUBLIC;

DO $$
DECLARE v_tabela RECORD;
BEGIN
    FOR v_tabela IN
        SELECT c.relname AS nome, a.attname AS chave
        FROM pg_catalog.pg_class c
        JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
        JOIN pg_catalog.pg_index i ON i.indrelid = c.oid AND i.indisprimary
        JOIN pg_catalog.pg_attribute a ON a.attrelid = c.oid
             AND a.attnum = i.indkey[0]
        WHERE n.nspname = 'public' AND c.relkind = 'r'
          AND c.relname <> 'auditoria_sistema'
    LOOP
        EXECUTE format('CREATE TRIGGER %I AFTER INSERT OR UPDATE OR DELETE ON public.%I '
                       || 'FOR EACH ROW EXECUTE FUNCTION public.fn_auditar_alteracao(%L)',
                       'trg_auditar_' || v_tabela.nome, v_tabela.nome, v_tabela.chave);
    END LOOP;
END $$;

-- Sem politica de DELETE, e sem GRANT de DELETE/TRUNCATE ao backend.
-- O proprietario do schema deve ser reservado a migracoes controladas.
