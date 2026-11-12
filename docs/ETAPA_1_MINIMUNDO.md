
# ETAPA 1: Definição do Minimundo

**Projeto:** Sistema Integrado de Gestão Acadêmica e Biblioteca (SIGAA)  
**Equipe:** Alonso, Ruan, Gwylhermme e Francisco  
**SGBD:** Oracle Database, via SQL Developer

---

## 1.1 Descrição do negócio

O minimundo é uma instituição de ensino superior que administra, no mesmo sistema, dois processos hoje tratados separadamente: a **vida acadêmica** (cursos, disciplinas, turmas, matrículas, notas e frequência) e a **biblioteca** (acervo, exemplares, empréstimos, reservas e multas).

A instituição é organizada em **departamentos**, que ofertam **cursos** e **disciplinas** e abrigam **professores**. Cada semestre, os departamentos abrem **turmas**, que são ofertas de uma disciplina conduzidas por um professor, com horário, sala e número limitado de vagas. Os alunos se **matriculam** nas turmas e, ao longo do semestre, recebem nota e frequência, até a situação final (aprovado, reprovado por nota, reprovado por falta ou trancado).

A biblioteca mantém um **acervo de obras** (livros, periódicos, TCCs). Cada obra tem um ou mais **exemplares físicos** numerados, que podem ser emprestados a alunos e professores. Quando todos os exemplares estão emprestados, o usuário pode fazer uma **reserva**. Devoluções em atraso geram **multas**, e o usuário com multa pendente fica impedido de novos empréstimos.

O ponto de integração entre os dois módulos é a **Pessoa**: o mesmo cadastro de aluno ou professor serve à matrícula e ao empréstimo. Isso permite regras cruzadas, como bloquear a rematrícula de quem tem pendência na biblioteca.

## 1.2 Problema que o sistema resolve

- **Redundância e inconsistência:** o mesmo aluno cadastrado em planilhas diferentes (secretaria e biblioteca), com dados divergentes.
- **Matrículas acima da capacidade:** sem controle automático de vagas, turmas ultrapassam o limite.
- **Matrícula sem pré-requisito:** a validação manual falha e permite matrícula em disciplinas sem pré-requisito cumprido.
- **Controle frágil do acervo:** não há rastreio de qual exemplar está com quem, nem de atrasos.
- **Falta de visão gerencial:** é difícil responder perguntas como “quais disciplinas têm mais reprovação por falta?” ou “quais obras são mais emprestadas?”.

## 1.3 Objetivos

### Objetivo geral

Projetar, normalizar, implementar e validar um banco de dados relacional em Oracle que integre a gestão acadêmica e a biblioteca, garantindo integridade, consistência e suporte a consultas analíticas.

### Objetivos específicos

1. Modelar o domínio com DER formal, com pelo menos 6 entidades.
2. Mapear o DER para o modelo relacional e demonstrar a normalização até a FNBC.
3. Implementar o esquema com constraints nomeadas e regras de negócio via `CHECK`.
4. Automatizar regras críticas com triggers (vagas, bloqueio de empréstimo, auditoria de notas).
5. Disponibilizar consultas analíticas e views para gestão e segurança.
6. Demonstrar controle transacional e tratamento de concorrência.

## 1.4 Escopo

### Dentro do escopo

- Cadastro de departamentos, cursos, disciplinas (com pré-requisitos), turmas, professores e alunos.
- Matrícula em turmas, lançamento de nota e frequência, e apuração da situação final.
- Cadastro de obras, autores, exemplares, empréstimos, reservas e multas.
- Regras de integridade e automação por triggers.
- Consultas gerenciais e views.

### Fora do escopo

Para manter o projeto viável no prazo, não serão implementados:

- Interface gráfica, autenticação de usuários e perfis de acesso reais (a “segurança” será demonstrada via view).
- Financeiro (mensalidades, pagamento de multas por gateway).
- Grade horária com detecção de conflito de salas.
- Histórico escolar oficial e emissão de diplomas.

## 1.5 Atores

| Ator | Papel no sistema |
|---|---|
| **Aluno** | Matricula-se em turmas, consulta notas, pega livros emprestados e faz reservas. |
| **Professor** | Ministra turmas, lança notas e frequência, e também pode pegar livros emprestados. |
| **Secretaria acadêmica** | Cadastra cursos, disciplinas, turmas e alunos, e gerencia matrículas. |
| **Bibliotecário** | Cadastra o acervo, registra empréstimos, devoluções, reservas e multas. |
| **Coordenador/Chefe de departamento** | Consulta indicadores de desempenho e demanda. |

## 1.6 Requisitos funcionais

| ID | Requisito |
|---|---|
| RF01 | Cadastrar e manter pessoas (alunos e professores), com endereço e telefones. |
| RF02 | Cadastrar departamentos, cursos e disciplinas, incluindo pré-requisitos. |
| RF03 | Criar turmas por semestre, com professor, vagas, sala e horário. |
| RF04 | Matricular aluno em turma, validando vagas e pré-requisitos. |
| RF05 | Lançar nota e frequência, e calcular a situação final da matrícula. |
| RF06 | Cadastrar obras, autores e exemplares. |
| RF07 | Registrar empréstimo de exemplar a um usuário e sua devolução. |
| RF08 | Registrar reserva de obra quando não há exemplar disponível. |
| RF09 | Gerar multa automática por atraso na devolução. |
| RF10 | Registrar auditoria das alterações de nota. |
| RF11 | Emitir consultas e views gerenciais (desempenho, acervo, inadimplência). |

