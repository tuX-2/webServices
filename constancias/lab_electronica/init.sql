--    4. db_lab_elec    → Nodo periférico Laboratorio de Electrónica

-- ==============================================================
-- BD 4: LABORATORIO DE ELECTRÓNICA  (Nodo Periférico)
--   Gestiona componentes, herramientas y prácticas.
-- ==============================================================

CREATE DATABASE IF NOT EXISTS db_lab_electronica
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE db_lab_electronica;

-- Inventario de componentes y herramientas
CREATE TABLE componentes (
    id_componente  INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo         VARCHAR(20)  NOT NULL UNIQUE,
    nombre         VARCHAR(100) NOT NULL,
    tipo           ENUM('Herramienta','Componente Electrónico','Instrumento de Medición',
                        'Kit','Equipo','Otro') NOT NULL,
    cantidad_total SMALLINT UNSIGNED NOT NULL DEFAULT 1,
    cantidad_disponible SMALLINT UNSIGNED NOT NULL DEFAULT 1,
    activo         TINYINT(1)   NOT NULL DEFAULT 1
);

INSERT INTO componentes (codigo, nombre, tipo, cantidad_total, cantidad_disponible) VALUES
    ('EL-H001', 'Multímetro Digital',         'Instrumento de Medición', 10, 8),
    ('EL-H002', 'Cautín 30W',                 'Herramienta',             15, 13),
    ('EL-H003', 'Osciloscopio 2 canales',     'Instrumento de Medición',  5, 4),
    ('EL-K001', 'Kit Resistencias surtidas',  'Kit',                     20, 18),
    ('EL-K002', 'Kit Arduino UNO + sensores', 'Kit',                     12, 10),
    ('EL-C001', 'Protoboard 830 pts',         'Componente Electrónico',  25, 22);

-- Préstamos de componentes/herramientas
CREATE TABLE prestamos_componente (
    id_prestamo    BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    matricula      VARCHAR(12)  NOT NULL,
    id_componente  INT UNSIGNED NOT NULL,
    cantidad       SMALLINT UNSIGNED NOT NULL DEFAULT 1,
    fecha_prestamo DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_limite   DATE         NOT NULL,
    fecha_devolucion DATETIME,
    estatus        ENUM('Activo','Devuelto','Vencido','Dañado','Perdido') NOT NULL DEFAULT 'Activo',
    usuario_registro VARCHAR(60) NOT NULL,
    CONSTRAINT fk_pc_comp FOREIGN KEY (id_componente) REFERENCES componentes(id_componente)
);

-- Prácticas del laboratorio de electrónica
CREATE TABLE practicas_elec (
    id_practica    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    clave          VARCHAR(10)  NOT NULL UNIQUE,
    nombre         VARCHAR(150) NOT NULL,
    semestre       TINYINT UNSIGNED NOT NULL
);

INSERT INTO practicas_elec (clave, nombre, semestre) VALUES
    ('EL-P01', 'Circuitos resistivos en serie y paralelo',   2),
    ('EL-P02', 'Uso del osciloscopio – señales AC/DC',       4),
    ('EL-P03', 'Circuitos lógicos combinacionales',          4),
    ('EL-P04', 'Programación básica Arduino – sensores',     6),
    ('EL-P05', 'Amplificadores operacionales',               6);

CREATE TABLE practicas_alumno_elec (
    id_registro    BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    matricula      VARCHAR(12)  NOT NULL,
    id_practica    INT UNSIGNED NOT NULL,
    id_ciclo_clave VARCHAR(10)  NOT NULL,
    calificacion   DECIMAL(4,2),
    estatus        ENUM('Pendiente','Entregada','Calificada','No Entregada') NOT NULL DEFAULT 'Pendiente',
    fecha_entrega  DATETIME,
    CONSTRAINT fk_pae_prac FOREIGN KEY (id_practica) REFERENCES practicas_elec(id_practica)
);

-- Adeudos consolidados del laboratorio de electrónica
CREATE TABLE adeudos_lab_electronica (
    id_adeudo      BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    matricula      VARCHAR(12)  NOT NULL,
    tipo           ENUM('Componente No Devuelto','Componente Dañado',
                        'Práctica Pendiente','Multa') NOT NULL,
    descripcion    VARCHAR(255) NOT NULL,
    monto          DECIMAL(8,2) UNSIGNED NOT NULL DEFAULT 0.00,
    estatus        ENUM('Pendiente','Solventado','Cancelado') NOT NULL DEFAULT 'Pendiente',
    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_solvento DATETIME,
    usuario_registro VARCHAR(60) NOT NULL
);

-- Datos de ejemplo
INSERT INTO prestamos_componente (matricula, id_componente, cantidad, fecha_limite, estatus, usuario_registro) VALUES
    ('PE2022001001', 2, 1, '2025-07-01', 'Vencido',  'lab_elec_enc'),
    ('PE2021001003', 3, 1, '2025-07-20', 'Devuelto', 'lab_elec_enc');

INSERT INTO adeudos_lab_electronica (matricula, tipo, descripcion, monto, estatus, usuario_registro) VALUES
    ('PE2022001001', 'Componente No Devuelto', 'Cautín 30W no devuelto (préstamo vencido 01/07/2025)', 0.00, 'Pendiente', 'lab_elec_enc');

INSERT INTO practicas_alumno_elec (matricula, id_practica, id_ciclo_clave, estatus) VALUES
    ('PE2024001004', 3, '2025-B', 'No Entregada');

INSERT INTO adeudos_lab_electronica (matricula, tipo, descripcion, monto, estatus, usuario_registro) VALUES
    ('PE2024001004', 'Práctica Pendiente', 'Práctica EL-P03: Circuitos lógicos combinacionales – no entregada', 0.00, 'Pendiente', 'lab_elec_enc');

CREATE INDEX idx_le_mat ON adeudos_lab_electronica(matricula);
CREATE INDEX idx_le_est ON adeudos_lab_electronica(estatus);

-- Vista check para el orquestador
CREATE OR REPLACE VIEW v_check_lab_electronica AS
SELECT
    matricula,
    COUNT(*)  AS total_pendientes,
    CASE WHEN COUNT(*) > 0 THEN TRUE ELSE FALSE END AS tiene_adeudo,
    GROUP_CONCAT(descripcion SEPARATOR ' | ') AS detalle
FROM adeudos_lab_electronica
WHERE estatus = 'Pendiente'
GROUP BY matricula;
