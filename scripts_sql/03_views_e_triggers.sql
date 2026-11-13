/* =====================================================================
   SIGAB - Sistema Integrado de Gestão Acadêmica e Biblioteca
   DCC 502 - Banco de Dados I (UFRR) - Grupo 06
   Script 03: Visões (views) e gatilhos (triggers)
   Pré-requisito: scripts 01 e 02 executados.

   Visões (Etapa 6, seção 1)
     VW_SITUACAO_ACADEMICA  analítica e de segurança  WITH READ ONLY
     VW_MATRICULAS_ATIVAS   proteção de escrita        WITH CHECK OPTION
     VW_ACERVO_PENDENCIAS   gerencial da biblioteca    WITH READ ONLY

   Gatilhos (Etapa 6, seção 2)
     TRG_VALIDA_MATRICULA      RN04 vagas e RN05 pré-requisitos  (COMPOUND)
     TRG_VALIDA_EMPRESTIMO     RN10, RN11, RN12 e RN14           (COMPOUND)
     TRG_GERA_MULTA_DEVOLUCAO  RN13 multa de R$ 1,00 por dia
     TRG_AUDITORIA_NOTA        RN16 / RF10 log de alteração de nota

   Os triggers que precisam consultar a própria tabela (MATRICULA e
   EMPRESTIMO) são COMPOUND: as linhas são guardadas no BEFORE EACH ROW e
   validadas no AFTER STATEMENT, o que evita o ORA-04091 (tabela mutante)
   também em INSERT ... SELECT e UPDATE de várias linhas.

   Códigos de erro: -20001 vagas | -20002 pré-requisito | -20003 multa
                    -20004 exemplar emprestado | -20005 limite de empréstimos
   Reexecutável: tudo usa CREATE OR REPLACE.
   ===================================================================== */

SET DEFINE OFF;
SET SERVEROUTPUT ON;

/* =====================================================================
   1. VISÕES
   As views vêm antes dos triggers porque TRG_VALIDA_MATRICULA usa a
   VW_SITUACAO_ACADEMICA para checar pré-requisitos.
   ===================================================================== */

-- ---------------------------------------------------------------------
-- 1.1 VW_SITUACAO_ACADEMICA (analítica e de segurança, somente leitura)
-- Fonte única da regra RN08: a situação final é calculada aqui a partir
-- de nota_final, frequencia e status_matricula, e não armazenada em
-- MATRICULA (evita a dependência transitiva - 3FN, Etapa 4, seção 4.1).
-- Segurança: expõe apenas dados acadêmicos; CPF, e-mail, data de
-- nascimento e endereço do aluno ficam ocultos.
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW VW_SITUACAO_ACADEMICA AS
SELECT m.id_aluno,
       a.matricula,
       p.nome            AS nome_aluno,
       c.id_curso,
       c.nome            AS curso,
       m.id_turma,
       t.semestre,
       d.id_disciplina,
       d.codigo          AS codigo_disciplina,
       d.nome            AS disciplina,
       d.id_departamento,
       m.nota_final,
       m.frequencia,
       m.status_matricula,
       CASE
           WHEN m.status_matricula = 'TRANCADA'             THEN 'TRANCADO'
           WHEN m.nota_final IS NULL OR m.frequencia IS NULL THEN 'CURSANDO'
           WHEN m.frequencia < 75                           THEN 'REPROVADO_FALTA'
           WHEN m.nota_final >= 6                           THEN 'APROVADO'
           ELSE                                                  'REPROVADO_NOTA'
       END               AS situacao_final_calculada
  FROM MATRICULA  m
  JOIN ALUNO      a ON a.id_pessoa     = m.id_aluno
  JOIN PESSOA     p ON p.id_pessoa     = a.id_pessoa
  JOIN CURSO      c ON c.id_curso      = a.id_curso
  JOIN TURMA      t ON t.id_turma      = m.id_turma
  JOIN DISCIPLINA d ON d.id_disciplina = t.id_disciplina
WITH READ ONLY;

-- ---------------------------------------------------------------------
-- 1.2 VW_MATRICULAS_ATIVAS (proteção de escrita, WITH CHECK OPTION)
-- Permite INSERT/UPDATE pela view, mas só se a linha continuar visível
-- nela: nenhuma operação feita pela view pode deixar a matrícula fora
-- do estado 'ATIVA' (ex.: trancar por aqui gera ORA-01402).
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW VW_MATRICULAS_ATIVAS AS
SELECT id_aluno,
       id_turma,
       data_matricula,
       nota_final,
       frequencia,
       status_matricula
  FROM MATRICULA
 WHERE status_matricula = 'ATIVA'
