/* =====================================================================
   SIGAB - Sistema Integrado de Gestão Acadêmica e Biblioteca
   DCC 502 - Banco de Dados I (UFRR) - Grupo 06
   Script 05: Teste transacional - concorrência, COMMIT, ROLLBACK e
              SAVEPOINT (Etapa 6, seção 4)
   Pré-requisito: scripts 01 a 03 executados e base do script 02 intacta.

   Roteiro
     PARTE A - Duas sessões disputam a última vaga da turma 501
               (SELECT ... FOR UPDATE, bloqueio de linha, COMMIT/ROLLBACK)
     PARTE B - Recuperação parcial com SAVEPOINT / ROLLBACK TO SAVEPOINT
     PARTE C - Tratamento de exceções de integridade em lote (PL/SQL),
               com um SAVEPOINT por item e COMMIT ao final

   COMO EXECUTAR NO SQL DEVELOPER
   ---------------------------------------------------------------------
   * Auto-commit deve estar DESLIGADO (padrão do SQL Developer:
     Ferramentas > Preferências > Banco de Dados > Avançado).
   * A PARTE A precisa de DUAS SESSÕES de verdade. Duas abas comuns da
     mesma conexão compartilham a mesma sessão e o teste não funciona.
     Abra a 2ª aba com "Planilha SQL Não Compartilhada" (Ctrl+Shift+N)
     na conexão SIGAB e cole nela apenas os comandos marcados SESSÃO 2.
   * Na PARTE A, execute um comando por vez (Ctrl+Enter), na ordem dos
     instantes T0 a T6. As PARTES B e C podem ser executadas selecionando
     o trecho e pressionando F5.
   * Para repetir a demonstração do zero, rode de novo o script 02
     (ele recarrega a base e já é compatível com os triggers ativos).
   ===================================================================== */

SET SERVEROUTPUT ON;

/* =====================================================================
   PARTE A - CONCORRÊNCIA: disputa pela última vaga (RN04)
   ---------------------------------------------------------------------
   Pré-condição: turma 501 (Banco de Dados I) com 3 vagas e 2 matrículas
   ativas. Isabela (1009) na SESSÃO 1 e João Victor (1010) na SESSÃO 2
   cumprem os pré-requisitos (ver Q05) e tentam a última vaga ao mesmo
   tempo.

   Instante  SESSÃO 1 (aluna 1009)        SESSÃO 2 (aluno 1010)         Efeito no Oracle
   T1        SELECT ... FOR UPDATE        -                             S1 trava a linha da turma 501 (lock TX)
   T2        -                            INSERT matrícula 1010         Trigger de S2 tenta travar a mesma linha: S2 FICA ESPERANDO
   T3        INSERT matrícula 1009        (esperando...)                S1 ocupa a última vaga (3/3)
   T4        COMMIT                       (desbloqueia)                 S2 retoma, conta 4 ativas > 3 vagas: ORA-20001
   T5        -                            ROLLBACK                      S2 encerra a transação; só 1009 ficou com a vaga
   ===================================================================== */

-- T0 (qualquer sessão) - Conferir a pré-condição: esperado 3 vagas, 2 ativas
SELECT t.id_turma,
       t.vagas_total,
       (SELECT COUNT(*) FROM MATRICULA m
         WHERE m.id_turma = t.id_turma AND m.status_matricula = 'ATIVA') AS ativas,
       (SELECT COUNT(*) FROM MATRICULA m
         WHERE m.id_turma = t.id_turma AND m.id_aluno IN (1009, 1010))  AS ja_matriculados_1009_1010
  FROM TURMA t
 WHERE t.id_turma = 501;
-- Se "ativas" for 3 ou "ja_matriculados" for maior que 0, rode o script 02 antes.

-- ---------------------------------------------------------------------
-- T1 - SESSÃO 1: trava a linha da turma 501 (bloqueio exclusivo de linha)
-- ---------------------------------------------------------------------
SELECT id_turma, vagas_total
  FROM TURMA
 WHERE id_turma = 501
   FOR UPDATE;

-- ---------------------------------------------------------------------
-- T2 - SESSÃO 2 (planilha não compartilhada): tenta matricular o 1010.
-- O trigger TRG_VALIDA_MATRICULA executa SELECT ... FOR UPDATE na turma
-- 501, que está travada pela SESSÃO 1: o comando fica "executando"
-- (aguardando o lock) até a SESSÃO 1 terminar a transação.
-- ---------------------------------------------------------------------
INSERT INTO MATRICULA (id_aluno, id_turma, status_matricula) VALUES (1010, 501, 'ATIVA');

