#!/usr/bin/env bash
# Configura milestones, labels e issues do projeto no GitHub.
# Requisitos: GitHub CLI (gh), jq e autenticação via `gh auth login`.
# Execute na pasta local do repositório.

set -Eeuo pipefail

REPO_NAME="sistema-gestao-academica-biblioteca"
REPO="$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || true)"

if [[ -z "$REPO" ]]; then
  echo "ERRO: esta pasta não está associada a um repositório GitHub."
  echo "Crie o repositório '$REPO_NAME', conecte-o como origin e execute novamente."
  exit 1
fi

if [[ "${REPO##*/}" != "$REPO_NAME" ]]; then
  echo "ERRO: repositório atual: $REPO"
  echo "Este script foi preparado para: $REPO_NAME"
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERRO: jq não foi encontrado. Instale o jq e tente novamente."
  exit 1
fi

echo "Repositório detectado: $REPO"
echo "Configurando visibilidade pública (conforme solicitado)..."
gh repo edit "$REPO" --visibility public --accept-visibility-change-consequences

# Datas de referência: prazo final 15/11/2026.
# Milestones distribuídos de forma compacta para o prazo informado.
create_milestone() {
  local title="$1"
  local due="$2"

  if gh api "repos/$REPO/milestones?state=all&per_page=100" --paginate \
      --jq '.[].title' | grep -Fxq "$title"; then
    echo "Milestone já existe: $title"
  else
    gh api "repos/$REPO/milestones" --method POST \
      -f title="$title" \
      -f due_on="${due}T23:59:00Z" \
      -f state="open" >/dev/null
    echo "Milestone criado: $title (prazo $due)"
  fi
}

echo
echo "== 1/3: Milestones =="

create_milestone "M1 - Analise e Modelagem" "2026-11-10"
create_milestone "M2 - Modelo Relacional e Normalizacao" "2026-11-11"
create_milestone "M3 - Implementacao SQL" "2026-11-12"
create_milestone "M4 - Recursos Avancados" "2026-11-14"
create_milestone "M5 - Testes e Entrega" "2026-11-15"

create_label() {
  local name="$1"
  local color="$2"
  local description="$3"

  if gh label list --repo "$REPO" --limit 200 --json name --jq '.[].name' |
      grep -Fxq "$name"; then
    echo "Label já existe: $name"
  else
    gh label create "$name" --repo "$REPO" \
      --color "$color" --description "$description" >/dev/null
    echo "Label criada: $name"
  fi
}

echo
echo "== 2/3: Labels =="

create_label "type: documentation" "0075CA" "Documentacao, relatorio e instrucoes"
create_label "type: database" "7057FF" "Implementacao SQL e banco de dados"
create_label "type: modeling" "1D76DB" "DER, modelo relacional e normalizacao"
create_label "type: testing" "0E8A16" "Testes, validacoes e evidencias"
create_label "type: bug" "D73A4A" "Defeito ou comportamento incorreto"
create_label "type: research" "C5DEF5" "Levantamento e pesquisa"
create_label "priority: critical" "B60205" "Bloqueia a entrega ou compromete requisito essencial"
create_label "priority: high" "FF8C00" "Prioridade alta"
create_label "priority: medium" "FBCA04" "Prioridade media"
create_label "priority: low" "C2E0C6" "Prioridade baixa"
create_label "status: todo" "EDEDED" "Ainda nao iniciada"
create_label "status: in progress" "0052CC" "Em desenvolvimento"
create_label "status: review" "5319E7" "Aguardando revisao"
create_label "status: blocked" "B60205" "Bloqueada por dependencia ou impedimento"

create_issue() {
  local title="$1"
  local milestone="$2"
  local labels="$3"
  local body="$4"

  if gh issue list --repo "$REPO" --state all --limit 500 \
      --json title --jq '.[].title' | grep -Fxq "$title"; then
    echo "Issue já existe: $title"
  else
    gh issue create --repo "$REPO" \
      --title "$title" \
      --body "$body" \
      --milestone "$milestone" \
      --label "$labels"
    echo "Issue criada: $title"
  fi
}

echo
echo "== 3/3: Issues =="

create_issue \
  "Definir o minimundo do sistema" \
  "M1 - Analise e Modelagem" \
  "type: documentation,priority: critical,status: todo" \
  "$(cat <<'EOF'