WITH CHECK OPTION CONSTRAINT CK_VW_MATRICULA_ATIVA;

-- ---------------------------------------------------------------------
-- 1.3 VW_ACERVO_PENDENCIAS (gerencial da biblioteca, somente leitura)
-- Lista empréstimos não devolvidos ou com multa pendente, com os dias de
-- atraso correntes e se o usuário está bloqueado para novos empréstimos
-- (RN13, RN14).
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW VW_ACERVO_PENDENCIAS AS
SELECT e.id_emprestimo,
       p.id_pessoa,
       p.nome                                       AS usuario,
       CASE p.tipo_pessoa WHEN 'A' THEN 'ALUNO'
                          ELSE 'PROFESSOR' END       AS perfil,
       o.id_obra,
       o.titulo,
       e.numero_exemplar,
       e.data_emprestimo,
       e.data_prevista_devolucao,
       e.data_devolucao,
       CASE
           WHEN e.data_devolucao IS NULL
           THEN GREATEST(TRUNC(SYSDATE) - TRUNC(e.data_prevista_devolucao), 0)
           ELSE 0
       END                                          AS dias_atraso_corrente,
       mu.valor                                     AS multa_pendente,
       CASE
           WHEN mu.id_multa IS NOT NULL                       THEN 'MULTA PENDENTE'
           WHEN TRUNC(SYSDATE) > e.data_prevista_devolucao    THEN 'EM ATRASO'
           ELSE                                                    'NO PRAZO'
       END                                          AS situacao,
       CASE
           WHEN EXISTS (SELECT 1
                          FROM MULTA m2
                          JOIN EMPRESTIMO e2 ON e2.id_emprestimo = m2.id_emprestimo
                         WHERE e2.id_pessoa = e.id_pessoa
                           AND m2.data_pagamento IS NULL)
           THEN 'SIM' ELSE 'NAO'
       END                                          AS usuario_bloqueado
  FROM EMPRESTIMO e
  JOIN PESSOA     p ON p.id_pessoa = e.id_pessoa
  JOIN OBRA       o ON o.id_obra   = e.id_obra
  LEFT JOIN MULTA mu ON mu.id_emprestimo  = e.id_emprestimo
                    AND mu.data_pagamento IS NULL
 WHERE e.data_devolucao IS NULL
    OR mu.id_multa IS NOT NULL
WITH READ ONLY;

/* =====================================================================
   2. GATILHOS
   ===================================================================== */

