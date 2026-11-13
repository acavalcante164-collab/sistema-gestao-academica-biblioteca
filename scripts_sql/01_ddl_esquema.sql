/*
   SIGAB - Sistema Integrado de Gestão Acadêmica e Biblioteca
   DCC 502 - Banco de Dados I (UFRR) - Grupo 06
   Script 01: DDL do esquema (tabelas, restrições, sequências e índices)
   SGBD: Oracle Database (testado para 11g+ / 19c / 21c XE)

   Ordem de execução: 01 -> 02 -> 03 -> 04 -> 05
   Reexecutável: o bloco inicial remove os objetos existentes antes de
   recriá-los (RNF04).

   Convenções (RNF02 / RNF06):
     PK_<TABELA>               chave primária
     FK_<ORIGEM>_<DESTINO>     chave estrangeira
     UQ_<TABELA>_<COLUNA>      unicidade / chave candidata
     CK_<TABELA>_<REGRA>       regra de domínio / negócio
     NN_<TABELA>_<COLUNA>      NOT NULL nomeado
     SEQ_<TABELA>              sequência geradora de chave
     IDX_<TABELA>_<COLUNAS>    índice de apoio
*/

SET DEFINE OFF;
SET SERVEROUTPUT ON;

/* ---------------------------------------------------------------------
   0. LIMPEZA (torna o script reexecutável)
   CASCADE CONSTRAINTS remove as FKs dependentes; os triggers são
   removidos junto com as tabelas e as views são recriadas no script 03.
   --------------------------------------------------------------------- */
BEGIN
    FOR t IN (
        SELECT table_name FROM user_tables
         WHERE table_name IN (
               'MULTA','RESERVA','EMPRESTIMO','EXEMPLAR','AUTORIA','AUTOR',
               'OBRA','AUDITORIA_NOTA','MATRICULA','TURMA','PROFESSOR',
               'ALUNO','TELEFONE_PESSOA','PESSOA','PRE_REQUISITO',
               'DISCIPLINA','CURSO','DEPARTAMENTO')
    ) LOOP
        EXECUTE IMMEDIATE 'DROP TABLE ' || t.table_name || ' CASCADE CONSTRAINTS PURGE';
    END LOOP;

    FOR s IN (
        SELECT sequence_name FROM user_sequences
         WHERE sequence_name IN (
               'SEQ_DEPARTAMENTO','SEQ_CURSO','SEQ_DISCIPLINA','SEQ_PESSOA',
               'SEQ_TURMA','SEQ_AUDITORIA_NOTA','SEQ_OBRA','SEQ_AUTOR',
               'SEQ_EMPRESTIMO','SEQ_RESERVA','SEQ_MULTA')
    ) LOOP
        EXECUTE IMMEDIATE 'DROP SEQUENCE ' || s.sequence_name;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('Limpeza concluída.');
END;
/

/* =====================================================================
   1. MÓDULO ACADÊMICO
   ===================================================================== */

-- 1. DEPARTAMENTO: unidades que ofertam cursos/disciplinas e lotam professores (R1, R2, R16)
CREATE TABLE DEPARTAMENTO (
    id_departamento  NUMBER(10),
    nome             VARCHAR2(100) CONSTRAINT NN_DEPARTAMENTO_NOME  NOT NULL,
    sigla            VARCHAR2(10)  CONSTRAINT NN_DEPARTAMENTO_SIGLA NOT NULL,
    CONSTRAINT PK_DEPARTAMENTO       PRIMARY KEY (id_departamento),
    CONSTRAINT UQ_DEPARTAMENTO_NOME  UNIQUE (nome),
    CONSTRAINT UQ_DEPARTAMENTO_SIGLA UNIQUE (sigla)
);

-- 2. CURSO: cursos de graduação (R1, RN02)
CREATE TABLE CURSO (
    id_curso         NUMBER(10),
    nome             VARCHAR2(100) CONSTRAINT NN_CURSO_NOME  NOT NULL,
    carga_horaria    NUMBER(5)     CONSTRAINT NN_CURSO_CH    NOT NULL,
    id_departamento  NUMBER(10)    CONSTRAINT NN_CURSO_DEPTO NOT NULL,
    CONSTRAINT PK_CURSO              PRIMARY KEY (id_curso),
    CONSTRAINT UQ_CURSO_NOME         UNIQUE (nome),
    CONSTRAINT CK_CURSO_CH           CHECK (carga_horaria > 0),
    CONSTRAINT FK_CURSO_DEPARTAMENTO FOREIGN KEY (id_departamento)
        REFERENCES DEPARTAMENTO (id_departamento)            -- padrão Oracle (restrict)
);

