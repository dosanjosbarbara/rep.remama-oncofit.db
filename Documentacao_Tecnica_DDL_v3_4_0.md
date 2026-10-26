# Documentação Técnica — DDL v3.4.0
## REMAMA / ONcoFITT · Banco de dados PostgreSQL

**Data:** 26/10/2026  
**Versão do script:** DDL_v3_4_0.sql  
**Scripts complementares:** policy_RLS.txt  
**Elaborado por:** Equipe 6 — Validação e Qualidade (QA)

---

## 1. Visão geral

O banco de dados do REMAMA / ONcoFITT é o repositório central de todos os dados operacionais dos dois programas de reabilitação física para mulheres sobreviventes de câncer de mama. Ele armazena cadastro e ficha médica das participantes, atestados, justificativas de falta, frequência, avaliações físicas e controle de acesso, e é a fonte única de dados para o site (Grupo 3), as telas (Grupos 4 e 5) e os painéis analíticos (Grupo 5).

O script `DDL_v3_4_0.sql` cria todas as tabelas, views, funções, triggers, roles, GRANTs por coluna e políticas de RLS em um banco PostgreSQL 16 novo. O arquivo `policy_RLS.txt` complementa o DDL com políticas de RLS para 12 tabelas de catálogo e auditoria que o DDL principal deixava sem política definida (item 2.6 do relatório de validação Sprint 02).

**Fora do escopo do banco** (responsabilidade do backend ou de serviços externos):

- Hash e verificação de senha (bcrypt/Argon2 no backend, ou Supabase Auth via `auth_user_id`)
- Mascaramento LGPD de campos sensíveis
- Regras RN03, RN04, RN07, RF11, RF14
- Fluxo de recuperação de senha (RF01, via Supabase Auth)
- Armazenamento de arquivos (PDFs de atestados e laudos — URLs gravadas no banco)

---

## 2. Histórico de versões

| Versão | Data aprox. | Principais mudanças |
|--------|-------------|----------------------|
| v3.1 | — | Baseline inicial. Erros de seed (Atralgia, IC), falta de GRANT em `nivel_acesso`, campos ausentes declarados no MD. |
| v3.2 | — | Harmonização com especificação MVP2 v2.4. Correção dos erros da v3.1. Implementação de RF04–RF08, RN01–RN02, RN05, RN10–RN13. |
| v3.3 | — | Decisões da coordenação: status global automático (RF07), tabela `barco` (RN12), deferimento de justificativa liberado para `gestao_2`, link de aula via `fn_link_aula`, `auth_user_id` para Supabase Auth. |
| v3.3.1 | — | Grau de linfedema corrigido para 1–4 (revertido na v3.4.0). |
| **v3.4.0** | **26/10/2026** | Correções da validação QA Sprint 02 (ver seção 7). |

---

## 3. Estrutura do banco

O banco contém **32 tabelas**, **9 views** e as principais funções e triggers descritos abaixo.

### 3.1 Tabelas por domínio

| Domínio | Tabelas |
|---------|---------|
| **Catálogos** | `status_participante`, `estado_civil`, `programa`, `tipo_comorbidade`, `variacao_comorbidade`, `tipo_treinamento`, `status_presenca`, `cargo_participante`, `tipo_cancer`, `nivel_acesso`, `barco` |
| **Cadastro** | `participante`, `endereco`, `contato`, `dados_antropometricos` |
| **Ficha médica** | `ficha_medica`, `comorbidade`, `sintoma` |
| **Atestado e justificativa** | `atestado_medico`, `justificativa_falta`, `justificativa_arquivo_versao` |
| **Programa e frequência** | `inscricao_programa`, `aula`, `registro_frequencia`, `evento` |
| **Avaliação física** | `avaliacao` |
| **Treinamento e portfólio** | `treinamento`, `observacao_clinica`, `ocorrencia` |
| **Acesso e auditoria** | `usuario_acesso`, `funcionarios`, `nivel_acesso`, `auditoria_sistema` |

### 3.2 Views

