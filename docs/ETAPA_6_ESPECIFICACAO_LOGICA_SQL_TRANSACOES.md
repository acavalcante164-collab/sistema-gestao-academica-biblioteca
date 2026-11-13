# ETAPA 6: Especificação Lógica de Consultas Analíticas, Views, Triggers e Transações

**Projeto:** Sistema Integrado de Gestão Acadêmica e Biblioteca (SIGAB) — Grupo 06  
**Disciplina:** DCC 502 - Banco de Dados I (UFRR) — Prof. Jean Bertrand  
**Responsável Alonso:** Normalização e Lógica Relacional  
**Referências:** Issues #9, #10, #11 e #12 | Seções 3.5 e 3.6 da Especificação Oficial  

---

## 1. Especificação Lógica das 8 Consultas Analíticas (Issue #9)

Para atender integralmente à Seção 3.5 da especificação do trabalho prático e aos requisitos de negócio do minimundo (`RF11`), foram projetadas 8 consultas analíticas cobrindo todos os operadores exigidos.

### Quadro Resumo de Cobertura do Edital (Seção 3.5)

| Consulta | Título / Objetivo de Negócio | Requisito Técnico Obrigatório Atendido | Tabelas Envolvidas |
|---|---|---|---|
| **Q01** | Desempenho por Disciplina e Índice de Reprovação por Falta | `INNER JOIN` múltiplo + `GROUP BY` + `HAVING` | `DEPARTAMENTO`, `DISCIPLINA`, `TURMA`, `MATRICULA` |
| **Q02** | Mapa de Ocupação do Acervo e Taxa de Empréstimos (Incluindo Obras Nunca Emprestadas) | `LEFT OUTER JOIN` múltiplo + Agregação | `OBRA`, `AUTORIA`, `AUTOR`, `EXEMPLAR`, `EMPRESTIMO` |
| **Q03** | Alunos com Rendimento Superior a Todos os Alunos de Outros Cursos | Subconsulta Independente com Operador de Conjunto (`ALL` / `IN`) | `PESSOA`, `ALUNO`, `CURSO`, `MATRICULA` |
| **Q04** | Usuários Impedidos de Empréstimo por Inadimplência e Retenção de Acervo | Subconsulta Correlacionada com `EXISTS` (RN14) | `PESSOA`, `EMPRESTIMO`, `MULTA` |
| **Q05** | Alunos Aptos a Cursar Disciplinas com Pré-Requisito Pendente de Oferta | Subconsulta Correlacionada com `NOT EXISTS` (RN05) | `ALUNO`, `PESSOA`, `DISCIPLINA`, `PRE_REQUISITO`, `MATRICULA`, `TURMA` |
| **Q06** | Ranking dos Top Alunos por Curso e Comparativo com Média Anterior | Window Functions (`DENSE_RANK() OVER` e `LAG() OVER`) | `PESSOA`, `ALUNO`, `CURSO`, `MATRICULA` |
| **Q07** | Produtividade Docente e Sobrecarga de Turmas no Semestre | `INNER JOIN` + `GROUP BY` + `HAVING` + Subconsulta Escalar | `PROFESSOR`, `PESSOA`, `DEPARTAMENTO`, `TURMA`, `MATRICULA` |
| **Q08** | Fila Crítica de Reservas em Obras com 100% dos Exemplares Emprestados | `INNER JOIN` + `NOT EXISTS` + `GROUP BY` (RN15) | `OBRA`, `RESERVA`, `EXEMPLAR`, `EMPRESTIMO` |

---

### Detalhamento Teórico de cada Consulta (Base para o RUAN)

#### Q01 — Taxa de Reprovação por Falta e Média por Disciplina (`INNER JOIN` + `GROUP BY` + `HAVING`)
* **Pergunta de Negócio:** Quais disciplinas possuem média de reprovação por falta superior a 20% ou média de notas abaixo de 6,0 nos semestres ofertados?
* **Álgebra / Lógica Relacional:**
  1. Realizar junção interna (`INNER JOIN`) entre `DEPARTAMENTO ⋈ DISCIPLINA ⋈ TURMA ⋈ MATRICULA` filtrando `status_matricula = 'ATIVA'` e `nota_final IS NOT NULL`.
  2. Agrupar por `(sigla_depto, codigo_disciplina, nome_disciplina, semestre)`.
  3. Calcular o total de matriculados, a média de `nota_final`, e a contagem condicional `SUM(CASE WHEN frequencia < 75 THEN 1 ELSE 0 END)`.
  4. Filtrar grupos via `HAVING COUNT(*) >= 3` e onde haja ocorrência de reprovação ou média crítica.

