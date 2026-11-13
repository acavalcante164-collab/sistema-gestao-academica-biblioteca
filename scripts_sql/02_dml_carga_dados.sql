/* =====================================================================
   SIGAB - Sistema Integrado de Gestão Acadêmica e Biblioteca
   DCC 502 - Banco de Dados I (UFRR) - Grupo 06
   Script 02: DML - carga da base de testes
   Pré-requisito: 01_ddl_esquema.sql executado.

   Reexecutável: começa apagando todas as linhas (ordem filho -> pai).
   Os IDs são fixos para facilitar a leitura nas consultas e nos testes.

   Cenários embutidos de propósito na carga
   ----------------------------------------
   * Situação acadêmica (RN08): aprovados, reprovados por nota, reprovados
     por falta (inclusive com nota >= 6), cursando e trancados.
   * Turma 501 (Banco de Dados I, 2026.2): 3 vagas e 2 matrículas ativas,
     ou seja, resta exatamente 1 vaga. Alunos 1009 e 1010 cumpriram os
     pré-requisitos e NÃO estão matriculados nela -> teste de concorrência
     do script 05.
   * Turma 513 sem professor (id_professor NULL) e turmas sem matrículas
     (504, 509) -> filtros de presença/ausência e LEFT JOIN.
   * Alunos 1003 e 1012: matrícula ativa + multa pendente (Q04, RN14).
   * Obra 303 (2 exemplares) e obra 308 (1 exemplar) totalmente emprestadas
     e com fila de reservas ativas (Q08, RN15).
   * Obras 311 e 312 nunca emprestadas (Q02, LEFT JOIN).
   * Empréstimos em aberto e atrasados (VW_ACERVO_PENDENCIAS).
   * Exemplos do minimundo (Etapa 1): Carla (1003) devolve 3 dias atrasada
     e recebe multa de R$ 3,00; Diego (1004) reserva "Sistemas
     Operacionais Modernos".
   ===================================================================== */

SET DEFINE OFF;
SET SERVEROUTPUT ON;

/* ---------------------------------------------------------------------
   0. LIMPEZA DOS DADOS (ordem: tabelas filhas -> tabelas pais)
   --------------------------------------------------------------------- */
DELETE FROM MULTA;
DELETE FROM RESERVA;
DELETE FROM EMPRESTIMO;
DELETE FROM EXEMPLAR;
DELETE FROM AUTORIA;
DELETE FROM AUTOR;
DELETE FROM OBRA;
DELETE FROM AUDITORIA_NOTA;
DELETE FROM MATRICULA;
DELETE FROM TURMA;
DELETE FROM PROFESSOR;
DELETE FROM ALUNO;
DELETE FROM TELEFONE_PESSOA;
DELETE FROM PESSOA;
DELETE FROM PRE_REQUISITO;
DELETE FROM DISCIPLINA;
DELETE FROM CURSO;
DELETE FROM DEPARTAMENTO;

/* =====================================================================
   1. MÓDULO ACADÊMICO
   ===================================================================== */

-- 1. DEPARTAMENTO (10)
INSERT INTO DEPARTAMENTO (id_departamento, nome, sigla) VALUES (1,  'Departamento de Ciência da Computação', 'DCC');
INSERT INTO DEPARTAMENTO (id_departamento, nome, sigla) VALUES (2,  'Departamento de Matemática',            'DMAT');
INSERT INTO DEPARTAMENTO (id_departamento, nome, sigla) VALUES (3,  'Departamento de Física',                'DFIS');
INSERT INTO DEPARTAMENTO (id_departamento, nome, sigla) VALUES (4,  'Departamento de Química',               'DQUI');
INSERT INTO DEPARTAMENTO (id_departamento, nome, sigla) VALUES (5,  'Departamento de Letras',                'DLET');
INSERT INTO DEPARTAMENTO (id_departamento, nome, sigla) VALUES (6,  'Departamento de História',              'DHIS');
INSERT INTO DEPARTAMENTO (id_departamento, nome, sigla) VALUES (7,  'Departamento de Administração',         'DADM');
INSERT INTO DEPARTAMENTO (id_departamento, nome, sigla) VALUES (8,  'Departamento de Direito',               'DDIR');
INSERT INTO DEPARTAMENTO (id_departamento, nome, sigla) VALUES (9,  'Departamento de Engenharia Civil',      'DEC');
INSERT INTO DEPARTAMENTO (id_departamento, nome, sigla) VALUES (10, 'Departamento de Biologia',              'DBIO');

-- 2. CURSO (10) - cursos com carga horária >= 3000h são usados na Q03
INSERT INTO CURSO (id_curso, nome, carga_horaria, id_departamento) VALUES (10, 'Ciência da Computação', 3200, 1);
INSERT INTO CURSO (id_curso, nome, carga_horaria, id_departamento) VALUES (11, 'Matemática',            2800, 2);
INSERT INTO CURSO (id_curso, nome, carga_horaria, id_departamento) VALUES (12, 'Física',                2900, 3);
INSERT INTO CURSO (id_curso, nome, carga_horaria, id_departamento) VALUES (13, 'Química',               3000, 4);
INSERT INTO CURSO (id_curso, nome, carga_horaria, id_departamento) VALUES (14, 'Letras',                2800, 5);
INSERT INTO CURSO (id_curso, nome, carga_horaria, id_departamento) VALUES (15, 'História',              2700, 6);
INSERT INTO CURSO (id_curso, nome, carga_horaria, id_departamento) VALUES (16, 'Administração',         3000, 7);
INSERT INTO CURSO (id_curso, nome, carga_horaria, id_departamento) VALUES (17, 'Direito',               3700, 8);
INSERT INTO CURSO (id_curso, nome, carga_horaria, id_departamento) VALUES (18, 'Engenharia Civil',      3600, 9);
INSERT INTO CURSO (id_curso, nome, carga_horaria, id_departamento) VALUES (19, 'Ciências Biológicas',   3200, 10);

-- 3. DISCIPLINA (12)
INSERT INTO DISCIPLINA (id_disciplina, codigo, nome, carga_horaria, id_departamento) VALUES (100, 'DCC502', 'Banco de Dados I',              60, 1);
INSERT INTO DISCIPLINA (id_disciplina, codigo, nome, carga_horaria, id_departamento) VALUES (101, 'DCC301', 'Estruturas de Dados',           60, 1);
INSERT INTO DISCIPLINA (id_disciplina, codigo, nome, carga_horaria, id_departamento) VALUES (102, 'DCC101', 'Algoritmos e Programação',      90, 1);
INSERT INTO DISCIPLINA (id_disciplina, codigo, nome, carga_horaria, id_departamento) VALUES (103, 'DCC503', 'Banco de Dados II',             60, 1);
INSERT INTO DISCIPLINA (id_disciplina, codigo, nome, carga_horaria, id_departamento) VALUES (104, 'DCC401', 'Sistemas Operacionais',         60, 1);
INSERT INTO DISCIPLINA (id_disciplina, codigo, nome, carga_horaria, id_departamento) VALUES (105, 'MAT101', 'Cálculo I',                     90, 2);
INSERT INTO DISCIPLINA (id_disciplina, codigo, nome, carga_horaria, id_departamento) VALUES (106, 'MAT102', 'Cálculo II',                    90, 2);
INSERT INTO DISCIPLINA (id_disciplina, codigo, nome, carga_horaria, id_departamento) VALUES (107, 'MAT201', 'Álgebra Linear',                60, 2);
INSERT INTO DISCIPLINA (id_disciplina, codigo, nome, carga_horaria, id_departamento) VALUES (108, 'FIS101', 'Física I',                      60, 3);
INSERT INTO DISCIPLINA (id_disciplina, codigo, nome, carga_horaria, id_departamento) VALUES (109, 'QUI101', 'Química Geral',                 60, 4);
INSERT INTO DISCIPLINA (id_disciplina, codigo, nome, carga_horaria, id_departamento) VALUES (110, 'LET101', 'Língua Portuguesa',             60, 5);
INSERT INTO DISCIPLINA (id_disciplina, codigo, nome, carga_horaria, id_departamento) VALUES (111, 'ADM101', 'Teoria Geral da Administração', 60, 7);