-- ---------------------------------------------------------------------
-- 2.1 TRG_VALIDA_MATRICULA  (RN04 vagas, RN05 pré-requisitos)
-- Dispara quando uma matrícula passa a ser ATIVA: INSERT, reativação de
-- TRANCADA para ATIVA, ou troca de aluno/turma.
--  BEFORE EACH ROW : trava a linha da TURMA (SELECT ... FOR UPDATE).
--                    Duas sessões disputando a mesma turma são
--                    serializadas aqui: a segunda espera o COMMIT ou
--                    ROLLBACK da primeira (cenário do script 05).
--  AFTER STATEMENT : conta as matrículas ativas e checa os pré-requisitos
--                    na VW_SITUACAO_ACADEMICA (situação APROVADO).
-- ---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_VALIDA_MATRICULA
FOR INSERT OR UPDATE OF status_matricula, id_turma, id_aluno ON MATRICULA
COMPOUND TRIGGER

    TYPE t_matricula IS RECORD (
        id_aluno  MATRICULA.id_aluno%TYPE,
        id_turma  MATRICULA.id_turma%TYPE
    );
    TYPE t_lista IS TABLE OF t_matricula INDEX BY PLS_INTEGER;
    g_lista t_lista;

    BEFORE STATEMENT IS
    BEGIN
        g_lista.DELETE;
    END BEFORE STATEMENT;

    BEFORE EACH ROW IS
        v_vagas  TURMA.vagas_total%TYPE;
        v_idx    PLS_INTEGER;
    BEGIN
        IF :NEW.status_matricula = 'ATIVA'
           AND (   INSERTING
                OR :OLD.status_matricula <> 'ATIVA'
                OR :OLD.id_turma <> :NEW.id_turma
                OR :OLD.id_aluno <> :NEW.id_aluno)
        THEN
            BEGIN
                -- Bloqueio de linha: serializa matrículas concorrentes na mesma turma
                SELECT vagas_total
                  INTO v_vagas
                  FROM TURMA
                 WHERE id_turma = :NEW.id_turma
                   FOR UPDATE;

                v_idx := g_lista.COUNT + 1;
                g_lista(v_idx).id_aluno := :NEW.id_aluno;
                g_lista(v_idx).id_turma := :NEW.id_turma;
            EXCEPTION
                WHEN NO_DATA_FOUND THEN
                    NULL;  -- turma inexistente: a FK_MATRICULA_TURMA rejeita a linha
            END;
        END IF;
    END BEFORE EACH ROW;

    AFTER STATEMENT IS
        v_aluno       MATRICULA.id_aluno%TYPE;
        v_turma       MATRICULA.id_turma%TYPE;
        v_vagas       TURMA.vagas_total%TYPE;
        v_disciplina  TURMA.id_disciplina%TYPE;
        v_ativas      NUMBER;
        v_pendentes   VARCHAR2(4000);
    BEGIN
        FOR i IN 1 .. g_lista.COUNT LOOP
            v_aluno := g_lista(i).id_aluno;
            v_turma := g_lista(i).id_turma;

            SELECT vagas_total, id_disciplina
              INTO v_vagas, v_disciplina
              FROM TURMA
             WHERE id_turma = v_turma;

            -- RN04: matrículas ativas não podem exceder as vagas
            SELECT COUNT(*)
              INTO v_ativas
              FROM MATRICULA
             WHERE id_turma = v_turma
               AND status_matricula = 'ATIVA';

            IF v_ativas > v_vagas THEN
                RAISE_APPLICATION_ERROR(-20001,
                    'RN04 violada: turma ' || v_turma || ' sem vagas (' ||
                    v_ativas || ' matrículas ativas para ' || v_vagas || ' vagas).');
            END IF;

            -- RN05: todo pré-requisito precisa estar APROVADO (RN08 via view)
            SELECT LISTAGG(d.codigo, ', ') WITHIN GROUP (ORDER BY d.codigo)
              INTO v_pendentes
              FROM PRE_REQUISITO pr
              JOIN DISCIPLINA d ON d.id_disciplina = pr.id_disciplina_req
             WHERE pr.id_disciplina = v_disciplina
               AND NOT EXISTS (SELECT 1
                                 FROM VW_SITUACAO_ACADEMICA s
                                WHERE s.id_aluno = v_aluno
                                  AND s.id_disciplina = pr.id_disciplina_req
                                  AND s.situacao_final_calculada = 'APROVADO');

            IF v_pendentes IS NOT NULL THEN
                RAISE_APPLICATION_ERROR(-20002,
                    'RN05 violada: aluno ' || v_aluno ||
                    ' não foi aprovado no(s) pré-requisito(s): ' || v_pendentes || '.');
            END IF;
        END LOOP;

        g_lista.DELETE;
    END AFTER STATEMENT;

END TRG_VALIDA_MATRICULA;
/

