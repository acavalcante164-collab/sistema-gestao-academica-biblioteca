# ETAPA 6: Especificação Lógica de Consultas Analíticas, Views, Triggers e Transações

**Projeto:** Sistema Integrado de Gestão Acadêmica e Biblioteca (SIGAB) — Grupo 06  
**Disciplina:** DCC 502 - Banco de Dados I (UFRR) — Prof. Jean Bertrand  
**Responsável pela Modelagem Lógica:** Alonso Fernandes Cavalcante (Pessoa 2)  
**Referências:** Issues #9, #10, #11 e #12 | Seções 3.5 e 3.6 da Especificação Oficial  

---

## 1. Especificação Lógica das Visões Relacionais (Issue #10 — `sql/03_views.sql`)

Conforme a Seção 3.5 (item 4) do edital e a decisão de normalização na Etapa 4 (eliminação da dependência transitiva em `MATRICULA`), o sistema implementa três visões estratégicas:

| View | Classificação no Edital | Tabelas-Base | Regra de Negócio / Objetivo |
|---|---|---|---|
| **`VW_SITUACAO_ACADEMICA`** | Visão Analítica e de Segurança (`WITH READ ONLY`) | `MATRICULA`, `ALUNO`, `PESSOA`, `CURSO`, `TURMA`, `DISCIPLINA` | **Fonte única da verdade da RN08:** Calcula dinamicamente a coluna `situacao_final_calculada` (`'APROVADO'`, `'REPROVADO_NOTA'`, `'REPROVADO_FALTA'`, `'TRANCADO'`, `'CURSANDO'`) e oculta dados pessoais sensíveis (`cpf`, `rua`, `numero`, `bairro`, `cep`). |
| **`VW_MATRICULAS_ATIVAS`** | Visão com Proteção de Escrita (`WITH CHECK OPTION`) | `MATRICULA` | Filtra registros onde `status_matricula = 'ATIVA'` e utiliza `WITH CHECK OPTION CONSTRAINT CK_VW_MATRICULA_ATIVA` para impedir que operações DML pela view alterem o status para fora do domínio ativo. |
| **`VW_ACERVO_PENDENCIAS`** | Visão Gerencial Bibliotecária (`WITH READ ONLY`) | `EMPRESTIMO`, `PESSOA`, `OBRA`, `MULTA` | Lista todos os empréstimos não devolvidos ou com multa pendente (`data_pagamento IS NULL`), calculando os dias de atraso correntes e a situação de bloqueio (`RN13`, `RN14`). |

---

## 2. Especificação Lógica dos Gatilhos / Triggers (Issue #11 — `sql/04_triggers.sql`)

Para eliminar o erro `ORA-04091 (table is mutating)` do Oracle tanto em `UPDATE` quanto em inserções em lote (`INSERT ALL` / `INSERT ... SELECT`), as triggers que consultam a própria tabela (`MATRICULA` e `EMPRESTIMO`) utilizam a arquitetura **`COMPOUND TRIGGER`** do Oracle Database:

