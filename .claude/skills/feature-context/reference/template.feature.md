# Contexto — <Nombre de la persona> (rama: <nombre-exacto-de-la-rama>)

> Copia este archivo a `contexts/people/<nombre-exacto-de-la-rama>.feature.md`
> y complétalo. El nombre del archivo debe coincidir con el de la rama para
> que los agentes lo encuentren automáticamente.

## Rol de usuario que atiende esta funcionalidad

Cliente | Propietario | Administrador del sistema

Feature: <nombre corto de la funcionalidad, ej. "Reserva de habitación">

  Scenario: <caso principal>
    Given <estado inicial / quién y con qué datos>
    When <acción concreta del usuario>
    Then <resultado esperado, verificable>

  Scenario: <caso alterno o de error>
    Given <estado inicial>
    When <acción>
    Then <resultado esperado, incluyendo el manejo del error>

  Scenario: <caso de borde relevante, si aplica>
    Given ...
    When ...
    Then ...

## Alcance técnico

- **Carpetas donde trabajo**: lib/... (sé específico: vistas, controllers,
  modelos, servicios concretos)
- **Depende de** (otra persona/funcionalidad, o "ninguna"): ...
- **De quién depende trabajo mío** (para avisarle de cambios): ...
- **Fuera de alcance de esta rama** (para que ningún agente lo asuma): ...
- **Decisiones ya tomadas específicas de esta funcionalidad** (si las hay,
  distintas de las decisiones globales pendientes del proyecto): ...

## Notas para los agentes

- Cualquier nota puntual que un agente deba saber y que no esté ya en
  `project-context` (por ejemplo: "esta pantalla reemplaza un mock que
  existía en views/old_motel_list.dart, bórralo al terminar").
