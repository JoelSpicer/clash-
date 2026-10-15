# Clash! - Project Architecture & Systems Map

## 1. Engine & Core Paradigms
- **Engine Target:** Godot 4.x (Strictly GDScript 2.0).
- **Typing Discipline:** Strict static typing enforced across all scripts, parameters, and return types to maintain static analyzer integrity.
- **Architectural Pattern:** "Call down, signal up." Game logic and state mutation are strictly decoupled from UI/visual presentation.
- **Multiplayer Model:** Authoritative Dedicated Headless Server with connected client peers.

## 2. Directory & Asset Structure
- `res://Art/`: Visual assets, strictly decoupled from logic scripts.
  - `Background/`: Arena/match backgrounds (`1.png`).
  - `Fonts/`: `MainGameFont.tres` utilizing `Oswald`, `OpenSans`, and `NotoEmoji` variable fonts.
  - `Icons/`: Status effect and combat state indicators (`icon_Bide.png`, `icon_Injured.png`, `icon_Opening.png`, `icon_Opportunity.png`).
  - `Portraits/`: Character art (e.g., `heavy.png`).
  - Root Art: Core action category visuals (`OffenceBasic.jpg`, `DefenceBasic.jpg`).
- *(Note: `.import` files and binary assets are excluded from AI context packs).*

## 3. Core Autoloads / Singletons
- **`GameManager.gd`**: The central authority for combat flow and match rules.
  - Holds global match constants (e.g., `MOMENTUM_P1_MAX`—never overwrite global constants during state resets).
  - Instantiates and manages the active `MatchState` container via `GameManager.state`.
  - Executes combat resolution, action combining logic, and turn phase transitions.
- **`NetworkManager.gd`**: Manages multiplayer connectivity, peer tracking, and headless server operations.
  - Implements detailed network logging, static typing, and strict memory cleanup on peer disconnect.
  - Controls the **Handshake Synchronization System** to guarantee both clients and the headless server are aligned before advancing match phases, preventing networking race conditions.

## 4. State Management (`MatchState`)
- **`MatchState` (Disposable State Container)**:
  - Lives inside `GameManager` (accessed globally via `GameManager.state`).
  - Centralizes all match-specific mutable variables (player health, momentum, selected actions, active status effects like *Bide*, *Injured*, *Opening*, and *Opportunity*, and turn counters).
  - **Lifecycle:** Completely disposed of and re-instantiated as a fresh object in a single-line reset during combat initialization. This prevents state bleed and memory leaks between consecutive combat sessions.
  - **Network Sync:** Designed so the authoritative server can serialize and broadcast the entire state payload to clients to enforce alignment and prevent headless server desyncs.

## 5. UI & Presentation Layer
- **`BattleUI.gd`**: The primary visual interface for combat.
  - Strictly a consumer of `GameManager.state`. It does not calculate core combat math independently.
  - Reads momentum, health, and status icons (`Bide`, `Injured`, `Opening`, `Opportunity`) by querying `GameManager.state` upon receiving state-update signals.
  - Captures local player inputs (Offence/Defence actions, action combining) and forwards requests up to `NetworkManager` / `GameManager`.

## 6. Combat & Network Loop
1. **Match Initialization:** `GameManager` instantiates a clean `MatchState` (`GameManager.state = MatchState.new()`). `NetworkManager` verifies client readiness via handshake.
2. **Planning / Action Phase:** Players select and combine Offence/Defence actions in `BattleUI`. Selections are sent to the authoritative server via `Callable.rpc_id(1, ...)`.
3. **Resolution Phase:** The server evaluates action combinations, calculates Momentum shifts, applies damage, and updates status flags (`Bide`, `Injured`, `Opening`, `Opportunity`) inside `GameManager.state`.
4. **Reveal Phase & Sync:** The server synchronizes the updated `GameManager.state` to all clients and triggers the reveal phase. Handshake barriers ensure animations and state updates do not desync on headless server instances.