-- 4. PRE_REQUISITO (10) - (disciplina, disciplina exigida)
INSERT INTO PRE_REQUISITO (id_disciplina, id_disciplina_req) VALUES (100, 101); -- BD I        exige Estruturas de Dados
INSERT INTO PRE_REQUISITO (id_disciplina, id_disciplina_req) VALUES (100, 102); -- BD I        exige Algoritmos
INSERT INTO PRE_REQUISITO (id_disciplina, id_disciplina_req) VALUES (101, 102); -- Estruturas  exige Algoritmos
INSERT INTO PRE_REQUISITO (id_disciplina, id_disciplina_req) VALUES (103, 100); -- BD II       exige BD I
INSERT INTO PRE_REQUISITO (id_disciplina, id_disciplina_req) VALUES (104, 101); -- Sist. Oper. exige Estruturas de Dados
INSERT INTO PRE_REQUISITO (id_disciplina, id_disciplina_req) VALUES (104, 102); -- Sist. Oper. exige Algoritmos
INSERT INTO PRE_REQUISITO (id_disciplina, id_disciplina_req) VALUES (106, 105); -- Cálculo II  exige Cálculo I
INSERT INTO PRE_REQUISITO (id_disciplina, id_disciplina_req) VALUES (107, 105); -- Álgebra    exige Cálculo I
INSERT INTO PRE_REQUISITO (id_disciplina, id_disciplina_req) VALUES (108, 105); -- Física I    exige Cálculo I
INSERT INTO PRE_REQUISITO (id_disciplina, id_disciplina_req) VALUES (108, 107); -- Física I    exige Álgebra Linear

-- 5. PESSOA (25) - 15 alunos (tipo 'A', ids 1001-1015) e 10 professores (tipo 'P', ids 2001-2010)
INSERT INTO PESSOA (id_pessoa, cpf, nome, data_nascimento, email, tipo_pessoa, rua, numero, bairro, cidade, cep) VALUES (1001, '01234567890', 'Ana Carolina Souza',      DATE '2003-04-15', 'ana.souza@ufrr.br',        'A', 'Av. Ville Roy',            '1540', 'Caçari',          'Boa Vista', '69307000');
INSERT INTO PESSOA (id_pessoa, cpf, nome, data_nascimento, email, tipo_pessoa, rua, numero, bairro, cidade, cep) VALUES (1002, '12345678909', 'Bruno Henrique Lima',     DATE '2004-07-22', 'bruno.lima@ufrr.br',       'A', 'Rua Coronel Pinto',        '210',  'Centro',          'Boa Vista', '69301150');
INSERT INTO PESSOA (id_pessoa, cpf, nome, data_nascimento, email, tipo_pessoa, rua, numero, bairro, cidade, cep) VALUES (1003, '23456789018', 'Carla Mendes Rocha',      DATE '2004-01-30', 'carla.rocha@ufrr.br',      'A', 'Rua Professor Agnelo',     '88',   'Paraviana',       'Boa Vista', '69307250');
INSERT INTO PESSOA (id_pessoa, cpf, nome, data_nascimento, email, tipo_pessoa, rua, numero, bairro, cidade, cep) VALUES (1004, '34567890127', 'Diego Alves Pereira',     DATE '2003-11-05', 'diego.pereira@ufrr.br',    'A', 'Av. Ataíde Teive',         '3021', 'Liberdade',       'Boa Vista', '69309050');
INSERT INTO PESSOA (id_pessoa, cpf, nome, data_nascimento, email, tipo_pessoa, rua, numero, bairro, cidade, cep) VALUES (1005, '45678901236', 'Eduarda Martins Costa',   DATE '2005-02-18', 'eduarda.costa@ufrr.br',    'A', 'Rua das Acácias',          '45',   'Aparecida',       'Boa Vista', '69306030');
INSERT INTO PESSOA (id_pessoa, cpf, nome, data_nascimento, email, tipo_pessoa, rua, numero, bairro, cidade, cep) VALUES (1006, '56789012345', 'Felipe Rodrigues Nunes',  DATE '2004-09-09', 'felipe.nunes@ufrr.br',     'A', 'Av. Brigadeiro Eduardo',   '1200', 'Mecejana',        'Boa Vista', '69304000');
INSERT INTO PESSOA (id_pessoa, cpf, nome, data_nascimento, email, tipo_pessoa, rua, numero, bairro, cidade, cep) VALUES (1007, '67890123454', 'Gabriela Fernandes Dias', DATE '2005-06-12', 'gabriela.dias@ufrr.br',    'A', 'Rua Pedro Rodrigues',      '77',   'São Francisco',   'Boa Vista', '69305010');
INSERT INTO PESSOA (id_pessoa, cpf, nome, data_nascimento, email, tipo_pessoa, rua, numero, bairro, cidade, cep) VALUES (1008, '78901234563', 'Henrique Batista Moura',  DATE '2002-12-01', 'henrique.moura@ufrr.br',   'A', 'Av. Mário Homem de Melo',  '980',  'Pricumã',         'Boa Vista', '69309410');
INSERT INTO PESSOA (id_pessoa, cpf, nome, data_nascimento, email, tipo_pessoa, rua, numero, bairro, cidade, cep) VALUES (1009, '89012345672', 'Isabela Cristina Ramos',  DATE '2004-03-27', 'isabela.ramos@ufrr.br',    'A', 'Rua Jaime Brasil',         '312',  'Centro',          'Boa Vista', '69301350');
INSERT INTO PESSOA (id_pessoa, cpf, nome, data_nascimento, email, tipo_pessoa, rua, numero, bairro, cidade, cep) VALUES (1010, '90123456781', 'João Victor Cardoso',     DATE '2003-08-14', 'joao.cardoso@ufrr.br',     'A', 'Rua Uraricoera',           '56',   'Cauamé',          'Boa Vista', '69314000');
INSERT INTO PESSOA (id_pessoa, cpf, nome, data_nascimento, email, tipo_pessoa, rua, numero, bairro, cidade, cep) VALUES (1011, '11223344556', 'Larissa Gomes Teixeira',  DATE '2005-10-03', 'larissa.teixeira@ufrr.br', 'A', 'Rua Estrela Dalva',        '19',   'Jardim Floresta', 'Boa Vista', '69312000');
INSERT INTO PESSOA (id_pessoa, cpf, nome, data_nascimento, email, tipo_pessoa, rua, numero, bairro, cidade, cep) VALUES (1012, '22334455667', 'Marcos Paulo Freitas',    DATE '2001-05-20', 'marcos.freitas@ufrr.br',   'A', 'Av. Capitão Júlio Bezerra','640',  'Aparecida',       'Boa Vista', '69306100');
INSERT INTO PESSOA (id_pessoa, cpf, nome, data_nascimento, email, tipo_pessoa, rua, numero, bairro, cidade, cep) VALUES (1013, '33445566778', 'Natália Barros Pinto',    DATE '2004-12-11', 'natalia.pinto@ufrr.br',    'A', 'Rua Araújo Filho',         '1033', 'Centro',          'Boa Vista', '69301090');
INSERT INTO PESSOA (id_pessoa, cpf, nome, data_nascimento, email, tipo_pessoa, rua, numero, bairro, cidade, cep) VALUES (1014, '44556677889', 'Otávio Santana Melo',     DATE '2003-02-25', 'otavio.melo@ufrr.br',      'A', 'Rua Ajuricaba',            '402',  'Caçari',          'Boa Vista', '69307380');
INSERT INTO PESSOA (id_pessoa, cpf, nome, data_nascimento, email, tipo_pessoa, rua, numero, bairro, cidade, cep) VALUES (1015, '55667788990', 'Paula Regina Farias',     DATE '2005-08-08', 'paula.farias@ufrr.br',     'A', 'Rua Hélio Campos',         '25',   'Paraviana',       'Boa Vista', '69307100');

