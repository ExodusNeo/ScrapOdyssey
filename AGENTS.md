# AGENTS.md — Scrap Odyssey Project Context & Agent Guide

> **Project Name**: Scrap Odyssey  
> **Engine / Platform**: Roblox (Luau)  
> **Workspace Root**: `D:\RobloxProjects\MyRobloxGame`  
> **Git Remote**: `https://github.com/ExodusNeo/ScrapOdyssey.git` (`main` branch)  
> **Last Updated**: October 2026  

---

## 🚀 Quick Start for AI Agents & Developers

When picking up tasks on this repository, follow this standard operational loop:

1. **Read This Document First**: Understand the system architecture, file structure, and hard constraints before modifying code.
2. **Edit Source Files Locally**: All production game code resides inside `src/`.
3. **Deploy to Roblox Studio**: Always synchronize code changes to the running Roblox Studio session:
   ```powershell
   python deploy_to_studio.py
   ```
4. **Verify Live**: Use Roblox Studio MCP tools (`execute_luau`, `screen_capture`, `get_console_output`, `start_stop_play`) to test in play solo mode.
5. **Version Control**: Commit and push all verified changes:
   ```powershell
   git add src/
   git commit -m "<Clear, descriptive commit message>"
   git push origin main
   ```

---

## 🎮 Game Concept & Aesthetic Vision

- **Genre**: Industrial sci-fi action simulator & incremental salvage game.
- **Core Loop**: Dismantle scrap piles in deep-space junkyards with heavy industrial tools ➔ Collect Scrap ➔ Deposit at Recycler for currency ➔ Upgrade Backpack Cargo & Tools ➔ Hatch and equip salvage Drones ➔ Unlock new Sectors & participate in Orbital Drop Pod raid events ➔ Rebirth for permanent multipliers and Gears.
- **Visual Aesthetic**:
  - Chunky retro-future sci-fi, orbital asteroid belts, cosmic space wreckage.
  - High-contrast materials: Hazard Yellow DiamondPlate, Safety Orange, Electric Cyan, Neon Magenta, Titanium Slate, Dark Alloys, and Brass.
  - Deep-space cosmic skybox with purple/blue nebulae. **No blinding sun glare or harsh daytime disks**.
  - All sectors/zones are circular/oval organic junkyards with branching salvage paths and scrap barriers, avoiding rigid straight-line linear rectangles.

---

## 🏗️ Codebase Architecture

The project follows a strict authoritative server-client architecture written in typed Luau.

```
D:\RobloxProjects\MyRobloxGame\
├── src/
│   ├── shared/
│   │   ├── Modules/
│   │   │   ├── Config.luau          # Master configuration: Zones, Tools, Upgrades, Drones, Quests, Codes
│   │   │   ├── Remotes.luau         # RemoteEvent & RemoteFunction registry
│   │   │   ├── Types.luau           # Strict type contracts and data models
│   │   │   └── DroneVisuals.luau    # Procedural 3D drone models
│   │   └── default.project.json
│   ├── server/
│   │   ├── Main.server.luau         # Server bootstrapper & initialization order
│   │   └── Systems/
│   │       ├── ActionService.luau   # Tool building, mining/scrapping validation, multi-hit durability, combos
│   │       ├── BackpackService.luau # Visual character backpacks with dynamic capacity scaling
│   │       ├── CurrencyService.luau # Scrap banking, Leaderstats, recycling depot
│   │       ├── DataService.luau     # DataStoreService save/load handling with auto-save & session locking
│   │       ├── DebugService.luau    # In-game developer admin console
│   │       ├── EnvironmentService.luau # Skybox, celestial lighting, distant asteroid vista generation
│   │       ├── EventService.luau    # Orbital Drop Pod raid bosses & dynamic meteor events
│   │       ├── LeaderboardService.luau # Telemetry & high-definition surface leaderboards
│   │       ├── MonetizationService.luau# Developer products, Gamepasses, idempotent receipt handling
│   │       ├── PetService.luau      # Drone egg hatching, pet inventory, pet equipping
│   │       ├── QuestService.luau    # Daily quests, unified objectives, 20h claim cooldown
│   │       ├── RebirthService.luau  # Prestige & rebirth system with permanent stat multipliers
│   │       ├── ShopService.luau     # Tool purchases, gear upgrades, cargo capacity upgrades
│   │       └── ZoneService.luau     # Procedural organic zone generation, scrap nodes, recyclers, bridges
│   └── client/
│       ├── ClientMain.luau          # Client bootstrapper & controller initialization
│       └── Controllers/
│           ├── ActionController.luau# Close-quarters melee targeting, hold-to-swing mining, tool animations
│           ├── HUDController.luau   # Top/right HUD, currency indicators, floating damage numbers
│           ├── MenuController.luau  # Upgrades, Armory, Drones, World Map/Fast Travel, Rebirth, Quests
│           ├── MovementController.luau# Sprinting (Shift/L3/Touch) and dynamic FOV
│           ├── PetController.luau   # 144Hz RenderStepped smooth drone floating & sinusoidal bobbing
│           ├── SoundController.luau # 12-channel audio bus, BGM, SFX pitch modulation
│           ├── TutorialController.luau# 5-stage interactive onboarding brief
│           ├── UIController.luau    # ScreenGui management, modal transitions
│           └── VFXController.luau   # Particle sparks, camera shake, visual hit feedback
├── deploy_to_studio.py              # Script pushing local src/ directly into active Studio session
└── default.project.json             # Rojo project file
```