| Trigger | Evento e Tipo | Regra Atendida | Lógica Teórica de Validação e Exceções |
|---|---|---|---|
| **`TRG_VALIDA_MATRICULA`** | `FOR INSERT OR UPDATE OF status_matricula, id_turma, id_aluno ON MATRICULA COMPOUND TRIGGER` | **RN04** (Capacidade) e **RN05** (Pré-requisitos via **RN08**) | 1. **Gatilho em Inserção e Reativação:** Dispara sempre que `:NEW.status_matricula = 'ATIVA'` (cobrindo tanto `INSERT` quanto `UPDATE` de `'TRANCADA'` para `'ATIVA'`).<br>2. **`BEFORE EACH ROW`:** Aplica `SELECT vagas_total, id_disciplina FROM TURMA WHERE id_turma = :NEW.id_turma FOR UPDATE` (serializando sessões concorrentes).<br>3. **`AFTER STATEMENT`:** Conta `MATRICULA` com `status_matricula = 'ATIVA'`. Se `> vagas_total`, aborta com `RAISE_APPLICATION_ERROR(-20001, ...)`. Verifica em `PRE_REQUISITO` se toda disciplina exigida consta em **`VW_SITUACAO_ACADEMICA`** com `situacao_final_calculada = 'APROVADO'`. Caso contrário, lança `RAISE_APPLICATION_ERROR(-20002, ...)`. |
| **`TRG_VALIDA_EMPRESTIMO`** | `FOR INSERT ON EMPRESTIMO COMPOUND TRIGGER` | **RN10**, **RN11**, **RN12** e **RN14** | 1. **`BEFORE EACH ROW`:** Bloqueia a linha em `EXEMPLAR` (`FOR UPDATE`). Verifica em `MULTA` se o usuário possui registro com `data_pagamento IS NULL`; se houver, lança `RAISE_APPLICATION_ERROR(-20003, ...)`. Sobrescreve **incondicionalmente** `:NEW.data_prevista_devolucao := TRUNC(:NEW.data_emprestimo) + v_prazo_dias` (+7 dias se `'A'`, +15 dias se `'P'`), garantindo a determinância funcional da RN12 (FNBC).<br>2. **`AFTER STATEMENT`:** Verifica se o exemplar tem mais de 1 empréstimo com `data_devolucao IS NULL` (`-20004`, RN10) e se o total de empréstimos em aberto do usuário excede 3 (Aluno) ou 5 (Professor) (`-20005`, RN11). |
| **`TRG_GERA_MULTA_DEVOLUCAO`** | `AFTER UPDATE OF data_devolucao ON EMPRESTIMO FOR EACH ROW` | **RN13** (Multa R$ 1,00/dia) | Quando `OLD.data_devolucao IS NULL AND NEW.data_devolucao IS NOT NULL`, calcula `v_dias := TRUNC(:NEW.data_devolucao) - TRUNC(:NEW.data_prevista_devolucao)`. Se `v_dias > 0`, insere automaticamente na tabela `MULTA` com `valor = v_dias * 1.00`. |
| **`TRG_AUDITORIA_NOTA`** | `AFTER UPDATE OF nota_final ON MATRICULA FOR EACH ROW` | **RN16** e **RF10** (Trilha de Auditoria) | Quando `NVL(OLD.nota_final, -1) <> NVL(NEW.nota_final, -1)`, insere registro imutável em `AUDITORIA_NOTA` contendo `id_aluno`, `id_turma`, `nota_anterior`, `nota_nova`, `SYSDATE` e `USER`. |

---

## 3. Especificação Lógica das 8 Consultas Analíticas (Issue #9 — `sql/05_consultas_analiticas.sql`)

Todas as exigências da Seção 3.5 do edital estão cobertas e sincronizadas com o script `sql/05_consultas_analiticas.sql`:

| ID | Título e Objetivo Gerencial | Requisito do Edital (Seção 3.5) | Tabelas / Views Envolvidas | Lógica Relacional e Filtros |
|---|---|---|---|---|
| **Q01** | Taxa de reprovação por falta e por nota por disciplina | Junções Múltiplas (`INNER JOIN`) + `GROUP BY` + `HAVING` | `VW_SITUACAO_ACADEMICA`, `DISCIPLINA`, `DEPARTAMENTO` | Agrupa por departamento e disciplina usando a view `VW_SITUACAO_ACADEMICA` (fonte única da RN08) e filtra disciplinas com `HAVING COUNT(*) >= 3`. |
| **Q02** | Giro de acervo completo (com autores e obras sem empréstimo) | Junções Múltiplas (`INNER JOIN` e `LEFT OUTER JOIN`) + `LISTAGG` | `OBRA`, `AUTORIA`, `AUTOR`, `EXEMPLAR`, `EMPRESTIMO`, `RESERVA` | Consolida autores via `AUTORIA`/`AUTOR` e preserva todas as obras via `LEFT OUTER JOIN`, exibindo total de exemplares, empréstimos históricos e reservas ativas. |
| **Q03** | Alunos de cursos com carga horária $\ge 3000\text{h}$ com média superior às médias departamentais | Subconsulta independente com operadores de conjunto (`IN` e `ALL`) | `ALUNO`, `PESSOA`, `CURSO`, `MATRICULA`, `TURMA`, `DISCIPLINA` | Filtra `id_curso IN (SELECT id_curso FROM CURSO WHERE carga_horaria >= 3000)` e compara `HAVING AVG(nota_final) >= ALL (...)`. |
| **Q04** | Alunos com matrícula ativa no semestre e bloqueados na biblioteca por multa pendente | Subconsulta correlacionada com `EXISTS` | `ALUNO`, `PESSOA`, `CURSO`, `MATRICULA`, `EMPRESTIMO`, `MULTA` | Aplica duplo `EXISTS` correlacionado ao `a.id_pessoa`: um validando matrícula `'ATIVA'` e outro validando multa com `data_pagamento IS NULL`. |
| **Q05** | Alunos aptos a cursar disciplinas com pré-requisitos (Divisão Relacional) | Subconsulta correlacionada com `NOT EXISTS` | `ALUNO`, `PESSOA`, `CURSO`, `DISCIPLINA`, `PRE_REQUISITO`, `VW_SITUACAO_ACADEMICA` | Seleciona disciplinas com pré-requisitos onde `NOT EXISTS` pré-requisito não aprovado pelo aluno em `VW_SITUACAO_ACADEMICA` e `NOT EXISTS` matrícula já aprovada/em curso na disciplina-alvo. |
| **Q06** | Ranking de alunos por curso e diferença para o colocado imediatamente acima | Window Functions com cláusula `OVER()` (`DENSE_RANK`, `LAG`, `AVG`) | `ALUNO`, `PESSOA`, `CURSO`, `MATRICULA` | Particiona por `id_curso` (`PARTITION BY id_curso ORDER BY media_aluno DESC`) calculando posição no ranking, média do curso e diferença via `LAG()`. |
| **Q07** | Indicadores de atraso, média de dias de retenção e multas por perfil de usuário | Agregação Analítica com `GROUP BY`, `CASE` e funções estatísticas | `PESSOA`, `EMPRESTIMO`, `MULTA` | Compara os perfis `'A'` (Aluno) e `'P'` (Professor) quanto ao total de empréstimos, média de dias de atraso, total de multas geradas e saldo pendente. |
| **Q08** | Fila prioritária de reservas ativas para obras sem exemplares disponíveis (`RN15`) | Window Function (`ROW_NUMBER() OVER`) + Subconsulta Correlacionada `NOT EXISTS` | `RESERVA`, `OBRA`, `PESSOA`, `EXEMPLAR`, `EMPRESTIMO` | Numera a ordem de atendimento por obra (`PARTITION BY id_obra ORDER BY data_reserva ASC`) e valida via `NOT EXISTS` que a obra não possui exemplar livre. |

