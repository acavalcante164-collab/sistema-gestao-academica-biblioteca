-- ============================================================================
-- UNIVERSIDADE FEDERAL DE RORAIMA (UFRR) - DCC 502: BANCO DE DADOS I
-- PROJETO: Sistema Integrado de Gestão Acadêmica e Biblioteca (SIGAB) - Grupo 06
-- SCRIPT: 03_views.sql (Referência: Issue #10 e Seção 3.5.4 do Edital)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- VIEW 1: VW_SITUACAO_ACADEMICA (Visão Analítica e de Segurança - WITH READ ONLY)
-- Finalidade:
--   1. Derivar dinamicamente a situação final da matrícula conforme a RN08
--      (Nota >= 6.0 e Frequência >= 75%), mantendo a tabela MATRICULA na 3FN/FNBC.
--   2. Proteger dados pessoais sensíveis de PESSOA (omite CPF, endereço e CEP).
--   3. Impedir operações DML diretas através da cláusula WITH READ ONLY.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW VW_SITUACAO_ACADEMICA AS
SELECT
    a.id_pessoa              AS id_aluno,
    a.matricula              AS matricula_academica,
    p.nome                   AS nome_aluno,
    c.nome                   AS nome_curso,
    d.sigla                  AS sigla_departamento,
    disc.codigo              AS codigo_disciplina,
    disc.nome                AS nome_disciplina,
    t.id_turma,
    t.semestre,
    p_prof.nome              AS nome_professor,
    m.data_matricula,
    m.nota_final,
    m.frequencia,
    m.status_matricula,
    CASE
        WHEN m.status_matricula = 'TRANCADA' THEN 'TRANCADO'
        WHEN m.nota_final IS NULL OR m.frequencia IS NULL THEN 'CURSANDO'
        WHEN m.frequencia < 75.0 THEN 'REPROVADO_FALTA'
        WHEN m.nota_final >= 6.0 THEN 'APROVADO'
        ELSE 'REPROVADO_NOTA'
    END                      AS situacao_final_calculada
FROM MATRICULA m
JOIN ALUNO a            ON m.id_aluno = a.id_pessoa
JOIN PESSOA p           ON a.id_pessoa = p.id_pessoa
JOIN CURSO c            ON a.id_curso = c.id_curso
JOIN TURMA t            ON m.id_turma = t.id_turma
JOIN DISCIPLINA disc    ON t.id_disciplina = disc.id_disciplina
JOIN DEPARTAMENTO d     ON disc.id_departamento = d.id_departamento
LEFT JOIN PROFESSOR pr  ON t.id_professor = pr.id_pessoa
LEFT JOIN PESSOA p_prof ON pr.id_pessoa = p_prof.id_pessoa
WITH READ ONLY;

-- ----------------------------------------------------------------------------
-- VIEW 2: VW_ACERVO_PENDENCIAS (Visão Gerencial da Biblioteca - WITH READ ONLY)
-- Finalidade:
--   Listar todos os empréstimos em atraso ou com multa pendente, exibindo os
--   dias de atraso calculados e o status de bloqueio do usuário (RN13 e RN14).
-- ----------------------------------------------------------------------------
CREATE OR REPLACE VIEW VW_ACERVO_PENDENCIAS AS
SELECT
    e.id_emprestimo,
    p.id_pessoa,
    p.nome                                                              AS nome_usuario,
    DECODE(p.tipo_pessoa, 'A', 'ALUNO', 'P', 'PROFESSOR')               AS perfil_usuario,
    p.email,
    o.id_obra,
    o.titulo                                                            AS titulo_obra,
    e.numero_exemplar,
    e.data_emprestimo,
    e.data_prevista_devolucao,
    e.data_devolucao,
    GREATEST(0, TRUNC(NVL(e.data_devolucao, SYSDATE)) - TRUNC(e.data_prevista_devolucao)) AS dias_atraso,
    mu.id_multa,
    NVL(mu.valor, 0)                                                    AS valor_multa_registrada,
    mu.data_pagamento,
    CASE
        WHEN mu.id_multa IS NOT NULL AND mu.data_pagamento IS NULL THEN 'BLOQUEADO_MULTA_PENDENTE'
        WHEN e.data_devolucao IS NULL AND TRUNC(SYSDATE) > TRUNC(e.data_prevista_devolucao) THEN 'EM_ATRASO_SEM_DEVOLUCAO'
        ELSE 'REGULAR'
    END                                                                 AS situacao_biblioteca
FROM EMPRESTIMO e
JOIN PESSOA p   ON e.id_pessoa = p.id_pessoa
JOIN OBRA o     ON e.id_obra = o.id_obra
LEFT JOIN MULTA mu ON e.id_emprestimo = mu.id_emprestimo
WHERE (mu.id_multa IS NOT NULL AND mu.data_pagamento IS NULL)
   OR (e.data_devolucao IS NULL AND TRUNC(SYSDATE) > TRUNC(e.data_prevista_devolucao))
WITH READ ONLY;

-- ----------------------------------------------------------------------------
-- VIEW 3: VW_MATRICULAS_ATIVAS (Visão com Proteção de Escrita - WITH CHECK OPTION)
-- Finalidade:
--   Expor apenas matrículas com vínculo ativo ('ATIVA') para lançamento de notas
--   e frequências, impedindo via WITH CHECK OPTION que registros inseridos ou
--   atualizados por esta view alterem o status para 'TRANCADA'.
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
WITH CHECK OPTION CONSTRAINT CK_VW_MATRICULAS_ATIVAS;