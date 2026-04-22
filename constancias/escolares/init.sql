--    1. db_escolares   → Nodo Orquestador + datos académicos
-- ==============================================================
-- BD 1: ESCOLARES  (Nodo Principal / Orquestador)
--   Contiene los datos maestros del alumno.
--   También registra el veredicto final de constancia.
-- ==============================================================

CREATE DATABASE IF NOT EXISTS db_escolares
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE db_escolares;

-- Carreras de la UMAR Puerto Escondido
CREATE TABLE carreras (
    id_carrera   INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    clave        VARCHAR(10)  NOT NULL UNIQUE,
    nombre       VARCHAR(120) NOT NULL,
    activa       TINYINT(1)   NOT NULL DEFAULT 1
);

INSERT INTO carreras (clave, nombre) VALUES
    ('BM',  'Biología Marina'),
    ('ENF', 'Enfermería'),
    ('ADM', 'Administración de Empresas Turísticas'),
    ('DER', 'Derecho'),
    ('INF', 'Informática'),
    ('ACU', 'Acuacultura'),
    ('NUT', 'Nutrición'),
    ('ING', 'Ingeniería en Manejo de Recursos Naturales');

-- Datos maestros del alumno (la matrícula es el identificador global)
CREATE TABLE alumnos (
    matricula        VARCHAR(12)  NOT NULL PRIMARY KEY,   -- PE2021001234
    nombre           VARCHAR(60)  NOT NULL,
    apellido_paterno VARCHAR(60)  NOT NULL,
    apellido_materno VARCHAR(60)  NOT NULL,
    curp             CHAR(18)     NOT NULL UNIQUE,
    email            VARCHAR(120) NOT NULL UNIQUE,
    telefono         VARCHAR(15),
    id_carrera       INT UNSIGNED NOT NULL,
    semestre_actual  TINYINT UNSIGNED NOT NULL DEFAULT 1,
    turno            ENUM('Matutino','Vespertino') NOT NULL DEFAULT 'Matutino',
    estatus          ENUM('Activo','Baja Temporal','Baja Definitiva','Egresado','Titulado')
                     NOT NULL DEFAULT 'Activo',
    fecha_ingreso    DATE NOT NULL,
    fecha_egreso     DATE,
    created_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_al_carrera FOREIGN KEY (id_carrera) REFERENCES carreras(id_carrera)
);

-- Ciclos escolares
CREATE TABLE ciclos_escolares (
    id_ciclo     INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    clave        VARCHAR(10) NOT NULL UNIQUE,   -- 2025-A, 2025-B
    descripcion  VARCHAR(60) NOT NULL,
    fecha_inicio DATE        NOT NULL,
    fecha_fin    DATE        NOT NULL,
    activo       TINYINT(1)  NOT NULL DEFAULT 0
);

INSERT INTO ciclos_escolares (clave, descripcion, fecha_inicio, fecha_fin, activo) VALUES
    ('2024-B', 'Semestre B 2024', '2024-08-05', '2024-12-13', 0),
    ('2025-A', 'Semestre A 2025', '2025-01-13', '2025-06-27', 0),
    ('2025-B', 'Semestre B 2025', '2025-08-04', '2025-12-12', 1);

-- Tipos de adeudo propios de Servicios Escolares
-- (documentos faltantes, credencial, constancias, pagos académicos)
CREATE TABLE tipos_adeudo_esc (
    id_tipo      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    categoria    ENUM('Documento','Credencial','Constancia','Pago','Titulación','Otro')
                 NOT NULL,
    nombre       VARCHAR(100) NOT NULL UNIQUE,
    descripcion  TEXT,
    monto_default DECIMAL(10,2) UNSIGNED NOT NULL DEFAULT 0.00,
    requiere_pago TINYINT(1)   NOT NULL DEFAULT 0,
    activo       TINYINT(1)   NOT NULL DEFAULT 1
);

