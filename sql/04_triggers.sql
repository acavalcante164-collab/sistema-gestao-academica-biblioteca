-- ============================================================================
-- UNIVERSIDADE FEDERAL DE RORAIMA (UFRR) - DCC 502: BANCO DE DADOS I
-- PROJETO: Sistema Integrado de Gestão Acadêmica e Biblioteca (SIGAB) - Grupo 06
-- SCRIPT: 04_triggers.sql (Referência: Issue #11 e Seção 3.6 do Edital)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- TRIGGER 1: TRG_VALIDA_MATRICULA
-- Regras Automatizadas:
--   RN04: Impede matrícula ativa em turma cuja capacidade (vagas_total) foi atingida.
--   RN05: Impede matrícula se o aluno não cumpriu todos os pré-requisitos da
--         disciplina (exige nota_final >= 6.0 e frequencia >= 75.0).
-- Concorrência:
--   Utiliza SELECT ... FOR UPDATE na linha da TURMA para serializar transações
--   concorrentes que disputem a última vaga.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_VALIDA_MATRICULA
BEFORE INSERT ON MATRICULA
FOR EACH ROW
DECLARE
    v_vagas_total       TURMA.vagas_total%TYPE;
    v_id_disciplina     TURMA.id_disciplina%TYPE;
    v_vagas_ocupadas    NUMBER;
    v_prereq_pendentes  NUMBER;
BEGIN
    -- 1. Bloqueia a linha da turma (evita condição de corrida em matrículas simultâneas)
    SELECT vagas_total, id_disciplina
      INTO v_vagas_total, v_id_disciplina
      FROM TURMA
     WHERE id_turma = :NEW.id_turma
       FOR UPDATE;

    -- 2. Verifica disponibilidade de vagas (RN04) se a matrícula for inserida como ATIVA
    IF :NEW.status_matricula = 'ATIVA' THEN
        SELECT COUNT(*)
          INTO v_vagas_ocupadas
          FROM MATRICULA
         WHERE id_turma = :NEW.id_turma
           AND status_matricula = 'ATIVA';

        IF v_vagas_ocupadas >= v_vagas_total THEN
            RAISE_APPLICATION_ERROR(
                -20001,
                'RN04 Violada: A turma ' || :NEW.id_turma ||
                ' já atingiu sua capacidade máxima (' || v_vagas_total || ' vagas).'
            );
        END IF;
    END IF;

    -- 3. Verifica cumprimento de todos os pré-requisitos da disciplina (RN05 e RN08)
    SELECT COUNT(*)
      INTO v_prereq_pendentes
      FROM PRE_REQUISITO pr
     WHERE pr.id_disciplina = v_id_disciplina
       AND NOT EXISTS (
           SELECT 1
             FROM MATRICULA m
             JOIN TURMA t ON m.id_turma = t.id_turma
            WHERE m.id_aluno = :NEW.id_aluno
              AND t.id_disciplina = pr.id_disciplina_req
              AND m.status_matricula = 'ATIVA'
              AND m.nota_final >= 6.0
              AND m.frequencia >= 75.0
       );

    IF v_prereq_pendentes > 0 THEN
        RAISE_APPLICATION_ERROR(
            -20002,
            'RN05 Violada: O aluno ' || :NEW.id_aluno ||
            ' possui ' || v_prereq_pendentes ||
            ' pré-requisito(s) não cumprido(s) para a disciplina ' || v_id_disciplina || '.'
        );
    END IF;
END;
/

-- ----------------------------------------------------------------------------
-- TRIGGER 2: TRG_VALIDA_EMPRESTIMO
-- Regras Automatizadas:
--   RN10: Um exemplar só pode ter um empréstimo em aberto por vez.
--   RN11: Limite de 3 empréstimos simultâneos para Alunos e 5 para Professores.
--   RN12: Prazo automático de 7 dias para Alunos e 15 dias para Professores.
--   RN14: Bloqueia novo empréstimo se o usuário tiver multa pendente.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_VALIDA_EMPRESTIMO
BEFORE INSERT ON EMPRESTIMO
FOR EACH ROW
DECLARE
    v_tipo_pessoa       PESSOA.tipo_pessoa%TYPE;
    v_multas_pendentes  NUMBER;
    v_exemplar_ocupado  NUMBER;
    v_emp_ativos        NUMBER;
    v_limite_emp        NUMBER;
    v_prazo_dias        NUMBER;
BEGIN
    -- 1. Obtém o tipo da pessoa ('A' = Aluno, 'P' = Professor)
    SELECT tipo_pessoa
      INTO v_tipo_pessoa
      FROM PESSOA
     WHERE id_pessoa = :NEW.id_pessoa;

    -- 2. Verifica se o usuário possui multa pendente de pagamento (RN14)
    SELECT COUNT(*)
      INTO v_multas_pendentes
      FROM MULTA mu
      JOIN EMPRESTIMO e ON mu.id_emprestimo = e.id_emprestimo
     WHERE e.id_pessoa = :NEW.id_pessoa
       AND mu.data_pagamento IS NULL;

    IF v_multas_pendentes > 0 THEN
        RAISE_APPLICATION_ERROR(
            -20003,
            'RN14 Violada: Usuário ' || :NEW.id_pessoa ||
            ' possui multa(s) pendente(s) na biblioteca e está impedido de realizar empréstimos.'
        );
    END IF;

    -- 3. Verifica se o exemplar físico já está emprestado no momento (RN10)
    SELECT COUNT(*)
      INTO v_exemplar_ocupado
      FROM EMPRESTIMO
     WHERE id_obra = :NEW.id_obra
       AND numero_exemplar = :NEW.numero_exemplar
       AND data_devolucao IS NULL;

    IF v_exemplar_ocupado > 0 THEN
        RAISE_APPLICATION_ERROR(
            -20004,
            'RN10 Violada: O exemplar ' || :NEW.numero_exemplar ||
            ' da obra ' || :NEW.id_obra || ' já possui um empréstimo em aberto.'
        );
    END IF;

    -- 4. Verifica limite de empréstimos simultâneos em aberto (RN11)
    SELECT COUNT(*)
      INTO v_emp_ativos
      FROM EMPRESTIMO
     WHERE id_pessoa = :NEW.id_pessoa
       AND data_devolucao IS NULL;

    IF v_tipo_pessoa = 'A' THEN
        v_limite_emp := 3;
        v_prazo_dias := 7;
    ELSE
        v_limite_emp := 5;
        v_prazo_dias := 15;
    END IF;

    IF v_emp_ativos >= v_limite_emp THEN
        RAISE_APPLICATION_ERROR(
            -20005,
            'RN11 Violada: Limite máximo de ' || v_limite_emp ||
            ' empréstimos simultâneos atingido para o usuário ' || :NEW.id_pessoa || '.'
        );
    END IF;

    -- 5. Aplica o prazo regulamentar caso não tenha sido definido (RN12)
    IF :NEW.data_emprestimo IS NULL THEN
        :NEW.data_emprestimo := SYSDATE;
    END IF;

    IF :NEW.data_prevista_devolucao IS NULL THEN
        :NEW.data_prevista_devolucao := TRUNC(:NEW.data_emprestimo) + v_prazo_dias;
    END IF;
END;
/

-- ----------------------------------------------------------------------------
-- TRIGGER 3: TRG_GERA_MULTA_DEVOLUCAO
-- Regra Automatizada:
--   RN13: Ao registrar a devolução (data_devolucao deixa de ser NULL), se houver
--         atraso em relação a data_prevista_devolucao, gera multa automática de
--         R$ 1,00 por dia de atraso.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_GERA_MULTA_DEVOLUCAO
AFTER UPDATE OF data_devolucao ON EMPRESTIMO
FOR EACH ROW
WHEN (OLD.data_devolucao IS NULL AND NEW.data_devolucao IS NOT NULL)
DECLARE
    v_dias_atraso   NUMBER;
    v_novo_id_multa NUMBER;
BEGIN
    v_dias_atraso := TRUNC(:NEW.data_devolucao) - TRUNC(:NEW.data_prevista_devolucao);

    IF v_dias_atraso > 0 THEN
        SELECT NVL(MAX(id_multa), 0) + 1
          INTO v_novo_id_multa
          FROM MULTA;

        INSERT INTO MULTA (
            id_multa,
            id_emprestimo,
            valor,
            data_geracao,
            data_pagamento
        ) VALUES (
            v_novo_id_multa,
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
-- Regra Automatizada:
--   RN16: Toda alteração de nota_final em MATRICULA deve ser registrada na tabela
--         AUDITORIA_NOTA com valor anterior, novo valor, data e usuário do SGBD.
-- ----------------------------------------------------------------------------
CREATE OR REPLACE TRIGGER TRG_AUDITORIA_NOTA
AFTER UPDATE OF nota_final ON MATRICULA
FOR EACH ROW
DECLARE
    v_novo_id_auditoria NUMBER;
BEGIN
    -- Dispara apenas se o valor realmente mudou (incluindo transição de/para NULL)
    IF NVL(:OLD.nota_final, -1) <> NVL(:NEW.nota_final, -1) THEN
        SELECT NVL(MAX(id_auditoria), 0) + 1
          INTO v_novo_id_auditoria
          FROM AUDITORIA_NOTA;

        INSERT INTO AUDITORIA_NOTA (
            id_auditoria,
            id_aluno,
            id_turma,
            nota_anterior,
            nota_nova,
            data_alteracao,
            usuario
        ) VALUES (
            v_novo_id_auditoria,
            :OLD.id_aluno,
            :OLD.id_turma,
            :OLD.nota_final,
            :NEW.nota_final,
            SYSDATE,
            USER
        );
    END IF;
END;
/