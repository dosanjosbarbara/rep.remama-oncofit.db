-- =====================================================
-- REMAMA / ONCOFIT - QUERIES DE INTEGRIDADE E INSIGHTS
-- =====================================================


-- =====================================================
-- PARTE 1: INTEGRIDADE E QUALIDADE DOS DADOS
-- =====================================================

-- 1.1 Cobertura de cadastro: quantas participantes têm cada registro
-- complementar preenchido. Serve pra achar "buracos" no cadastro
-- (ex: participante sem endereço, sem ficha médica etc.)
SELECT
    (SELECT COUNT(*) FROM participante) AS total_participantes,
    (SELECT COUNT(*) FROM endereco) AS com_endereco,
    (SELECT COUNT(*) FROM contato) AS com_contato,
    (SELECT COUNT(*) FROM ficha_medica) AS com_ficha_medica,
    (SELECT COUNT(DISTINCT id_participante) FROM avaliacao) AS com_avaliacao,
    (SELECT COUNT(DISTINCT id_participante) FROM dados_antropometricos) AS com_antropometrico,
    (SELECT COUNT(DISTINCT id_participante) FROM inscricao_programa) AS com_inscricao;

-- 1.2 Participantes SEM nenhuma inscrição em programa
-- (não deveria existir em produção - toda aluna precisa estar
-- vinculada a pelo menos um programa)
SELECT p.id_participante, p.nome_completo
FROM participante p
LEFT JOIN inscricao_programa ip ON ip.id_participante = p.id_participante
WHERE ip.id_inscricao IS NULL;

-- 1.3 Consistência da trigger: status_participante deve bater com
-- a existência (ou não) de inscrição ativa. Essa query reconstrói
-- a regra do zero e compara com o valor gravado -- se aparecer
-- alguma linha aqui, a trigger falhou ou foi contornada (ex: UPDATE
-- direto na tabela participante, sem passar por inscricao_programa).
WITH situacao_calculada AS (
    SELECT
        p.id_participante,
        p.id_status AS status_gravado,
        CASE WHEN EXISTS (
            SELECT 1 FROM inscricao_programa ip
            WHERE ip.id_participante = p.id_participante
              AND ip.data_desligamento IS NULL
        ) THEN 1 ELSE 4 END AS status_esperado
    FROM participante p
)
SELECT * FROM situacao_calculada
WHERE status_gravado IN (1,4) AND status_gravado <> status_esperado;

-- 1.4 Faixas de valor fora do esperado clinicamente, mesmo que
-- dentro do CHECK do banco (o CHECK garante 0-10 de PSE, por
-- exemplo, mas não garante que o dado faz sentido). Aqui, IMC
-- calculado fora da faixa 15-45 é sinal de erro de digitação
-- em peso/altura.
SELECT
    id_participante,
    peso_kg,
    altura_m,
    ROUND((peso_kg / (altura_m * altura_m))::NUMERIC, 1) AS imc
FROM dados_antropometricos
WHERE (peso_kg / (altura_m * altura_m)) NOT BETWEEN 15 AND 45;

-- 1.5 Duplicidade de CPF ou e-mail (o UNIQUE do schema já impede
-- isso fisicamente -- essa query é só a forma de provar/auditar
-- que a constraint está realmente segurando).
SELECT cpf, COUNT(*) FROM participante GROUP BY cpf HAVING COUNT(*) > 1
UNION ALL
SELECT email, COUNT(*) FROM usuario_acesso GROUP BY email HAVING COUNT(*) > 1;

-- 1.6 Registros de frequência sem vínculo correto (nem treinamento
-- nem evento) -- o CHECK já impede isso na inserção, essa query é
-- a auditoria de confirmação.
SELECT COUNT(*) AS registros_invalidos
FROM registro_frequencia
WHERE id_treinamento IS NULL AND id_evento IS NULL;


-- =====================================================
-- PARTE 2: INSIGHTS DE ANÁLISE DE DADOS
-- =====================================================

-- 2.1 Perfil etário x tipo de câncer -- média de idade por
-- diagnóstico, útil pra entender se algum subtipo concentra
-- faixa etária diferente das demais.
SELECT
    tc.nome_cancer,
    COUNT(*) AS total_participantes,
    ROUND(AVG(EXTRACT(YEAR FROM AGE(p.data_nascimento))), 1) AS idade_media,
    MIN(EXTRACT(YEAR FROM AGE(p.data_nascimento))) AS idade_min,
    MAX(EXTRACT(YEAR FROM AGE(p.data_nascimento))) AS idade_max
FROM ficha_medica fm
JOIN participante p ON p.id_participante = fm.id_participante
JOIN tipo_cancer tc ON tc.id_tipo_cancer = fm.id_tipo_cancer
GROUP BY tc.nome_cancer
ORDER BY total_participantes DESC;

