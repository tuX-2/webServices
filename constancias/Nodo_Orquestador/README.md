# Nodo Orquestador — Constancias de No Adeudo

## Descripción
Centraliza las consultas a los cuatro nodos periféricos y emite el
veredicto final de constancia de no adeudo.

---

## Tabla de IPs y puertos

| Nodo              | Variable de entorno        | IP (LAN)          | Puerto |
|-------------------|----------------------------|-------------------|--------|
| **Orquestador**   | —                          | `192.168.1.??`    | 8000   |
| Escolares         | `NODO_ESCOLARES`           | `192.168.1.XX`    | 5001   |
| Biblioteca        | `NODO_BIBLIOTECA`          | `192.168.1.YY`    | 5002   |
| Lab. Redes        | `NODO_LAB_REDES`           | `192.168.1.ZZ`    | 5003   |
| Lab. Electrónica  | `NODO_LAB_ELECTRONICA`     | `192.168.1.WW`    | 5004   |

> Sustituye XX/YY/ZZ/WW con las IPs reales al llegar al laboratorio.

---

## Inicio rápido

### Con Docker Compose (recomendado)
```bash
# 1. Editar IPs en docker-compose.yml
# 2. Construir e iniciar
docker compose up --build -d

# Ver logs
docker compose logs -f
```

### Sin Docker (desarrollo local)
```bash
pip install -r requirements.txt

NODO_ESCOLARES=http://192.168.1.XX:5001 \
NODO_BIBLIOTECA=http://192.168.1.YY:5002 \
NODO_LAB_REDES=http://192.168.1.ZZ:5003 \
NODO_LAB_ELECTRONICA=http://192.168.1.WW:5004 \
python app.py
```

---

## API Reference

Todos los endpoints están bajo el prefijo `/api/v1`.
La raíz `/` queda libre para montar la interfaz gráfica futura.

### `GET /api/v1/constancia/<matricula>`
Consulta todos los nodos en paralelo y devuelve el veredicto final.

**Ejemplo:**
```
GET http://localhost:8000/api/v1/constancia/2020001
```

**Respuesta exitosa (200):**
```json
{
  "matricula": "2020001",
  "nombre_alumno": "Juan Pérez López",
  "estatus": "APROBADO",
  "aprobado": true,
  "timestamp": "2026-04-26T15:00:00+00:00",
  "request_id": "a1b2c3d4-...",
  "resumen": {
    "total_nodos": 4,
    "nodos_online": 4,
    "nodos_con_adeudo": 0
  },
  "detalles": [
    {
      "departamento": "Escolares",
      "matricula": "2020001",
      "nombre_completo": "Juan Pérez López",
      "adeudo": false,
      "total_pendientes": 0,
      "mensaje": "Sin adeudos en Escolares",
      "online": true,
      "http_status": 200
    },
    ...
  ]
}
```

**Si hay adeudos (`estatus: "RECHAZADO"`):**  
Igual que arriba pero `"aprobado": false` y algún nodo tendrá `"adeudo": true`.

**Si un nodo está offline:**  
El nodo aparece con `"online": false, "error": "Nodo no disponible"`.
El orquestador cuenta eso como adeudo (política conservadora).

---

### `GET /api/v1/nodos`
Estado de conectividad de todos los nodos periféricos.

```json
{
  "timestamp": "2026-04-26T15:00:00+00:00",
  "nodos": [
    { "nodo": "escolares",     "url": "http://...", "online": true,  "status": "ok" },
    { "nodo": "biblioteca",    "url": "http://...", "online": false, "status": "offline" },
    ...
  ]
}
```

---

### `GET /api/v1/health`
Health check del propio orquestador.

```json
{ "status": "ok", "nodo": "orquestador", "version": "1.0", "timestamp": "..." }
```

---

### `GET /api/v1/config`
Configuración activa (IPs y timeout).

```json
{
  "nodos": {
    "escolares": "http://192.168.1.XX:5001",
    ...
  },
  "timeout": 4
}
```

---

## Notas para la interfaz gráfica futura

- **CORS habilitado**: el frontend puede estar en cualquier origen.
- **Blueprint `/api/v1`**: la raíz `/` está libre; monta el frontend ahí.
- **`nombre_alumno`**: disponible en la respuesta de `/constancia` si Escolares
  está online; úsalo para mostrar el nombre en la UI.
- **`resumen`**: contadores listos para mostrar en tarjetas/dashboard.
- **`detalles[]`**: array uniforme; cada nodo tiene `online`, `adeudo`,
  `departamento` — ideal para una tabla de resultados.
- **`X-Request-ID`** en cabeceras: para correlacionar logs con la UI.
