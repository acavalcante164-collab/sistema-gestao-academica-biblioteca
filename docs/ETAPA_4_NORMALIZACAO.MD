# ETAPA 4: Memorial de Dependências Funcionais e Normalização (1FN à FNBC)

**Projeto:** Sistema Integrado de Gestão Acadêmica e Biblioteca (SIGAB)  
**Milestone:** M2 - Modelo Relacional e Normalização  
**Referência:** Issue #5  

---

## 1. Visão Geral do Esquema Relacional Base (Pós-Mapeamento E-R)

Para demonstrar o processo formal de normalização (1FN $\rightarrow$ 2FN $\rightarrow$ 3FN $\rightarrow$ FNBC), partimos de visões preliminares não normalizadas (ou parcialmente mapeadas) extraídas do minimundo e demonstramos passo a passo as decomposições sem perda de informação (junção sem perda) e com preservação de dependências.

---

## 2. Primeira Forma Normal (1FN)
**Definição:** Uma relação está na 1FN se e somente se todos os domínios de seus atributos contêm apenas valores atômicos (indivisíveis) e não existem grupos repetitivos ou atributos multivalorados.

### 2.1. Tratamento de Atributos Compostos e Multivalorados em `PESSOA`
* **Estado Inicial (Não Normalizado - $\text{UNF}$):**
  $$\text{PESSOA\_UNF}(\underline{\text{id\_pessoa}}, \text{cpf}, \text{nome}, \text{email}, \text{tipo\_pessoa}, \text{endereco\_completo}, \{\text{telefones}\})$$
* **Análise de Violação:**
  1. `endereco_completo` é um atributo composto (contém logradouro, número, bairro, cidade, UF e CEP), prejudicando filtros analíticos por bairro ou CEP.
  2. `{telefones}` é um atributo multivalorado (uma pessoa pode possuir vários números de telefone), violando a atomicidade da 1FN.
* **Decomposição para 1FN:**
  1. Decompomos `endereco_completo` em atributos atômicos na própria tabela `PESSOA`.
  2. Removemos o grupo repetitivo `{telefones}` criando uma relação própria `TELEFONE_PESSOA`, cuja chave primária é composta pela chave estrangeira de `PESSOA` e pelo próprio número do telefone.
* **Esquema Resultante em 1FN:**
  * $\text{PESSOA}(\underline{\text{id\_pessoa}}, \text{cpf}, \text{nome}, \text{email}, \text{tipo\_pessoa}, \text{end\_logradouro}, \text{end\_numero}, \text{end\_bairro}, \text{end\_cidade}, \text{end\_uf}, \text{end\_cep})$
  * $\text{TELEFONE\_PESSOA}(\underline{\text{id\_pessoa}}, \underline{\text{numero\_telefone}}, \text{tipo\_telefone})$

### 2.2. Tratamento de Múltiplos Autores em `OBRA`
* **Estado Inicial ($\text{UNF}$):** $\text{OBRA\_UNF}(\underline{\text{id\_obra}}, \text{isbn}, \text{titulo}, \text{tipo\_obra}, \text{ano\_publicacao}, \{\text{id\_autor}, \text{nome\_autor}, \text{ordem\_autoria}\})$
* **Decomposição para 1FN:** Separação em três relações atômicas:
  * $\text{OBRA}(\underline{\text{id\_obra}}, \text{isbn}, \text{titulo}, \text{tipo\_obra}, \text{ano\_publicacao}, \text{editora})$
  * $\text{AUTOR}(\underline{\text{id\_autor}}, \text{nome\_autor}, \text{nacionalidade})$
  * $\text{AUTORIA}(\underline{\text{id\_obra}}, \underline{\text{id\_autor}}, \text{ordem\_autoria})$

---

## 3. Segunda Forma Normal (2FN)
**Definição:** Uma relação está na 2FN se está na 1FN e todo atributo não-primo (que não faz parte de nenhuma chave candidata) é total e funcionalmente dependente de toda a chave primária (ausência de dependências funcionais parciais).

> **Nota Teórica:** Relações em 1FN cuja chave primária é simples (formada por um único atributo) já estão automaticamente na 2FN. Portanto, a análise de 2FN concentra-se nas relações com **chaves primárias compostas**.

### 3.1. Análise de `MATRICULA` (Chave Composta Inicial)
* **Cenário Preliminar (1FN):** Suponha uma relação de matrícula identificada por $(\text{id\_aluno}, \text{id\_turma})$ que armazene também dados da disciplina e do aluno para facilitar relatórios:
  $$\text{MATRICULA\_1FN}(\underline{\text{id\_aluno}}, \underline{\text{id\_turma}}, \text{data\_matricula}, \text{nota\_final}, \text{frequencia}, \text{nome\_aluno}, \text{id\_disciplina}, \text{nome\_disciplina})$$