INSERT INTO PESSOA (id_pessoa, cpf, nome, data_nascimento, email, tipo_pessoa, rua, numero, bairro, cidade, cep) VALUES (2001, '66778899001', 'Ricardo Almeida Torres',  DATE '1975-03-10', 'ricardo.torres@ufrr.br',   'P', 'Av. Glaycon de Paiva',     '2200', 'Paraviana',       'Boa Vista', '69307140');
INSERT INTO PESSOA (id_pessoa, cpf, nome, data_nascimento, email, tipo_pessoa, rua, numero, bairro, cidade, cep) VALUES (2002, '77889900112', 'Sandra Oliveira Brito',   DATE '1980-06-25', 'sandra.brito@ufrr.br',     'P', 'Rua Bento Brasil',         '540',  'Centro',          'Boa Vista', '69301060');
INSERT INTO PESSOA (id_pessoa, cpf, nome, data_nascimento, email, tipo_pessoa, rua, numero, bairro, cidade, cep) VALUES (2003, '88990011223', 'Tiago Monteiro Sales',    DATE '1988-11-02', 'tiago.sales@ufrr.br',      'P', 'Rua Cecília Brasil',       '115',  'São Francisco',   'Boa Vista', '69305080');
INSERT INTO PESSOA (id_pessoa, cpf, nome, data_nascimento, email, tipo_pessoa, rua, numero, bairro, cidade, cep) VALUES (2004, '99001122334', 'Vanessa Cunha Araújo',    DATE '1978-01-19', 'vanessa.araujo@ufrr.br',   'P', 'Av. Ville Roy',            '3300', 'Caçari',          'Boa Vista', '69307010');
INSERT INTO PESSOA (id_pessoa, cpf, nome, data_nascimento, email, tipo_pessoa, rua, numero, bairro, cidade, cep) VALUES (2005, '10293847561', 'Wagner Lopes Siqueira',   DATE '1985-09-30', 'wagner.siqueira@ufrr.br',  'P', 'Rua Alfredo Cruz',         '98',   'Centro',          'Boa Vista', '69301020');
INSERT INTO PESSOA (id_pessoa, cpf, nome, data_nascimento, email, tipo_pessoa, rua, numero, bairro, cidade, cep) VALUES (2006, '29384756102', 'Yasmin Carvalho Reis',    DATE '1983-04-14', 'yasmin.reis@ufrr.br',      'P', 'Rua Floriano Peixoto',     '670',  'Mecejana',        'Boa Vista', '69304030');
INSERT INTO PESSOA (id_pessoa, cpf, nome, data_nascimento, email, tipo_pessoa, rua, numero, bairro, cidade, cep) VALUES (2007, '38475610293', 'Rafael Duarte Campos',    DATE '1990-07-07', 'rafael.campos@ufrr.br',    'P', 'Av. São Joaquim',          '1450', 'Liberdade',       'Boa Vista', '69309120');
INSERT INTO PESSOA (id_pessoa, cpf, nome, data_nascimento, email, tipo_pessoa, rua, numero, bairro, cidade, cep) VALUES (2008, '47561029384', 'Mariana Queiroz Lemos',   DATE '1982-12-21', 'mariana.lemos@ufrr.br',    'P', 'Rua General Sampaio',      '333',  'Aparecida',       'Boa Vista', '69306060');
INSERT INTO PESSOA (id_pessoa, cpf, nome, data_nascimento, email, tipo_pessoa, rua, numero, bairro, cidade, cep) VALUES (2009, '56102938475', 'Leonardo Pacheco Viana',  DATE '1972-02-05', 'leonardo.viana@ufrr.br',   'P', 'Av. Nossa Senhora da Consolata', '880', 'Pricumã',   'Boa Vista', '69309300');
INSERT INTO PESSOA (id_pessoa, cpf, nome, data_nascimento, email, tipo_pessoa, rua, numero, bairro, cidade, cep) VALUES (2010, '61029384756', 'Juliana Prado Nogueira',  DATE '1993-10-28', 'juliana.nogueira@ufrr.br', 'P', 'Rua Sebastião Diniz',      '61',   'Centro',          'Boa Vista', '69301080');

-- 6. TELEFONE_PESSOA (32) - atributo multivalorado: algumas pessoas têm dois telefones
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (1001, '95991112233');
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (1001, '9536241010');
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (1002, '95991223344');
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (1003, '95991334455');
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (1004, '95991445566');
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (1005, '95991556677');
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (1005, '95981556677');
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (1006, '95991667788');
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (1007, '95991778899');
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (1008, '95991889900');
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (1009, '95991990011');
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (1010, '95992001122');
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (1010, '9536233030');
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (1011, '95992112233');
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (1012, '95992223344');
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (1013, '95992334455');
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (1014, '95992445566');
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (1015, '95992556677');
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (2001, '95981001001');
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (2001, '9536213001');
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (2002, '95981002002');
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (2002, '9536213002');
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (2003, '95981003003');
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (2004, '95981004004');
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (2004, '9536213004');
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (2005, '95981005005');
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (2006, '95981006006');
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (2007, '95981007007');
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (2008, '95981008008');
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (2009, '95981009009');
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (2009, '9536213009');
INSERT INTO TELEFONE_PESSOA (id_pessoa, telefone) VALUES (2010, '95981010010');

-- 7. ALUNO (15) - tipo_pessoa assume o DEFAULT 'A'
INSERT INTO ALUNO (id_pessoa, matricula, data_ingresso, id_curso) VALUES (1001, '2024010001', DATE '2024-03-04', 10);
INSERT INTO ALUNO (id_pessoa, matricula, data_ingresso, id_curso) VALUES (1002, '2025010002', DATE '2025-03-03', 10);
INSERT INTO ALUNO (id_pessoa, matricula, data_ingresso, id_curso) VALUES (1003, '2025010003', DATE '2025-03-03', 10);
INSERT INTO ALUNO (id_pessoa, matricula, data_ingresso, id_curso) VALUES (1004, '2025010004', DATE '2025-03-03', 10);
INSERT INTO ALUNO (id_pessoa, matricula, data_ingresso, id_curso) VALUES (1005, '2025010005', DATE '2025-03-03', 10);
INSERT INTO ALUNO (id_pessoa, matricula, data_ingresso, id_curso) VALUES (1006, '2025020006', DATE '2025-03-03', 11);
INSERT INTO ALUNO (id_pessoa, matricula, data_ingresso, id_curso) VALUES (1007, '2025010007', DATE '2025-03-03', 10);
INSERT INTO ALUNO (id_pessoa, matricula, data_ingresso, id_curso) VALUES (1008, '2025090008', DATE '2025-03-03', 18);
INSERT INTO ALUNO (id_pessoa, matricula, data_ingresso, id_curso) VALUES (1009, '2025010009', DATE '2025-03-03', 10);
INSERT INTO ALUNO (id_pessoa, matricula, data_ingresso, id_curso) VALUES (1010, '2025010010', DATE '2025-03-03', 10);
INSERT INTO ALUNO (id_pessoa, matricula, data_ingresso, id_curso) VALUES (1011, '2025030011', DATE '2025-03-03', 12);
INSERT INTO ALUNO (id_pessoa, matricula, data_ingresso, id_curso) VALUES (1012, '2026070012', DATE '2026-03-02', 16);
INSERT INTO ALUNO (id_pessoa, matricula, data_ingresso, id_curso) VALUES (1013, '2025080013', DATE '2025-08-04', 17);
INSERT INTO ALUNO (id_pessoa, matricula, data_ingresso, id_curso) VALUES (1014, '2025040014', DATE '2025-03-03', 13);
INSERT INTO ALUNO (id_pessoa, matricula, data_ingresso, id_curso) VALUES (1015, '2025050015', DATE '2025-08-04', 14);

-- 8. PROFESSOR (10) - tipo_pessoa assume o DEFAULT 'P'
INSERT INTO PROFESSOR (id_pessoa, titulacao, data_admissao, id_departamento) VALUES (2001, 'DOUTOR',       DATE '2008-03-01', 1);
INSERT INTO PROFESSOR (id_pessoa, titulacao, data_admissao, id_departamento) VALUES (2002, 'DOUTOR',       DATE '2012-08-10', 1);
INSERT INTO PROFESSOR (id_pessoa, titulacao, data_admissao, id_departamento) VALUES (2003, 'MESTRE',       DATE '2016-08-10', 1);
INSERT INTO PROFESSOR (id_pessoa, titulacao, data_admissao, id_departamento) VALUES (2004, 'DOUTOR',       DATE '2010-03-01', 2);
INSERT INTO PROFESSOR (id_pessoa, titulacao, data_admissao, id_departamento) VALUES (2005, 'MESTRE',       DATE '2015-03-02', 2);
INSERT INTO PROFESSOR (id_pessoa, titulacao, data_admissao, id_departamento) VALUES (2006, 'DOUTOR',       DATE '2013-08-05', 3);
INSERT INTO PROFESSOR (id_pessoa, titulacao, data_admissao, id_departamento) VALUES (2007, 'ESPECIALISTA', DATE '2019-03-04', 4);
INSERT INTO PROFESSOR (id_pessoa, titulacao, data_admissao, id_departamento) VALUES (2008, 'MESTRE',       DATE '2014-08-11', 5);
INSERT INTO PROFESSOR (id_pessoa, titulacao, data_admissao, id_departamento) VALUES (2009, 'DOUTOR',       DATE '2005-03-01', 7);
INSERT INTO PROFESSOR (id_pessoa, titulacao, data_admissao, id_departamento) VALUES (2010, 'GRADUADO',     DATE '2024-08-05', 1);

