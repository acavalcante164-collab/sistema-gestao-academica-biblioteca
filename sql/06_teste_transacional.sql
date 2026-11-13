-- ============================================================================
-- PROJETO: Sistema Integrado de Gestão Acadêmica e Biblioteca (SIGAB)
-- SCRIPT : 06_teste_transacional.sql
-- OBJETIVO: Controle Transacional, Concorrência (FOR UPDATE) e SAVEPOINT
-- REFERÊNCIA: Issue #12 e Seção 3.6 da Especificação Oficial
-- ============================================================================
-- INSTRUÇÕES DE EXECUÇÃO PARA DEMONSTRAÇÃO PRÁTICA:
-- Para reproduzir o cenário real de concorrência (Parte 1), abra DUAS janelas
-- (conexões independentes) no Oracle SQL Developer:
--   -> Janela A: SESSÃO 1 (Transação do Aluno 1009)
--   -> Janela B: SESSÃO 2 (Transação do Aluno 1010)
-- Execute os blocos na ordem cronológica dos PASSOS (T1 a T6).
-- ============================================================================

-- ============================================================================
-- PARTE 1: CENÁRIO DE CONCORRÊNCIA — DISPUTA PELA ÚLTIMA VAGA (RN04)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- PASSO 0 (PREPARAÇÃO DO AMBIENTE - Executar na SESSÃO 1):
-- Ajusta a capacidade da Turma 501 para (matrículas ativas atuais + 1),
-- garantindo que reste EXATAMENTE 1 VAGA disponível para disputa.
-- ----------------------------------------------------------------------------
UPDATE TURMA t
   SET t.vagas_total = (
       SELECT COUNT(*) + 1
         FROM MATRICULA m
        WHERE m.id_turma = 501
          AND m.status_matricula = 'ATIVA'
   )
 WHERE t.id_turma = 501;

-- Garante que os alunos 1009 e 1010 ainda não estão matriculados na turma 501
DELETE FROM MATRICULA WHERE id_turma = 501 AND id_aluno IN (1009, 1010);
COMMIT;

-- Conferência do estado inicial antes da disputa (deve mostrar 1 vaga restante)
SELECT t.id_turma,
       t.vagas_total,
       COUNT(m.id_aluno) AS matriculas_ativas,
       (t.vagas_total - COUNT(m.id_aluno)) AS vagas_disponiveis
  FROM TURMA t
  LEFT JOIN MATRICULA m
    ON m.id_turma = t.id_turma
   AND m.status_matricula = 'ATIVA'
 WHERE t.id_turma = 501
 GROUP BY t.id_turma, t.vagas_total;


-- ----------------------------------------------------------------------------
-- PASSO 1 [Instante T1] — Executar na SESSÃO 1:
-- A Sessão 1 inicia a transação e solicita bloqueio pessimista (FOR UPDATE)
-- na linha da Turma 501 para alocar a última vaga ao Aluno 1009.
-- ----------------------------------------------------------------------------
SELECT id_turma, semestre, vagas_total
  FROM TURMA
 WHERE id_turma = 501
   FOR UPDATE;


-- ----------------------------------------------------------------------------
-- PASSO 2 [Instante T2] — Executar na SESSÃO 2 (em paralelo):
-- A Sessão 2 tenta matricular o Aluno 1010 na mesma Turma 501.
-- COMPORTAMENTO ESPERADO:
-- O comando ficará EM ESPERA (bloqueado/travado no SQL Developer), pois o
-- bloco BEFORE EACH ROW da COMPOUND TRIGGER (TRG_VALIDA_MATRICULA) executa
-- SELECT ... FOR UPDATE na linha id_turma = 501, que está retida pela Sessão 1.
-- ----------------------------------------------------------------------------
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, status_matricula)
VALUES (1010, 501, SYSDATE, 'ATIVA');


-- ----------------------------------------------------------------------------
-- PASSO 3 [Instante T3] — Executar na SESSÃO 1:
-- Enquanto a Sessão 2 aguarda na fila de lock, a Sessão 1 insere a matrícula
-- do Aluno 1009, ocupando a última vaga disponível da Turma 501.
-- ----------------------------------------------------------------------------
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, status_matricula)
VALUES (1009, 501, SYSDATE, 'ATIVA');


-- ----------------------------------------------------------------------------
-- PASSO 4 [Instante T4] — Executar na SESSÃO 1:
-- A Sessão 1 confirma a transação (COMMIT) e libera o lock sobre a Turma 501.
-- COMPORTAMENTO IMEDIATO NA SESSÃO 2:
-- Assim que o COMMIT abaixo é executado, a Sessão 2 é desbloqueada, avança
-- para o bloco AFTER STATEMENT da trigger TRG_VALIDA_MATRICULA, lê a nova
-- contagem comitada (matriculas_ativas > vagas_total) e falha com:
-- ORA-20001: RN04 Violada: A turma 501 já atingiu sua capacidade máxima...
-- ----------------------------------------------------------------------------
COMMIT;


