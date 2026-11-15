/* =====================================================================
   SIGAB - Sistema Integrado de Gestão Acadêmica e Biblioteca
   DCC 502 - Banco de Dados I (UFRR) - Grupo 06
   Script 04: Consultas analíticas (DQL)
   Pré-requisito: scripts 01, 02 e 03 executados (Q01 e Q05 usam a
   VW_SITUACAO_ACADEMICA, fonte única da regra de aprovação RN08).

   Cobertura da Seção 3.5 do edital
   ---------------------------------------------------------------------
   Item do edital                                         Consultas
   1. Junções múltiplas (INNER JOIN e LEFT OUTER JOIN)    Q01, Q02 (também Q04-Q08)
   2. Subconsulta independente com IN / ALL               Q03
   3. Subconsultas correlacionadas EXISTS / NOT EXISTS    Q04 (EXISTS), Q05 e Q08 (NOT EXISTS)
   4. Visões (analítica/segurança e com proteção)         script 03: VW_SITUACAO_ACADEMICA
                                                          (READ ONLY), VW_MATRICULAS_ATIVAS
                                                          (CHECK OPTION), VW_ACERVO_PENDENCIAS
   5. Funções de janela com OVER()                        Q06 (DENSE_RANK, LAG, AVG), Q08 (ROW_NUMBER)
   Extra: agregação analítica com GROUP BY/HAVING/CASE    Q01, Q07

   Os "Resultados esperados" de cada consulta referem-se à base do
   script 02. Valores que dependem da data de execução estão indicados.
   ===================================================================== */

SET DEFINE OFF;

/* =====================================================================
   Q01 - Taxa de reprovação por disciplina (por nota e por falta)
   ---------------------------------------------------------------------
   Objetivo de negócio: o coordenador quer saber quais disciplinas
   reprovam mais e se o problema é desempenho (nota) ou evasão (falta).
   Considera só matrículas já avaliadas e disciplinas com pelo menos 3
   alunos avaliados, para a taxa ter significado.
   Técnicas: INNER JOIN múltiplo (view + DISCIPLINA + DEPARTAMENTO),
             GROUP BY, HAVING, agregação condicional com CASE.
   Resultado esperado: 3 disciplinas. MAT101 (Cálculo I) 40,0%,
   DCC301 (Estruturas de Dados) 33,3% e DCC101 (Algoritmos) 25,0%;
   cada uma com 1 reprovação por nota e 1 por falta.
   ===================================================================== */
SELECT dp.sigla                                                        AS departamento,
       d.codigo,
       d.nome                                                          AS disciplina,
       COUNT(*)                                                        AS avaliados,
       COUNT(CASE WHEN s.situacao_final_calculada = 'APROVADO'        THEN 1 END) AS aprovados,
       COUNT(CASE WHEN s.situacao_final_calculada = 'REPROVADO_NOTA'  THEN 1 END) AS reprov_nota,
       COUNT(CASE WHEN s.situacao_final_calculada = 'REPROVADO_FALTA' THEN 1 END) AS reprov_falta,
       ROUND(100 * COUNT(CASE WHEN s.situacao_final_calculada LIKE 'REPROVADO%' THEN 1 END)
                 / COUNT(*), 1)                                        AS taxa_reprovacao_pct
  FROM VW_SITUACAO_ACADEMICA s
 INNER JOIN DISCIPLINA   d  ON d.id_disciplina    = s.id_disciplina
 INNER JOIN DEPARTAMENTO dp ON dp.id_departamento = d.id_departamento
 WHERE s.situacao_final_calculada IN ('APROVADO', 'REPROVADO_NOTA', 'REPROVADO_FALTA')
 GROUP BY dp.sigla, d.codigo, d.nome
HAVING COUNT(*) >= 3
 ORDER BY taxa_reprovacao_pct DESC, d.codigo;

