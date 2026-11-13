-- ============================================================================
-- UNIVERSIDADE FEDERAL DE RORAIMA (UFRR) - DCC 502: BANCO DE DADOS I
-- PROJETO: Sistema Integrado de Gestão Acadêmica e Biblioteca (SIGAB) - Grupo 06
-- SCRIPT: 06_teste_transacional.sql (Referência: Issue #12 e Seção 3.6 do Edital)
-- ============================================================================
-- INSTRUÇÕES DE EXECUÇÃO:
--   A Parte 1 demonstra controle de concorrência entre DUAS SESSÕES simultâneas
--   no Oracle SQL Developer (abra duas conexões: SESSÃO 1 e SESSÃO 2).
--   A Parte 2 demonstra atomicidade e recuperação parcial via SAVEPOINT/ROLLBACK.
-- ============================================================================

-- ============================================================================
-- PARTE 1: DISPUTA CONCORRENTE PELA ÚLTIMA VAGA DA TURMA (SELECT ... FOR UPDATE)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- PASSO 0 (PREPARAÇÃO DO CENÁRIO - Executar na SESSÃO 1):
-- Configura temporariamente a turma 501 para ter capacidade exatamente igual
-- ao número atual de matriculados + 1 (restando apenas 1 ÚLTIMA VAGA).
-- ----------------------------------------------------------------------------
DECLARE
    v_matriculados_atuais NUMBER;
BEGIN
    SELECT COUNT(*)
      INTO v_matriculados_atuais
      FROM MATRICULA
     WHERE id_turma = 501
       AND status_matricula = 'ATIVA';

    UPDATE TURMA
       SET vagas_total = v_matriculados_atuais + 1
     WHERE id_turma = 501;

    COMMIT;
END;
/

-- Conferência do estado antes da disputa (Resta 1 vaga disponível):
SELECT t.id_turma,
       t.vagas_total,
       COUNT(m.id_aluno) AS vagas_ocupadas,
       (t.vagas_total - COUNT(m.id_aluno)) AS vagas_restantes
  FROM TURMA t
  LEFT JOIN MATRICULA m ON t.id_turma = m.id_turma AND m.status_matricula = 'ATIVA'
 WHERE t.id_turma = 501
 GROUP BY t.id_turma, t.vagas_total;

-- ----------------------------------------------------------------------------
-- PASSO 1 (Executar na SESSÃO 1 - T1):
-- A Sessão 1 bloqueia explicitamente a linha da turma 501 com FOR UPDATE
-- e insere a matrícula do primeiro candidato na última vaga, SEM dar COMMIT ainda.
-- ----------------------------------------------------------------------------
SELECT id_turma, vagas_total
  FROM TURMA
 WHERE id_turma = 501
   FOR UPDATE;

-- Insere o Aluno candidato A na última vaga (substitua 1009 por um id_aluno válido não matriculado na turma 501):
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula)
VALUES (1009, 501, SYSDATE, NULL, NULL, 'ATIVA');

-- ATENÇÃO: NÃO execute COMMIT ainda na Sessão 1! Vá para a Sessão 2.

-- ----------------------------------------------------------------------------
-- PASSO 2 (Executar na SESSÃO 2 - T2):
-- Enquanto a Sessão 1 mantém a transação aberta, o segundo aluno tenta disputar
-- a mesma vaga na turma 501.
-- Resultado esperado: A Sessão 2 ficará BLOQUEADA (em espera / Row Exclusive Lock)
-- porque a trigger TRG_VALIDA_MATRICULA (ou o comando abaixo) executa SELECT ... FOR UPDATE.
-- ----------------------------------------------------------------------------
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula)
VALUES (1010, 501, SYSDATE, NULL, NULL, 'ATIVA');

-- ----------------------------------------------------------------------------
-- PASSO 3 (Voltar à SESSÃO 1 - T3):
-- Efetiva a matrícula da Sessão 1 com COMMIT, liberando o bloqueio da linha.
-- ----------------------------------------------------------------------------
COMMIT;

-- ----------------------------------------------------------------------------
-- PASSO 4 (Observar o resultado imediato na SESSÃO 2 - T4):
-- Assim que a Sessão 1 executa o COMMIT, a Sessão 2 é desbloqueada e a trigger
-- TRG_VALIDA_MATRICULA aborta a segunda matrícula com o erro:
--   ORA-20001: RN04 Violada: A turma 501 já atingiu sua capacidade máxima.
-- Em seguida, encerre a transação na Sessão 2:
-- ----------------------------------------------------------------------------
ROLLBACK;


-- ============================================================================
-- PARTE 2: CONTROLE TRANSACIONAL COM SAVEPOINT E ROLLBACK TO SAVEPOINT
-- (Pode ser executado integralmente na SESSÃO 1)
-- ============================================================================

-- 1. Inicia uma transação atualizando validamente a nota de uma matrícula
--    (Isso dispara automaticamente a trigger TRG_AUDITORIA_NOTA)
UPDATE MATRICULA
   SET nota_final = 8.75,
       frequencia = 92.00
 WHERE id_aluno = 1001
   AND id_turma = 501;

-- 2. Cria um SAVEPOINT garantindo que o lançamento válido da nota e sua auditoria
--    estão salvos dentro da transação atual:
SAVEPOINT sp_lancamento_nota_valido;

-- 3. Provoca uma operação inválida subsequente dentro da mesma transação
--    (Bloco PL/SQL captura a violação de integridade CK_MATRICULA_NOTA: nota > 10
--     e executa ROLLBACK TO SAVEPOINT para recuperar o estado íntegro anterior):
BEGIN
    -- Tentativa de lançar uma nota inválida (15.00 viola CK_MATRICULA_NOTA BETWEEN 0 AND 10)
    UPDATE MATRICULA
       SET nota_final = 15.00
     WHERE id_aluno = 1001
       AND id_turma = 501;
EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE('Erro capturado: ' || SQLERRM);
        DBMS_OUTPUT.PUT_LINE('Executando ROLLBACK TO SAVEPOINT sp_lancamento_nota_valido...');
        ROLLBACK TO SAVEPOINT sp_lancamento_nota_valido;
END;
/

-- 4. Confirma a transação preservando tudo o que ocorreu antes do SAVEPOINT:
COMMIT;

-- 5. Evidência final: comprova que a nota 8.75 foi persistida e auditada com sucesso!
SELECT id_aluno, id_turma, nota_final, frequencia, status_matricula
  FROM MATRICULA
 WHERE id_aluno = 1001
   AND id_turma = 501;

SELECT id_auditoria, id_aluno, id_turma, nota_anterior, nota_nova, data_alteracao, usuario
  FROM AUDITORIA_NOTA
 WHERE id_aluno = 1001
   AND id_turma = 501
 ORDER BY id_auditoria DESC;