| View | Papel principal | Acesso |
|------|-----------------|--------|
| `vw_poder_usuario` | Nível de acesso e permissões do usuário autenticado | `gestao_1`, `gestao_2` |
| `vw_inscricoes_participante` | Inscrições ativas e históricas por participante | Todos |
| `vw_calendario_aulas` | Aulas futuras não canceladas por programa | Todos |
| `vw_frequencia_programa` | Histórico de presença com status e PSE | Todos |
| `vw_pesquisador_evolucao` | Avaliações com medidas antropométricas na data | `gestao_1`, `gestao_2` |
| `vw_professor_aulas` | Chamadas e presenças por aula | `gestao_1`, `gestao_2` |
| `vw_participante_acompanhamento` | Inscrições e avaliações da própria aluna | `participante` |
| `vw_participante_apto` | Aptidão médica atual e validade do atestado | Todos |
| `vw_assiduidade_programa` | Assiduidade percentual com alerta abaixo de 60% | Todos |

Todas as views usam `SECURITY INVOKER` (PostgreSQL 15+), submetendo as tabelas de origem ao RLS e aos GRANTs do papel que invoca.

### 3.3 Funções principais

| Função | Descrição |
|--------|-----------|
| `app_usuario_id()` | Retorna o `id_usuario` autenticado via `app.id_usuario` (SET LOCAL) |
| `app_nivel_usuario()` | Retorna o nível de acesso do usuário autenticado |
| `app_participante_id()` | Retorna o `id_participante` vinculado ao usuário autenticado (só para `participante`) |
| `fn_participante_apto(id, data)` | Verifica se há atestado aprovado e vigente (≤ 180 dias) na data indicada |
| `fn_recalcular_status_participante(id, retorno)` | Automatiza o ciclo de vida do status global (RF07): Inativa→Ativa, Ativa→Desligada, retorno |
| `fn_link_aula(id_aula)` | Entrega o link Meet/Zoom somente se a aula está em andamento, a aluna tem pré-registro e atestado vigente |
| `fn_cancelar_aula()` | Trigger: bloqueia reativação de aula cancelada, obriga motivo, fixa `cancelada_em` |
| `fn_validar_atestado()` | Trigger: atestado nasce `pendente`; só `gestao_1` aprova/rejeita; data futura rejeitada |
| `fn_analisar_justificativa()` | Trigger: deferimento/indeferimento exclusivo de `gestao_1` (v3.4.0); fixa analista e data |
| `fn_marcar_falta_justificada()` | Trigger: converte F→J no `registro_frequencia` ao deferir a justificativa |
| `fn_validar_frequencia_status()` | Trigger: PRE só pela aluna em aula ONcoFITT; P/F/CSP só pelo professor; P exige atestado vigente (aula e evento, v3.4.0) |
| `fn_auditar_alteracao()` | Trigger em todas as tabelas de negócio: grava INSERT/UPDATE/DELETE em `auditoria_sistema` |

---

## 4. Papéis e permissões

O banco define três roles de aplicação. Nenhum tem `BYPASSRLS` nem é proprietário das tabelas.

| Operação | `app_participante` | `app_gestao_1` | `app_gestao_2` |
|----------|--------------------|----------------|----------------|
| Ler catálogos (programa, status, cargos etc.) | ✓ | ✓ | ✓ |
| Ler/inserir participante | SELECT (colunas restritas), INSERT próprio | ✓ | ✓ |
| Atualizar cadastro próprio (profissão, renda, medicamentos) | ✓ (colunas específicas) | ✓ | ✓ |
| Inserir/atualizar endereço, contato, comorbidade, sintoma | ✓ (próprios) | ✓ | ✓ |
| Gerenciar ficha médica e avaliações | — | ✓ | ✓ |
| Inserir atestado | ✓ (nasce `pendente`) | ✓ | ✓ |
| **Aprovar / rejeitar atestado** | — | **Exclusivo** | — |
| Inserir justificativa | ✓ | ✓ | ✓ |
| **Deferir / indeferir justificativa** | — | **Exclusivo** | — |
| Lançar chamada (P, F, CSP) | — | — | **Exclusivo** |
| Pré-registro (PRE) — ONcoFITT | ✓ (próprio) | — | — |
| Registrar PSE — REMAMA | — | — | ✓ |
| Registrar PSE — ONcoFITT | ✓ (próprio, 24h) | — | ✓ |
| Encerrar inscrição (`data_desligamento`) | — | **Exclusivo** | — |
| Alterar status global (`id_status`) | — | **Exclusivo** | — |
| Alterar CID-O e lateralidade já preenchidos | — | **Exclusivo** | — |
| Cancelar aula | — | **Exclusivo** | — |
| Inserir/atualizar barco | — | ✓ | ✓ |
| Ler auditoria | — | ✓ | ✓ |
| Ler `usuario_acesso` (colunas não sensíveis) | — | ✓ | ✓ |