-- 9. TURMA (13) - semestres 2025.2 e 2026.1 encerrados; 2026.2 em andamento
INSERT INTO TURMA (id_turma, id_disciplina, id_professor, semestre, vagas_total, sala, dia_semana, hora_inicio, hora_fim) VALUES (501, 100, 2001, '2026.2',  3, 'Lab 02 - DCC',    'SEG-QUA', '14:00', '16:00'); -- 1 vaga livre (teste de concorrência)
INSERT INTO TURMA (id_turma, id_disciplina, id_professor, semestre, vagas_total, sala, dia_semana, hora_inicio, hora_fim) VALUES (502, 101, 2002, '2026.1', 30, 'Sala 101 - DCC',  'TER-QUI', '08:00', '10:00');
INSERT INTO TURMA (id_turma, id_disciplina, id_professor, semestre, vagas_total, sala, dia_semana, hora_inicio, hora_fim) VALUES (503, 102, 2003, '2025.2', 30, 'Lab 01 - DCC',    'SEG-QUA', '08:00', '10:00');
INSERT INTO TURMA (id_turma, id_disciplina, id_professor, semestre, vagas_total, sala, dia_semana, hora_inicio, hora_fim) VALUES (504, 103, 2010, '2026.2', 20, 'Lab 02 - DCC',    'TER-QUI', '14:00', '16:00'); -- sem matrículas
INSERT INTO TURMA (id_turma, id_disciplina, id_professor, semestre, vagas_total, sala, dia_semana, hora_inicio, hora_fim) VALUES (505, 104, 2002, '2026.2', 25, 'Sala 102 - DCC',  'SEG-QUA', '10:00', '12:00');
INSERT INTO TURMA (id_turma, id_disciplina, id_professor, semestre, vagas_total, sala, dia_semana, hora_inicio, hora_fim) VALUES (506, 105, 2004, '2025.2', 40, 'Sala 201 - DMAT', 'TER-QUI', '10:00', '12:00');
INSERT INTO TURMA (id_turma, id_disciplina, id_professor, semestre, vagas_total, sala, dia_semana, hora_inicio, hora_fim) VALUES (507, 106, 2005, '2026.1', 40, 'Sala 202 - DMAT', 'SEG-QUA', '16:00', '18:00');
INSERT INTO TURMA (id_turma, id_disciplina, id_professor, semestre, vagas_total, sala, dia_semana, hora_inicio, hora_fim) VALUES (508, 107, 2004, '2026.2', 35, 'Sala 201 - DMAT', 'SEX',     '08:00', '12:00');
INSERT INTO TURMA (id_turma, id_disciplina, id_professor, semestre, vagas_total, sala, dia_semana, hora_inicio, hora_fim) VALUES (509, 108, 2006, '2026.2', 30, 'Lab de Física',   'TER-QUI', '16:00', '18:00'); -- sem matrículas
INSERT INTO TURMA (id_turma, id_disciplina, id_professor, semestre, vagas_total, sala, dia_semana, hora_inicio, hora_fim) VALUES (510, 109, 2007, '2026.1', 25, 'Lab de Química',  'QUA',     '14:00', '18:00');
INSERT INTO TURMA (id_turma, id_disciplina, id_professor, semestre, vagas_total, sala, dia_semana, hora_inicio, hora_fim) VALUES (511, 110, 2008, '2026.1', 40, 'Sala 05 - CCLA',  'SEG',     '19:00', '22:00');
INSERT INTO TURMA (id_turma, id_disciplina, id_professor, semestre, vagas_total, sala, dia_semana, hora_inicio, hora_fim) VALUES (512, 111, 2009, '2026.2', 45, 'Sala 10 - CCSA',  'QUI',     '19:00', '22:00');
INSERT INTO TURMA (id_turma, id_disciplina, id_professor, semestre, vagas_total, sala, dia_semana, hora_inicio, hora_fim) VALUES (513, 102, NULL, '2026.2', 30, 'Lab 01 - DCC',    'SEG-QUA', '08:00', '10:00'); -- professor a definir

-- 10. MATRICULA (41) - inserida em ordem cronológica, para que os
--     pré-requisitos já existam quando o trigger de matrícula estiver ativo.
-- 2025.2 - Algoritmos e Programação (turma 503)
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1001, 503, DATE '2025-08-04', 9.00,  95.00, 'ATIVA'); -- APROVADO
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1002, 503, DATE '2025-08-04', 7.50,  88.00, 'ATIVA'); -- APROVADO
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1003, 503, DATE '2025-08-04', 8.00,  90.00, 'ATIVA'); -- APROVADO
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1004, 503, DATE '2025-08-04', 4.00,  80.00, 'ATIVA'); -- REPROVADO_NOTA
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1005, 503, DATE '2025-08-04', 8.50,  60.00, 'ATIVA'); -- REPROVADO_FALTA (nota alta)
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1007, 503, DATE '2025-08-04', 6.00,  75.00, 'ATIVA'); -- APROVADO (limite exato)
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1009, 503, DATE '2025-08-04', 7.00,  85.00, 'ATIVA'); -- APROVADO
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1010, 503, DATE '2025-08-04', 6.50,  80.00, 'ATIVA'); -- APROVADO
-- 2025.2 - Cálculo I (turma 506)
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1006, 506, DATE '2025-08-04', 8.00,  90.00, 'ATIVA'); -- APROVADO
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1008, 506, DATE '2025-08-04', 3.50,  50.00, 'ATIVA'); -- REPROVADO_FALTA
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1011, 506, DATE '2025-08-04', 7.00,  85.00, 'ATIVA'); -- APROVADO
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1001, 506, DATE '2025-08-04', 6.00,  80.00, 'ATIVA'); -- APROVADO
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1014, 506, DATE '2025-08-04', 5.50,  78.00, 'ATIVA'); -- REPROVADO_NOTA
-- 2026.1 - Estruturas de Dados (turma 502)
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1001, 502, DATE '2026-03-02', 8.50,  92.00, 'ATIVA'); -- APROVADO
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1002, 502, DATE '2026-03-02', 5.00,  90.00, 'ATIVA'); -- REPROVADO_NOTA
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1003, 502, DATE '2026-03-02', 9.50, 100.00, 'ATIVA'); -- APROVADO
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1007, 502, DATE '2026-03-02', 7.00,  70.00, 'ATIVA'); -- REPROVADO_FALTA
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1009, 502, DATE '2026-03-02', 8.00,  88.00, 'ATIVA'); -- APROVADO
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1010, 502, DATE '2026-03-02', 7.00,  82.00, 'ATIVA'); -- APROVADO
-- 2026.1 - Cálculo II (turma 507)
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1006, 507, DATE '2026-03-02', 7.50,  90.00, 'ATIVA');    -- APROVADO
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1011, 507, DATE '2026-03-02', 4.50,  76.00, 'ATIVA');    -- REPROVADO_NOTA
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1001, 507, DATE '2026-03-02', NULL,  NULL,  'TRANCADA'); -- TRANCADO
-- 2026.1 - Química Geral (turma 510) e Língua Portuguesa (turma 511)
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1014, 510, DATE '2026-03-02', 9.00,  95.00, 'ATIVA'); -- APROVADO
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1008, 510, DATE '2026-03-02', 6.00,  40.00, 'ATIVA'); -- REPROVADO_FALTA
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1015, 511, DATE '2026-03-02', 8.00, 100.00, 'ATIVA'); -- APROVADO
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1013, 511, DATE '2026-03-02', 7.00,  90.00, 'ATIVA'); -- APROVADO
-- 2026.2 - semestre em andamento (nota e frequência ainda NULL -> CURSANDO)
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1001, 501, DATE '2026-08-03', NULL, NULL, 'ATIVA');    -- BD I (2 de 3 vagas)
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1003, 501, DATE '2026-08-03', NULL, NULL, 'ATIVA');
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1003, 505, DATE '2026-08-03', NULL, NULL, 'ATIVA');    -- Sistemas Operacionais
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1009, 505, DATE '2026-08-03', NULL, NULL, 'ATIVA');
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1010, 505, DATE '2026-08-03', NULL, NULL, 'ATIVA');
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1001, 508, DATE '2026-08-03', NULL, NULL, 'ATIVA');    -- Álgebra Linear
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1006, 508, DATE '2026-08-03', NULL, NULL, 'ATIVA');
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1011, 508, DATE '2026-08-03', NULL, NULL, 'ATIVA');
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1012, 512, DATE '2026-08-03', NULL, NULL, 'ATIVA');    -- Teoria Geral da Administração
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1013, 512, DATE '2026-08-03', NULL, NULL, 'ATIVA');
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1015, 512, DATE '2026-08-03', NULL, NULL, 'TRANCADA');
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1004, 513, DATE '2026-08-03', NULL, NULL, 'ATIVA');    -- Algoritmos (refazendo)
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1005, 513, DATE '2026-08-03', NULL, NULL, 'ATIVA');
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1008, 513, DATE '2026-08-03', NULL, NULL, 'ATIVA');
INSERT INTO MATRICULA (id_aluno, id_turma, data_matricula, nota_final, frequencia, status_matricula) VALUES (1012, 513, DATE '2026-08-03', NULL, NULL, 'ATIVA');