-- 3. DISCIPLINA: componentes curriculares ofertados pelos departamentos (R2)
CREATE TABLE DISCIPLINA (
    id_disciplina    NUMBER(10),
    codigo           VARCHAR2(10)  CONSTRAINT NN_DISCIPLINA_CODIGO NOT NULL,
    nome             VARCHAR2(100) CONSTRAINT NN_DISCIPLINA_NOME   NOT NULL,
    carga_horaria    NUMBER(4)     CONSTRAINT NN_DISCIPLINA_CH     NOT NULL,
    id_departamento  NUMBER(10)    CONSTRAINT NN_DISCIPLINA_DEPTO  NOT NULL,
    CONSTRAINT PK_DISCIPLINA              PRIMARY KEY (id_disciplina),
    CONSTRAINT UQ_DISCIPLINA_CODIGO       UNIQUE (codigo),
    CONSTRAINT CK_DISCIPLINA_CH           CHECK (carga_horaria > 0),
    CONSTRAINT FK_DISCIPLINA_DEPARTAMENTO FOREIGN KEY (id_departamento)
        REFERENCES DEPARTAMENTO (id_departamento)            -- padrão Oracle (restrict)
);

-- 4. PRE_REQUISITO: auto-relacionamento N:M de DISCIPLINA (R8, RN05)
CREATE TABLE PRE_REQUISITO (
    id_disciplina      NUMBER(10),
    id_disciplina_req  NUMBER(10),
    CONSTRAINT PK_PRE_REQUISITO       PRIMARY KEY (id_disciplina, id_disciplina_req),
    CONSTRAINT CK_PREREQ_DISTINTO     CHECK (id_disciplina <> id_disciplina_req),
    CONSTRAINT FK_PREREQ_DISCIPLINA   FOREIGN KEY (id_disciplina)
        REFERENCES DISCIPLINA (id_disciplina) ON DELETE CASCADE,
    CONSTRAINT FK_PREREQ_DISC_EXIGIDA FOREIGN KEY (id_disciplina_req)
        REFERENCES DISCIPLINA (id_disciplina) ON DELETE CASCADE
);

-- 5. PESSOA: supertipo de ALUNO e PROFESSOR (R15, RN01)
--    Endereço composto decomposto em colunas atômicas (1FN).
--    UQ_PESSOA_ID_TIPO é o alvo das FKs compostas dos subtipos (disjunção).
CREATE TABLE PESSOA (
    id_pessoa        NUMBER(10),
    cpf              CHAR(11)      CONSTRAINT NN_PESSOA_CPF    NOT NULL,
    nome             VARCHAR2(120) CONSTRAINT NN_PESSOA_NOME   NOT NULL,
    data_nascimento  DATE          CONSTRAINT NN_PESSOA_NASC   NOT NULL,
    email            VARCHAR2(100) CONSTRAINT NN_PESSOA_EMAIL  NOT NULL,
    tipo_pessoa      CHAR(1)       CONSTRAINT NN_PESSOA_TIPO   NOT NULL,
    rua              VARCHAR2(120) CONSTRAINT NN_PESSOA_RUA    NOT NULL,
    numero           VARCHAR2(15)  CONSTRAINT NN_PESSOA_NUMERO NOT NULL,
    bairro           VARCHAR2(60)  CONSTRAINT NN_PESSOA_BAIRRO NOT NULL,
    cidade           VARCHAR2(60)  CONSTRAINT NN_PESSOA_CIDADE NOT NULL,
    cep              CHAR(8)       CONSTRAINT NN_PESSOA_CEP    NOT NULL,
    CONSTRAINT PK_PESSOA         PRIMARY KEY (id_pessoa),
    CONSTRAINT UQ_PESSOA_CPF     UNIQUE (cpf),
    CONSTRAINT UQ_PESSOA_EMAIL   UNIQUE (email),
    CONSTRAINT UQ_PESSOA_ID_TIPO UNIQUE (id_pessoa, tipo_pessoa),
    CONSTRAINT CK_PESSOA_CPF     CHECK (REGEXP_LIKE(cpf, '^[0-9]{11}$')),
    CONSTRAINT CK_PESSOA_CEP     CHECK (REGEXP_LIKE(cep, '^[0-9]{8}$')),
    CONSTRAINT CK_PESSOA_TIPO    CHECK (tipo_pessoa IN ('A', 'P')),
    CONSTRAINT CK_PESSOA_EMAIL   CHECK (email LIKE '%_@_%._%')
);