## Objetivo
Descrever o cenário, os limites e os atores do sistema integrado de gestão acadêmica e biblioteca.

## Atividades
- [ ] Descrever o módulo acadêmico: departamentos, cursos, disciplinas, pré-requisitos, turmas e matrículas.
- [ ] Descrever o módulo biblioteca: obras, autores, exemplares, empréstimos, reservas e multas.
- [ ] Descrever Pessoa como supertipo e Aluno/Professor como subtipos.
- [ ] Definir os perfis de usuário e os limites do sistema.
- [ ] Registrar premissas e termos do domínio.

## Critérios de aceitação
- [ ] Minimundo escrito de forma clara e sem ambiguidades.
- [ ] Todos os módulos do escopo estão contemplados.
- [ ] Documento revisado pelos quatro integrantes.

## Dependências
Nenhuma. Esta é a atividade inicial.
EOF
)"

create_issue \
  "Levantar requisitos e regras de negócio" \
  "M1 - Analise e Modelagem" \
  "type: research,priority: critical,status: todo" \
  "$(cat <<'EOF'
## Objetivo
Transformar o minimundo em requisitos funcionais, restrições e regras de negócio verificáveis.

## Atividades
- [ ] Definir regras de matrícula, pré-requisitos, capacidade de turma, nota e frequência.
- [ ] Definir regras de empréstimo, limite por aluno, multas, reservas e devoluções.
- [ ] Definir a regra de professor chefe de departamento ou a alternativa Aluno–Conta de biblioteca.
- [ ] Definir endereço composto e telefones multivalorados.
- [ ] Definir regras de auditoria de alterações de notas.
- [ ] Identificar dados obrigatórios, únicos e opcionais.

## Critérios de aceitação
- [ ] Regras numeradas e rastreáveis.
- [ ] Regras sem contradições com o minimundo.
- [ ] Requisitos revisados pelo grupo.

## Dependências
Depende de: Definir o minimundo do sistema.
EOF
)"

create_issue \
  "Construir o DER completo" \
  "M1 - Analise e Modelagem" \
  "type: modeling,priority: critical,status: todo" \
  "$(cat <<'EOF'
## Objetivo
Construir o Diagrama Entidade-Relacionamento contemplando todo o escopo aprovado.

## Atividades
- [ ] Modelar Departamento, Curso, Disciplina, Turma e Matrícula.
- [ ] Modelar Obra, Autor, Autoria, Exemplar, Empréstimo, Reserva e Multa.
- [ ] Modelar Pessoa como supertipo e Aluno/Professor como especialização.
- [ ] Representar endereço composto e telefones multivalorados.
- [ ] Representar relacionamentos 1:1, 1:N e N:M.
- [ ] Representar Exemplar como entidade fraca, se confirmado pela semântica e pelas regras do trabalho.
- [ ] Definir participação, cardinalidade e atributos identificadores.

## Critérios de aceitação
- [ ] DER legível e completo.
- [ ] Cardinalidades e restrições documentadas.
- [ ] Decisões de modelagem justificadas.
- [ ] Arquivo editável e exportação PNG salvos em diagramas/.

## Dependências
Depende de: Definir o minimundo do sistema; Levantar requisitos e regras de negócio.
EOF
)"

create_issue \
  "Converter DER em modelo relacional" \
  "M2 - Modelo Relacional e Normalizacao" \
  "type: modeling,priority: high,status: todo" \
  "$(cat <<'EOF'
## Objetivo
Mapear o DER aprovado para relações, chaves e restrições relacionais.

## Atividades
- [ ] Converter entidades fortes em tabelas.
- [ ] Mapear especialização Pessoa/Aluno/Professor e justificar a estratégia escolhida.
- [ ] Mapear relacionamentos 1:N e 1:1.
- [ ] Criar tabelas associativas para relacionamentos N:M.
- [ ] Definir PK, FK, UNIQUE e nulabilidade.
- [ ] Documentar o mapeamento da entidade fraca Exemplar.

## Critérios de aceitação
- [ ] Todas as entidades e relacionamentos do DER estão representados.
- [ ] Chaves e referências estão consistentes.
- [ ] Modelo relacional revisado contra o DER.

