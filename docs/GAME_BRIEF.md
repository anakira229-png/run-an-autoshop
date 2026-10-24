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

## Player Fantasy

Turn a modest workshop into your own car business while creating a car that feels like yours. Repair work should make visible progress, and driving should give that progress a purpose outside the garage.

## Proposed Core Loop

1. Accept a customer repair job at your shop.
2. Identify a clearly communicated fault and complete a short repair interaction.
3. Receive payment and visible feedback that the car is fixed.
4. Spend earnings on shop improvements and parts for your personal car.
5. Install parts, drive around the city, and return to take another job.

This loop is a proposal based on the confirmed concept. Job selection, pricing, progression, and rewards still need design decisions.

## Proposed First Playable

Validate one complete repair-to-driving loop before building a large map or extensive progression.

- One small shop with one repair bay.
- One customer car type and two straightforward jobs, such as a wheel change and battery replacement.
- Short interactions with clear progress and visible before/after changes, rather than repetitive clicking without feedback.
- A simple job payout and a way to spend it on a starter personal car or its parts.
- One personal car chassis with a small set of installable parts. Actual part installation matters; do not substitute paint-only customization for the car-building requirement.
- A compact road district for testing steering, acceleration, braking, getting in and out, and returning to the shop.
- A minimal interface for the current job, money, and relevant interactions.

Exact jobs, car assembly depth, and the order of implementation require approval. A prototype can use simple original placeholder geometry. Do not imply production-ready vehicle physics or multiplayer support until tested.

## Later Possibilities

Potential additions, not a release checklist: more repair types, additional car chassis, shop expansion, cosmetic customization, tuning, and driving activities. Add features only after the core loop proves enjoyable.

## Open Decisions

- Audience and target devices: mobile, PC, console, or a subset?
- Social model: separate shops in a shared server, private shop instances, or another layout? Is collaborative repair needed?
- Visual direction: stylized low-poly, classic Roblox, or a more detailed look?
- First playable priorities and the minimum depth of personal car assembly.
- Driving feel and whether to adopt a maintained, appropriately licensed vehicle chassis or use a simple prototype.
- Progression and saving requirements. Monetization has not been designed.
- Time and asset budget. Do not purchase assets or promise a schedule without approval.

## Development Boundaries

- Make repairing, building, and driving enjoyable before expanding the city.
- Prefer a small, tested implementation over speculative service frameworks or large dependency stacks.
- The server must validate money, ownership, job completion, and part installation. Client visuals must not grant rewards.
- Do not add live DataStore writes, purchases, publishing automation, or account secrets during initial scaffolding.
- Keep assets original or appropriately licensed; inspect imported models for scripts. Use fictional cars unless rights to branding are established.
- Agree on file-versus-Studio ownership before introducing Rojo. Never sync over an existing place without confirming the target and preserving its contents.

## Current Technical State

- Git and GitHub CLI are installed and authenticated on the development machine.
- Repository: https://github.com/anakira229-png/run-an-autoshop (public).
- Branch: main. Repository-local commit identity uses GitHub's noreply address.
- Credentials and local binary Studio snapshots are excluded by the existing ignore rules; exclusions are not a complete secrets scanner.
- Workspace contains documentation and Git setup only. No gameplay code, imported assets, tools configuration, or Studio place has been created here.
- Roblox Studio MCP tools are exposed in the chat environment, but no Studio instance connection or playtest has been verified during this setup.
- No game build, formatting, analysis, or test commands exist yet. Document actual commands when the toolchain is chosen.

## Next Session

1. Read this brief and the repository instructions. Keep confirmed direction intact; ask only about unresolved decisions.
2. Agree on target devices, the social model, visual direction, and the proposed first playable.
3. Confirm the intended Studio instance and existing contents before modifying it.
4. Choose a minimal implementation workflow and define a concrete acceptance checklist.
5. Build one small playable loop, test it, and record what was actually verified.

Initial acceptance should cover a repair paying exactly once, correct ownership and part-install rules, and a personal car that can be built to a drivable state and taken around the test district. Add persistence and multiplayer checks when those systems are actually in scope.