# otel-instrumentation

Chart local que empaqueta el recurso `Instrumentation` del OpenTelemetry Operator. Lo consume
`modules/java-autoinstrumentation`.

Empaquetar el recurso como chart desacopla la planificación de Terraform de la existencia del CRD:
`kubernetes_manifest` exige el CRD en tiempo de `plan`, un `helm_release` lo valida en `apply`.

| Valor | Default | Propósito |
|---|---|---|
| `exporter.endpoint` | agente de nodo `:4318` | Destino OTLP/HTTP del agente Java |
| `java.captureResponseHeaders` | `X-Business-*` | Contrato de semántica de negocio |
| `java.extensions` | `[]` | Extensiones corporativas del agente (InnerSource) |
| `sampler.type` | `parentbased_always_on` | El muestreo se decide en el Gateway |
