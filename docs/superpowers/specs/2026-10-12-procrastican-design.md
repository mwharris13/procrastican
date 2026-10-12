# Procrastican — Design Spec

*Date: 2026-10-12 · Status: draft for review*

## 1. Intent

A roguelite time-waster for Marc's own iPhone, reached for when bored, in 2–10 minute sessions, one-handed.
Inspired by RippleLoop (an incremental stone-skipping game: launch, bounce, upgrade, go farther), re-themed
around an everyday action: **kicking a can down the road**. The reinforcement loop must feel exponentially
more rewarding as skills and gear accumulate across runs.

**Success criteria**
- 30 seconds of launching and tapping is fun on its own, before any upgrades.
- Touch and audio feel instant on iPhone (as responsive as RippleLoop).
- Every run ends with something to buy, and numbers grow visibly exponentially across zones.
- Restart from a finished run in ≤ 2 taps.

**Name:** Procrastican. Possible title-screen gag: "Mild Littering".

## 2. The run

### 2.1 Launch
- The kid stands at screen-left with the can at their foot.
- The player presses and drags **back** from the can like a pinball plunger / slingshot.
  - Drag length → power (clamped to a max; scaled by Kick Power).
  - Drag direction → launch angle, clamped to roughly 10°–70°.
  - A dotted arc previews the first part of the flight while dragging.
- Release → kick animation, hit-stop, kick SFX. The kid scrolls off; the camera follows the can.
- The kid does not walk or reappear during the run.

