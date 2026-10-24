# Run an Autoshop: Game Brief

## Purpose

Persistent concept and handoff for future development sessions. This is a design starting point, not a claim that any gameplay has been implemented. Keep confirmed requirements separate from proposals.

## Confirmed Direction

- Platform: Roblox.
- Working title: Run an Autoshop. The user wants a simple, descriptive name rather than an abstract brand name. Name availability and trademark clearance have not been checked.
- Each player has their own auto shop.
- Players repair and build cars, including a personal car they can drive.
- A city provides freeroam driving beyond the shop.
- Repair gameplay uses quick arcade interactions, not a deep mechanical simulator.
- More activities may be added later, but none are committed scope yet.

## Agreed Decisions (2026-10-24)

- Devices: PC keyboard and mouse only for now.
- Social model: one shared server with 4 shop plots around a shared road loop. Server size should be set to 4 in Game Settings.
- Collaborative repair: deferred until after the first playable. When added, the owner invites specific players and payouts are split among contributors.
- Visuals: the long-term target is a detailed look; the first playable uses original placeholder geometry.
- Repair jobs: wheel change and body dent. The fault is shown upfront. Customer cars drive in and out on a scripted path.
- Minigames: spin the mouse around a ring to loosen and tighten bolts, with slips for spinning too fast; click glowing dents before they fade. Misses lower a 1-3 star quality rating that scales payout (100/80/60%) and never blocks completion.
- Personal car: assemble from a bare chassis by buying and installing an engine, transmission, battery, seat, and 4 wheels. One part tier; parts do not change stats yet.
- Driving: a simple custom constraint chassis first; reevaluate after playtesting.
- Saving: money, upgrades, part inventory, and installed parts persist in the dev DataStore `RunAutoshop_Dev_v1`. The experience is published privately with Studio API access enabled. Rename the store before any public release.
- One shop upgrade: Better Tools, which makes both minigames easier.
- Starting economy (tunable in `src/shared/Config.luau`): wheel job $60, dent job $80; engine $150, transmission $100, battery $50, seat $40, wheel $25 each; Better Tools $200; start with $0.

## Player Fantasy

Turn a modest workshop into your own car business while creating a car that feels like yours. Repair work should make visible progress, and driving should give that progress a purpose outside the garage.

## Proposed Core Loop

1. Accept a customer repair job at your shop.
2. Identify a clearly communicated fault and complete a short repair interaction.
3. Receive payment and visible feedback that the car is fixed.
4. Spend earnings on shop improvements and parts for your personal car.
5. Install parts, drive around the city, and return to take another job.

This loop is a proposal based on the confirmed concept. Job selection, pricing, progression, and rewards still need design decisions.

## First Playable (Agreed and Implemented)

Validate one complete repair-to-driving loop before building a large map or extensive progression.

- 4 shop plots, each with one repair bay, a personal car pad, a parts shelf, and a tool bench.
- One customer car type with two jobs: wheel change and body dent.
- Short minigames with visible before/after changes: lug nuts disappear and reappear, the flat wheel is swapped, and dents pop out.
- Star-scaled job payouts spent on personal car parts and one tool upgrade.
- One personal car chassis with 8 required part installs before it can drive.
- A compact road loop with a center cross for testing steering, acceleration, braking, getting in and out, and returning to the shop.
- A minimal HUD for money, the current job, car build progress, and a reset-car button.

The prototype uses simple original placeholder geometry. Do not imply production-ready vehicle physics or multiplayer support until tested.

## Later Possibilities

Potential additions, not a release checklist: more repair types, additional car chassis, shop expansion, cosmetic customization, tuning, and driving activities. Add features only after the core loop proves enjoyable.

## Open Decisions

- Whether the first playable's feel (spin rate, dent timing, driving, pricing) is fun; tune after manual playtests.
- Whether to keep the custom chassis or adopt a maintained, appropriately licensed one.
- Detailed art direction and asset budget. Do not purchase assets or promise a schedule without approval.
- DataStore session locking before any public release; the prototype saves without it.
- Monetization has not been designed.

