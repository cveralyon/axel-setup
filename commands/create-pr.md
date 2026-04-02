# Create a Pull Request

- Check that I'm in a branch other than `main`, `staging`, or `prod`. If not, bail and explain.
- Run `git status` to see all changes
- If there's unstaged or staged work that hasn't been committed, commit all relevant code first
  - Follow commit format: `<tipo> (Modelo/Archivo): Mensaje descriptivo`
  - Max 6 files per commit, grouped by model/functionality
- Use `gh pr create` to open a PR with:
  - Title: `<feature_area>: <Title>` (80 chars or less)
  - Body: TLDR (2 sentences max) + 1-3 bullet points explaining what's changing
- Always paste the PR link in the response
- Prepend `GIT_EDITOR=true` to git commands to avoid blocking
- **NEVER use `--no-verify`**
