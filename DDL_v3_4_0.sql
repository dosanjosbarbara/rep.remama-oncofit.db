-- =====================================================
-- BANCO DE DADOS REMAMA / ONcoFITT - PostgreSQL - DDL V3.4.0
-- Estrutura, integridade e politicas de acesso. Executar em banco novo.
-- Requer PostgreSQL 15+ para views SECURITY_INVOKER.
-- Baseline aplicada: status global independente das inscricoes por programa.
-- O backend autentica o usuario e configura app.id_usuario por transacao.
--
-- V3.2 = V3.1 + harmonizacao com a Especificacao Consolidada MVP2 (v2.4).
-- CORRECOES DE ERROS DA V3.1
--   * status_presenca: descricao VARCHAR(20) rejeitava o seed 'Compareceu sem
--     participacao' (27 caracteres) e sigla CHAR(1) nao comporta 'CSP'.
--   * nivel_acesso sem GRANT SELECT: vw_poder_usuario falhava para os papeis.
--   * Seeds: 'Atralgia' -> 'Artralgia'; 'IC' -> 'Insuficiencia Cardiaca';
--     programas padronizados como REMAMA e ONcoFITT.
--   * RLS: removido o par CREATE/DROP POLICY de observacao_clinica/ocorrencia.
-- ITENS QUE O MD DECLARAVA NA V3.1 E NAO EXISTIAM NO SCRIPT
--   * participante.possui_alergia (+ descricao_alergia) e medicamentos.
--   * Cargo Voga (id 5); cargo base 'Aluna / Remadora'.
--   * 4 estados P/F/J/CSP + pre_registro (PRE) em status_presenca.
-- REGRAS DO MD IMPLEMENTADAS
--   RF04/RN09  ficha_medica: datas de termino (cirurgia/quimio/radio),
--              hormonioterapia, radioterapia em manutencao.
--   RF05       tabela sintoma (linfedema e neuropatia/dormencia).
--   RF06       atestado_medico com status_validacao (so gestao_1);
--              justificativa texto OU anexo OU ambos, com deferimento (so
--              gestao_1) e conversao F->J somente no deferimento.
--   RF03/RN08  contato com parentesco obrigatorio; ativacao (id_status=1)
--              exige contato, atestado vigente e inscricao ativa.
--   RF08/RN11  pre_registro (aluna), chamada P/F/CSP exclusiva do professor
--              (gestao_2), PSE ONcoFITT pelo professor ou pela aluna (24h),
--              PA pre/pos opcional (ck_frequencia_pa), ck_frequencia_fc.
--   RN02       atestado aprovado e com ate 180 dias bloqueia presenca (P) e
--              pre_registro; fn_participante_apto / vw_participante_apto.
--   RN05       ONcoFITT: 101a presenca confirmada bloqueada.
--   RN01       vw_assiduidade_programa (formula com deducao de J e CSP).
--   RN12       maximo de 1 Capita ativa por barco (ver V3.3: tabela barco).
--   RN13       aula.tipo_aula (raia / indoor / online).
--   RN10/2.2   CID-O e lateralidade so alteraveis por gestao_1; cancelar
--              aula so gestao_1; auto-edicao da aluna (ALT-01 a ALT-03).
--
-- V3.3 = V3.2 + decisoes da coordenacao + correcoes da validacao em PostgreSQL 16
-- DECISOES (V3.3)
--   RF07   status global AUTOMATICO (MD): 2->1 quando ha contato de emergencia,
--          atestado aprovado/vigente e inscricao ativa; 1->4 quando a ultima
--          inscricao ativa e encerrada; 4->1 em novo ingresso (retorno).
--          3 (Afastada) e sempre manual (gestao_1). Atestado vencido NAO
--          desativa (RN02: matricula ativa com apto_pratica = false).
--   RN12   nova tabela barco + inscricao_programa.id_barco; 1 Capita ativa por
--          BARCO. turma continua sendo a turma-horario (08h, 09h...).
--   RF06   deferir/indeferir justificativa: gestao_1 OU gestao_2. [REVERTIDO EM V3.4.0]
--   RF08   aula.link_aula (Meet/Zoom) inserido pelo professor; a aluna so
--          obtem o link por fn_link_aula() (aula em andamento, atestado
--          vigente, pre_registro feito). A coluna nao e legivel pela aluna.
--   RF01   usuario_acesso.auth_user_id (Supabase Auth); senha_hash passa a ser
--          opcional quando a credencial vive no Supabase Auth.
-- CORRECOES (achadas nos testes da V3.2)
--   * gestao_1 nao conseguia preencher data_documento ao aprovar atestado
--     enviado sem data (aprovacao falhava em ck_atestado_aprovado_data).
--   * data_documento futura era aceita; agora e rejeitada.
--   * UPDATE de id_aula/id_participante em registro_frequencia contornava o
--     limite de 100 presencas e a trava de atestado; agora gestao_1/gestao_2
--     so atualizam status, FC, PA e PSE (GRANT por coluna).
--
-- V3.3.1 = V3.3 + grau de linfedema corrigido para 1-4 (RF05) [REVERTIDO EM V3.4.0]
--
-- V3.4.0 = V3.3.1 + correcoes da validacao QA (Sprint 02, 22/10/2026)
-- CORRECOES DE REGRA (itens reprovados nos testes 15, 23, 24, 25 e na
--   compatibilidade com as telas dos Grupos 4 e 5 — encaminhamento Grupo 1,
--   21/10/2026):
--
--   RF06 / teste 15  deferimento de justificativa exclusivo da gestao_1
--                    (reverte decisao V3.3 que tambem liberava gestao_2);
--                    GRANT e trigger atualizados.
--
--   RF05 / teste 23  grau de linfedema corrigido para 1 a 3 (escala oficial
--                    Leve/Moderado/Grave); reverte alteracao da V3.3.1 que
--                    ampliava para 1-4.
--
--   RN02 / teste 24  trava de atestado vencido estendida a evento: presenca
--                    (sigla P) em evento agora tambem exige atestado vigente,
--                    igual ao comportamento em aula (fn_validar_frequencia_status).
--
--   RF02 / teste 25  nome_completo da participante tornado NOT NULL; era
--                    opcional e permitia cadastrar aluna sem nome.
--
--   Compatibilidade com telas (item 2.5 do relatorio de validacao):
--     atestado_medico     + motivo_recusa TEXT          (L03 — texto de recusa)
--     justificativa_falta + motivo_indeferimento TEXT   (L04 — motivo obrigatorio ao indeferir)
--                         + observacao_deferimento TEXT (L04 — observacao opcional ao deferir)
--     ficha_medica        + realizou_cirurgia BOOLEAN
--                         + realizou_quimioterapia BOOLEAN
--                         + realizou_radioterapia BOOLEAN
--                         + data_inicio_hormonioterapia DATE
--                         + data_fim_hormonioterapia DATE
--                         + data_laudo DATE
--                         + observacao_diagnostico TEXT
--                         + observacao_recidiva TEXT
--     avaliacao           amplitude_braco_cm renomeado para flexibilidade_ombros_cm
--                         + flexibilidade_tronco_cm DECIMAL(5,2)
--                         classificacao_flexibilidade, movimentacao_tronco,
--                         equilibrio, cond_aerobico e forca removidos (Grupo 5
--                         calcula faixas 1-5 sobre resultados brutos; encaminhamento
--                         21/10/2026).
--
--   Pontos de atencao (item 2.6 — permanecem como pendencia para o Grupo 2):
--     tabela evento, tratamentos_realizados e campo senha_hash nao alterados
--     aqui: aguardam definicao de uso pelos grupos ate a revalidacao.
--
-- RECOMENDACAO OPERACIONAL: ALTER DATABASE <db> SET timezone TO
--   'America/Sao_Paulo' (vigencia de 180 dias e janela da aula usam datas).
-- Fora do banco (backend/UI): senha de ADM (RN10), mascara LGPD, RN03, RN04,
-- RN07, RF11, RF14, fluxo de recuperacao de senha (RF01, via Supabase Auth).
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
    sigla VARCHAR(5) NOT NULL UNIQUE,
    descricao VARCHAR(40) NOT NULL
);