---

## 4. Desenho Teórico do Cenário de Concorrência e Transação (Issue #12 — `sql/06_teste_transacional.sql`)

### 4.1. Parte A: Disputa Concorrente pela Última Vaga (`SELECT ... FOR UPDATE`)
* **Pré-condição:** A Turma `id_turma = 501` encontra-se com `vagas_total - 1` matrículas ativas (resta exatamente **1 vaga**). Dois alunos (`id_aluno = 1009` na **Sessão 1** e `id_aluno = 1010` na **Sessão 2**) tentam se matricular simultaneamente.

| Instante | Sessão 1 (Aluno `1009`) | Sessão 2 (Aluno `1010`) | Estado de Bloqueio / Isolamento no Oracle |
|---|---|---|---|
| **$T_1$** | `SELECT vagas_total FROM TURMA WHERE id_turma = 501 FOR UPDATE;` | — | Sessão 1 adquire bloqueio exclusivo de linha (*Row-X Lock / TX*) sobre `id_turma = 501`. |
| **$T_2$** | — | `INSERT INTO MATRICULA (id_aluno, id_turma, status_matricula) VALUES (1010, 501, 'ATIVA');` | A trigger `TRG_VALIDA_MATRICULA` na Sessão 2 executa `SELECT ... FOR UPDATE` na turma `501` e entra em **WAIT (bloqueada)** aguardando a Sessão 1. |
| **$T_3$** | `INSERT INTO MATRICULA (id_aluno, id_turma, status_matricula) VALUES (1009, 501, 'ATIVA');` | *(Em espera...)* | A Sessão 1 preenche a última vaga disponível (`vagas_ativas = vagas_total`). |
| **$T_4$** | `COMMIT;` | *(Desbloqueada imediatamente)* | Sessão 1 confirma a matrícula de `1009` e libera o lock. A Sessão 2 retoma a execução, lê o estado comitado no `AFTER STATEMENT` da trigger, detecta `vagas_ativas > vagas_total` e sofre aborto automático com **`ORA-20001: RN04 Violada`**. |
| **$T_5$** | — | `ROLLBACK;` | Sessão 2 encerra a transação limpa. Apenas o aluno `1009` ocupa a última vaga. |

### 4.2. Parte B: Recuperação Parcial de Transação com `SAVEPOINT` e `ROLLBACK TO SAVEPOINT`
1. Inicia-se uma transação na Sessão 1 atualizando a nota do aluno `1009` na turma `501` para `8.50` (o que dispara `TRG_AUDITORIA_NOTA`).
2. Cria-se o marco transacional: `SAVEPOINT sp_nota_lancada;`.
3. Tenta-se realizar uma operação inválida na sequência (ex.: inserir matrícula duplicada ou nota `15.00` que viola `CK_MATRICULA_NOTA` com erro `ORA-02290`).
4. Executa-se `ROLLBACK TO SAVEPOINT sp_nota_lancada;`, desfazendo apenas a operação falha e preservando a atualização da nota `8.50` e seu respectivo registro em `AUDITORIA_NOTA`.
5. Executa-se `COMMIT;` confirmando o estado consistente no banco.