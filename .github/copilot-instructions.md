# Run an Autoshop

Read [the game brief](../docs/GAME_BRIEF.md) before planning or implementing gameplay. It is the persistent handoff and separates confirmed requirements, proposals, open decisions, and current technical state.

## Direction

This Roblox game is about owning an auto shop, repairing customer cars, building a personal car, and city freeroaming. Favor quick arcade interactions over mechanical simulation. Do not replace that direction with an unrelated tycoon or driving-only game.

## Workflow

- Confirm unresolved scope choices before implementing the first playable; do not treat proposed features as approved requirements.
- Keep changes small and verify the touched behavior. Distinguish static checks from actual Studio playtests, and state unverified requirements honestly.
- Use Luau for Roblox scripts. Choose the toolchain and source-of-truth boundaries before creating a framework or installing dependencies.
- Confirm the intended Studio instance before modifying it. Preserve existing content; do not sync over unknown scripts or maps.
- Validate rewards, ownership, and part changes on the server. Keep initial work away from live player data and purchases.
- Keep credentials and player data out of this public repository. Preserve the repository-local noreply commit identity.
- Do not publish the Roblox experience, buy assets, or commit and push changes unless the user authorizes those actions.
- Update the game brief when scope or technical state changes so the next session has an accurate handoff.

## Multiple Agents

Four agents (Gameplay, UI, Art, World; defined in `.github/agents/`) work in parallel chat sessions, or the Gameplay lead runs the others as subagents from one chat. Read [the coordination file](../docs/COORDINATION.md) before starting and follow it:

- Edit only the files your agent owns; ask other owners through the coordination file's request list.
- Only the Gameplay agent starts or stops Studio playtests. Others use Studio in Edit mode only, after checking its state and setting the Studio status line.
- Only the Art agent uses Blender.
- Pull with rebase before working and before committing; stage only your own paths; run StyLua, Selene, and the Rojo build before every commit. Committing and pushing your own verified files is authorized; subagents leave commits to the lead.