-- ---------------------------------------------------------------------
-- T3 - SESSÃO 1: matricula a 1009 e ocupa a última vaga (3 de 3)
-- ---------------------------------------------------------------------
INSERT INTO MATRICULA (id_aluno, id_turma, status_matricula) VALUES (1009, 501, 'ATIVA');

-- ---------------------------------------------------------------------
-- T4 - SESSÃO 1: confirma. O lock é liberado e a SESSÃO 2 continua.
-- Na SESSÃO 2 aparece:
--   ORA-20001: RN04 violada: turma 501 sem vagas (4 matrículas ativas para 3 vagas).
-- ---------------------------------------------------------------------
COMMIT;

-- ---------------------------------------------------------------------
-- T5 - SESSÃO 2: encerra a transação que falhou
-- ---------------------------------------------------------------------
ROLLBACK;

-- ---------------------------------------------------------------------
-- T6 (qualquer sessão) - Resultado: 3 ativas, 1009 matriculada, 1010 não
-- ---------------------------------------------------------------------
SELECT m.id_aluno, p.nome, m.status_matricula, m.data_matricula
  FROM MATRICULA m
 INNER JOIN PESSOA p ON p.id_pessoa = m.id_aluno
 WHERE m.id_turma = 501
 ORDER BY m.id_aluno;

/* Variação para a arguição: se em T4 a SESSÃO 1 executar ROLLBACK em vez
   de COMMIT, a matrícula da 1009 é desfeita, a vaga continua livre e o
   INSERT da SESSÃO 2 é concluído com sucesso (o 1010 fica com a vaga).
   Sem o FOR UPDATE, as duas sessões contariam 2 ativas ao mesmo tempo,
   ambas passariam na validação e a turma terminaria com 4 alunos para
   3 vagas (anomalia de concorrência evitada pelo bloqueio de linha). */


/* =====================================================================
   PARTE B - SAVEPOINT e ROLLBACK TO SAVEPOINT (recuperação parcial)
   ---------------------------------------------------------------------
   Cenário: a professora lança notas da turma 501. A primeira nota está
   correta e vira um marco (SAVEPOINT). Em seguida ocorrem dois erros:
     (1) nota 15,00, que viola CK_MATRICULA_NOTA (ORA-02290). O Oracle
         desfaz SOZINHO apenas aquele comando (atomicidade de comando);
     (2) uma nota digitada errado (2,00 para a Carla), que o banco ACEITA.
   O ROLLBACK TO SAVEPOINT desfaz o erro (2) e o log de auditoria gerado
   por ele, preservando a nota correta da Isabela e seu log. O COMMIT
   final grava o estado consistente.
   Pré-condição: PARTE A concluída (Isabela, 1009, matriculada na 501).
   Selecione do passo B1 ao B7 e execute com F5.
   ===================================================================== */

-- B1. Lança nota e frequência da Isabela (dispara TRG_AUDITORIA_NOTA)
UPDATE MATRICULA
   SET nota_final = 8.50, frequencia = 90
 WHERE id_aluno = 1009 AND id_turma = 501;

-- B2. Marco transacional: até aqui está tudo correto
SAVEPOINT sp_nota_lancada;

-- B3. Erro 1 - nota fora do domínio: ORA-02290 (CK_MATRICULA_NOTA).
--     O comando é rejeitado e desfeito; a transação continua aberta.
UPDATE MATRICULA
   SET nota_final = 15.00
 WHERE id_aluno = 1003 AND id_turma = 501;

-- B4. Erro 2 - nota digitada errado (aceita pelo banco: 2,00 é válido)
UPDATE MATRICULA
   SET nota_final = 2.00, frequencia = 95
 WHERE id_aluno = 1003 AND id_turma = 501;

-- B5. Estado intermediário (dentro da transação): as duas notas e os 2 logs novos
SELECT m.id_aluno, m.nota_final, m.frequencia,
       (SELECT COUNT(*) FROM AUDITORIA_NOTA a
         WHERE a.id_aluno = m.id_aluno AND a.id_turma = m.id_turma) AS logs_auditoria
  FROM MATRICULA m
 WHERE m.id_turma = 501 AND m.id_aluno IN (1003, 1009)
 ORDER BY m.id_aluno;

-- B6. Desfaz somente o que veio depois do marco (o erro 2 e o seu log)
ROLLBACK TO SAVEPOINT sp_nota_lancada;

-- B7. Confirma: Isabela com 8,50 (1 log); Carla sem nota (0 logs)
COMMIT;