#### Q02 — Panorama Completo do Acervo com Obras sem Giro (`LEFT OUTER JOIN`)
* **Pergunta de Negócio:** Qual é a quantidade de exemplares físicos e o total histórico de empréstimos de todas as obras do catálogo, listando inclusive obras recém-adquiridas que nunca possuíram exemplares ou empréstimos?
* **Lógica Relacional:**
  1. Partir da tabela `OBRA` como base à esquerda.
  2. Aplicar `LEFT OUTER JOIN` com `EXEMPLAR (id_obra)` e, em seguida, `LEFT OUTER JOIN` com `EMPRESTIMO (id_obra, numero_exemplar)`.
  3. Agrupar por `id_obra, titulo, tipo, editora`, contabilizando `COUNT(DISTINCT e.numero_exemplar)` para total de cópias e `COUNT(emp.id_emprestimo)` para total de empréstimos.

#### Q03 — Alunos de Destaque Absoluto (`Subconsulta Independente com ALL / IN`)
* **Pergunta de Negócio:** Quais alunos ativos possuem média geral de notas estritamente maior do que a média de **todos** os alunos de um curso específico (ou estão no conjunto de cursos tecnológicos com maior carga horária)?
* **Lógica Relacional:**
  1. Consulta externa agrupa `MATRICULA` por `id_aluno` (unido a `ALUNO`, `PESSOA` e `CURSO`).
  2. Cláusula `WHERE c.id_curso IN (SELECT id_curso FROM CURSO WHERE carga_horaria >= 3000)` filtra os cursos principais.
  3. Cláusula `HAVING AVG(m.nota_final) >= ALL (SELECT AVG(m2.nota_final) FROM MATRICULA m2 JOIN ALUNO a2 ON m2.id_aluno = a2.id_pessoa WHERE m2.nota_final IS NOT NULL GROUP BY a2.id_curso)` compara contra as médias por curso.

#### Q04 — Diagnóstico de Usuários Bloqueados na Biblioteca (`Correlacionada com EXISTS`)
* **Pergunta de Negócio:** Quais usuários (alunos ou professores) estão atualmente bloqueados para novos empréstimos por possuírem pelo menos uma multa não paga (`data_pagamento IS NULL`, conforme RN14)?
* **Lógica Relacional:**
  1. Selecionar dados de identificação em `PESSOA p`.
  2. Filtrar com predicado existencial correlacionado:
     `WHERE EXISTS (SELECT 1 FROM EMPRESTIMO e JOIN MULTA mu ON mu.id_emprestimo = e.id_emprestimo WHERE e.id_pessoa = p.id_pessoa AND mu.data_pagamento IS NULL)`.

#### Q05 — Verificação de Cumprimento Integral de Pré-Requisitos (`Correlacionada com NOT EXISTS` — Divisão Relacional)
* **Pergunta de Negócio:** Para uma determinada disciplina avançada (que exige pré-requisitos), quais alunos já cumpriram **todos** os seus pré-requisitos (aprovados com `nota_final >= 6` e `frequencia >= 75`), mas ainda não cursaram a referida disciplina?
* **Lógica Relacional (Dupla Negação / Divisão de Codd):**
  1. Selecionar o par `(ALUNO a, DISCIPLINA d)` onde `d` possui pelo menos um pré-requisito cadastrado.
  2. Garantir que **não existe** (`NOT EXISTS`) nenhum pré-requisito `pr` da disciplina `d` para o qual **não exista** (`NOT EXISTS`) uma matrícula aprovada do aluno `a`.

#### Q06 — Ranking de Desempenho por Curso e Diferença para o Colocado Anterior (`Window Functions OVER()`)
* **Pergunta de Negócio:** Qual a classificação (ranking denso) de cada aluno dentro do seu respectivo curso com base no Coeficiente de Rendimento (média das notas finais), e qual a diferença de pontuação em relação ao aluno imediatamente acima no ranking?
* **Lógica Relacional:**
  1. CTE (`WITH media_alunos AS (...)`) calcula a média das notas concluídas (`cr_aluno`) por aluno e curso.
  2. Consulta principal aplica funções de janela particionadas por `id_curso`:
     * `DENSE_RANK() OVER (PARTITION BY id_curso ORDER BY cr_aluno DESC) AS posicao_ranking`
     * `LAG(cr_aluno, 1) OVER (PARTITION BY id_curso ORDER BY cr_aluno DESC) AS cr_colocado_acima`
     * `ROUND(cr_aluno - LAG(cr_aluno, 1) OVER (PARTITION BY id_curso ORDER BY cr_aluno DESC), 2) AS diferenca_para_anterior`.

