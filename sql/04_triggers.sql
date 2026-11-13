-- ============================================================================
-- PROJETO: Sistema Integrado de Gestão Acadêmica e Biblioteca (SIGAB)
-- SCRIPT : 04_triggers.sql
-- OBJETIVO: Implementação de Regras Ativas e Auditoria (Issue #11 / Seção 3.6)
-- ============================================================================

-- Sequências de suporte para chaves geradas por Triggers (RN13 e RN16)
CREATE SEQUENCE SEQ_AUDITORIA_NOTA START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_MULTA          START WITH 1000 INCREMENT BY 1 NOCACHE;

-- ----------------------------------------------------------------------------
-- TRIGGER 1: TRG_VALIDA_MATRICULA (COMPOUND TRIGGER)
-- Regras atendidas:
--   - RN04: Impede que matrículas ATIVAS ultrapassem vagas_total da turma,
--           tanto na inserção (INSERT) quanto na reativação (UPDATE de
--           'TRANCADA' para 'ATIVA').
--   - RN05: Valida cumprimento de todos os pré-requisitos consultando a fonte
--           única da RN08 (VW_SITUACAO_ACADEMICA = 'APROVADO').
--   - Concorrência e Mutating Table: Faz SELECT ... FOR UPDATE na linha de
--           TURMA no BEFORE EACH ROW e valida a contagem total no AFTER
--           STATEMENT, evitando ORA-04091 em UPDATE e INSERT multi-linhas.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_VALIDA_MATRICULA
FOR INSERT OR UPDATE OF status_matricula, id_turma, id_aluno ON MATRICULA
COMPOUND TRIGGER

    TYPE t_par_matricula IS RECORD (
        id_aluno        MATRICULA.id_aluno%TYPE,
        id_turma        MATRICULA.id_turma%TYPE,
        id_disciplina   TURMA.id_disciplina%TYPE,
        vagas_total     TURMA.vagas_total%TYPE
    );
    TYPE t_lista_matriculas IS TABLE OF t_par_matricula INDEX BY PLS_INTEGER;
    g_matriculas t_lista_matriculas;
    g_idx        PLS_INTEGER := 0;

    BEFORE EACH ROW IS
        v_vagas_total   TURMA.vagas_total%TYPE;
        v_id_disciplina TURMA.id_disciplina%TYPE;
    BEGIN
        -- Só valida vagas e pré-requisitos se o estado resultante for 'ATIVA'
        IF :NEW.status_matricula = 'ATIVA' AND
           (INSERTING OR NVL(:OLD.status_matricula, 'TRANCADA') <> 'ATIVA' OR :OLD.id_turma <> :NEW.id_turma) THEN

            -- Bloqueio pessimista (Row-Level Lock) na linha de TURMA para serializar concorrentes
            SELECT vagas_total, id_disciplina
              INTO v_vagas_total, v_id_disciplina
              FROM TURMA
             WHERE id_turma = :NEW.id_turma
               FOR UPDATE;

            g_idx := g_idx + 1;
            g_matriculas(g_idx).id_aluno      := :NEW.id_aluno;
            g_matriculas(g_idx).id_turma      := :NEW.id_turma;
            g_matriculas(g_idx).id_disciplina := v_id_disciplina;
            g_matriculas(g_idx).vagas_total   := v_vagas_total;
        END IF;
    END BEFORE EACH ROW;

    AFTER STATEMENT IS
        v_matriculas_ativas NUMBER;
        v_prereq_pendentes  NUMBER;
    BEGIN
        FOR i IN 1 .. g_idx LOOP
            -- 1. Validação de Capacidade da Turma (RN04) após efetivação na tabela
            SELECT COUNT(*)
              INTO v_matriculas_ativas
              FROM MATRICULA
             WHERE id_turma = g_matriculas(i).id_turma
               AND status_matricula = 'ATIVA';

            IF v_matriculas_ativas > g_matriculas(i).vagas_total THEN
                RAISE_APPLICATION_ERROR(-20001,
                    'RN04 Violada: A turma ' || g_matriculas(i).id_turma ||
                    ' já atingiu sua capacidade máxima de ' || g_matriculas(i).vagas_total || ' vagas.');
            END IF;

            -- 2. Validação de Pré-requisitos (RN05) usando a fonte única VW_SITUACAO_ACADEMICA (RN08)
            SELECT COUNT(*)
              INTO v_prereq_pendentes
              FROM PRE_REQUISITO pr
             WHERE pr.id_disciplina = g_matriculas(i).id_disciplina
               AND NOT EXISTS (
                   SELECT 1
                     FROM VW_SITUACAO_ACADEMICA vw
                    WHERE vw.id_aluno = g_matriculas(i).id_aluno
                      AND vw.id_disciplina = pr.id_disciplina_req
                      AND vw.situacao_final_calculada = 'APROVADO'
               );

            IF v_prereq_pendentes > 0 THEN
                RAISE_APPLICATION_ERROR(-20002,
                    'RN05 Violada: O aluno ' || g_matriculas(i).id_aluno ||
                    ' possui ' || v_prereq_pendentes || ' pré-requisito(s) não cumprido(s) para esta disciplina.');
            END IF;
        END LOOP;
    END AFTER STATEMENT;

END TRG_VALIDA_MATRICULA;
/

-- ----------------------------------------------------------------------------
-- TRIGGER 2: TRG_VALIDA_EMPRESTIMO (COMPOUND TRIGGER)
-- Regras atendidas:
--   - RN14: Bloqueia empréstimo se o usuário possuir multa pendente.
--   - RN10: Impede dois empréstimos simultâneos em aberto para o mesmo exemplar.
--   - RN11: Respeita o limite de empréstimos em aberto (3 p/ Aluno, 5 p/ Professor).
--   - RN12: Calcula e sobrescreve SEMPRE data_prevista_devolucao (+7 dias Aluno,
--           +15 dias Professor), garantindo determinância e conformidade FNBC.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_VALIDA_EMPRESTIMO
FOR INSERT ON EMPRESTIMO
COMPOUND TRIGGER

    TYPE t_reg_emp IS RECORD (
        id_pessoa       EMPRESTIMO.id_pessoa%TYPE,
        tipo_pessoa     PESSOA.tipo_pessoa%TYPE,
        limite_max      NUMBER,
        id_obra         EMPRESTIMO.id_obra%TYPE,
        numero_exemplar EMPRESTIMO.numero_exemplar%TYPE
    );
    TYPE t_lista_emp IS TABLE OF t_reg_emp INDEX BY PLS_INTEGER;
    g_emps t_lista_emp;
    g_idx  PLS_INTEGER := 0;

    BEFORE EACH ROW IS
        v_tipo_pessoa     PESSOA.tipo_pessoa%TYPE;
        v_prazo_dias      NUMBER;
        v_limite_max      NUMBER;
        v_multas_abertas  NUMBER;
        v_dummy_lock      EXEMPLAR.numero_exemplar%TYPE;
    BEGIN
        -- Serializa o acesso ao exemplar físico
        SELECT numero_exemplar
          INTO v_dummy_lock
          FROM EXEMPLAR
         WHERE id_obra = :NEW.id_obra
           AND numero_exemplar = :NEW.numero_exemplar
           FOR UPDATE;

        -- Identifica o tipo de usuário e fixa parâmetros das regras RN11 e RN12
        SELECT tipo_pessoa
          INTO v_tipo_pessoa
          FROM PESSOA
         WHERE id_pessoa = :NEW.id_pessoa;

        IF v_tipo_pessoa = 'A' THEN
            v_limite_max := 3;
            v_prazo_dias := 7;
        ELSE
            v_limite_max := 5;
            v_prazo_dias := 15;
        END IF;

        -- 1. Verifica inadimplência de multas (RN14)
        SELECT COUNT(*)
          INTO v_multas_abertas
          FROM MULTA mu
          INNER JOIN EMPRESTIMO e ON e.id_emprestimo = mu.id_emprestimo
         WHERE e.id_pessoa = :NEW.id_pessoa
           AND mu.data_pagamento IS NULL;

        IF v_multas_abertas > 0 THEN
            RAISE_APPLICATION_ERROR(-20003,
                'RN14 Violada: Usuário ' || :NEW.id_pessoa ||
                ' possui multa(s) pendente(s) e está impedido de realizar novos empréstimos.');
        END IF;

        -- 2. Padroniza data_emprestimo e sobrescreve SEMPRE data_prevista_devolucao (RN12 / FNBC)
        IF :NEW.data_emprestimo IS NULL THEN
            :NEW.data_emprestimo := SYSDATE;
        END IF;
        :NEW.data_prevista_devolucao := TRUNC(:NEW.data_emprestimo) + v_prazo_dias;

        -- Se o empréstimo está sendo inserido em aberto, agenda validação pós-statement (RN10 e RN11)
        IF :NEW.data_devolucao IS NULL THEN
            g_idx := g_idx + 1;
            g_emps(g_idx).id_pessoa       := :NEW.id_pessoa;
            g_emps(g_idx).tipo_pessoa     := v_tipo_pessoa;
            g_emps(g_idx).limite_max      := v_limite_max;
            g_emps(g_idx).id_obra         := :NEW.id_obra;
            g_emps(g_idx).numero_exemplar := :NEW.numero_exemplar;
        END IF;
    END BEFORE EACH ROW;

    AFTER STATEMENT IS
        v_exemplar_aberto NUMBER;
        v_emp_ativos      NUMBER;
    BEGIN
        FOR i IN 1 .. g_idx LOOP
            -- 3. Verifica unicidade de empréstimo aberto para o exemplar (RN10)
            SELECT COUNT(*)
              INTO v_exemplar_aberto
              FROM EMPRESTIMO
             WHERE id_obra = g_emps(i).id_obra
               AND numero_exemplar = g_emps(i).numero_exemplar
               AND data_devolucao IS NULL;

            IF v_exemplar_aberto > 1 THEN
                RAISE_APPLICATION_ERROR(-20004,
                    'RN10 Violada: O exemplar ' || g_emps(i).numero_exemplar ||
                    ' da obra ' || g_emps(i).id_obra || ' já se encontra emprestado.');
            END IF;

            -- 4. Verifica limite simultâneo por usuário (RN11)
            SELECT COUNT(*)
              INTO v_emp_ativos
              FROM EMPRESTIMO
             WHERE id_pessoa = g_emps(i).id_pessoa
               AND data_devolucao IS NULL;

            IF v_emp_ativos > g_emps(i).limite_max THEN
                RAISE_APPLICATION_ERROR(-20005,
                    'RN11 Violada: Limite máximo de ' || g_emps(i).limite_max ||
                    ' empréstimos simultâneos excedido para o usuário ' || g_emps(i).id_pessoa || '.');
            END IF;
        END LOOP;
    END AFTER STATEMENT;

END TRG_VALIDA_EMPRESTIMO;
/

-- ----------------------------------------------------------------------------
-- TRIGGER 3: TRG_GERA_MULTA_DEVOLUCAO
-- Regra atendida:
--   - RN13: Gera multa automática de R$ 1,00 por dia de atraso quando a
--           devolução é registrada após a data_prevista_devolucao.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_GERA_MULTA_DEVOLUCAO
AFTER UPDATE OF data_devolucao ON EMPRESTIMO
FOR EACH ROW
WHEN (OLD.data_devolucao IS NULL AND NEW.data_devolucao IS NOT NULL)
DECLARE
    v_dias_atraso NUMBER;
BEGIN
    v_dias_atraso := TRUNC(:NEW.data_devolucao) - TRUNC(:NEW.data_prevista_devolucao);

    IF v_dias_atraso > 0 THEN
        INSERT INTO MULTA (
            id_multa,
            id_emprestimo,
            valor,
            data_geracao,
            data_pagamento
        ) VALUES (
            SEQ_MULTA.NEXTVAL,
            :NEW.id_emprestimo,
            v_dias_atraso * 1.00,
            SYSDATE,
            NULL
        );
    END IF;
END;
/

-- ----------------------------------------------------------------------------
-- TRIGGER 4: TRG_AUDITORIA_NOTA
-- Regra atendida:
--   - RN16 / RF10: Registra automaticamente na tabela AUDITORIA_NOTA toda
--                  alteração de nota_final em MATRICULA.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_AUDITORIA_NOTA
AFTER UPDATE OF nota_final ON MATRICULA
FOR EACH ROW
WHEN (NVL(OLD.nota_final, -1) <> NVL(NEW.nota_final, -1))
BEGIN
    INSERT INTO AUDITORIA_NOTA (
        id_auditoria,
        id_aluno,
        id_turma,
        nota_anterior,
        nota_nova,
        data_alteracao,
        usuario
    ) VALUES (
        SEQ_AUDITORIA_NOTA.NEXTVAL,
        :NEW.id_aluno,
        :NEW.id_turma,
        :OLD.nota_final,
        :NEW.nota_final,
        SYSDATE,
        USER
    );
END;
/