---

## ⚔️ The Arsenal (5 Scrapper Tools)

All weapons in `ActionService.luau` are modeled with custom multi-part geometry, grouped into sub-`Model`s, and configured with natural action grips:

1. **Omni-Wrench** (`OmniWrench`):
   - *Design*: Titan Heavy Hydraulic Scrap-Wrench.
   - *Visuals*: Hazard Yellow DiamondPlate chassis with black hazard stripes, black rubber grip ribs, brass pommel, knuckle guard with green LED, chrome hydraulic cylinder with orange fluid lines, 3.4-stud wide forged interlocking jaws, knurled worm gear, and glowing amber Neon induction core with spark VFX.
   - *Grip*: `CFrame.new(0, 0, -0.15) * CFrame.Angles(math.rad(15), 0, 0)` (held upright, tilted slightly forward).

2. **Pneumatic Drill** (`PneumaticDrill`):
   - *Design*: Vortex Impact Breaker Auger.
   - *Visuals*: Safety orange engine casing with cooling fins, D-loop handle with safety trigger, dual lateral bike grips, twin cyan nitrogen flasks with brass valves and pressure dials, heavy keyed chuck, and stepped conical spiral auger bit tapering to a glowing molten yellow chisel tip with exhaust smoke VFX.
   - *Grip*: `CFrame.new(0, 0, -0.3) * CFrame.Angles(math.rad(75), 0, 0)` (forward-pointing rotary auger).

3. **Plasma Cutter** (`PlasmaCutter`):
   - *Design*: Thermal Arc Lance & Dismantler.
   - *Visuals*: Titanium slate DiamondPlate receiver chassis, tactical pistol grip and underside foregrip, spine-mounted cryo-plasma fuel vial in glass, dual forward-swept copper magnetic rail horns, massive continuous dual-layer electric cyan plasma torch blade, holographic crosshair reticle, dynamic point light, and plasma arc discharge VFX.
   - *Grip*: `CFrame.new(0, 0, -0.3) * CFrame.Angles(math.rad(75), 0, 0)` (forward-pointing plasma lance).

4. **Cyber Scythe** (`CyberScythe`):
   - *Design*: High-Frequency Nanite War-Scythe.
   - *Visuals*: Dark titanium staff with grounding tungsten spike, dual magenta/cyan Neon spine conduits, articulated scythe hub with rotating Neon gyroscopic core ring, rear salvage claw hook, and 4.5-stud wide forward-curving crescent energy blade with cyan edge tip and nanite lightning discharge VFX.
   - *Grip*: `CFrame.new(0, 0, -0.2) * CFrame.Angles(math.rad(15), 0, 0)` (upright war scythe posture with forward-hooking blade).