#### Q07 — Relatório de Atrasos e Arrecadação de Multas por Perfil de Usuário (`JOIN` + `GROUP BY`)
* **Pergunta de Negócio:** Qual o volume de empréstimos, média de dias de atraso, valor total de multas geradas, valor quitado e saldo pendente agrupado pelo tipo de vínculo (`ALUNO` vs `PROFESSOR`)?
* **Lógica Relacional:**
  1. Unir `PESSOA ⋈ EMPRESTIMO` e `LEFT JOIN MULTA`.
  2. Agrupar por `p.tipo_pessoa`, calculando `SUM(mu.valor)`, `SUM(CASE WHEN mu.data_pagamento IS NULL THEN mu.valor ELSE 0 END)` (pendente) e média de dias de atraso.

#### Q08 — Demanda Reprimida do Acervo: Obras com Reservas Ativas e Zero Exemplares Disponíveis
* **Pergunta de Negócio:** Quais obras possuem fila de reserva ativa (`situacao = 'ATIVA'`) e comprovadamente não possuem nenhum exemplar disponível na estante?
* **Lógica Relacional:**
  1. Unir `OBRA ⋈ RESERVA` onde `r.situacao = 'ATIVA'`.
  2. Validar via `NOT EXISTS` que não há exemplar daquela obra sem empréstimo em aberto (`data_devolucao IS NULL`).
  3. Agrupar por obra e ordenar pelo tamanho da fila (`COUNT(r.id_reserva) DESC`).

---

## 2. Especificação Lógica das Views (Issue #10)

A Seção 3.5 (item 4) do edital exige pelo menos **2 visões relacionais**: uma visão analítica/de segurança e uma visão com cláusula de proteção de escrita (`WITH READ ONLY` ou `WITH CHECK OPTION`). Criaremos 3 visões estratégicas para cobrir tanto o módulo acadêmico quanto a biblioteca.

### 2.1. `VW_SITUACAO_ACADEMICA` (Visão Analítica, Derivação 3FN e Segurança — `WITH READ ONLY`)
* **Finalidade:**
  1. **Normalização (3FN/FNBC):** Derivar em tempo de execução a situação pedagógica final da matrícula (`APROVADO`, `REPROVADO_NOTA`, `REPROVADO_FALTA`, `TRANCADO`, `CURSANDO`) segundo os parâmetros da **RN08** (nota $\ge 6,0$ e frequência $\ge 75\%$), eliminando dependência transitiva na tabela física `MATRICULA`.
  2. **Segurança de Dados (Seção 1.4 do Minimundo):** Expor os dados de boletim sem revelar dados pessoais sensíveis da tabela `PESSOA` (omite `cpf`, `data_nascimento`, `rua`, `numero`, `bairro`, `cep`).
  3. **Proteção de Escrita:** Declarada com `WITH READ ONLY` para impedir `DML` direto sobre colunas calculadas.

### 2.2. `VW_ACERVO_PENDENCIAS` (Visão Gerencial da Biblioteca — `WITH READ ONLY`)
* **Finalidade:** Consolidar para o bibliotecário todos os empréstimos em atraso ou com multas pendentes (`data_pagamento IS NULL`), calculando os dias corridos de atraso até a data atual (`TRUNC(NVL(data_devolucao, SYSDATE)) - TRUNC(data_prevista_devolucao)`) e indicando o status de bloqueio do usuário (RN13, RN14).

### 2.3. `VW_MATRICULAS_ATIVAS` (Visão Operacional com Proteção de Escrita — `WITH CHECK OPTION`)
* **Finalidade:** Exibir e permitir manutenção apenas de matrículas cujo `status_matricula = 'ATIVA'`, aplicando `WITH CHECK OPTION CONSTRAINT CK_VW_MATRICULA_ATIVA`. Qualquer tentativa de `INSERT` ou `UPDATE` através da view que tente gravar `status_matricula <> 'ATIVA'` é bloqueada pelo Oracle.

---

## 3. Especificação Lógica dos Triggers e Auditoria (Issue #11)

Para atender à Seção 3.6 do edital e às regras críticas `RN04`, `RN05`, `RN10`, `RN11`, `RN12`, `RN13`, `RN14`, `RN15` e `RN16`, projetamos **4 Triggers** em PL/SQL:

### 3.1. `TRG_VALIDA_MATRICULA` (Controle de Vagas e Pré-Requisitos — RN04 e RN05)
* **Tabela Alvo:** `MATRICULA`
* **Momento / Nível:** `BEFORE INSERT ON MATRICULA FOR EACH ROW`
* **Lógica Passo a Passo:**
  1. **Bloqueio pessimista da turma para controle de concorrência:** Executa `SELECT vagas_total, id_disciplina INTO v_vagas_total, v_id_disciplina FROM TURMA WHERE id_turma = :NEW.id_turma FOR UPDATE`. Isso serializa matrículas simultâneas na mesma turma!
  2. **Contagem de ocupação (RN04):** Conta quantas matrículas com `status_matricula = 'ATIVA'` já existem naquela turma. Se `v_ocupadas >= v_vagas_total`, aborta a transação com `RAISE_APPLICATION_ERROR(-20001, 'RN04 Violada: A turma atingiu o limite máximo de vagas.')`.
  3. **Verificação de Pré-Requisitos (RN05):** Verifica se existe na tabela `PRE_REQUISITO` alguma disciplina exigida para `v_id_disciplina` na qual o aluno (`:NEW.id_aluno`) não possua matrícula ativa concluída com `nota_final >= 6.0` e `frequencia >= 75.0`. Se houver pendência, aborta com `RAISE_APPLICATION_ERROR(-20002, 'RN05 Violada: Aluno não cumpriu todos os pré-requisitos da disciplina.')`.

### 3.2. `TRG_VALIDA_EMPRESTIMO` (Bloqueio por Multa, Limite de Cotas, Disponibilidade e Prazo — RN10, RN11, RN12, RN14)
* **Tabela Alvo:** `EMPRESTIMO`
* **Momento / Nível:** `BEFORE INSERT ON EMPRESTIMO FOR EACH ROW`
* **Lógica Passo a Passo:**
  1. **Identificação do Perfil:** Busca `tipo_pessoa` em `PESSOA` (`'A'` = Aluno, `'P'` = Professor).
  2. **Verificação de Multa Pendente (RN14):** Conta registros em `MULTA` associados a empréstimos de `:NEW.id_pessoa` onde `data_pagamento IS NULL`. Se $> 0$, aborta com `RAISE_APPLICATION_ERROR(-20003, 'RN14 Violada: Usuário possui multa pendente na biblioteca.')`.
  3. **Verificação de Exemplar Disponível (RN10):** Conta se o exemplar `(:NEW.id_obra, :NEW.numero_exemplar)` já possui empréstimo com `data_devolucao IS NULL`. Se $> 0$, aborta com `RAISE_APPLICATION_ERROR(-20004, 'RN10 Violada: Este exemplar já se encontra emprestado.')`.
  4. **Verificação de Limite Simultâneo (RN11):** Conta empréstimos em aberto (`data_devolucao IS NULL`) de `:NEW.id_pessoa`. Define limite $= 3$ se `'A'` ou $= 5$ se `'P'`. Se `v_abertos >= v_limite`, aborta com `RAISE_APPLICATION_ERROR(-20005, 'RN11 Violada: Limite máximo de empréstimos simultâneos atingido.')`.
  5. **Cálculo Automático do Prazo (RN12):** Se `:NEW.data_prevista_devolucao` não for informada (ou para padronizar a regra), define `:NEW.data_prevista_devolucao := TRUNC(:NEW.data_emprestimo) + (CASE WHEN v_tipo = 'A' THEN 7 ELSE 15 END)`.

### 3.3. `TRG_GERA_MULTA_DEVOLUCAO` (Cálculo Automático de Multa no Atraso — RN13)
* **Tabela Alvo:** `EMPRESTIMO`
* **Momento / Nível:** `AFTER UPDATE OF data_devolucao ON EMPRESTIMO FOR EACH ROW`
* **Condição (`WHEN`):** `OLD.data_devolucao IS NULL AND NEW.data_devolucao IS NOT NULL`
* **Lógica Passo a Passo:**
  1. Calcula `v_dias_atraso := TRUNC(:NEW.data_devolucao) - TRUNC(:NEW.data_prevista_devolucao)`.
  2. Se `v_dias_atraso > 0`, insere automaticamente na tabela `MULTA` com `valor = v_dias_atraso * 1.00` (R$ 1,00 por dia de atraso conforme RN13) e `data_pagamento = NULL`.

### 3.4. `TRG_AUDITORIA_NOTA` (Trilha de Auditoria de Notas — RN16)
* **Tabela Alvo:** `MATRICULA`
* **Momento / Nível:** `AFTER UPDATE OF nota_final ON MATRICULA FOR EACH ROW`
* **Lógica Passo a Passo:**
  1. Compara se houve mudança real no valor de `nota_final` (tratando nulos com `NVL(:OLD.nota_final, -1) <> NVL(:NEW.nota_final, -1)`).
  2. Insere registro na tabela independente `AUDITORIA_NOTA` gravando `:OLD.id_aluno`, `:OLD.id_turma`, `:OLD.nota_final`, `:NEW.nota_final`, `SYSDATE` e `USER`.