SELECT m.id_aluno, p.nome, m.nota_final, m.frequencia,
       (SELECT COUNT(*) FROM AUDITORIA_NOTA a
         WHERE a.id_aluno = m.id_aluno AND a.id_turma = m.id_turma) AS logs_auditoria
  FROM MATRICULA m
 INNER JOIN PESSOA p ON p.id_pessoa = m.id_aluno
 WHERE m.id_turma = 501 AND m.id_aluno IN (1003, 1009)
 ORDER BY m.id_aluno;

SELECT id_auditoria, id_aluno, id_turma, nota_anterior, nota_nova,
       TO_CHAR(data_alteracao, 'DD/MM/YYYY HH24:MI:SS') AS data_alteracao, usuario
  FROM AUDITORIA_NOTA
 WHERE id_turma = 501
 ORDER BY id_auditoria;


/* =====================================================================
   PARTE C - Tratamento de exceções de integridade em lote (PL/SQL)
   ---------------------------------------------------------------------
   Cenário: a secretaria matricula um lote de 4 alunos em Sistemas
   Operacionais (turma 505). Cada aluno tem seu próprio SAVEPOINT: se uma
   matrícula violar alguma regra, só ela é desfeita e o lote continua.
   No final, um único COMMIT grava as matrículas válidas (atomicidade
   por item, consistência garantida pelos triggers e constraints).
   Resultado esperado:
     1001 Ana       -> matriculada
     1002 Bruno     -> recusado: RN05, falta DCC301 (ORA-20002)
     1003 Carla     -> recusada: já matriculada na turma (ORA-00001)
     1007 Gabriela  -> recusada: RN05, falta DCC301 (ORA-20002)
   Selecione o bloco e execute com F5.
   ===================================================================== */
DECLARE
    TYPE t_ids IS TABLE OF MATRICULA.id_aluno%TYPE;
    v_lote        t_ids := t_ids(1001, 1002, 1003, 1007);
    v_turma       CONSTANT MATRICULA.id_turma%TYPE := 505;
    v_aceitas     PLS_INTEGER := 0;
    v_recusadas   PLS_INTEGER := 0;

    e_sem_vaga     EXCEPTION;
    e_pre_requisito EXCEPTION;
    PRAGMA EXCEPTION_INIT(e_sem_vaga,      -20001);
    PRAGMA EXCEPTION_INIT(e_pre_requisito, -20002);
BEGIN
    DBMS_OUTPUT.PUT_LINE('Matrícula em lote na turma ' || v_turma);

    FOR i IN 1 .. v_lote.COUNT LOOP
        SAVEPOINT sp_aluno;
        BEGIN
            INSERT INTO MATRICULA (id_aluno, id_turma, status_matricula)
            VALUES (v_lote(i), v_turma, 'ATIVA');

            v_aceitas := v_aceitas + 1;
            DBMS_OUTPUT.PUT_LINE('  [ACEITA]   aluno ' || v_lote(i));
        EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
                ROLLBACK TO SAVEPOINT sp_aluno;
                v_recusadas := v_recusadas + 1;
                DBMS_OUTPUT.PUT_LINE('  [RECUSADA] aluno ' || v_lote(i) || ': já matriculado nesta turma (RN06)');
            WHEN e_sem_vaga OR e_pre_requisito THEN
                ROLLBACK TO SAVEPOINT sp_aluno;
                v_recusadas := v_recusadas + 1;
                DBMS_OUTPUT.PUT_LINE('  [RECUSADA] aluno ' || v_lote(i) || ': ' || SQLERRM);
            WHEN OTHERS THEN
                ROLLBACK TO SAVEPOINT sp_aluno;
                v_recusadas := v_recusadas + 1;
                DBMS_OUTPUT.PUT_LINE('  [ERRO]     aluno ' || v_lote(i) || ': ' || SQLERRM);
        END;
    END LOOP;

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('COMMIT: ' || v_aceitas || ' matrícula(s) gravada(s), ' ||
                         v_recusadas || ' recusada(s).');
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;  -- falha inesperada fora do laço: desfaz o lote inteiro
        DBMS_OUTPUT.PUT_LINE('Lote cancelado (ROLLBACK): ' || SQLERRM);
        RAISE;
END;
/

-- Resultado: turma 505 com a nova matrícula da Ana
SELECT s.id_aluno, s.nome_aluno, s.codigo_disciplina, s.situacao_final_calculada
  FROM VW_SITUACAO_ACADEMICA s
 WHERE s.id_turma = 505
 ORDER BY s.id_aluno;