## Development Boundaries

- Make repairing, building, and driving enjoyable before expanding the city.
- Prefer a small, tested implementation over speculative service frameworks or large dependency stacks.
- The server must validate money, ownership, job completion, and part installation. Client visuals must not grant rewards.
- Saves go only to the dev DataStore while the experience is private. Do not add purchases, publishing automation, or account secrets.
- Keep assets original or appropriately licensed; inspect imported models for scripts. Use fictional cars unless rights to branding are established.
- Rojo owns only the three `RunAutoshop` script containers. Never sync over other place content.

## Current Technical State

- Git and GitHub CLI are installed and authenticated on the development machine.
- Repository: https://github.com/anakira229-png/run-an-autoshop (public).
- Branch: main. Repository-local commit identity uses GitHub's noreply address.
- Credentials and local binary Studio snapshots are excluded by the existing ignore rules; exclusions are not a complete secrets scanner.
- Blender MCP is configured in VS Code's user-level MCP settings for reuse across workspaces, using an absolute uvx executable path and localhost port 9876, with safe mode enabled and telemetry disabled. The configured process passed MCP initialization, tool discovery (9 tools), and a read-only scene query against Blender 5.2. No scene changes were made. VS Code may still require the new server to be started or trusted before its tools appear in chat.
- Studio place: "Run An Autoshop!" (placeId 113428819245695), published privately. It started as an empty baseplate. Roblox Studio MCP is connected and was used for building and playtesting.
- Toolchain: Rokit pins Rojo 7.7.1, StyLua 2.6.0, and Selene 0.32.0 (`rokit.toml`). Rojo syncs only `src/shared` to `ReplicatedStorage.RunAutoshop`, `src/server` to `ServerScriptService.RunAutoshop`, and `src/client` to `StarterPlayerScripts.RunAutoshop`. Commands are in the README.
- Map and templates live in Studio (`Workspace.RunAutoshopMap`, `ServerStorage.RunAutoshopAssets`) and are reproducible from `tools/BuildMap.luau`. Rerunning it replaces only those two folders.
- Server code: `PlayerData` (load/save, money, inventory), `Plots` (assignment, owner-only prompts), `Spin` (server-timed spin minigame), `RepairJobs` (customer cycle, jobs, payout), `Shop` (parts shelf, tool bench), `PersonalCar` (install, assembly, driving). Client: HUD, spin minigame UI, and hiding prompts on other players' plots.

### Verified on 2026-10-24

Static: StyLua check, Selene (0 warnings), and `rojo build` pass.

Studio playtests (single player, driven by test scripts through real prompts and remotes):
- Plot claim, sign, teleport, data load, personal chassis, and customer drive-in.
- Full wheel-change job: four steps, slip detection, 3-star payout of $60 paid once; extra spin input after completion paid nothing. Next customer arrived.
- Dent job: accept and start; dents activate and expired dents count as misses.
- Purchases: rejected without enough money, accepted otherwise. Installing requires stock, decrements inventory, and replaces the slot.
- Persistence across a play restart: money and installed parts restored, and the car was rebuilt.
- Completed car (temporarily seeded save, then restored): assembles unanchored, gives the owner network ownership on sitting, drives forward and in reverse, steers in the right direction, stays upright at speed, and coasts down.

Not yet verified:
- Clicking dents to finish a dent job (test scripts cannot simulate clicks).
- Real keyboard driving feel and the HUD and spin UI look and feel.
- Better Tools purchase effects, the reset button, and non-owner seat ejection.
- Two-player plot separation and ownership rejection (needs Studio's local server test with 2 players).
- DataStore failure fallback.

## Next Session

1. Read this brief and the repository instructions.
2. Run `rojo serve` and connect the Rojo plugin in Studio before editing scripts.
3. Manually playtest the unverified items above, then tune `Config.luau` values based on feel.
4. Decide on collaboration, chassis, and art next steps only after the loop feels fun.