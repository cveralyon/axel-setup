# Generate PRP

Lee `INITIAL.md` en el directorio actual y genera un PRP (Product Requirements Prompt) completo
que sirva como blueprint de implementación autosuficiente.

## Proceso obligatorio

### 1. Lee INITIAL.md
Entiende exactamente qué se quiere construir, el contexto de negocio y los criterios de aceptación.

### 2. Explora el codebase sin asumir nada
Antes de escribir una sola línea del PRP, ejecuta en paralelo:
- Lee `.claude/rules/` completo para entender todas las restricciones activas
- Busca con Grep/Glob archivos similares a lo que se va a construir (modelos, servicios, hooks, etc.)
- Lee los archivos más relevantes que el PRP referenciará como ejemplos
- Si hay `docs/` con documentación técnica, léela en la sección relevante

### 3. Genera el PRP en `PRPs/<feature-slug>.md`

El slug del archivo debe ser kebab-case descriptivo (ej: `PRPs/candidate-enrichment.md`).

---

## Estructura del PRP a generar

```markdown
# PRP: [Nombre de la Feature]

## Goal
Qué construir y por qué — conectar con el impacto de negocio en tu proyecto.

## Context

### Archivos clave a leer antes de implementar
Lista de paths absolutos (relativos al repo) con descripción de por qué son relevantes.

### Patrones a seguir
Referencias concretas: "sigue el patrón de X para hacer Y" con paths exactos.

### Restricciones activas
Reglas de `.claude/rules/` que aplican directamente a esta feature (no las repitas, solo referencialas).

## Implementation Plan

Pasos ordenados. Cada paso debe tener:
- Acción concreta
- Path exacto del archivo
- Qué leer primero si aplica

### Paso 1: [Nombre]
...

### Paso N: Tests
Qué specs escribir, qué casos cubrir (happy path, edge cases, unauthorized, not found).

## API Contract (si aplica)
Endpoint, método HTTP, request body, response body, status codes.

## Validation Checklist
- [ ] Todos los tests pasan (`RAILS_ENV=test bundle exec rspec` o `pnpm check`)
- [ ] Sin N+1 queries
- [ ] Lint pasa
- [ ] Criterios de aceptación de INITIAL.md cumplidos
- [ ] Soft delete implementado si aplica (Paranoia)
- [ ] Pundit policy actualizada si aplica
```

---

## Principios del PRP

- **Autosuficiente**: otro Claude debe poder ejecutarlo sin preguntar nada más
- **Sin redundancia**: no repetir reglas que ya están en `.claude/rules/`, solo referenciarlas
- **Específico**: paths concretos, no "algo similar a los servicios existentes"
- **Honesto**: si algo es incierto, marcarlo como "verificar antes de implementar"