/* =====================================================================
   Q02 - Giro do acervo: todas as obras, com autores, exemplares,
         empréstimos e reservas (inclusive obras nunca emprestadas)
   ---------------------------------------------------------------------
   Objetivo de negócio: a biblioteca quer ver quais títulos têm mais
   saída, quais estão parados e onde falta exemplar (reservas ativas).
   Técnicas: INNER JOIN (OBRA x autores) e LEFT OUTER JOIN (exemplares,
             empréstimos, reservas), LISTAGG. As contagens são feitas em
             subconsultas agregadas antes da junção, para que juntar
             várias tabelas 1:N não multiplique as linhas.
   Resultado esperado: 12 obras. As obras 311 e 312 aparecem com 0
   empréstimos graças ao LEFT JOIN; 303 e 308 têm 0 exemplares
   disponíveis e reservas ativas.
   ===================================================================== */
SELECT o.id_obra,
       o.titulo,
       o.tipo,
       aut.autores,
       NVL(ex.exemplares, 0)                          AS exemplares,
       NVL(ex.exemplares, 0) - NVL(emp.em_aberto, 0)  AS disponiveis,
       NVL(emp.total, 0)                              AS emprestimos_historico,
       NVL(res.ativas, 0)                             AS reservas_ativas
  FROM OBRA o
 INNER JOIN (SELECT au.id_obra,
                    LISTAGG(a.nome, '; ') WITHIN GROUP (ORDER BY a.nome) AS autores
               FROM AUTORIA au
              INNER JOIN AUTOR a ON a.id_autor = au.id_autor
              GROUP BY au.id_obra) aut
         ON aut.id_obra = o.id_obra
  LEFT OUTER JOIN (SELECT id_obra, COUNT(*) AS exemplares
                     FROM EXEMPLAR
                    GROUP BY id_obra) ex
         ON ex.id_obra = o.id_obra
  LEFT OUTER JOIN (SELECT id_obra,
                          COUNT(*)                                          AS total,
                          COUNT(CASE WHEN data_devolucao IS NULL THEN 1 END) AS em_aberto
                     FROM EMPRESTIMO
                    GROUP BY id_obra) emp
         ON emp.id_obra = o.id_obra
  LEFT OUTER JOIN (SELECT id_obra, COUNT(*) AS ativas
                     FROM RESERVA
                    WHERE situacao = 'ATIVA'
                    GROUP BY id_obra) res
         ON res.id_obra = o.id_obra
 ORDER BY emprestimos_historico DESC, o.titulo;

/* =====================================================================
   Q03 - Alunos de cursos com carga horária >= 3000 h cuja média é
         maior ou igual à maior média departamental
   ---------------------------------------------------------------------
   Objetivo de negócio: identificar destaques acadêmicos (candidatos a
   monitoria ou bolsa) nos cursos longos, comparando cada aluno com a
   média de notas de TODOS os departamentos.
   Técnicas: subconsultas independentes (não correlacionadas) com IN
             (filtro de cursos) e >= ALL (comparação com o conjunto de
             médias departamentais).
   Resultado esperado: médias departamentais 7,25 (DCC), 6,00 (DMAT),
   7,50 (DQUI) e 7,50 (DLET); logo, o corte é 7,50. Aparecem 4 alunos
   de Ciência da Computação: Carla (8,75), Eduarda (8,50), Ana (7,83)
   e Isabela (7,50).
   ===================================================================== */
SELECT p.nome                       AS aluno,
       a.matricula,
       c.nome                       AS curso,
       c.carga_horaria,
       ROUND(AVG(m.nota_final), 2)  AS media_aluno
  FROM ALUNO a
 INNER JOIN PESSOA    p ON p.id_pessoa = a.id_pessoa
 INNER JOIN CURSO     c ON c.id_curso  = a.id_curso
 INNER JOIN MATRICULA m ON m.id_aluno  = a.id_pessoa
 WHERE m.nota_final IS NOT NULL
   AND a.id_curso IN (SELECT id_curso
                        FROM CURSO
                       WHERE carga_horaria >= 3000)
 GROUP BY p.nome, a.matricula, c.nome, c.carga_horaria
