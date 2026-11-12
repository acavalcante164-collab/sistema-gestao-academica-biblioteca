# ETAPA 5: Dicionário de Dados do Modelo Relacional

**Projeto:** Sistema Integrado de Gestão Acadêmica e Biblioteca (SIGAB) — Grupo 06  
**Disciplina:** DCC 502 - Banco de Dados I (UFRR)  
**SGBD:** Oracle Database (`VARCHAR2`, `NUMBER`, `DATE`, `CHAR`)  
**Milestone:** M2 - Modelo Relacional e Normalização (Issue #6)  

---

## 1. Padrões de Nomenclatura Adotados (RNF01, RNF02 e RNF06)

* **Tabelas:** Nomes em maiúsculas e no singular (`PESSOA`, `MATRICULA`, `AUDITORIA_NOTA`).
* **Chave Primária (`PK`):** `PK_<TABELA>`
* **Chave Estrangeira (`FK`):** `FK_<ORIGEM>_<DESTINO>`
* **Unicidade (`UNIQUE`):** `UQ_<TABELA>_<COLUNA>`
* **Validação (`CHECK`):** `CK_<TABELA>_<REGRA>`

---

## 2. Detalhamento das Tabelas e Colunas

### 2.1. Tabela `DEPARTAMENTO`
**Descrição:** Unidades acadêmicas que ofertam cursos e disciplinas (R1, R2) e lotam professores (R16).

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_departamento` | `NUMBER(10)` | `NOT NULL` | `PK_DEPARTAMENTO` | Identificador único do departamento. | `1` |
| `nome` | `VARCHAR2(100)` | `NOT NULL` | `UQ_DEPARTAMENTO_NOME` | Nome completo do departamento. | `'Departamento de Ciência da Computação'` |
| `sigla` | `VARCHAR2(10)` | `NOT NULL` | `UQ_DEPARTAMENTO_SIGLA` | Sigla oficial do departamento. | `'DCC'` |

---

### 2.2. Tabela `CURSO`
**Descrição:** Cursos de graduação ofertados por um departamento (R1, RN02).
* **Ação Referencial:** `FK_CURSO_DEPARTAMENTO` (`RESTRICT` — impede excluir departamento com cursos vinculados).

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_curso` | `NUMBER(10)` | `NOT NULL` | `PK_CURSO` | Identificador único do curso. | `10` |
| `nome` | `VARCHAR2(100)` | `NOT NULL` | `UQ_CURSO_NOME` | Nome oficial do curso. | `'Ciência da Computação'` |
| `carga_horaria` | `NUMBER(5)` | `NOT NULL` | `CK_CURSO_CH` (`carga_horaria > 0`) | Carga horária total do curso em horas. | `3200` |
| `id_departamento` | `NUMBER(10)` | `NOT NULL` | `FK_CURSO_DEPARTAMENTO` | Departamento responsável pelo curso (R1). | `1` |

---

### 2.3. Tabela `DISCIPLINA`
**Descrição:** Disciplinas ofertadas pelos departamentos nas grades curriculares (R2).

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_disciplina` | `NUMBER(10)` | `NOT NULL` | `PK_DISCIPLINA` | Identificador único da disciplina. | `100` |
| `codigo` | `VARCHAR2(10)` | `NOT NULL` | `UQ_DISCIPLINA_CODIGO` | Código identificador da disciplina. | `'DCC502'` |
| `nome` | `VARCHAR2(100)` | `NOT NULL` | — | Nome da disciplina. | `'Banco de Dados I'` |
| `carga_horaria` | `NUMBER(4)` | `NOT NULL` | `CK_DISCIPLINA_CH` (`carga_horaria > 0`) | Carga horária semestral em horas. | `60` |
| `id_departamento` | `NUMBER(10)` | `NOT NULL` | `FK_DISCIPLINA_DEPARTAMENTO` | Departamento ofertante da disciplina (R2). | `1` |

---

### 2.4. Tabela `PRE_REQUISITO`
**Descrição:** Tabela associativa que resolve o auto-relacionamento `N:M` (R8) de pré-requisitos entre disciplinas (RF02, RN05).
* **Ação Referencial:** `ON DELETE CASCADE` em ambas as chaves estrangeiras.

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_disciplina` | `NUMBER(10)` | `NOT NULL` | `PK_PRE_REQUISITO` (1/2), `FK_PREREQ_DISCIPLINA` | Disciplina que exige o pré-requisito. | `100` (*Banco de Dados I*) |
| `id_disciplina_req`| `NUMBER(10)` | `NOT NULL` | `PK_PRE_REQUISITO` (2/2), `FK_PREREQ_DISC_EXIGIDA`, `CK_PREREQ_DISTINTO` (`id_disciplina <> id_disciplina_req`) | Disciplina que deve ser cumprida previamente. | `90` (*Estruturas de Dados*) |

---

### 2.5. Tabela `PESSOA`
**Descrição:** Entidade forte supertipo que unifica o cadastro de alunos e professores para integração entre secretaria acadêmica e biblioteca (R15, RN01). Contém o atributo composto `endereco` decomposto em colunas atômicas.

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_pessoa` | `NUMBER(10)` | `NOT NULL` | `PK_PESSOA` | Identificador único da pessoa. | `1001` |
| `cpf` | `CHAR(11)` | `NOT NULL` | `UQ_PESSOA_CPF`, `CK_PESSOA_CPF` (`LENGTH(TRIM(cpf)) = 11`) | CPF da pessoa (apenas números, chave candidata). | `'01234567890'` |
| `nome` | `VARCHAR2(120)` | `NOT NULL` | — | Nome completo da pessoa. | `'Ana Carolina Souza'` |
| `data_nascimento` | `DATE` | `NOT NULL` | — | Data de nascimento. | `DATE '2003-04-15'` |
| `email` | `VARCHAR2(100)` | `NOT NULL` | `UQ_PESSOA_EMAIL` | Endereço de e-mail único. | `'ana.souza@ufrr.br'` |
| `rua` | `VARCHAR2(120)` | `NOT NULL` | — | Endereço (composto): Logradouro/Rua. | `'Av. Ville Roy'` |
| `numero` | `VARCHAR2(15)` | `NOT NULL` | — | Endereço (composto): Número do imóvel. | `'1540'` |
| `bairro` | `VARCHAR2(60)` | `NOT NULL` | — | Endereço (composto): Bairro. | `'Caçari'` |
| `cidade` | `VARCHAR2(60)` | `NOT NULL` | — | Endereço (composto): Cidade. | `'Boa Vista'` |
| `cep` | `CHAR(8)` | `NOT NULL` | `CK_PESSOA_CEP` (`LENGTH(TRIM(cep)) = 8`) | Endereço (composto): CEP (8 dígitos). | `'69307000'` |
| `tipo_pessoa` | `VARCHAR2(15)` | `NOT NULL` | `CK_PESSOA_TIPO` (`tipo_pessoa IN ('ALUNO', 'PROFESSOR')`) | Discriminador da especialização total e disjunta (RN01). | `'ALUNO'` |

---

### 2.6. Tabela `TELEFONE_PESSOA`
**Descrição:** Relação resultante do mapeamento do atributo multivalorado `telefone` de `PESSOA` (RF01).
* **Ação Referencial:** `FK_TELEFONE_PESSOA` com `ON DELETE CASCADE`.

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_pessoa` | `NUMBER(10)` | `NOT NULL` | `PK_TELEFONE_PESSOA` (1/2), `FK_TELEFONE_PESSOA` | Identificador da pessoa titular do telefone. | `1001` |
| `telefone` | `VARCHAR2(15)` | `NOT NULL` | `PK_TELEFONE_PESSOA` (2/2) | Número de telefone com DDD. | `'95991112233'` |

---

### 2.7. Tabela `ALUNO`
**Descrição:** Subtipo de `PESSOA` (R15) vinculado a um curso de graduação (R3, RN01, RN02). Herda a chave primária de `PESSOA`.
* **Ações Referenciais:** `FK_ALUNO_PESSOA` (`ON DELETE CASCADE`); `FK_ALUNO_CURSO` (`RESTRICT`).

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_pessoa` | `NUMBER(10)` | `NOT NULL` | `PK_ALUNO`, `FK_ALUNO_PESSOA` | Identificador herdado de `PESSOA`. | `1001` |
| `matricula` | `VARCHAR2(15)` | `NOT NULL` | `UQ_ALUNO_MATRICULA` | Matrícula acadêmica única (chave candidata). | `'2024005534'` |
| `data_ingresso` | `DATE` | `NOT NULL` | — | Data de ingresso do aluno no curso. | `DATE '2024-03-01'` |
| `id_curso` | `NUMBER(10)` | `NOT NULL` | `FK_ALUNO_CURSO` | Curso em que o aluno está matriculado (R3). | `10` |

---

### 2.8. Tabela `PROFESSOR`
**Descrição:** Subtipo de `PESSOA` (R15) lotado em um departamento acadêmico (R16, RN01). Herda a chave primária de `PESSOA`.
* **Ações Referenciais:** `FK_PROFESSOR_PESSOA` (`ON DELETE CASCADE`); `FK_PROFESSOR_DEPARTAMENTO` (`RESTRICT`).

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_pessoa` | `NUMBER(10)` | `NOT NULL` | `PK_PROFESSOR`, `FK_PROFESSOR_PESSOA` | Identificador herdado de `PESSOA`. | `2001` |
| `titulacao` | `VARCHAR2(30)` | `NOT NULL` | `CK_PROFESSOR_TITULACAO` (`titulacao IN ('GRADUADO', 'ESPECIALISTA', 'MESTRE', 'DOUTOR')`) | Titulação acadêmica do docente. | `'DOUTOR'` |
| `data_admissao` | `DATE` | `NOT NULL` | — | Data de admissão do professor na instituição. | `DATE '2016-08-10'` |
| `id_departamento` | `NUMBER(10)` | `NOT NULL` | `FK_PROFESSOR_DEPARTAMENTO` | Departamento de lotação do docente (R16). | `1` |

---

### 2.9. Tabela `TURMA`
**Descrição:** Oferta de uma disciplina em um semestre, ministrada por um professor e com limite de vagas (R4, R5, RN03, RN04).

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_turma` | `NUMBER(10)` | `NOT NULL` | `PK_TURMA` | Identificador único da turma. | `501` |
| `id_disciplina` | `NUMBER(10)` | `NOT NULL` | `FK_TURMA_DISCIPLINA` | Disciplina ofertada na turma (R4). | `100` |
| `id_professor` | `NUMBER(10)` | `NOT NULL` | `FK_TURMA_PROFESSOR` | Professor responsável pela turma (R5). | `2001` |
| `semestre` | `VARCHAR2(10)` | `NOT NULL` | `CK_TURMA_SEMESTRE` (`REGEXP_LIKE(semestre, '^[0-9]{4}\.[1-2]$')`) | Semestre letivo no formato `AAAA.S`. | `'2026.2'` |
| `vagas_total` | `NUMBER(3)` | `NOT NULL` | `CK_TURMA_VAGAS` (`vagas_total > 0`) | Capacidade máxima de alunos na turma (RN04). | `40` |
| `sala` | `VARCHAR2(30)` | `NOT NULL` | — | Sala ou laboratório de aula. | `'Lab 02 - DCC'` |
| `horario` | `VARCHAR2(40)` | `NOT NULL` | — | Dias e horários das aulas. | `'SEG/QUA 14:00-16:00'` |

---

### 2.10. Tabela `MATRICULA`
**Descrição:** Entidade associativa (`ALUNO × TURMA`, R6) identificada pelo par `(id_aluno, id_turma)` (RN06), que registra nota, frequência e situação final (RN07, RN08).

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_aluno` | `NUMBER(10)` | `NOT NULL` | `PK_MATRICULA` (1/2), `FK_MATRICULA_ALUNO` | Aluno matriculado na turma (R6). | `1001` |
| `id_turma` | `NUMBER(10)` | `NOT NULL` | `PK_MATRICULA` (2/2), `FK_MATRICULA_TURMA` | Turma na qual o aluno se matriculou (R6). | `501` |
| `data_matricula` | `DATE` | `NOT NULL` | `DEFAULT SYSDATE` | Data de realização da matrícula. | `SYSDATE` |
| `nota_final` | `NUMBER(4,2)` | `NULL` | `CK_MATRICULA_NOTA` (`nota_final BETWEEN 0 AND 10`) | Nota final entre 0,00 e 10,00 (RN07). | `8.50` |
| `frequencia` | `NUMBER(5,2)` | `NULL` | `CK_MATRICULA_FREQ` (`frequencia BETWEEN 0 AND 100`) | Percentual de frequência entre 0 e 100% (RN07). | `85.00` |
| `situacao` | `VARCHAR2(20)` | `NOT NULL` | `DEFAULT 'CURSANDO'`, `CK_MATRICULA_SITUACAO` (`situacao IN ('CURSANDO', 'APROVADO', 'REPROVADO_NOTA', 'REPROVADO_FALTA', 'TRANCADO')`) | Situação da matrícula (RN08). | `'APROVADO'` |

---

### 2.11. Tabela `AUDITORIA_NOTA`
**Descrição:** Registra o histórico de alterações de notas de uma matrícula via Trigger (R7, RF10, RN16).
* **Chave Estrangeira Composta:** Referencia `(id_aluno, id_turma)` da tabela `MATRICULA` com `ON DELETE CASCADE`.

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_auditoria` | `NUMBER(10)` | `NOT NULL` | `PK_AUDITORIA_NOTA` | Identificador único do registro de auditoria. | `1` |
| `id_aluno` | `NUMBER(10)` | `NOT NULL` | `FK_AUDITORIA_MATRICULA` (1/2) | Aluno da matrícula auditada (R7). | `1001` |
| `id_turma` | `NUMBER(10)` | `NOT NULL` | `FK_AUDITORIA_MATRICULA` (2/2) | Turma da matrícula auditada (R7). | `501` |
| `nota_anterior` | `NUMBER(4,2)` | `NULL` | — | Valor da nota antes da alteração. | `5.50` |
| `nota_nova` | `NUMBER(4,2)` | `NULL` | — | Novo valor atribuído à nota. | `7.00` |
| `data_alteracao` | `DATE` | `NOT NULL` | `DEFAULT SYSDATE` | Data e hora do evento de alteração. | `SYSDATE` |
| `usuario` | `VARCHAR2(60)` | `NOT NULL` | `DEFAULT USER` | Usuário do banco que realizou a modificação. | `'SYSTEM'` |

---

### 2.12. Tabela `OBRA`
**Descrição:** Títulos bibliográficos do acervo da biblioteca (RF06).

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_obra` | `NUMBER(10)` | `NOT NULL` | `PK_OBRA` | Identificador único da obra no acervo. | `301` |
| `titulo` | `VARCHAR2(200)` | `NOT NULL` | — | Título da obra. | `'Database System Concepts'` |
| `tipo` | `VARCHAR2(20)` | `NOT NULL` | `CK_OBRA_TIPO` (`tipo IN ('LIVRO', 'PERIODICO', 'TCC')`) | Classificação do material bibliográfico. | `'LIVRO'` |
| `ano_publicacao` | `NUMBER(4)` | `NOT NULL` | `CK_OBRA_ANO` (`ano_publicacao > 1500`) | Ano de publicação. | `2019` |
| `editora` | `VARCHAR2(100)` | `NULL` | — | Nome da editora ou instituição. | `'McGraw-Hill'` |

---

### 2.13. Tabela `AUTOR`
**Descrição:** Autores das obras pertencentes ao acervo (RF06).

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_autor` | `NUMBER(10)` | `NOT NULL` | `PK_AUTOR` | Identificador único do autor. | `50` |
| `nome` | `VARCHAR2(120)` | `NOT NULL` | — | Nome completo do autor. | `'Abraham Silberschatz'` |

---

### 2.14. Tabela `AUTORIA`
**Descrição:** Tabela associativa que resolve o relacionamento `N:M` (R9) entre `OBRA` e `AUTOR`.
* **Ação Referencial:** `FK_AUTORIA_OBRA` (`ON DELETE CASCADE`); `FK_AUTORIA_AUTOR` (`RESTRICT`).

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_obra` | `NUMBER(10)` | `NOT NULL` | `PK_AUTORIA` (1/2), `FK_AUTORIA_OBRA` | Identificador da obra (R9). | `301` |
| `id_autor` | `NUMBER(10)` | `NOT NULL` | `PK_AUTORIA` (2/2), `FK_AUTORIA_AUTOR` | Identificador do autor (R9). | `50` |

---

### 2.15. Tabela `EXEMPLAR` (Entidade Fraca)
**Descrição:** Cópias físicas numeradas de uma obra (R10, RN09). Identificada pela chave da obra combinada com a chave parcial `numero_exemplar`.
* **Ação Referencial:** `FK_EXEMPLAR_OBRA` com `ON DELETE CASCADE` (dependência existencial de entidade fraca).

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_obra` | `NUMBER(10)` | `NOT NULL` | `PK_EXEMPLAR` (1/2), `FK_EXEMPLAR_OBRA` | Obra proprietária do exemplar (R10). | `301` |
| `numero_exemplar` | `NUMBER(4)` | `NOT NULL` | `PK_EXEMPLAR` (2/2), `CK_EXEMPLAR_NUM` (`numero_exemplar > 0`) | Chave parcial (discriminador) sequencial dentro da obra. | `2` |
| `data_aquisicao` | `DATE` | `NOT NULL` | `DEFAULT SYSDATE` | Data em que o exemplar físico foi adquirido. | `DATE '2022-02-15'` |

---

### 2.16. Tabela `EMPRESTIMO`
**Descrição:** Empréstimos de exemplares físicos realizados por pessoas (alunos ou professores) (R11, R12, RN10 a RN12).
* **Chave Estrangeira Composta:** `FK_EMPRESTIMO_EXEMPLAR` referencia `(id_obra, numero_exemplar)` em `EXEMPLAR`.

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_emprestimo` | `NUMBER(10)` | `NOT NULL` | `PK_EMPRESTIMO` | Identificador único do empréstimo. | `7001` |
| `id_pessoa` | `NUMBER(10)` | `NOT NULL` | `FK_EMPRESTIMO_PESSOA` | Pessoa (aluno ou professor) que retirou o exemplar (R11). | `1001` |
| `id_obra` | `NUMBER(10)` | `NOT NULL` | `FK_EMPRESTIMO_EXEMPLAR` (1/2) | Obra correspondente ao exemplar emprestado (R12). | `301` |
| `numero_exemplar` | `NUMBER(4)` | `NOT NULL` | `FK_EMPRESTIMO_EXEMPLAR` (2/2) | Número do exemplar emprestado (R12). | `2` |
| `data_emprestimo` | `DATE` | `NOT NULL` | `DEFAULT SYSDATE` | Data da retirada. | `DATE '2026-10-01'` |
| `data_prevista_devolucao`| `DATE` | `NOT NULL` | `CK_EMP_PREVISTA` (`data_prevista_devolucao >= data_emprestimo`) | Data limite (+7 dias aluno, +15 dias professor - RN12). | `DATE '2026-10-08'` |
| `data_devolucao` | `DATE` | `NULL` | `CK_EMP_DEVOLUCAO` (`data_devolucao IS NULL OR data_devolucao >= data_emprestimo`) | Data efetiva da devolução (`NULL` enquanto em aberto). | `DATE '2026-10-11'` |

---

### 2.17. Tabela `RESERVA`
**Descrição:** Entidade associativa (`PESSOA × OBRA`, R14) para reserva de obras sem exemplares disponíveis no momento (RF08, RN15).

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_reserva` | `NUMBER(10)` | `NOT NULL` | `PK_RESERVA` | Identificador único da reserva. | `901` |
| `id_pessoa` | `NUMBER(10)` | `NOT NULL` | `FK_RESERVA_PESSOA` | Usuário solicitante da reserva (R14). | `1001` |
| `id_obra` | `NUMBER(10)` | `NOT NULL` | `FK_RESERVA_OBRA` | Obra reservada (R14). | `301` |
| `data_reserva` | `DATE` | `NOT NULL` | `DEFAULT SYSDATE` | Data e hora da solicitação da reserva. | `SYSDATE` |
| `situacao` | `VARCHAR2(15)` | `NOT NULL` | `DEFAULT 'ATIVA'`, `CK_RESERVA_SITUACAO` (`situacao IN ('ATIVA', 'ATENDIDA', 'CANCELADA')`) | Status da reserva na fila. | `'ATIVA'` |

---

### 2.18. Tabela `MULTA`
**Descrição:** Multa gerada por atraso na devolução de um empréstimo (R13 — Relacionamento `1:1`, RN13, RN14).
* **Relacionamento 1:1:** A coluna `id_emprestimo` possui constraint `UNIQUE` (`UQ_MULTA_EMPRESTIMO`) e `FK_MULTA_EMPRESTIMO` (`ON DELETE CASCADE`).

| Coluna | Tipo Oracle | Nulo? | Restrições (Constraints) | Descrição / Domínio | Exemplo |
|---|---|---|---|---|---|
| `id_multa` | `NUMBER(10)` | `NOT NULL` | `PK_MULTA` | Identificador único da multa. | `401` |
| `id_emprestimo` | `NUMBER(10)` | `NOT NULL` | `UQ_MULTA_EMPRESTIMO`, `FK_MULTA_EMPRESTIMO` | Empréstimo gerador da multa (R13 - 1:1). | `7001` |
| `valor` | `NUMBER(8,2)` | `NOT NULL` | `CK_MULTA_VALOR` (`valor > 0`) | Valor em R$ (R$ 1,00 por dia de atraso - RN13). | `3.00` |
| `data_geracao` | `DATE` | `NOT NULL` | `DEFAULT SYSDATE` | Data em que a multa foi gerada. | `DATE '2026-10-11'` |
| `data_pagamento` | `DATE` | `NULL` | `CK_MULTA_PAGTO` (`data_pagamento IS NULL OR data_pagamento >= data_geracao`) | Data de quitação (`NULL` indica multa pendente - RN14). | `NULL` |

---

## 3. Matriz de Integridade Referencial (Resumo das FKs)

| Constraint FK | Tabela Origem | Tabela Destino | Ação `ON DELETE` | Justificativa |
|---|---|---|---|---|
| `FK_CURSO_DEPARTAMENTO` | `CURSO` | `DEPARTAMENTO` | `RESTRICT` (Padrão) | Impede apagar departamento com cursos ativos. |
| `FK_DISCIPLINA_DEPARTAMENTO` | `DISCIPLINA` | `DEPARTAMENTO` | `RESTRICT` (Padrão) | Impede apagar departamento com disciplinas. |
| `FK_PREREQ_DISCIPLINA` | `PRE_REQUISITO` | `DISCIPLINA` | `ON DELETE CASCADE` | Remove o vínculo de requisito se a disciplina for excluída. |
| `FK_PREREQ_DISC_EXIGIDA` | `PRE_REQUISITO` | `DISCIPLINA` | `ON DELETE CASCADE` | Remove a exigência se a disciplina base for excluída. |
| `FK_TELEFONE_PESSOA` | `TELEFONE_PESSOA` | `PESSOA` | `ON DELETE CASCADE` | Atributo multivalorado depende existencialmente de `PESSOA`. |
| `FK_ALUNO_PESSOA` | `ALUNO` | `PESSOA` | `ON DELETE CASCADE` | Subtipo herda existência do supertipo `PESSOA`. |
| `FK_ALUNO_CURSO` | `ALUNO` | `CURSO` | `RESTRICT` (Padrão) | Impede excluir curso que possui alunos vinculados. |
| `FK_PROFESSOR_PESSOA` | `PROFESSOR` | `PESSOA` | `ON DELETE CASCADE` | Subtipo herda existência do supertipo `PESSOA`. |
| `FK_PROFESSOR_DEPARTAMENTO` | `PROFESSOR` | `DEPARTAMENTO` | `RESTRICT` (Padrão) | Impede excluir departamento com docentes lotados. |
| `FK_TURMA_DISCIPLINA` | `TURMA` | `DISCIPLINA` | `RESTRICT` (Padrão) | Preserva histórico de ofertas da disciplina. |
| `FK_TURMA_PROFESSOR` | `TURMA` | `PROFESSOR` | `RESTRICT` (Padrão) | Impede excluir professor vinculado a turmas ofertadas. |
| `FK_MATRICULA_ALUNO` | `MATRICULA` | `ALUNO` | `RESTRICT` (Padrão) | Preserva histórico escolar do aluno. |
| `FK_MATRICULA_TURMA` | `MATRICULA` | `TURMA` | `RESTRICT` (Padrão) | Impede excluir turma com alunos matriculados. |
| `FK_AUDITORIA_MATRICULA` | `AUDITORIA_NOTA` | `MATRICULA` | `ON DELETE CASCADE` | Mantém o log atrelado à existência da matrícula. |
| `FK_AUTORIA_OBRA` | `AUTORIA` | `OBRA` | `ON DELETE CASCADE` | Remove vínculo de autoria caso a obra seja descadastrada. |
| `FK_AUTORIA_AUTOR` | `AUTORIA` | `AUTOR` | `RESTRICT` (Padrão) | Impede excluir autor que possui obras no acervo. |
| `FK_EXEMPLAR_OBRA` | `EXEMPLAR` | `OBRA` | `ON DELETE CASCADE` | Entidade fraca: exemplares deixam de existir sem a obra. |
| `FK_EMPRESTIMO_PESSOA` | `EMPRESTIMO` | `PESSOA` | `RESTRICT` (Padrão) | Impede excluir pessoa com histórico de empréstimos. |
| `FK_EMPRESTIMO_EXEMPLAR` | `EMPRESTIMO` | `EXEMPLAR` | `RESTRICT` (Padrão) | Impede excluir exemplar físico que possui empréstimos. |
| `FK_RESERVA_PESSOA` | `RESERVA` | `PESSOA` | `ON DELETE CASCADE` | Cancela/remove reservas caso a pessoa seja removida. |
| `FK_RESERVA_OBRA` | `RESERVA` | `OBRA` | `ON DELETE CASCADE` | Remove reservas caso a obra deixe de existir. |
| `FK_MULTA_EMPRESTIMO` | `MULTA` | `EMPRESTIMO` | `ON DELETE CASCADE` | A multa depende existencialmente do empréstimo que a gerou. |