* **Dependências Funcionais Identificadas:**
  * $DF_1: \{\text{id\_aluno}, \text{id\_turma}\} \rightarrow \{\text{data\_matricula}, \text{nota\_final}, \text{frequencia}\}$ *(Dependência Total)*
  * $DF_2: \{\text{id\_aluno}\} \rightarrow \{\text{nome\_aluno}\}$ *(Violação de 2FN: Dependência Parcial)*
  * $DF_3: \{\text{id\_turma}\} \rightarrow \{\text{id\_disciplina}, \text{nome\_disciplina}\}$ *(Violação de 2FN: Dependência Parcial)*
* **Decomposição para 2FN:**
  Os atributos parcialmente dependentes são movidos para suas respectivas relações determinantes (`PESSOA`/`ALUNO` e `TURMA`/`DISCIPLINA`), restando em `MATRICULA` apenas atributos que dependem do par $(\text{id\_aluno}, \text{id\_turma})$ (ou de uma chave substituta `id_matricula` com constraint `UNIQUE(id_aluno, id_turma)` conforme RN06):
  * $\text{MATRICULA}(\underline{\text{id\_matricula}}, \text{id\_aluno}, \text{id\_turma}, \text{data\_matricula}, \text{nota\_final}, \text{frequencia}, \text{status\_matricula})$

### 3.2. Análise da Entidade Fraca `EXEMPLAR` (RN09)
* **Esquema:** $\text{EXEMPLAR}(\underline{\text{id\_obra}}, \underline{\text{num\_exemplar}}, \text{codigo\_barras}, \text{estado\_conservacao}, \text{status\_disponibilidade})$
* **Dependências Funcionais:**
  * $DF_1: \{\text{id\_obra}, \text{num\_exemplar}\} \rightarrow \{\text{codigo\_barras}, \text{estado\_conservacao}, \text{status\_disponibilidade}\}$
  * Nenhum atributo não-primo depende apenas de `id_obra` (pois exemplares diferentes da mesma obra têm códigos de barras, estados de conservação e disponibilidades distintas) nem apenas de `num_exemplar` (pois o exemplar nº 1 existe em diversas obras).
* **Conclusão:** `EXEMPLAR` encontra-se integralmente na **2FN**.

### 3.3. Análise das Tabelas Associativas (`PREREQUISITO` e `AUTORIA`)
* $\text{PREREQUISITO}(\underline{\text{id\_disciplina}}, \underline{\text{id\_disciplina\_req}})$: Composta exclusivamente por atributos primos (todos fazem parte da PK). Está automaticamente em **2FN, 3FN e FNBC**.
* $\text{AUTORIA}(\underline{\text{id\_obra}}, \underline{\text{id\_autor}}, \text{ordem\_autoria})$: O atributo `ordem_autoria` (1º autor, 2º autor) depende conjuntamente da obra e do autor ($\{\text{id\_obra}, \text{id\_autor}\} \rightarrow \text{ordem\_autoria}$). Está na **2FN**.

---

## 4. Terceira Forma Normal (3FN)
**Definição:** Uma relação está na 3FN se está na 2FN e nenhum atributo não-primo é transitivamente dependente da chave primária (ou seja, não existem dependências $X \rightarrow Y \rightarrow Z$ onde $X$ é a chave, $Y$ não é superchave e $Z$ é um atributo não-primo).

### 4.1. Análise e Decomposição em `CURSO` e `ALUNO` (RN02)
* **Cenário Preliminar (2FN):** Suponha que a tabela `ALUNO` armazene o curso e o departamento ao qual o aluno está vinculado:
  $$\text{ALUNO\_2FN}(\underline{\text{id\_pessoa}}, \text{matricula\_academica}, \text{ano\_ingresso}, \text{id\_curso}, \text{nome\_curso}, \text{id\_departamento}, \text{sigla\_depto})$$
* **Dependências Funcionais:**
  * $\text{id\_pessoa} \rightarrow \text{id\_curso}$
  * $\text{id\_curso} \rightarrow \{\text{nome\_curso}, \text{id\_departamento}\}$
  * $\text{id\_departamento} \rightarrow \text{sigla\_depto}$