INSERT INTO tipos_adeudo_esc (categoria, nombre, descripcion, monto_default, requiere_pago) VALUES
-- Documentos para reinscripción / titulación
('Documento', 'CURP',                          'Copia de CURP actualizada',                0.00, 0),
('Documento', 'Certificado de Bachillerato',   'Original y copia para expediente',         0.00, 0),
('Documento', 'Acta de Nacimiento',            'Original no mayor a 1 año',                0.00, 0),
('Documento', 'Comprobante de Domicilio',      'Recibo reciente (luz/agua/teléfono)',       0.00, 0),
('Documento', 'Fotografías',                   '6 fotos tamaño título B&N',                0.00, 0),
('Documento', 'Historial Médico',              'Certificado IMSS o ISSSTE',                0.00, 0),
('Documento', 'Comprobante Pago Inscripción',  'Recibo oficial de derechos de inscripción',0.00, 0),
-- Credencial
('Credencial', 'Credencial Universitaria',     'Credencial UMAR vigente del ciclo',      150.00, 1),
('Credencial', 'Reposición de Credencial',     'Por extravío o deterioro',               200.00, 1),
('Credencial', 'Credencial Vencida',           'Credencial de ciclo anterior sin renovar',0.00, 0),
-- Constancias
('Constancia', 'Constancia de Estudios',       'Constancia de alumno regular',            50.00, 1),
('Constancia', 'Constancia de Calificaciones', 'Kárdex sellado por Servicios Escolares',  50.00, 1),
('Constancia', 'Constancia de Término',        'Para inicio de trámites de titulación',   50.00, 1),
-- Pagos académicos
('Pago', 'Colegiatura Pendiente',              'Mensualidad no cubierta',                  0.00, 1),
('Pago', 'Derecho de Reinscripción',           'Pago semestral de derechos',               0.00, 1),
('Pago', 'Examen de Regularización',           'Pago por examen extraordinario',         100.00, 1),
('Pago', 'Derecho de Titulación',              'Pago para iniciar titulación',             0.00, 1),
-- Titulación
('Titulación', 'Servicio Social Incompleto',       'Liberación de servicio social',        0.00, 0),
('Titulación', 'Prácticas Profesionales Incompletas','Horas de práctica no cubiertas',    0.00, 0);

-- Adeudos registrados en Escolares
CREATE TABLE adeudos_escolares (
    id_adeudo        BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    matricula        VARCHAR(12)  NOT NULL,
    id_tipo          INT UNSIGNED NOT NULL,
    id_ciclo         INT UNSIGNED NOT NULL,
    descripcion      VARCHAR(255),
    monto            DECIMAL(10,2) UNSIGNED NOT NULL DEFAULT 0.00,
    estatus          ENUM('Pendiente','Solventado','Vencido','En Proceso','Cancelado')
                     NOT NULL DEFAULT 'Pendiente',
    fecha_registro   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_limite     DATE,
    fecha_solvento   DATETIME,
    usuario_registro VARCHAR(60) NOT NULL,
    usuario_solvento VARCHAR(60),
    observaciones    TEXT,
    CONSTRAINT fk_ade_alumno FOREIGN KEY (matricula) REFERENCES alumnos(matricula),
    CONSTRAINT fk_ade_tipo   FOREIGN KEY (id_tipo)   REFERENCES tipos_adeudo_esc(id_tipo),
    CONSTRAINT fk_ade_ciclo  FOREIGN KEY (id_ciclo)  REFERENCES ciclos_escolares(id_ciclo)
);

-- Pagos que solvientan adeudos con costo
CREATE TABLE pagos_escolares (
    id_pago          BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    id_adeudo        BIGINT UNSIGNED NOT NULL,
    folio_recibo     VARCHAR(40)  NOT NULL UNIQUE,
    monto_pagado     DECIMAL(10,2) UNSIGNED NOT NULL,
    metodo_pago      ENUM('Efectivo','Transferencia','Depósito','Tarjeta','Ventanilla UMAR') NOT NULL,
    fecha_pago       DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    usuario_registro VARCHAR(60) NOT NULL,
    comprobante_path VARCHAR(255),
    CONSTRAINT fk_pago_ade FOREIGN KEY (id_adeudo) REFERENCES adeudos_escolares(id_adeudo)
);

-- Solicitudes de trámites (constancias, credencial, etc.)
CREATE TABLE solicitudes (
    id_solicitud     BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    matricula        VARCHAR(12)  NOT NULL,
    id_tipo          INT UNSIGNED NOT NULL,
    id_ciclo         INT UNSIGNED NOT NULL,
    motivo           TEXT,
    estatus          ENUM('Recibida','En Revisión','Aprobada','Lista para Entrega',
                          'Entregada','Rechazada','Cancelada') NOT NULL DEFAULT 'Recibida',
    fecha_solicitud  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_entrega_est DATE,
    fecha_entrega_real DATETIME,
    usuario_atiende  VARCHAR(60),
    observaciones    TEXT,
    CONSTRAINT fk_sol_al FOREIGN KEY (matricula) REFERENCES alumnos(matricula),
    CONSTRAINT fk_sol_tp FOREIGN KEY (id_tipo)   REFERENCES tipos_adeudo_esc(id_tipo),
    CONSTRAINT fk_sol_ci FOREIGN KEY (id_ciclo)  REFERENCES ciclos_escolares(id_ciclo)
);

-- Veredicto final del Orquestador (resultado de consultar todos los nodos)
CREATE TABLE constancias_no_adeudo (
    id_constancia    BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    matricula        VARCHAR(12)  NOT NULL,
    id_ciclo         INT UNSIGNED NOT NULL,
    estatus_final    ENUM('LISTO','RECHAZADO') NOT NULL,
    detalle_json     JSON,          -- guarda la respuesta completa de los 4 nodos
    fecha_consulta   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    fecha_emision    DATETIME,      -- cuando se imprime/entrega la constancia
    usuario_emite    VARCHAR(60),
    CONSTRAINT fk_cna_al FOREIGN KEY (matricula) REFERENCES alumnos(matricula),
    CONSTRAINT fk_cna_ci FOREIGN KEY (id_ciclo)  REFERENCES ciclos_escolares(id_ciclo)
);