-- 2.2 Taxa de adesão por participante (% de presenças sobre o
-- total de registros de frequência), usando window function pra
-- já trazer o ranking dentro da mesma consulta -- não precisa de
-- uma segunda query pra descobrir quem tem menor adesão.
SELECT
    p.id_participante,
    p.nome_completo,
    COUNT(*) AS total_registros,
    COUNT(*) FILTER (WHERE rf.id_status_presenca = 1) AS presencas,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE rf.id_status_presenca = 1) / COUNT(*), 1
    ) AS taxa_adesao_pct,
    RANK() OVER (
        ORDER BY COUNT(*) FILTER (WHERE rf.id_status_presenca = 1)::NUMERIC / COUNT(*) DESC
    ) AS ranking_adesao
FROM registro_frequencia rf
JOIN participante p ON p.id_participante = rf.id_participante
GROUP BY p.id_participante, p.nome_completo
ORDER BY taxa_adesao_pct DESC;

-- 2.3 Evolução do PSE (esforço percebido) entre a 1ª e a 2ª
-- avaliação de cada participante -- usa LAG() pra comparar a
-- linha atual com a anterior sem precisar de self-join.
SELECT
    id_participante,
    numero_avaliacao,
    data_avaliacao,
    pse,
    LAG(pse) OVER (PARTITION BY id_participante ORDER BY numero_avaliacao) AS pse_avaliacao_anterior,
    pse - LAG(pse) OVER (PARTITION BY id_participante ORDER BY numero_avaliacao) AS variacao_pse
FROM avaliacao
ORDER BY id_participante, numero_avaliacao;

-- 2.4 Relação entre comorbidades e taxa de adesão -- participantes
-- com comorbidade têm frequência menor? CTE + subquery correlata
-- (lateral) pra trazer a taxa de adesão calculada por participante
-- e comparar entre os dois grupos.
WITH adesao_por_participante AS (
    SELECT
        id_participante,
        ROUND(
            100.0 * COUNT(*) FILTER (WHERE id_status_presenca = 1) / COUNT(*), 1
        ) AS taxa_adesao_pct
    FROM registro_frequencia
    GROUP BY id_participante
)
SELECT
    CASE WHEN c.id_participante IS NOT NULL THEN 'Com comorbidade' ELSE 'Sem comorbidade' END AS grupo,
    COUNT(DISTINCT a.id_participante) AS participantes,
    ROUND(AVG(a.taxa_adesao_pct), 1) AS adesao_media_pct
FROM adesao_por_participante a
LEFT JOIN (SELECT DISTINCT id_participante FROM comorbidade) c
    ON c.id_participante = a.id_participante
GROUP BY grupo;

-- 2.5 Ranking de flexibilidade x tempo de programa -- participantes
-- com mais tempo de inscrição têm classificação de flexibilidade
-- melhor? Junta inscricao_programa (tempo) com a avaliação mais
-- recente de cada uma (via LATERAL, pega só a última avaliação
-- sem precisar de subquery de MAX + join de volta).
SELECT
    p.id_participante,
    p.nome_completo,
    ip.data_inscricao,
    DATE_PART('day', NOW() - ip.data_inscricao) AS dias_no_programa,
    ult_aval.classificacao_flexibilidade,
    ult_aval.data_avaliacao
FROM participante p
JOIN inscricao_programa ip ON ip.id_participante = p.id_participante
JOIN LATERAL (
    SELECT classificacao_flexibilidade, data_avaliacao
    FROM avaliacao a
    WHERE a.id_participante = p.id_participante
    ORDER BY a.numero_avaliacao DESC
    LIMIT 1
) ult_aval ON TRUE
ORDER BY dias_no_programa DESC;

-- 2.6 Distribuição de participantes por programa e status --
-- visão rápida tipo "tabela dinâmica" pra entender a composição
-- geral da base antes de qualquer análise mais profunda.
SELECT
    pr.nome_programa,
    sp.nome_status,
    COUNT(*) AS total
FROM inscricao_programa ip
JOIN programa pr ON pr.id_programa = ip.id_programa
JOIN participante p ON p.id_participante = ip.id_participante
JOIN status_participante sp ON sp.id_status = p.id_status
GROUP BY pr.nome_programa, sp.nome_status
ORDER BY pr.nome_programa, total DESC;

-- 2.7 Top 5 comorbidades mais frequentes -- direciona, por
-- exemplo, se vale a pena ter um profissional de saúde específico
-- de plantão nos dias de treino.
SELECT
    tc.nome_comorbidade,
    COUNT(*) AS total_participantes,
    ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM participante), 1) AS pct_da_base
FROM comorbidade c
JOIN tipo_comorbidade tc ON tc.id_tipo_comorbidade = c.id_tipo_comorbidade
GROUP BY tc.nome_comorbidade
ORDER BY total_participantes DESC
LIMIT 5;