## Dependências
Depende de: Construir o DER completo.
EOF
)"

create_issue \
  "Aplicar normalização até 3FN" \
  "M2 - Modelo Relacional e Normalizacao" \
  "type: database,priority: high,status: todo" \
  "$(cat <<'EOF'
## Objetivo
Verificar e documentar a normalização das relações até a Terceira Forma Normal.

## Atividades
- [ ] Identificar atributos atômicos e eliminar grupos repetitivos (1FN).
- [ ] Identificar dependências funcionais e eliminar dependências parciais (2FN).
- [ ] Eliminar dependências transitivas (3FN).
- [ ] Registrar decomposições realizadas e justificar preservação de informação.
- [ ] Revisar tabelas associativas e chaves compostas.

## Critérios de aceitação
- [ ] Justificativa de 1FN, 2FN e 3FN documentada.
- [ ] Dependências funcionais relevantes registradas.
- [ ] Modelo final consistente com o DER e sem redundâncias evitáveis.

## Dependências
Depende de: Converter DER em modelo relacional.
EOF
)"

create_issue \
  "Elaborar dicionário de dados" \
  "M2 - Modelo Relacional e Normalizacao" \
  "type: documentation,priority: medium,status: todo" \
  "$(cat <<'EOF'
## Objetivo
Documentar a estrutura de cada tabela e coluna do modelo relacional.

## Atividades
- [ ] Descrever finalidade de cada tabela.
- [ ] Registrar coluna, tipo de dado, tamanho e domínio.
- [ ] Identificar PK, FK, UNIQUE, CHECK e NOT NULL.
- [ ] Descrever relacionamentos e regras de exclusão/atualização.
- [ ] Registrar significado e exemplos dos atributos.

## Critérios de aceitação
- [ ] Todas as tabelas e colunas estão documentadas.
- [ ] Tipos e restrições correspondem ao modelo relacional.
- [ ] Documento salvo em docs/ e revisado.

## Dependências
Depende de: Converter DER em modelo relacional; Aplicar normalização até 3FN.
EOF
)"

create_issue \
  "Implementar DDL e restrições de integridade" \
  "M3 - Implementacao SQL" \
  "type: database,priority: critical,status: todo" \
  "$(cat <<'EOF'
## Objetivo
Criar o esquema físico no Oracle SQL a partir do modelo relacional aprovado.

## Atividades
- [ ] Implementar CREATE TABLE para todas as relações.
- [ ] Definir tipos Oracle adequados.
- [ ] Implementar PK, FK, UNIQUE, CHECK e NOT NULL.
- [ ] Nomear constraints de forma consistente.
- [ ] Definir estratégia de identidade e sequência quando aplicável.
- [ ] Definir ordem de criação e remoção das tabelas.
- [ ] Garantir que o script possa ser executado de forma reproduzível.

## Critérios de aceitação
- [ ] Script sql/01_ddl_esquema.sql executa sem erros.
- [ ] Todas as tabelas e constraints foram criadas.
- [ ] Restrições são coerentes com o dicionário de dados.
- [ ] Evidências de execução registradas.

## Dependências
Depende de: Converter DER em modelo relacional; Aplicar normalização até 3FN; Elaborar dicionário de dados.
EOF
)"

create_issue \
  "Implementar carga de dados de teste" \
  "M3 - Implementacao SQL" \
  "type: database,priority: high,status: todo" \
  "$(cat <<'EOF'
## Objetivo
Popular o banco com dados coerentes para validar relacionamentos, consultas e regras de negócio.

## Atividades
- [ ] Criar registros para departamentos, cursos, disciplinas e pré-requisitos.
- [ ] Criar professores, alunos, turmas e matrículas.
- [ ] Criar obras, autores, autorias e exemplares.
- [ ] Criar empréstimos, reservas e multas em cenários variados.
- [ ] Incluir dados-limite: turma lotada, multa pendente e limite de empréstimos.
- [ ] Garantir ordem de inserção compatível com as FKs.

## Critérios de aceitação
- [ ] Script sql/02_dml_carga_dados.sql executa sem violar integridade.
- [ ] Dados permitem demonstrar todas as consultas e triggers.
- [ ] Há cenários positivos e negativos de teste.

## Dependências
Depende de: Implementar DDL e restrições de integridade.
EOF
)"