O backend autentica o usuário, faz `SET LOCAL app.id_usuario = <id>` na sessão e usa o role correspondente ao nível. Nunca deve usar o proprietário das tabelas nem um login com `BYPASSRLS`.

---

## 5. Row Level Security (RLS)

### 5.1 Tabelas com RLS definido no DDL principal

O DDL ativa RLS e cria políticas via loop `DO $$` nas seguintes tabelas de dados pessoais:

`participante` · `endereco` · `contato` · `dados_antropometricos` · `avaliacao` · `ficha_medica` · `comorbidade` · `atestado_medico` · `treinamento` · `evento` · `inscricao_programa` · `registro_frequencia` · `justificativa_falta` · `observacao_clinica` · `ocorrencia` · `justificativa_arquivo_versao` · `sintoma`

**Política padrão gerada pelo loop:**

- `app_participante`: `SELECT USING (id_participante = app_participante_id())` — a aluna só vê os próprios dados.
- `app_gestao_1` e `app_gestao_2`: `ALL USING/WITH CHECK (current_user e app_nivel_usuario() batem com o papel)` — acesso a todas as linhas, mas somente quando o role SQL e o nível autenticado coincidem, prevenindo elevação de privilégio.

**Políticas adicionais declaradas explicitamente no DDL:**

| Tabela | Política | Efeito |
|--------|----------|--------|
| `registro_frequencia` | `aluna_registrar_pse_oncofitt` | Aluna atualiza coluna `pse` somente nas próprias linhas do programa 2 |
| `observacao_clinica` | `aluna_ler_observacao_clinica` | Aluna lê somente anotações que ela mesma escreveu |
| `ocorrencia` | `aluna_ler_ocorrencia` | Idem para ocorrências |
| `observacao_clinica` | `aluna_criar_observacao` | Aluna insere somente com `id_usuario_autor` próprio |
| `ocorrencia` | `aluna_criar_ocorrencia` | Idem |
| `justificativa_falta` | `aluna_enviar_justificativa` | Aluna insere somente para si mesma |
| `justificativa_arquivo_versao` | `aluna_enviar_versao` | Idem |
| `atestado_medico` | `aluna_enviar_atestado` | Aluna insere somente para si mesma |
| `participante` | `aluna_editar_participante` | Aluna edita somente a própria linha |
| `aula` | `aluna_aula` | Aluna vê somente aulas dos programas com inscrição ativa; aulas canceladas só se já tiver frequência |
| `aula` | `equipe_aula` | Gestão vê e edita todas as aulas |
| `usuario_acesso` | `equipe_usuarios` | Gestão lê `usuario_acesso` (sem auto-promoção) |
| `funcionarios` | `equipe_funcionarios` | Gestão lê `funcionarios` |
| `registro_frequencia` | `aluna_pre_registro` | Aluna insere pré-registro somente para si no programa ONcoFITT |

### 5.2 Políticas complementares — arquivo `policy_RLS.txt`

O arquivo complementa o DDL habilitando RLS e criando políticas para **12 tabelas que o DDL deixava sem proteção de linha**. Deve ser executado **após** o DDL principal, dentro da mesma transação ou em seguida.

**Tabelas incluídas:**

`programa` · `nivel_acesso` · `tipo_cancer` · `estado_civil` · `cargo_participante` · `status_participante` · `status_presenca` · `tipo_comorbidade` · `variacao_comorbidade` · `tipo_treinamento` · `barco` · `auditoria_sistema`

