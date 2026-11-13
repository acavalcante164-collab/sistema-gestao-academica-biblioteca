-- ============================================================================
-- PROJETO: Sistema Integrado de Gestão Acadêmica e Biblioteca (SIGAB)
-- SCRIPT : 05_consultas_analiticas.sql
-- OBJETIVO: 8 Consultas Analíticas Avançadas (Issue #9 e Seção 3.5 do Edital)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- CONSULTA 01 (Q01): Taxa de Reprovação por Falta e por Nota nas Disciplinas
-- Requisito Técnico: Junções múltiplas + GROUP BY + HAVING (COUNT(*) >= 3).
-- Objetivo de Negócio: Responder à questão gerencial da Seção 1.2 do minimundo
--                      utilizando a fonte única da RN08 (VW_SITUACAO_ACADEMICA).
-- ----------------------------------------------------------------------------
SELECT
    dep.sigla AS departamento,
    vw.codigo_disciplina,
    vw.nome_disciplina,
    COUNT(*) AS total_matriculas,
    SUM(CASE WHEN vw.situacao_final_calculada = 'APROVADO' THEN 1 ELSE 0 END) AS qtd_aprovados,
    SUM(CASE WHEN vw.situacao_final_calculada = 'REPROVADO_FALTA' THEN 1 ELSE 0 END) AS qtd_reprov_falta,
    SUM(CASE WHEN vw.situacao_final_calculada = 'REPROVADO_NOTA' THEN 1 ELSE 0 END) AS qtd_reprov_nota,
    ROUND(
        SUM(CASE WHEN vw.situacao_final_calculada IN ('REPROVADO_FALTA', 'REPROVADO_NOTA') THEN 1 ELSE 0 END)
        * 100.0 / COUNT(*), 2
    ) AS percentual_reprovacao
FROM VW_SITUACAO_ACADEMICA vw
INNER JOIN DISCIPLINA d     ON d.id_disciplina = vw.id_disciplina
INNER JOIN DEPARTAMENTO dep ON dep.id_departamento = d.id_departamento
GROUP BY dep.sigla, vw.codigo_disciplina, vw.nome_disciplina
HAVING COUNT(*) >= 3
ORDER BY percentual_reprovacao DESC, qtd_reprov_falta DESC;

-- ----------------------------------------------------------------------------
-- CONSULTA 02 (Q02): Giro de Acervo Completo (Incluindo Autores e Obras sem Uso)
-- Requisito Técnico: Junções Múltiplas com INNER JOIN e LEFT OUTER JOIN
--                    envolvendo OBRA, AUTORIA, AUTOR, EXEMPLAR, EMPRESTIMO e RESERVA.
-- Objetivo de Negócio: Mapear a demanda de todas as obras do catálogo com seus
--                      respectivos autores, inclusive títulos recém-adquiridos.
-- ----------------------------------------------------------------------------
WITH CTE_AUTORES_OBRA AS (
    SELECT
        au_rel.id_obra,
        LISTAGG(a.nome, '; ') WITHIN GROUP (ORDER BY a.nome) AS autores
    FROM AUTORIA au_rel
    INNER JOIN AUTOR a ON a.id_autor = au_rel.id_autor
    GROUP BY au_rel.id_obra
),
CTE_RESERVAS_OBRA AS (
    SELECT
        id_obra,
        COUNT(*) AS total_reservas_ativas
    FROM RESERVA
    WHERE situacao = 'ATIVA'
    GROUP BY id_obra
)
SELECT
    o.id_obra,
    o.titulo,
    o.tipo,
    NVL(aut.autores, 'Sem autor vinculado') AS autores,
    COUNT(DISTINCT ex.numero_exemplar) AS qtd_exemplares_fisicos,
    COUNT(DISTINCT e.id_emprestimo) AS total_emprestimos_historico,
    NVL(res.total_reservas_ativas, 0) AS reservas_ativas_fila
FROM OBRA o
LEFT OUTER JOIN CTE_AUTORES_OBRA aut  ON aut.id_obra = o.id_obra
LEFT OUTER JOIN EXEMPLAR ex           ON ex.id_obra = o.id_obra
LEFT OUTER JOIN EMPRESTIMO e          ON e.id_obra = ex.id_obra
                                     AND e.numero_exemplar = ex.numero_exemplar
LEFT OUTER JOIN CTE_RESERVAS_OBRA res ON res.id_obra = o.id_obra
GROUP BY o.id_obra, o.titulo, o.tipo, aut.autores, res.total_reservas_ativas
ORDER BY total_emprestimos_historico DESC, reservas_ativas_fila DESC;

-- ----------------------------------------------------------------------------
-- CONSULTA 03 (Q03): Alunos de Cursos de Alta Carga Horária (>= 3000h) com
--                    Desempenho Superior a Todas as Médias de Turmas de um Depto
-- Requisito Técnico: Subconsulta independente com operadores de conjunto IN e ALL.
-- Objetivo de Negócio: Identificar alunos de destaque elegíveis a bolsas de
--                      monitoria/iniciação científica em cursos com CH >= 3000h.
-- ----------------------------------------------------------------------------
SELECT
    p.nome AS nome_aluno,
    a.matricula,
    c.nome AS nome_curso,
    c.carga_horaria AS ch_curso,
    ROUND(AVG(m.nota_final), 2) AS media_global_aluno
FROM ALUNO a
INNER JOIN PESSOA p    ON p.id_pessoa = a.id_pessoa
INNER JOIN CURSO c     ON c.id_curso = a.id_curso
INNER JOIN MATRICULA m ON m.id_aluno = a.id_pessoa
WHERE m.nota_final IS NOT NULL
  AND a.id_curso IN (
      SELECT sub_c.id_curso
        FROM CURSO sub_c
       WHERE sub_c.carga_horaria >= 3000
  )
GROUP BY p.nome, a.matricula, c.nome, c.carga_horaria
HAVING AVG(m.nota_final) >= ALL (
    SELECT AVG(m2.nota_final)
      FROM MATRICULA m2
      INNER JOIN TURMA t2      ON t2.id_turma = m2.id_turma
      INNER JOIN DISCIPLINA d2 ON d2.id_disciplina = t2.id_disciplina
     WHERE m2.nota_final IS NOT NULL
     GROUP BY d2.id_departamento
)
ORDER BY media_global_aluno DESC;

-- ----------------------------------------------------------------------------
-- CONSULTA 04 (Q04): Alunos com Matrícula Ativa no Semestre e Bloqueados na
--                    Biblioteca por Multa Pendente
-- Requisito Técnico: Subconsulta Correlacionada utilizando EXISTS.
-- Objetivo de Negócio: Demonstrar a integração entre Secretaria Acadêmica e
--                      Biblioteca através da entidade PESSOA (Seção 1.1).
-- ----------------------------------------------------------------------------
SELECT
    a.id_pessoa,
    a.matricula AS matricula_academica,
    p.nome AS nome_aluno,
    p.email,
    c.nome AS curso
FROM ALUNO a
INNER JOIN PESSOA p ON p.id_pessoa = a.id_pessoa
INNER JOIN CURSO c  ON c.id_curso = a.id_curso
WHERE EXISTS (
    SELECT 1
      FROM MATRICULA m
     WHERE m.id_aluno = a.id_pessoa
       AND m.status_matricula = 'ATIVA'
)
AND EXISTS (
    SELECT 1
      FROM EMPRESTIMO e
      INNER JOIN MULTA mu ON mu.id_emprestimo = e.id_emprestimo
     WHERE e.id_pessoa = a.id_pessoa
       AND mu.data_pagamento IS NULL
)
ORDER BY p.nome;

-- ----------------------------------------------------------------------------
-- CONSULTA 05 (Q05): Alunos Aptos a Cursar Disciplinas com Pré-requisitos
--                    (Todos os Pré-requisitos Cumpridos, mas Disciplina Não Cursada)
-- Requisito Técnico: Subconsulta Correlacionada com Duplo NOT EXISTS (Divisão
--                    Relacional) consultando VW_SITUACAO_ACADEMICA (RN08).
-- Objetivo de Negócio: Planejamento de oferta de vagas para o próximo semestre.
-- ----------------------------------------------------------------------------
SELECT
    a.matricula AS matricula_aluno,
    p.nome AS nome_aluno,
    d.codigo AS cod_disciplina_liberada,
    d.nome AS disciplina_liberada
FROM ALUNO a
INNER JOIN PESSOA p     ON p.id_pessoa = a.id_pessoa
INNER JOIN CURSO c      ON c.id_curso = a.id_curso
INNER JOIN DISCIPLINA d ON d.id_departamento = c.id_departamento
WHERE EXISTS (
    -- Garante que a disciplina avaliada possui pelo menos 1 pré-requisito
    SELECT 1
      FROM PRE_REQUISITO pr_check
     WHERE pr_check.id_disciplina = d.id_disciplina
)
AND NOT EXISTS (
    -- Não existe nenhum pré-requisito desta disciplina que o aluno NÃO tenha sido APROVADO
    SELECT 1
      FROM PRE_REQUISITO pr
     WHERE pr.id_disciplina = d.id_disciplina
       AND NOT EXISTS (
           SELECT 1
             FROM VW_SITUACAO_ACADEMICA vw
            WHERE vw.id_aluno = a.id_pessoa
              AND vw.id_disciplina = pr.id_disciplina_req
              AND vw.situacao_final_calculada = 'APROVADO'
       )
)
AND NOT EXISTS (
    -- E o aluno ainda não está cursando nem foi aprovado na disciplina-alvo
    SELECT 1
      FROM VW_SITUACAO_ACADEMICA vw_alvo
     WHERE vw_alvo.id_aluno = a.id_pessoa
       AND vw_alvo.id_disciplina = d.id_disciplina
       AND vw_alvo.situacao_final_calculada IN ('APROVADO', 'CURSANDO')
)
ORDER BY d.codigo, p.nome;

-- ----------------------------------------------------------------------------
-- CONSULTA 06 (Q06): Ranking de Desempenho dos Alunos por Curso e Diferença
--                    para o Colocado Anterior
-- Requisito Técnico: Window Functions com cláusula OVER() (DENSE_RANK, LAG, AVG).
-- Objetivo de Negócio: Classificar os alunos dentro de cada curso pela média
--                      geral e comparar com a média do próprio curso.
-- ----------------------------------------------------------------------------
WITH CTE_MEDIA_ALUNO AS (
    SELECT
        a.id_pessoa,
        a.matricula,
        p.nome AS nome_aluno,
        c.id_curso,
        c.nome AS nome_curso,
        ROUND(AVG(m.nota_final), 2) AS media_aluno
    FROM ALUNO a
    INNER JOIN PESSOA p    ON p.id_pessoa = a.id_pessoa
    INNER JOIN CURSO c     ON c.id_curso = a.id_curso
    INNER JOIN MATRICULA m ON m.id_aluno = a.id_pessoa
    WHERE m.nota_final IS NOT NULL
    GROUP BY a.id_pessoa, a.matricula, p.nome, c.id_curso, c.nome
)
SELECT
    nome_curso,
    matricula,
    nome_aluno,
    media_aluno,
    DENSE_RANK() OVER (
        PARTITION BY id_curso
        ORDER BY media_aluno DESC
    ) AS posicao_ranking_curso,
    ROUND(AVG(media_aluno) OVER (PARTITION BY id_curso), 2) AS media_geral_do_curso,
    NVL(
        media_aluno - LAG(media_aluno, 1) OVER (
            PARTITION BY id_curso
            ORDER BY media_aluno DESC
        ), 0
    ) AS diferenca_para_colocado_acima
FROM CTE_MEDIA_ALUNO
ORDER BY nome_curso, posicao_ranking_curso, nome_aluno;

-- ----------------------------------------------------------------------------
-- CONSULTA 07 (Q07): Indicadores de Atraso, Média de Retenção e Multas por
--                    Perfil de Usuário (Aluno vs. Professor)
-- Requisito Técnico: Agregação Analítica com GROUP BY, CASE e funções estatísticas.
-- Objetivo de Negócio: Avaliar o cumprimento dos prazos da RN12 (7/15 dias), a
--                      média de dias de atraso e o volume financeiro de multas (RN13).
-- ----------------------------------------------------------------------------
SELECT
    CASE p.tipo_pessoa
        WHEN 'A' THEN 'ALUNO (Prazo: 7 dias | Limite: 3)'
        WHEN 'P' THEN 'PROFESSOR (Prazo: 15 dias | Limite: 5)'
    END AS categoria_usuario,
    COUNT(DISTINCT p.id_pessoa) AS qtd_usuarios_ativos,
    COUNT(e.id_emprestimo) AS total_emprestimos,
    ROUND(AVG(
        CASE
            WHEN e.data_devolucao IS NOT NULL AND TRUNC(e.data_devolucao) > TRUNC(e.data_prevista_devolucao)
                THEN TRUNC(e.data_devolucao) - TRUNC(e.data_prevista_devolucao)
            WHEN e.data_devolucao IS NULL AND TRUNC(SYSDATE) > TRUNC(e.data_prevista_devolucao)
                THEN TRUNC(SYSDATE) - TRUNC(e.data_prevista_devolucao)
            ELSE 0
        END
    ), 2) AS media_dias_atraso,
    COUNT(mu.id_multa) AS qtd_multas_geradas,
    NVL(SUM(mu.valor), 0) AS montante_total_multas_rs,
    NVL(SUM(CASE WHEN mu.data_pagamento IS NULL THEN mu.valor ELSE 0 END), 0) AS montante_pendente_rs
FROM PESSOA p
INNER JOIN EMPRESTIMO e ON e.id_pessoa = p.id_pessoa
LEFT OUTER JOIN MULTA mu ON mu.id_emprestimo = e.id_emprestimo
GROUP BY p.tipo_pessoa
ORDER BY total_emprestimos DESC;

-- ----------------------------------------------------------------------------
-- CONSULTA 08 (Q08): Fila Prioritária de Reservas Ativas por Obra com Posição
--                    Cronológica (Apenas Obras sem Exemplares Disponíveis - RN15)
-- Requisito Técnico: Window Function (ROW_NUMBER() OVER) + Subconsulta
--                    Correlacionada com NOT EXISTS.
-- Objetivo de Negócio: Orientar o bibliotecário sobre qual usuário deve ser
--                      atendido primeiro para obras 100% emprestadas (RN15).
-- ----------------------------------------------------------------------------
SELECT
    r.id_obra,
    o.titulo AS titulo_obra,
    ROW_NUMBER() OVER (
        PARTITION BY r.id_obra
        ORDER BY r.data_reserva ASC, r.id_reserva ASC
    ) AS posicao_na_fila,
    p.id_pessoa,
    p.nome AS nome_solicitante,
    p.email,
    TO_CHAR(r.data_reserva, 'DD/MM/YYYY HH24:MI:SS') AS data_hora_reserva,
    r.situacao
FROM RESERVA r
INNER JOIN OBRA o   ON o.id_obra = r.id_obra
INNER JOIN PESSOA p ON p.id_pessoa = r.id_pessoa
WHERE r.situacao = 'ATIVA'
  -- Validação correlacionada da RN15: garante que NÃO EXISTE exemplar disponível para a obra
  AND NOT EXISTS (
      SELECT 1
        FROM EXEMPLAR ex
       WHERE ex.id_obra = r.id_obra
         AND NOT EXISTS (
             SELECT 1
               FROM EMPRESTIMO emp
              WHERE emp.id_obra = ex.id_obra
                AND emp.numero_exemplar = ex.numero_exemplar
                AND emp.data_devolucao IS NULL
         )
  )
ORDER BY r.id_obra, posicao_na_fila;