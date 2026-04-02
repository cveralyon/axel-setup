# Daily Briefing

Generate a focused daily briefing for the user.

## Steps

1. **Linear — active issues**
   - Fetch issues assigned to the authenticated user that are In Progress or Todo
   - List them grouped by project/team

2. **Google Calendar — today's agenda**
   - Fetch today's events from the user's primary calendar
   - Show time, title, and meeting link if available

3. **Linear — blocked PRs/issues**
   - Any issues with status Blocked or marked as urgent

## Output Format

```
## Hoy — [fecha]

### Reuniones
- HH:MM — [título] ([link si existe])

### En progreso
- [TEAM-XXX] Título del issue

### Pendiente / Todo
- [TEAM-XXX] Título del issue

### Bloqueado
- [TEAM-XXX] Título del issue — motivo si está en descripción
```

Keep it concise. No filler text. This is a morning briefing.