HAVING AVG(m.nota_final) >= ALL (SELECT AVG(m2.nota_final)
                                   FROM MATRICULA  m2
                                  INNER JOIN TURMA      t2 ON t2.id_turma      = m2.id_turma
                                  INNER JOIN DISCIPLINA d2 ON d2.id_disciplina = t2.id_disciplina
                                  WHERE m2.nota_final IS NOT NULL
                                  GROUP BY d2.id_departamento)
 ORDER BY media_aluno DESC;

/* =====================================================================
   Q04 - Alunos com matrícula ativa no semestre corrente e bloqueados
         na biblioteca por multa pendente
   ---------------------------------------------------------------------
   Objetivo de negócio: cruzar os dois módulos (o ponto de integração do
   sistema) para a secretaria cobrar a pendência antes da rematrícula.
   Técnicas: duas subconsultas correlacionadas com EXISTS (ligadas ao
   aluno da consulta externa) e uma subconsulta escalar para o valor.
   Semestre corrente = maior semestre cadastrado em TURMA.
   Resultado esperado: Carla Mendes Rocha (R$ 3,00) e Marcos Paulo
   Freitas (R$ 5,00).
   ===================================================================== */
SELECT p.nome      AS aluno,
       a.matricula,
       c.nome      AS curso,
       (SELECT SUM(mu.valor)
          FROM MULTA mu
         INNER JOIN EMPRESTIMO e ON e.id_emprestimo = mu.id_emprestimo
         WHERE e.id_pessoa = a.id_pessoa
           AND mu.data_pagamento IS NULL) AS total_multas_pendentes
  FROM ALUNO a
 INNER JOIN PESSOA p ON p.id_pessoa = a.id_pessoa
 INNER JOIN CURSO  c ON c.id_curso  = a.id_curso
 WHERE EXISTS (SELECT 1
                 FROM MATRICULA m
                INNER JOIN TURMA t ON t.id_turma = m.id_turma
                WHERE m.id_aluno = a.id_pessoa
                  AND m.status_matricula = 'ATIVA'
                  AND t.semestre = (SELECT MAX(semestre) FROM TURMA))
   AND EXISTS (SELECT 1
                 FROM EMPRESTIMO e
                INNER JOIN MULTA mu ON mu.id_emprestimo = e.id_emprestimo
                WHERE e.id_pessoa = a.id_pessoa
                  AND mu.data_pagamento IS NULL)
 ORDER BY p.nome;

/* =====================================================================
   Q05 - Alunos aptos a cursar disciplinas que têm pré-requisitos
         (divisão relacional)
   ---------------------------------------------------------------------
   Objetivo de negócio: apoiar o planejamento de oferta, listando quem já
   pode se matricular em cada disciplina com pré-requisito.
   Técnicas: NOT EXISTS duplo ("não existe pré-requisito que o aluno não
   tenha cumprido") = divisão relacional; mais um NOT EXISTS que exclui
   quem já foi aprovado ou está cursando a disciplina-alvo.
   Resultado esperado: 7 pares aluno-disciplina. Destaques: Isabela e
   João Victor aptos a Banco de Dados I (são os alunos do teste de
   concorrência do script 05); Ana apta a Cálculo II, pois trancou a
   disciplina antes.
   ===================================================================== */
