"""
Nodo: LABORATORIO DE REDES  (periférico)
Puerto: 5003
BD:     db_lab_redes
Vista:  v_check_lab_redes
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
    "database": os.environ.get("DB_NAME",     "db_lab_redes"),
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
            "SELECT * FROM v_check_lab_redes WHERE matricula = %s",
            (matricula,)
        )
        row = cur.fetchone()
        cur.close()
        conn.close()

        if row is None:
            return jsonify({
                "departamento":     "Lab. Redes",
                "matricula":        matricula,
                "adeudo":           False,
                "total_pendientes": 0,
                "mensaje":          "Sin adeudos en Lab. Redes",
            }), 200

        tiene_adeudo = bool(row["tiene_adeudo"])
        return jsonify({
            "departamento":     "Lab. Redes",
            "matricula":        matricula,
            "adeudo":           tiene_adeudo,
            "total_pendientes": int(row["total_pendientes"]),
            "detalle":          row["detalle"],
            "mensaje":          "Tiene adeudos pendientes en Lab. Redes"
                                if tiene_adeudo
                                else "Sin adeudos en Lab. Redes",
        }), 200

    except Error as e:
        return jsonify({
            "departamento": "Lab. Redes",
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
            FROM   adeudos_lab_redes
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
        return jsonify({"departamento": "Lab. Redes", "matricula": matricula, "adeudos": rows}), 200

    except Error as e:
        return jsonify({"error": str(e)}), 500


# ──────────────────────────────────────────────
# GET /equipos/<matricula>
# Préstamos de equipo activos/vencidos
# ──────────────────────────────────────────────
@app.route("/equipos/<matricula>", methods=["GET"])
def equipos(matricula):
    try:
        conn = get_connection()
        cur  = conn.cursor(dictionary=True)
        cur.execute(
            """
            SELECT pe.id_prestamo, e.nombre AS equipo, e.tipo,
                   pe.fecha_prestamo, pe.fecha_limite,
                   pe.fecha_devolucion, pe.estatus
            FROM   prestamos_equipo pe
            JOIN   equipos          e  ON e.id_equipo = pe.id_equipo
            WHERE  pe.matricula = %s
              AND  pe.estatus IN ('Activo','Vencido','Dañado')
            ORDER  BY pe.fecha_prestamo DESC
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
        return jsonify({"departamento": "Lab. Redes", "matricula": matricula, "equipos": rows}), 200

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
        return jsonify({"status": "ok", "nodo": "lab_redes"}), 200
    except Error as e:
        return jsonify({"status": "error", "detail": str(e)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8080, debug=False)