-- 6. TELEFONE_PESSOA: atributo multivalorado de PESSOA (1FN, RF01)
CREATE TABLE TELEFONE_PESSOA (
    id_pessoa  NUMBER(10),
    telefone   VARCHAR2(15),
    CONSTRAINT PK_TELEFONE_PESSOA PRIMARY KEY (id_pessoa, telefone),
    CONSTRAINT CK_TELEFONE_FORMATO CHECK (REGEXP_LIKE(telefone, '^[0-9]{10,11}$')),
    CONSTRAINT FK_TELEFONE_PESSOA FOREIGN KEY (id_pessoa)
        REFERENCES PESSOA (id_pessoa) ON DELETE CASCADE
);

-- 7. ALUNO: subtipo de PESSOA vinculado a um curso (R3, RN01, RN02)
--    A FK composta (id_pessoa, tipo_pessoa) com tipo fixo 'A' impede que
--    uma pessoa do tipo 'P' seja cadastrada como aluno.
CREATE TABLE ALUNO (
    id_pessoa      NUMBER(10),
    tipo_pessoa    CHAR(1) DEFAULT 'A' CONSTRAINT NN_ALUNO_TIPO      NOT NULL,
    matricula      VARCHAR2(15)        CONSTRAINT NN_ALUNO_MATRICULA NOT NULL,
    data_ingresso  DATE                CONSTRAINT NN_ALUNO_INGRESSO  NOT NULL,
    id_curso       NUMBER(10)          CONSTRAINT NN_ALUNO_CURSO     NOT NULL,
    CONSTRAINT PK_ALUNO           PRIMARY KEY (id_pessoa),
    CONSTRAINT UQ_ALUNO_MATRICULA UNIQUE (matricula),
    CONSTRAINT CK_ALUNO_TIPO      CHECK (tipo_pessoa = 'A'),
    CONSTRAINT FK_ALUNO_PESSOA    FOREIGN KEY (id_pessoa, tipo_pessoa)
        REFERENCES PESSOA (id_pessoa, tipo_pessoa) ON DELETE CASCADE,
    CONSTRAINT FK_ALUNO_CURSO     FOREIGN KEY (id_curso)
        REFERENCES CURSO (id_curso)                          -- padrão Oracle (restrict)
);

-- 8. PROFESSOR: subtipo de PESSOA lotado em um departamento (R16, RN01, RN17)
CREATE TABLE PROFESSOR (
    id_pessoa        NUMBER(10),
    tipo_pessoa      CHAR(1) DEFAULT 'P' CONSTRAINT NN_PROFESSOR_TIPO      NOT NULL,
    titulacao        VARCHAR2(30)        CONSTRAINT NN_PROFESSOR_TITULACAO NOT NULL,
    data_admissao    DATE                CONSTRAINT NN_PROFESSOR_ADMISSAO  NOT NULL,
    id_departamento  NUMBER(10)          CONSTRAINT NN_PROFESSOR_DEPTO     NOT NULL,
    CONSTRAINT PK_PROFESSOR              PRIMARY KEY (id_pessoa),
    CONSTRAINT CK_PROFESSOR_TIPO         CHECK (tipo_pessoa = 'P'),
    CONSTRAINT CK_PROFESSOR_TITULACAO    CHECK (titulacao IN ('GRADUADO','ESPECIALISTA','MESTRE','DOUTOR')),
    CONSTRAINT FK_PROFESSOR_PESSOA       FOREIGN KEY (id_pessoa, tipo_pessoa)
        REFERENCES PESSOA (id_pessoa, tipo_pessoa) ON DELETE CASCADE,
    CONSTRAINT FK_PROFESSOR_DEPARTAMENTO FOREIGN KEY (id_departamento)
        REFERENCES DEPARTAMENTO (id_departamento)            -- padrão Oracle (restrict)
);