### 2.2 Flight and bounces
- The can moves under custom, deterministic physics (not Godot's RigidBody): gravity, air drag, spin,
  bounce restitution, ground roll friction.
- A ground shadow and a shrinking ring around the can telegraph each upcoming touchdown.

### 2.3 Tapping (re-kicks)
- The player taps **on the can** (hit area ≈ 1.5–2× the can's sprite, scaled by Reach). Taps elsewhere do nothing.
- Timing is judged relative to the predicted ground-contact moment:

| Grade | Window (start values, tunable) | Effect |
|---|---|---|
| Perfect | ±60 ms | Re-kick forward keeping most of its speed (more with Sneakers), combo +1, big juice |
| Good | ±130 ms | Re-kick keeping less speed, combo kept |
| Miss / no tap | — | Dead bounce: large energy loss, combo resets |

- At most one graded tap per touchdown. A tap outside the Good window is ignored (unless it triggers an Air Kick);
  no graded tap by the end of the window = Miss for that touchdown.
- **Air Kick** (upgrade): N charges per run. A tap on the can while airborne and outside any touchdown window spends a charge for a forward boost.

### 2.4 Street objects
- **Helpers** (bounce/speed/combo bonuses): mailboxes, car hoods, trash cans, sleeping dog, etc.
- **Hazards** (heavy speed loss): puddles, grass verges, storm drains, gravel.
- The available set depends on the zone.

### 2.5 End of run
- When the can is grounded and its speed falls below a threshold, it rolls to rest and the run ends.
- A watchdog ends the run if the can stays in an invalid state (NaN, stuck, out of bounds) for too long.
- Results screen: distance, best combo, coins earned, new-record badge. Buttons: **Shop**, **Kick again**.
- Target run length: 20–60 s early, longer with upgrades.

### 2.6 Roguelite layer (in-run)
- **Street modifier:** one per run, drawn at launch and shown on the aim screen
  (e.g. Downhill, Tailwind, Garbage Day = more helpers, Rain-slick = lower friction and lower restitution).
- **Perk picks:** at distance checkpoints (first at ~250 m, then spaced further apart each time) the game
  pauses and offers 3 perks; pick 1. Perks last for this run only.
  Examples: "Car bounces +40% speed", "Every 5th Perfect is a Super Kick", "Puddles become trampolines".
- Draws are seeded and weighted; rarity odds are affected by the Perk Odds upgrade.

## 3. Progression and economy

### 3.1 Currency
- One currency: coins (¢).
- `coins = distance × (1 + combo bonus) × zone value + pickups`, then × Coin Magnet.
- Large numbers are abbreviated: 1.2K, 34.5M, 8.1B, 2.3T, ….

### 3.2 Zones
Bands of one continuous street, not separate levels. Each zone changes the look, helpers, hazards and
coin value. The can's physics stay in a sane range; exponential growth comes from zone value and stacked multipliers.

| Zone | Starts at | Value | Flavor |
|---|---|---|---|
| Your Block | 0 m | ×1 | Houses, mailboxes, sleeping dog |
| Downtown | ~250 m | ×10 | Parked cars, storm drains, pigeons |
| Highway Shoulder | ~1,200 m | ×100 | Guardrails, truck draft boost, gravel |

Zone thresholds and values are data and will be tuned.

### 3.3 Shop
Costs grow geometrically (start ≈ ×1.6 per level). Effects stack multiplicatively.

| Track | Upgrade | Effect |
|---|---|---|
| Gear | Kick Power | Launch speed |
| Gear | Sneakers | Perfect re-kick boost |
| Gear | Cans (collectible, one equipped) | Soda (balanced), Paint can (heavy, keeps speed), Lucky can (more coins, less bounce) |
| Skills | Timing | Wider Perfect/Good windows |
| Skills | Reach | Larger tap hit area |
| Skills | Combo | More value per combo step |
| Skills | Air Kick | Mid-air boost charges per run |
| Luck | Perk Odds | Better rarity rolls |
| Luck | Coin Magnet | % bonus coins |
| Luck | Helpers | Helper spawn frequency |

### 3.4 Persistence
- Auto-save after every run and every purchase. Saved: upgrade levels, coins, owned/equipped cans,
  best distance, lifetime stats, save version.
- Settings screen: **export / import save code** (copyable text) as insurance against iOS clearing web storage.

## 4. Visual and audio direction
- **Look:** soft flat-vector palette (pastel daylight, warm houses) rendered as **hi-bit pixel art**:
  internal width **270 px**, portrait, height expands to the phone's aspect (≈ 512–585), nearest-neighbor upscale.
- **v1 art is placeholder,** generated from simple shapes in code/Godot, good enough to tune feel against.
  A separate art spec follows v1 and chooses between asset packs, AI-generated sprites with cleanup, or hand-drawn art.
- **Juice:** hit-stop, screen shake, squash/stretch, particle bursts, popup grade text (PERFECT!/GOOD), coin popups.
- **Audio:** short, preloaded SFX for kick, re-kick grades, helper bounce, hazard, perk, shop. Audio is unlocked on first touch.
- **UI:** a pixel font in the same pixel space; HUD shows distance (top-left) and combo (top-right).

## 5. Technical architecture

### 5.1 Platform
- Godot 4.7, Compatibility renderer, single-threaded web export as a PWA. Deployed to Vercel from the Mac
  via `build_web.sh` / `deploy_web.sh` (same pattern as Foreshortened). 60 fps cap.
- Repo `~/scm/personal/procrastican`, with the personal git identity set locally.
- Native iOS export of the same project is the fallback if the feel test fails.

### 5.2 Logic units (plain GDScript, node-free, unit-tested)

| Unit | Responsibility | Depends on |
|---|---|---|
| `CanPhysics` | Step the can (gravity, drag, spin, bounce, roll); predict the next touchdown | resolved stats |
| `TapJudge` | Hit-area test and Perfect/Good/Miss timing grade | resolved stats, `CanPhysics` prediction |
| `LaunchAim` | Drag vector → angle/power; arc preview points | resolved stats |
| `StatResolver` | **Single place where modifiers stack:** base tuning × upgrades × can × perks × modifier → resolved stats | data resources |
| `RunState` | Distance, combo, run coins, current zone, next perk checkpoint | — |
| `Economy` | Upgrade cost/effect per level; coin formula | upgrade data |
| `PerkDeck`, `ModifierDeck` | Seeded, weighted draws | luck stats |
| `StreetGen` | Seeded chunk generation per zone (helpers/hazards placement) | zone data |
| `SaveStore` | Versioned JSON in `user://`, export/import code, migration, corrupt-save fallback | — |
| `NumFmt` | Big-number abbreviation | — |

### 5.3 Data (`.tres` resources)
Upgrades, cans, perks, modifiers, zones and base tuning are data. Adding content means adding data, not code.

### 5.4 Scenes
- `Main`: screen state machine (Title → Aim → Run → PerkPick → Results → Shop; Settings off Title).
- `RunView`: camera follow, can and kid sprites, parallax street, object views.
- `Juice` helper: hit-stop, shake, squash/stretch, particles, popups.
- `Sfx` helper: preloaded players, first-touch unlock.
- **Tuning overlay** (hidden; three-finger tap): live sliders for physics and windows, frame-time and
  touch→response latency readout, copy-out of current values.

### 5.5 Error handling
- Corrupt or missing save → defaults (and keep the bad file aside for inspection).
- Failed save write → small toast.
- App backgrounded → auto-pause.
- Physics watchdog ends a stuck run (§2.5).

## 6. Testing and milestones

### 6.1 Milestone 0 — iPhone feel test (go/no-go for web)
Build: slingshot launch, `CanPhysics` on a flat placeholder street, tap grading, hit-stop/shake/particles,
kick SFX, tuning overlay with latency readout. Deploy to Vercel and play from the iPhone home screen.

Pass criteria:
1. Taps feel instant; overlay-measured touch→visual response is acceptable.
2. Kick SFX lands with the hit, without noticeable lag.
3. Steady 60 fps without stutter.

Fail and not fixable by tuning → stop and switch to native iOS export before further work.
Pass → tune windows and physics until 30 s of bare launching and tapping is fun, then build progression.

### 6.2 Automated tests (GUT)
- `CanPhysics`: deterministic for fixed inputs; miss reduces energy and Perfect increases it; the can always
  comes to rest; no tunneling through the ground at low frame rates.
- `TapJudge`: window edges, hit-area edges, Timing/Reach scaling.
- `StatResolver`: stacking order and multiplicative composition.
- `Economy`, `NumFmt`: cost curve, coin formula, rounding and abbreviation boundaries (999 → 1.0K).
- `StreetGen`, `PerkDeck`, `ModifierDeck`: seed determinism, weights respected.
- `SaveStore`: round-trip, export/import, corrupt fallback, version migration.
- **Balance simulation:** a headless bot that always lands "Good", plays N runs with greedy shopping; asserts
  no progression wall in the first ~30 simulated minutes and roughly exponential coin growth across zones.

## 7. Out of scope for v1 (backlog)
- Final art (separate art spec), prestige ("Move to a new town" / "Aggravated Littering"), zones beyond the
  first three, daily challenge runs, achievements, native iOS build (unless Milestone 0 fails).