-- 11. AUDITORIA_NOTA (10) - histórico anterior à criação do trigger.
--     Cada nota_nova coincide com a nota_final atual da matrícula.
INSERT INTO AUDITORIA_NOTA (id_auditoria, id_aluno, id_turma, nota_anterior, nota_nova, data_alteracao, usuario) VALUES (1,  1004, 503, 3.50, 4.00, TO_DATE('2025-12-15 10:30', 'YYYY-MM-DD HH24:MI'), 'PROF_TIAGO');
INSERT INTO AUDITORIA_NOTA (id_auditoria, id_aluno, id_turma, nota_anterior, nota_nova, data_alteracao, usuario) VALUES (2,  1007, 503, 5.50, 6.00, TO_DATE('2025-12-15 10:42', 'YYYY-MM-DD HH24:MI'), 'PROF_TIAGO');
INSERT INTO AUDITORIA_NOTA (id_auditoria, id_aluno, id_turma, nota_anterior, nota_nova, data_alteracao, usuario) VALUES (3,  1014, 506, 5.00, 5.50, TO_DATE('2025-12-18 09:05', 'YYYY-MM-DD HH24:MI'), 'PROF_VANESSA');
INSERT INTO AUDITORIA_NOTA (id_auditoria, id_aluno, id_turma, nota_anterior, nota_nova, data_alteracao, usuario) VALUES (4,  1001, 506, 5.80, 6.00, TO_DATE('2025-12-18 09:20', 'YYYY-MM-DD HH24:MI'), 'PROF_VANESSA');
INSERT INTO AUDITORIA_NOTA (id_auditoria, id_aluno, id_turma, nota_anterior, nota_nova, data_alteracao, usuario) VALUES (5,  1002, 502, 4.50, 5.00, TO_DATE('2026-07-08 14:10', 'YYYY-MM-DD HH24:MI'), 'PROF_SANDRA');
INSERT INTO AUDITORIA_NOTA (id_auditoria, id_aluno, id_turma, nota_anterior, nota_nova, data_alteracao, usuario) VALUES (6,  1011, 507, 4.00, 4.50, TO_DATE('2026-07-09 16:00', 'YYYY-MM-DD HH24:MI'), 'PROF_WAGNER');
INSERT INTO AUDITORIA_NOTA (id_auditoria, id_aluno, id_turma, nota_anterior, nota_nova, data_alteracao, usuario) VALUES (7,  1006, 507, 7.00, 7.50, TO_DATE('2026-07-09 16:12', 'YYYY-MM-DD HH24:MI'), 'PROF_WAGNER');
INSERT INTO AUDITORIA_NOTA (id_auditoria, id_aluno, id_turma, nota_anterior, nota_nova, data_alteracao, usuario) VALUES (8,  1008, 510, NULL, 6.00, TO_DATE('2026-07-10 11:00', 'YYYY-MM-DD HH24:MI'), 'PROF_RAFAEL');
INSERT INTO AUDITORIA_NOTA (id_auditoria, id_aluno, id_turma, nota_anterior, nota_nova, data_alteracao, usuario) VALUES (9,  1015, 511, NULL, 8.00, TO_DATE('2026-07-10 20:30', 'YYYY-MM-DD HH24:MI'), 'PROF_MARIANA');
INSERT INTO AUDITORIA_NOTA (id_auditoria, id_aluno, id_turma, nota_anterior, nota_nova, data_alteracao, usuario) VALUES (10, 1013, 511, NULL, 7.00, TO_DATE('2026-07-10 20:35', 'YYYY-MM-DD HH24:MI'), 'PROF_MARIANA');

/* =====================================================================
   2. MÓDULO BIBLIOTECA
   ===================================================================== */

-- 12. OBRA (12) - livros, um periódico e dois TCCs (um sem editora: NULL)
INSERT INTO OBRA (id_obra, titulo, tipo, ano_publicacao, editora) VALUES (301, 'Database System Concepts',                    'LIVRO',     2019, 'McGraw-Hill');
INSERT INTO OBRA (id_obra, titulo, tipo, ano_publicacao, editora) VALUES (302, 'Sistemas de Banco de Dados',                  'LIVRO',     2018, 'Pearson');
INSERT INTO OBRA (id_obra, titulo, tipo, ano_publicacao, editora) VALUES (303, 'Sistemas Operacionais Modernos',              'LIVRO',     2016, 'Pearson');
INSERT INTO OBRA (id_obra, titulo, tipo, ano_publicacao, editora) VALUES (304, 'Algoritmos: Teoria e Prática',                'LIVRO',     2012, 'Elsevier');
INSERT INTO OBRA (id_obra, titulo, tipo, ano_publicacao, editora) VALUES (305, 'Estruturas de Dados e Algoritmos em Java',    'LIVRO',     2013, 'Bookman');
INSERT INTO OBRA (id_obra, titulo, tipo, ano_publicacao, editora) VALUES (306, 'Cálculo - Volume 1',                          'LIVRO',     2013, 'Cengage Learning');
INSERT INTO OBRA (id_obra, titulo, tipo, ano_publicacao, editora) VALUES (307, 'Álgebra Linear com Aplicações',               'LIVRO',     2012, 'Bookman');
INSERT INTO OBRA (id_obra, titulo, tipo, ano_publicacao, editora) VALUES (308, 'Fundamentos de Física - Mecânica',            'LIVRO',     2016, 'LTC');
INSERT INTO OBRA (id_obra, titulo, tipo, ano_publicacao, editora) VALUES (309, 'Química Geral - Volume 1',                    'LIVRO',     2010, 'Makron Books');
INSERT INTO OBRA (id_obra, titulo, tipo, ano_publicacao, editora) VALUES (310, 'Revista de Informática Teórica e Aplicada',   'PERIODICO', 2023, 'UFRGS');
INSERT INTO OBRA (id_obra, titulo, tipo, ano_publicacao, editora) VALUES (311, 'Sistema de Gestão de Biblioteca para a UFRR', 'TCC',       2025, 'UFRR');
INSERT INTO OBRA (id_obra, titulo, tipo, ano_publicacao, editora) VALUES (312, 'Análise de Desempenho de Consultas em Oracle','TCC',       2024, NULL);

-- 13. AUTOR (19)
INSERT INTO AUTOR (id_autor, nome) VALUES (50, 'Abraham Silberschatz');
INSERT INTO AUTOR (id_autor, nome) VALUES (51, 'Henry F. Korth');
INSERT INTO AUTOR (id_autor, nome) VALUES (52, 'S. Sudarshan');
INSERT INTO AUTOR (id_autor, nome) VALUES (53, 'Ramez Elmasri');
INSERT INTO AUTOR (id_autor, nome) VALUES (54, 'Shamkant B. Navathe');
INSERT INTO AUTOR (id_autor, nome) VALUES (55, 'Andrew S. Tanenbaum');
INSERT INTO AUTOR (id_autor, nome) VALUES (56, 'Herbert Bos');
INSERT INTO AUTOR (id_autor, nome) VALUES (57, 'Thomas H. Cormen');
INSERT INTO AUTOR (id_autor, nome) VALUES (58, 'Charles E. Leiserson');
INSERT INTO AUTOR (id_autor, nome) VALUES (59, 'Michael T. Goodrich');
INSERT INTO AUTOR (id_autor, nome) VALUES (60, 'Roberto Tamassia');
INSERT INTO AUTOR (id_autor, nome) VALUES (61, 'James Stewart');
INSERT INTO AUTOR (id_autor, nome) VALUES (62, 'Howard Anton');
INSERT INTO AUTOR (id_autor, nome) VALUES (63, 'David Halliday');
INSERT INTO AUTOR (id_autor, nome) VALUES (64, 'Robert Resnick');
INSERT INTO AUTOR (id_autor, nome) VALUES (65, 'John B. Russell');
INSERT INTO AUTOR (id_autor, nome) VALUES (66, 'Instituto de Informática - UFRGS');
INSERT INTO AUTOR (id_autor, nome) VALUES (67, 'Lucas Ferreira Andrade');
INSERT INTO AUTOR (id_autor, nome) VALUES (68, 'Beatriz Lima Castro');