5. **Void Ripper** (`VoidRipper`):
   - *Design*: Dark-Matter Graviton Singularity Cleaver.
   - *Visuals*: Spiked void pommel, colossal 3.2-stud wide dreadnought crossguard with glowing Neon fins, broad guillotine cleaver blade (4.2 studs tall, 2.6 studs wide), 4 glowing purple plasma teeth along the serrated cutting edge, central hollow aperture ring with a levitating dark-matter singularity sphere, accretion halo, point light, and swirling void vortex VFX.
   - *Grip*: `CFrame.new(0, 0, -0.2) * CFrame.Angles(math.rad(20), 0, 0)` (broad executioner cleaver stance).

---

## 📜 Critical Design Rules & Guidelines

### 1. Component Grouping Rule (Strict User Requirement)
Whenever you create or proceduralize multi-part objects (tools, benches, tables, machinery, props):
- **ALWAYS group sub-components into logical child `Model` instances** inside the parent (e.g., `GripComponents`, `ChassisAssembly`, `EnergyBlade`, `EngineAssembly`).
- This allows developers to easily select, manipulate, re-skin, or replace entire sub-assemblies in Roblox Studio Explorer without breaking the whole object.
- For Roblox `Tool` instances: `tool.Handle` must remain an immediate child of the `Tool`, but all attached parts can be grouped inside child `Model`s and welded to `tool.Handle` via `WeldConstraint`.

### 2. Close-Quarters Melee Combat (No Ranged Sniping)
- Tools strictly enforce close melee contact (`Range = 8` studs from the node surface in `Config.luau`).
- `ActionController.luau` uses smart front-facing raycasts and surface distance calculations (`(playerPos - nodePos).Magnitude - nodeRadius <= Range`).
- Hitting nodes behind the player or from far away is strictly prohibited.
- Hold-to-swing continuous mining is supported on mouse and touch.

### 3. Smooth Upper-Body Only Animations
- Swing animations (`Chop` ID `507768375` and `Slash` ID `522635514`) are upper-body animations.
- The player character's legs must run, sprint, and jump freely while swinging tools without freezing or stuttering.

### 4. Non-Linear, Organic Environments
- Zones are shaped as circular/oval organic junkyards with winding salvage pathways, peripheral scrap walls, and natural barriers.
- **Never revert to plain rectangular boxes or straight single-file bridges.**
- Teleport pads, recyclers, and armory stations must have clear, unobstructed approach paths with generous clearance (no scrap nodes spawning inside or blocking interactables).

### 5. UI Cleanliness & No Redundant Prompts
- Scrap nodes and raid pods do **NOT** have `[E] Strike Scrap` / `ProximityPrompt` popups. Mining is handled organically by swinging your tool.
- Orbital Drop Pod raid bosses feature in-world 3D billboard health bars and despawn timers directly under the pod rather than persistent full-screen banners.
- Gameplay buttons (Teleport, Upgrades, Drones, Quests) reside on the middle-right side of the screen with clear icon hierarchy.

---

## 🛠️ Tooling & Integration Workflows

### Deploying to Roblox Studio
A local Python deployer pushes `src/` files into the live Roblox Studio session:
```powershell
python deploy_to_studio.py
```

### Blender MCP Integration
When creating or refining complex 3D geometry:
- Use `blender.execute_blender_code` to prototype meshes, inspect dimensions, and configure materials (Principled BSDF, roughness, metallic, emission).
- Use `blender.get_viewport_screenshot` to visually inspect models before translating them into Luau procedural parts or importing mesh assets.

### Studio MCP Integration
- `Roblox_Studio.start_stop_play`: Starts or stops play mode.
- `Roblox_Studio.execute_luau`: Executes server or client-side code directly in the active session for live state verification.
- `Roblox_Studio.screen_capture`: Takes in-game camera screenshots from arbitrary 3D positions to inspect geometry, UI, and character visual state.
- `Roblox_Studio.get_console_output`: Fetches live Studio log outputs and bootstrap messages.
