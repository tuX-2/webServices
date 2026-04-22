"""
Nodo: BIBLIOTECA  (periférico)
Puerto: 5002
BD:     db_biblioteca
Vista:  v_check_biblioteca
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
    "database": os.environ.get("DB_NAME",     "db_biblioteca"),
    "charset":  "utf8mb4",
}


def get_connection():
    return mysql.connector.connect(**DB_CONFIG)


# ──────────────────────────────────────────────
# GET /check/<matricula>
# ──────────────────────────────────────────────
@app.route("/check/<matricula>", methods=["GET"])
def check(matricula):
    try:
        conn = get_connection()
        cur  = conn.cursor(dictionary=True)
        cur.execute(
            "SELECT * FROM v_check_biblioteca WHERE matricula = %s",
            (matricula,)
        )
        row = cur.fetchone()
        cur.close()
        conn.close()

        if row is None:
            return jsonify({
                "departamento":     "Biblioteca",
                "matricula":        matricula,
                "adeudo":           False,
                "total_pendientes": 0,
                "mensaje":          "Sin adeudos en Biblioteca",
            }), 200

        tiene_adeudo = bool(row["tiene_adeudo"])
        return jsonify({
            "departamento":     "Biblioteca",
            "matricula":        matricula,
            "adeudo":           tiene_adeudo,
            "total_pendientes": int(row["total_pendientes"]),
            "detalle":          row["detalle"],
            "mensaje":          "Tiene adeudos pendientes en Biblioteca"
                                if tiene_adeudo
                                else "Sin adeudos en Biblioteca",
        }), 200

    except Error as e:
        return jsonify({
            "departamento": "Biblioteca",
            "matricula":    matricula,
            "error":        str(e),
        }), 500


# ──────────────────────────────────────────────
# GET /adeudos/<matricula>
# ──────────────────────────────────────────────
@app.route("/adeudos/<matricula>", methods=["GET"])
def adeudos(matricula):
    try:
        conn = get_connection()
        cur  = conn.cursor(dictionary=True)
        cur.execute(
            """
            SELECT id_adeudo, tipo, descripcion, monto, estatus, fecha_registro
            FROM   adeudos_biblioteca
            WHERE  matricula = %s AND estatus = 'Pendiente'
            ORDER  BY fecha_registro DESC
            """,
            (matricula,)
        )
        rows = cur.fetchall()
        for r in rows:
            for k, v in r.items():
                if hasattr(v, "isoformat"):
                    r[k] = v.isoformat()
        cur.close()
        conn.close()
        return jsonify({"departamento": "Biblioteca", "matricula": matricula, "adeudos": rows}), 200

    except Error as e:
        return jsonify({"error": str(e)}), 500


# ──────────────────────────────────────────────
# GET /prestamos/<matricula>
# Préstamos activos o vencidos del alumno
# ──────────────────────────────────────────────
@app.route("/prestamos/<matricula>", methods=["GET"])
def prestamos(matricula):
    try:
        conn = get_connection()
        cur  = conn.cursor(dictionary=True)
        cur.execute(
            """
            SELECT p.id_prestamo, m.titulo, m.codigo,
                   p.fecha_prestamo, p.fecha_limite,
                   p.fecha_devolucion, p.estatus
            FROM   prestamos p
            JOIN   material  m ON m.id_material = p.id_material
            WHERE  p.matricula = %s
              AND  p.estatus IN ('Activo','Vencido')
            ORDER  BY p.fecha_prestamo DESC
            """,
            (matricula,)
        )
        rows = cur.fetchall()
        for r in rows:
            for k, v in r.items():
                if hasattr(v, "isoformat"):
                    r[k] = v.isoformat()
        cur.close()
        conn.close()
        return jsonify({"departamento": "Biblioteca", "matricula": matricula, "prestamos": rows}), 200

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
        return jsonify({"status": "ok", "nodo": "biblioteca"}), 200
    except Error as e:
        return jsonify({"status": "error", "detail": str(e)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=False)
