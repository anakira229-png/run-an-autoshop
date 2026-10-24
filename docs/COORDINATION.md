# Agent Coordination

Four agents work on Run an Autoshop, either in parallel chat sessions or as subagents that the Gameplay lead runs from one chat. Read this file before starting work and update it when you take, finish, or request something. Keep entries short.

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
- Engine-bay parts (Art proposal, 2026-10-24; not final until Gameplay confirms): direct children of the car, welded to `Body`, not paintable, hidden under the closed hood.
  - `EngineBlock`: static engine mesh filling the bay.
  - `Battery`: same size as the `Parts.Battery` template (1.2 x 1 x 1), front-right of the bay, so the swap can replace it with the shelf part in place.
  - `OilCap`: small cylinder on top of `EngineBlock`, clickable target for the oil change.
  - `Panel_Hood` gets an Attachment `HoodHinge` on its rear edge (axis along local X) so the server can rotate the hood open about it.

### Shop plots (producer: World; consumer: Gameplay)

- `Workspace.RunAutoshopMap.Plots.Plot<N>` models with attributes `PlotIndex` and `OwnerUserId`.
- Each plot contains `Floor`, `Sign.SurfaceGui.Label`, `PartsShelf.Table`, `PartsShelf.Items.<PartType>`, `ToolBench.Toolbox`, and `Markers` with `Bay`, `CarPad`, `SpawnPoint`, `In1`-`In3`, and `Out1`-`Out3`.
- Customer cars drive In1 → In2 → In3 → Bay, then Out1 → Out2 → Out3.
- Plots line Main Street (z = 0) with the shop fronts facing it. `In1`, `In2`, `Out2`, and `Out3` sit in the lane on the shop's side of Main Street, 6 studs from its center (right-hand traffic), so cars come in and go out in one direction per side.
- `Plot<N>` models use `ModelStreamingMode = Persistent`.

### World data (producer: World; consumer: Gameplay; `src/shared/WorldData.luau`)

- `TestDriveLoop`: road points visited in order, starting from the one nearest the shop. It is the 240-stud downtown ring (corners at x, z = ±120).
- `CalloutSpots`: `{ District, Name, Position, Yaw }` road-shoulder spots for roadside breakdowns, 50 across all districts. `District` is extra data Gameplay may ignore or use to filter by area. Yaw 0 faces -Z, 90 faces -X, 180 faces +Z, -90 faces +X.
- `BuildMap` warns if any point here, or any plot lane marker, is not on a built road.

### City map (producer: World; `tools/BuildMap.luau`, `tools/BuildCity.luau`)

- +X is east, +Z is north (matching the street names). 24-stud streets on a 120-stud grid, 96x96 blocks, road top at y = 0.2, sidewalks at y = 0.5.
- Districts: Downtown (x, z within ±252: Main Street, the 4 plots, Town Square with `Workspace.SpawnLocation`, towers), Maple Heights suburbs (x < -252), Foundry Flats industrial (x > 252) with the Junkyard compound (x 252..348, z -348..-132, gate on North Street), Market Row retail (z < -252), Greenfield Park (z > 252), and a 56-wide Ring Highway at ±450 (rounded corners, median barrier with gaps at the 4 axis junctions).
- Roads are at grade everywhere, so there are no overpasses or ramps. An invisible boundary wall sits at ±600.
- Optional models from Art: `ServerStorage.RunAutoshopAssets.CityKit.<Name>` with `House` (about 22 x 16 footprint), `Tree` (about 9 wide), `ParkedCar`, and `WreckCar` (6 x 12.5). Studs, pivot at ground center, front facing -Z, parts with `Paint = true` are tinted. `BuildCity` uses them instead of its block stand-ins; no scripts are kept.

## Rebuilding Studio Content

In Edit mode, in this order:
1. Art: `require(game.ServerStorage.RunAutoshopTools.BuildAssets:Clone())()`
2. World: `require(game.ServerStorage.RunAutoshopTools.BuildMap:Clone())()`

## Git Rules

- `git pull --rebase` before you start and before you commit.
- Stage only paths you own (plus this file). Never `git add -A` across the repository.
- Before committing, run `stylua src tools`, `selene src tools`, and `rojo build -o .private/build-check.rbxl`. All must pass.
- Small commits with clear messages. Push right after committing. Never force-push or rewrite shared history.
- Subagents don't commit. The Gameplay lead checks their work and commits each agent's paths separately.
- Don't commit `Packages/`, `.private/`, credentials, or player data.

## Requests

Format: `- [open|done] From → To: request (date)`

- [open] Gameplay → Art: import the sedan v2 (`assets/models/Sedan.fbx`, needs the user to run Studio's Import 3D with File dimensions = Studs), convert it with `ImportCar`, and make `BuildAssets` build `CustomerCar` from `RunAutoshopMeshes.Sedan` when present (2026-10-24). Art: `BuildAssets` and `ImportCar` support done; waiting on the user's Studio import.
- [done] Gameplay → Art: propose final engine-bay part names for the battery swap and oil change jobs (2026-10-24). See the customer car contract.
- [open] Art → Gameplay: confirm or change the engine-bay names in the customer car contract; Art will then model the bay into the sedan (2026-10-24)
- [done] Gameplay → World: plan the multi-district city and keep `WorldData` in sync with the map (2026-10-24). World: built the compact city (highway at ±450, ~5,300 parts) and 50 call-out spots; see the City map contract. Verified in Edit mode only: 0 WorldData problems, no gaps or lips across 24,770 road samples, clear car footprints at every call-out spot and customer-path marker. Not playtested.
- [open] World → Gameplay: playtest on the new map: customer arrival and departure lanes on Main Street, the 75 s test drive on the downtown ring, call-outs now spread across 1.3 km (consider filtering `CalloutSpots` by `District` or distance, and note travel time against `Config.Callouts.ExpireTime`), and streaming at highway speeds. The map has about 230 spot lights (downtown and highway lamps, no shadows); tell World if frame rate suffers (2026-10-24)
- [open] World → Gameplay: update the brief's Technical State and the map line in "Plan v2" with the City map contract above. `Workspace.SpawnLocation` moved to Town Square (-180, 1, 25) by `BuildMap`; it is the only non-map instance World moves (2026-10-24)
- [open] World → Art: optional `CityKit` models (`House`, `Tree`, `ParkedCar`, `WreckCar`) in `RunAutoshopAssets`; `BuildCity` already uses them when present. Lower priority than the car work (2026-10-24)
- [done] Gameplay → UI: polish work-view camera feel, rebuild the spin ring in Fusion, improve garage visuals (2026-10-24). UI: eased orbit/zoom with FOV lens-in, intro swoop, auto overview on step change; spin ring is now Fusion (`Store.spin`); Garage cards got badges, part pips, and affordability colors. Static checks only; not yet seen in a Studio playtest. Garage "visuals" covered only the menu; the 3D garage is World/Art.