-- 9. TURMA: oferta semestral de uma disciplina (R4, R5, RN03, RN04)
--    Horário decomposto em dia_semana / hora_inicio / hora_fim (1FN).
--    id_professor aceita NULL com ON DELETE SET NULL (turma preservada se o docente sair).
CREATE TABLE TURMA (
    id_turma       NUMBER(10),
    id_disciplina  NUMBER(10)   CONSTRAINT NN_TURMA_DISCIPLINA NOT NULL,
    id_professor   NUMBER(10),
    semestre       VARCHAR2(6)  CONSTRAINT NN_TURMA_SEMESTRE   NOT NULL,
    vagas_total    NUMBER(3)    CONSTRAINT NN_TURMA_VAGAS      NOT NULL,
    sala           VARCHAR2(30) CONSTRAINT NN_TURMA_SALA       NOT NULL,
    dia_semana     VARCHAR2(15) CONSTRAINT NN_TURMA_DIA        NOT NULL,
    hora_inicio    CHAR(5)      CONSTRAINT NN_TURMA_HINI       NOT NULL,
    hora_fim       CHAR(5)      CONSTRAINT NN_TURMA_HFIM       NOT NULL,
    CONSTRAINT PK_TURMA            PRIMARY KEY (id_turma),
    CONSTRAINT CK_TURMA_SEMESTRE   CHECK (REGEXP_LIKE(semestre, '^[0-9]{4}\.[1-2]$')),
    CONSTRAINT CK_TURMA_VAGAS      CHECK (vagas_total > 0),
    CONSTRAINT CK_TURMA_DIA        CHECK (dia_semana IN ('SEG','TER','QUA','QUI','SEX','SAB','SEG-QUA','TER-QUI')),
    CONSTRAINT CK_TURMA_HINI       CHECK (REGEXP_LIKE(hora_inicio, '^([01][0-9]|2[0-3]):[0-5][0-9]$')),
    CONSTRAINT CK_TURMA_HFIM       CHECK (REGEXP_LIKE(hora_fim,    '^([01][0-9]|2[0-3]):[0-5][0-9]$')
                                          AND hora_fim > hora_inicio),
    CONSTRAINT FK_TURMA_DISCIPLINA FOREIGN KEY (id_disciplina)
        REFERENCES DISCIPLINA (id_disciplina),               -- padrão Oracle (restrict)
    CONSTRAINT FK_TURMA_PROFESSOR  FOREIGN KEY (id_professor)
        REFERENCES PROFESSOR (id_pessoa) ON DELETE SET NULL
);

-- 10. MATRICULA: entidade associativa ALUNO x TURMA (R6, RN04 a RN08)
--     PK composta impede matrícula duplicada (RN06).
--     Guarda só o estado do vínculo; a situação acadêmica (RN08) é derivada
--     na VW_SITUACAO_ACADEMICA (elimina a dependência transitiva - 3FN).
CREATE TABLE MATRICULA (
    id_aluno          NUMBER(10),
    id_turma          NUMBER(10),
    data_matricula    DATE         DEFAULT SYSDATE CONSTRAINT NN_MATRICULA_DATA   NOT NULL,
    nota_final        NUMBER(4,2),
    frequencia        NUMBER(5,2),
    status_matricula  VARCHAR2(10) DEFAULT 'ATIVA' CONSTRAINT NN_MATRICULA_STATUS NOT NULL,
    CONSTRAINT PK_MATRICULA        PRIMARY KEY (id_aluno, id_turma),
    CONSTRAINT CK_MATRICULA_NOTA   CHECK (nota_final BETWEEN 0 AND 10),
    CONSTRAINT CK_MATRICULA_FREQ   CHECK (frequencia BETWEEN 0 AND 100),
    CONSTRAINT CK_MATRICULA_STATUS CHECK (status_matricula IN ('ATIVA', 'TRANCADA')),
    CONSTRAINT FK_MATRICULA_ALUNO  FOREIGN KEY (id_aluno)
        REFERENCES ALUNO (id_pessoa),                        -- padrão Oracle (restrict)
    CONSTRAINT FK_MATRICULA_TURMA  FOREIGN KEY (id_turma)
        REFERENCES TURMA (id_turma)                          -- padrão Oracle (restrict)
);

