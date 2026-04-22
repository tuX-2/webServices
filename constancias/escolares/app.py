"""
Nodo: ESCOLARES  (periférico de datos académicos)
Puerto: 5001
BD:     db_escolares
Vista:  v_check_escolares
"""

import os
from flask import Flask, jsonify
import mysql.connector
from mysql.connector import Error

app = Flask(__name__)

DB_CONFIG = {
    "host":     os.environ.get("DB_HOST",     "localhost"),
    "port":     int(os.environ.get("DB_PORT", 3306)),
    "user":     os.environ.get("DB_USER",     "root"),
    "password": os.environ.get("DB_PASSWORD", ""),
    "database": os.environ.get("DB_NAME",     "db_escolares"),
    "charset":  "utf8mb4",
}


def get_connection():
    return mysql.connector.connect(**DB_CONFIG)


# ──────────────────────────────────────────────
# GET /check/<matricula>
# Respuesta estándar para el orquestador
# ──────────────────────────────────────────────
@app.route("/check/<matricula>", methods=["GET"])
def check(matricula):
    try:
        conn = get_connection()
        cur  = conn.cursor(dictionary=True)

        # Usamos la vista ya definida en el SQL
        cur.execute(
            "SELECT * FROM v_check_escolares WHERE matricula = %s",
            (matricula,)
        )
        row = cur.fetchone()
        cur.close()
        conn.close()

        if row is None:
            # Matrícula no existe en el sistema
            return jsonify({
                "departamento": "Escolares",
                "matricula":    matricula,
                "adeudo":       False,
                "total_pendientes": 0,
                "mensaje":      "Matrícula no registrada en Escolares",
            }), 200

        tiene_adeudo = bool(row["tiene_adeudo"])
        return jsonify({
            "departamento":     "Escolares",
            "matricula":        matricula,
            "nombre_completo":  row["nombre_completo"],
            "adeudo":           tiene_adeudo,
            "total_pendientes": int(row["total_pendientes"]),
            "mensaje":          "Tiene adeudos pendientes en Escolares"
                                if tiene_adeudo
                                else "Sin adeudos en Escolares",
        }), 200

    except Error as e:
        return jsonify({
            "departamento": "Escolares",
            "matricula":    matricula,
            "error":        str(e),
        }), 500


# ──────────────────────────────────────────────
# GET /adeudos/<matricula>
# Detalle completo de adeudos (útil para debug/UI)
# ──────────────────────────────────────────────
@app.route("/adeudos/<matricula>", methods=["GET"])
def adeudos(matricula):
    try:
        conn = get_connection()
        cur  = conn.cursor(dictionary=True)
        cur.execute(
            """
            SELECT ae.id_adeudo, t.categoria, t.nombre AS tipo,
                   ae.descripcion, ae.monto, ae.estatus,
                   ae.fecha_registro, ae.fecha_limite
            FROM   adeudos_escolares ae
            JOIN   tipos_adeudo_esc  t  ON t.id_tipo = ae.id_tipo
            WHERE  ae.matricula = %s
              AND  ae.estatus IN ('Pendiente','Vencido','En Proceso')
            ORDER BY ae.fecha_registro DESC
            """,
            (matricula,)
        )
        rows = cur.fetchall()
        # Convertir objetos date/datetime a string para JSON
        for r in rows:
            for k, v in r.items():
                if hasattr(v, "isoformat"):
                    r[k] = v.isoformat()
        cur.close()
        conn.close()
        return jsonify({"departamento": "Escolares", "matricula": matricula, "adeudos": rows}), 200

    except Error as e:
        return jsonify({"error": str(e)}), 500


# ──────────────────────────────────────────────
# GET /alumno/<matricula>
# Datos generales del alumno
# ──────────────────────────────────────────────
@app.route("/alumno/<matricula>", methods=["GET"])
def alumno(matricula):
    try:
        conn = get_connection()
        cur  = conn.cursor(dictionary=True)
        cur.execute(
            """
            SELECT a.matricula,
                   CONCAT(a.nombre,' ',a.apellido_paterno,' ',a.apellido_materno) AS nombre_completo,
                   a.email, a.telefono, a.semestre_actual, a.turno, a.estatus,
                   c.nombre AS carrera
            FROM   alumnos  a
            JOIN   carreras c ON c.id_carrera = a.id_carrera
            WHERE  a.matricula = %s
            """,
            (matricula,)
        )
        row = cur.fetchone()
        cur.close()
        conn.close()
        if row is None:
            return jsonify({"error": "Alumno no encontrado"}), 404
        for k, v in row.items():
            if hasattr(v, "isoformat"):
                row[k] = v.isoformat()
        return jsonify(row), 200

    except Error as e:
        return jsonify({"error": str(e)}), 500


# ──────────────────────────────────────────────
# GET /health
# ──────────────────────────────────────────────
@app.route("/health", methods=["GET"])
def health():
    try:
        conn = get_connection()
        conn.close()
        return jsonify({"status": "ok", "nodo": "escolares"}), 200
    except Error as e:
        return jsonify({"status": "error", "detail": str(e)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=False)