SELECT d.codigo,
       d.nome     AS disciplina,
       p.nome     AS aluno,
       a.matricula,
       c.nome     AS curso
  FROM ALUNO a
 INNER JOIN PESSOA p ON p.id_pessoa = a.id_pessoa
 INNER JOIN CURSO  c ON c.id_curso  = a.id_curso
 CROSS JOIN DISCIPLINA d
 WHERE EXISTS (SELECT 1                              -- a disciplina tem pré-requisito
                 FROM PRE_REQUISITO pr
                WHERE pr.id_disciplina = d.id_disciplina)
   AND NOT EXISTS (SELECT 1                          -- não há pré-requisito pendente
                     FROM PRE_REQUISITO pr
                    WHERE pr.id_disciplina = d.id_disciplina
                      AND NOT EXISTS (SELECT 1
                                        FROM VW_SITUACAO_ACADEMICA s
                                       WHERE s.id_aluno      = a.id_pessoa
                                         AND s.id_disciplina = pr.id_disciplina_req
                                         AND s.situacao_final_calculada = 'APROVADO'))
   AND NOT EXISTS (SELECT 1                          -- ainda não fez nem está fazendo
                     FROM VW_SITUACAO_ACADEMICA s2
                    WHERE s2.id_aluno      = a.id_pessoa
                      AND s2.id_disciplina = d.id_disciplina
                      AND s2.situacao_final_calculada IN ('APROVADO', 'CURSANDO'))
 ORDER BY d.codigo, p.nome;

/* =====================================================================
   Q06 - Ranking de alunos por curso e distância para o colocado acima
   ---------------------------------------------------------------------
   Objetivo de negócio: classificar os alunos dentro do próprio curso
   (ex.: ordem de prioridade para bolsas) e mostrar quanto falta para
   cada um alcançar o colega imediatamente à frente.
   Técnicas: CTE com GROUP BY + funções de janela com OVER(PARTITION BY):
             DENSE_RANK (posição), AVG (média do curso na mesma linha) e
             LAG (média do colocado anterior).
   Resultado esperado: 14 alunos com nota em 7 cursos. Em Ciência da
   Computação (média do curso 7,01), Carla é 1ª (8,75) e Eduarda 2ª
   (8,50, a 0,25 da 1ª); nos demais cursos há um aluno avaliado cada.
   ===================================================================== */
WITH media_por_aluno AS (
    SELECT a.id_curso,
           c.nome                 AS curso,
           p.nome                 AS aluno,
           COUNT(*)               AS disciplinas_avaliadas,
           AVG(m.nota_final)      AS media_aluno
      FROM MATRICULA m
     INNER JOIN ALUNO  a ON a.id_pessoa = m.id_aluno
     INNER JOIN PESSOA p ON p.id_pessoa = a.id_pessoa
     INNER JOIN CURSO  c ON c.id_curso  = a.id_curso
     WHERE m.nota_final IS NOT NULL
     GROUP BY a.id_curso, c.nome, p.nome
)
SELECT curso,
       DENSE_RANK() OVER (PARTITION BY id_curso ORDER BY media_aluno DESC)          AS posicao,
       aluno,
       disciplinas_avaliadas,
       ROUND(media_aluno, 2)                                                        AS media_aluno,
       ROUND(AVG(media_aluno) OVER (PARTITION BY id_curso), 2)                      AS media_do_curso,
       ROUND(LAG(media_aluno) OVER (PARTITION BY id_curso ORDER BY media_aluno DESC)
             - media_aluno, 2)                                                      AS distancia_para_anterior
  FROM media_por_aluno
 ORDER BY curso, posicao, aluno;

/* =====================================================================
   Q07 - Indicadores de atraso e multas por perfil de usuário
   ---------------------------------------------------------------------
   Objetivo de negócio: comparar alunos e professores (prazos diferentes:
   7 x 15 dias) quanto a atrasos, tempo de retenção e inadimplência,
   para avaliar se os prazos da RN12 estão adequados.
   Técnicas: LEFT JOIN, GROUP BY com agregação condicional (CASE dentro
   de COUNT/AVG/SUM) e aritmética de datas.
   Resultado esperado: ALUNO 15 empréstimos, 8 devolvidos com atraso
   (média 4,25 dias), R$ 34,00 em multas, dos quais R$ 8,00 pendentes;
   PROFESSOR 7 empréstimos, 2 com atraso (média 5,5 dias), R$ 11,00 em
   multas, nada pendente.
   ===================================================================== */
