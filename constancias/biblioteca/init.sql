--    2. db_biblioteca  → Nodo periférico Biblioteca
-- ==============================================================
-- BD 2: BIBLIOTECA  (Nodo Periférico)
--   Gestiona préstamos de libros y multas.
-- ==============================================================

CREATE DATABASE IF NOT EXISTS db_biblioteca
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE db_biblioteca;

-- Catálogo de material bibliográfico
CREATE TABLE material (
    id_material    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    codigo         VARCHAR(20)  NOT NULL UNIQUE,
    titulo         VARCHAR(200) NOT NULL,
    autor          VARCHAR(150),
    editorial      VARCHAR(100),
    anio           YEAR,
    tipo           ENUM('Libro','Revista','Tesis','Manual','CD/DVD','Otro') NOT NULL DEFAULT 'Libro',
    total_ejemplares TINYINT UNSIGNED NOT NULL DEFAULT 1,
    disponibles    TINYINT UNSIGNED NOT NULL DEFAULT 1,
    activo         TINYINT(1)   NOT NULL DEFAULT 1
);

INSERT INTO material (codigo, titulo, autor, editorial, anio, tipo, total_ejemplares, disponibles) VALUES
    ('BIB-001', 'Sistemas Distribuidos',         'Tanenbaum, A.',    'Pearson',    2017, 'Libro', 3, 2),
    ('BIB-002', 'Biología Marina Tropical',      'Reyes, H.',        'UNAM',       2019, 'Libro', 2, 2),
    ('BIB-003', 'Fundamentos de Informática',    'Laudon, K.',       'McGraw-Hill',2020, 'Libro', 4, 3),
    ('BIB-004', 'Derecho Constitucional',        'Fix-Zamudio, H.',  'Porrúa',     2018, 'Libro', 2, 2),
    ('BIB-005', 'Administración de Empresas',    'Robbins, S.',      'Pearson',    2021, 'Libro', 3, 3);

-- Préstamos activos e histórico
CREATE TABLE prestamos (
    id_prestamo    BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    matricula      VARCHAR(12)  NOT NULL,    -- referencia al alumno (en db_escolares)
    id_material    INT UNSIGNED NOT NULL,
    fecha_prestamo DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_limite   DATE         NOT NULL,    -- normalmente 7 días hábiles
    fecha_devolucion DATETIME,
    estatus        ENUM('Activo','Devuelto','Vencido') NOT NULL DEFAULT 'Activo',
    usuario_registro VARCHAR(60) NOT NULL,
    CONSTRAINT fk_prest_mat FOREIGN KEY (id_material) REFERENCES material(id_material)
);

-- Multas por retraso o pérdida
CREATE TABLE multas (
    id_multa       BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_prestamo    BIGINT UNSIGNED NOT NULL,
    matricula      VARCHAR(12)  NOT NULL,
    motivo         ENUM('Retraso','Material Dañado','Material Perdido') NOT NULL,
    dias_retraso   SMALLINT UNSIGNED DEFAULT 0,
    monto          DECIMAL(8,2) UNSIGNED NOT NULL DEFAULT 0.00,
    estatus        ENUM('Pendiente','Pagada','Condonada') NOT NULL DEFAULT 'Pendiente',
    fecha_multa    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_pago     DATETIME,
    usuario_registro VARCHAR(60) NOT NULL,
    CONSTRAINT fk_multa_prest FOREIGN KEY (id_prestamo) REFERENCES prestamos(id_prestamo)
);

-- Adeudos consolidados de Biblioteca (lo que consulta el orquestador)
CREATE TABLE adeudos_biblioteca (
    id_adeudo      BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    matricula      VARCHAR(12)  NOT NULL,
    tipo           ENUM('Libro No Devuelto','Multa Pendiente','Material Dañado') NOT NULL,
    descripcion    VARCHAR(255) NOT NULL,
    monto          DECIMAL(8,2) UNSIGNED NOT NULL DEFAULT 0.00,
    estatus        ENUM('Pendiente','Solventado','Cancelado') NOT NULL DEFAULT 'Pendiente',
    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_solvento DATETIME,
    usuario_registro VARCHAR(60) NOT NULL
);

-- Datos de ejemplo
INSERT INTO prestamos (matricula, id_material, fecha_limite, estatus, usuario_registro) VALUES
    ('PE2022001005', 3, '2025-06-20', 'Vencido',  'bib_capturista'),
    ('PE2021001003', 1, '2025-07-10', 'Devuelto', 'bib_capturista'),
    ('PE2023001002', 2, '2025-07-30', 'Activo',   'bib_capturista');

INSERT INTO multas (id_prestamo, matricula, motivo, dias_retraso, monto, estatus, usuario_registro) VALUES
    (1, 'PE2022001005', 'Retraso', 30, 30.00, 'Pendiente', 'bib_capturista');

INSERT INTO adeudos_biblioteca (matricula, tipo, descripcion, monto, estatus, usuario_registro) VALUES
    ('PE2022001005', 'Libro No Devuelto',  'Libro "Fundamentos de Informática" sin devolver', 0.00,  'Pendiente', 'bib_capturista'),
    ('PE2022001005', 'Multa Pendiente',    'Multa por 30 días de retraso',                    30.00, 'Pendiente', 'bib_capturista');

CREATE INDEX idx_bib_mat   ON adeudos_biblioteca(matricula);
CREATE INDEX idx_bib_est   ON adeudos_biblioteca(estatus);
CREATE INDEX idx_prest_mat ON prestamos(matricula);

-- Vista que expone el check por matrícula (endpoint /check/<matricula>)
CREATE OR REPLACE VIEW v_check_biblioteca AS
SELECT
    matricula,
    COUNT(*)  AS total_pendientes,
    CASE WHEN COUNT(*) > 0 THEN TRUE ELSE FALSE END AS tiene_adeudo,
    GROUP_CONCAT(descripcion SEPARATOR ' | ') AS detalle
FROM adeudos_biblioteca
WHERE estatus = 'Pendiente'
GROUP BY matricula;