create_issue \
  "Desenvolver consultas SQL analíticas" \
  "M4 - Recursos Avancados" \
  "type: database,priority: high,status: todo" \
  "$(cat <<'EOF'
## Objetivo
Implementar consultas que demonstrem recuperação e análise de dados acadêmicos e bibliotecários.

## Atividades
- [ ] Criar consultas com JOIN entre entidades relacionadas.
- [ ] Utilizar GROUP BY e HAVING em indicadores.
- [ ] Utilizar subconsultas e operadores de conjunto quando pertinentes.
- [ ] Produzir consultas de desempenho acadêmico e frequência.
- [ ] Produzir consultas de empréstimos, atrasos, reservas e multas.
- [ ] Documentar objetivo e resultado esperado de cada consulta.

## Critérios de aceitação
- [ ] Consultas executam no Oracle.
- [ ] Consultas cobrem os requisitos do trabalho.
- [ ] Resultados são demonstrados com dados de teste.

## Dependências
Depende de: Implementar DDL e restrições de integridade; Implementar carga de dados de teste.
EOF
)"

create_issue \
  "Implementar Views" \
  "M4 - Recursos Avancados" \
  "type: database,priority: medium,status: todo" \
  "$(cat <<'EOF'
## Objetivo
Criar visões reutilizáveis para relatórios acadêmicos e bibliotecários.

## Atividades
- [ ] Definir necessidade e finalidade de cada view.
- [ ] Criar views de situação acadêmica e matrículas.
- [ ] Criar views de acervo, empréstimos e pendências.
- [ ] Avaliar nomes, colunas expostas e legibilidade.
- [ ] Documentar consultas-base.

## Critérios de aceitação
- [ ] Views criadas sem erros.
- [ ] Resultados conferidos com os dados de teste.
- [ ] Script sql/03_views.sql versionado.

## Dependências
Depende de: Implementar DDL e restrições de integridade; Implementar carga de dados de teste.
EOF
)"

create_issue \
  "Implementar Triggers e auditoria" \
  "M4 - Recursos Avancados" \
  "type: database,priority: critical,status: todo" \
  "$(cat <<'EOF'
## Objetivo
Implementar regras automatizadas no banco e trilha de auditoria.

## Atividades
- [ ] Impedir matrícula em turma sem vagas e manter vagas disponíveis de forma consistente.
- [ ] Bloquear empréstimo quando houver multa pendente ou limite de empréstimos atingido.
- [ ] Auditar alterações de nota, registrando valor anterior, novo valor, data e usuário quando disponível.
- [ ] Avaliar concorrência, consistência e efeitos de triggers por linha/por comando.
- [ ] Tratar exceções com mensagens compreensíveis.
- [ ] Documentar decisões e limitações.

## Critérios de aceitação
- [ ] Cada trigger possui teste positivo e negativo.
- [ ] Não permite ultrapassar capacidade nem limite de empréstimos.
- [ ] Auditoria registra alterações corretamente.
- [ ] Script sql/04_triggers.sql executa sem erros.

## Dependências
Depende de: Implementar DDL e restrições de integridade; Implementar carga de dados de teste.
EOF
)"

create_issue \
  "Implementar controle transacional" \
  "M4 - Recursos Avancados" \
  "type: database,priority: critical,status: todo" \
  "$(cat <<'EOF'
## Objetivo
Demonstrar propriedades transacionais e tratamento de concorrência no Oracle.

## Atividades
- [ ] Preparar cenário com duas sessões disputando a última vaga.
- [ ] Utilizar SELECT ... FOR UPDATE para bloquear a linha relevante.
- [ ] Demonstrar comportamento da segunda sessão enquanto a primeira mantém o bloqueio.
- [ ] Demonstrar COMMIT e liberação do bloqueio.
- [ ] Criar SAVEPOINT e provocar violação de integridade.
- [ ] Demonstrar ROLLBACK TO SAVEPOINT e estado final dos dados.
- [ ] Documentar comandos e resultados das sessões.

## Critérios de aceitação
- [ ] Cenário concorrente reproduzível em duas sessões.
- [ ] Apenas uma matrícula ocupa a última vaga.
- [ ] SAVEPOINT e ROLLBACK demonstrados com evidências.
- [ ] Script sql/06_teste_transacional.sql documentado.