-- ----------------------------------------------------------------------------
-- PASSO 5 [Instante T5] — Executar na SESSÃO 2 (após receber o erro ORA-20001):
-- Encerra a transação da Sessão 2 garantindo estado limpo.
-- ----------------------------------------------------------------------------
ROLLBACK;


-- ----------------------------------------------------------------------------
-- PASSO 6 [Instante T6] — Conferência Pós-Concorrência (Qualquer Sessão):
-- Comprova que apenas o Aluno 1009 ocupou a última vaga e que vagas_disponiveis = 0.
-- ----------------------------------------------------------------------------
SELECT t.id_turma,
       t.vagas_total,
       COUNT(m.id_aluno) AS matriculas_ativas,
       (t.vagas_total - COUNT(m.id_aluno)) AS vagas_disponiveis
  FROM TURMA t
  LEFT JOIN MATRICULA m
    ON m.id_turma = t.id_turma
   AND m.status_matricula = 'ATIVA'
 WHERE t.id_turma = 501
 GROUP BY t.id_turma, t.vagas_total;


-- ============================================================================
-- PARTE 2: CONTROLE TRANSACIONAL COM SAVEPOINT E ROLLBACK PARCIAL
-- ============================================================================
-- Objetivo: Demonstrar atomicidade parcial, preservação de dados válidos
--           (incluindo trigger de auditoria RN16) e descarte de operações
--           inválidas após SAVEPOINT (inclusive tentativa de furar vagas via
--           UPDATE de 'TRANCADA' para 'ATIVA').
-- ============================================================================

-- 1. Inicia-se uma operação válida na transação: lançamento da nota 8.50 e
--    frequência 90% para o Aluno 1009 na Turma 501 (dispara TRG_AUDITORIA_NOTA).
UPDATE MATRICULA
   SET nota_final = 8.50,
       frequencia = 90.00
 WHERE id_aluno = 1009
   AND id_turma = 501;

-- 2. Cria-se o SAVEPOINT após o lançamento válido da nota e de sua auditoria
SAVEPOINT sp_nota_85_validada;

-- 3. Operação subsequente na mesma transação: altera a nota para um valor
--    equivocado (4.00) e tenta inserir uma matrícula trancada para o Aluno 1010
UPDATE MATRICULA
   SET nota_final = 4.00
 WHERE id_aluno = 1009
   AND id_turma = 501;

INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, status_matricula)
VALUES (1010, 501, SYSDATE, 'TRANCADA');

-- 4. Provoca-se uma violação de regra de negócio/integridade:
--    Tentativa de reativar (UPDATE para 'ATIVA') a matrícula do Aluno 1010
--    na Turma 501 que já está lotada (bloqueada por TRG_VALIDA_MATRICULA com ORA-20001)
--    ou tentativa de atribuir nota fora do domínio (ORA-02290: CK_MATRICULA_NOTA).
BEGIN
    UPDATE MATRICULA
       SET status_matricula = 'ATIVA'
     WHERE id_aluno = 1010
       AND id_turma = 501;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Exceção capturada após SAVEPOINT: ' || SQLERRM);
END;
/

-- 5. Recuperação parcial: desfaz todas as alterações feitas APÓS o SAVEPOINT
--    (desfaz a nota 4.00 e a inserção da matrícula trancada do aluno 1010),
--    mas PRESERVA a nota 8.50, a frequência 90% e o primeiro log de auditoria!
ROLLBACK TO SAVEPOINT sp_nota_85_validada;

-- 6. Confirma a parte íntegra da transação de forma permanente (Durabilidade ACID)
COMMIT;

-- 7. Evidência Final (Verificação do Estado Consistente dos Dados e da Auditoria):
SELECT id_aluno,
       id_turma,
       nota_final,
       frequencia,
       status_matricula,
       situacao_final_calculada
  FROM VW_SITUACAO_ACADEMICA
 WHERE id_turma = 501
   AND id_aluno IN (1009, 1010);

SELECT id_auditoria,
       id_aluno,
       id_turma,
       nota_anterior,
       nota_nova,
       TO_CHAR(data_alteracao, 'DD/MM/YYYY HH24:MI:SS') AS data_hora,
       usuario
  FROM AUDITORIA_NOTA
 WHERE id_turma = 501
   AND id_aluno = 1009
 ORDER BY id_auditoria;