# payments-qr-java

Aplicación de referencia en Spring Boot **sin dependencias de OpenTelemetry** (sin SDK, API ni anotaciones).
La telemetría la provee la plataforma: el OpenTelemetry Operator inyecta el agente Java al crear el pod.

| Servicio | Endpoint | Rol |
|---|---|---|
| `payments-qr` | `POST /payments/qr` | Orquesta el pago; consulta `fraud-api` |
| `fraud-api` | `POST /risk/score` | Score de riesgo |

Ambos servicios usan la misma imagen; el nombre de servicio lo asigna el Operator desde el Deployment.

## Contrato de negocio

Toda respuesta incluye `X-Business-Operation`, `X-Business-Outcome` y `X-Business-Reason`.

| Escenario | HTTP | Outcome | Reason |
|---|---|---|---|
| Aprobado | 201 | `approved` | `OK` |
| Rechazo por riesgo | **500** | `declined` | `RIESGO_ALTO` |
| Fondos insuficientes | 200 | `declined` | `FONDOS_INSUFICIENTES` |
| Falla de sistema | **200** | `failed` | `ERROR_SISTEMA` |
| Timeout del core | 500 | — (excepción) | — |

Los casos en negrilla son los anti-patrones que la plataforma corrige en el Gateway sin cambiar la aplicación.

## Build

```bash
minikube -p bancoplus image build -t bancoplus/payments-qr:1.0.0 .
```