-- ---------------------------------------------------------------------
-- 2.2 TRG_VALIDA_EMPRESTIMO  (RN10, RN11, RN12, RN14)
--  BEFORE EACH ROW : trava a PESSOA e o EXEMPLAR (FOR UPDATE), serializando
--                    empréstimos concorrentes do mesmo usuário ou exemplar,
--                    e calcula o prazo SEMPRE pela regra (RN12):
--                    aluno +7 dias, professor +15 dias.
--  AFTER STATEMENT : multa pendente (RN14), exemplar já emprestado (RN10)
--                    e limite de empréstimos simultâneos (RN11: 3 / 5).
--                    A checagem de multa fica aqui, e não no BEFORE ROW,
--                    porque precisa ler EMPRESTIMO (tabela mutante).
-- ---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_VALIDA_EMPRESTIMO
FOR INSERT ON EMPRESTIMO
COMPOUND TRIGGER

    TYPE t_emprestimo IS RECORD (
        id_pessoa        EMPRESTIMO.id_pessoa%TYPE,
        id_obra          EMPRESTIMO.id_obra%TYPE,
        numero_exemplar  EMPRESTIMO.numero_exemplar%TYPE,
        tipo_pessoa      PESSOA.tipo_pessoa%TYPE
    );
    TYPE t_lista IS TABLE OF t_emprestimo INDEX BY PLS_INTEGER;
    g_lista t_lista;

    BEFORE STATEMENT IS
    BEGIN
        g_lista.DELETE;
    END BEFORE STATEMENT;

    BEFORE EACH ROW IS
        v_tipo     PESSOA.tipo_pessoa%TYPE;
        v_dummy    NUMBER;
        v_idx      PLS_INTEGER;
        v_existem  BOOLEAN := TRUE;
    BEGIN
        BEGIN
            SELECT tipo_pessoa
              INTO v_tipo
              FROM PESSOA
             WHERE id_pessoa = :NEW.id_pessoa
               FOR UPDATE;

            SELECT 1
              INTO v_dummy
              FROM EXEMPLAR
             WHERE id_obra = :NEW.id_obra
               AND numero_exemplar = :NEW.numero_exemplar
               FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                v_existem := FALSE;  -- pessoa ou exemplar inexistente: as FKs rejeitam a linha
        END;

        IF v_existem THEN
            -- RN12: o prazo é sempre derivado do perfil, nunca informado à mão
            :NEW.data_emprestimo := NVL(:NEW.data_emprestimo, SYSDATE);
            :NEW.data_prevista_devolucao :=
                TRUNC(:NEW.data_emprestimo) + CASE v_tipo WHEN 'P' THEN 15 ELSE 7 END;

            v_idx := g_lista.COUNT + 1;
            g_lista(v_idx).id_pessoa       := :NEW.id_pessoa;
            g_lista(v_idx).id_obra         := :NEW.id_obra;
            g_lista(v_idx).numero_exemplar := :NEW.numero_exemplar;
            g_lista(v_idx).tipo_pessoa     := v_tipo;
        END IF;
    END BEFORE EACH ROW;

    AFTER STATEMENT IS
        v_pessoa    EMPRESTIMO.id_pessoa%TYPE;
        v_obra      EMPRESTIMO.id_obra%TYPE;
        v_exemplar  EMPRESTIMO.numero_exemplar%TYPE;
        v_tipo      PESSOA.tipo_pessoa%TYPE;
        v_qtd       NUMBER;
        v_limite    NUMBER;
    BEGIN
        FOR i IN 1 .. g_lista.COUNT LOOP
            v_pessoa   := g_lista(i).id_pessoa;
            v_obra     := g_lista(i).id_obra;
            v_exemplar := g_lista(i).numero_exemplar;
            v_tipo     := g_lista(i).tipo_pessoa;

            -- RN14: usuário com multa pendente não pode pegar livro
            SELECT COUNT(*)
              INTO v_qtd
              FROM MULTA mu
              JOIN EMPRESTIMO e ON e.id_emprestimo = mu.id_emprestimo
             WHERE e.id_pessoa = v_pessoa
               AND mu.data_pagamento IS NULL;

            IF v_qtd > 0 THEN
                RAISE_APPLICATION_ERROR(-20003,
                    'RN14 violada: usuário ' || v_pessoa ||
                    ' possui ' || v_qtd || ' multa(s) pendente(s).');
            END IF;

            -- RN10: um exemplar só pode ter um empréstimo em aberto
            SELECT COUNT(*)
              INTO v_qtd
              FROM EMPRESTIMO
             WHERE id_obra = v_obra
               AND numero_exemplar = v_exemplar
               AND data_devolucao IS NULL;

            IF v_qtd > 1 THEN
                RAISE_APPLICATION_ERROR(-20004,
                    'RN10 violada: exemplar ' || v_exemplar || ' da obra ' ||
                    v_obra || ' já está emprestado.');
            END IF;

            -- RN11: limite de empréstimos simultâneos (aluno 3, professor 5)
            v_limite := CASE v_tipo WHEN 'P' THEN 5 ELSE 3 END;

            SELECT COUNT(*)
              INTO v_qtd
              FROM EMPRESTIMO
             WHERE id_pessoa = v_pessoa
               AND data_devolucao IS NULL;

            IF v_qtd > v_limite THEN
                RAISE_APPLICATION_ERROR(-20005,
                    'RN11 violada: usuário ' || v_pessoa || ' atingiu o limite de ' ||
                    v_limite || ' empréstimos simultâneos.');
            END IF;
        END LOOP;

        g_lista.DELETE;
    END AFTER STATEMENT;

