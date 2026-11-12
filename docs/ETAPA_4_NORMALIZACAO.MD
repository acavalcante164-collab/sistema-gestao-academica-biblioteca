# ETAPA 4: Memorial de Dependências Funcionais e Normalização (1FN à FNBC)

**Projeto:** Sistema Integrado de Gestão Acadêmica e Biblioteca (SIGAB) — Grupo 06  
**Disciplina:** DCC 502 - Banco de Dados I (UFRR)  
**Milestone:** M2 - Modelo Relacional e Normalização (Issue #5)  

---

## 1. Visão Geral do Mapeamento Relacional (Baseado na Etapa 2 - DER)

A partir das 15 entidades e 16 relacionamentos levantados na Etapa 2 (`Levantamento_DER`), o mapeamento para o modelo relacional resulta em **18 relações** (as 15 entidades mais 3 tabelas originadas de atributo multivalorado e relacionamentos `N:M` sem atributos próprios):

1. **PESSOA** (<u>id_pessoa</u>, cpf, nome, data_nascimento, email, rua, numero, bairro, cidade, cep, tipo_pessoa)
2. **TELEFONE_PESSOA** (<u>id_pessoa</u>, <u>telefone</u>)
3. **ALUNO** (<u>id_pessoa</u>, matricula, data_ingresso, id_curso)
4. **PROFESSOR** (<u>id_pessoa</u>, titulacao, data_admissao, id_departamento)
5. **DEPARTAMENTO** (<u>id_departamento</u>, nome, sigla)
6. **CURSO** (<u>id_curso</u>, nome, carga_horaria, id_departamento)
7. **DISCIPLINA** (<u>id_disciplina</u>, codigo, nome, carga_horaria, id_departamento)
8. **PRE_REQUISITO** (<u>id_disciplina</u>, <u>id_disciplina_req</u>)
9. **TURMA** (<u>id_turma</u>, semestre, vagas_total, sala, horario, id_disciplina, id_professor)
10. **MATRICULA** (<u>id_aluno</u>, <u>id_turma</u>, data_matricula, nota_final, frequencia, situacao)
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

**Definição:** Uma relação encontra-se na **1FN** se e somente se todos os seus atributos contêm apenas valores atômicos (indivisíveis) e não existem atributos compostos ou grupos repetitivos (multivalorados).

### 2.1. Tratamento de `endereco` (Composto) e `telefone` (Multivalorado) em `PESSOA`
* **Esquema Preliminar (Não Normalizado - UNF):**
  * **PESSOA_UNF** (<u>id_pessoa</u>, cpf, nome, data_nascimento, email, endereco(rua, numero, bairro, cidade, cep), {telefone})
* **Violações da 1FN identificadas:**
  1. O atributo `endereco` é composto por cinco subatributos (`rua`, `numero`, `bairro`, `cidade`, `cep`).
  2. O atributo `{telefone}` é multivalorado, pois uma mesma pessoa pode possuir mais de um número de telefone cadastrado.
* **Decomposição para 1FN:**
  1. Os componentes do endereço composto são achatados em atributos simples e atômicos diretamente na relação `PESSOA`.
  2. O atributo multivalorado `{telefone}` é extraído para uma nova relação `TELEFONE_PESSOA`, cuja chave primária é composta pela chave estrangeira `id_pessoa` e pelo próprio atributo `telefone`.
* **Relações Resultantes em 1FN:**
  * **PESSOA** (<u>id_pessoa</u>, cpf, nome, data_nascimento, email, rua, numero, bairro, cidade, cep, tipo_pessoa)
  * **TELEFONE_PESSOA** (<u>id_pessoa</u>, <u>telefone</u>)

### 2.2. Tratamento de Múltiplos Autores por Obra (Relacionamento R9)
* **Esquema Preliminar (UNF):**
  * **OBRA_UNF** (<u>id_obra</u>, titulo, tipo, ano_publicacao, editora, {id_autor, nome_autor})
* **Decomposição para 1FN:** Separação do grupo repetitivo de autores na entidade `AUTOR` e na relação associativa `AUTORIA`:
  * **OBRA** (<u>id_obra</u>, titulo, tipo, ano_publicacao, editora)
  * **AUTOR** (<u>id_autor</u>, nome)
  * **AUTORIA** (<u>id_obra</u>, <u>id_autor</u>)

---

## 3. Segunda Forma Normal (2FN)

**Definição:** Uma relação está na **2FN** se está na 1FN e todo atributo não-primo (que não pertence a nenhuma chave candidata) é total e funcionalmente dependente de **toda** a chave primária (ausência de dependências funcionais parciais).

> **Observação Formal:** Todas as relações do esquema cuja chave primária é simples (`PESSOA`, `ALUNO`, `PROFESSOR`, `DEPARTAMENTO`, `CURSO`, `DISCIPLINA`, `TURMA`, `AUDITORIA_NOTA`, `OBRA`, `AUTOR`, `EMPRESTIMO`, `RESERVA`, `MULTA`) e que já estão na 1FN encontram-se **automaticamente na 2FN**, pois não há como existir dependência parcial de uma chave de atributo único. A verificação de 2FN concentra-se nas relações com **chave primária composta**.

### 3.1. Análise da Entidade Associativa `MATRICULA` (R6)
* **Cenário com Violação de 2FN (Hipotético antes da decomposição):**
  Se a relação `MATRICULA` armazenasse informações da turma ou do aluno junto ao registro de matrícula:
  * **MATRICULA_1FN** (<u>id_aluno</u>, <u>id_turma</u>, data_matricula, nota_final, frequencia, situacao, matricula_aluno, semestre_turma, id_disciplina)
* **Dependências Funcionais identificadas:**
  * `DF1:` `{id_aluno, id_turma} → {data_matricula, nota_final, frequencia, situacao}` *(Dependência Total)*
  * `DF2:` `{id_aluno} → {matricula_aluno}` *(Violação de 2FN — Dependência Parcial)*
  * `DF3:` `{id_turma} → {semestre_turma, id_disciplina}` *(Violação de 2FN — Dependência Parcial)*
* **Solução no Modelo SIGAB (Conformidade com 2FN):**
  Os atributos parcialmente dependentes permanecem exclusivamente nas relações `ALUNO` e `TURMA`. Na relação `MATRICULA`, restam apenas os atributos que dependem funcionalmente do par `{id_aluno, id_turma}`:
  * **MATRICULA** (<u>id_aluno</u>, <u>id_turma</u>, data_matricula, nota_final, frequencia, situacao)

### 3.2. Análise da Entidade Fraca `EXEMPLAR` (R10)
* **Esquema:** **EXEMPLAR** (<u>id_obra</u>, <u>numero_exemplar</u>, data_aquisicao)
* **Dependência Funcional:**
  * `DF1:` `{id_obra, numero_exemplar} → {data_aquisicao}`
* **Justificativa de 2FN:** O atributo não-primo `data_aquisicao` depende simultaneamente da obra (`id_obra`) e do número sequencial do exemplar dentro daquela obra (`numero_exemplar`), pois cópias físicas distintas de um mesmo livro podem ser adquiridas pela biblioteca em datas diferentes, e o exemplar de número `1` repete-se em diferentes obras. Logo, não há dependência parcial e `EXEMPLAR` está na **2FN**.

### 3.3. Análise das Relações `All-Key` (`TELEFONE_PESSOA`, `PRE_REQUISITO`, `AUTORIA`)
* **Esquemas:**
  * **TELEFONE_PESSOA** (<u>id_pessoa</u>, <u>telefone</u>)
  * **PRE_REQUISITO** (<u>id_disciplina</u>, <u>id_disciplina_req</u>)
  * **AUTORIA** (<u>id_obra</u>, <u>id_autor</u>)
* **Justificativa:** Como não possuem nenhum atributo não-primo (todos os atributos compõem a chave primária composta), não pode haver dependência parcial ou transitiva de atributos não-primos. Encontram-se automaticamente em **2FN, 3FN e FNBC**.

---

## 4. Terceira Forma Normal (3FN)

**Definição:** Uma relação está na **3FN** se está na 2FN e nenhum atributo não-primo é transitivamente dependente da chave primária (ausência de cadeias `X → Y → Z`, onde `X` é chave, `Y` não é superchave e `Z` é atributo não-primo).

### 4.1. Eliminação de Dependências Transitivas entre `ALUNO`, `CURSO` e `DEPARTAMENTO` (R1 e R3)
* **Cenário Preliminar com Violação de 3FN:**
  Se os dados do curso e do departamento estivessem embutidos em `ALUNO`:
  * **ALUNO_2FN** (<u>id_pessoa</u>, matricula, data_ingresso, id_curso, nome_curso, id_departamento, nome_departamento, sigla_departamento)
* **Cadeia Transitiva:**
  * `id_pessoa → id_curso → {nome_curso, id_departamento} → {nome_departamento, sigla_departamento}`
* **Decomposição em 3FN aplicada no SIGAB:**
  * **DEPARTAMENTO** (<u>id_departamento</u>, nome, sigla)
  * **CURSO** (<u>id_curso</u>, nome, carga_horaria, id_departamento)
  * **ALUNO** (<u>id_pessoa</u>, matricula, data_ingresso, id_curso)

### 4.2. Eliminação de Redundâncias e Atributos Derivados (`TURMA` e `EXEMPLAR`)
Conforme documentado na Etapa 2 (`Levantamento_DER`, Seção 3):
1. **Ausência de `vagas_ocupadas` em `TURMA`:** O modelo armazena apenas `vagas_total` (`id_turma → vagas_total`). A ocupação atual é obtida por contagem das matrículas ativas da turma, evitando redundância e anomalias de atualização.
2. **Ausência de `disponivel` em `EXEMPLAR`:** O status de disponibilidade de um exemplar não é armazenado estaticamente em `EXEMPLAR`; ele é verificado pela ausência de registro em `EMPRESTIMO` com `data_devolucao IS NULL` para aquele exemplar (RN10), mantendo `EXEMPLAR` livre de anomalias transitivas.

### 4.3. Justificativa Formal do Atributo `situacao` em `MATRICULA` (RN08)
* **Análise:** Na relação **MATRICULA** (<u>id_aluno</u>, <u>id_turma</u>, data_matricula, nota_final, frequencia, situacao), poder-se-ia questionar se `{nota_final, frequencia} → situacao` configuraria uma dependência transitiva.
* **Prova de Conformidade com a 3FN:** Conforme documentado nas observações da Etapa 2, o domínio do atributo `situacao` compreende `{'CURSANDO', 'APROVADO', 'REPROVADO_NOTA', 'REPROVADO_FALTA', 'TRANCADO'}`. Como o estado `'TRANCADO'` (e `'CURSANDO'` com notas parciais) é um ato administrativo/acadêmico que independe dos valores numéricos de `nota_final` e `frequencia`, o par `{nota_final, frequencia}` **não determina funcionalmente** sozinho o atributo `situacao` em todos os estados possíveis. Portanto, `situacao` depende diretamente da chave `{id_aluno, id_turma}` (sendo validada por restrição `CHECK`/Trigger no fechamento), preservando a **3FN**.

---

## 5. Forma Normal de Boyce-Codd (FNBC / BCNF) e Catálogo de Dependências Funcionais

**Definição:** Uma relação está na **FNBC** se e somente se, para toda dependência funcional não-trivial `X → Y`, o determinante `X` é uma **superchave** da relação.

A tabela a seguir consolida todas as Dependências Funcionais ($DF$) das 18 relações do esquema final e comprova que todo determinante à esquerda da seta é uma chave candidata (superchave mínima):

| # | Relação | Chaves Candidatas (Superchaves) | Dependências Funcionais Não-Triviais (`X → Y`) | `X` é Superchave? | Forma Normal |
|---|---|---|---|---|---|
| 1 | `PESSOA` | `{id_pessoa}`, `{cpf}`, `{email}` | `id_pessoa → {cpf, nome, data_nascimento, email, rua, numero, bairro, cidade, cep, tipo_pessoa}`<br>`cpf → {id_pessoa, nome, ...}`<br>`email → {id_pessoa, nome, ...}` | Sim | **FNBC** |
| 2 | `TELEFONE_PESSOA` | `{id_pessoa, telefone}` | *(Relação composta apenas pela chave — DFs triviais)* | Sim | **FNBC** |
| 3 | `ALUNO` | `{id_pessoa}`, `{matricula}` | `id_pessoa → {matricula, data_ingresso, id_curso}`<br>`matricula → {id_pessoa, data_ingresso, id_curso}` | Sim | **FNBC** |
| 4 | `PROFESSOR` | `{id_pessoa}` | `id_pessoa → {titulacao, data_admissao, id_departamento}` | Sim | **FNBC** |
| 5 | `DEPARTAMENTO` | `{id_departamento}`, `{sigla}`, `{nome}` | `id_departamento → {nome, sigla}`<br>`sigla → {id_departamento, nome}`<br>`nome → {id_departamento, sigla}` | Sim | **FNBC** |
| 6 | `CURSO` | `{id_curso}`, `{nome}` | `id_curso → {nome, carga_horaria, id_departamento}`<br>`nome → {id_curso, carga_horaria, id_departamento}` | Sim | **FNBC** |
| 7 | `DISCIPLINA` | `{id_disciplina}`, `{codigo}` | `id_disciplina → {codigo, nome, carga_horaria, id_departamento}`<br>`codigo → {id_disciplina, nome, carga_horaria, id_departamento}` | Sim | **FNBC** |
| 8 | `PRE_REQUISITO` | `{id_disciplina, id_disciplina_req}` | *(Relação composta apenas pela chave — DFs triviais)* | Sim | **FNBC** |
| 9 | `TURMA` | `{id_turma}` | `id_turma → {semestre, vagas_total, sala, horario, id_disciplina, id_professor}` | Sim | **FNBC** |
| 10 | `MATRICULA` | `{id_aluno, id_turma}` | `{id_aluno, id_turma} → {data_matricula, nota_final, frequencia, situacao}` | Sim | **FNBC** |
| 11 | `AUDITORIA_NOTA` | `{id_auditoria}` | `id_auditoria → {id_aluno, id_turma, nota_anterior, nota_nova, data_alteracao, usuario}` | Sim | **FNBC** |
| 12 | `OBRA` | `{id_obra}` | `id_obra → {titulo, tipo, ano_publicacao, editora}` | Sim | **FNBC** |
| 13 | `AUTOR` | `{id_autor}` | `id_autor → {nome}` | Sim | **FNBC** |
| 14 | `AUTORIA` | `{id_obra, id_autor}` | *(Relação composta apenas pela chave — DFs triviais)* | Sim | **FNBC** |
| 15 | `EXEMPLAR` | `{id_obra, numero_exemplar}` | `{id_obra, numero_exemplar} → {data_aquisicao}` | Sim | **FNBC** |
| 16 | `EMPRESTIMO` | `{id_emprestimo}` | `id_emprestimo → {id_pessoa, id_obra, numero_exemplar, data_emprestimo, data_prevista_devolucao, data_devolucao}` | Sim | **FNBC** |
| 17 | `RESERVA` | `{id_reserva}` | `id_reserva → {id_pessoa, id_obra, data_reserva, situacao}` | Sim | **FNBC** |
| 18 | `MULTA` | `{id_multa}`, `{id_emprestimo}` | `id_multa → {id_emprestimo, valor, data_geracao, data_pagamento}`<br>`id_emprestimo → {id_multa, valor, data_geracao, data_pagamento}` | Sim | **FNBC** |

**Conclusão:** Todas as 18 relações mapeadas a partir do DER estão comprovadamente na **1FN, 2FN, 3FN e FNBC**, sem perda de informação e preservando todas as dependências funcionais do domínio.