**Políticas criadas por tabela:**

| Tabela | Política | Operação | Quem acessa | Condição |
|--------|----------|----------|-------------|----------|
| Catálogos (10 tabelas) | `<tabela>_leitura` | SELECT | Todos os papéis | `USING (true)` — leitura irrestrita dos catálogos públicos |
| `barco` | `barco_inserir_gestao` | INSERT | `gestao_1`, `gestao_2` | Role SQL e nível autenticado devem coincidir |
| `barco` | `barco_atualizar_gestao` | UPDATE | `gestao_1`, `gestao_2` | Idem |
| `auditoria_sistema` | `auditoria_leitura_gestao` | SELECT | `gestao_1`, `gestao_2` | Role SQL e nível autenticado devem coincidir |

> **Nota:** Todas as políticas usam `DROP POLICY IF EXISTS` antes do `CREATE POLICY`, tornando o script idempotente e seguro para reexecução.

---

## 6. Regras de negócio implementadas

| RF/RN | Descrição | Implementação |
|-------|-----------|---------------|
| RF01 | Autenticação por `senha_hash` ou Supabase Auth (`auth_user_id`) | `usuario_acesso`, `ck_usuario_credencial`, `fn_validar_tipo_usuario` |
| RF02 | Cadastro exige nome completo (v3.4.0), CPF, data de nascimento | `participante.nome_completo NOT NULL`, `cpf NOT NULL` |
| RF03 / RN08 | Contato de emergência com nome, telefone e parentesco obrigatórios para ativar a participante | `contato.contato_emergencia_parentesco CHECK`, `fn_proteger_status_global` |
| RF04 / RN09 | Marcos do tratamento oncológico: datas de término de cirurgia, quimio, radio; flags `realizou_*`; hormonioterapia; radioterapia em manutenção bloqueia sem atestado específico | `ficha_medica`, `ck_radioterapia_manutencao`, `fn_participante_apto` |
| RF05 | Sintomas oncológicos (linfedema grau 1–3; neuropatia/dormência) e medicamentos | `sintoma`, `ck_sintoma_campos`, `grau BETWEEN 1 AND 3` |
| RF06 | Atestado: aluna envia, coordenação (`gestao_1`) aprova/rejeita com `motivo_recusa`; justificativa: texto ou anexo, deferida/indeferida somente pela coordenação com `motivo_indeferimento` | `atestado_medico`, `justificativa_falta`, `fn_validar_atestado`, `fn_analisar_justificativa` |
| RF07 | Status global automático: Inativa→Ativa (contato + atestado + inscrição), Ativa→Desligada (última inscrição encerrada), retorno | `fn_recalcular_status_participante`, triggers em `inscricao_programa`, `atestado_medico`, `contato` |
| RF08 / RN11 | Chamada (P/F/CSP) exclusiva do professor; PRE pela aluna no ONcoFITT; PSE REMAMA pelo professor; PSE ONcoFITT pelo professor ou aluna (24 h); link da aula só em andamento com atestado e PRE | `fn_validar_frequencia_status`, `fn_validar_frequencia_pse`, `fn_link_aula` |
| RF09 | Avaliação física: sentar/levantar, flexão de cotovelo (dominante), marcha estacionária, FC de repouso, PSE; testes de flexibilidade em cm (ombros/Apley e tronco/sentar-e-alcançar) | `avaliacao`, `flexibilidade_ombros_cm`, `flexibilidade_tronco_cm` |
| RF10 | Classificação de desempenho em faixas 1–5 calculadas pelo Grupo 5 sobre os resultados brutos | Colunas de texto removidas da `avaliacao` (v3.4.0); faixas calculadas fora do banco |
| RN01 | Assiduidade = P ÷ (total − J − CSP); alerta abaixo de 60% | `vw_assiduidade_programa` |
| RN02 | Atestado aprovado e vigente (≤ 180 dias) para presença P — tanto em aula quanto em evento (v3.4.0) | `fn_participante_apto`, `fn_validar_frequencia_status` |
| RN05 | ONcoFITT: limite de 100 presenças confirmadas por aula | `fn_validar_frequencia_status` |
| RN06 | PA e FC pré/pós-treino opcionais, nunca bloqueiam chamada | `ck_frequencia_pa`, `ck_frequencia_fc` (faixas amplas) |
| RN09 | Aptidão para prática: atestado vigente e tratamento agudo encerrado ou em condição controlada | `fn_participante_apto`, `ficha_medica` |
| RN10 / 2.2 | CID-O e lateralidade já preenchidos: alteração exclusiva da `gestao_1` | `fn_proteger_diagnostico_base` |
| RN12 | Máximo de 1 Capitã ativa por barco | `uq_capita_por_barco` (unique index parcial) |
| RN13 | Tipo de aula: `raia` (REMAMA), `indoor` (REMAMA chuva), `online` (ONcoFITT exclusivo) | `aula.tipo_aula`, `fn_cancelar_aula` |