-- 11. AUDITORIA_NOTA: trilha de alterações de nota, alimentada por trigger (R7, RF10, RN16)
--     Sem FK para MATRICULA, de propósito: o log sobrevive à exclusão da matrícula.
CREATE TABLE AUDITORIA_NOTA (
    id_auditoria    NUMBER(10),
    id_aluno        NUMBER(10)   CONSTRAINT NN_AUDITORIA_ALUNO   NOT NULL,
    id_turma        NUMBER(10)   CONSTRAINT NN_AUDITORIA_TURMA   NOT NULL,
    nota_anterior   NUMBER(4,2),
    nota_nova       NUMBER(4,2),
    data_alteracao  DATE         DEFAULT SYSDATE CONSTRAINT NN_AUDITORIA_DATA    NOT NULL,
    usuario         VARCHAR2(60) DEFAULT USER    CONSTRAINT NN_AUDITORIA_USUARIO NOT NULL,
    CONSTRAINT PK_AUDITORIA_NOTA PRIMARY KEY (id_auditoria)
);

/* =====================================================================
   2. MÓDULO BIBLIOTECA
   ===================================================================== */

-- 12. OBRA: títulos do acervo (RF06)
CREATE TABLE OBRA (
    id_obra         NUMBER(10),
    titulo          VARCHAR2(200) CONSTRAINT NN_OBRA_TITULO NOT NULL,
    tipo            VARCHAR2(20)  CONSTRAINT NN_OBRA_TIPO   NOT NULL,
    ano_publicacao  NUMBER(4)     CONSTRAINT NN_OBRA_ANO    NOT NULL,
    editora         VARCHAR2(100),
    CONSTRAINT PK_OBRA      PRIMARY KEY (id_obra),
    CONSTRAINT CK_OBRA_TIPO CHECK (tipo IN ('LIVRO', 'PERIODICO', 'TCC')),
    CONSTRAINT CK_OBRA_ANO  CHECK (ano_publicacao > 1500)
);

-- 13. AUTOR: autores das obras (RF06)
CREATE TABLE AUTOR (
    id_autor  NUMBER(10),
    nome      VARCHAR2(120) CONSTRAINT NN_AUTOR_NOME NOT NULL,
    CONSTRAINT PK_AUTOR PRIMARY KEY (id_autor)
);

-- 14. AUTORIA: N:M entre OBRA e AUTOR (R9)
CREATE TABLE AUTORIA (
    id_obra   NUMBER(10),
    id_autor  NUMBER(10),
    CONSTRAINT PK_AUTORIA       PRIMARY KEY (id_obra, id_autor),
    CONSTRAINT FK_AUTORIA_OBRA  FOREIGN KEY (id_obra)
        REFERENCES OBRA (id_obra) ON DELETE CASCADE,
    CONSTRAINT FK_AUTORIA_AUTOR FOREIGN KEY (id_autor)
        REFERENCES AUTOR (id_autor)                          -- padrão Oracle (restrict)
);

-- 15. EXEMPLAR: entidade fraca de OBRA; chave parcial numero_exemplar (R10, RN09)
CREATE TABLE EXEMPLAR (
    id_obra          NUMBER(10),
    numero_exemplar  NUMBER(4),
    data_aquisicao   DATE DEFAULT SYSDATE CONSTRAINT NN_EXEMPLAR_AQUISICAO NOT NULL,
    CONSTRAINT PK_EXEMPLAR      PRIMARY KEY (id_obra, numero_exemplar),
    CONSTRAINT CK_EXEMPLAR_NUM  CHECK (numero_exemplar > 0),
    CONSTRAINT FK_EXEMPLAR_OBRA FOREIGN KEY (id_obra)
        REFERENCES OBRA (id_obra) ON DELETE CASCADE
);

