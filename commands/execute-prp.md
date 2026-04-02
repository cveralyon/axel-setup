# Execute PRP

Ejecuta el PRP especificado: `$ARGUMENTS`

Si no se pasa argumento, busca el PRP más reciente en `PRPs/` o pregunta cuál ejecutar.

## Proceso obligatorio

### 1. Lee el PRP completo
Antes de tocar un solo archivo, lee el PRP entero. Entiende el scope total.

### 2. Lee todos los archivos referenciados en "Context"
No asumas nada del código existente — lee los archivos mencionados en el PRP.
Si el PRP dice "sigue el patrón de X", lee X antes de empezar.

### 3. Implementa paso a paso
Sigue el `Implementation Plan` en orden. Por cada paso:
- Implementa
- Si es un bloque lógico completo (modelo, servicio, controller, etc.), haz commit inmediato
- Commit format: `feat (Modelo/Archivo): Descripción` — max 6 archivos por commit

### 4. Valida al finalizar
Corre el `Validation Checklist` del PRP ítem por ítem.
Reporta resultados antes de declarar la feature terminada.

### 5. Marca pasos completados en el PRP
Actualiza el PRP con ✅ en cada paso del `Implementation Plan` al completarlo.

---

## Reglas de ejecución

- **No saltes pasos** — si un paso requiere leer algo primero, léelo
- **No asumas que el PRP está actualizado** — si encuentras discrepancias con el código real, actualiza el PRP y reporta
- **Bloqueantes primero** — si algo bloquea la implementación, repórtalo inmediatamente antes de continuar con pasos posteriores
- **Tests no son opcionales** — el paso de tests es parte de la implementación, no un extra
- **Nunca `--no-verify`** en ningún commit
