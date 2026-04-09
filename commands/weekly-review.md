# Weekly Review

Generate a summary of my work across all Mainder repos for the past 7-10 days, **split by deploy target** (main vs staging) so it's obvious what's in prod, what's in pre-prod, and what's still local/open.

## Steps

1. **Identity & repos**
   - `git config user.email` → confirm identity. If not set, ask.
   - Target repos (iterate):
     - `~/Mainder/Mainder-API`
     - `~/Mainder/SKYLINE-V9`
     - `~/Mainder/MultipostingService`
     - `~/Mainder/AIAgentService`
     - `~/Mainder/Career-Site`
     - `~/Mainder/back-office`
   - Skip any repo that doesn't exist locally (report the skip, don't fail).

2. **For each repo — fetch + gather state**
   - `git fetch origin --prune` (don't mutate local branches).
   - Capture:
     - `git log --first-parent origin/main --since="10 days ago" --author="$EMAIL"` → **main activity**
     - `git log --first-parent origin/staging --since="10 days ago" --author="$EMAIL"` → **staging activity** (if the repo has `origin/staging`; Mainder-API, SKYLINE-V9, MultipostingService do, some others may not)
     - `git log origin/main..origin/staging --first-parent` → **in staging but not in main** (pending prod deploy)
     - `git log origin/staging..origin/main --first-parent` → **in main but not in staging** (unusual; hotfixes or divergence — flag it)
     - Open PRs from me: `gh pr list --author "@me" --state open` (if `gh` is authenticated; otherwise skip)
   - Exclude `schema.rb` and lockfiles from diff summaries but not from the commit list.

3. **Classify every commit**
   - **In prod (main):** merged to `origin/main`.
   - **In staging only:** in `origin/staging` but not in `origin/main` → **pending deploy to prod**.
   - **In main only (not in staging):** unusual; usually hotfix. Flag it.
   - **WIP / unreleased:** on a feature branch, not yet in main or staging. Include if the branch was pushed.
   - **Open PR:** mention even if no commits in the window.

## Output Format

```
## Weekly Review — semana del [fecha_inicio] al [fecha_fin]

### 🟢 En producción (main) — lo que llegó al usuario final
Por repo:

#### Mainder-API
- `abc1234` feat (Offer): ... — owner/repo#NNN
- `def5678` fix (Candidate): ...

#### SKYLINE-V9
- (none)

### 🟡 En staging, pendiente deploy a prod
Estos commits están validados en pre-prod pero todavía no en main. Candidato a cut-release.

#### Mainder-API
- `ghi9012` feat (People Finder): ... — PR#NNN merged a staging [fecha]

### 🔀 En main, no en staging (revisar — puede ser hotfix o divergencia)
Si aparece algo aquí, investigar. Hotfixes legítimos → OK. Si es un merge normal, el staging quedó desincronizado.

- (ideally empty)

### 🛠 WIP / branches sin mergear
Ramas push-eadas pero sin merge a main ni staging.

- `feat/people-finder-locations` (Mainder-API) — último commit hace 2d
- `fix/combobox-revert` (MultipostingService) — listo para PR

### 📬 PRs abiertos
- owner/repo#NNN — título — estado CI — última actualización

### 📊 Breakdown por tipo (agregado de la semana, todos los repos)
- **New Features:** bullets
- **Bug Fixes:** bullets
- **Tech Debt:** bullets
- **Infra/CI:** bullets

### 🧭 Highlight
Párrafo corto conectando el trabajo con impacto de negocio (People Finder adoption, platform stability, team velocity).

### ⚠ Desalineaciones detectadas
- Repo X: main está 3 commits adelante de staging — ¿hotfix pendiente de back-merge?
- Repo Y: PR#NNN mergeado hace 5 días a staging, aún no en main
```

## Notes

- Output in Spanish (neutro/chileno).
- For commits with format `<tipo> (Modelo/Archivo): ...`, preserve the prefix so it's skimmable.
- Don't include commits that aren't mine unless they're on a branch I authored.
- If a repo doesn't have `origin/staging`, mark its staging section as `(sin branch staging — solo main)` and continue.
- Never guess PR numbers. If `gh` can't verify one, omit it rather than fabricating.
- Exclude `schema.rb`, `Gemfile.lock`, `package-lock.json`, `yarn.lock` from breakdown calculations per user preference, but keep them in the commit list if they're the only change.
