# ETAPA 5: Dicionário de Dados do Modelo Relacional

**Projeto:** Sistema Integrado de Gestão Acadêmica e Biblioteca (SIGAB) — Grupo 06  
**Disciplina:** DCC 502 - Banco de Dados I (UFRR)  
**SGBD:** Oracle Database (`VARCHAR2`, `NUMBER`, `DATE`, `CHAR`)  
**Milestone:** M2 - Modelo Relacional e Normalização (Issue #6)  

---

## 1. Padrões de Nomenclatura e Comportamento Referencial no Oracle

* **Nomes de Tabelas:** Maiúsculas e no singular (`PESSOA`, `MATRICULA`, `AUDITORIA_NOTA`).
* **Constraints Nomeadas (RNF02, RNF06):** `PK_<TABELA>`, `FK_<ORIGEM>_<DESTINO>`, `UQ_<TABELA>_<COLUNA>`, `CK_<TABELA>_<REGRA>`.
* **Ações Referenciais no Oracle Database (Item 3.3 da Especificação):**
  1. **`ON DELETE CASCADE`:** Declarado explicitamente em entidades fracas (`EXEMPLAR`), subtipos (`ALUNO`, `PROFESSOR`), atributos multivalorados (`TELEFONE_PESSOA`) e tabelas associativas dependentes.
  2. **`ON DELETE SET NULL`:** Declarado explicitamente em relacionamentos onde a remoção do registro pai preserva o histórico do registro filho tornando a referência nula (ex.: `TURMA.id_professor` — caso um docente seja desligado ou desvinculado, a oferta da turma não é perdida, ficando com professor "a definir" / `NULL`).
  3. **Comportamento Padrão do Oracle (Omissão de cláusula `ON DELETE`):** O Oracle SQL não possui a sintaxe `ON DELETE RESTRICT`. Quando a cláusula `ON DELETE` é omitida no DDL, o SGBD aplica nativamente a restrição de integridade (rejeitando a exclusão do pai com o erro `ORA-02292: integrity constraint violated - child record found`). Usado para proteger o histórico acadêmico e de empréstimos.

---

## 2. Detalhamento das Tabelas e Colunas

### 2.1. Tabela `DEPARTAMENTO`
**Finalidade:** Unidades acadêmicas que ofertam cursos e disciplinas (R1, R2) e lotam professores (R16).

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_departamento` | `NUMBER(10)` | `NOT NULL` | `PK_DEPARTAMENTO` | Identificador único do departamento. | `1` |
| `nome` | `VARCHAR2(100)` | `NOT NULL` | `UQ_DEPARTAMENTO_NOME` | Nome completo do departamento. | `'Departamento de Ciência da Computação'` |
| `sigla` | `VARCHAR2(10)` | `NOT NULL` | `UQ_DEPARTAMENTO_SIGLA` | Sigla oficial do departamento. | `'DCC'` |

---

### 2.2. Tabela `CURSO`
**Finalidade:** Cursos de graduação ofertados por um departamento (R1, RN02).

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_curso` | `NUMBER(10)` | `NOT NULL` | `PK_CURSO` | Identificador único do curso. | `10` |
| `nome` | `VARCHAR2(100)` | `NOT NULL` | `UQ_CURSO_NOME` | Nome oficial do curso. | `'Ciência da Computação'` |
| `carga_horaria` | `NUMBER(5)` | `NOT NULL` | `CK_CURSO_CH` (`carga_horaria > 0`) | Carga horária total do curso em horas. | `3200` |
| `id_departamento` | `NUMBER(10)` | `NOT NULL` | `FK_CURSO_DEPARTAMENTO` *(Padrão Oracle)* | Departamento responsável pelo curso (R1). | `1` |

---

### 2.3. Tabela `DISCIPLINA`
**Finalidade:** Disciplinas ofertadas pelos departamentos nas grades curriculares (R2).

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_disciplina` | `NUMBER(10)` | `NOT NULL` | `PK_DISCIPLINA` | Identificador único da disciplina. | `100` |
| `codigo` | `VARCHAR2(10)` | `NOT NULL` | `UQ_DISCIPLINA_CODIGO` | Código identificador da disciplina. | `'DCC502'` |
| `nome` | `VARCHAR2(100)` | `NOT NULL` | — | Nome da disciplina. | `'Banco de Dados I'` |
| `carga_horaria` | `NUMBER(4)` | `NOT NULL` | `CK_DISCIPLINA_CH` (`carga_horaria > 0`) | Carga horária semestral em horas. | `60` |
| `id_departamento` | `NUMBER(10)` | `NOT NULL` | `FK_DISCIPLINA_DEPARTAMENTO` *(Padrão Oracle)* | Departamento ofertante da disciplina (R2). | `1` |

---

### 2.4. Tabela `PRE_REQUISITO`
**Finalidade:** Tabela associativa que resolve o auto-relacionamento `N:M` (R8) de pré-requisitos entre disciplinas (RF02, RN05).

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_disciplina` | `NUMBER(10)` | `NOT NULL` | `PK_PRE_REQUISITO` (1/2), `FK_PREREQ_DISCIPLINA` (`ON DELETE CASCADE`) | Disciplina que exige o pré-requisito. | `100` |
| `id_disciplina_req`| `NUMBER(10)` | `NOT NULL` | `PK_PRE_REQUISITO` (2/2), `FK_PREREQ_DISC_EXIGIDA` (`ON DELETE CASCADE`), `CK_PREREQ_DISTINTO` (`id_disciplina <> id_disciplina_req`) | Disciplina que deve ser cumprida previamente. | `90` |

---

### 2.5. Tabela `PESSOA`
**Finalidade:** Entidade supertipo que unifica o cadastro de alunos e professores (R15, RN01). Inclui constraint composta `UQ_PESSOA_ID_TIPO (id_pessoa, tipo_pessoa)` para garantir disjunção relacional nos subtipos.

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_pessoa` | `NUMBER(10)` | `NOT NULL` | `PK_PESSOA`, `UQ_PESSOA_ID_TIPO` (1/2) | Identificador único da pessoa. | `1001` |
| `cpf` | `CHAR(11)` | `NOT NULL` | `UQ_PESSOA_CPF`, `CK_PESSOA_CPF` (`REGEXP_LIKE(cpf, '^[0-9]{11}$')`) | CPF da pessoa (apenas 11 dígitos numéricos). | `'01234567890'` |
| `nome` | `VARCHAR2(120)` | `NOT NULL` | — | Nome completo da pessoa. | `'Ana Carolina Souza'` |
| `data_nascimento` | `DATE` | `NOT NULL` | — | Data de nascimento. | `DATE '2003-04-15'` |
| `email` | `VARCHAR2(100)` | `NOT NULL` | `UQ_PESSOA_EMAIL` | Endereço de e-mail único. | `'ana.souza@ufrr.br'` |
| `tipo_pessoa` | `CHAR(1)` | `NOT NULL` | `UQ_PESSOA_ID_TIPO` (2/2), `CK_PESSOA_TIPO` (`tipo_pessoa IN ('A', 'P')`) | Discriminador da especialização: `'A'` (Aluno) ou `'P'` (Professor) (RN01). | `'A'` |
| `rua` | `VARCHAR2(120)` | `NOT NULL` | — | Endereço (composto): Logradouro/Rua. | `'Av. Ville Roy'` |
| `numero` | `VARCHAR2(15)` | `NOT NULL` | — | Endereço (composto): Número predial. | `'1540'` |
| `bairro` | `VARCHAR2(60)` | `NOT NULL` | — | Endereço (composto): Bairro. | `'Caçari'` |
| `cidade` | `VARCHAR2(60)` | `NOT NULL` | — | Endereço (composto): Cidade. | `'Boa Vista'` |
| `cep` | `CHAR(8)` | `NOT NULL` | `CK_PESSOA_CEP` (`REGEXP_LIKE(cep, '^[0-9]{8}$')`) | Endereço (composto): CEP (8 dígitos). | `'69307000'` |

---

### 2.6. Tabela `TELEFONE_PESSOA`
**Finalidade:** Relação resultante do mapeamento do atributo multivalorado `telefone` de `PESSOA` (1FN, RF01).

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_pessoa` | `NUMBER(10)` | `NOT NULL` | `PK_TELEFONE_PESSOA` (1/2), `FK_TELEFONE_PESSOA` (`ON DELETE CASCADE`) | Identificador da pessoa titular do telefone. | `1001` |
| `telefone` | `VARCHAR2(15)` | `NOT NULL` | `PK_TELEFONE_PESSOA` (2/2) | Número de telefone com DDD. | `'95991112233'` |

---

### 2.7. Tabela `ALUNO`
**Finalidade:** Subtipo de `PESSOA` (R15) vinculado a um curso (R3, RN01, RN02). Garante disjunção via FK composta `(id_pessoa, tipo_pessoa)` com `tipo_pessoa = 'A'`.

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_pessoa` | `NUMBER(10)` | `NOT NULL` | `PK_ALUNO`, `FK_ALUNO_PESSOA` (1/2, `ON DELETE CASCADE`) | Identificador herdado de `PESSOA`. | `1001` |
| `tipo_pessoa` | `CHAR(1)` | `NOT NULL` | `DEFAULT 'A'`, `CK_ALUNO_TIPO` (`tipo_pessoa = 'A'`), `FK_ALUNO_PESSOA` (2/2) | Constante `'A'` para garantir disjunção com `PROFESSOR`. | `'A'` |
| `matricula` | `VARCHAR2(15)` | `NOT NULL` | `UQ_ALUNO_MATRICULA` | Matrícula acadêmica única (chave candidata). | `'2024005534'` |
| `data_ingresso` | `DATE` | `NOT NULL` | — | Data de ingresso no curso. | `DATE '2024-03-01'` |
| `id_curso` | `NUMBER(10)` | `NOT NULL` | `FK_ALUNO_CURSO` *(Padrão Oracle)* | Curso ao qual o aluno pertence (R3). | `10` |

---

### 2.8. Tabela `PROFESSOR`
**Finalidade:** Subtipo de `PESSOA` (R15) lotado em um departamento (R16, RN01). Garante disjunção via FK composta `(id_pessoa, tipo_pessoa)` com `tipo_pessoa = 'P'`.

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_pessoa` | `NUMBER(10)` | `NOT NULL` | `PK_PROFESSOR`, `FK_PROFESSOR_PESSOA` (1/2, `ON DELETE CASCADE`) | Identificador herdado de `PESSOA`. | `2001` |
| `tipo_pessoa` | `CHAR(1)` | `NOT NULL` | `DEFAULT 'P'`, `CK_PROFESSOR_TIPO` (`tipo_pessoa = 'P'`), `FK_PROFESSOR_PESSOA` (2/2) | Constante `'P'` para garantir disjunção com `ALUNO`. | `'P'` |
| `titulacao` | `VARCHAR2(30)` | `NOT NULL` | `CK_PROFESSOR_TITULACAO` (`titulacao IN ('GRADUADO', 'ESPECIALISTA', 'MESTRE', 'DOUTOR')`) | Titulação acadêmica do docente. | `'DOUTOR'` |
| `data_admissao` | `DATE` | `NOT NULL` | — | Data de admissão na instituição. | `DATE '2016-08-10'` |
| `id_departamento` | `NUMBER(10)` | `NOT NULL` | `FK_PROFESSOR_DEPARTAMENTO` *(Padrão Oracle)* | Departamento de lotação do docente (R16). | `1` |

---

### 2.9. Tabela `TURMA`
**Finalidade:** Oferta semestral de uma disciplina (R4, R5, RN03, RN04). Possui horários decompostos em atributos atômicos (1FN) e aplica `ON DELETE SET NULL` em `id_professor` (caso o docente seja removido, a turma permanece registrada com docente a definir).

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_turma` | `NUMBER(10)` | `NOT NULL` | `PK_TURMA` | Identificador único da turma. | `501` |
| `id_disciplina` | `NUMBER(10)` | `NOT NULL` | `FK_TURMA_DISCIPLINA` *(Padrão Oracle)* | Disciplina ofertada na turma (R4). | `100` |
| `id_professor` | `NUMBER(10)` | `NULL` | `FK_TURMA_PROFESSOR` (`ON DELETE SET NULL`) | Professor responsável (`NULL` se docente desligado/a definir). | `2001` |
| `semestre` | `VARCHAR2(6)` | `NOT NULL` | `CK_TURMA_SEMESTRE` (`REGEXP_LIKE(semestre, '^[0-9]{4}\.[1-2]$')`) | Semestre letivo no formato `AAAA.S`. | `'2026.2'` |
| `vagas_total` | `NUMBER(3)` | `NOT NULL` | `CK_TURMA_VAGAS` (`vagas_total > 0`) | Capacidade máxima de alunos na turma (RN04). | `40` |
| `sala` | `VARCHAR2(30)` | `NOT NULL` | — | Sala ou laboratório de aula. | `'Lab 02 - DCC'` |
| `dia_semana` | `VARCHAR2(15)` | `NOT NULL` | `CK_TURMA_DIA` (`dia_semana IN ('SEG', 'TER', 'QUA', 'QUI', 'SEX', 'SAB', 'SEG-QUA', 'TER-QUI')`) | Dia(s) de realização do encontro semanal (1FN). | `'SEG-QUA'` |
| `hora_inicio` | `CHAR(5)` | `NOT NULL` | `CK_TURMA_HINI` (`REGEXP_LIKE(hora_inicio, '^[0-2][0-9]:[0-5][0-9]$')`) | Horário de início da aula (`HH:MM`). | `'14:00'` |
| `hora_fim` | `CHAR(5)` | `NOT NULL` | `CK_TURMA_HFIM` (`REGEXP_LIKE(hora_fim, '^[0-2][0-9]:[0-5][0-9]$') AND hora_fim > hora_inicio`) | Horário de término da aula (`HH:MM`). | `'16:00'` |

---

### 2.10. Tabela `MATRICULA`
**Finalidade:** Entidade associativa (`ALUNO × TURMA`, R6) identificada pelo par `(id_aluno, id_turma)` (RN06). Armazena apenas `status_matricula IN ('ATIVA', 'TRANCADA')`; a situação pedagógica (`APROVADO`, `REPROVADO_NOTA`, `REPROVADO_FALTA`, `CURSANDO`, `TRANCADO`) é derivada na view `VW_SITUACAO_ACADEMICA` (3FN/FNBC e Issue #10).

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_aluno` | `NUMBER(10)` | `NOT NULL` | `PK_MATRICULA` (1/2), `FK_MATRICULA_ALUNO` *(Padrão Oracle)* | Aluno matriculado na turma (R6). | `1001` |
| `id_turma` | `NUMBER(10)` | `NOT NULL` | `PK_MATRICULA` (2/2), `FK_MATRICULA_TURMA` *(Padrão Oracle)* | Turma na qual o aluno se matriculou (R6). | `501` |
| `data_matricula` | `DATE` | `NOT NULL` | `DEFAULT SYSDATE` | Data de efetivação da matrícula. | `SYSDATE` |
| `nota_final` | `NUMBER(4,2)` | `NULL` | `CK_MATRICULA_NOTA` (`nota_final BETWEEN 0 AND 10`) | Nota final entre 0,00 e 10,00 (RN07). | `8.50` |
| `frequencia` | `NUMBER(5,2)` | `NULL` | `CK_MATRICULA_FREQ` (`frequencia BETWEEN 0 AND 100`) | Percentual de frequência entre 0 e 100% (RN07). | `85.00` |
| `status_matricula`| `VARCHAR2(10)` | `NOT NULL` | `DEFAULT 'ATIVA'`, `CK_MATRICULA_STATUS` (`status_matricula IN ('ATIVA', 'TRANCADA')`) | Estado operacional do vínculo da matrícula (3FN). | `'ATIVA'` |

---

### 2.11. Tabela `AUDITORIA_NOTA`
**Finalidade:** Trilha de auditoria imutável gerada via Trigger para alterações de nota em `MATRICULA` (R7, RF10, RN16).
* **Decisão Arquitetural de Auditoria:** As colunas `id_aluno` e `id_turma` **não possuem constraint de FK** para `MATRICULA` (nem `ON DELETE CASCADE`), garantindo que o histórico de auditoria sobreviva integralmente no banco mesmo que um registro de matrícula venha a ser excluído.

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_auditoria` | `NUMBER(10)` | `NOT NULL` | `PK_AUDITORIA_NOTA` | Identificador único do registro de auditoria. | `1` |
| `id_aluno` | `NUMBER(10)` | `NOT NULL` | *(Sem FK — preservação histórica de log)* | Identificador do aluno da matrícula auditada. | `1001` |
| `id_turma` | `NUMBER(10)` | `NOT NULL` | *(Sem FK — preservação histórica de log)* | Identificador da turma da matrícula auditada. | `501` |
| `nota_anterior` | `NUMBER(4,2)` | `NULL` | — | Valor da nota antes da alteração. | `5.50` |
| `nota_nova` | `NUMBER(4,2)` | `NULL` | — | Novo valor atribuído à nota. | `7.00` |
| `data_alteracao` | `DATE` | `NOT NULL` | `DEFAULT SYSDATE` | Timestamp da alteração (RN16). | `SYSDATE` |
| `usuario` | `VARCHAR2(60)` | `NOT NULL` | `DEFAULT USER` | Usuário do banco que executou a operação. | `'SYSTEM'` |

---

### 2.12. Tabela `OBRA`
**Finalidade:** Títulos bibliográficos do acervo da biblioteca (RF06).

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_obra` | `NUMBER(10)` | `NOT NULL` | `PK_OBRA` | Identificador único da obra no acervo. | `301` |
| `titulo` | `VARCHAR2(200)` | `NOT NULL` | — | Título da obra. | `'Database System Concepts'` |
| `tipo` | `VARCHAR2(20)` | `NOT NULL` | `CK_OBRA_TIPO` (`tipo IN ('LIVRO', 'PERIODICO', 'TCC')`) | Classificação do material bibliográfico. | `'LIVRO'` |
| `ano_publicacao` | `NUMBER(4)` | `NOT NULL` | `CK_OBRA_ANO` (`ano_publicacao > 1500`) | Ano de publicação. | `2019` |
| `editora` | `VARCHAR2(100)` | `NULL` | — | Nome da editora ou instituição. | `'McGraw-Hill'` |

---

### 2.13. Tabela `AUTOR`
**Finalidade:** Autores das obras pertencentes ao acervo (RF06).

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_autor` | `NUMBER(10)` | `NOT NULL` | `PK_AUTOR` | Identificador único do autor. | `50` |
| `nome` | `VARCHAR2(120)` | `NOT NULL` | — | Nome completo do autor. | `'Abraham Silberschatz'` |

---

### 2.14. Tabela `AUTORIA`
**Finalidade:** Tabela associativa que resolve o relacionamento `N:M` (R9) entre `OBRA` e `AUTOR`.

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_obra` | `NUMBER(10)` | `NOT NULL` | `PK_AUTORIA` (1/2), `FK_AUTORIA_OBRA` (`ON DELETE CASCADE`) | Identificador da obra (R9). | `301` |
| `id_autor` | `NUMBER(10)` | `NOT NULL` | `PK_AUTORIA` (2/2), `FK_AUTORIA_AUTOR` *(Padrão Oracle)* | Identificador do autor (R9). | `50` |

---

### 2.15. Tabela `EXEMPLAR` (Entidade Fraca)
**Finalidade:** Cópias físicas numeradas de uma obra (R10, RN09). Identificada pela chave da obra combinada com a chave parcial `numero_exemplar`.

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_obra` | `NUMBER(10)` | `NOT NULL` | `PK_EXEMPLAR` (1/2), `FK_EXEMPLAR_OBRA` (`ON DELETE CASCADE`) | Obra proprietária do exemplar (R10). | `301` |
| `numero_exemplar` | `NUMBER(4)` | `NOT NULL` | `PK_EXEMPLAR` (2/2), `CK_EXEMPLAR_NUM` (`numero_exemplar > 0`) | Chave parcial (discriminador) sequencial dentro da obra. | `2` |
| `data_aquisicao` | `DATE` | `NOT NULL` | `DEFAULT SYSDATE` | Data em que o exemplar físico foi adquirido. | `DATE '2022-02-15'` |

---

### 2.16. Tabela `EMPRESTIMO`
**Finalidade:** Empréstimos de exemplares físicos realizados por pessoas (alunos ou professores) (R11, R12, RN10 a RN12).

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_emprestimo` | `NUMBER(10)` | `NOT NULL` | `PK_EMPRESTIMO` | Identificador único do empréstimo. | `7001` |
| `id_pessoa` | `NUMBER(10)` | `NOT NULL` | `FK_EMPRESTIMO_PESSOA` *(Padrão Oracle)* | Pessoa que retirou o exemplar (R11). | `1001` |
| `id_obra` | `NUMBER(10)` | `NOT NULL` | `FK_EMPRESTIMO_EXEMPLAR` (1/2) *(Padrão Oracle)* | Obra correspondente ao exemplar emprestado (R12). | `301` |
| `numero_exemplar` | `NUMBER(4)` | `NOT NULL` | `FK_EMPRESTIMO_EXEMPLAR` (2/2) *(Padrão Oracle)* | Número do exemplar emprestado (R12). | `2` |
| `data_emprestimo` | `DATE` | `NOT NULL` | `DEFAULT SYSDATE` | Data da retirada. | `DATE '2026-10-01'` |
| `data_prevista_devolucao`| `DATE` | `NOT NULL` | `CK_EMP_PREVISTA` (`data_prevista_devolucao >= data_emprestimo`) | Data limite (+7 dias aluno, +15 dias professor - RN12). | `DATE '2026-10-08'` |
| `data_devolucao` | `DATE` | `NULL` | `CK_EMP_DEVOLUCAO` (`data_devolucao IS NULL OR data_devolucao >= data_emprestimo`) | Data efetiva da devolução (`NULL` enquanto em aberto). | `DATE '2026-10-11'` |

---

### 2.17. Tabela `RESERVA`
**Finalidade:** Entidade associativa (`PESSOA × OBRA`, R14) para reserva de obras sem exemplares disponíveis (RF08, RN15).

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_reserva` | `NUMBER(10)` | `NOT NULL` | `PK_RESERVA` | Identificador único da reserva. | `901` |
| `id_pessoa` | `NUMBER(10)` | `NOT NULL` | `FK_RESERVA_PESSOA` (`ON DELETE CASCADE`) | Usuário solicitante da reserva (R14). | `1001` |
| `id_obra` | `NUMBER(10)` | `NOT NULL` | `FK_RESERVA_OBRA` (`ON DELETE CASCADE`) | Obra reservada (R14). | `301` |
| `data_reserva` | `DATE` | `NOT NULL` | `DEFAULT SYSDATE` | Data e hora da solicitação da reserva. | `SYSDATE` |
| `situacao` | `VARCHAR2(15)` | `NOT NULL` | `DEFAULT 'ATIVA'`, `CK_RESERVA_SITUACAO` (`situacao IN ('ATIVA', 'ATENDIDA', 'CANCELADA')`) | Status da reserva na fila. | `'ATIVA'` |

---

### 2.18. Tabela `MULTA`
**Finalidade:** Multa gerada por atraso na devolução de um empréstimo (R13 — Relacionamento `1:1`, RN13, RN14).

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_multa` | `NUMBER(10)` | `NOT NULL` | `PK_MULTA` | Identificador único da multa. | `401` |
| `id_emprestimo` | `NUMBER(10)` | `NOT NULL` | `UQ_MULTA_EMPRESTIMO`, `FK_MULTA_EMPRESTIMO` *(Padrão Oracle)* | Empréstimo gerador da multa (R13 - 1:1). | `7001` |
| `valor` | `NUMBER(8,2)` | `NOT NULL` | `CK_MULTA_VALOR` (`valor > 0`) | Valor em R$ (R$ 1,00 por dia de atraso - RN13). | `3.00` |
| `data_geracao` | `DATE` | `NOT NULL` | `DEFAULT SYSDATE` | Data em que a multa foi gerada. | `DATE '2026-10-11'` |
| `data_pagamento` | `DATE` | `NULL` | `CK_MULTA_PAGTO` (`data_pagamento IS NULL OR data_pagamento >= data_geracao`) | Data de quitação (`NULL` indica multa pendente - RN14). | `NULL` |

---

## 3. Matriz de Integridade Referencial (Todas as 21 FKs do Esquema)

| Constraint FK | Tabela Origem | Tabela Destino | Cláusula no DDL Oracle | Comportamento / Justificativa |
|---|---|---|---|---|
| `FK_CURSO_DEPARTAMENTO` | `CURSO` | `DEPARTAMENTO` | *(Omitida — Padrão Oracle)* | Rejeita exclusão de departamento com cursos vinculados (`ORA-02292`). |
| `FK_DISCIPLINA_DEPARTAMENTO` | `DISCIPLINA` | `DEPARTAMENTO` | *(Omitida — Padrão Oracle)* | Rejeita exclusão de departamento com disciplinas vinculadas. |
| `FK_PREREQ_DISCIPLINA` | `PRE_REQUISITO` | `DISCIPLINA` | `ON DELETE CASCADE` | Remove o pré-requisito se a disciplina principal for excluída. |
| `FK_PREREQ_DISC_EXIGIDA` | `PRE_REQUISITO` | `DISCIPLINA` | `ON DELETE CASCADE` | Remove a exigência se a disciplina requisito for excluída. |
| `FK_TELEFONE_PESSOA` | `TELEFONE_PESSOA` | `PESSOA` | `ON DELETE CASCADE` | Atributo multivalorado removido junto com a pessoa titular. |
| `FK_ALUNO_PESSOA` | `ALUNO` | `PESSOA` | `ON DELETE CASCADE` | Subtipo (FK composta `id_pessoa, tipo_pessoa`) removido com o supertipo. |
| `FK_ALUNO_CURSO` | `ALUNO` | `CURSO` | *(Omitida — Padrão Oracle)* | Rejeita exclusão de curso que possui alunos matriculados. |
| `FK_PROFESSOR_PESSOA` | `PROFESSOR` | `PESSOA` | `ON DELETE CASCADE` | Subtipo (FK composta `id_pessoa, tipo_pessoa`) removido com o supertipo. |
| `FK_PROFESSOR_DEPARTAMENTO` | `PROFESSOR` | `DEPARTAMENTO` | *(Omitida — Padrão Oracle)* | Rejeita exclusão de departamento com professores lotados. |
| `FK_TURMA_DISCIPLINA` | `TURMA` | `DISCIPLINA` | *(Omitida — Padrão Oracle)* | Preserva histórico de turmas ofertadas da disciplina. |
| `FK_TURMA_PROFESSOR` | `TURMA` | `PROFESSOR` | `ON DELETE SET NULL` | Se o professor for excluído, a turma permanece registrada com docente `NULL` (a definir). |
| `FK_MATRICULA_ALUNO` | `MATRICULA` | `ALUNO` | *(Omitida — Padrão Oracle)* | Preserva histórico de matrículas do aluno. |
| `FK_MATRICULA_TURMA` | `MATRICULA` | `TURMA` | *(Omitida — Padrão Oracle)* | Rejeita exclusão de turma que possua matrículas. |
| `FK_AUTORIA_OBRA` | `AUTORIA` | `OBRA` | `ON DELETE CASCADE` | Remove o vínculo de autoria se a obra for removida. |
| `FK_AUTORIA_AUTOR` | `AUTORIA` | `AUTOR` | *(Omitida — Padrão Oracle)* | Rejeita exclusão de autor que possui obras catalogadas. |
| `FK_EXEMPLAR_OBRA` | `EXEMPLAR` | `OBRA` | `ON DELETE CASCADE` | Entidade fraca: exemplares dependem existencialmente da obra. |
| `FK_EMPRESTIMO_PESSOA` | `EMPRESTIMO` | `PESSOA` | *(Omitida — Padrão Oracle)* | Impede excluir pessoa com histórico de empréstimos. |
| `FK_EMPRESTIMO_EXEMPLAR` | `EMPRESTIMO` | `EXEMPLAR` | *(Omitida — Padrão Oracle)* | Impede excluir exemplar físico que possui histórico de empréstimos. |
| `FK_RESERVA_PESSOA` | `RESERVA` | `PESSOA` | `ON DELETE CASCADE` | Cancela/remove reservas caso o usuário seja excluído. |
| `FK_RESERVA_OBRA` | `RESERVA` | `OBRA` | `ON DELETE CASCADE` | Remove a fila de reservas caso a obra seja excluída. |
| `FK_MULTA_EMPRESTIMO` | `MULTA` | `EMPRESTIMO` | *(Omitida — Padrão Oracle)* | Impede excluir empréstimo que gerou registro financeiro de multa. |