-- 14. AUTORIA (19) - toda obra tem ao menos um autor (participação total no DER)
INSERT INTO AUTORIA (id_obra, id_autor) VALUES (301, 50);
INSERT INTO AUTORIA (id_obra, id_autor) VALUES (301, 51);
INSERT INTO AUTORIA (id_obra, id_autor) VALUES (301, 52);
INSERT INTO AUTORIA (id_obra, id_autor) VALUES (302, 53);
INSERT INTO AUTORIA (id_obra, id_autor) VALUES (302, 54);
INSERT INTO AUTORIA (id_obra, id_autor) VALUES (303, 55);
INSERT INTO AUTORIA (id_obra, id_autor) VALUES (303, 56);
INSERT INTO AUTORIA (id_obra, id_autor) VALUES (304, 57);
INSERT INTO AUTORIA (id_obra, id_autor) VALUES (304, 58);
INSERT INTO AUTORIA (id_obra, id_autor) VALUES (305, 59);
INSERT INTO AUTORIA (id_obra, id_autor) VALUES (305, 60);
INSERT INTO AUTORIA (id_obra, id_autor) VALUES (306, 61);
INSERT INTO AUTORIA (id_obra, id_autor) VALUES (307, 62);
INSERT INTO AUTORIA (id_obra, id_autor) VALUES (308, 63);
INSERT INTO AUTORIA (id_obra, id_autor) VALUES (308, 64);
INSERT INTO AUTORIA (id_obra, id_autor) VALUES (309, 65);
INSERT INTO AUTORIA (id_obra, id_autor) VALUES (310, 66);
INSERT INTO AUTORIA (id_obra, id_autor) VALUES (311, 67);
INSERT INTO AUTORIA (id_obra, id_autor) VALUES (312, 68);

-- 15. EXEMPLAR (19) - entidade fraca: numeração reinicia em cada obra
INSERT INTO EXEMPLAR (id_obra, numero_exemplar, data_aquisicao) VALUES (301, 1, DATE '2020-02-10');
INSERT INTO EXEMPLAR (id_obra, numero_exemplar, data_aquisicao) VALUES (301, 2, DATE '2022-02-15');
INSERT INTO EXEMPLAR (id_obra, numero_exemplar, data_aquisicao) VALUES (301, 3, DATE '2024-03-01');
INSERT INTO EXEMPLAR (id_obra, numero_exemplar, data_aquisicao) VALUES (302, 1, DATE '2019-08-20');
INSERT INTO EXEMPLAR (id_obra, numero_exemplar, data_aquisicao) VALUES (302, 2, DATE '2021-03-12');
INSERT INTO EXEMPLAR (id_obra, numero_exemplar, data_aquisicao) VALUES (303, 1, DATE '2017-05-05');
INSERT INTO EXEMPLAR (id_obra, numero_exemplar, data_aquisicao) VALUES (303, 2, DATE '2019-05-06');
INSERT INTO EXEMPLAR (id_obra, numero_exemplar, data_aquisicao) VALUES (304, 1, DATE '2013-02-01');
INSERT INTO EXEMPLAR (id_obra, numero_exemplar, data_aquisicao) VALUES (304, 2, DATE '2015-02-02');
INSERT INTO EXEMPLAR (id_obra, numero_exemplar, data_aquisicao) VALUES (304, 3, DATE '2020-08-03');
INSERT INTO EXEMPLAR (id_obra, numero_exemplar, data_aquisicao) VALUES (305, 1, DATE '2014-09-10');
INSERT INTO EXEMPLAR (id_obra, numero_exemplar, data_aquisicao) VALUES (306, 1, DATE '2014-02-20');
INSERT INTO EXEMPLAR (id_obra, numero_exemplar, data_aquisicao) VALUES (306, 2, DATE '2018-02-21');
INSERT INTO EXEMPLAR (id_obra, numero_exemplar, data_aquisicao) VALUES (307, 1, DATE '2013-07-15');
INSERT INTO EXEMPLAR (id_obra, numero_exemplar, data_aquisicao) VALUES (308, 1, DATE '2017-03-30');
INSERT INTO EXEMPLAR (id_obra, numero_exemplar, data_aquisicao) VALUES (309, 1, DATE '2011-04-04');
INSERT INTO EXEMPLAR (id_obra, numero_exemplar, data_aquisicao) VALUES (310, 1, DATE '2024-01-15');
INSERT INTO EXEMPLAR (id_obra, numero_exemplar, data_aquisicao) VALUES (311, 1, DATE '2025-12-10');
INSERT INTO EXEMPLAR (id_obra, numero_exemplar, data_aquisicao) VALUES (312, 1, DATE '2024-12-12');

-- 16. EMPRESTIMO (22)
--     Prazo (RN12): aluno +7 dias, professor +15 dias.
--     No máximo 1 empréstimo em aberto por exemplar (RN10) e limite por perfil (RN11).
--     Nenhum usuário pegou livro enquanto tinha multa pendente (RN14).
-- Histórico com devolução no prazo
INSERT INTO EMPRESTIMO (id_emprestimo, id_pessoa, id_obra, numero_exemplar, data_emprestimo, data_prevista_devolucao, data_devolucao) VALUES (7002, 1001, 302, 1, DATE '2026-09-01', DATE '2026-09-08', DATE '2026-09-07');
INSERT INTO EMPRESTIMO (id_emprestimo, id_pessoa, id_obra, numero_exemplar, data_emprestimo, data_prevista_devolucao, data_devolucao) VALUES (7003, 2001, 301, 1, DATE '2026-09-10', DATE '2026-09-25', DATE '2026-09-20');
INSERT INTO EMPRESTIMO (id_emprestimo, id_pessoa, id_obra, numero_exemplar, data_emprestimo, data_prevista_devolucao, data_devolucao) VALUES (7005, 1009, 304, 1, DATE '2026-10-05', DATE '2026-10-12', DATE '2026-10-12');
INSERT INTO EMPRESTIMO (id_emprestimo, id_pessoa, id_obra, numero_exemplar, data_emprestimo, data_prevista_devolucao, data_devolucao) VALUES (7014, 1006, 307, 1, DATE '2026-10-01', DATE '2026-10-08', DATE '2026-10-08');
INSERT INTO EMPRESTIMO (id_emprestimo, id_pessoa, id_obra, numero_exemplar, data_emprestimo, data_prevista_devolucao, data_devolucao) VALUES (7021, 2009, 304, 1, DATE '2026-06-15', DATE '2026-06-30', DATE '2026-06-30');
INSERT INTO EMPRESTIMO (id_emprestimo, id_pessoa, id_obra, numero_exemplar, data_emprestimo, data_prevista_devolucao, data_devolucao) VALUES (7022, 1001, 306, 1, DATE '2026-07-01', DATE '2026-07-08', DATE '2026-07-07');
-- Histórico com devolução em atraso (cada um gera uma multa)
INSERT INTO EMPRESTIMO (id_emprestimo, id_pessoa, id_obra, numero_exemplar, data_emprestimo, data_prevista_devolucao, data_devolucao) VALUES (7001, 1003, 301, 2, DATE '2026-10-01', DATE '2026-10-08', DATE '2026-10-11'); -- 3 dias (Carla)
INSERT INTO EMPRESTIMO (id_emprestimo, id_pessoa, id_obra, numero_exemplar, data_emprestimo, data_prevista_devolucao, data_devolucao) VALUES (7004, 1012, 306, 1, DATE '2026-09-15', DATE '2026-09-22', DATE '2026-09-27'); -- 5 dias
INSERT INTO EMPRESTIMO (id_emprestimo, id_pessoa, id_obra, numero_exemplar, data_emprestimo, data_prevista_devolucao, data_devolucao) VALUES (7006, 1004, 305, 1, DATE '2026-08-20', DATE '2026-08-27', DATE '2026-09-06'); -- 10 dias
INSERT INTO EMPRESTIMO (id_emprestimo, id_pessoa, id_obra, numero_exemplar, data_emprestimo, data_prevista_devolucao, data_devolucao) VALUES (7007, 2004, 307, 1, DATE '2026-08-10', DATE '2026-08-25', DATE '2026-08-30'); -- 5 dias (professora)
INSERT INTO EMPRESTIMO (id_emprestimo, id_pessoa, id_obra, numero_exemplar, data_emprestimo, data_prevista_devolucao, data_devolucao) VALUES (7015, 1011, 304, 3, DATE '2026-09-01', DATE '2026-09-08', DATE '2026-09-10'); -- 2 dias
INSERT INTO EMPRESTIMO (id_emprestimo, id_pessoa, id_obra, numero_exemplar, data_emprestimo, data_prevista_devolucao, data_devolucao) VALUES (7016, 1005, 309, 1, DATE '2026-03-02', DATE '2026-03-09', DATE '2026-03-13'); -- 4 dias
INSERT INTO EMPRESTIMO (id_emprestimo, id_pessoa, id_obra, numero_exemplar, data_emprestimo, data_prevista_devolucao, data_devolucao) VALUES (7017, 1014, 309, 1, DATE '2026-04-01', DATE '2026-04-08', DATE '2026-04-09'); -- 1 dia
INSERT INTO EMPRESTIMO (id_emprestimo, id_pessoa, id_obra, numero_exemplar, data_emprestimo, data_prevista_devolucao, data_devolucao) VALUES (7018, 2008, 310, 1, DATE '2026-04-10', DATE '2026-04-25', DATE '2026-05-01'); -- 6 dias (professora)
INSERT INTO EMPRESTIMO (id_emprestimo, id_pessoa, id_obra, numero_exemplar, data_emprestimo, data_prevista_devolucao, data_devolucao) VALUES (7019, 1013, 302, 2, DATE '2026-05-04', DATE '2026-05-11', DATE '2026-05-18'); -- 7 dias
INSERT INTO EMPRESTIMO (id_emprestimo, id_pessoa, id_obra, numero_exemplar, data_emprestimo, data_prevista_devolucao, data_devolucao) VALUES (7020, 1015, 301, 1, DATE '2026-06-01', DATE '2026-06-08', DATE '2026-06-10'); -- 2 dias
-- Empréstimos em aberto (data_devolucao NULL)
INSERT INTO EMPRESTIMO (id_emprestimo, id_pessoa, id_obra, numero_exemplar, data_emprestimo, data_prevista_devolucao, data_devolucao) VALUES (7008, 1002, 303, 1, DATE '2026-11-05', DATE '2026-11-12', NULL); -- 303 totalmente emprestada
INSERT INTO EMPRESTIMO (id_emprestimo, id_pessoa, id_obra, numero_exemplar, data_emprestimo, data_prevista_devolucao, data_devolucao) VALUES (7009, 2002, 303, 2, DATE '2026-11-03', DATE '2026-11-18', NULL);
INSERT INTO EMPRESTIMO (id_emprestimo, id_pessoa, id_obra, numero_exemplar, data_emprestimo, data_prevista_devolucao, data_devolucao) VALUES (7010, 1010, 301, 3, DATE '2026-11-10', DATE '2026-11-17', NULL);
INSERT INTO EMPRESTIMO (id_emprestimo, id_pessoa, id_obra, numero_exemplar, data_emprestimo, data_prevista_devolucao, data_devolucao) VALUES (7011, 2003, 304, 2, DATE '2026-11-01', DATE '2026-11-16', NULL);
INSERT INTO EMPRESTIMO (id_emprestimo, id_pessoa, id_obra, numero_exemplar, data_emprestimo, data_prevista_devolucao, data_devolucao) VALUES (7012, 1007, 308, 1, DATE '2026-10-20', DATE '2026-10-27', NULL); -- 308 totalmente emprestada (atrasado)
INSERT INTO EMPRESTIMO (id_emprestimo, id_pessoa, id_obra, numero_exemplar, data_emprestimo, data_prevista_devolucao, data_devolucao) VALUES (7013, 2006, 306, 2, DATE '2026-11-02', DATE '2026-11-17', NULL);

