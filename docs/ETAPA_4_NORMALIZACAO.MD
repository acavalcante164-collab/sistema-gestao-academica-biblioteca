# ETAPA 4: Memorial de Dependências Funcionais e Normalização (1FN à FNBC)

**Projeto:** Sistema Integrado de Gestão Acadêmica e Biblioteca (SIGAB) — Grupo 06  
**Disciplina:** DCC 502 - Banco de Dados I (UFRR)  
**Milestone:** M2 - Modelo Relacional e Normalização (Issue #5)  

---

## 1. Visão Geral do Esquema Relacional Mapeado

A partir das entidades e relacionamentos levantados no DER, e aplicando o refinamento de normalização até a Forma Normal de Boyce-Codd (FNBC), o esquema relacional do SIGAB é composto pelas 18 relações abaixo:

1. **DEPARTAMENTO** (<u>id_departamento</u>, nome, sigla)
2. **CURSO** (<u>id_curso</u>, nome, carga_horaria, id_departamento)
3. **DISCIPLINA** (<u>id_disciplina</u>, codigo, nome, carga_horaria, id_departamento)
4. **PRE_REQUISITO** (<u>id_disciplina</u>, <u>id_disciplina_req</u>)
5. **PESSOA** (<u>id_pessoa</u>, cpf, nome, data_nascimento, email, tipo_pessoa, rua, numero, bairro, cidade, cep)
6. **TELEFONE_PESSOA** (<u>id_pessoa</u>, <u>telefone</u>)
7. **ALUNO** (<u>id_pessoa</u>, tipo_pessoa, matricula, data_ingresso, id_curso)
8. **PROFESSOR** (<u>id_pessoa</u>, tipo_pessoa, titulacao, data_admissao, id_departamento)
9. **TURMA** (<u>id_turma</u>, semestre, vagas_total, sala, dia_semana, hora_inicio, hora_fim, id_disciplina, id_professor)
10. **MATRICULA** (<u>id_aluno</u>, <u>id_turma</u>, data_matricula, nota_final, frequencia, status_matricula)
11. **AUDITORIA_NOTA** (<u>id_auditoria</u>, id_aluno, id_turma, nota_anterior, nota_nova, data_alteracao, usuario)
12. **OBRA** (<u>id_obra</u>, titulo, tipo, ano_publicacao, editora)
13. **AUTOR** (<u>id_autor</u>, nome)
14. **AUTORIA** (<u>id_obra</u>, <u>id_autor</u>)
15. **EXEMPLAR** (<u>id_obra</u>, <u>numero_exemplar</u>, data_aquisicao)
16. **EMPRESTIMO** (<u>id_emprestimo</u>, id_pessoa, id_obra, numero_exemplar, data_emprestimo, data_prevista_devolucao, data_devolucao)
17. **RESERVA** (<u>id_reserva</u>, id_pessoa, id_obra, data_reserva, situacao)
18. **MULTA** (<u>id_multa</u>, id_emprestimo, valor, data_geracao, data_pagamento)

---

## 2. Primeira Forma Normal (1FN)

**Definição:** Uma relação está na **1FN** se e somente se todos os seus atributos contêm apenas valores atômicos (indivisíveis) e não existem atributos compostos ou grupos repetitivos (multivalorados).

### 2.1. Tratamento de `endereco` (Composto) e `telefone` (Multivalorado) em `PESSOA`
* **Esquema Preliminar (Não Normalizado - UNF):**
  * **PESSOA_UNF** (<u>id_pessoa</u>, cpf, nome, data_nascimento, email, tipo_pessoa, endereco(rua, numero, bairro, cidade, cep), {telefone})
* **Violações da 1FN identificadas:**
  1. `endereco` é um atributo composto estruturado em subatributos.
  2. `{telefone}` é um atributo multivalorado (grupo repetitivo).
* **Decomposição para 1FN:**
  1. Os componentes de `endereco` são decompostos em atributos atômicos (`rua`, `numero`, `bairro`, `cidade`, `cep`) na relação `PESSOA`.
  2. O grupo repetitivo `{telefone}` é movido para a relação independente `TELEFONE_PESSOA` com chave primária composta `(id_pessoa, telefone)`.
* **Relações Resultantes em 1FN:**
  * **PESSOA** (<u>id_pessoa</u>, cpf, nome, data_nascimento, email, tipo_pessoa, rua, numero, bairro, cidade, cep)
  * **TELEFONE_PESSOA** (<u>id_pessoa</u>, <u>telefone</u>)

### 2.2. Atomicidade do Atributo `horario` em `TURMA`
* **Esquema Preliminar (UNF):**
  * **TURMA_UNF** (<u>id_turma</u>, semestre, vagas_total, sala, horario_composto, id_disciplina, id_professor)
* **Violação da 1FN identificada:**
  Armazenar expressões agregadas como `'SEG/QUA 14:00-16:00'` em uma única coluna `horario` embute dia da semana, hora de início e hora de término no mesmo atributo, violando a atomicidade da 1FN e impedindo consultas diretas por turno ou dia.
* **Decomposição para 1FN:**
  Substituição do atributo não-atômico `horario` pelos atributos simples e indivisíveis `dia_semana` (ex.: `'SEG-QUA'`, ou dia do bloco), `hora_inicio` (ex.: `'14:00'`) e `hora_fim` (ex.: `'16:00'`):
  * **TURMA** (<u>id_turma</u>, semestre, vagas_total, sala, dia_semana, hora_inicio, hora_fim, id_disciplina, id_professor)

### 2.3. Tratamento de Múltiplos Autores em `OBRA` (Relacionamento R9)
* **Esquema Preliminar (UNF):**
  * **OBRA_UNF** (<u>id_obra</u>, titulo, tipo, ano_publicacao, editora, {id_autor, nome_autor})
* **Decomposição para 1FN:**
  Extração do grupo repetitivo para a entidade `AUTOR` e para a tabela associativa `AUTORIA`:
  * **OBRA** (<u>id_obra</u>, titulo, tipo, ano_publicacao, editora)
  * **AUTOR** (<u>id_autor</u>, nome)
  * **AUTORIA** (<u>id_obra</u>, <u>id_autor</u>)

---

## 3. Segunda Forma Normal (2FN)

**Definição:** Uma relação está na **2FN** se está na 1FN e todo atributo não-primo depende funcionalmente de **toda** a chave primária (ausência de dependências funcionais parciais).

> **Nota Formal:** As relações com chave primária simples (`DEPARTAMENTO`, `CURSO`, `DISCIPLINA`, `PESSOA`, `ALUNO`, `PROFESSOR`, `TURMA`, `AUDITORIA_NOTA`, `OBRA`, `AUTOR`, `EMPRESTIMO`, `RESERVA`, `MULTA`) já em 1FN estão **automaticamente na 2FN**. Avaliamos a seguir todas as relações de chave primária composta.

### 3.1. Análise da Relação `MATRICULA` (Chave Composta: `id_aluno, id_turma`)
* **Cenário com Violação de 2FN (Antes da decomposição):**
  * **MATRICULA_1FN** (<u>id_aluno</u>, <u>id_turma</u>, data_matricula, nota_final, frequencia, status_matricula, matricula_academica, semestre_turma)
* **Dependências Funcionais:**
  * `DF1:` `{id_aluno, id_turma} → {data_matricula, nota_final, frequencia, status_matricula}` *(Dependência Total)*
  * `DF2:` `{id_aluno} → {matricula_academica}` *(Violação de 2FN — Dependência Parcial)*
  * `DF3:` `{id_turma} → {semestre_turma}` *(Violação de 2FN — Dependência Parcial)*
* **Solução em 2FN:**
  Remoção dos atributos parciais para suas respectivas tabelas determinantes (`ALUNO` e `TURMA`), mantendo em `MATRICULA` exclusivamente atributos determinados pelo par `{id_aluno, id_turma}`:
  * **MATRICULA** (<u>id_aluno</u>, <u>id_turma</u>, data_matricula, nota_final, frequencia, status_matricula)

### 3.2. Análise da Entidade Fraca `EXEMPLAR` (Chave Composta: `id_obra, numero_exemplar`)
* **Esquema:** **EXEMPLAR** (<u>id_obra</u>, <u>numero_exemplar</u>, data_aquisicao)
* **Dependência Funcional:** `{id_obra, numero_exemplar} → {data_aquisicao}`
* **Conformidade 2FN:** A data de aquisição pertence à cópia física específica (exemplar `numero_exemplar` daquela `id_obra`), não dependendo apenas da obra nem apenas do número sequencial isolado. Logo, está na **2FN**.

### 3.3. Análise das Relações `All-Key` (`TELEFONE_PESSOA`, `PRE_REQUISITO`, `AUTORIA`)
Como todos os atributos de `TELEFONE_PESSOA(id_pessoa, telefone)`, `PRE_REQUISITO(id_disciplina, id_disciplina_req)` e `AUTORIA(id_obra, id_autor)` fazem parte da chave primária composta (não possuem atributos não-primos), essas relações encontram-se trivialmente em **2FN, 3FN e FNBC**.

---

## 4. Terceira Forma Normal (3FN)

**Definição:** Uma relação está na **3FN** se está na 2FN e nenhum atributo não-primo é transitivamente dependente da chave primária (ausência de cadeias `X → Y → Z` onde `Y` não é superchave).

### 4.1. Eliminação da Dependência Transitiva da Situação Final em `MATRICULA` (RN08 e Issue #10)
* **Análise do Problema (Violação de 3FN se armazenado):**
  Pela regra de negócio **RN08**, os estados `'APROVADO'`, `'REPROVADO_NOTA'` e `'REPROVADO_FALTA'` são inteiramente determinados pelos valores de `nota_final` e `frequencia`. Se armazenássemos uma coluna `situacao` contendo esses resultados na tabela `MATRICULA`, teríamos a dependência transitiva:
  * `{id_aluno, id_turma} → {nota_final, frequencia} → situacao_aprovacao`
  Isso causaria anomalia de atualização (alterar a nota sem recalcular a situação deixaria o banco inconsistente).
* **Decomposição / Solução em 3FN e FNBC:**
  1. Na tabela física **`MATRICULA`**, mantém-se apenas o atributo administrativo `status_matricula` com domínio restrito a `('ATIVA', 'TRANCADA')`, que representa o estado do vínculo contratual da matrícula e **não** depende de `nota_final` ou `frequencia`.
  2. A situação acadêmica final (`'APROVADO'`, `'REPROVADO_NOTA'`, `'REPROVADO_FALTA'`, `'TRANCADO'`, `'CURSANDO'`) é derivada dinamicamente na camada de visão (**`VW_SITUACAO_ACADEMICA`**, requisito da Issue #10), utilizando a expressão condicional da RN08:
     ```sql
     CASE
         WHEN m.status_matricula = 'TRANCADA' THEN 'TRANCADO'
         WHEN m.nota_final IS NULL OR m.frequencia IS NULL THEN 'CURSANDO'
         WHEN m.frequencia < 75 THEN 'REPROVADO_FALTA'
         WHEN m.nota_final >= 6.0 THEN 'APROVADO'
         ELSE 'REPROVADO_NOTA'
     END AS situacao_academica
     ```
  Com isso, elimina-se 100% da dependência transitiva e garante-se consistência absoluta sem necessidade de triggers de sincronização.

### 4.2. Análise de Endereço e CEP em `PESSOA`
* **Questão Teórica:** Em bases postais completas (DNE/Correios), o `cep` específico pode determinar `rua`, `bairro` e `cidade` (`id_pessoa → cep → {bairro, cidade}`).
* **Premissa de Domínio Adotada no SIGAB:** No contexto regional da instituição (municípios de Roraima que utilizam CEP geral único por localidade, ex.: `69300-000`, e áreas de expansão urbana sem CEP por logradouro), o atributo `cep` **não determina funcionalmente** o `bairro` nem a `rua` (um mesmo CEP abrange múltiplos bairros e ruas, e uma mesma rua pode cruzar faixas distintas). Assim, sob essa regra semântica do minimundo, `{rua, numero, bairro, cidade, cep}` dependem funcionalmente apenas de `id_pessoa`, preservando a **3FN e FNBC** sem necessidade de uma tabela externa de diretório postal.

### 4.3. Ausência de Atributos Derivados em `TURMA` e `EXEMPLAR`
* Em **`TURMA`**, armazena-se apenas `vagas_total`. O total de vagas ocupadas é obtido por agregação (`COUNT(*)`) sobre matrículas com `status_matricula = 'ATIVA'`.
* Em **`EXEMPLAR`**, não há coluna redundante de disponibilidade; um exemplar está disponível se e somente se não possui registro em `EMPRESTIMO` com `data_devolucao IS NULL` (RN10).

---

## 5. Garantia Relacional da Especialização Disjunta (`PESSOA`, `ALUNO`, `PROFESSOR` - RN01)

Para evitar que `tipo_pessoa` em `PESSOA` seja redundante ou permita inconsistências (ex.: uma pessoa marcada como `'A'` ser inserida em `PROFESSOR`), aplica-se o padrão de **Integridade Referencial com Discriminador Compartilhado**:
1. `PESSOA` declara a restrição `UNIQUE (id_pessoa, tipo_pessoa)`, onde `tipo_pessoa IN ('A', 'P')`.
2. `ALUNO` possui a coluna `tipo_pessoa CHAR(1) DEFAULT 'A' NOT NULL CHECK (tipo_pessoa = 'A')` e referencia `PESSOA(id_pessoa, tipo_pessoa)`.
3. `PROFESSOR` possui a coluna `tipo_pessoa CHAR(1) DEFAULT 'P' NOT NULL CHECK (tipo_pessoa = 'P')` e referencia `PESSOA(id_pessoa, tipo_pessoa)`.

Como `tipo_pessoa` em `ALUNO` e `PROFESSOR` admite apenas uma constante fixa de 1 caractere (`'A'` ou `'P'`), toda dependência funcional continua tendo `id_pessoa` como determinante único, mantendo **FNBC** e garantindo no próprio DDL que nenhum aluno exista na tabela `PROFESSOR` e vice-versa.

---

## 6. Forma Normal de Boyce-Codd (FNBC / BCNF) — Quadro Síntese

**Definição:** Uma relação está na **FNBC** se e somente se, para toda dependência funcional não-trivial `X → Y`, o determinante `X` é uma **superchave** da relação.

| # | Relação | Chaves Candidatas (Superchaves Mínimas) | Dependências Funcionais Não-Triviais (`X → Y`) | `X` é Superchave? | Forma Normal |
|---|---|---|---|---|---|
| 1 | `DEPARTAMENTO` | `{id_departamento}`, `{sigla}`, `{nome}` | `id_departamento → {nome, sigla}`<br>`sigla → {id_departamento, nome}`<br>`nome → {id_departamento, sigla}` | Sim | **FNBC** |
| 2 | `CURSO` | `{id_curso}`, `{nome}` | `id_curso → {nome, carga_horaria, id_departamento}`<br>`nome → {id_curso, carga_horaria, id_departamento}` | Sim | **FNBC** |
| 3 | `DISCIPLINA` | `{id_disciplina}`, `{codigo}` | `id_disciplina → {codigo, nome, carga_horaria, id_departamento}`<br>`codigo → {id_disciplina, nome, carga_horaria, id_departamento}` | Sim | **FNBC** |
| 4 | `PRE_REQUISITO` | `{id_disciplina, id_disciplina_req}` | *(Apenas DFs triviais — relação toda-chave)* | Sim | **FNBC** |
| 5 | `PESSOA` | `{id_pessoa}`, `{cpf}`, `{email}` | `id_pessoa → {cpf, nome, data_nascimento, email, tipo_pessoa, rua, numero, bairro, cidade, cep}`<br>`cpf → {id_pessoa, ...}`<br>`email → {id_pessoa, ...}` | Sim | **FNBC** |
| 6 | `TELEFONE_PESSOA` | `{id_pessoa, telefone}` | *(Apenas DFs triviais — relação toda-chave)* | Sim | **FNBC** |
| 7 | `ALUNO` | `{id_pessoa}`, `{matricula}` | `id_pessoa → {tipo_pessoa, matricula, data_ingresso, id_curso}`<br>`matricula → {id_pessoa, tipo_pessoa, data_ingresso, id_curso}` | Sim | **FNBC** |
| 8 | `PROFESSOR` | `{id_pessoa}` | `id_pessoa → {tipo_pessoa, titulacao, data_admissao, id_departamento}` | Sim | **FNBC** |
| 9 | `TURMA` | `{id_turma}` | `id_turma → {semestre, vagas_total, sala, dia_semana, hora_inicio, hora_fim, id_disciplina, id_professor}` | Sim | **FNBC** |
| 10 | `MATRICULA` | `{id_aluno, id_turma}` | `{id_aluno, id_turma} → {data_matricula, nota_final, frequencia, status_matricula}` | Sim | **FNBC** |
| 11 | `AUDITORIA_NOTA` | `{id_auditoria}` | `id_auditoria → {id_aluno, id_turma, nota_anterior, nota_nova, data_alteracao, usuario}` | Sim | **FNBC** |
| 12 | `OBRA` | `{id_obra}` | `id_obra → {titulo, tipo, ano_publicacao, editora}` | Sim | **FNBC** |
| 13 | `AUTOR` | `{id_autor}` | `id_autor → {nome}` | Sim | **FNBC** |
| 14 | `AUTORIA` | `{id_obra, id_autor}` | *(Apenas DFs triviais — relação toda-chave)* | Sim | **FNBC** |
| 15 | `EXEMPLAR` | `{id_obra, numero_exemplar}` | `{id_obra, numero_exemplar} → {data_aquisicao}` | Sim | **FNBC** |
| 16 | `EMPRESTIMO` | `{id_emprestimo}` | `id_emprestimo → {id_pessoa, id_obra, numero_exemplar, data_emprestimo, data_prevista_devolucao, data_devolucao}` | Sim | **FNBC** |
| 17 | `RESERVA` | `{id_reserva}` | `id_reserva → {id_pessoa, id_obra, data_reserva, situacao}` | Sim | **FNBC** |
| 18 | `MULTA` | `{id_multa}`, `{id_emprestimo}` | `id_multa → {id_emprestimo, valor, data_geracao, data_pagamento}`<br>`id_emprestimo → {id_multa, valor, data_geracao, data_pagamento}` | Sim | **FNBC** |