* **Violação de 3FN:** Existem dependências transitivas ($\text{id\_pessoa} \rightarrow \text{id\_curso} \rightarrow \text{id\_departamento} \rightarrow \text{sigla\_depto}$). Se um curso mudar de nome, atualizaríamos múltiplos alunos (anomalia de atualização).
* **Decomposição para 3FN:**
  * $\text{DEPARTAMENTO}(\underline{\text{id\_departamento}}, \text{sigla}, \text{nome}, \text{id\_prof\_chefe})$
  * $\text{CURSO}(\underline{\text{id\_curso}}, \text{codigo\_curso}, \text{nome}, \text{carga\_horaria\_total}, \text{id\_departamento})$
  * $\text{ALUNO}(\underline{\text{id\_pessoa}}, \text{matricula\_academica}, \text{ano\_ingresso}, \text{id\_curso})$

### 4.2. Decisão Arquitetural sobre `situacao_final` em `MATRICULA` (Alerta 1.11.2 do Minimundo e RN08)
* **Problema Teórico:** Pela RN08, a situação de aprovação (`APROVADO`, `REPROVADO_NOTA`, `REPROVADO_FALTA`) é determinada por `nota_final` e `frequencia`. Logo, na tabela `MATRICULA`:
  $$\text{id\_matricula} \rightarrow \{\text{nota\_final}, \text{frequencia}\} \rightarrow \text{situacao\_final}$$
  Isso configura uma dependência transitiva (atributo derivado).
* **Solução Adotada para Conformidade Estrita com 3FN/FNBC:**
  1. Na tabela `MATRICULA`, armazenamos o atributo `status_matricula` restrito ao estado operacional do vínculo (`CURSANDO`, `CONCLUIDA`, `TRANCADA`), que **não** depende de nota ou frequência.
  2. A situação pedagógica final (`APROVADO`, `REPROVADO_NOTA`, `REPROVADO_FALTA`, `TRANCADO`, `EM_CURSO`) é calculada dinamicamente na camada de visões (`VW_HISTORICO_ACADEMICO`) ou coluna virtual (`GENERATED ALWAYS AS`), eliminando 100% da anomalia de atualização e mantendo a tabela `MATRICULA` estritamente em **3FN e FNBC**.