-- 17. RESERVA (10) - só para obra sem exemplar disponível na data da reserva (RN15)
INSERT INTO RESERVA (id_reserva, id_pessoa, id_obra, data_reserva, situacao) VALUES (901, 1004, 303, TO_DATE('2026-11-06 09:15', 'YYYY-MM-DD HH24:MI'), 'ATIVA');     -- Diego (1º da fila)
INSERT INTO RESERVA (id_reserva, id_pessoa, id_obra, data_reserva, situacao) VALUES (902, 1005, 303, TO_DATE('2026-11-07 14:40', 'YYYY-MM-DD HH24:MI'), 'ATIVA');
INSERT INTO RESERVA (id_reserva, id_pessoa, id_obra, data_reserva, situacao) VALUES (903, 2010, 303, TO_DATE('2026-11-08 10:05', 'YYYY-MM-DD HH24:MI'), 'ATIVA');
INSERT INTO RESERVA (id_reserva, id_pessoa, id_obra, data_reserva, situacao) VALUES (904, 1011, 308, TO_DATE('2026-10-22 08:30', 'YYYY-MM-DD HH24:MI'), 'ATIVA');
INSERT INTO RESERVA (id_reserva, id_pessoa, id_obra, data_reserva, situacao) VALUES (905, 1006, 308, TO_DATE('2026-10-25 16:20', 'YYYY-MM-DD HH24:MI'), 'ATIVA');
INSERT INTO RESERVA (id_reserva, id_pessoa, id_obra, data_reserva, situacao) VALUES (906, 1006, 307, TO_DATE('2026-08-15 11:00', 'YYYY-MM-DD HH24:MI'), 'ATENDIDA');
INSERT INTO RESERVA (id_reserva, id_pessoa, id_obra, data_reserva, situacao) VALUES (907, 1014, 309, TO_DATE('2026-03-05 10:00', 'YYYY-MM-DD HH24:MI'), 'ATENDIDA');
INSERT INTO RESERVA (id_reserva, id_pessoa, id_obra, data_reserva, situacao) VALUES (908, 1012, 310, TO_DATE('2026-04-15 15:30', 'YYYY-MM-DD HH24:MI'), 'CANCELADA');
INSERT INTO RESERVA (id_reserva, id_pessoa, id_obra, data_reserva, situacao) VALUES (909, 1007, 305, TO_DATE('2026-08-22 09:45', 'YYYY-MM-DD HH24:MI'), 'CANCELADA');
INSERT INTO RESERVA (id_reserva, id_pessoa, id_obra, data_reserva, situacao) VALUES (910, 1015, 309, TO_DATE('2026-04-03 13:10', 'YYYY-MM-DD HH24:MI'), 'CANCELADA');

-- 18. MULTA (10) - R$ 1,00 por dia de atraso (RN13); data_pagamento NULL = pendente
INSERT INTO MULTA (id_multa, id_emprestimo, valor, data_geracao, data_pagamento) VALUES (401, 7001,  3.00, DATE '2026-10-11', NULL);               -- PENDENTE (Carla, 1003)
INSERT INTO MULTA (id_multa, id_emprestimo, valor, data_geracao, data_pagamento) VALUES (402, 7004,  5.00, DATE '2026-09-27', NULL);               -- PENDENTE (Marcos, 1012)
INSERT INTO MULTA (id_multa, id_emprestimo, valor, data_geracao, data_pagamento) VALUES (403, 7006, 10.00, DATE '2026-09-06', DATE '2026-09-10');
INSERT INTO MULTA (id_multa, id_emprestimo, valor, data_geracao, data_pagamento) VALUES (404, 7007,  5.00, DATE '2026-08-30', DATE '2026-09-02');
INSERT INTO MULTA (id_multa, id_emprestimo, valor, data_geracao, data_pagamento) VALUES (405, 7015,  2.00, DATE '2026-09-10', DATE '2026-09-15');
INSERT INTO MULTA (id_multa, id_emprestimo, valor, data_geracao, data_pagamento) VALUES (406, 7016,  4.00, DATE '2026-03-13', DATE '2026-03-20');
INSERT INTO MULTA (id_multa, id_emprestimo, valor, data_geracao, data_pagamento) VALUES (407, 7017,  1.00, DATE '2026-04-09', DATE '2026-04-09');
INSERT INTO MULTA (id_multa, id_emprestimo, valor, data_geracao, data_pagamento) VALUES (408, 7018,  6.00, DATE '2026-05-01', DATE '2026-05-05');
INSERT INTO MULTA (id_multa, id_emprestimo, valor, data_geracao, data_pagamento) VALUES (409, 7019,  7.00, DATE '2026-05-18', DATE '2026-05-20');
INSERT INTO MULTA (id_multa, id_emprestimo, valor, data_geracao, data_pagamento) VALUES (410, 7020,  2.00, DATE '2026-06-10', DATE '2026-06-10');

COMMIT;

/* =====================================================================
   3. TESTES DE INTEGRIDADE (o esquema deve REJEITAR cada comando abaixo)
   Cada teste imprime [OK] com o erro do Oracle quando a restrição
   funciona. Habilite a saída: Exibir > Saída DBMS (ou SET SERVEROUTPUT ON).
   Nenhum dado é alterado.
   ===================================================================== */
