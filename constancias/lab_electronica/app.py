"""
Nodo: LABORATORIO DE ELECTRÓNICA  (periférico)
Puerto: 5004
BD:     db_lab_electronica
Vista:  v_check_lab_electronica
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
    "database": os.environ.get("DB_NAME",     "db_lab_electronica"),
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
            "SELECT * FROM v_check_lab_electronica WHERE matricula = %s",
            (matricula,)
        )
        row = cur.fetchone()
        cur.close()
        conn.close()

        if row is None:
            return jsonify({
                "departamento":     "Lab. Electrónica",
                "matricula":        matricula,
                "adeudo":           False,
                "total_pendientes": 0,
                "mensaje":          "Sin adeudos en Lab. Electrónica",
            }), 200

        tiene_adeudo = bool(row["tiene_adeudo"])
        return jsonify({
            "departamento":     "Lab. Electrónica",
            "matricula":        matricula,
            "adeudo":           tiene_adeudo,
            "total_pendientes": int(row["total_pendientes"]),
            "detalle":          row["detalle"],
            "mensaje":          "Tiene adeudos pendientes en Lab. Electrónica"
                                if tiene_adeudo
                                else "Sin adeudos en Lab. Electrónica",
        }), 200

    except Error as e:
        return jsonify({
            "departamento": "Lab. Electrónica",
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
            FROM   adeudos_lab_electronica
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
        return jsonify({"departamento": "Lab. Electrónica", "matricula": matricula, "adeudos": rows}), 200

    except Error as e:
        return jsonify({"error": str(e)}), 500


# ──────────────────────────────────────────────
# GET /componentes/<matricula>
# Préstamos de componentes activos/vencidos
# ──────────────────────────────────────────────
@app.route("/componentes/<matricula>", methods=["GET"])
def componentes(matricula):
    try:
        conn = get_connection()
        cur  = conn.cursor(dictionary=True)
        cur.execute(
            """
            SELECT pc.id_prestamo, c.nombre AS componente, c.tipo,
                   pc.cantidad, pc.fecha_prestamo, pc.fecha_limite,
                   pc.fecha_devolucion, pc.estatus
            FROM   prestamos_componente pc
            JOIN   componentes          c  ON c.id_componente = pc.id_componente
            WHERE  pc.matricula = %s
              AND  pc.estatus IN ('Activo','Vencido','Dañado','Perdido')
            ORDER  BY pc.fecha_prestamo DESC
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
        return jsonify({"departamento": "Lab. Electrónica", "matricula": matricula, "componentes": rows}), 200

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
        return jsonify({"status": "ok", "nodo": "lab_electronica"}), 200
    except Error as e:
        return jsonify({"status": "error", "detail": str(e)}), 500


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=False)
