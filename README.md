# Run an Autoshop

Own an auto shop, repair customer cars, build your own car, and drive around a city in Roblox.

The game favors quick, satisfying arcade interactions over detailed mechanical simulation. **Run an Autoshop** is the working title, not a cleared commercial name.

## Project Status

Concept and development handoff only. No game code, Studio place, Rojo configuration, or automated gameplay tests have been added to this repository.

- [Game brief](docs/GAME_BRIEF.md): confirmed direction, proposed first playable, open decisions, and next steps.
- [Copilot instructions](.github/copilot-instructions.md): project context for future chat sessions.
- [GitHub repository](https://github.com/anakira229-png/run-an-autoshop): public source and version history.

## Next Chat

Open this workspace in the new chat and start with:

```text
Read .github/copilot-instructions.md and docs/GAME_BRIEF.md.
Continue Run an Autoshop, a Roblox game about owning an auto shop,
repairing customer cars, building a personal car, and city freeroaming.
Keep repairs arcade-style. Help me settle the open scope decisions,
then agree on the smallest playable prototype before implementation.
```

## Gameplay Loop

Take a repair job, fix the customer car, earn money, improve your shop and personal car, then drive around the city and return for more jobs. Expansion ideas and exact progression are not yet approved scope.

## Version Control

- Keep game source and intentional shared assets in Git.
- Local binary Studio places (`.rbxl`), credentials, logs, and local tools are ignored.
- Store local Studio snapshots outside the repository or in `.private/`.
- Never commit passwords, API keys, authentication cookies, or player data. Ignore rules are not a complete secrets scanner.
- Review staged changes before each commit, especially because this repository is public.
- Publishing the Roblox experience is separate from pushing code to GitHub.

## Daily Workflow

```powershell
git status
git diff
git add <specific-files>
git diff --cached
git commit -m "Describe the change"
git push
```

Test gameplay changes in Roblox Studio before committing. See the game brief for the next implementation steps; there are no game build or test commands yet.