-- 16. EMPRESTIMO: retirada de um exemplar por uma pessoa (R11, R12, RN10 a RN12)
--     data_prevista_devolucao é calculada pelo trigger TRG_VALIDA_EMPRESTIMO (RN12).
CREATE TABLE EMPRESTIMO (
    id_emprestimo            NUMBER(10),
    id_pessoa                NUMBER(10) CONSTRAINT NN_EMPRESTIMO_PESSOA   NOT NULL,
    id_obra                  NUMBER(10) CONSTRAINT NN_EMPRESTIMO_OBRA     NOT NULL,
    numero_exemplar          NUMBER(4)  CONSTRAINT NN_EMPRESTIMO_EXEMPLAR NOT NULL,
    data_emprestimo          DATE DEFAULT SYSDATE CONSTRAINT NN_EMPRESTIMO_DATA     NOT NULL,
    data_prevista_devolucao  DATE                 CONSTRAINT NN_EMPRESTIMO_PREVISTA NOT NULL,
    data_devolucao           DATE,
    CONSTRAINT PK_EMPRESTIMO          PRIMARY KEY (id_emprestimo),
    CONSTRAINT CK_EMP_PREVISTA        CHECK (data_prevista_devolucao >= data_emprestimo),
    CONSTRAINT CK_EMP_DEVOLUCAO       CHECK (data_devolucao IS NULL OR data_devolucao >= data_emprestimo),
    CONSTRAINT FK_EMPRESTIMO_PESSOA   FOREIGN KEY (id_pessoa)
        REFERENCES PESSOA (id_pessoa),                       -- padrão Oracle (restrict)
    CONSTRAINT FK_EMPRESTIMO_EXEMPLAR FOREIGN KEY (id_obra, numero_exemplar)
        REFERENCES EXEMPLAR (id_obra, numero_exemplar)       -- padrão Oracle (restrict)
);

-- 17. RESERVA: fila de reservas PESSOA x OBRA (R14, RF08, RN15)
CREATE TABLE RESERVA (
    id_reserva    NUMBER(10),
    id_pessoa     NUMBER(10)   CONSTRAINT NN_RESERVA_PESSOA NOT NULL,
    id_obra       NUMBER(10)   CONSTRAINT NN_RESERVA_OBRA   NOT NULL,
    data_reserva  DATE         DEFAULT SYSDATE CONSTRAINT NN_RESERVA_DATA     NOT NULL,
    situacao      VARCHAR2(15) DEFAULT 'ATIVA' CONSTRAINT NN_RESERVA_SITUACAO NOT NULL,
    CONSTRAINT PK_RESERVA          PRIMARY KEY (id_reserva),
    CONSTRAINT CK_RESERVA_SITUACAO CHECK (situacao IN ('ATIVA', 'ATENDIDA', 'CANCELADA')),
    CONSTRAINT FK_RESERVA_PESSOA   FOREIGN KEY (id_pessoa)
        REFERENCES PESSOA (id_pessoa) ON DELETE CASCADE,
    CONSTRAINT FK_RESERVA_OBRA     FOREIGN KEY (id_obra)
        REFERENCES OBRA (id_obra) ON DELETE CASCADE
);

-- 18. MULTA: penalidade por atraso, no máximo uma por empréstimo (R13 1:1, RN13, RN14)
--     data_pagamento NULL = multa pendente (bloqueia novos empréstimos).
CREATE TABLE MULTA (
    id_multa        NUMBER(10),
    id_emprestimo   NUMBER(10)  CONSTRAINT NN_MULTA_EMPRESTIMO NOT NULL,
    valor           NUMBER(8,2) CONSTRAINT NN_MULTA_VALOR      NOT NULL,
    data_geracao    DATE DEFAULT SYSDATE CONSTRAINT NN_MULTA_GERACAO NOT NULL,
    data_pagamento  DATE,
    CONSTRAINT PK_MULTA            PRIMARY KEY (id_multa),
    CONSTRAINT UQ_MULTA_EMPRESTIMO UNIQUE (id_emprestimo),
    CONSTRAINT CK_MULTA_VALOR      CHECK (valor > 0),
    CONSTRAINT CK_MULTA_PAGTO      CHECK (data_pagamento IS NULL OR data_pagamento >= data_geracao),
    CONSTRAINT FK_MULTA_EMPRESTIMO FOREIGN KEY (id_emprestimo)
        REFERENCES EMPRESTIMO (id_emprestimo)                -- padrão Oracle (restrict)
);