-- Usuarios del sistema (personal Servicios Escolares)
CREATE TABLE usuarios_sistema (
    id_usuario      INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    username        VARCHAR(40)  NOT NULL UNIQUE,
    nombre_completo VARCHAR(150) NOT NULL,
    email           VARCHAR(120) NOT NULL UNIQUE,
    rol             ENUM('Admin','Jefe Servicios Escolares','Capturista','Consulta')
                    NOT NULL DEFAULT 'Capturista',
    activo          TINYINT(1)   NOT NULL DEFAULT 1,
    created_at      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO usuarios_sistema (username, nombre_completo, email, rol) VALUES
    ('admin',       'Administrador Sistema',        'admin@umar.mx',                      'Admin'),
    ('jefe_se',     'Jefe Servicios Escolares PE',  'servesc_pe@aulavirtual.umar.mx',     'Jefe Servicios Escolares'),
    ('capturista1', 'Capturista 1',                 'capturista1@umar.mx',                'Capturista');

-- Alumnos de ejemplo
INSERT INTO alumnos (matricula, nombre, apellido_paterno, apellido_materno, curp, email, telefono, id_carrera, semestre_actual, estatus, fecha_ingreso) VALUES
    ('PE2022001001', 'Sofía',        'Ramírez',   'Torres',    'RATS020315MOXTRS09', 'sofia.ramirez@umar.mx',    '9541234567', 1, 7, 'Activo',       '2022-01-17'),
    ('PE2023001002', 'Miguel Ángel', 'Cruz',      'Hernández', 'CUHM030822MOCRRL07', 'miguel.cruz@umar.mx',      '9547654321', 2, 5, 'Activo',       '2023-01-16'),
    ('PE2021001003', 'Laura',        'Mendoza',   'Jiménez',   'MEJL010610MOCNDRA04','laura.mendoza@umar.mx',    '9549876543', 1, 9, 'Activo',       '2021-01-18'),
    ('PE2024001004', 'Carlos',       'López',     'Pérez',     'LOPC040920MOCPRR01', 'carlos.lopez@umar.mx',     '9541111111', 3, 3, 'Activo',       '2024-01-15'),
    ('PE2022001005', 'Valeria',      'Gutiérrez', 'Ruiz',      'GURV020714MOCTER02', 'valeria.gutierrez@umar.mx','9542222222', 5, 7, 'Baja Temporal','2022-01-17');

-- Adeudos de ejemplo en Escolares (ciclo 2025-B = id 3)
INSERT INTO adeudos_escolares (matricula, id_tipo, id_ciclo, descripcion, monto, estatus, fecha_limite, usuario_registro) VALUES
    ('PE2022001001', 1,  3, 'CURP requerida para reinscripción semestre 8',         0.00,   'Pendiente', '2025-08-01', 'capturista1'),
    ('PE2023001002', 8,  3, 'Credencial ciclo 2025 no tramitada',                 150.00,   'Pendiente', '2025-09-01', 'capturista1'),
    ('PE2023001002', 14, 3, 'Colegiatura Mayo 2025 pendiente',                      0.00,   'Pendiente', NULL,         'capturista1'),
    ('PE2021001003', 9,  3, 'Reposición credencial por extravío',                 200.00,   'En Proceso','2025-08-15', 'jefe_se'),
    ('PE2024001004', 5,  3, '6 fotografías tamaño título para expediente',          0.00,   'Pendiente', '2025-08-05', 'capturista1');

-- Índices
CREATE INDEX idx_ade_esc_mat    ON adeudos_escolares(matricula);
CREATE INDEX idx_ade_esc_estatus ON adeudos_escolares(estatus);
CREATE INDEX idx_alumnos_carrera ON alumnos(id_carrera);

-- Vista: alumnos libres de adeudo en Escolares (para el orquestador)
CREATE OR REPLACE VIEW v_check_escolares AS
SELECT
    al.matricula,
    CONCAT(al.nombre,' ',al.apellido_paterno,' ',al.apellido_materno) AS nombre_completo,
    COUNT(a.id_adeudo) AS total_pendientes,
    CASE WHEN COUNT(a.id_adeudo) = 0 THEN FALSE ELSE TRUE END AS tiene_adeudo
FROM alumnos al
LEFT JOIN adeudos_escolares a
       ON a.matricula = al.matricula
      AND a.estatus IN ('Pendiente','Vencido','En Proceso')
GROUP BY al.matricula, al.nombre, al.apellido_paterno, al.apellido_materno;

