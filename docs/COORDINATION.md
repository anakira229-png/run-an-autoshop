# Agent Coordination

Four agents work on Run an Autoshop in parallel chat sessions. Read this file before starting work and update it when you take, finish, or request something. Keep entries short.

## Studio Status

Only the Gameplay agent starts or stops playtests. Other agents may use Studio only in Edit mode, and only after `get_studio_state` shows Edit. Set this line before Studio work that changes content (rebuilding assets, rebuilding the map, importing), and reset it to `free` afterward.

- Studio: free

## Ownership

| Agent | Owns (may edit) | Studio / tools |
|---|---|---|
| Gameplay (lead) | `src/server/**`, `src/shared/**` except `WorldData.luau`, `default.project.json`, `rokit.toml`, `wally.toml`, `wally.lock`, `selene.toml`, `stylua.toml`, `.gitignore`, `docs/GAME_BRIEF.md`, `README.md` | Only agent that playtests; owns DataStore test fixtures and the Rojo server |
| UI | `src/client/**` | Studio Edit inspection and screenshots |
| Art | `assets/**`, `tools/BuildAssets.luau`, `tools/ImportCar.luau`; Studio `ServerStorage.RunAutoshopAssets` and `ServerStorage.RunAutoshopMeshes` | Only agent that uses Blender |
| World | `tools/BuildMap.luau`, `tools/BuildCity.luau`, `src/shared/WorldData.luau`; Studio `Workspace.RunAutoshopMap`, `Lighting`, `Baseplate` | Studio Edit mode |

Everyone may edit this file. To change a file you don't own, add a request below instead.

## Contracts

Changing a contract needs a request, and the owner of the consuming code must agree.

### Remotes (owner: Gameplay; `src/shared/Remotes.luau`)

Server to client: `SpinState`, `DentState`, `JobUpdate`, `JobResult`, `Notify`, `RouteState`, `CalloutOffer`, `CalloutState`, `WorkState`, `OpenPanel`. Client to server: `SpinInput`, `ResetCar`, `CalloutRespond`, `WorkAction`, `WorkExit`, `ShopBuy`. Player attributes: `Money`, `Inv_<Part>`, `Installed_<Slot>`, `Tier_<Part>`, `Upgrade_<Name>`, `CarReady`.

### Customer car model (producer: Art; consumer: Gameplay)

- Built in studs, front facing -Z, model pivot at the ground center, `PrimaryPart` = `Body`.
- Required direct children: `Body`, `Cabin`, `Roof`, `Panel_Hood`, `Panel_Left`, `Panel_Right`, `Wheel_FL`, `Wheel_FR`, `Wheel_RL`, `Wheel_RR`. Each wheel has a child `Hub` welded to it.
- Wheels: axle along the wheel's local X, width about 1.2, radius 1.3 to 1.45.
- Paintable parts have the attribute `Paint = true`; the server recolors them per customer.
- Engine-bay names for the battery swap and oil change jobs: proposed `Battery`, `OilCap`, `EngineBlock`, and an openable `Panel_Hood`. Not final until Gameplay confirms.

### Shop plots (producer: World; consumer: Gameplay)

- `Workspace.RunAutoshopMap.Plots.Plot<N>` models with attributes `PlotIndex` and `OwnerUserId`.
- Each plot contains `Floor`, `Sign.SurfaceGui.Label`, `PartsShelf.Table`, `PartsShelf.Items.<PartType>`, `ToolBench.Toolbox`, and `Markers` with `Bay`, `CarPad`, `SpawnPoint`, `In1`-`In3`, and `Out1`-`Out3`.
- Customer cars drive In1 → In2 → In3 → Bay, then Out1 → Out2 → Out3.

### World data (producer: World; consumer: Gameplay; `src/shared/WorldData.luau`)

- `TestDriveLoop`: road points visited in order, starting from the one nearest the shop.
- `CalloutSpots`: `{ Name, Position, Yaw }` road-shoulder spots for roadside breakdowns.

## Rebuilding Studio Content

In Edit mode, in this order:
1. Art: `require(game.ServerStorage.RunAutoshopTools.BuildAssets:Clone())()`
2. World: `require(game.ServerStorage.RunAutoshopTools.BuildMap:Clone())()`

## Git Rules

- `git pull --rebase` before you start and before you commit.
- Stage only paths you own (plus this file). Never `git add -A` across the repository.
- Before committing, run `stylua src tools`, `selene src tools`, and `rojo build -o .private/build-check.rbxl`. All must pass.
- Small commits with clear messages. Push right after committing. Never force-push or rewrite shared history.
- Don't commit `Packages/`, `.private/`, credentials, or player data.

## Requests

Format: `- [open|done] From → To: request (date)`

- [open] Gameplay → Art: import the sedan v2 (`assets/models/Sedan.fbx`, needs the user to run Studio's Import 3D with File dimensions = Studs), convert it with `ImportCar`, and make `BuildAssets` build `CustomerCar` from `RunAutoshopMeshes.Sedan` when present (2026-10-24)
- [open] Gameplay → Art: propose final engine-bay part names for the battery swap and oil change jobs (2026-10-24)
- [open] Gameplay → World: plan the multi-district city and keep `WorldData` in sync with the map (2026-10-24)
- [open] Gameplay → UI: polish work-view camera feel, rebuild the spin ring in Fusion, improve garage visuals (2026-10-24)
