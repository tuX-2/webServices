--    3. db_lab_redes   → Nodo periférico Laboratorio de Redes
-- ==============================================================
-- BD 3: LABORATORIO DE REDES  (Nodo Periférico)
--   Gestiona equipos prestados y prácticas adeudadas.
-- ==============================================================

CREATE DATABASE IF NOT EXISTS db_lab_redes
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE db_lab_redes;

-- Inventario de equipos del laboratorio
CREATE TABLE equipos (
    id_equipo      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    numero_serie   VARCHAR(40)  NOT NULL UNIQUE,
    nombre         VARCHAR(100) NOT NULL,
    tipo           ENUM('Switch','Router','Cable UTP','Patch Panel','Laptop','Herramienta','Otro') NOT NULL,
    estado         ENUM('Disponible','Prestado','Dañado','Baja') NOT NULL DEFAULT 'Disponible',
    activo         TINYINT(1)   NOT NULL DEFAULT 1
);

INSERT INTO equipos (numero_serie, nombre, tipo, estado) VALUES
    ('SW-LAB-001', 'Switch Cisco Catalyst 24p', 'Switch',    'Disponible'),
    ('RT-LAB-001', 'Router Cisco 2911',         'Router',    'Disponible'),
    ('CB-LAB-001', 'Kit Cable UTP Cat6',        'Cable UTP', 'Disponible'),
    ('LT-LAB-001', 'Laptop Dell Inspiron',      'Laptop',    'Prestado'),
    ('HT-LAB-001', 'Kit Crimpeadora/Ponchadora','Herramienta','Disponible');

-- Préstamos de equipos
CREATE TABLE prestamos_equipo (
    id_prestamo    BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    matricula      VARCHAR(12)  NOT NULL,
    id_equipo      INT UNSIGNED NOT NULL,
    fecha_prestamo DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_limite   DATE         NOT NULL,
    fecha_devolucion DATETIME,
    estatus        ENUM('Activo','Devuelto','Vencido','Dañado') NOT NULL DEFAULT 'Activo',
    usuario_registro VARCHAR(60) NOT NULL,
    CONSTRAINT fk_pe_equipo FOREIGN KEY (id_equipo) REFERENCES equipos(id_equipo)
);

-- Prácticas con calificación / entrega pendiente
CREATE TABLE practicas (
    id_practica    INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    clave          VARCHAR(10)  NOT NULL UNIQUE,
    nombre         VARCHAR(150) NOT NULL,
    semestre       TINYINT UNSIGNED NOT NULL,
    descripcion    TEXT
);

INSERT INTO practicas (clave, nombre, semestre) VALUES
    ('RD-P01', 'Configuración básica de Switch',        3),
    ('RD-P02', 'Ruteo estático y dinámico (OSPF/RIP)',  5),
    ('RD-P03', 'Instalación de cableado estructurado',  3),
    ('RD-P04', 'Configuración VLAN',                    5),
    ('RD-P05', 'Seguridad en redes – ACL',              7);

CREATE TABLE practicas_alumno (
    id_registro    BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    matricula      VARCHAR(12)  NOT NULL,
    id_practica    INT UNSIGNED NOT NULL,
    id_ciclo_clave VARCHAR(10)  NOT NULL,   -- ej. '2025-B' (referencia lógica, no FK)
    calificacion   DECIMAL(4,2),
    estatus        ENUM('Pendiente','Entregada','Calificada','No Entregada') NOT NULL DEFAULT 'Pendiente',
    fecha_entrega  DATETIME,
    CONSTRAINT fk_pa_practica FOREIGN KEY (id_practica) REFERENCES practicas(id_practica)
);

-- Adeudos consolidados del laboratorio de redes
CREATE TABLE adeudos_lab_redes (
    id_adeudo      BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    matricula      VARCHAR(12)  NOT NULL,
    tipo           ENUM('Equipo No Devuelto','Equipo Dañado','Práctica Pendiente','Multa') NOT NULL,
    descripcion    VARCHAR(255) NOT NULL,
    monto          DECIMAL(8,2) UNSIGNED NOT NULL DEFAULT 0.00,
    estatus        ENUM('Pendiente','Solventado','Cancelado') NOT NULL DEFAULT 'Pendiente',
    fecha_registro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_solvento DATETIME,
    usuario_registro VARCHAR(60) NOT NULL
);

-- Datos de ejemplo
INSERT INTO prestamos_equipo (matricula, id_equipo, fecha_limite, estatus, usuario_registro) VALUES
    ('PE2024001004', 4, '2025-07-15', 'Vencido', 'lab_redes_enc');

INSERT INTO adeudos_lab_redes (matricula, tipo, descripcion, monto, estatus, usuario_registro) VALUES
    ('PE2024001004', 'Equipo No Devuelto', 'Laptop Dell Inspiron no devuelta (préstamo vencido)', 0.00, 'Pendiente', 'lab_redes_enc');

INSERT INTO practicas_alumno (matricula, id_practica, id_ciclo_clave, estatus) VALUES
    ('PE2023001002', 4, '2025-B', 'No Entregada');

INSERT INTO adeudos_lab_redes (matricula, tipo, descripcion, monto, estatus, usuario_registro) VALUES
    ('PE2023001002', 'Práctica Pendiente', 'Práctica RD-P04: Configuración VLAN – no entregada', 0.00, 'Pendiente', 'lab_redes_enc');

CREATE INDEX idx_lr_mat ON adeudos_lab_redes(matricula);
CREATE INDEX idx_lr_est ON adeudos_lab_redes(estatus);

-- Vista check para el orquestador
CREATE OR REPLACE VIEW v_check_lab_redes AS
SELECT
    matricula,
    COUNT(*)  AS total_pendientes,
    CASE WHEN COUNT(*) > 0 THEN TRUE ELSE FALSE END AS tiene_adeudo,
    GROUP_CONCAT(descripcion SEPARATOR ' | ') AS detalle
FROM adeudos_lab_redes
WHERE estatus = 'Pendiente'
GROUP BY matricula;
