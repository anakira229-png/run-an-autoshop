# Roblox Development

Workspace for an AI-assisted Roblox game. Game code and tooling will be added as development begins.

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

Test gameplay changes in Roblox Studio before committing. This repository does not yet configure Rojo or automated tests.