## Dependências
Depende de: Implementar DDL e restrições de integridade; Implementar carga de dados de teste; Implementar Triggers e auditoria.
EOF
)"

create_issue \
  "Executar testes de integridade e funcionalidades" \
  "M5 - Testes e Entrega" \
  "type: testing,priority: critical,status: todo" \
  "$(cat <<'EOF'
## Objetivo
Executar uma rodada integrada de testes e registrar evidências de conformidade.

## Atividades
- [ ] Testar PK, FK, UNIQUE, CHECK e NOT NULL.
- [ ] Testar regras acadêmicas e bibliotecárias.
- [ ] Testar views e consultas analíticas.
- [ ] Testar triggers em cenários válidos e inválidos.
- [ ] Reexecutar cenário concorrente e recuperação por SAVEPOINT.
- [ ] Registrar resultado esperado, resultado obtido e evidência.
- [ ] Corrigir defeitos encontrados e repetir os testes afetados.

## Critérios de aceitação
- [ ] Casos de teste documentados.
- [ ] Requisitos críticos aprovados ou com limitações explicitadas.
- [ ] Evidências organizadas em evidencias/.
- [ ] Nenhum erro impeditivo conhecido na entrega.

## Dependências
Depende de: Desenvolver consultas SQL analíticas; Implementar Views; Implementar Triggers e auditoria; Implementar controle transacional.
EOF
)"

create_issue \
  "Elaborar relatório técnico" \
  "M5 - Testes e Entrega" \
  "type: documentation,priority: high,status: todo" \
  "$(cat <<'EOF'
## Objetivo
Consolidar decisões de projeto, implementação e evidências em relatório técnico.

## Atividades
- [ ] Descrever minimundo e requisitos.
- [ ] Apresentar DER e modelo relacional.
- [ ] Explicar normalização e dicionário de dados.
- [ ] Descrever DDL, carga, consultas, views e triggers.
- [ ] Explicar transações e concorrência.
- [ ] Incluir evidências e resultados dos testes.
- [ ] Revisar formatação e aderência ao enunciado oficial.

## Critérios de aceitação
- [ ] Relatório cobre todos os itens exigidos.
- [ ] Figuras, tabelas e trechos SQL estão legíveis.
- [ ] Afirmações técnicas são sustentadas por evidências.
- [ ] Arquivo final salvo em docs/relatorio_tecnico.pdf.

## Dependências
Depende de: Executar testes de integridade e funcionalidades.
EOF
)"

create_issue \
  "Preparar apresentação e pacote final" \
  "M5 - Testes e Entrega" \
  "type: documentation,priority: critical,status: todo" \
  "$(cat <<'EOF'
## Objetivo
Preparar a apresentação do grupo e conferir o pacote final para submissão.

## Atividades
- [ ] Criar slides com problema, modelagem, implementação e demonstrações.
- [ ] Dividir a apresentação entre os quatro integrantes.
- [ ] Ensaiar demonstrações de consultas, triggers e transações.
- [ ] Conferir nomes, caminhos e versões dos arquivos.
- [ ] Conferir README com instruções de execução.
- [ ] Validar que não há arquivos temporários, credenciais ou dados sensíveis no repositório.
- [ ] Conferir o formato exigido para a entrega.

## Critérios de aceitação
- [ ] Slides finais em apresentacao/slides.pdf.
- [ ] Scripts SQL executáveis na ordem documentada.
- [ ] DER, modelo, relatório e evidências incluídos.
- [ ] Quatro integrantes revisaram o pacote.
- [ ] Entrega final pronta até 15/11/2026.

## Dependências
Depende de: Executar testes de integridade e funcionalidades; Elaborar relatório técnico.
EOF
)"

echo
echo "Configuração concluída."
echo "Confira os Milestones: gh milestone list --repo $REPO"
echo "Confira as Issues:     gh issue list --repo $REPO --state all"
echo "Confira as Labels:     gh label list --repo $REPO"
echo
echo "Observação: as dependências entre Issues estão documentadas nos corpos das tarefas."
echo "Distribua responsáveis entre os quatro integrantes usando:"
echo "  gh issue edit NUMERO --repo $REPO --add-assignee USUARIO_GITHUB"