/* =====================================================================
   3. SEQUÊNCIAS
   A carga (script 02) usa IDs fixos e baixos para facilitar a leitura
   (ex.: alunos 1001+, turmas 501+). As sequências começam em 10000 para
   que inserções feitas por triggers e testes nunca colidam com a carga.
   ===================================================================== */
CREATE SEQUENCE SEQ_DEPARTAMENTO   START WITH 10000 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_CURSO          START WITH 10000 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_DISCIPLINA     START WITH 10000 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_PESSOA         START WITH 10000 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_TURMA          START WITH 10000 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_AUDITORIA_NOTA START WITH 10000 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_OBRA           START WITH 10000 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_AUTOR          START WITH 10000 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_EMPRESTIMO     START WITH 10000 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_RESERVA        START WITH 10000 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE SEQ_MULTA          START WITH 10000 INCREMENT BY 1 NOCACHE;

/* =====================================================================
   4. ÍNDICES
   O Oracle já cria índices para PK e UNIQUE. Os índices abaixo cobrem as
   FKs (evitam bloqueio da tabela filha ao excluir/alterar o pai) e os
   filtros mais usados por triggers, views e consultas analíticas.
   ===================================================================== */
-- FKs do módulo acadêmico
CREATE INDEX IDX_CURSO_DEPTO       ON CURSO (id_departamento);
CREATE INDEX IDX_DISCIPLINA_DEPTO  ON DISCIPLINA (id_departamento);
CREATE INDEX IDX_PREREQ_REQ        ON PRE_REQUISITO (id_disciplina_req);
CREATE INDEX IDX_ALUNO_CURSO       ON ALUNO (id_curso);
CREATE INDEX IDX_PROFESSOR_DEPTO   ON PROFESSOR (id_departamento);
CREATE INDEX IDX_TURMA_DISCIPLINA  ON TURMA (id_disciplina);
CREATE INDEX IDX_TURMA_PROFESSOR   ON TURMA (id_professor);

-- Contagem de vagas ocupadas por turma (TRG_VALIDA_MATRICULA, RN04)
CREATE INDEX IDX_MATRICULA_TURMA_STATUS ON MATRICULA (id_turma, status_matricula);

-- Consulta do histórico de auditoria por matrícula
CREATE INDEX IDX_AUDITORIA_MATRICULA ON AUDITORIA_NOTA (id_aluno, id_turma);

-- FKs do módulo biblioteca
CREATE INDEX IDX_AUTORIA_AUTOR     ON AUTORIA (id_autor);
CREATE INDEX IDX_RESERVA_PESSOA    ON RESERVA (id_pessoa);

-- Empréstimos em aberto por usuário (RN11) e por exemplar (RN10)
CREATE INDEX IDX_EMPRESTIMO_PESSOA   ON EMPRESTIMO (id_pessoa, data_devolucao);
CREATE INDEX IDX_EMPRESTIMO_EXEMPLAR ON EMPRESTIMO (id_obra, numero_exemplar, data_devolucao);

-- Fila de reservas ativas por obra, em ordem de chegada (Q08)
CREATE INDEX IDX_RESERVA_OBRA ON RESERVA (id_obra, situacao, data_reserva);

/* =====================================================================
   5. COMENTÁRIOS NO DICIONÁRIO DO ORACLE (consultáveis em USER_TAB_COMMENTS)
   ===================================================================== */
