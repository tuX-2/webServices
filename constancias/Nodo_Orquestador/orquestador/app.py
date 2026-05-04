"""
Nodo: ORQUESTADOR  (Principal)
Puerto: 8000
Descripción:
    Centraliza las consultas a los nodos periféricos y emite el
    veredicto final de constancia de no adeudo.

Arquitectura preparada para UI:
    - Todos los endpoints devuelven JSON estructurado y consistente.
    - CORS habilitado para que un frontend externo pueda consumir la API.
    - Cabecera X-Request-ID en cada respuesta para trazabilidad.
    - Blueprint "api_v1" bajo el prefijo /api/v1 — la futura UI puede
      montarse en la raíz "/" sin colisiones.
"""

import os
import uuid
import logging
import concurrent.futures
from datetime import datetime, timezone

import requests
from flask import Flask, jsonify, Blueprint, g
from flask_cors import CORS

# ──────────────────────────────────────────────────────────────────────────────
# Configuración de logging
# ──────────────────────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
log = logging.getLogger("orquestador")

# ──────────────────────────────────────────────────────────────────────────────
# Nodos periféricos  (IPs configurables via variables de entorno)
# ──────────────────────────────────────────────────────────────────────────────
NODOS = {
    "escolares": os.getenv("NODO_ESCOLARES"),
    "biblioteca": os.getenv("NODO_BIBLIOTECA"),
    "lab_redes": os.getenv("NODO_LAB_REDES"),
    "lab_electronica": os.getenv("NODO_LAB_ELECTRONICA"),
}

TIMEOUT = int(os.environ.get("NODO_TIMEOUT", 4))   # segundos por petición

# ──────────────────────────────────────────────────────────────────────────────
# Flask + CORS
# ──────────────────────────────────────────────────────────────────────────────
app = Flask(__name__)
app.config['JSON_AS_ASCII'] = False
CORS(app)   # permite peticiones desde cualquier origen (frontend futuro)

# ──────────────────────────────────────────────────────────────────────────────
# Middleware: X-Request-ID en cada respuesta
# ──────────────────────────────────────────────────────────────────────────────
@app.before_request
def asignar_request_id():
    g.request_id = str(uuid.uuid4())

@app.after_request
def agregar_headers(response):
    response.headers["X-Request-ID"] = getattr(g, "request_id", "—")
    response.headers["X-Powered-By"] = "Orquestador/1.0"
    return response

# ──────────────────────────────────────────────────────────────────────────────
# Blueprint  /api/v1  — la UI futura puede usar la raíz "/" libremente
# ──────────────────────────────────────────────────────────────────────────────
api = Blueprint("api_v1", __name__, url_prefix="/api/v1")


# ──────────────────────────────────────────────────────────────────────────────
# Función auxiliar: consultar un nodo periférico
# ──────────────────────────────────────────────────────────────────────────────
def _consultar_nodo(nombre: str, base_url: str, matricula: str) -> dict:
    """
    Consulta GET /<base_url>/check/<matricula>.
    Siempre devuelve un dict con al menos: departamento, adeudo, online.
    """
    url = f"{base_url}/check/{matricula}"
    try:
        r = requests.get(url, timeout=TIMEOUT)
        r.raise_for_status()
        data = r.json()
        data["online"]       = True
        data["http_status"]  = r.status_code
        log.info("[%s] %s → adeudo=%s", nombre, matricula, data.get("adeudo"))
        return data

    except requests.exceptions.ConnectionError:
        log.warning("[%s] OFFLINE (ConnectionError)", nombre)
    except requests.exceptions.Timeout:
        log.warning("[%s] TIMEOUT después de %ss", nombre, TIMEOUT)
    except requests.exceptions.HTTPError as e:
        log.warning("[%s] HTTP error: %s", nombre, e)
    except Exception as e:
        log.warning("[%s] error inesperado: %s", nombre, e)

    return {
        "departamento": nombre,
        "matricula":    matricula,
        "adeudo":       True,       # falla = bloquear por precaución
        "online":       False,
        "error":        "Nodo no disponible",
    }