### 4.3. Decisão Arquitetural sobre `vagas_ocupadas` em `TURMA` (Alerta 1.11.3 do Minimundo e RN04)
* **Problema Teórico:** O número de vagas ocupadas é derivado da contagem de registros ativos em `MATRICULA`.
* **Solução Adotada:** A tabela `TURMA` armazena `vagas_total` (dependência direta $\text{id\_turma} \rightarrow \text{vagas\_total}$). Para viabilizar o requisito de controle de concorrência com `SELECT ... FOR UPDATE` na linha da turma (Issue #12) e validação imediata via Trigger (Issue #11), mantém-se `vagas_ocupadas` controlada exclusivamente por trigger transacional (`TRG_CONTROLE_VAGAS_MATRICULA`), documentando-se formalmente essa decisão de projeto físico para garantia de isolamento concorrente no Oracle.

### 4.4. Análise de `EMPRESTIMO` e `MULTA` (RN12 e RN13)
* **Empréstimo:** $\text{EMPRESTIMO}(\underline{\text{id\_emprestimo}}, \text{id\_pessoa}, \text{id\_obra}, \text{num\_exemplar}, \text{data\_emprestimo}, \text{data\_prevista\_devolucao}, \text{data\_devolucao\_real})$
  * A `data_prevista_devolucao` depende de `data_emprestimo` e do `tipo_pessoa` (RN12: +7 dias aluno, +15 dias professor). Como `tipo_pessoa` reside em `PESSOA` (outra relação), não há dependência transitiva interna na relação `EMPRESTIMO` que viole a 3FN, mas seu valor é fixado na inserção via Trigger para preservar o histórico caso a regra de prazo mude no futuro.
* **Multa:** $\text{MULTA}(\underline{\text{id\_multa}}, \text{id\_emprestimo}, \text{valor\_multa}, \text{dias\_atraso}, \text{status\_pagamento}, \text{data\_geracao}, \text{data\_pagamento})$
  * Relacionamento 1:1 opcional com `EMPRESTIMO` (`id_emprestimo` possui constraint `UNIQUE`). Todos os atributos dependem diretamente da chave `id_multa` e da chave candidata `id_emprestimo`. Encontra-se em **3FN**.

---

## 5. Forma Normal de Boyce-Codd (FNBC / BCNF)
**Definição:** Uma relação está na FNBC se e somente se, para toda dependência funcional não-trivial $X \rightarrow Y$ válida na relação, o determinante $X$ é uma **superchave** da relação.

### 5.1. Verificação de Chaves Candidatas Superpostas no Esquema SIGAB
Avaliamos todas as relações do esquema em 3FN em busca de determinantes que não sejam superchaves:

| Relação | Chaves Candidatas (Superchaves Mínimas) | Dependências Funcionais Não-Triviais ($X \rightarrow Y$) | $X$ é Superchave? | Conformidade FNBC |
|---|---|---|---|---|
| `PESSOA` | $\{id\_pessoa\}$, $\{cpf\}$, $\{email\}$ | $id\_pessoa \rightarrow \text{todos}$; $cpf \rightarrow \text{todos}$; $email \rightarrow \text{todos}$ | Sim | **Sim (FNBC)** |
| `TELEFONE_PESSOA` | $\{id\_pessoa, numero\_telefone\}$ | $\{id\_pessoa, numero\_telefone\} \rightarrow tipo\_telefone$ | Sim | **Sim (FNBC)** |
| `DEPARTAMENTO` | $\{id\_departamento\}$, $\{sigla\}$, $\{id\_prof\_chefe\}$ | $id\_departamento \rightarrow \text{todos}$; $sigla \rightarrow \text{todos}$ | Sim | **Sim (FNBC)** |
| `PROFESSOR` | $\{id\_pessoa\}$, $\{siape\}$ | $id\_pessoa \rightarrow \text{todos}$; $siape \rightarrow \text{todos}$ | Sim | **Sim (FNBC)** |
| `CURSO` | $\{id\_curso\}$, $\{codigo\_curso\}$ | $id\_curso \rightarrow \text{todos}$; $codigo\_curso \rightarrow \text{todos}$ | Sim | **Sim (FNBC)** |
| `ALUNO` | $\{id\_pessoa\}$, $\{matricula\_academica\}$ | $id\_pessoa \rightarrow \text{todos}$; $matricula\_academica \rightarrow \text{todos}$ | Sim | **Sim (FNBC)** |
| `DISCIPLINA` | $\{id\_disciplina\}$, $\{codigo\_disc\}$ | $id\_disciplina \rightarrow \text{todos}$; $codigo\_disc \rightarrow \text{todos}$ | Sim | **Sim (FNBC)** |
| `PREREQUISITO` | $\{id\_disciplina, id\_disciplina\_req\}$ | *(Apenas DFs triviais — relação toda chave)* | Sim | **Sim (FNBC)** |
| `TURMA` | $\{id\_turma\}$, $\{id\_disciplina, semestre, codigo\_turma\}$ | $id\_turma \rightarrow \text{todos}$; $\{id\_disciplina, semestre, codigo\_turma\} \rightarrow \text{todos}$ | Sim | **Sim (FNBC)** |
| `MATRICULA` | $\{id\_matricula\}$, $\{id\_aluno, id\_turma\}$ | $id\_matricula \rightarrow \text{todos}$; $\{id\_aluno, id\_turma\} \rightarrow \text{todos}$ | Sim | **Sim (FNBC)** |
| `HISTORICO_NOTA_LOG`| $\{id\_log\}$ | $id\_log \rightarrow \text{todos}$ | Sim | **Sim (FNBC)** |
| `OBRA` | $\{id\_obra\}$, $\{isbn\}$ | $id\_obra \rightarrow \text{todos}$; $isbn \rightarrow \text{todos}$ | Sim | **Sim (FNBC)** |
| `AUTOR` | $\{id\_autor\}$ | $id\_autor \rightarrow \{\text{nome\_autor}, \text{nacionalidade}\}$ | Sim | **Sim (FNBC)** |
| `AUTORIA` | $\{id\_obra, id\_autor\}$ | $\{id\_obra, id\_autor\} \rightarrow ordem\_autoria$ | Sim | **Sim (FNBC)** |
| `EXEMPLAR` | $\{id\_obra, num\_exemplar\}$, $\{codigo\_barras\}$ | $\{id\_obra, num\_exemplar\} \rightarrow \text{todos}$; $codigo\_barras \rightarrow \text{todos}$ | Sim | **Sim (FNBC)** |
| `EMPRESTIMO` | $\{id\_emprestimo\}$ | $id\_emprestimo \rightarrow \text{todos}$ | Sim | **Sim (FNBC)** |
| `RESERVA` | $\{id\_reserva\}$ | $id\_reserva \rightarrow \text{todos}$ | Sim | **Sim (FNBC)** |
| `MULTA` | $\{id\_multa\}$, $\{id\_emprestimo\}$ | $id\_multa \rightarrow \text{todos}$; $id\_emprestimo \rightarrow \text{todos}$ | Sim | **Sim (FNBC)** |

**Conclusão do Memorial:** Todas as 18 relações que compõem o modelo relacional final do SIGAB encontram-se rigorosamente na **Forma Normal de Boyce-Codd (FNBC)**, garantindo ausência de redundâncias de dados e proteção contra anomalias de inserção, exclusão e atualização.