-- 1 = Aluna / Remadora / 2 = Gerente / 3 = Capita / 4 = Dragonete / 5 = Voga
-- (o indice uq_capita_por_barco depende do id 3 = Capita)
CREATE TABLE cargo_participante (
    id_cargo INT PRIMARY KEY,
    nome_cargo VARCHAR(30) NOT NULL
);

CREATE TABLE tipo_cancer (
    id_tipo_cancer INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome_cancer VARCHAR(100) NOT NULL,
    cid_o VARCHAR(10)  -- opcional: código CID-O, se a Remama quiser rastreabilidade clínica
);

-- V3.3 (RN12): embarcacao do REMAMA. turma = turma-horario; barco = guarnicao.
-- Uma turma pode usar varios barcos (diretriz de 20 remadoras por barco, sem hard-block).
CREATE TABLE barco (
    id_barco INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nome_barco VARCHAR(50) NOT NULL CHECK (btrim(nome_barco) <> ''),
    ativo BOOLEAN NOT NULL DEFAULT TRUE
);
CREATE UNIQUE INDEX uq_barco_nome ON barco (lower(btrim(nome_barco)));

-- =====================================================
-- 2. TABELA PRINCIPAL (participante)
-- =====================================================

CREATE TABLE participante (
    id_participante INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cpf CHAR(11) UNIQUE NOT NULL,
    numero_carteirinha VARCHAR(20) UNIQUE,
    id_status INT NOT NULL DEFAULT 2 REFERENCES status_participante(id_status),
    data_inscricao TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP,
    nome_completo VARCHAR(150) NOT NULL,  -- RF02 (v3.4.0): obrigatorio no cadastro
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
    observacoes TEXT,
    -- RF03/RN08: alergia declarada no cadastro; descricao obrigatoria se TRUE.
    possui_alergia BOOLEAN NOT NULL DEFAULT FALSE,
    descricao_alergia TEXT,
    -- RF05: medicamentos de uso continuo (Card de Emergencia).
    medicamentos TEXT,
    CONSTRAINT ck_alergia_descricao CHECK
        (NOT possui_alergia OR NULLIF(btrim(descricao_alergia), '') IS NOT NULL)
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
    contato_emergencia_parentesco VARCHAR(30) NOT NULL
        CHECK (btrim(contato_emergencia_parentesco) <> '')  -- RF03/RN08
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
    -- v3.4.0 (item 2.5 #9 / RF09): testes de flexibilidade em cm, padronizados.
    --   flexibilidade_ombros_cm = Apley / alcance atras das costas (era amplitude_braco_cm).
    --   flexibilidade_tronco_cm = Sentar e alcançar.
    -- Classificacoes textuais (classificacao_flexibilidade, movimentacao_tronco,
    -- equilibrio, cond_aerobico, forca) removidas: faixas 1-5 calculadas pelo
    -- Grupo 5 sobre os resultados brutos (encaminhamento Grupo 1, 21/10/2026).
    flexibilidade_ombros_cm DECIMAL(5,2),
    flexibilidade_tronco_cm DECIMAL(5,2),
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
    tratamentos_realizados TEXT,
    -- RF04/RN09: marcos do tratamento agudo.
    data_termino_cirurgia DATE,
    data_termino_quimioterapia DATE,
    data_termino_radioterapia DATE,
    hormonioterapia_em_andamento BOOLEAN NOT NULL DEFAULT FALSE,  -- apta (RN09)
    -- Radioterapia ativa em manutencao exige atestado especifico (RN09).
    radioterapia_em_manutencao BOOLEAN NOT NULL DEFAULT FALSE,
    -- v3.4.0 (item 2.5 #5 / RF04/RN09): flags Sim/Nao de tratamentos realizados,
    -- independentes das datas de termino (quem fez sem data ainda registrada nao
    -- some como se nao tivesse feito). Obrigatorios quando a ficha e preenchida.
    realizou_cirurgia BOOLEAN NOT NULL DEFAULT FALSE,
    realizou_quimioterapia BOOLEAN NOT NULL DEFAULT FALSE,
    realizou_radioterapia BOOLEAN NOT NULL DEFAULT FALSE,
    -- v3.4.0 (item 2.5 #6 / RF04): datas de inicio e conclusao da hormonioterapia.
    data_inicio_hormonioterapia DATE,
    data_fim_hormonioterapia DATE,
    -- v3.4.0 (item 2.5 #7 / RF04): data do documento de laudo e observacoes clinicas.
    data_laudo DATE,
    observacao_diagnostico TEXT,
    observacao_recidiva TEXT,
    CONSTRAINT ck_radioterapia_manutencao CHECK
        (NOT radioterapia_em_manutencao OR data_termino_radioterapia IS NULL),
    CONSTRAINT ck_hormonioterapia_datas CHECK
        (data_fim_hormonioterapia IS NULL OR data_inicio_hormonioterapia IS NOT NULL),
    CONSTRAINT ck_hormonioterapia_periodo CHECK
        (data_fim_hormonioterapia IS NULL
         OR data_fim_hormonioterapia >= data_inicio_hormonioterapia)
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

-- RF05: sintomas oncologicos nomeados. Historico: a linha mais recente por
-- (participante, tipo_sintoma) e a situacao atual; remissao = nova linha com
-- presente = FALSE. Grau de linfedema 1-3: 1=Leve, 2=Moderado, 3=Grave
-- (escala definida pelo Grupo 1 em 21/10/2026; campo vazio quando sem linfedema).
CREATE TABLE sintoma (
    id_sintoma INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_participante INT NOT NULL REFERENCES participante(id_participante),
    tipo_sintoma VARCHAR(20) NOT NULL CHECK (tipo_sintoma IN ('linfedema', 'neuropatia')),
    presente BOOLEAN NOT NULL DEFAULT TRUE,
    braco_afetado VARCHAR(5) CHECK (braco_afetado IN ('LD', 'LE', 'Ambos')),
    grau SMALLINT CHECK (grau BETWEEN 1 AND 3),  -- RF05 (v3.4.0): 1=Leve, 2=Moderado, 3=Grave
    localizacao VARCHAR(100),
    registrado_em TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT ck_sintoma_campos CHECK (
        (tipo_sintoma = 'linfedema' AND localizacao IS NULL
            AND ((presente AND braco_afetado IS NOT NULL AND grau IS NOT NULL)
              OR (NOT presente AND braco_afetado IS NULL AND grau IS NULL)))
        OR
        (tipo_sintoma = 'neuropatia' AND braco_afetado IS NULL AND grau IS NULL
            AND ((presente AND NULLIF(btrim(localizacao), '') IS NOT NULL)
              OR (NOT presente AND localizacao IS NULL)))
    )
);
CREATE INDEX idx_sintoma_participante
    ON sintoma (id_participante, tipo_sintoma, registrado_em DESC);

-- A ficha atual permanece 1:1; documentos historicos sao 1:N.
-- RF06/RN02: o atestado entra 'pendente'; somente gestao_1 aprova/rejeita.
-- Validade: 180 dias a contar de data_documento (ver fn_participante_apto).
CREATE TABLE atestado_medico (
    id_atestado BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_participante INT NOT NULL REFERENCES participante(id_participante),
    arquivo_url TEXT NOT NULL CHECK (btrim(arquivo_url) <> ''),
    observacao TEXT,
    data_documento DATE,
    tipo_atestado VARCHAR(30) NOT NULL DEFAULT 'liberacao_esforco'
        CHECK (tipo_atestado IN ('liberacao_esforco', 'radioterapia_manutencao')),
    status_validacao VARCHAR(10) NOT NULL DEFAULT 'pendente'
        CHECK (status_validacao IN ('pendente', 'aprovado', 'rejeitado')),
    data_validacao TIMESTAMPTZ,
    id_usuario_validador INT,
    anexado_em TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_usuario_autor INT NOT NULL,
    -- v3.4.0 (item 2.5 #1): texto de recusa escrito pela coordenacao, separado
    -- da observacao enviada pela aluna. Obrigatorio quando rejeitado.
    motivo_recusa TEXT,
    CONSTRAINT ck_atestado_validacao CHECK (
        (status_validacao = 'pendente'
            AND data_validacao IS NULL AND id_usuario_validador IS NULL)
        OR (status_validacao <> 'pendente'
            AND data_validacao IS NOT NULL AND id_usuario_validador IS NOT NULL)
    ),
    CONSTRAINT ck_atestado_aprovado_data CHECK
        (status_validacao <> 'aprovado' OR data_documento IS NOT NULL),
    CONSTRAINT ck_atestado_motivo_recusa CHECK
        (status_validacao <> 'rejeitado' OR NULLIF(btrim(motivo_recusa), '') IS NOT NULL)
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
    turma VARCHAR(20),  -- turma-horario (ex.: REMAMA 08h-09h x 09h-10h)
    id_barco INT REFERENCES barco(id_barco),  -- V3.3: guarnicao (so REMAMA)
    data_inscricao TIMESTAMPTZ DEFAULT CURRENT_DATE,
    especializacao_leme BOOLEAN DEFAULT FALSE,
    especializacao_tambor BOOLEAN DEFAULT FALSE,
    data_desligamento DATE NULL,
    CONSTRAINT uq_inscricao_identidade UNIQUE (id_inscricao, id_participante, id_programa),
    CONSTRAINT uq_inscricao_participante UNIQUE (id_inscricao, id_participante),
    CONSTRAINT ck_inscricao_barco CHECK (id_barco IS NULL OR id_programa = 1),
    CONSTRAINT ck_inscricao_periodo CHECK
        (data_desligamento IS NULL OR data_desligamento >= data_inscricao::date)
);

-- Uma inscricao ativa por participante e programa; inscricoes historicas permanecem.
CREATE UNIQUE INDEX uq_inscricao_ativa
    ON inscricao_programa (id_participante, id_programa)
    WHERE data_desligamento IS NULL;

-- RN12 (V3.3): no maximo 1 Capita (id_cargo = 3) ativa por barco. Inscricao
-- sem barco atribuido nao entra na regra (guarnicao ainda nao montada).
CREATE UNIQUE INDEX uq_capita_por_barco
    ON inscricao_programa (id_barco)
    WHERE id_cargo = 3 AND id_barco IS NOT NULL AND data_desligamento IS NULL;

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
    -- V3.3 (RF08): sala virtual (Meet/Zoom) informada pelo professor. Nao e
    -- legivel pela aluna (GRANT por coluna); ela usa fn_link_aula().
    link_aula TEXT,
    -- RN13: chuva no REMAMA = 'indoor', e a aula conta como realizada.
    -- Preenchido pela trigger quando omitido (ONcoFITT = 'online').
    tipo_aula VARCHAR(10) NOT NULL CHECK (tipo_aula IN ('raia', 'indoor', 'online')),
    cancelada BOOLEAN NOT NULL DEFAULT FALSE,
    motivo_cancelamento TEXT,
    cancelada_em TIMESTAMPTZ,
    CONSTRAINT ck_aula_cancelamento CHECK (
        (cancelada = FALSE AND motivo_cancelamento IS NULL AND cancelada_em IS NULL)
        OR (cancelada = TRUE AND motivo_cancelamento IS NOT NULL
            AND btrim(motivo_cancelamento) <> '' AND cancelada_em IS NOT NULL)
    ),
    CONSTRAINT ck_aula_periodo CHECK (fim > inicio),
    CONSTRAINT ck_aula_link CHECK (link_aula IS NULL
        OR (tipo_aula = 'online' AND link_aula ~ '^https://[^[:space:]]+$')),
    CONSTRAINT uq_aula_programa UNIQUE (id_aula, id_programa)
);

CREATE INDEX idx_aula_calendario ON aula (id_programa, inicio)
    WHERE cancelada = FALSE;

-- Cancelar nao apaga chamadas anteriores. O motivo e obrigatorio e a data
-- e fixada pelo servidor; uma aula ja cancelada nao pode ser reativada.
CREATE OR REPLACE FUNCTION fn_cancelar_aula() RETURNS TRIGGER AS $$
BEGIN
    NEW.tipo_aula := COALESCE(NEW.tipo_aula,
        CASE WHEN NEW.id_programa = 2 THEN 'online' ELSE 'raia' END);
    IF (NEW.id_programa = 2) <> (NEW.tipo_aula = 'online') THEN
        RAISE EXCEPTION 'tipo_aula online e exclusivo do ONcoFITT';
    END IF;
    -- Cancelar aula e exclusivo da gestao_1 (secao 2.2 do MD).
    IF NEW.cancelada AND (TG_OP = 'INSERT' OR NOT OLD.cancelada) AND
       (current_user IN ('app_gestao_2','app_participante') OR
        (current_user = 'app_gestao_1' AND app_nivel_usuario() <> 'gestao_1')) THEN
        RAISE EXCEPTION 'Somente gestao_1 cancela aulas';
    END IF;
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
-- Estados normativos: P=Presente, F=Falta, J=Justificada, CSP=Compareceu sem
-- participacao (nao conta presenca/falta e nao gera PSE). PRE = pre_registro,
-- estado transitorio criado pela aluna ao entrar na aula ONcoFITT; o professor
-- o converte em P/F/CSP. J so surge pelo deferimento da justificativa.
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
    -- RN06: PA e FC pre/pos-treino sao opcionais e nunca bloqueiam chamada/PSE.
    fc_antes INT,
    fc_depois INT,
    pa_sistolica_antes SMALLINT,
    pa_diastolica_antes SMALLINT,
    pa_sistolica_depois SMALLINT,
    pa_diastolica_depois SMALLINT,
    -- PSE desta participante nesta aula, separado do PSE da avaliacao.
    pse INT CHECK (pse BETWEEN 0 AND 10),
    CONSTRAINT ck_frequencia_fc CHECK (
        (fc_antes IS NULL OR fc_antes BETWEEN 30 AND 220)
        AND (fc_depois IS NULL OR fc_depois BETWEEN 30 AND 220)
    ),
    -- Faixas amplas (50-300 / 30-200 mmHg): o MD nao as define, so a FC.
    CONSTRAINT ck_frequencia_pa CHECK (
        (pa_sistolica_antes IS NULL) = (pa_diastolica_antes IS NULL)
        AND (pa_sistolica_depois IS NULL) = (pa_diastolica_depois IS NULL)
        AND (pa_sistolica_antes IS NULL OR (pa_sistolica_antes BETWEEN 50 AND 300
             AND pa_diastolica_antes BETWEEN 30 AND 200
             AND pa_sistolica_antes > pa_diastolica_antes))
        AND (pa_sistolica_depois IS NULL OR (pa_sistolica_depois BETWEEN 50 AND 300
             AND pa_diastolica_depois BETWEEN 30 AND 200
             AND pa_sistolica_depois > pa_diastolica_depois))
    ),
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

-- Uma justificativa imutavel por falta (ALT-12: texto, anexo ou ambos).
-- Somente status_analise/data_analise/id_usuario_analista mudam.
-- v3.4.0 (RF06 / teste 15): deferir/indeferir e exclusivo da gestao_1;
-- gestao_2 (professor) apenas visualiza. Reverte decisao da V3.3.
-- Deferir converte F em J; indeferir mantem F.
CREATE TABLE justificativa_falta (
    id_justificativa BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_frequencia INT NOT NULL UNIQUE REFERENCES registro_frequencia(id_frequencia),
    id_participante INT NOT NULL,
    motivo TEXT CHECK (btrim(motivo) <> ''),
    arquivo_url TEXT CHECK (btrim(arquivo_url) <> ''),
    registrado_em TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    id_usuario_autor INT NOT NULL,
    status_analise VARCHAR(10) NOT NULL DEFAULT 'pendente'
        CHECK (status_analise IN ('pendente', 'deferida', 'indeferida')),
    data_analise TIMESTAMPTZ,
    id_usuario_analista INT,
    -- v3.4.0 (item 2.5 #2 / RF06): motivo obrigatorio ao indeferir (L04, telas 13-16).
    motivo_indeferimento TEXT,
    -- v3.4.0 (item 2.5 #3 / RF06): observacao opcional da coordenacao ao deferir (L04, telas 9-12).
    observacao_deferimento TEXT,
    CONSTRAINT ck_justificativa_conteudo CHECK (motivo IS NOT NULL OR arquivo_url IS NOT NULL),
    CONSTRAINT ck_justificativa_motivo_indeferimento CHECK
        (status_analise <> 'indeferida' OR NULLIF(btrim(motivo_indeferimento), '') IS NOT NULL),
    CONSTRAINT ck_justificativa_analise CHECK (
        (status_analise = 'pendente'
            AND data_analise IS NULL AND id_usuario_analista IS NULL)
        OR (status_analise <> 'pendente'
            AND data_analise IS NOT NULL AND id_usuario_analista IS NOT NULL)
    ),
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
    -- V3.3 (RF01): hash proprio OU credencial no Supabase Auth (auth_user_id).
    senha_hash VARCHAR(255) CHECK (btrim(senha_hash) <> ''),
    id_nivel_acesso INT NOT NULL REFERENCES nivel_acesso(id_nivel_acesso),
    id_participante INT UNIQUE REFERENCES participante(id_participante),
    id_funcionario INT UNIQUE REFERENCES funcionarios(id_funcionario),
    ativo BOOLEAN NOT NULL DEFAULT TRUE,
    criado_em TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ultimo_login TIMESTAMPTZ,
    auth_user_id UUID UNIQUE,  -- = auth.users.id (sem FK: o DDL roda tambem fora do Supabase)
    CONSTRAINT ck_usuario_vinculo CHECK (
        (id_participante IS NOT NULL AND id_funcionario IS NULL)
        OR (id_participante IS NULL AND id_funcionario IS NOT NULL)
    ),
    CONSTRAINT ck_usuario_credencial CHECK (senha_hash IS NOT NULL OR auth_user_id IS NOT NULL)
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
ALTER TABLE atestado_medico ADD CONSTRAINT fk_atestado_validador
    FOREIGN KEY (id_usuario_validador) REFERENCES usuario_acesso(id_usuario);
ALTER TABLE justificativa_falta ADD CONSTRAINT fk_justificativa_analista
    FOREIGN KEY (id_usuario_analista) REFERENCES usuario_acesso(id_usuario);

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
    (1, 'REMAMA'),
    (2, 'ONcoFITT');

INSERT INTO cargo_participante (id_cargo, nome_cargo) VALUES
    (1, 'Aluna / Remadora'),
    (2, 'Gerente'),
    (3, 'Capitã'),
    (4, 'Dragonete'),
    (5, 'Voga');

INSERT INTO status_presenca (sigla, descricao) VALUES
    ('P', 'Presente'),
    ('F', 'Falta'),
    ('J', 'Justificada'),
    ('CSP', 'Compareceu sem participação'),
    ('PRE', 'Pré-registro');

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
    ('Doenças Cardiovasculares','Insuficiência Cardíaca'),
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
    ('Musculo-esqueléticas','Artralgia'),
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
-- 8. STATUS GLOBAL E INSCRICOES INDEPENDENTES POR PROGRAMA
-- O status global representa o cadastro da participante, nao o vinculo
-- isolado a REMAMA/ONcoFITT. Encerrar uma inscricao nao altera id_status.
-- O status inicial e 2 (Inativa/Pendente); ativacao/desligamento global
-- e uma acao administrativa separada, validada no backend e protegida abaixo.
-- =====================================================

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
       a.titulo, a.inicio, a.fim, a.local_aula, a.descricao, a.tipo_aula
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
       av.marcha_passadas,
       av.flexibilidade_ombros_cm, av.flexibilidade_tronco_cm,
       av.obs_avaliacao,
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
       a.titulo, a.inicio, a.fim, a.tipo_aula, a.cancelada,
       a.motivo_cancelamento, a.cancelada_em,
       COUNT(f.id_frequencia) AS chamadas_registradas,
       COUNT(f.id_frequencia) FILTER (WHERE NOT a.cancelada AND sp.sigla = 'P') AS presentes_validos,
       COUNT(f.id_frequencia) FILTER (WHERE NOT a.cancelada AND sp.sigla = 'F') AS faltas_validas,
       COUNT(f.id_frequencia) FILTER (WHERE NOT a.cancelada AND sp.sigla = 'J') AS justificadas_validas,
       COUNT(f.id_frequencia) FILTER (WHERE NOT a.cancelada AND sp.sigla = 'CSP') AS csp_validos,
       COUNT(f.id_frequencia) FILTER (WHERE NOT a.cancelada AND sp.sigla = 'PRE') AS pre_registros_pendentes
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
       av.marcha_passadas, av.flexibilidade_ombros_cm, av.flexibilidade_tronco_cm
FROM inscricao_programa i
JOIN programa pr ON pr.id_programa = i.id_programa
LEFT JOIN avaliacao av ON av.id_inscricao = i.id_inscricao
  AND av.id_participante = i.id_participante;

-- RN02/RN09: apta = atestado APROVADO por gestao_1 com data_documento ate
-- 180 dias antes da data consultada. Se ha radioterapia em manutencao, o
-- atestado precisa ser do tipo 'radioterapia_manutencao'.
CREATE OR REPLACE FUNCTION fn_participante_apto(p_id_participante INT, p_data DATE)
RETURNS BOOLEAN LANGUAGE sql STABLE AS $$
    SELECT EXISTS (
        SELECT 1 FROM atestado_medico a
        WHERE a.id_participante = p_id_participante
          AND a.status_validacao = 'aprovado'
          AND a.data_documento IS NOT NULL
          AND p_data BETWEEN a.data_documento AND a.data_documento + 180
          AND (a.tipo_atestado = 'radioterapia_manutencao'
               OR NOT COALESCE((SELECT f.radioterapia_em_manutencao FROM ficha_medica f
                                WHERE f.id_participante = p_id_participante), FALSE))
    )
$$;

-- apto_pratica = FALSE: trava medica (presenca na raia e botao 'Entrar na aula').
CREATE VIEW vw_participante_apto WITH (security_invoker = true) AS
SELECT p.id_participante,
       fn_participante_apto(p.id_participante, CURRENT_DATE) AS apto_pratica,
       (SELECT MAX(a.data_documento) + 180 FROM atestado_medico a
        WHERE a.id_participante = p.id_participante
          AND a.status_validacao = 'aprovado') AS atestado_valido_ate
FROM participante p;

-- RN01: assiduidade = P / (aulas realizadas - J - CSP). Aulas canceladas e
-- pre_registro ainda nao confirmado ficam fora. Alerta se < 60%.
CREATE VIEW vw_assiduidade_programa WITH (security_invoker = true) AS
SELECT t.*, COALESCE(t.assiduidade_pct < 60, FALSE) AS alerta_assiduidade
FROM (
    SELECT i.id_participante, i.id_inscricao, i.id_programa, pr.nome_programa,
           COUNT(*) AS aulas_realizadas,
           COUNT(*) FILTER (WHERE s.sigla = 'P') AS presencas,
           COUNT(*) FILTER (WHERE s.sigla = 'F') AS faltas,
           COUNT(*) FILTER (WHERE s.sigla = 'J') AS faltas_justificadas,
           COUNT(*) FILTER (WHERE s.sigla = 'CSP') AS compareceu_sem_participacao,
           ROUND(100.0 * COUNT(*) FILTER (WHERE s.sigla = 'P')
                 / NULLIF(COUNT(*) - COUNT(*) FILTER (WHERE s.sigla IN ('J', 'CSP')), 0), 2)
               AS assiduidade_pct
    FROM inscricao_programa i
    JOIN programa pr ON pr.id_programa = i.id_programa
    JOIN registro_frequencia f ON f.id_inscricao = i.id_inscricao
      AND f.id_participante = i.id_participante
    JOIN aula a ON a.id_aula = f.id_aula AND a.cancelada = FALSE
    JOIN status_presenca s ON s.id_status_presenca = f.id_status_presenca
      AND s.sigla <> 'PRE'
    GROUP BY i.id_participante, i.id_inscricao, i.id_programa, pr.nome_programa
) t;

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

-- A justificativa so existe sobre uma falta (F) e nasce 'pendente'.
CREATE OR REPLACE FUNCTION fn_validar_justificativa_falta() RETURNS TRIGGER AS $$
DECLARE v_sigla VARCHAR(5);
BEGIN
    IF NEW.status_analise IS DISTINCT FROM 'pendente' THEN
        RAISE EXCEPTION 'A justificativa entra na fila como pendente';
    END IF;
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

-- Deferir/indeferir: exclusivo da gestao_1 (v3.4.0 / RF06 / teste 15);
-- analista e data sao fixados pelo servidor.
CREATE OR REPLACE FUNCTION fn_analisar_justificativa() RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status_analise IS DISTINCT FROM OLD.status_analise THEN
        IF OLD.status_analise <> 'pendente' THEN
            RAISE EXCEPTION 'Justificativa ja analisada; a decisao e historica';
        END IF;
        IF current_user <> 'app_gestao_1' OR app_nivel_usuario() <> 'gestao_1' THEN
            RAISE EXCEPTION 'Somente a coordenacao (gestao_1) defere ou indefere justificativas';
        END IF;
        IF app_usuario_id() IS NOT NULL THEN
            NEW.data_analise := CURRENT_TIMESTAMP;
            NEW.id_usuario_analista := app_usuario_id();
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_analisar_justificativa
BEFORE UPDATE ON justificativa_falta FOR EACH ROW
EXECUTE FUNCTION fn_analisar_justificativa();

-- RF06/RN01: a falta passa de F para J somente quando a justificativa e deferida.
CREATE OR REPLACE FUNCTION fn_marcar_falta_justificada() RETURNS TRIGGER AS $$
BEGIN
    UPDATE registro_frequencia
    SET id_status_presenca = (SELECT id_status_presenca FROM status_presenca WHERE sigla = 'J')
    WHERE id_frequencia = NEW.id_frequencia
      AND id_status_presenca = (SELECT id_status_presenca FROM status_presenca WHERE sigla = 'F');
    IF NOT FOUND THEN RAISE EXCEPTION 'A falta foi alterada durante a analise'; END IF;
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public, pg_temp;
CREATE TRIGGER trg_marcar_falta_justificada
AFTER UPDATE OF status_analise ON justificativa_falta FOR EACH ROW
WHEN (OLD.status_analise = 'pendente' AND NEW.status_analise = 'deferida')
EXECUTE FUNCTION fn_marcar_falta_justificada();

-- Invariante: status J <=> existe justificativa DEFERIDA para a chamada.
CREATE OR REPLACE FUNCTION fn_conferir_status_justificativa() RETURNS TRIGGER AS $$
DECLARE v_sigla VARCHAR(5); v_existe BOOLEAN;
BEGIN
    SELECT sigla INTO v_sigla FROM status_presenca
    WHERE id_status_presenca = NEW.id_status_presenca;
    SELECT EXISTS (SELECT 1 FROM justificativa_falta
                   WHERE id_frequencia = NEW.id_frequencia
                     AND status_analise = 'deferida') INTO v_existe;
    IF (v_sigla = 'J') IS DISTINCT FROM v_existe THEN
        RAISE EXCEPTION 'Status J requer justificativa deferida; justificativa deferida requer status J';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_conferir_status_justificativa
BEFORE INSERT OR UPDATE OF id_status_presenca ON registro_frequencia
FOR EACH ROW
EXECUTE FUNCTION fn_conferir_status_justificativa();

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
-- Status global: manual so por gestao_1 (e validado abaixo); a automacao do
-- ciclo de vida (RF07) esta em fn_recalcular_status_participante.
-- Ativar (id_status = 1) exige: contato de emergencia completo (RN08),
-- atestado aprovado e vigente (RF02/RN02) e inscricao ativa (RF02).
CREATE OR REPLACE FUNCTION fn_proteger_status_global() RETURNS TRIGGER AS $$
BEGIN
    -- V3.3: mudancas feitas pela automacao (fn_recalcular_status_participante,
    -- SECURITY DEFINER) rodam como proprietario e ja validam os requisitos.
    IF current_user NOT IN ('app_participante','app_gestao_1','app_gestao_2') THEN
        RETURN NEW;
    END IF;
    IF NEW.id_status IS DISTINCT FROM OLD.id_status THEN
        IF current_user <> 'app_gestao_1' OR app_nivel_usuario() <> 'gestao_1' THEN
            RAISE EXCEPTION 'Somente gestao_1 pode alterar o status global';
        END IF;
        IF NEW.id_status NOT IN (1,2,3,4) THEN
            RAISE EXCEPTION 'Status global invalido';
        END IF;
        IF NEW.id_status = 1 THEN
            IF NOT EXISTS (SELECT 1 FROM contato c
                           WHERE c.id_participante = NEW.id_participante
                             AND NULLIF(btrim(c.contato_emergencia_nome), '') IS NOT NULL
                             AND NULLIF(btrim(c.contato_emergencia_tel), '') IS NOT NULL
                             AND NULLIF(btrim(c.contato_emergencia_parentesco), '') IS NOT NULL) THEN
                RAISE EXCEPTION 'RN08: contato de emergencia com nome, telefone e parentesco e obrigatorio';
            END IF;
            IF NOT fn_participante_apto(NEW.id_participante, CURRENT_DATE) THEN
                RAISE EXCEPTION 'RF02/RN02: atestado medico aprovado e vigente e obrigatorio';
            END IF;
            IF NOT EXISTS (SELECT 1 FROM inscricao_programa i
                           WHERE i.id_participante = NEW.id_participante
                             AND i.data_desligamento IS NULL) THEN
                RAISE EXCEPTION 'RF02: matricula ativa em turma e obrigatoria';
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_proteger_status_global
BEFORE UPDATE OF id_status ON participante
FOR EACH ROW
EXECUTE FUNCTION fn_proteger_status_global();

-- RF07 (MD): o status global alterna automaticamente conforme o ciclo de vida.
--   2 (Pendente) -> 1 (Ativa): contato de emergencia + atestado aprovado e
--      vigente + inscricao ativa (RF02/RN02/RN08). Disparado por aprovacao de
--      atestado, contato novo/alterado ou inscricao nova.
--   1 -> 4 (Desligada): quando a ULTIMA inscricao ativa e encerrada.
--   4 -> 1: novo ingresso (retorno) com os requisitos em dia. Nunca por
--      evento de contato/atestado, para nao reativar quem gestao_1 desligou.
--   3 (Afastada): nunca mexe (manual, gestao_1). Atestado vencido nao muda o
--      status: a aluna segue ativa com apto_pratica = false (RN02).
CREATE OR REPLACE FUNCTION fn_recalcular_status_participante(p_id INT, p_retorno BOOLEAN)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER
SET search_path = pg_catalog, public, pg_temp AS $$
DECLARE v_atual INT; v_inscricao BOOLEAN; v_ok BOOLEAN;
BEGIN
    SELECT id_status INTO v_atual FROM participante WHERE id_participante = p_id FOR UPDATE;
    IF NOT FOUND THEN RETURN; END IF;
    v_inscricao := EXISTS (SELECT 1 FROM inscricao_programa i
                           WHERE i.id_participante = p_id AND i.data_desligamento IS NULL);
    v_ok := v_inscricao
        AND EXISTS (SELECT 1 FROM contato c
                    WHERE c.id_participante = p_id
                      AND NULLIF(btrim(c.contato_emergencia_nome), '') IS NOT NULL
                      AND NULLIF(btrim(c.contato_emergencia_tel), '') IS NOT NULL
                      AND NULLIF(btrim(c.contato_emergencia_parentesco), '') IS NOT NULL)
        AND fn_participante_apto(p_id, CURRENT_DATE);
    IF (v_atual = 2 OR (v_atual = 4 AND p_retorno)) AND v_ok THEN
        UPDATE participante SET id_status = 1 WHERE id_participante = p_id;
    ELSIF v_atual = 1 AND NOT v_inscricao THEN
        UPDATE participante SET id_status = 4 WHERE id_participante = p_id;
    END IF;
END;
$$;
REVOKE ALL ON FUNCTION fn_recalcular_status_participante(INT, BOOLEAN) FROM PUBLIC;

CREATE OR REPLACE FUNCTION fn_atualiza_status_participante() RETURNS TRIGGER AS $$
BEGIN
    PERFORM fn_recalcular_status_participante(NEW.id_participante,
        TG_TABLE_NAME = 'inscricao_programa' AND TG_OP = 'INSERT');
    RETURN NULL;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog, public, pg_temp;
REVOKE ALL ON FUNCTION fn_atualiza_status_participante() FROM PUBLIC;

CREATE TRIGGER trg_atualiza_status_participante
AFTER INSERT OR UPDATE OF data_desligamento ON inscricao_programa
FOR EACH ROW EXECUTE FUNCTION fn_atualiza_status_participante();
CREATE TRIGGER trg_atualiza_status_participante_atestado
AFTER INSERT OR UPDATE OF status_validacao ON atestado_medico
FOR EACH ROW WHEN (NEW.status_validacao = 'aprovado')
EXECUTE FUNCTION fn_atualiza_status_participante();
CREATE TRIGGER trg_atualiza_status_participante_contato
AFTER INSERT OR UPDATE ON contato
FOR EACH ROW EXECUTE FUNCTION fn_atualiza_status_participante();

-- RF04/RN10: CID-O (tipo de cancer) e lateralidade ja preenchidos so mudam por
-- gestao_1 (a senha de ADM e exigida pelo backend). Preencher o dado inicial
-- continua permitido a gestao_2 (pre-cadastro).
CREATE OR REPLACE FUNCTION fn_proteger_diagnostico_base() RETURNS TRIGGER AS $$
BEGIN
    IF ((NEW.id_tipo_cancer IS DISTINCT FROM OLD.id_tipo_cancer AND OLD.id_tipo_cancer IS NOT NULL)
        OR (NEW.mamas_afetadas IS DISTINCT FROM OLD.mamas_afetadas AND OLD.mamas_afetadas IS NOT NULL))
       AND (current_user IN ('app_gestao_2','app_participante') OR
            (current_user = 'app_gestao_1' AND app_nivel_usuario() <> 'gestao_1')) THEN
        RAISE EXCEPTION 'Somente gestao_1 altera CID-O e lateralidade do diagnostico base';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_proteger_diagnostico_base
BEFORE UPDATE ON ficha_medica FOR EACH ROW
EXECUTE FUNCTION fn_proteger_diagnostico_base();

-- RF06/RN02: atestado novo entra pendente; so gestao_1 aprova/rejeita, uma
-- unica vez (nova avaliacao = novo atestado). Validador e data sao do servidor.
CREATE OR REPLACE FUNCTION fn_validar_atestado() RETURNS TRIGGER AS $$
BEGIN
    IF current_user NOT IN ('app_participante','app_gestao_1','app_gestao_2') THEN
        RETURN NEW;  -- proprietario: importacao controlada de historico
    END IF;
    IF NEW.data_documento IS NOT NULL AND NEW.data_documento > CURRENT_DATE THEN
        RAISE EXCEPTION 'A data de emissao do atestado nao pode ser futura';
    END IF;
    -- V3.3: gestao_1 completa a data enquanto pendente; depois e historica.
    IF TG_OP = 'UPDATE' AND NEW.data_documento IS DISTINCT FROM OLD.data_documento
       AND OLD.status_validacao <> 'pendente' THEN
        RAISE EXCEPTION 'Atestado ja decidido: a data de emissao nao pode mudar';
    END IF;
    IF TG_OP = 'INSERT' THEN
        IF NEW.status_validacao <> 'pendente' THEN
            RAISE EXCEPTION 'Atestado novo entra na fila de homologacao como pendente';
        END IF;
        RETURN NEW;
    END IF;
    IF NEW.status_validacao IS DISTINCT FROM OLD.status_validacao THEN
        IF current_user <> 'app_gestao_1' OR app_nivel_usuario() <> 'gestao_1' THEN
            RAISE EXCEPTION 'Somente gestao_1 homologa atestados';
        END IF;
        IF OLD.status_validacao <> 'pendente' THEN
            RAISE EXCEPTION 'Decisao sobre o atestado e historica; envie um novo atestado';
        END IF;
        NEW.data_validacao := CURRENT_TIMESTAMP;
        NEW.id_usuario_validador := app_usuario_id();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_validar_atestado
BEFORE INSERT OR UPDATE ON atestado_medico FOR EACH ROW
EXECUTE FUNCTION fn_validar_atestado();

-- Regras imutaveis de frequencia/PSE:
-- REMAMA: PSE registrado por gestao_2 (professor), escala 0-10.
-- ONcoFITT: PSE registrado pelo professor (gestao_2) ao termino da aula ou
-- pela propria participante ate 24h apos aula.fim (RF08 / ALT-10).
-- Apos PSE, nem presenca nem PSE podem ser alterados.
CREATE OR REPLACE FUNCTION fn_validar_frequencia_pse() RETURNS TRIGGER AS $$
DECLARE
    v_nivel TEXT;
    v_id_programa INT;
    v_fim TIMESTAMPTZ;
    v_sigla VARCHAR(5);
BEGIN
    v_nivel := app_nivel_usuario();

    IF TG_OP = 'UPDATE' AND OLD.pse IS NOT NULL THEN
        IF NEW.pse IS DISTINCT FROM OLD.pse
           OR NEW.id_status_presenca IS DISTINCT FROM OLD.id_status_presenca THEN
            RAISE EXCEPTION 'Presenca e PSE ficam imutaveis apos o registro do PSE';
        END IF;
    END IF;

    IF NEW.pse IS NOT NULL AND (TG_OP = 'INSERT' OR OLD.pse IS NULL) THEN
        IF NEW.id_aula IS NULL THEN
            RAISE EXCEPTION 'PSE so pode ser registrado para frequencia vinculada a aula';
        END IF;
        SELECT sigla INTO v_sigla FROM status_presenca
        WHERE id_status_presenca = NEW.id_status_presenca;
        IF v_sigla <> 'P' THEN
            RAISE EXCEPTION 'PSE so pode ser registrado para presenca confirmada';
        END IF;
        SELECT id_programa, fim INTO v_id_programa, v_fim FROM aula WHERE id_aula = NEW.id_aula;
        IF v_id_programa = 1 THEN
            IF current_user <> 'app_gestao_2' OR v_nivel <> 'gestao_2' THEN
                RAISE EXCEPTION 'No REMAMA, somente o professor (gestao_2) registra o PSE';
            END IF;
        ELSIF v_id_programa = 2 THEN
            IF current_user = 'app_gestao_2' AND v_nivel = 'gestao_2' THEN
                NULL;  -- professor registra o PSE ao termino da aula online
            ELSIF current_user = 'app_participante' AND v_nivel = 'participante'
                  AND app_participante_id() IS NOT DISTINCT FROM NEW.id_participante THEN
                IF CURRENT_TIMESTAMP > v_fim + INTERVAL '24 hours' THEN
                    RAISE EXCEPTION 'Prazo de 24 horas para responder ao PSE encerrado';
                END IF;
            ELSE
                RAISE EXCEPTION 'No ONcoFITT, o PSE e registrado pelo professor (gestao_2) ou pela propria participante';
            END IF;
        ELSE
            RAISE EXCEPTION 'Programa da aula invalido para registro de PSE';
        END IF;
    END IF;

    -- Se o PSE ainda nao existe, a chamada pode ser corrigida pela equipe.
    -- Quando houver PSE, a regra acima bloqueia alteracoes de presenca/PSE.
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_validar_frequencia_pse
BEFORE INSERT OR UPDATE ON registro_frequencia
FOR EACH ROW
EXECUTE FUNCTION fn_validar_frequencia_pse();

-- V3.3 (RF08/ALT-08): link da sala virtual.
CREATE OR REPLACE FUNCTION fn_aula_tem_link(p_id_aula INT) RETURNS BOOLEAN
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog, public, pg_temp AS $$
    SELECT COALESCE((SELECT link_aula IS NOT NULL FROM public.aula WHERE id_aula = p_id_aula), FALSE)
$$;
-- Entrega o link somente se: aula ONcoFITT nao cancelada, agora entre inicio e
-- fim, atestado vigente na data da aula e pre_registro/presenca ja registrado.
CREATE OR REPLACE FUNCTION fn_link_aula(p_id_aula INT) RETURNS TEXT
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = pg_catalog, public, pg_temp AS $$
DECLARE v_part INT; v_aula public.aula%ROWTYPE;
BEGIN
    v_part := public.app_participante_id();
    IF v_part IS NULL THEN RAISE EXCEPTION 'Somente a participante autenticada obtem o link'; END IF;
    SELECT * INTO v_aula FROM public.aula WHERE id_aula = p_id_aula;
    IF NOT FOUND OR v_aula.id_programa <> 2 OR v_aula.cancelada THEN
        RAISE EXCEPTION 'Aula online indisponivel';
    END IF;
    IF CURRENT_TIMESTAMP < v_aula.inicio OR CURRENT_TIMESTAMP > v_aula.fim THEN
        RAISE EXCEPTION 'O link so e liberado durante a aula';
    END IF;
    IF NOT public.fn_participante_apto(v_part, v_aula.inicio::date) THEN
        RAISE EXCEPTION 'Atestado ausente, nao aprovado ou vencido (180 dias)';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM public.registro_frequencia f
                   JOIN public.status_presenca s ON s.id_status_presenca = f.id_status_presenca
                   WHERE f.id_participante = v_part AND f.id_aula = p_id_aula
                     AND s.sigla IN ('PRE','P')) THEN
        RAISE EXCEPTION 'Use "Entrar na aula" antes de abrir a sala';
    END IF;
    IF v_aula.link_aula IS NULL THEN RAISE EXCEPTION 'O professor ainda nao publicou o link'; END IF;
    RETURN v_aula.link_aula;
END;
$$;
REVOKE ALL ON FUNCTION fn_aula_tem_link(INT), fn_link_aula(INT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_aula_tem_link(INT), fn_link_aula(INT)
TO app_participante, app_gestao_1, app_gestao_2;

-- RF08/RN02/RN05/RN11: quem pode lancar cada estado e quando.
--  PRE: so a propria aluna, so ONcoFITT, so no horario da aula, so se apta.
--  P/F/CSP: exclusivamente o professor (gestao_2). P exige atestado vigente
--  (calculado na data da aula) e, no ONcoFITT, respeita 100 presencas.
--  J nasce apenas do deferimento (fn_conferir_status_justificativa).
-- O proprietario/funcoes privilegiadas (importacao, F->J) nao passam por aqui.
CREATE OR REPLACE FUNCTION fn_validar_frequencia_status() RETURNS TRIGGER AS $$
DECLARE
    v_sigla VARCHAR(5);
    v_nivel TEXT;
    v_inicio TIMESTAMPTZ;
    v_fim TIMESTAMPTZ;
    v_programa INT;
    v_confirmadas INT;
BEGIN
    IF current_user NOT IN ('app_participante','app_gestao_1','app_gestao_2') THEN
        RETURN NEW;
    END IF;
    IF TG_OP = 'UPDATE' AND NEW.id_status_presenca = OLD.id_status_presenca THEN
        RETURN NEW;
    END IF;
    v_nivel := app_nivel_usuario();
    SELECT sigla INTO v_sigla FROM status_presenca
    WHERE id_status_presenca = NEW.id_status_presenca;
    IF v_sigla = 'J' THEN RETURN NEW; END IF;
    IF NEW.id_aula IS NOT NULL THEN
        SELECT inicio, fim, id_programa INTO v_inicio, v_fim, v_programa
        FROM aula WHERE id_aula = NEW.id_aula;
    END IF;

    IF v_sigla = 'PRE' THEN
        IF TG_OP <> 'INSERT' THEN
            RAISE EXCEPTION 'O pre_registro so e criado na entrada da aula';
        END IF;
        IF current_user <> 'app_participante' OR v_nivel <> 'participante'
           OR app_participante_id() IS DISTINCT FROM NEW.id_participante THEN
            RAISE EXCEPTION 'O pre_registro e gerado pela propria participante ao entrar na aula';
        END IF;
        IF NEW.id_aula IS NULL OR v_programa IS DISTINCT FROM 2 THEN
            RAISE EXCEPTION 'O pre_registro existe somente para aulas do ONcoFITT';
        END IF;
        IF CURRENT_TIMESTAMP < v_inicio OR CURRENT_TIMESTAMP > v_fim THEN
            RAISE EXCEPTION 'Entrada na aula somente no dia e horario da aula';
        END IF;
        IF NOT fn_participante_apto(NEW.id_participante, v_inicio::date) THEN
            RAISE EXCEPTION 'Atestado ausente, nao aprovado ou vencido (180 dias): entrada bloqueada';
        END IF;
        IF NOT fn_aula_tem_link(NEW.id_aula) THEN
            RAISE EXCEPTION 'O professor ainda nao publicou o link da aula';
        END IF;
        RETURN NEW;
    END IF;

    IF current_user <> 'app_gestao_2' OR v_nivel <> 'gestao_2' THEN
        RAISE EXCEPTION 'A chamada (P, F, CSP) e lancada exclusivamente pelo professor (gestao_2)';
    END IF;
    -- v3.4.0 (RN02 / teste 24): trava de atestado vale tanto para aula quanto
    -- para evento; antes, id_aula IS NOT NULL excluia eventos da verificacao.
    IF v_sigla = 'P' THEN
        DECLARE
            v_data_ref DATE;
        BEGIN
            IF NEW.id_aula IS NOT NULL THEN
                v_data_ref := v_inicio::date;
            ELSE
                -- Para evento, usa a data do registro como referencia.
                v_data_ref := NEW.data_registro;
            END IF;
            IF NOT fn_participante_apto(NEW.id_participante, v_data_ref) THEN
                RAISE EXCEPTION 'Atestado ausente, nao aprovado ou vencido (180 dias): presenca bloqueada';
            END IF;
        END;
        IF NEW.id_aula IS NOT NULL AND v_programa = 2 THEN
            PERFORM 1 FROM aula WHERE id_aula = NEW.id_aula FOR UPDATE;  -- serializa a contagem
            SELECT COUNT(*) INTO v_confirmadas
            FROM registro_frequencia f
            JOIN status_presenca s ON s.id_status_presenca = f.id_status_presenca
            WHERE f.id_aula = NEW.id_aula AND s.sigla = 'P'
              AND f.id_frequencia IS DISTINCT FROM NEW.id_frequencia;
            IF v_confirmadas >= 100 THEN
                RAISE EXCEPTION 'ONcoFITT: limite de 100 presencas confirmadas atingido';
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_validar_frequencia_status
BEFORE INSERT OR UPDATE OF id_status_presenca ON registro_frequencia
FOR EACH ROW
EXECUTE FUNCTION fn_validar_frequencia_status();

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
    status_presenca, cargo_participante, tipo_cancer, nivel_acesso, barco
TO app_participante, app_gestao_1, app_gestao_2;
GRANT INSERT, UPDATE ON barco TO app_gestao_1, app_gestao_2;

-- Permissoes operacionais da equipe; DELETE fisico e TRUNCATE nao concedidos.
GRANT SELECT, INSERT ON participante TO app_gestao_1, app_gestao_2;
-- Status geral so e atualizado pela trigger privilegiada de inscricao.
GRANT UPDATE (cpf, numero_carteirinha, nome_completo, nome_social,
    data_nascimento, sexo, id_estado_civil, possui_filhos, quantidade_filhos,
    profissao, trabalha_atualmente, renda_familiar_faixa, foto_url,
    observacoes, possui_alergia, descricao_alergia, medicamentos)
    ON participante TO app_gestao_1, app_gestao_2;
GRANT SELECT, INSERT, UPDATE ON endereco, contato,
    dados_antropometricos, avaliacao, ficha_medica, comorbidade, sintoma,
    treinamento, evento, aula
TO app_gestao_1, app_gestao_2;
-- V3.3: a chamada nao pode ter aula/participante/inscricao trocados por UPDATE
-- (contornava o limite de 100 e a trava de atestado). UPDATE so nestas colunas.
GRANT SELECT, INSERT ON registro_frequencia TO app_gestao_1, app_gestao_2;
GRANT UPDATE (id_status_presenca, fc_antes, fc_depois, pa_sistolica_antes,
    pa_diastolica_antes, pa_sistolica_depois, pa_diastolica_depois, pse)
ON registro_frequencia TO app_gestao_1, app_gestao_2;
GRANT SELECT, INSERT ON observacao_clinica, ocorrencia,
    atestado_medico, justificativa_falta, justificativa_arquivo_versao
TO app_gestao_1, app_gestao_2;
-- Homologar atestado: exclusivo da gestao_1 (data_documento so enquanto pendente).
-- v3.4.0: inclui motivo_recusa (obrigatorio ao rejeitar, item 2.5 #1).
GRANT UPDATE (status_validacao, data_validacao, id_usuario_validador, data_documento,
              motivo_recusa)
ON atestado_medico TO app_gestao_1;
-- Deferir/indeferir justificativa: exclusivo da gestao_1 (v3.4.0 / RF06 / teste 15).
-- gestao_2 so tem SELECT (concedido acima em conjunto com gestao_1).
-- O campo motivo_indeferimento e observacao_deferimento tambem sao escritos pela gestao_1.
GRANT UPDATE (status_analise, data_analise, id_usuario_analista,
              motivo_indeferimento, observacao_deferimento)
ON justificativa_falta TO app_gestao_1;
GRANT SELECT, INSERT ON inscricao_programa TO app_gestao_1, app_gestao_2;
GRANT UPDATE (id_cargo, turma, id_barco, especializacao_leme, especializacao_tambor)
ON inscricao_programa TO app_gestao_1, app_gestao_2;
GRANT UPDATE (data_desligamento) ON inscricao_programa TO app_gestao_1;
GRANT UPDATE (id_status) ON participante TO app_gestao_1;
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
    trabalha_atualmente, renda_familiar_faixa, foto_url,
    possui_alergia, descricao_alergia, medicamentos)
ON participante TO app_participante;
GRANT SELECT ON endereco, contato, dados_antropometricos, avaliacao,
    ficha_medica, comorbidade, sintoma, treinamento, evento, inscricao_programa,
    registro_frequencia, observacao_clinica, ocorrencia,
    atestado_medico, justificativa_falta, justificativa_arquivo_versao
TO app_participante;
-- V3.3: a aluna le a aula SEM link_aula (o link sai so por fn_link_aula).
GRANT SELECT (id_aula, id_programa, titulo, inicio, fim, local_aula, descricao,
    tipo_aula, cancelada, motivo_cancelamento, cancelada_em)
ON aula TO app_participante;
-- A participante pode preencher somente seu PSE no ONcoFITT; o trigger
-- valida programa, identidade, presença confirmada e prazo de 24 horas.
GRANT UPDATE (pse) ON registro_frequencia TO app_participante;

-- Auto-gestao da aluna (ALT-01 a ALT-03): endereco, telefones/contato de
-- emergencia, dados socioeconomicos, medicamentos, comorbidades e sintomas.
-- Ficha oncologica/laudos e alergias seguem exclusivos da equipe (ALT-02).
GRANT UPDATE (profissao, trabalha_atualmente, renda_familiar_faixa, medicamentos)
ON participante TO app_participante;
GRANT INSERT ON endereco, contato, comorbidade, sintoma TO app_participante;
GRANT UPDATE (cep, logradouro, numero, complemento, bairro, cidade, uf)
ON endereco TO app_participante;
GRANT UPDATE (telefone_fixo, celular, contato_emergencia_nome, contato_emergencia_tel,
    contato_emergencia_parentesco) ON contato TO app_participante;
GRANT UPDATE (id_tipo_comorbidade, id_variacao, descricao_outras, toma_medicamento,
    qual_medicamento) ON comorbidade TO app_participante;
GRANT UPDATE (tipo_sintoma, presente, braco_afetado, grau, localizacao)
ON sintoma TO app_participante;
-- Upload de atestado (nasce pendente) e pre_registro ao entrar na aula ONcoFITT.
GRANT INSERT ON atestado_medico TO app_participante;
GRANT INSERT (id_participante, id_status_presenca, id_inscricao, id_programa, id_aula)
ON registro_frequencia TO app_participante;
GRANT INSERT ON observacao_clinica, ocorrencia, justificativa_falta,
    justificativa_arquivo_versao
TO app_participante;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA public TO app_participante;

GRANT SELECT ON vw_inscricoes_participante, vw_calendario_aulas,
    vw_frequencia_programa, vw_participante_acompanhamento,
    vw_participante_apto, vw_assiduidade_programa
TO app_participante;
GRANT SELECT ON vw_poder_usuario, vw_inscricoes_participante,
    vw_calendario_aulas, vw_frequencia_programa,
    vw_pesquisador_evolucao, vw_professor_aulas,
    vw_participante_acompanhamento, vw_participante_apto,
    vw_assiduidade_programa
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
        'justificativa_arquivo_versao','sintoma'
    ] LOOP
        EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', v_tabela);
        -- observacao_clinica e ocorrencia: leitura propria definida adiante
        -- (a aluna so le o que ela mesma escreveu).
        IF v_tabela NOT IN ('observacao_clinica','ocorrencia') THEN
            EXECUTE format(
                'CREATE POLICY %I ON %I FOR SELECT TO app_participante '
                || 'USING (id_participante = app_participante_id())',
                'aluna_ler_' || v_tabela, v_tabela);
        END IF;
        EXECUTE format(
            'CREATE POLICY %I ON %I FOR ALL TO app_gestao_1, app_gestao_2 '
            || 'USING ((current_user = ''app_gestao_1'' AND app_nivel_usuario() = ''gestao_1'') '
            || 'OR (current_user = ''app_gestao_2'' AND app_nivel_usuario() = ''gestao_2'')) '
            || 'WITH CHECK ((current_user = ''app_gestao_1'' AND app_nivel_usuario() = ''gestao_1'') '
            || 'OR (current_user = ''app_gestao_2'' AND app_nivel_usuario() = ''gestao_2''))',
            'equipe_' || v_tabela, v_tabela);
    END LOOP;
END $$;

-- PSE do ONcoFITT: a aluna atualiza apenas a propria linha do programa 2.
CREATE POLICY aluna_registrar_pse_oncofitt ON registro_frequencia
FOR UPDATE TO app_participante
USING (id_participante = app_participante_id() AND id_programa = 2)
WITH CHECK (id_participante = app_participante_id() AND id_programa = 2);

-- Selecao de notas da aluna: apenas as que ela propria escreveu.
CREATE POLICY aluna_ler_observacao_clinica ON observacao_clinica
FOR SELECT TO app_participante
USING (id_participante = app_participante_id()
       AND id_usuario_autor = app_usuario_id());
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
CREATE POLICY aluna_enviar_atestado ON atestado_medico
FOR INSERT TO app_participante
WITH CHECK (id_participante = app_participante_id()
            AND id_usuario_autor = app_usuario_id());

-- ALT-01 a ALT-03: auto-edicao da aluna restrita as proprias linhas.
CREATE POLICY aluna_editar_participante ON participante
FOR UPDATE TO app_participante
USING (id_participante = app_participante_id())
WITH CHECK (id_participante = app_participante_id());
DO $$
DECLARE v_tabela TEXT;
BEGIN
    FOREACH v_tabela IN ARRAY ARRAY['endereco','contato','comorbidade','sintoma'] LOOP
        EXECUTE format(
            'CREATE POLICY %I ON %I FOR INSERT TO app_participante '
            || 'WITH CHECK (id_participante = app_participante_id())',
            'aluna_criar_' || v_tabela, v_tabela);
        EXECUTE format(
            'CREATE POLICY %I ON %I FOR UPDATE TO app_participante '
            || 'USING (id_participante = app_participante_id()) '
            || 'WITH CHECK (id_participante = app_participante_id())',
            'aluna_editar_' || v_tabela, v_tabela);
    END LOOP;
END $$;

-- ALT-08: o botao 'Entrar na aula' cria o pre_registro (ONcoFITT) da propria aluna.
CREATE POLICY aluna_pre_registro ON registro_frequencia
FOR INSERT TO app_participante
WITH CHECK (id_participante = app_participante_id()
            AND id_programa = 2 AND id_aula IS NOT NULL);

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
