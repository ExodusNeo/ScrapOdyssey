---
name: scrap-odyssey
description: >
  Comprehensive engineering and design skill for developing, maintaining, and expanding Scrap Odyssey,
  an industrial sci-fi Roblox simulator built in Luau. Covers authoritative server architecture,
  close-quarters mining combat, component grouping into child Models, procedural non-linear junkyards,
  tool building and grip kinematics, Blender MCP 3D prototyping, Studio deployment, and live testing.
  Use whenever working on Scrap Odyssey gameplay, tools, zones, UI, networking, or deployment.
---

# Scrap Odyssey Development Skill

Use this skill when making architectural, gameplay, visual, or systemic changes to **Scrap Odyssey**.

---

## 🧭 Source of Truth & Project Rules

1. **Local Files Are Authoritative**:
   - All production Luau code resides under `src/`.
   - Never write code exclusively into Roblox Studio without committing it to `src/`.
   - After any local code changes, deploy to the live Roblox Studio session using:
     ```powershell
     python deploy_to_studio.py
     ```

2. **Mandatory Component Grouping (Strict Rule)**:
   - When building any multi-part 3D object (weapons, props, workbenches, machinery, decorations):
     - **Always group sub-components into logical child `Model` containers** inside the parent instance.
     - Examples for a Tool:
       - `tool.Handle` (Part, direct child of Tool)
       - `tool.GripComponents` (Model containing grip rings, pommel, knuckle guard)
       - `tool.ChassisAssembly` (Model containing engine, housing, cylinders, hoses)
       - `tool.HeadAssembly` / `tool.EnergyBlade` (Model containing jaws, auger cones, plasma blade, teeth)
       - `tool.Core` (Model containing neon core, point light, particle emitters)
     - For static props (e.g. table, terminal):
       - Group into `Legs`, `Tabletop`, `Electronics`, `DisplayPanel`, etc.
   - All parts must be welded to the main base/handle using `WeldConstraint` (`weld.Part0 = basePart`, `weld.Part1 = subPart`).

3. **Close-Quarters Melee Combat**:
   - Mining strictly enforces melee contact (`Range = 8` studs from node surface in `Config.luau`).
   - Ranged targeting or hitting nodes through walls/behind the character is blocked.
   - `ActionController.luau` uses front-facing camera raycasts and directional dot-product cone validation.

4. **Smooth Movement & Upper-Body Animations**:
   - Tool swing animations (`Chop` ID `507768375` and `Slash` ID `522635514`) are strictly upper-body only.
   - Character legs run, sprint, and jump freely while swinging tools with zero freezing or stuttering.

5. **Organic Non-Linear Junkyard Environments**:
   - Sectors/Zones are circular or oval junkyards with peripheral scrap heaps, branching scrap trails, and natural barriers.
   - Avoid flat rectangular planes or single-file linear bridges.
   - All interactable stations (Armory, Recycler Depot, Teleport Pads, Leaderboards) must have clear, unobstructed 10+ stud approach corridors.

---

## 🏗️ System Architecture Reference

| Directory / File | Ownership & Purpose |
| :--- | :--- |
| `src/shared/Modules/Config.luau` | Master data: Zones, Tools, Upgrades, Drones, Quests, Codes, Multipliers, Combat ranges. |
| `src/shared/Modules/Remotes.luau` | Centralized lazy registry for all client-server `RemoteEvent` and `RemoteFunction` instances. |
| `src/shared/Modules/Types.luau` | Strict Luau type definitions for save states, configurations, and network packets. |
| `src/server/Systems/ActionService.luau` | Tool creation (`buildTool`), hit registration, durability, combo streaks, crits. |
| `src/server/Systems/ZoneService.luau` | Sector layout, scrap node spawning (regular & dense variants), anti-gravity void protection. |
| `src/server/Systems/EventService.luau` | Orbital Drop Pod raid bosses, world-space 3D health meters, MVP telemetry. |
| `src/server/Systems/EnvironmentService.luau` | Cosmic skybox, anti-glare ambient lighting, asteroid belt vistas. |
| `src/server/Systems/DataService.luau` | DataStoreService profile persistence, auto-save cycles, session locking. |
| `src/server/Systems/CurrencyService.luau` | Scrap banking, recycling depot sell mechanics, leaderstats synchronization. |
| `src/server/Systems/BackpackService.luau` | Dynamic visual character backpacks with bounded scale caps to preserve camera visibility. |
| `src/client/Controllers/ActionController.luau` | Input handling, hold-to-swing continuous mining, client-side hit prediction. |
| `src/client/Controllers/PetController.luau` | 144Hz `RenderStepped` smooth drone floating, sinusoidal bobbing, formation following. |

---

## 🛠️ Verification & Tooling Workflow

When changing code, always follow this verification sequence:

1. **Deploy Local Edits**:
   ```powershell
   python deploy_to_studio.py
   ```
2. **Studio MCP Live Check**:
   - Start Play mode: `Roblox_Studio.start_stop_play(is_start=True)`
   - Run verification Luau scripts: `Roblox_Studio.execute_luau(datamodel_type="Server"|"Client", code=...)`
   - Capture third-person / in-game visual screenshots: `Roblox_Studio.screen_capture(camera_position=..., look_at_position=...)`
   - Read console logs: `Roblox_Studio.get_console_output()`
   - Stop Play mode: `Roblox_Studio.start_stop_play(is_start=False)`
3. **Blender MCP 3D Inspection** (if creating new models):
   - Prototype and inspect complex meshes via `blender.execute_blender_code` and `blender.get_viewport_screenshot`.
4. **Git Sync**:
   ```powershell
   git add src/
   git commit -m "Description of changes"
   git push origin main
   ```