## 1.7 Requisitos não funcionais

| ID | Requisito |
|---|---|
| RNF01 | Todo o código deve ser compatível com Oracle Database (`VARCHAR2`, `NUMBER`, `DATE`). |
| RNF02 | Todas as constraints devem ter nomes explícitos e padronizados. |
| RNF03 | O esquema deve estar em, no mínimo, 3FN, com avaliação da FNBC. |
| RNF04 | Os scripts devem ser reexecutáveis e rodar em ordem (01 a 05). |
| RNF05 | As transações devem respeitar as propriedades ACID. |
| RNF06 | Nomenclatura padronizada: tabelas em maiúsculas e singular, PKs `PK_<TABELA>`, FKs `FK_<ORIGEM>_<DESTINO>`. |

## 1.8 Regras de negócio

| ID | Regra |
|---|---|
| RN01 | Toda pessoa é exclusivamente aluno ou professor (especialização disjunta e total). |
| RN02 | Um aluno pertence a exatamente um curso; um curso pertence a exatamente um departamento. |
| RN03 | Uma turma tem uma única disciplina, um único professor responsável e um semestre. |
| RN04 | O número de matrículas ativas em uma turma não pode exceder suas vagas. |
| RN05 | O aluno só pode se matricular em disciplina cujos pré-requisitos tenha cumprido. |
| RN06 | Um aluno não pode se matricular duas vezes na mesma turma. |
| RN07 | Nota deve estar entre 0 e 10; frequência, entre 0 e 100%. |
| RN08 | Aprovação exige nota final de pelo menos 6,0 e frequência de pelo menos 75%; abaixo de 75% a reprovação é por falta, independentemente da nota. |
| RN09 | Cada exemplar pertence a uma obra e é identificado pelo número do exemplar dentro dela. |
| RN10 | Um exemplar só pode ter um empréstimo em aberto por vez. |
| RN11 | Alunos podem ter até 3 empréstimos simultâneos; professores, até 5. |
| RN12 | O prazo de empréstimo é de 7 dias para alunos e 15 para professores. |
| RN13 | Atraso na devolução gera multa de R$ 1,00 por dia de atraso. |
| RN14 | Usuário com multa pendente não pode fazer novo empréstimo. |
| RN15 | Reserva só é permitida para obra sem exemplar disponível. |
| RN16 | Toda alteração de nota deve ser registrada em log (valor anterior, novo valor, data e usuário). |
| RN17 | Todo professor pertence a exatamente um departamento. |

> [!IMPORTANT]
> Os valores numéricos (6,0, 75%, 3/5 empréstimos, 7/15 dias, R$ 1,00) são **parâmetros propostos pela nossa equipe**, com base em práticas comuns.

## 1.9 Processos principais

1. **Matrícula:** a secretaria abre a turma, o aluno solicita matrícula, e o sistema valida vagas, pré-requisito e duplicidade antes de confirmar.
2. **Fechamento de semestre:** o professor lança nota e frequência, e o sistema calcula a situação final.
3. **Empréstimo:** o bibliotecário registra o empréstimo, e o sistema valida limite, multa pendente e disponibilidade do exemplar.
4. **Devolução:** o bibliotecário registra a devolução, e o sistema gera multa automaticamente se houve atraso.
5. **Reserva:** quando não há exemplar disponível, o usuário reserva a obra e entra na fila.

## 1.10 Exemplos de utilização

- **Matrícula bem-sucedida:** Ana, do curso de Ciência da Computação, solicita matrícula em *Banco de Dados I – Turma A*. Há vaga e ela cumpriu *Estruturas de Dados* (pré-requisito), então a matrícula é aceita.
- **Matrícula bloqueada:** Bruno tenta se matricular na mesma turma, mas as 40 vagas já estão ocupadas. O sistema rejeita a operação.
- **Empréstimo com atraso:** Carla pega o exemplar 2 de *Database System Concepts* por 7 dias e devolve 3 dias depois do prazo. O sistema gera uma multa de R$ 3,00, e ela fica impedida de novos empréstimos até quitá-la.
- **Reserva:** todos os exemplares de *Sistemas Operacionais Modernos* estão emprestados. Diego reserva a obra e entra na fila.
- **Consulta gerencial:** o coordenador pergunta quais disciplinas tiveram mais reprovações por falta no semestre. O sistema responde via consulta analítica.

## 1.11 Revisão de consistência e alertas

### Decisões que impactam etapas posteriores

1. **Pessoa como supertipo (RN01):** a especialização exige escolher a estratégia de mapeamento (uma tabela por subtipo com PK/FK compartilhada). Essa decisão será tomada na Etapa 3. A proposta inicial é utilizar **PESSOA + ALUNO + PROFESSOR**, para preservar a integração do usuário da biblioteca.

2. **Situação final (RN08):** a situação pode ser **derivada** (calculada por consulta) ou **armazenada**. Armazená-la cria dependência transitiva, o que afeta a normalização na Etapa 4. A recomendação é armazená-la com justificativa e tratá-la por trigger, ou derivá-la em uma view. A decisão deverá ser tomada até a Etapa 3.

3. **Vagas disponíveis:** guardar apenas `vagas_total` e **contar** as matrículas evita redundância. Se guardarmos `vagas_ocupadas`, ela precisará de trigger para permanecer consistente.

### Problemas possíveis

- **Concorrência nas matrículas:** pode ocorrer conflito entre a RN04 e duas matrículas simultâneas disputando a última vaga. Esse cenário será tratado na Etapa 10 com bloqueio de linha.