END TRG_VALIDA_EMPRESTIMO;
/

-- ---------------------------------------------------------------------
-- 2.3 TRG_GERA_MULTA_DEVOLUCAO  (RN13)
-- Ao registrar a devolução (data_devolucao passa de NULL para uma data),
-- gera automaticamente a multa de R$ 1,00 por dia de atraso.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_GERA_MULTA_DEVOLUCAO
AFTER UPDATE OF data_devolucao ON EMPRESTIMO
FOR EACH ROW
WHEN (OLD.data_devolucao IS NULL AND NEW.data_devolucao IS NOT NULL)
DECLARE
    v_dias NUMBER;
BEGIN
    v_dias := TRUNC(:NEW.data_devolucao) - TRUNC(:NEW.data_prevista_devolucao);

    IF v_dias > 0 THEN
        INSERT INTO MULTA (id_multa, id_emprestimo, valor, data_geracao, data_pagamento)
        VALUES (SEQ_MULTA.NEXTVAL, :NEW.id_emprestimo, v_dias * 1.00,
                TRUNC(:NEW.data_devolucao), NULL);
    END IF;
END TRG_GERA_MULTA_DEVOLUCAO;
/

-- ---------------------------------------------------------------------
-- 2.4 TRG_AUDITORIA_NOTA  (RN16, RF10)
-- Registra toda alteração de nota_final, inclusive o primeiro lançamento
-- (NULL -> valor) e a remoção (valor -> NULL).
-- ---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_AUDITORIA_NOTA
AFTER UPDATE OF nota_final ON MATRICULA
FOR EACH ROW
WHEN (NVL(OLD.nota_final, -1) <> NVL(NEW.nota_final, -1))
BEGIN
    INSERT INTO AUDITORIA_NOTA (id_auditoria, id_aluno, id_turma,
                                nota_anterior, nota_nova, data_alteracao, usuario)
    VALUES (SEQ_AUDITORIA_NOTA.NEXTVAL, :NEW.id_aluno, :NEW.id_turma,
            :OLD.nota_final, :NEW.nota_final, SYSDATE, USER);
END TRG_AUDITORIA_NOTA;
/

/* =====================================================================
   3. VERIFICAÇÃO DOS OBJETOS (todos devem estar VALID)
   ===================================================================== */
SELECT object_type, object_name, status
  FROM user_objects
 WHERE object_type IN ('VIEW', 'TRIGGER')
 ORDER BY object_type, object_name;

/* =====================================================================
   4. TESTES DOS TRIGGERS E DAS VIEWS
   Cada teste roda dentro de um SAVEPOINT e é desfeito no final:
   a base continua exatamente como o script 02 deixou.
   Habilite a saída: Exibir > Saída DBMS.
   ===================================================================== */
DECLARE
    v_num   NUMBER;
    v_data  DATE;
    v_txt   VARCHAR2(200);

    -- Executa um comando que DEVE ser rejeitado e mostra o erro obtido
    PROCEDURE esperar_erro(p_descricao IN VARCHAR2, p_comando IN VARCHAR2) IS
    BEGIN
        SAVEPOINT sp_erro;
        EXECUTE IMMEDIATE p_comando;
        DBMS_OUTPUT.PUT_LINE('[FALHOU] ' || p_descricao || ' -> o comando foi aceito');
        ROLLBACK TO SAVEPOINT sp_erro;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('[OK] ' || p_descricao);
            DBMS_OUTPUT.PUT_LINE('     ' || SQLERRM);
            ROLLBACK TO SAVEPOINT sp_erro;
    END;