---

## 4. Desenho Teórico do Cenário de Concorrência e Transação (Issue #12)

Para demonstrar as propriedades **ACID** (Atomicidade, Consistência, Isolamento e Durabilidade) no Oracle Database, o roteiro transacional (`sql/06_teste_transacional.sql`) divide-se em dois experimentos formais:

### Experimento 1: Disputa Concorrente pela Última Vaga de uma Turma (`SELECT ... FOR UPDATE`)
* **Estado Inicial de Preparação:**
  * A Turma `id_turma = 505` possui `vagas_total = 2` e já conta com `1` matrícula ativa (resta exatamente **1 última vaga**).
  * Dois alunos aptos (Aluno `1008` na **Sessão A** e Aluno `1009` na **Sessão B**) tentam se matricular simultaneamente nessa última vaga.

#### Linha do Tempo de Execução Concorrente ($T_1 \rightarrow T_6$)

| Instante | Sessão 1 (Secretaria — Terminal A) | Sessão 2 (Portal do Aluno — Terminal B) | Estado dos Bloqueios (Locks no Oracle) |
|---|---|---|---|
| **$T_1$** | Inicia transação e executa:<br>`SELECT vagas_total FROM TURMA WHERE id_turma = 505 FOR UPDATE;` | — | **Sessão 1** adquire bloqueio exclusivo de linha (*Row-X / TX Lock*) sobre `id_turma = 505`. |
| **$T_2$** | — | Tenta reservar a mesma turma:<br>`SELECT vagas_total FROM TURMA WHERE id_turma = 505 FOR UPDATE;`<br>*(ou dispara `INSERT INTO MATRICULA` que aciona a trigger)* | **Sessão 2 entra em espera (BLOCKED)** aguardando a liberação do lock pela Sessão 1. |
| **$T_3$** | Insere a matrícula ocupando a última vaga:<br>`INSERT INTO MATRICULA (id_aluno, id_turma, ...) VALUES (1008, 505, ...);` | *(Continua aguardando em fila)* | Trigger valida `ocupadas (1) < vagas_total (2)` e aceita a inserção na Sessão 1 (vagas ocupadas passa a ser 2/2 na visão da Sessão 1). |
| **$T_4$** | Confirma a transação:<br>`COMMIT;` | *(Desbloqueada imediatamente após o COMMIT da Sessão 1)* | **Sessão 1** persiste a vaga e libera o *TX Lock*. **Sessão 2** adquire o lock e prossegue. |
| **$T_5$** | — | Tenta inserir sua matrícula:<br>`INSERT INTO MATRICULA (id_aluno, id_turma, ...) VALUES (1009, 505, ...);` | A trigger `TRG_VALIDA_MATRICULA` lê o estado já comitado (`ocupadas = 2 = vagas_total`) e **rejeita** com `ORA-20001: RN04 Violada: A turma atingiu o limite máximo de vagas`. |
| **$T_6$** | — | Encerra a transação com `ROLLBACK;` | Consistência preservada: apenas 2 alunos matriculados na turma de capacidade 2. |

---

### Experimento 2: Recuperação Parcial de Transação Complexa com `SAVEPOINT` e `ROLLBACK TO SAVEPOINT`
* **Objetivo:** Demonstrar que uma transação composta por múltiplas operações pode descartar apenas um trecho que sofreu violação de regra de negócio sem perder o trabalho válido anterior.
* **Fluxo Passo a Passo:**
  1. **Início da Transação:** Atualização válida de nota de um aluno em `MATRICULA` (gera automaticamente 1 registro em `AUDITORIA_NOTA`).
  2. **Criação do Ponto de Salvamento:** `SAVEPOINT sp_apos_lancamento_nota;`
  3. **Operação Subsequente Inválida:** Tentativa de inserir nota fora do domínio (`nota_final = 12.5`, violando `CK_MATRICULA_NOTA`) ou tentativa de empréstimo inválido.
  4. **Recuperação Parcial:** Execução de `ROLLBACK TO SAVEPOINT sp_apos_lancamento_nota;` (desfaz apenas o passo 3, preservando a atualização de nota e a auditoria do passo 1).
  5. **Efetivação:** Execução de `COMMIT;` e consulta final comprovando que a primeira alteração e seu log foram gravados com sucesso.