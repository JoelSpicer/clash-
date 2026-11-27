# CLASH - Project Architecture & Systems Map

## 1. Engine & Core Paradigms
- **Engine Target:** Godot 4.7.2-stable (Strictly GDScript 2.0, GL Compatibility renderer for Web/Desktop parity).
- **Typing Discipline:** Strict static typing enforced across runtime scripts, parameters, and return types.
- **Architectural Pattern:** "Call down, signal up." Combat rules and state mutation live in `GameManager` / `MatchState`; UI controllers (`BattleUI`, `CombatArena`, `BattleEffectsController`, `BattleTooltipController`, `BattleInspectPanel`, `TrialOverlay`) subscribe to signals and never calculate authoritative combat math independently.
- **Multiplayer Model:** Authoritative Dedicated Headless Server (or P2P host) with connected client peers via `NetworkManager` handshake barriers and authoritative `MatchState` snapshots.

## 2. Directory & Asset Structure
- `res://Art/`: Visual assets decoupled from logic (`Background/`, `Fonts/`, `Icons/`, `Portraits/`, `UI/`).
- `res://Data/`: Authored `.tres` resources:
  - `Actions/` & `Actions/Class/{Heavy,Patient,Quick,Technical}/`: `ActionData` card definitions.
  - `AI/`: Modular `AIBehavior` profiles (`AIAggressive`, `AIBalanced`, `AIDefensive`, `AITrickster`).
  - `BossModifiers/`: `BossModifierData` resources scaling Circuit bosses.
  - `Classes/`: `ClassDefinition` resources (`HeavyClass`, `PatientClass`, `QuickClass`, `TechnicalClass`).
  - `Equipment/`: `EquipmentData` passive modifiers.
  - `Events/`: `EventData` roguelike Circuit events.
  - `Presets/`: `PresetCharacter` fighters for Quick Match and Multiplayer.
  - `Sponsors/`: `SponsorData` run modifiers.
- `res://Scenes/`: All UI, combat, menu, balance runner, and regression test scenes.
- `res://Scripts/`:
  - Root scripts: Core UI screens, autoload managers, and shared helpers.
  - `Scripts/Battle/`: Combat controllers (`BotDecisionMaker`, `BattleEffectsController`, `BattleTooltipController`, `BattleInspectPanel`, `TrialOverlay`).
  - `Scripts/Resources/`: Data models & core singletons (`ActionData`, `AIBehavior`, `BaseModifierData`, `BossModifierData`, `CharacterData`, `ClassDefinition`, `CombatGlossary`, `EquipmentData`, `EventData`, `GameManager`, `GlobalSaveData`, `MatchState`, `PresetCharacter`, `RunSaveData`, `SponsorData`, `TrialData`).
  - `Scripts/Tests/`: Headless automated test suite (`CombatRegressionSuite.gd`).
  - `Scripts/Balance/`: Headless balance simulation runners (`Class`, `AI`, `Boss`, `Sponsor`, `Equipment`).

## 3. Autoloads / Singletons (`project.godot`)
- **`GameManager`** (`Scripts/Resources/GameManager.gd`): Authoritative combat state machine (`SETUP -> SELECTION -> REVEAL -> FEINT_CHECK -> RESOLUTION -> POST_CLASH -> GAME_OVER`), clash math, Repeat/Feint/Multi/Opening/Opportunity/Parry/Reversal/Retaliate/Tiring/Wall Crush rules, class passives, and server-authoritative state snapshot sync.
- **`NetworkManager`** (`Scripts/NetworkManager.gd`): Multiplayer connection lifecycle, lobby/rematch flow, peer tracking, and reveal/animation handshake synchronization.
- **`RunManager`** (`Scripts/RunManager.gd`): The Circuit roguelike campaign loop (node progression, Boss/Rival fights, Gym buffs, Equipment, Sponsors, meta-progression `GlobalSaveData`, and mid-run `RunSaveData` persistence).
- **`ClassFactory`** (`Scripts/ClassFactory.gd`): Class registry, action tree topology (`TREE_CONNECTIONS`, `ID_TO_NAME_MAP`), preset & procedural enemy/boss generation, smart hand curation, and `Counter X -> Create Opening >= X` draft validation.
- **`TrialManager`** (`Scripts/TrialManager.gd`): Curated Dojo Trials catalog (28 trials across Core Drills, Passives & Hybrids, and Tactical Puzzles), scripted bot responses, win/fail evaluation, and first-clear Circuit Token rewards.
- **`TutorialManager`** (`Scripts/TutorialManager.gd`): Guided full-match tutorials (`"begin"` first-launch intro and `"basic"` Sensei dojo lesson).
- **`AudioManager`** (`Scripts/AudioManager.gd`): SFX playback and Ovani dynamic-intensity music routing (Web Audio safe).
- **`SettingsManager`** (`Scripts/SettingsManager.gd`): Persistent audio/display settings (`user://settings.cfg`).
- **`SceneLoader`** (`Scripts/SceneLoader.gd`): Fade-transition scene switching.
- **`GlobalCinematics`** (`Scripts/GlobalCinematics.gd`): Screen-wide danger vignette, bars, and camera flash helpers.
- **`HitStopManager`** (`Scripts/HitStopManager.gd`): Impact hitstop frame freeze (automatically disabled in online multiplayer, headless mode, or paused/KO states).
- **`VFXManager`** (`Scripts/VFXManager.gd`): Impact bursts and floating damage/status/callout popups (headless-safe).
- **`DialogueManager`** (`Scripts/DialogueManager.gd`): Story/rival banter popups.
- **`Pausemenu`** (`Scripts/Pausemenu.gd`): Global pause overlay (`Esc`) with trial/run-safe return routing.

