-- ============================================================================
-- UNIVERSIDADE FEDERAL DE RORAIMA (UFRR) - DCC 502: BANCO DE DADOS I
-- PROJETO: Sistema Integrado de Gestão Acadêmica e Biblioteca (SIGAB) - Grupo 06
-- SCRIPT: 05_consultas_analiticas.sql (Referência: Issue #9 e Seção 3.5 do Edital)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- CONSULTA 01 (Requisito 3.5.1 - INNER JOIN múltiplo + GROUP BY + HAVING)
-- Objetivo de Negócio:
--   Identificar o índice de reprovação por falta e a média geral de notas por
--   disciplina e semestre, filtrando disciplinas que possuem matrículas avaliadas.
-- ----------------------------------------------------------------------------
SELECT
    dep.sigla                                                       AS departamento,
    d.codigo                                                        AS cod_disciplina,
    d.nome                                                          AS disciplina,
    t.semestre,
    COUNT(m.id_aluno)                                               AS total_matriculados,
    ROUND(AVG(m.nota_final), 2)                                     AS media_notas,
    ROUND(AVG(m.frequencia), 2)                                     AS media_frequencia,
    SUM(CASE WHEN m.frequencia < 75.0 THEN 1 ELSE 0 END)            AS qtd_reprovados_falta,
    SUM(CASE WHEN m.frequencia >= 75.0 AND m.nota_final >= 6.0 THEN 1 ELSE 0 END) AS qtd_aprovados
FROM DEPARTAMENTO dep
INNER JOIN DISCIPLINA d ON dep.id_departamento = d.id_departamento
INNER JOIN TURMA t      ON d.id_disciplina = t.id_disciplina
INNER JOIN MATRICULA m  ON t.id_turma = m.id_turma
WHERE m.status_matricula = 'ATIVA'
  AND m.nota_final IS NOT NULL
GROUP BY dep.sigla, d.codigo, d.nome, t.semestre
HAVING COUNT(m.id_aluno) >= 1
ORDER BY qtd_reprovados_falta DESC, media_notas ASC;

-- ----------------------------------------------------------------------------
-- CONSULTA 02 (Requisito 3.5.1 - LEFT OUTER JOIN múltiplo)
-- Objetivo de Negócio:
--   Mapear o giro de todo o acervo bibliográfico (obras, quantidade de exemplares
--   físicos cadastrados e total de empréstimos históricos), exibindo inclusive
--   obras recém-catalogadas que ainda não tiveram exemplares ou empréstimos.
-- ----------------------------------------------------------------------------
SELECT
    o.id_obra,
    o.titulo,
    o.tipo                                          AS tipo_material,
    o.editora,
    COUNT(DISTINCT ex.numero_exemplar)              AS qtd_exemplares_fisicos,
    COUNT(emp.id_emprestimo)                        AS total_emprestimos_realizados,
    SUM(CASE WHEN emp.id_emprestimo IS NOT NULL AND emp.data_devolucao IS NULL THEN 1 ELSE 0 END) AS exemplares_atualmente_emprestados
FROM OBRA o
LEFT OUTER JOIN EXEMPLAR ex    ON o.id_obra = ex.id_obra
LEFT OUTER JOIN EMPRESTIMO emp ON ex.id_obra = emp.id_obra
                              AND ex.numero_exemplar = emp.numero_exemplar
GROUP BY o.id_obra, o.titulo, o.tipo, o.editora
ORDER BY total_emprestimos_realizados DESC, o.titulo ASC;

-- ----------------------------------------------------------------------------
-- CONSULTA 03 (Requisito 3.5.2 - Subconsulta Independente com Operador ALL e IN)
-- Objetivo de Negócio:
--   Listar os alunos de destaque cujo Coeficiente de Rendimento (média das notas)
--   é maior ou igual à média geral de TODOS os cursos de graduação com carga
--   horária mínima de 3000 horas.
-- ----------------------------------------------------------------------------
SELECT
    a.matricula                 AS matricula_academica,
    p.nome                      AS nome_aluno,
    c.nome                      AS curso,
    COUNT(m.id_turma)           AS disciplinas_avaliadas,
    ROUND(AVG(m.nota_final), 2) AS media_geral_aluno
FROM ALUNO a
INNER JOIN PESSOA p    ON a.id_pessoa = p.id_pessoa
INNER JOIN CURSO c     ON a.id_curso = c.id_curso
INNER JOIN MATRICULA m ON a.id_pessoa = m.id_aluno
WHERE m.nota_final IS NOT NULL
  AND c.id_curso IN (
      SELECT c_sub.id_curso
        FROM CURSO c_sub
       WHERE c_sub.carga_horaria >= 2400
  )
GROUP BY a.matricula, p.nome, c.nome
HAVING AVG(m.nota_final) >= ALL (
    SELECT AVG(m2.nota_final)
      FROM MATRICULA m2
      INNER JOIN ALUNO a2 ON m2.id_aluno = a2.id_pessoa
     WHERE m2.nota_final IS NOT NULL
     GROUP BY a2.id_curso
)
ORDER BY media_geral_aluno DESC;

-- ----------------------------------------------------------------------------
-- CONSULTA 04 (Requisito 3.5.3 - Subconsulta Correlacionada com EXISTS)
-- Objetivo de Negócio:
--   Identificar todos os usuários (alunos e professores) que estão impedidos de
--   novos empréstimos por possuírem ao menos uma multa pendente de pagamento (RN14).
-- ----------------------------------------------------------------------------
SELECT
    p.id_pessoa,
    p.cpf,
    p.nome,
    DECODE(p.tipo_pessoa, 'A', 'ALUNO', 'P', 'PROFESSOR') AS categoria,
    p.email
FROM PESSOA p
WHERE EXISTS (
    SELECT 1
      FROM EMPRESTIMO e
      INNER JOIN MULTA mu ON e.id_emprestimo = mu.id_emprestimo
     WHERE e.id_pessoa = p.id_pessoa
       AND mu.data_pagamento IS NULL
)
ORDER BY p.nome;

-- ----------------------------------------------------------------------------
-- CONSULTA 05 (Requisito 3.5.3 - Subconsulta Correlacionada com NOT EXISTS)
-- Objetivo de Negócio:
--   Relacionar quais alunos já cumpriram TODOS os pré-requisitos de uma disciplina
--   que exige pré-requisito (Divisão Relacional via dupla negação com NOT EXISTS),
--   mas ainda não se matricularam nela com aprovação.
-- ----------------------------------------------------------------------------
SELECT
    a.matricula         AS matricula_aluno,
    p.nome              AS nome_aluno,
    d_alvo.codigo       AS cod_disciplina_liberada,
    d_alvo.nome         AS disciplina_liberada
FROM ALUNO a
INNER JOIN PESSOA p      ON a.id_pessoa = p.id_pessoa
CROSS JOIN DISCIPLINA d_alvo
WHERE EXISTS (
    -- A disciplina alvo deve possuir pelo menos um pré-requisito cadastrado
    SELECT 1
      FROM PRE_REQUISITO pr_check
     WHERE pr_check.id_disciplina = d_alvo.id_disciplina
)
AND NOT EXISTS (
    -- Não pode existir nenhum pré-requisito da disciplina alvo que o aluno NÃO tenha aprovado
    SELECT 1
      FROM PRE_REQUISITO pr
     WHERE pr.id_disciplina = d_alvo.id_disciplina
       AND NOT EXISTS (
           SELECT 1
             FROM MATRICULA m
             INNER JOIN TURMA t ON m.id_turma = t.id_turma
            WHERE m.id_aluno = a.id_pessoa
              AND t.id_disciplina = pr.id_disciplina_req
              AND m.status_matricula = 'ATIVA'
              AND m.nota_final >= 6.0
              AND m.frequencia >= 75.0
       )
)
AND NOT EXISTS (
    -- E o aluno ainda não foi aprovado na própria disciplina alvo
    SELECT 1
      FROM MATRICULA m_ja
      INNER JOIN TURMA t_ja ON m_ja.id_turma = t_ja.id_turma
     WHERE m_ja.id_aluno = a.id_pessoa
       AND t_ja.id_disciplina = d_alvo.id_disciplina
       AND m_ja.status_matricula = 'ATIVA'
       AND m_ja.nota_final >= 6.0
       AND m_ja.frequencia >= 75.0
)
ORDER BY p.nome, d_alvo.codigo;

-- ----------------------------------------------------------------------------
-- CONSULTA 06 (Requisito 3.5.5 - Window Functions com OVER: DENSE_RANK e LAG)
-- Objetivo de Negócio:
--   Classificar os alunos dentro de cada curso pelo seu Coeficiente de Rendimento
--   (média das notas finais), exibindo a posição no ranking (DENSE_RANK) e a
--   diferença de nota para o aluno imediatamente acima (LAG).
-- ----------------------------------------------------------------------------
WITH resumo_rendimento AS (
    SELECT
        c.id_curso,
        c.nome                      AS nome_curso,
        a.id_pessoa                 AS id_aluno,
        a.matricula                 AS matricula_academica,
        p.nome                      AS nome_aluno,
        COUNT(m.id_turma)           AS qtd_turmas_avaliadas,
        ROUND(AVG(m.nota_final), 2) AS cr_medio
    FROM ALUNO a
    INNER JOIN PESSOA p    ON a.id_pessoa = p.id_pessoa
    INNER JOIN CURSO c     ON a.id_curso = c.id_curso
    INNER JOIN MATRICULA m ON a.id_pessoa = m.id_aluno
    WHERE m.nota_final IS NOT NULL
    GROUP BY c.id_curso, c.nome, a.id_pessoa, a.matricula, p.nome
)
SELECT
    nome_curso,
    DENSE_RANK() OVER (PARTITION BY id_curso ORDER BY cr_medio DESC) AS ranking_no_curso,
    matricula_academica,
    nome_aluno,
    qtd_turmas_avaliadas,
    cr_medio,
    LAG(cr_medio, 1) OVER (PARTITION BY id_curso ORDER BY cr_medio DESC) AS cr_colocado_anterior,
    ROUND(
        cr_medio - LAG(cr_medio, 1) OVER (PARTITION BY id_curso ORDER BY cr_medio DESC),
        2
    ) AS diferenca_para_anterior
FROM resumo_rendimento
ORDER BY nome_curso, ranking_no_curso, nome_aluno;

-- ----------------------------------------------------------------------------
-- CONSULTA 07 (Análise Financeira e de Inadimplência da Biblioteca por Perfil)
-- Objetivo de Negócio:
--   Comparar o comportamento de empréstimos, atrasos e multas entre Alunos e
--   Professores, apurando o montante total gerado, valor já pago e saldo devedor.
-- ----------------------------------------------------------------------------
SELECT
    DECODE(p.tipo_pessoa, 'A', 'ALUNO', 'P', 'PROFESSOR')               AS perfil_usuario,
    COUNT(DISTINCT p.id_pessoa)                                         AS qtd_usuarios_ativos,
    COUNT(e.id_emprestimo)                                              AS total_emprestimos,
    SUM(CASE WHEN mu.id_multa IS NOT NULL THEN 1 ELSE 0 END)            AS qtd_emprestimos_com_multa,
    NVL(SUM(mu.valor), 0)                                               AS valor_total_multas,
    NVL(SUM(CASE WHEN mu.data_pagamento IS NOT NULL THEN mu.valor ELSE 0 END), 0) AS valor_multas_pagas,
    NVL(SUM(CASE WHEN mu.data_pagamento IS NULL THEN mu.valor ELSE 0 END), 0)     AS valor_multas_pendentes
FROM PESSOA p
INNER JOIN EMPRESTIMO e ON p.id_pessoa = e.id_pessoa
LEFT OUTER JOIN MULTA mu ON e.id_emprestimo = mu.id_emprestimo
GROUP BY p.tipo_pessoa
ORDER BY valor_multas_pendentes DESC;

-- ----------------------------------------------------------------------------
-- CONSULTA 08 (Gestão de Demanda Reprimida - Fila de Reservas vs Exemplares)
-- Objetivo de Negócio:
--   Listar as obras que possuem reservas ativas na fila de espera e verificar
--   quantos exemplares físicos cada obra possui no catálogo (apoio à aquisição).
-- ----------------------------------------------------------------------------
SELECT
    o.id_obra,
    o.titulo,
    o.tipo,
    COUNT(DISTINCT r.id_reserva)        AS qtd_reservas_ativas,
    MIN(r.data_reserva)                 AS reserva_mais_antiga,
    (
        SELECT COUNT(*)
          FROM EXEMPLAR ex
         WHERE ex.id_obra = o.id_obra
    )                                   AS total_exemplares_catalogo
FROM OBRA o
INNER JOIN RESERVA r ON o.id_obra = r.id_obra
WHERE r.situacao = 'ATIVA'
GROUP BY o.id_obra, o.titulo, o.tipo
HAVING COUNT(DISTINCT r.id_reserva) >= 1
ORDER BY qtd_reservas_ativas DESC, reserva_mais_antiga ASC;