-- ============================================================================
-- PROJETO: Sistema Integrado de Gestão Acadêmica e Biblioteca (SIGAB)
-- SCRIPT : 03_views.sql
-- OBJETIVO: Criação das Visões Relacionais (Issue #10 e Seção 3.5.4 do Edital)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. VISÃO ANALÍTICA E DE SEGURANÇA: VW_SITUACAO_ACADEMICA
-- Finalidade:
--   a) Fonte única da verdade para a Regra de Negócio RN08 (cálculo dinâmico
--      de 'APROVADO', 'REPROVADO_NOTA', 'REPROVADO_FALTA', 'TRANCADO',
--      'CURSANDO'), preservando a 3FN/FNBC na tabela física MATRICULA.
--   b) Segurança: Oculta dados sensíveis de PESSOA (CPF, endereço e data de
--      nascimento).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW VW_SITUACAO_ACADEMICA AS
SELECT
    m.id_aluno,
    a.matricula AS matricula_academica,
    p.nome AS nome_aluno,
    c.id_curso,
    c.nome AS nome_curso,
    t.id_turma,
    t.semestre,
    d.id_disciplina,
    d.codigo AS codigo_disciplina,
    d.nome AS nome_disciplina,
    d.carga_horaria,
    m.data_matricula,
    m.nota_final,
    m.frequencia,
    m.status_matricula,
    CASE
        WHEN m.status_matricula = 'TRANCADA' THEN 'TRANCADO'
        WHEN m.nota_final IS NULL OR m.frequencia IS NULL THEN 'CURSANDO'
        WHEN m.frequencia < 75 THEN 'REPROVADO_FALTA'
        WHEN m.nota_final >= 6.0 THEN 'APROVADO'
        ELSE 'REPROVADO_NOTA'
    END AS situacao_final_calculada
FROM MATRICULA m
INNER JOIN ALUNO a      ON a.id_pessoa = m.id_aluno
INNER JOIN PESSOA p     ON p.id_pessoa = a.id_pessoa
INNER JOIN CURSO c      ON c.id_curso = a.id_curso
INNER JOIN TURMA t      ON t.id_turma = m.id_turma
INNER JOIN DISCIPLINA d ON d.id_disciplina = t.id_disciplina
WITH READ ONLY;

-- ----------------------------------------------------------------------------
-- 2. VISÃO COM PROTEÇÃO DE ESCRITA: VW_MATRICULAS_ATIVAS
-- Finalidade:
--   Expor matrículas com vínculo ativo ('ATIVA') e bloquear via cláusula
--   WITH CHECK OPTION qualquer INSERT ou UPDATE através da view que tente
--   definir status_matricula diferente de 'ATIVA'.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW VW_MATRICULAS_ATIVAS AS
SELECT
    id_aluno,
    id_turma,
    data_matricula,
    nota_final,
    frequencia,
    status_matricula
FROM MATRICULA
WHERE status_matricula = 'ATIVA'
WITH CHECK OPTION CONSTRAINT CK_VW_MATRICULA_ATIVA;

-- ----------------------------------------------------------------------------
-- 3. VISÃO GERENCIAL DA BIBLIOTECA: VW_ACERVO_PENDENCIAS
-- Finalidade:
--   Consolidar empréstimos em aberto ou devolvidos com multa não quitada,
--   calculando dias de atraso correntes e status de bloqueio (RN13 e RN14).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW VW_ACERVO_PENDENCIAS AS
SELECT
    e.id_emprestimo,
    p.id_pessoa,
    p.nome AS nome_usuario,
    CASE p.tipo_pessoa
        WHEN 'A' THEN 'ALUNO'
        WHEN 'P' THEN 'PROFESSOR'
    END AS perfil_usuario,
    o.id_obra,
    o.titulo AS titulo_obra,
    e.numero_exemplar,
    e.data_emprestimo,
    e.data_prevista_devolucao,
    e.data_devolucao,
    CASE
        WHEN e.data_devolucao IS NULL AND TRUNC(SYSDATE) > TRUNC(e.data_prevista_devolucao)
            THEN TRUNC(SYSDATE) - TRUNC(e.data_prevista_devolucao)
        WHEN e.data_devolucao IS NOT NULL AND TRUNC(e.data_devolucao) > TRUNC(e.data_prevista_devolucao)
            THEN TRUNC(e.data_devolucao) - TRUNC(e.data_prevista_devolucao)
        ELSE 0
    END AS dias_atraso,
    mu.id_multa,
    NVL(mu.valor, 0) AS valor_multa_registrada,
    CASE
        WHEN mu.id_multa IS NOT NULL AND mu.data_pagamento IS NULL THEN 'BLOQUEADO_MULTA_PENDENTE'
        WHEN e.data_devolucao IS NULL AND TRUNC(SYSDATE) > TRUNC(e.data_prevista_devolucao) THEN 'EM_ATRASO_SEM_DEVOLUCAO'
        ELSE 'REGULAR_EM_ABERTO'
    END AS situacao_bibliotecaria
FROM EMPRESTIMO e
INNER JOIN PESSOA p ON p.id_pessoa = e.id_pessoa
INNER JOIN OBRA o   ON o.id_obra = e.id_obra
LEFT JOIN MULTA mu  ON mu.id_emprestimo = e.id_emprestimo
WHERE e.data_devolucao IS NULL
   OR (mu.id_multa IS NOT NULL AND mu.data_pagamento IS NULL)
WITH READ ONLY;