## 4. Combat Arena & Modular Battle Controllers
- **`CombatArena.tscn` / `CombatArena.gd`**: Top-level battle coordinator. Initializes P1/P2 fighters, binds `GameManager` signals, coordinates hotseat/AI/online turn flow, delegates bot AI decisions to `BotDecisionMaker`, drives `TrialOverlay` / `TutorialLayer`, and handles Game Over / Rematch / Circuit progression transitions.
- **`BotDecisionMaker`** (`Scripts/Battle/BotDecisionMaker.gd`): Standalone AI scoring engine (`class_name BotDecisionMaker`) evaluating legal cards using difficulty tier (`VERY_EASY..HARD`), `AIBehavior` weights, `MatchState`, Feint combinations, and class toggles (Rage / Custom Technique).
- **`BattleUI.gd`**: Primary combat HUD and input layer with keyboard shortcuts (`1–9` actions, `Tab` Offence/Defence, `I` Inspect, `L` Combat Log, `R` Retry Trial, `H` Trial Hint), hotkey badges on `CardButton`, and color-coded floating combat callouts (`GameManager.combat_callout`). Delegates specialized concerns to:
  - **`BattleEffectsController`**: Clash card reveal animations, momentum bar pulses, and impact VFX hooks.
  - **`BattleTooltipController`**: Rich keyword/card hover tooltips backed by `CombatGlossary`.
  - **`BattleInspectPanel`**: Full fighter deck, stats, passives, and equipment inspector (`I`).
  - **`TrialOverlay`**: Collapsible Dojo Trial objective/hint/retry HUD docked beneath the combat log toggle.

## 5. Hub & Game Modes (`CarouselHub.tscn`)
1. **The Circuit** (`MenuArcade.tscn` -> `TournamentMap.tscn` / `GymMain.tscn` / `EventRoom.tscn` / `RewardScreen.tscn` / `DeckEditScreen.tscn` / `LeagueVictoryScreen.tscn`): Roguelike tournament campaign with Sponsors, Boss Modifiers, and save/load support.
2. **Quick Match** (`MenuQuick.tscn`): Preset vs Preset (CPU or local Player 2 hotseat) across selectable arenas (`Ring` 6 slots, `Dojo` 8 slots, `Street` 10 slots).
3. **Dojo Trials** (`MenuDojoTrials.tscn`): 28 bite-sized combat puzzles teaching every trait, Class Passive, and hybrid interaction.
4. **Network Terminal** (`ShopTerminal.tscn`): Meta-progression unlocks (Classes, Sponsors, upgrades) using Circuit Tokens.
5. **Game Settings** (`MenuSettings.tscn`): Audio, display, and progress reset controls.
6. **Compendium** (`compendium.tscn`): Rules glossary (`CombatGlossary`) and full Action library browser.
7. **Multiplayer** (`Multi.tscn`): Online lobby and matchmaking via `NetworkManager`.

## 6. Automated Verification & Balance Tooling
- **Regression Test Suite (`Scenes/Tests/CombatRegressionSuite.tscn` / `Scripts/Tests/CombatRegressionSuite.gd`)**: Headless automated suite verifying every core combat rule, all 4 Class Passives, `FEINT_CHECK` state integrity, equipment modifiers, `RunSaveData` Save/Load roundtrip, and all 28 Dojo Trials (winning lines, trap plays, and UI legality).
- **Headless Balance Runners (`Scenes/*BalanceRunner.tscn`)**: Automated Monte Carlo match simulators for `Class`, `AI`, `Boss`, `Sponsor`, and `Equipment` balance auditing.
- **Export / `.pck` Safety**: All dynamic resource directory scans strip `.remap` / `.import` suffixes and deduplicate filenames so Web (`.pck`) exports load identically to the editor.