# ──────────────────────────────────────────────────────────────────────────────
# ENDPOINT PRINCIPAL
# GET /api/v1/constancia/<matricula>
# ──────────────────────────────────────────────────────────────────────────────
@api.route("/constancia/<matricula>", methods=["GET"])
def constancia(matricula):
    """
    Consulta todos los nodos en paralelo y emite el veredicto.

    Respuesta JSON:
    {
        "matricula":    "2020001",
        "estatus":      "APROBADO" | "RECHAZADO",
        "aprobado":     true | false,
        "timestamp":    "2026-04-26T15:00:00Z",
        "request_id":   "<uuid>",
        "nombre_alumno": "...",          # si Escolares lo devuelve
        "resumen": {
            "total_nodos":      4,
            "nodos_online":     4,
            "nodos_con_adeudo": 0
        },
        "detalles": [ { ...respuesta de cada nodo... } ]
    }
    """
    log.info("Consulta constancia → matrícula=%s", matricula)

    # Consultar todos los nodos en paralelo
    with concurrent.futures.ThreadPoolExecutor(max_workers=len(NODOS)) as pool:
        futuros = {
            pool.submit(_consultar_nodo, nombre, url, matricula): nombre
            for nombre, url in NODOS.items()
        }
        detalles = [f.result() for f in concurrent.futures.as_completed(futuros)]

    # Ordenar siempre igual (escolares primero para extraer nombre)
    orden = {"escolares": 0, "biblioteca": 1, "lab_redes": 2, "lab_electronica": 3}
    detalles.sort(key=lambda d: orden.get(d.get("departamento", "").lower().replace(". ", "_").replace(" ", "_"), 99))

    # Calcular veredicto
    aprobado        = all(not d.get("adeudo", True) for d in detalles)
    nodos_online    = sum(1 for d in detalles if d.get("online", False))
    nodos_con_adeudo = sum(1 for d in detalles if d.get("adeudo", False))

    # Intentar extraer nombre del alumno desde Escolares
    nombre_alumno = None
    for d in detalles:
        if d.get("departamento", "").lower() == "escolares":
            nombre_alumno = d.get("nombre_completo")
            break

    return jsonify({
        "matricula":     matricula,
        "nombre_alumno": nombre_alumno,
        "estatus":       "APROBADO" if aprobado else "RECHAZADO",
        "aprobado":      aprobado,
        "timestamp":     datetime.now(timezone.utc).isoformat(),
        "request_id":    g.request_id,
        "resumen": {
            "total_nodos":       len(NODOS),
            "nodos_online":      nodos_online,
            "nodos_con_adeudo":  nodos_con_adeudo,
        },
        "detalles": detalles,
    }), 200


# ──────────────────────────────────────────────────────────────────────────────
# GET /api/v1/nodos
# Estado de conectividad de todos los nodos (ping /health)
# ──────────────────────────────────────────────────────────────────────────────
@api.route("/nodos", methods=["GET"])
def estado_nodos():
    """
    Devuelve el estado de cada nodo periférico consultando /health.
    Útil para que la futura UI muestre un panel de estado en tiempo real.
    """
    def _ping(nombre, base_url):
        try:
            r = requests.get(f"{base_url}/health", timeout=TIMEOUT)
            data = r.json()
            return {
                "nodo":   nombre,
                "url":    base_url,
                "online": True,
                "status": data.get("status", "ok"),
            }
        except Exception:
            return {"nodo": nombre, "url": base_url, "online": False, "status": "offline"}

    with concurrent.futures.ThreadPoolExecutor(max_workers=len(NODOS)) as pool:
        resultados = list(pool.map(lambda kv: _ping(*kv), NODOS.items()))

    return jsonify({
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "nodos":     resultados,
    }), 200


# ──────────────────────────────────────────────────────────────────────────────
# GET /api/v1/health
# Health check del propio orquestador
# ──────────────────────────────────────────────────────────────────────────────
@api.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status":  "ok",
        "nodo":    "orquestador",
        "version": "1.0",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }), 200


# ──────────────────────────────────────────────────────────────────────────────
# GET /api/v1/config
# Expone la configuración de nodos (sin datos sensibles)
# ──────────────────────────────────────────────────────────────────────────────
@api.route("/config", methods=["GET"])
def config():
    return jsonify({
        "nodos":   {k: v for k, v in NODOS.items()},
        "timeout": TIMEOUT,
    }), 200


# ──────────────────────────────────────────────────────────────────────────────
# Registro del blueprint y arranque
# ──────────────────────────────────────────────────────────────────────────────
app.register_blueprint(api)


if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    log.info("Orquestador iniciando en 0.0.0.0:%s", port)
    log.info("Nodos configurados: %s", NODOS)
    app.run(host="0.0.0.0", port=port, debug=False)