BEGIN
    DBMS_OUTPUT.PUT_LINE('===== TRG_VALIDA_MATRICULA =====');

    -- T1. RN04: a turma 501 tem 1 vaga. O aluno 1009 ocupa; o 1010 é recusado.
    SAVEPOINT sp_t1;
    INSERT INTO MATRICULA (id_aluno, id_turma) VALUES (1009, 501);
    DBMS_OUTPUT.PUT_LINE('[OK] T1a. Aluno 1009 ocupou a última vaga da turma 501');
    esperar_erro('T1b. RN04 - aluno 1010 na turma 501 já lotada',
                 'INSERT INTO MATRICULA (id_aluno, id_turma) VALUES (1010, 501)');
    ROLLBACK TO SAVEPOINT sp_t1;

    -- T2. RN05: o aluno 1002 foi reprovado em Estruturas de Dados (DCC301)
    esperar_erro('T2. RN05 - aluno 1002 em Banco de Dados I sem o pré-requisito DCC301',
                 'INSERT INTO MATRICULA (id_aluno, id_turma) VALUES (1002, 501)');

    -- T3. Reativação (TRANCADA -> ATIVA) também passa pelas validações
    SAVEPOINT sp_t3;
    UPDATE MATRICULA SET status_matricula = 'ATIVA' WHERE id_aluno = 1015 AND id_turma = 512;
    DBMS_OUTPUT.PUT_LINE('[OK] T3. Matrícula TRANCADA de 1015 reativada (há vaga e não há pré-requisito)');
    ROLLBACK TO SAVEPOINT sp_t3;

    DBMS_OUTPUT.PUT_LINE(CHR(10) || '===== TRG_VALIDA_EMPRESTIMO =====');

    -- T4. RN14: a aluna 1003 (Carla) tem multa pendente
    esperar_erro('T4. RN14 - empréstimo para usuária com multa pendente',
                 'INSERT INTO EMPRESTIMO (id_emprestimo, id_pessoa, id_obra, numero_exemplar)
                  VALUES (SEQ_EMPRESTIMO.NEXTVAL, 1003, 302, 1)');

    -- T5. RN10: o exemplar 1 da obra 303 está com o aluno 1002
    esperar_erro('T5. RN10 - empréstimo de exemplar que já está emprestado',
                 'INSERT INTO EMPRESTIMO (id_emprestimo, id_pessoa, id_obra, numero_exemplar)
                  VALUES (SEQ_EMPRESTIMO.NEXTVAL, 1001, 303, 1)');

    -- T6. RN11: a aluna 1009 pega 3 livros; o 4º é recusado
    SAVEPOINT sp_t6;
    INSERT INTO EMPRESTIMO (id_emprestimo, id_pessoa, id_obra, numero_exemplar) VALUES (SEQ_EMPRESTIMO.NEXTVAL, 1009, 302, 1);
    INSERT INTO EMPRESTIMO (id_emprestimo, id_pessoa, id_obra, numero_exemplar) VALUES (SEQ_EMPRESTIMO.NEXTVAL, 1009, 304, 1);
    INSERT INTO EMPRESTIMO (id_emprestimo, id_pessoa, id_obra, numero_exemplar) VALUES (SEQ_EMPRESTIMO.NEXTVAL, 1009, 305, 1);
    DBMS_OUTPUT.PUT_LINE('[OK] T6a. Aluna 1009 pegou 3 livros (limite de aluno)');
    esperar_erro('T6b. RN11 - 4º empréstimo simultâneo de aluno',
                 'INSERT INTO EMPRESTIMO (id_emprestimo, id_pessoa, id_obra, numero_exemplar)
                  VALUES (SEQ_EMPRESTIMO.NEXTVAL, 1009, 307, 1)');
    ROLLBACK TO SAVEPOINT sp_t6;

    -- T7. RN12: o prazo informado (1 dia) é ignorado; professor recebe 15 dias
    SAVEPOINT sp_t7;
    INSERT INTO EMPRESTIMO (id_emprestimo, id_pessoa, id_obra, numero_exemplar,
                            data_emprestimo, data_prevista_devolucao)
    VALUES (SEQ_EMPRESTIMO.NEXTVAL, 2005, 311, 1, DATE '2026-11-18', DATE '2026-11-19')
    RETURNING data_prevista_devolucao INTO v_data;
    DBMS_OUTPUT.PUT_LINE('[OK] T7. RN12 - professor 2005, empréstimo em 18/11/2026: devolução prevista = '
                         || TO_CHAR(v_data, 'DD/MM/YYYY') || ' (esperado 03/12/2026)');
    ROLLBACK TO SAVEPOINT sp_t7;

    DBMS_OUTPUT.PUT_LINE(CHR(10) || '===== TRG_GERA_MULTA_DEVOLUCAO =====');

    -- T8. RN13: empréstimo 7008 vencia em 12/11/2026; devolvido em 15/11 -> R$ 3,00
    SAVEPOINT sp_t8;
    UPDATE EMPRESTIMO SET data_devolucao = DATE '2026-11-15' WHERE id_emprestimo = 7008;
    SELECT valor INTO v_num FROM MULTA WHERE id_emprestimo = 7008;
    DBMS_OUTPUT.PUT_LINE('[OK] T8. RN13 - devolução com 3 dias de atraso gerou multa de R$ '
                         || TO_CHAR(v_num, 'FM990.00'));
    ROLLBACK TO SAVEPOINT sp_t8;

    -- T9. Devolução no prazo não gera multa
    SAVEPOINT sp_t9;
    UPDATE EMPRESTIMO SET data_devolucao = DATE '2026-11-15' WHERE id_emprestimo = 7009;
    SELECT COUNT(*) INTO v_num FROM MULTA WHERE id_emprestimo = 7009;
    DBMS_OUTPUT.PUT_LINE('[OK] T9. Devolução dentro do prazo: ' || v_num || ' multa(s) gerada(s)');
    ROLLBACK TO SAVEPOINT sp_t9;

    DBMS_OUTPUT.PUT_LINE(CHR(10) || '===== TRG_AUDITORIA_NOTA =====');

    -- T10. RN16: lançar a nota de 1001 em Banco de Dados I gera log
    SAVEPOINT sp_t10;
    UPDATE MATRICULA SET nota_final = 7.5 WHERE id_aluno = 1001 AND id_turma = 501;
    SELECT NVL(TO_CHAR(nota_anterior, 'FM90.00'), 'NULL') || ' -> ' ||
           TO_CHAR(nota_nova, 'FM90.00') || ' por ' || usuario
      INTO v_txt
      FROM AUDITORIA_NOTA
     WHERE id_auditoria = (SELECT MAX(id_auditoria) FROM AUDITORIA_NOTA);
    DBMS_OUTPUT.PUT_LINE('[OK] T10. RN16 - log registrado: ' || v_txt);
    ROLLBACK TO SAVEPOINT sp_t10;

    DBMS_OUTPUT.PUT_LINE(CHR(10) || '===== VIEWS =====');

    -- T11. WITH CHECK OPTION: trancar pela view tiraria a linha da view
    esperar_erro('T11. VW_MATRICULAS_ATIVAS - trancar matrícula pela view (WITH CHECK OPTION)',
                 'UPDATE VW_MATRICULAS_ATIVAS SET status_matricula = ''TRANCADA''
                   WHERE id_aluno = 1001 AND id_turma = 501');

    -- T12. WITH CHECK OPTION permite alterações que mantêm a linha na view
    SAVEPOINT sp_t12;
    UPDATE VW_MATRICULAS_ATIVAS SET frequencia = 90 WHERE id_aluno = 1001 AND id_turma = 501;
    DBMS_OUTPUT.PUT_LINE('[OK] T12. VW_MATRICULAS_ATIVAS - lançar frequência pela view é permitido');
    ROLLBACK TO SAVEPOINT sp_t12;

    -- T13. WITH READ ONLY: nenhuma alteração pela view analítica
    esperar_erro('T13. VW_SITUACAO_ACADEMICA - alterar nota pela view (WITH READ ONLY)',
                 'UPDATE VW_SITUACAO_ACADEMICA SET nota_final = 10 WHERE id_aluno = 1001');
END;
/

/* =====================================================================
   5. CONSULTA ÀS VIEWS (amostra para a apresentação)
   ===================================================================== */
-- Situação de cada matrícula (RN08 calculada pela view)
SELECT nome_aluno, codigo_disciplina, semestre, nota_final, frequencia, situacao_final_calculada
  FROM VW_SITUACAO_ACADEMICA
 ORDER BY semestre, codigo_disciplina, nome_aluno;

-- Resumo por situação
SELECT situacao_final_calculada, COUNT(*) AS total
  FROM VW_SITUACAO_ACADEMICA
 GROUP BY situacao_final_calculada
 ORDER BY total DESC;

-- Pendências da biblioteca (dias de atraso dependem da data de execução)
SELECT id_emprestimo, usuario, perfil, titulo, data_prevista_devolucao,
       dias_atraso_corrente, multa_pendente, situacao, usuario_bloqueado
  FROM VW_ACERVO_PENDENCIAS
 ORDER BY usuario_bloqueado DESC, dias_atraso_corrente DESC;