---

## 7. Correções da v3.4.0

Todas as correções abaixo derivam do relatório de validação da Equipe 6 (QA), sprint 02, de 22/10/2026, com encaminhamentos do Grupo 1 em 21/10/2026.

### 7.1 Regras corrigidas (itens reprovados nos testes)

| Teste | RF/RN | Problema encontrado | Correção aplicada |
|-------|-------|---------------------|-------------------|
| 15 | RF06 | Professor (`gestao_2`) conseguia deferir justificativas, contrariando a especificação v2.4 e o planejamento de UX | `fn_analisar_justificativa` bloqueado para qualquer papel diferente de `gestao_1`; GRANT de UPDATE em `justificativa_falta` removido de `app_gestao_2` |
| 23 | RF05 | Banco aceitava grau de linfedema 4, mas a escala oficial definida pelo Grupo 1 é 1–3 (Leve, Moderado, Grave) | `CHECK (grau BETWEEN 1 AND 3)` na tabela `sintoma`; comentário do script atualizado |
| 24 | RN02 | Trava de atestado vencido só era conferida quando `id_aula IS NOT NULL`; eventos ficavam de fora | `fn_validar_frequencia_status` passou a verificar atestado tanto para aula quanto para evento, usando `data_registro` como referência quando não há aula vinculada |
| 25 | RF02 | Era possível cadastrar participante sem nome completo | `participante.nome_completo` tornado `NOT NULL` |

### 7.2 Campos adicionados por compatibilidade com as telas (item 2.5)

| Tabela | Campo(s) adicionado(s) | Tela(s) relacionada(s) | Grupo responsável pela integração |
|--------|------------------------|------------------------|-----------------------------------|
| `atestado_medico` | `motivo_recusa TEXT` (obrigatório ao rejeitar — `ck_atestado_motivo_recusa`) | L03 — telas 10, 15–18 | Grupo 3 |
| `justificativa_falta` | `motivo_indeferimento TEXT` (obrigatório ao indeferir — `ck_justificativa_motivo_indeferimento`) | L04 — telas 13–16 | Grupo 3 |
| `justificativa_falta` | `observacao_deferimento TEXT` (opcional ao deferir) | L04 — telas 9–12 | Grupo 3 (opcional) |
| `ficha_medica` | `realizou_cirurgia BOOLEAN NOT NULL DEFAULT FALSE` | L05 — telas 4, 5 | Grupo 3 |
| `ficha_medica` | `realizou_quimioterapia BOOLEAN NOT NULL DEFAULT FALSE` | L05 — telas 4, 5 | Grupo 3 |
| `ficha_medica` | `realizou_radioterapia BOOLEAN NOT NULL DEFAULT FALSE` | L05 — telas 4, 5 | Grupo 3 |
| `ficha_medica` | `data_inicio_hormonioterapia DATE`, `data_fim_hormonioterapia DATE` (opcionais; `ck_hormonioterapia_datas` e `ck_hormonioterapia_periodo`) | L05 — telas 1, 2, 4, 5, 8 | Grupo 3 |
| `ficha_medica` | `data_laudo DATE`, `observacao_diagnostico TEXT`, `observacao_recidiva TEXT` (opcionais) | L05 — telas 1, 2, 4, 5, 8 | Grupo 3 |
| `avaliacao` | `amplitude_braco_cm` renomeado para `flexibilidade_ombros_cm`; novo `flexibilidade_tronco_cm DECIMAL(5,2)` | Painéis Grupo 5 — telas 1, 3, 7, 8 | Grupo 5 (alinha nomes dos gráficos) |
| `avaliacao` | Removidos: `classificacao_flexibilidade`, `movimentacao_tronco`, `equilibrio`, `cond_aerobico`, `forca` | Painéis Grupo 5 | Grupo 5 calcula faixas 1–5 sobre resultados brutos |