COMMENT ON TABLE DEPARTAMENTO    IS 'Unidades acadêmicas que ofertam cursos e disciplinas e lotam professores.';
COMMENT ON TABLE CURSO           IS 'Cursos de graduação, cada um vinculado a um departamento.';
COMMENT ON TABLE DISCIPLINA      IS 'Disciplinas ofertadas pelos departamentos.';
COMMENT ON TABLE PRE_REQUISITO   IS 'Auto-relacionamento N:M: disciplina x disciplina exigida.';
COMMENT ON TABLE PESSOA          IS 'Supertipo de ALUNO e PROFESSOR (especialização disjunta e total).';
COMMENT ON TABLE TELEFONE_PESSOA IS 'Atributo multivalorado telefone de PESSOA.';
COMMENT ON TABLE ALUNO           IS 'Subtipo de PESSOA vinculado a um curso.';
COMMENT ON TABLE PROFESSOR       IS 'Subtipo de PESSOA lotado em um departamento.';
COMMENT ON TABLE TURMA           IS 'Oferta semestral de uma disciplina, com professor, vagas e horário.';
COMMENT ON TABLE MATRICULA       IS 'Associativa ALUNO x TURMA com nota, frequência e status do vínculo.';
COMMENT ON TABLE AUDITORIA_NOTA  IS 'Log imutável de alterações de nota (sem FK, para preservar histórico).';
COMMENT ON TABLE OBRA            IS 'Títulos do acervo da biblioteca.';
COMMENT ON TABLE AUTOR           IS 'Autores das obras.';
COMMENT ON TABLE AUTORIA         IS 'Associativa N:M entre OBRA e AUTOR.';
COMMENT ON TABLE EXEMPLAR        IS 'Entidade fraca: cópia física numerada de uma obra.';
COMMENT ON TABLE EMPRESTIMO      IS 'Empréstimo de um exemplar a uma pessoa.';
COMMENT ON TABLE RESERVA         IS 'Reserva de obra sem exemplar disponível (fila).';
COMMENT ON TABLE MULTA           IS 'Multa por atraso na devolução (1:1 com EMPRESTIMO).';

COMMENT ON COLUMN MATRICULA.status_matricula IS 'Estado do vínculo (ATIVA/TRANCADA). Situação acadêmica é derivada na VW_SITUACAO_ACADEMICA.';
COMMENT ON COLUMN MULTA.data_pagamento       IS 'NULL indica multa pendente (RN14 bloqueia novos empréstimos).';
COMMENT ON COLUMN TURMA.id_professor         IS 'NULL quando o docente foi desligado (ON DELETE SET NULL).';

/* =====================================================================
   6. VERIFICAÇÃO (para a demonstração ao vivo)
   Esperado: 18 tabelas, 11 sequências, 21 FKs.
   ===================================================================== */
SELECT 'TABELAS' AS objeto, COUNT(*) AS total FROM user_tables
 WHERE table_name IN ('DEPARTAMENTO','CURSO','DISCIPLINA','PRE_REQUISITO','PESSOA',
       'TELEFONE_PESSOA','ALUNO','PROFESSOR','TURMA','MATRICULA','AUDITORIA_NOTA',
       'OBRA','AUTOR','AUTORIA','EXEMPLAR','EMPRESTIMO','RESERVA','MULTA')
UNION ALL
SELECT 'SEQUENCIAS', COUNT(*) FROM user_sequences WHERE sequence_name LIKE 'SEQ\_%' ESCAPE '\'
UNION ALL
SELECT 'INDICES (nao PK/UQ)', COUNT(*) FROM user_indexes WHERE index_name LIKE 'IDX\_%' ESCAPE '\';

-- Restrições por tipo (P = PK, R = FK, U = UNIQUE, C = CHECK/NOT NULL)
SELECT constraint_type, COUNT(*) AS total
  FROM user_constraints
 WHERE table_name IN ('DEPARTAMENTO','CURSO','DISCIPLINA','PRE_REQUISITO','PESSOA',
       'TELEFONE_PESSOA','ALUNO','PROFESSOR','TURMA','MATRICULA','AUDITORIA_NOTA',
       'OBRA','AUTOR','AUTORIA','EXEMPLAR','EMPRESTIMO','RESERVA','MULTA')
 GROUP BY constraint_type
 ORDER BY constraint_type;

-- Ações referenciais declaradas em cada FK
SELECT table_name, constraint_name, delete_rule
  FROM user_constraints
 WHERE constraint_type = 'R'
 ORDER BY table_name, constraint_name;

-- Garantia de que nenhuma restrição ficou com nome gerado pelo sistema (esperado: 0 linhas)
SELECT table_name, constraint_name, constraint_type
  FROM user_constraints
 WHERE constraint_name LIKE 'SYS\_C%' ESCAPE '\'
   AND table_name IN ('DEPARTAMENTO','CURSO','DISCIPLINA','PRE_REQUISITO','PESSOA',
       'TELEFONE_PESSOA','ALUNO','PROFESSOR','TURMA','MATRICULA','AUDITORIA_NOTA',
       'OBRA','AUTOR','AUTORIA','EXEMPLAR','EMPRESTIMO','RESERVA','MULTA');