SELECT CASE p.tipo_pessoa WHEN 'A' THEN 'ALUNO' ELSE 'PROFESSOR' END              AS perfil,
       COUNT(*)                                                                    AS total_emprestimos,
       COUNT(CASE WHEN e.data_devolucao IS NULL THEN 1 END)                        AS em_aberto,
       COUNT(CASE WHEN e.data_devolucao > e.data_prevista_devolucao THEN 1 END)    AS devolvidos_com_atraso,
       ROUND(AVG(CASE WHEN e.data_devolucao > e.data_prevista_devolucao
                      THEN e.data_devolucao - e.data_prevista_devolucao END), 2)   AS media_dias_atraso,
       ROUND(AVG(CASE WHEN e.data_devolucao IS NOT NULL
                      THEN e.data_devolucao - e.data_emprestimo END), 2)           AS media_dias_retencao,
       COUNT(mu.id_multa)                                                          AS multas_geradas,
       NVL(SUM(mu.valor), 0)                                                       AS valor_total_multas,
       NVL(SUM(CASE WHEN mu.data_pagamento IS NULL THEN mu.valor END), 0)          AS saldo_pendente
  FROM EMPRESTIMO e
 INNER JOIN PESSOA p ON p.id_pessoa = e.id_pessoa
  LEFT JOIN MULTA mu ON mu.id_emprestimo = e.id_emprestimo
 GROUP BY p.tipo_pessoa
 ORDER BY perfil;

/* =====================================================================
   Q08 - Fila de reservas ativas para obras sem exemplar disponível
   ---------------------------------------------------------------------
   Objetivo de negócio: quando um exemplar voltar, o bibliotecário sabe
   quem chamar primeiro (ordem de chegada) e quando o primeiro exemplar
   deve ser devolvido (RN15).
   Técnicas: ROW_NUMBER() OVER (PARTITION BY obra ORDER BY data) e
   NOT EXISTS duplo correlacionado ("não existe exemplar que não esteja
   emprestado" = obra totalmente emprestada).
   Resultado esperado: 5 reservas. Obra 308 (Fundamentos de Física):
   Larissa (1ª), Felipe (2º); obra 303 (Sistemas Operacionais
   Modernos): Diego (1º), Eduarda (2ª), Juliana (3ª).
   ===================================================================== */
SELECT o.id_obra,
       o.titulo,
       ROW_NUMBER() OVER (PARTITION BY r.id_obra ORDER BY r.data_reserva) AS posicao_fila,
       p.nome                                                              AS usuario,
       CASE p.tipo_pessoa WHEN 'A' THEN 'ALUNO' ELSE 'PROFESSOR' END       AS perfil,
       TO_CHAR(r.data_reserva, 'DD/MM/YYYY HH24:MI')                       AS data_reserva,
       (SELECT MIN(e.data_prevista_devolucao)
          FROM EMPRESTIMO e
         WHERE e.id_obra = r.id_obra
           AND e.data_devolucao IS NULL)                                   AS previsao_liberacao
  FROM RESERVA r
 INNER JOIN OBRA   o ON o.id_obra   = r.id_obra
 INNER JOIN PESSOA p ON p.id_pessoa = r.id_pessoa
 WHERE r.situacao = 'ATIVA'
   AND NOT EXISTS (SELECT 1                          -- não existe exemplar livre
                     FROM EXEMPLAR x
                    WHERE x.id_obra = r.id_obra
                      AND NOT EXISTS (SELECT 1
                                        FROM EMPRESTIMO e
                                       WHERE e.id_obra         = x.id_obra
                                         AND e.numero_exemplar = x.numero_exemplar
                                         AND e.data_devolucao IS NULL))
 ORDER BY o.titulo, posicao_fila;