---

## 8. Pontos de atenção pendentes

Os itens abaixo foram classificados como **Pontos de Atenção** no relatório de validação (item 2.6). Se até a revalidação os grupos não definirem o uso, passam a **Reprovados**.

| Item | Tabela / campo | Situação | Ação necessária |
|------|----------------|----------|-----------------|
| 2.6 #1 | `evento` (tabela completa) + `registro_frequencia.id_evento` | A tabela `evento` e a coluna `id_evento` não aparecem na especificação v2.4 nem nas telas dos Grupos 4 e 5. A trava de atestado RN02 agora cobre eventos (v3.4.0), mas o uso da tabela em si não está definido. | Grupo 2 deve retirar a tabela ou levar o caso de uso ao Grupo 1 para inclusão na especificação oficial. |
| 2.6 #3 | `ficha_medica.tratamentos_realizados TEXT` | Com os campos `realizou_*` criados na v3.4.0, o campo de texto livre `tratamentos_realizados` passa a duplicar a informação de outra forma. | Grupo 2 deve avaliar a remoção ou redefinir o uso (ex.: texto livre complementar às flags). Definir antes da revalidação. |
| 2.6 #4 | `usuario_acesso.senha_hash` | O banco aceita `senha_hash` ou `auth_user_id` (Supabase Auth). Se o projeto adotar Supabase Auth, `senha_hash` fica sem uso e dois caminhos de login aumentam o risco de falha de segurança. | Grupos 2 e 3 devem definir uma forma única de autenticação antes da revalidação. |

---

## 9. Instruções de execução

### 9.1 Pré-requisitos

- PostgreSQL 16 (mínimo 15 para `SECURITY INVOKER` em views).
- Banco novo e vazio, ou banco de teste isolado.
- Conexão como proprietário do schema (não como `app_gestao_1`, `app_gestao_2` nem `app_participante`).
- Logins de aplicação `app_participante`, `app_gestao_1` e `app_gestao_2` criados **antes** de conectar o backend (o DDL cria os roles mas não os logins; logins são provisionados externamente).

### 9.2 Configuração recomendada antes da execução

```sql
ALTER DATABASE <nome_do_banco> SET timezone TO 'America/Sao_Paulo';
```

Isso é necessário porque as regras de vigência de 180 dias do atestado e as janelas de horário das aulas usam datas calculadas em relação ao fuso de São Paulo.

### 9.3 Ordem de execução

```
1. DDL_v3_4_0.sql      — cria toda a estrutura (tabelas, views, funções, triggers,
                          seeds, roles, GRANTs, RLS das tabelas de dados pessoais)

2. policy_RLS.txt       — habilita RLS e cria políticas para os 12 catálogos e
                          a tabela de auditoria (complemento ao DDL principal)
```

Ambos os scripts são **idempotentes na criação de policies** (`DROP POLICY IF EXISTS` no `policy_RLS.txt`). O DDL principal usa `CREATE OR REPLACE` nas funções e triggers, mas as tabelas e constraints não são recriáveis em banco já populado — usar somente em banco novo ou em banco de teste resetado.

### 9.4 Uso em runtime (backend)

```sql
BEGIN;
SET LOCAL ROLE app_gestao_1;  -- ou app_gestao_2 / app_participante
SELECT set_config('app.id_usuario', '<id_validado_pela_api>', true);
-- ... consultas e alterações ...
COMMIT;
```

- Nunca usar o login proprietário das tabelas em operações da aplicação.
- Nunca aceitar `id_usuario` enviado pelo cliente sem validação prévia na API.
- Nunca conceder `BYPASSRLS` a logins de aplicação.