DECLARE
    PROCEDURE testar(p_descricao IN VARCHAR2, p_comando IN VARCHAR2) IS
    BEGIN
        EXECUTE IMMEDIATE p_comando;
        DBMS_OUTPUT.PUT_LINE('[FALHOU] ' || p_descricao || ' -> o comando foi aceito');
        ROLLBACK;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('[OK] ' || p_descricao);
            DBMS_OUTPUT.PUT_LINE('     ' || SQLERRM);
    END;
BEGIN
    DBMS_OUTPUT.PUT_LINE('===== TESTES DE INTEGRIDADE =====');

    testar('01. CPF duplicado (UQ_PESSOA_CPF)',
        'INSERT INTO PESSOA (id_pessoa, cpf, nome, data_nascimento, email, tipo_pessoa, rua, numero, bairro, cidade, cep)
         VALUES (3001, ''01234567890'', ''Pessoa Teste'', DATE ''2000-01-01'', ''teste@ufrr.br'', ''A'', ''Rua X'', ''1'', ''Centro'', ''Boa Vista'', ''69301000'')');

    testar('02. Professor cadastrado também como aluno - disjunção (FK_ALUNO_PESSOA)',
        'INSERT INTO ALUNO (id_pessoa, matricula, data_ingresso, id_curso) VALUES (2001, ''2099000001'', DATE ''2026-01-01'', 10)');

    testar('03. Nota fora do intervalo 0-10 (CK_MATRICULA_NOTA)',
        'UPDATE MATRICULA SET nota_final = 11 WHERE id_aluno = 1001 AND id_turma = 503');

    testar('04. Matrícula duplicada na mesma turma (PK_MATRICULA / RN06)',
        'INSERT INTO MATRICULA (id_aluno, id_turma) VALUES (1001, 503)');

    testar('05. Matrícula em turma inexistente (FK_MATRICULA_TURMA)',
        'INSERT INTO MATRICULA (id_aluno, id_turma) VALUES (1002, 999)');

    testar('06. Excluir departamento com cursos, disciplinas e professores vinculados (ORA-02292)',
        'DELETE FROM DEPARTAMENTO WHERE id_departamento = 1');

    testar('07. Disciplina como pré-requisito de si mesma (CK_PREREQ_DISTINTO)',
        'INSERT INTO PRE_REQUISITO (id_disciplina, id_disciplina_req) VALUES (100, 100)');

    testar('08. Aula terminando antes de começar (CK_TURMA_HFIM)',
        'UPDATE TURMA SET hora_fim = ''13:00'' WHERE id_turma = 501');

    testar('09. Devolução anterior ao empréstimo (CK_EMP_DEVOLUCAO)',
        'UPDATE EMPRESTIMO SET data_devolucao = DATE ''2026-01-01'' WHERE id_emprestimo = 7008');

    testar('10. Segunda multa para o mesmo empréstimo - relação 1:1 (UQ_MULTA_EMPRESTIMO)',
        'INSERT INTO MULTA (id_multa, id_emprestimo, valor) VALUES (499, 7001, 1)');

    testar('11. Tipo de obra fora do domínio (CK_OBRA_TIPO)',
        'INSERT INTO OBRA (id_obra, titulo, tipo, ano_publicacao) VALUES (399, ''Obra Teste'', ''REVISTA'', 2020)');

    testar('12. Empréstimo de exemplar inexistente - entidade fraca (FK_EMPRESTIMO_EXEMPLAR)',
        'INSERT INTO EMPRESTIMO (id_emprestimo, id_pessoa, id_obra, numero_exemplar, data_prevista_devolucao)
         VALUES (7999, 1001, 301, 9, SYSDATE + 7)');
END;
/

/* ---------------------------------------------------------------------
   4. DEMONSTRAÇÃO DAS AÇÕES REFERENCIAIS (desfeita ao final)
   Excluir a professora 2010 (Juliana) dispara, em cadeia:
     PESSOA -> PROFESSOR        (ON DELETE CASCADE)
     PROFESSOR -> TURMA 504     (ON DELETE SET NULL: a turma continua)
     PESSOA -> TELEFONE_PESSOA  (ON DELETE CASCADE)
     PESSOA -> RESERVA 903      (ON DELETE CASCADE)
   --------------------------------------------------------------------- */
DECLARE
    v_prof      TURMA.id_professor%TYPE;
    v_qtd_prof  NUMBER;
    v_qtd_tel   NUMBER;
    v_qtd_res   NUMBER;
BEGIN
    DBMS_OUTPUT.PUT_LINE(CHR(10) || '===== AÇÕES REFERENCIAIS (CASCADE / SET NULL) =====');
    SAVEPOINT sp_demo_fk;

    SELECT id_professor INTO v_prof FROM TURMA WHERE id_turma = 504;
    DBMS_OUTPUT.PUT_LINE('Antes : turma 504 com professor ' || NVL(TO_CHAR(v_prof), 'NULL'));

    DELETE FROM PESSOA WHERE id_pessoa = 2010;

    SELECT id_professor INTO v_prof FROM TURMA WHERE id_turma = 504;
    SELECT COUNT(*) INTO v_qtd_prof FROM PROFESSOR       WHERE id_pessoa = 2010;
    SELECT COUNT(*) INTO v_qtd_tel  FROM TELEFONE_PESSOA WHERE id_pessoa = 2010;
    SELECT COUNT(*) INTO v_qtd_res  FROM RESERVA         WHERE id_pessoa = 2010;
    DBMS_OUTPUT.PUT_LINE('Depois: turma 504 com professor ' || NVL(TO_CHAR(v_prof), 'NULL') || ' (SET NULL)');
    DBMS_OUTPUT.PUT_LINE('        PROFESSOR=' || v_qtd_prof || ', TELEFONE=' || v_qtd_tel ||
                         ', RESERVA=' || v_qtd_res || ' (CASCADE)');

    ROLLBACK TO SAVEPOINT sp_demo_fk;
    DBMS_OUTPUT.PUT_LINE('ROLLBACK TO SAVEPOINT: dados restaurados.');
END;
/

/* =====================================================================
   5. VERIFICAÇÃO DA CARGA (quantidade de linhas por tabela)
   ===================================================================== */
SELECT 'DEPARTAMENTO'    AS tabela, COUNT(*) AS linhas FROM DEPARTAMENTO    UNION ALL
SELECT 'CURSO',                     COUNT(*)           FROM CURSO           UNION ALL
SELECT 'DISCIPLINA',                COUNT(*)           FROM DISCIPLINA      UNION ALL
SELECT 'PRE_REQUISITO',             COUNT(*)           FROM PRE_REQUISITO   UNION ALL
SELECT 'PESSOA',                    COUNT(*)           FROM PESSOA          UNION ALL
SELECT 'TELEFONE_PESSOA',           COUNT(*)           FROM TELEFONE_PESSOA UNION ALL
SELECT 'ALUNO',                     COUNT(*)           FROM ALUNO           UNION ALL
SELECT 'PROFESSOR',                 COUNT(*)           FROM PROFESSOR       UNION ALL
SELECT 'TURMA',                     COUNT(*)           FROM TURMA           UNION ALL
SELECT 'MATRICULA',                 COUNT(*)           FROM MATRICULA       UNION ALL
SELECT 'AUDITORIA_NOTA',            COUNT(*)           FROM AUDITORIA_NOTA  UNION ALL
SELECT 'OBRA',                      COUNT(*)           FROM OBRA            UNION ALL
SELECT 'AUTOR',                     COUNT(*)           FROM AUTOR           UNION ALL
SELECT 'AUTORIA',                   COUNT(*)           FROM AUTORIA         UNION ALL
SELECT 'EXEMPLAR',                  COUNT(*)           FROM EXEMPLAR        UNION ALL
SELECT 'EMPRESTIMO',                COUNT(*)           FROM EMPRESTIMO      UNION ALL
SELECT 'RESERVA',                   COUNT(*)           FROM RESERVA         UNION ALL
SELECT 'MULTA',                     COUNT(*)           FROM MULTA;

-- Conferência do cenário de concorrência: turma 501 deve ter 3 vagas e 2 ativas
SELECT t.id_turma, t.vagas_total,
       (SELECT COUNT(*) FROM MATRICULA m
         WHERE m.id_turma = t.id_turma AND m.status_matricula = 'ATIVA') AS ativas
  FROM TURMA t
 WHERE t.id_turma = 501;
