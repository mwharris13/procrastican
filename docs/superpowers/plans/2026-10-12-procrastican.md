# Procrastican Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build Procrastican v1. You flick a can down the street with a slingshot launch, keep it going with timed taps on the can, and spend the coins in a compounding upgrade shop. It ships as a Godot web app (PWA) for iPhone.

**Architecture:** All game logic lives in plain GDScript classes (`RefCounted`, no scene tree) under `scripts/core/` and is unit-tested with GUT. Thin node classes under `scripts/view/` and `scripts/ui/` draw placeholder art in code and turn touches into calls on the logic. Tunable numbers and content live in `data/*.json`. Phase A (Tasks 1–10) is the iPhone feel test, a hard go/no-go gate. Phase B (Tasks 11–22) adds progression on top.

**Tech Stack:** Godot 4.7.2 (`/opt/homebrew/bin/godot`), GDScript, GUT 9.7.1 (copied from `../foreshortened/addons/gut`), Compatibility renderer, web export as a PWA, Vercel CLI (run by the user).

**Spec:** `docs/superpowers/specs/2026-10-12-procrastican-design.md`

## Global Constraints

- Godot 4.7, Compatibility renderer, single-threaded web export as a PWA. Deploy from the Mac with `build_web.sh` and `deploy_web.sh`.
- Portrait display: internal width **270 px**; height expands to the phone (project viewport 270×585), `stretch/mode="viewport"`, `aspect="keep_width"`, nearest-neighbor texture filter, 60 fps cap.
- World units are meters and seconds. y points up, and the ground is y = 0. Screen pixels per meter is `px_per_m` in `data/tuning.json`.
- `StatResolver` is the **only** place where modifiers stack: base tuning × upgrades × can × perks × modifier.
- Logic classes in `scripts/core/` extend `RefCounted` and never touch the scene tree.
- Tunables and content are data in `data/*.json`. *(Deviation from spec §5.3, which says `.tres`. JSON matches Foreshortened's proven export `include_filter` and diffs as plain text.)*
- v1 art is placeholder, drawn in code. v1 uses Godot's default font; the pixel font moves to the art pass. *(Deviation from spec §4, flagged to the user.)*
- Run `./run_tests.sh` before every commit; it must be green.
- Commits are a subject line plus at most 2 body lines, with **no** Claude/Anthropic attribution trailer. The git identity is already set locally to Marc Harris <marc.w.harris@gmail.com>.
- Never run `deploy_web.sh` / `vercel deploy --prod` and never `git push`. The user does both.
- Off-limits for every agent: GCP projects `mars-95887257` and `proteus-592709` (including any Pulumi stack/config files for them), and AWS accounts `855237529943` and `750927504591`. Never read credential stores.
- American spelling. Code comments are one line, occasionally two.
- GDScript indentation is tabs.

## Review Focus

1. **A tap before the timing window, or a second tap in the same window,** is ignored. It never penalizes or double-grades. → Task 4 tests `test_too_early_tap_is_ignored_then_window_tap_counts` and `test_second_tap_in_window_is_ignored`.
2. **A long frame** (tab resume or GC hitch, `dt` = 0.5 s) must not skip a touchdown, tunnel through the ground or misgrade a buffered tap. → Task 3 `test_large_dt_stops_at_touchdown`, Task 4 `test_long_hitch_keeps_event_order`.
3. **An accidental tiny drag or tap on the aim screen** cancels and never launches a dud run. → Task 5 `test_tiny_drag_is_invalid`, Task 8 `test_tiny_drag_does_not_launch`.
4. **Huge coin values** (1e15–1e40 and beyond) format sanely and survive a save round-trip. → Task 11 `test_huge_and_special_values`, Task 13 `test_large_coins_round_trip`.
5. **A malformed or foreign import code** is rejected and leaves the current save untouched. → Task 13 `test_import_rejects_bad_codes`, Task 18 `test_bad_import_leaves_save_untouched`.

Also covered: backgrounding the app during a hit-stop restores `Engine.time_scale` (Task 20 `test_background_pause_restores_time_scale`).

## File Map

```
procrastican/
  project.godot, export_presets.cfg, .gitignore
  run_tests.sh, build_web.sh, deploy_web.sh
  .claude/launch.json                     # local static server for build/web
  addons/gut/                             # copied from ../foreshortened
  data/tuning.json                        # base stats (Task 2)
  data/upgrades.json, cans.json, perks.json, modifiers.json, zones.json, objects.json   # Task 12
  scenes/main.tscn
  scripts/main.gd                         # M0 wiring (Task 8), full flow (Task 20)
  scripts/core/game_data.gd               # GameData: loads data/*.json
  scripts/core/can_physics.gd             # CanPhysics
  scripts/core/tap_judge.gd               # TapJudge
  scripts/core/run_sim.gd                 # RunSim: physics + taps + street + watchdog
  scripts/core/launch_aim.gd              # LaunchAim
  scripts/core/latency_probe.gd           # LatencyProbe
  scripts/core/num_fmt.gd                 # NumFmt
  scripts/core/stat_resolver.gd           # StatResolver
  scripts/core/save_store.gd              # SaveStore
  scripts/core/economy.gd                 # Economy
  scripts/core/run_state.gd               # RunState
  scripts/core/perk_deck.gd, modifier_deck.gd
  scripts/core/street_gen.gd              # StreetGen
  scripts/audio/synth_sfx.gd, sfx.gd      # SynthSfx (procedural WAVs), Sfx (voice pool)
  scripts/view/juice.gd                   # Juice: hit-stop, shake, popups, bursts
  scripts/view/run_view.gd                # RunView: draw + input + sim driving
  scripts/ui/ui_theme.gd, hud.gd, tuning_overlay.gd
  scripts/ui/title_screen.gd, perk_pick_screen.gd, results_screen.gd, settings_screen.gd, shop_screen.gd
  test/test_*.gd                          # GUT tests, one per unit
  docs/feel-test-m0.md                    # Task 10 result record
```

---

# Phase A — Milestone 0: iPhone feel test

### Task 1: Project scaffold

**Files:**
- Create: `project.godot`, `export_presets.cfg`, `.gitignore` (overwrite the one-line existing file), `run_tests.sh`, `build_web.sh`, `deploy_web.sh`, `.claude/launch.json`, `scenes/main.tscn`, `scripts/main.gd`, `test/test_smoke.gd`
- Copy: `addons/gut/` from `../foreshortened/addons/gut/`

**Interfaces:**
- Produces: a runnable Godot project; `./run_tests.sh [-gtest=res://test/<file>.gd]` runs GUT headless and exits non-zero on failures or script errors.

- [ ] **Step 1: Branch, copy GUT and write the project files**

Work on a branch, as Ka-Chunk and Foreshortened did:
```bash
cd ~/scm/personal/procrastican
git checkout -b build/v1
mkdir -p addons scenes scripts/core scripts/audio scripts/view scripts/ui data test .claude
cp -R ../foreshortened/addons/gut addons/
```

`project.godot`:
```ini
config_version=5

[application]

config/name="Procrastican"
run/main_scene="res://scenes/main.tscn"
run/max_fps=60
config/features=PackedStringArray("4.7")

[display]

window/size/viewport_width=270
window/size/viewport_height=585
window/size/window_width_override=390
window/size/window_height_override=844
window/stretch/mode="viewport"
window/stretch/aspect="keep_width"
window/handheld/orientation=1

[editor_plugins]

enabled=PackedStringArray("res://addons/gut/plugin.cfg")

[input_devices]

pointing/emulate_touch_from_mouse=true

[rendering]

renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
textures/canvas_textures/default_texture_filter=0
2d/snap/snap_2d_transforms_to_pixel=true
```

`export_presets.cfg`:
```ini
[preset.0]

name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
include_filter="data/*.json"
exclude_filter="test/*, addons/gut/*, docs/*, build/*"
export_path="build/web/index.html"

[preset.0.options]

variant/extensions_support=false
variant/thread_support=false
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
progressive_web_app/enabled=true
progressive_web_app/ensure_cross_origin_isolation_headers=false
progressive_web_app/display=1
progressive_web_app/orientation=2
progressive_web_app/background_color=Color(0.56, 0.83, 0.96, 1)
```
*(PWA orientation 2 = portrait.)*

`.gitignore`:
```
.godot/
build/
.superpowers/
.vercel
.env*
*.tmp
.DS_Store
```

`run_tests.sh` (then `chmod +x`):
```bash
#!/usr/bin/env bash
set -uo pipefail
cd "$(dirname "$0")"
# Import refreshes the class_name cache so new scripts are visible to tests.
godot --headless --path . --import >/dev/null 2>&1 || true
args=(-gexit)
if [[ "$*" != *-gtest=* ]]; then
	args+=(-gdir=res://test -ginclude_subdirs)
fi
log=$(mktemp)
godot --headless --path . -s addons/gut/gut_cmdln.gd "${args[@]}" "$@" 2>&1 | tee "$log"
status=${PIPESTATUS[0]}
# GUT only warns when a test script fails to load, so treat script errors as failures.
if grep -qE "SCRIPT ERROR|Parse Error" "$log"; then
	echo "run_tests: script errors detected, failing run"
	status=1
fi
rm -f "$log"
exit "$status"
```

`build_web.sh` (then `chmod +x`):
```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build/web
# Stop Godot from importing its own build output back into the project.
touch build/.gdignore
godot --headless --path . --import >/dev/null 2>&1 || true
godot --headless --path . --export-release "Web" build/web/index.html
# Keep link metadata and the CLI-written token file out of the public upload.
printf '.env*\n.gitignore\n' > build/web/.vercelignore
test -f build/web/index.html && test -f build/web/index.wasm
echo "Web build ready in build/web"
```

`deploy_web.sh` (then `chmod +x`; **only the user runs this**):
```bash
#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
./build_web.sh
vercel deploy --cwd build/web --prod --yes
```

`.claude/launch.json`:
```json
{
  "version": "0.0.1",
  "configurations": [
    {
      "name": "procrastican-web",
      "runtimeExecutable": "python3",
      "runtimeArgs": ["-m", "http.server", "8062", "--bind", "127.0.0.1", "--directory", "build/web"],
      "port": 8062
    }
  ]
}
```

`scenes/main.tscn`:
```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/main.gd" id="1"]

[node name="Main" type="Node2D"]
script = ExtResource("1")
```

`scripts/main.gd` (placeholder, replaced in Task 8):
```gdscript
extends Node2D
```

- [ ] **Step 2: Write the smoke test**

`test/test_smoke.gd`:
```gdscript
extends GutTest

func test_portrait_270_wide_viewport():
	assert_eq(ProjectSettings.get_setting("display/window/size/viewport_width"), 270)
	assert_eq(ProjectSettings.get_setting("display/window/stretch/aspect"), "keep_width")

func test_main_scene_loads():
	var scene: PackedScene = load("res://scenes/main.tscn")
	assert_not_null(scene)
	var main = scene.instantiate()
	add_child_autofree(main)
	assert_true(main is Node2D)
```

- [ ] **Step 3: Run the tests**

Run: `./run_tests.sh`
Expected: 2 passed, 0 failed, and no "SCRIPT ERROR" lines.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "Scaffold Godot project with GUT, web export and scripts"
```

---

### Task 2: GameData loader and base tuning

**Files:**
- Create: `data/tuning.json`, `scripts/core/game_data.gd`, `test/test_game_data.gd`

**Interfaces:**
- Produces:
  - `GameData.load_all(dir: String = "res://data") -> GameData`. Its `tuning: Dictionary` maps stat name to float; `GameData.REQUIRED_STATS: Array[String]`.
  - `GameData.read_json(path: String) -> Variant` returns `null` when the file is missing or invalid.
  - Task 12 adds more fields to `GameData`.
- **Stat names below are the contract for every later task.**

- [ ] **Step 1: Write the tuning data**

`data/tuning.json`:
```json
{
	"gravity": 30.0,
	"air_drag": 0.08,
	"launch_speed_max": 22.0,
	"max_speed": 60.0,
	"angle_min": 10.0,
	"angle_max": 70.0,
	"drag_min_px": 12.0,
	"drag_max_px": 110.0,
	"can_radius": 0.3,
	"can_half_height": 0.45,
	"restitution_miss": 0.35,
	"miss_vx_keep": 0.6,
	"restitution_good": 0.7,
	"good_vx_keep": 0.92,
	"restitution_perfect": 0.9,
	"perfect_vx_boost": 1.06,
	"rekick_vy_min": 7.0,
	"roll_vy": 1.5,
	"ground_friction": 6.0,
	"rest_speed": 0.4,
	"tailwind": 0.0,
	"perfect_window": 0.06,
	"good_window": 0.13,
	"tap_reach_m": 2.2,
	"air_kicks": 0.0,
	"air_kick_boost": 4.0,
	"super_kick_every": 0.0,
	"super_kick_mult": 1.5,
	"helper_speed_mult": 1.0,
	"helper_freq": 1.0,
	"puddle_trampoline": 0.0,
	"coin_per_meter": 0.1,
	"coin_mult": 1.0,
	"combo_step": 0.1,
	"rare_mult": 1.0,
	"max_run_time": 600.0,
	"px_per_m": 14.0
}
```

- [ ] **Step 2: Write the failing test**

`test/test_game_data.gd`:
```gdscript
extends GutTest

const BAD_DIR := "user://bad_data"

func after_each():
	if FileAccess.file_exists(BAD_DIR + "/tuning.json"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(BAD_DIR + "/tuning.json"))

func test_tuning_has_every_required_stat_as_number():
	var d := GameData.load_all()
	for key in GameData.REQUIRED_STATS:
		assert_true(d.tuning.has(key), key)
		assert_true(typeof(d.tuning[key]) == TYPE_FLOAT, key + " is float")

func test_read_json_missing_or_corrupt_returns_null():
	assert_null(GameData.read_json("user://does_not_exist.json"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(BAD_DIR))
	var f := FileAccess.open(BAD_DIR + "/tuning.json", FileAccess.WRITE)
	f.store_string("{not json")
	f.close()
	assert_null(GameData.read_json(BAD_DIR + "/tuning.json"))

func test_load_all_from_bad_dir_gives_empty_tuning():
	var d := GameData.load_all("user://nowhere")
	assert_eq(d.tuning, {})
```

- [ ] **Step 3: Run it to confirm it fails**

Run: `./run_tests.sh -gtest=res://test/test_game_data.gd`
Expected: a failure or parse error because `GameData` is not defined.

- [ ] **Step 4: Implement**

`scripts/core/game_data.gd`:
```gdscript
class_name GameData
extends RefCounted
## Loads tuning and content JSON from data/.

const DATA_DIR := "res://data"
const REQUIRED_STATS: Array[String] = [
	"gravity", "air_drag", "launch_speed_max", "max_speed", "angle_min", "angle_max",
	"drag_min_px", "drag_max_px", "can_radius", "can_half_height", "restitution_miss",
	"miss_vx_keep", "restitution_good", "good_vx_keep", "restitution_perfect",
	"perfect_vx_boost", "rekick_vy_min", "roll_vy", "ground_friction", "rest_speed",
	"tailwind", "perfect_window", "good_window", "tap_reach_m", "air_kicks",
	"air_kick_boost", "super_kick_every", "super_kick_mult", "helper_speed_mult",
	"helper_freq", "puddle_trampoline", "coin_per_meter", "coin_mult", "combo_step",
	"rare_mult", "max_run_time", "px_per_m",
]

var tuning: Dictionary = {}


static func read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text := FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK:
		push_warning("GameData: bad JSON in %s" % path)
		return null
	return json.data


static func load_all(dir: String = DATA_DIR) -> GameData:
	var d := GameData.new()
	var t = read_json(dir + "/tuning.json")
	if t is Dictionary:
		for k in t:
			d.tuning[k] = float(t[k])
	return d
```

- [ ] **Step 5: Run the tests to confirm they pass**

Run: `./run_tests.sh`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add data/tuning.json scripts/core/game_data.gd test/test_game_data.gd
git commit -m "Add GameData loader and base tuning stats"
```

---

### Task 3: CanPhysics

**Files:**
- Create: `scripts/core/can_physics.gd`, `test/test_can_physics.gd`

**Interfaces:**
- Consumes: the stats dictionary keys from Task 2.
- Produces `CanPhysics`:
  - `CanPhysics.new(stats: Dictionary)`
  - fields: `pos: Vector2` (bottom of the can), `vel: Vector2`, `angle: float`, `time: float`, `launched`, `rolling`, `at_rest: bool`, `last_impact_vel: Vector2`, `stats: Dictionary`
  - `launch(angle_deg: float, power01: float) -> void`
  - `step(dt: float, events: Array) -> float` advances by at most `dt`, **stops right after a touchdown or rest**, appends `{"type":"touchdown","x","t"}` or `{"type":"rest","x","t"}`, and returns the seconds consumed
  - `rekick(perfect: bool) -> void` replaces the dead bounce from the last touchdown
  - `air_kick(boost: float) -> void`
  - `time_to_touchdown() -> float` returns `INF` when not airborne
  - Task 17 adds `apply_helper` and `apply_hazard`.

- [ ] **Step 1: Write the failing tests**

`test/test_can_physics.gd`:
```gdscript
extends GutTest

var stats: Dictionary

func before_each():
	stats = GameData.load_all().tuning.duplicate()

func _fly_to_touchdown(c: CanPhysics) -> Dictionary:
	for i in 2000:
		var ev: Array = []
		c.step(1.0 / 60.0, ev)
		for e in ev:
			if e.type == "touchdown":
				return e
	return {}

func test_launch_sets_velocity_from_angle_and_power():
	var c := CanPhysics.new(stats)
	c.launch(45.0, 0.5)
	assert_almost_eq(c.vel.length(), stats.launch_speed_max * 0.5, 0.001)
	assert_almost_eq(c.vel.x, c.vel.y, 0.001)

func test_same_inputs_same_flight():
	var a := CanPhysics.new(stats)
	var b := CanPhysics.new(stats)
	a.launch(40.0, 0.8)
	b.launch(40.0, 0.8)
	for i in 120:
		a.step(1.0 / 60.0, [])
		b.step(1.0 / 60.0, [])
	assert_eq(a.pos, b.pos)

func test_touchdown_event_and_dead_bounce_loses_energy():
	var c := CanPhysics.new(stats)
	c.launch(45.0, 1.0)
	var ev := _fly_to_touchdown(c)
	assert_eq(ev.get("type"), "touchdown")
	assert_eq(c.pos.y, 0.0)
	assert_lt(c.vel.length(), c.last_impact_vel.length())

func test_perfect_rekick_beats_good_beats_dead():
	var c := CanPhysics.new(stats)
	c.launch(45.0, 1.0)
	_fly_to_touchdown(c)
	var dead_vx := c.vel.x
	c.rekick(false)
	var good_vx := c.vel.x
	c.rekick(true)
	var perfect_vx := c.vel.x
	assert_gt(good_vx, dead_vx)
	assert_gt(perfect_vx, good_vx)
	assert_gt(perfect_vx, c.last_impact_vel.x)
	assert_gte(c.vel.y, stats.rekick_vy_min)

func test_speed_is_capped():
	var c := CanPhysics.new(stats)
	c.launch(45.0, 1.0)
	_fly_to_touchdown(c)
	c.last_impact_vel = Vector2(stats.max_speed * 2.0, -10.0)
	c.rekick(true)
	assert_lte(c.vel.x, stats.max_speed)

func test_always_comes_to_rest_without_taps():
	var c := CanPhysics.new(stats)
	c.launch(45.0, 1.0)
	var t := 0.0
	while not c.at_rest and t < 60.0:
		t += c.step(1.0 / 60.0, [])
	assert_true(c.at_rest)
	assert_eq(c.vel, Vector2.ZERO)

func test_large_dt_stops_at_touchdown():
	var c := CanPhysics.new(stats)
	c.launch(45.0, 0.3)
	var ev: Array = []
	var used := c.step(5.0, ev)
	assert_lt(used, 5.0)
	assert_eq(ev.size(), 1)
	assert_eq(ev[0].type, "touchdown")
	assert_gte(c.pos.y, 0.0)

func test_time_to_touchdown_predicts_without_drag():
	stats.air_drag = 0.0
	var c := CanPhysics.new(stats)
	c.launch(60.0, 1.0)
	c.step(0.1, [])
	var predicted := c.time_to_touchdown()
	var t0 := c.time
	var ev := _fly_to_touchdown(c)
	assert_almost_eq(ev.t - t0, predicted, 0.01)

func test_time_to_touchdown_inf_when_rolling():
	var c := CanPhysics.new(stats)
	assert_eq(c.time_to_touchdown(), INF)
	c.launch(10.0, 0.2)
	c.rolling = true
	assert_eq(c.time_to_touchdown(), INF)

func test_air_kick_adds_forward_speed():
	var c := CanPhysics.new(stats)
	c.launch(45.0, 0.5)
	c.step(0.1, [])
	var vx := c.vel.x
	c.air_kick(4.0)
	assert_almost_eq(c.vel.x, vx + 4.0, 0.001)
```

- [ ] **Step 2: Run them to confirm they fail**

Run: `./run_tests.sh -gtest=res://test/test_can_physics.gd`
Expected: `CanPhysics` is not defined.

- [ ] **Step 3: Implement**

`scripts/core/can_physics.gd`:
```gdscript
class_name CanPhysics
extends RefCounted
## Deterministic can flight: meters and seconds, y up, ground at y = 0, pos is the can's bottom.

const SUBSTEP := 1.0 / 240.0

var stats: Dictionary
var pos := Vector2.ZERO
var vel := Vector2.ZERO
var angle := 0.0
var time := 0.0
var launched := false
var rolling := false
var at_rest := false
var last_impact_vel := Vector2.ZERO


func _init(p_stats: Dictionary) -> void:
	stats = p_stats


func launch(angle_deg: float, power01: float) -> void:
	var a := deg_to_rad(angle_deg)
	var speed: float = stats.launch_speed_max * clampf(power01, 0.0, 1.0)
	vel = Vector2(cos(a), sin(a)) * speed
	pos = Vector2.ZERO
	launched = true
	rolling = false
	at_rest = false


## Advances up to dt but stops right after a touchdown or rest; returns the time consumed.
func step(dt: float, events: Array) -> float:
	if not launched or at_rest:
		return dt
	var used := 0.0
	while used < dt:
		var h := minf(SUBSTEP, dt - used)
		used += h
		time += h
		if _substep(h, events):
			break
	return used


func _substep(h: float, events: Array) -> bool:
	if rolling:
		vel.x = maxf(0.0, vel.x + (stats.tailwind - stats.ground_friction) * h)
		pos.x += vel.x * h
		angle += vel.x / stats.can_radius * h
		if vel.x <= stats.rest_speed:
			vel = Vector2.ZERO
			at_rest = true
			events.append({"type": "rest", "x": pos.x, "t": time})
			return true
		return false
	vel.y -= stats.gravity * h
	vel.x += stats.tailwind * h
	vel -= vel * stats.air_drag * h
	vel.x = minf(vel.x, stats.max_speed)
	pos += vel * h
	angle += vel.x / stats.can_radius * h * 0.5
	if pos.y <= 0.0 and vel.y < 0.0:
		pos.y = 0.0
		last_impact_vel = vel
		_dead_bounce()
		events.append({"type": "touchdown", "x": pos.x, "t": time})
		return true
	return false


func _dead_bounce() -> void:
	vel = Vector2(last_impact_vel.x * stats.miss_vx_keep, -last_impact_vel.y * stats.restitution_miss)
	if vel.y < stats.roll_vy:
		vel.y = 0.0
		rolling = true


func rekick(perfect: bool) -> void:
	var rest: float = stats.restitution_perfect if perfect else stats.restitution_good
	var keep: float = stats.perfect_vx_boost if perfect else stats.good_vx_keep
	vel.x = minf(last_impact_vel.x * keep, stats.max_speed)
	vel.y = maxf(-last_impact_vel.y * rest, stats.rekick_vy_min)
	pos.y = maxf(pos.y, 0.0)
	rolling = false
	at_rest = false


func air_kick(boost: float) -> void:
	vel.x = minf(vel.x + boost, stats.max_speed)
	vel.y = maxf(vel.y, boost * 0.5)


## Ignores drag, so it slightly overestimates; good enough for buffering and the telegraph ring.
func time_to_touchdown() -> float:
	if not launched or rolling or at_rest:
		return INF
	var g: float = stats.gravity
	return (vel.y + sqrt(vel.y * vel.y + 2.0 * g * maxf(pos.y, 0.0))) / g
```

- [ ] **Step 4: Run the tests to confirm they pass**

Run: `./run_tests.sh`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/core/can_physics.gd test/test_can_physics.gd
git commit -m "Add deterministic CanPhysics with bounce, rekick and rest"
```

---
### Task 4: TapJudge and RunSim (timing, buffering, air kicks, watchdog)

**Files:**
- Create: `scripts/core/tap_judge.gd`, `scripts/core/run_sim.gd`, `test/test_tap_judge.gd`, `test/test_run_sim.gd`

**Interfaces:**
- Consumes: `CanPhysics` (Task 3), the stats keys (Task 2).
- Produces:
  - `TapJudge.Grade { MISS, GOOD, PERFECT }`
  - `TapJudge.grade(offset_s: float, perfect_window: float, good_window: float) -> int`
  - `TapJudge.in_reach(tap: Vector2, can_center: Vector2, reach_m: float) -> bool`
  - `RunSim.new(stats: Dictionary)` with fields `stats`, `can: CanPhysics`, `street` (untyped, `null` until Task 17), `ended: bool`, `air_kicks_left: int`, `perfect_count: int`
  - `RunSim.launch(angle_deg: float, power01: float) -> void`
  - `RunSim.can_center() -> Vector2`
  - `RunSim.tap(world_pos: Vector2) -> Dictionary` returns `{}` when ignored, otherwise one of:
    - `{"type":"tap_buffered"}`
    - `{"type":"air_kick","x"}`
    - a graded event `{"type":"graded","grade":int,"x":float,"super":bool}`
  - `RunSim.advance(dt: float) -> Array` of events, in order. Types:
    - `touchdown {x,t}`
    - `graded {grade,x,super}`
    - `rest {x,t}`
    - `run_end {x, reason: "rest"|"watchdog"}`
    - from Task 17: `helper {id,x,combo}` and `hazard {id,x,trampoline}`

**Timing rules (spec §2.3):**
- A tap within reach while airborne and `time_to_touchdown() <= good_window` is buffered. At touchdown it is graded by the real elapsed offset.
- With no buffered tap, the touchdown applies a dead bounce and opens a late window. A tap within `good_window` after touchdown is graded by time since touchdown and rekicks the can.
- When the late window expires with no tap, the result is `graded MISS`.
- Taps earlier than the window are ignored, unless an air-kick charge is left, in which case they spend it.
- A second tap for the same touchdown is ignored.

- [ ] **Step 1: Write the failing tests**

`test/test_tap_judge.gd`:
```gdscript
extends GutTest

func test_grade_windows_are_inclusive_and_symmetric():
	assert_eq(TapJudge.grade(0.0, 0.06, 0.13), TapJudge.Grade.PERFECT)
	assert_eq(TapJudge.grade(0.06, 0.06, 0.13), TapJudge.Grade.PERFECT)
	assert_eq(TapJudge.grade(-0.06, 0.06, 0.13), TapJudge.Grade.PERFECT)
	assert_eq(TapJudge.grade(0.0601, 0.06, 0.13), TapJudge.Grade.GOOD)
	assert_eq(TapJudge.grade(-0.13, 0.06, 0.13), TapJudge.Grade.GOOD)
	assert_eq(TapJudge.grade(0.1301, 0.06, 0.13), TapJudge.Grade.MISS)

func test_in_reach_uses_distance():
	assert_true(TapJudge.in_reach(Vector2(2.2, 0), Vector2.ZERO, 2.2))
	assert_false(TapJudge.in_reach(Vector2(2.21, 0), Vector2.ZERO, 2.2))
```

`test/test_run_sim.gd`:
```gdscript
extends GutTest

const STEP := 1.0 / 240.0
var stats: Dictionary

func before_each():
	stats = GameData.load_all().tuning.duplicate()
	stats.air_drag = 0.0

func _sim() -> RunSim:
	var s := RunSim.new(stats)
	s.launch(45.0, 1.0)
	return s

## Advances in small steps until ttd <= seconds; returns events seen.
func _until_ttd(s: RunSim, seconds: float) -> Array:
	var out: Array = []
	for i in 20000:
		if s.can.time_to_touchdown() <= seconds:
			break
		out.append_array(s.advance(STEP))
	return out

func _until_type(s: RunSim, type: String) -> Array:
	var out: Array = []
	for i in 40000:
		var ev := s.advance(STEP)
		out.append_array(ev)
		for e in ev:
			if e.type == type:
				return out
	return out

func _graded(events: Array) -> Array:
	return events.filter(func(e): return e.type == "graded")

func test_buffered_early_tap_grades_perfect_at_touchdown():
	var s := _sim()
	_until_ttd(s, 0.03)
	assert_eq(s.tap(s.can_center()).get("type"), "tap_buffered")
	var ev := _until_type(s, "graded")
	var g := _graded(ev)
	assert_eq(g.size(), 1)
	assert_eq(g[0].grade, TapJudge.Grade.PERFECT)
	assert_gt(s.can.vel.y, 0.0)
	assert_eq(s.perfect_count, 1)

func test_buffered_tap_at_100ms_grades_good():
	var s := _sim()
	_until_ttd(s, 0.10)
	s.tap(s.can_center())
	var g := _graded(_until_type(s, "graded"))
	assert_eq(g[0].grade, TapJudge.Grade.GOOD)

func test_late_tap_after_touchdown_grades_by_delay():
	var s := _sim()
	_until_type(s, "touchdown")
	s.advance(0.03)
	var r := s.tap(s.can_center())
	assert_eq(r.get("type"), "graded")
	assert_eq(r.grade, TapJudge.Grade.PERFECT)
	var s2 := _sim()
	_until_type(s2, "touchdown")
	s2.advance(0.09)
	assert_eq(s2.tap(s2.can_center()).grade, TapJudge.Grade.GOOD)

func test_no_tap_gives_miss_after_late_window():
	var s := _sim()
	_until_type(s, "touchdown")
	var ev := s.advance(stats.good_window + 0.01)
	var g := _graded(ev)
	assert_eq(g.size(), 1)
	assert_eq(g[0].grade, TapJudge.Grade.MISS)

func test_tap_out_of_reach_is_ignored():
	var s := _sim()
	_until_ttd(s, 0.03)
	assert_eq(s.tap(s.can_center() + Vector2(stats.tap_reach_m + 0.5, 0)), {})

func test_too_early_tap_is_ignored_then_window_tap_counts():
	var s := _sim()
	_until_ttd(s, 0.5)
	assert_eq(s.tap(s.can_center()), {})
	_until_ttd(s, 0.03)
	assert_eq(s.tap(s.can_center()).get("type"), "tap_buffered")
	assert_eq(_graded(_until_type(s, "graded"))[0].grade, TapJudge.Grade.PERFECT)

func test_second_tap_in_window_is_ignored():
	var s := _sim()
	_until_ttd(s, 0.05)
	s.tap(s.can_center())
	assert_eq(s.tap(s.can_center()), {})
	var g := _graded(_until_type(s, "graded"))
	assert_eq(g.size(), 1)

func test_long_hitch_keeps_event_order():
	var s := _sim()
	_until_ttd(s, 0.03)
	s.tap(s.can_center())
	var ev := s.advance(0.5)
	var types := ev.map(func(e): return e.type)
	assert_eq(types[0], "touchdown")
	assert_eq(types[1], "graded")
	assert_eq(ev[1].grade, TapJudge.Grade.PERFECT)
	assert_gte(s.can.pos.y, 0.0)

func test_run_ends_at_rest_without_taps():
	var s := _sim()
	var ev := _until_type(s, "run_end")
	assert_true(s.ended)
	assert_eq(ev[-1].reason, "rest")
	assert_eq(s.advance(1.0), [])

func test_rest_waits_for_open_late_window():
	var s := _sim()
	s.can.launch(5.0, 0.05)
	var ev := _until_type(s, "run_end")
	var types := ev.map(func(e): return e.type)
	assert_true(types.find("graded") < types.find("run_end"))

func test_air_kick_spends_charge_when_far_from_ground():
	stats.air_kicks = 1.0
	var s := _sim()
	s.advance(0.2)
	var vx := s.can.vel.x
	assert_eq(s.tap(s.can_center()).get("type"), "air_kick")
	assert_gt(s.can.vel.x, vx)
	assert_eq(s.tap(s.can_center()), {})

func test_super_kick_every_nth_perfect():
	stats.super_kick_every = 1.0
	var s := _sim()
	_until_ttd(s, 0.02)
	s.tap(s.can_center())
	var g := _graded(_until_type(s, "graded"))
	assert_true(g[0].super)

func test_watchdog_ends_endless_roll():
	stats.ground_friction = 0.0
	stats.max_run_time = 3.0
	var s := _sim()
	var ev := _until_type(s, "run_end")
	assert_eq(ev[-1].reason, "watchdog")
```

- [ ] **Step 2: Run them to confirm they fail**

Run: `./run_tests.sh -gtest=res://test/test_run_sim.gd`
Expected: `RunSim` / `TapJudge` are not defined.

- [ ] **Step 3: Implement TapJudge**

`scripts/core/tap_judge.gd`:
```gdscript
class_name TapJudge
extends RefCounted

enum Grade { MISS, GOOD, PERFECT }


static func grade(offset_s: float, perfect_window: float, good_window: float) -> int:
	var d := absf(offset_s)
	if d <= perfect_window:
		return Grade.PERFECT
	if d <= good_window:
		return Grade.GOOD
	return Grade.MISS


static func in_reach(tap: Vector2, can_center: Vector2, reach_m: float) -> bool:
	return tap.distance_to(can_center) <= reach_m
```

- [ ] **Step 4: Implement RunSim**

`scripts/core/run_sim.gd`:
```gdscript
class_name RunSim
extends RefCounted
## One run: can physics plus tap timing, air kicks, street objects and a stuck-run watchdog.

const STALL_SECONDS := 5.0

var stats: Dictionary
var can: CanPhysics
var street = null
var ended := false
var air_kicks_left := 0
var perfect_count := 0
var _buffered_tap_t := NAN
var _late_open := false
var _since_touchdown := 0.0
var _stall_x := 0.0
var _stall_t := 0.0
var _used := {}


func _init(p_stats: Dictionary) -> void:
	stats = p_stats
	can = CanPhysics.new(stats)
	air_kicks_left = int(stats.air_kicks)


func launch(angle_deg: float, power01: float) -> void:
	can.launch(angle_deg, power01)


func can_center() -> Vector2:
	return can.pos + Vector2(0.0, stats.can_half_height)


func tap(world_pos: Vector2) -> Dictionary:
	if ended or not can.launched:
		return {}
	if not TapJudge.in_reach(world_pos, can_center(), stats.tap_reach_m):
		return {}
	if _late_open:
		_late_open = false
		return _resolve(TapJudge.grade(_since_touchdown, stats.perfect_window, stats.good_window))
	if not is_nan(_buffered_tap_t):
		return {}
	var ttd := can.time_to_touchdown()
	if ttd <= stats.good_window:
		_buffered_tap_t = can.time
		return {"type": "tap_buffered"}
	if air_kicks_left > 0 and ttd < INF:
		air_kicks_left -= 1
		can.air_kick(stats.air_kick_boost)
		return {"type": "air_kick", "x": can.pos.x}
	return {}


func advance(dt: float) -> Array:
	var events: Array = []
	if ended or not can.launched:
		return events
	var remaining := dt
	while remaining > 0.0 and not ended:
		var prev := can.pos
		var chunk: Array = []
		var used := can.step(remaining, chunk)
		remaining -= used
		if _late_open:
			_since_touchdown += used
		_check_street(prev, chunk, events)
		for ev in chunk:
			events.append(ev)
			if ev.type == "touchdown":
				_on_touchdown(ev, events)
		if _late_open and _since_touchdown > stats.good_window:
			_late_open = false
			events.append(_resolve(TapJudge.Grade.MISS))
		_watchdog(used, events)
		if can.at_rest and not _late_open and not ended:
			_end("rest", events)
	return events


func _on_touchdown(ev: Dictionary, events: Array) -> void:
	if not is_nan(_buffered_tap_t):
		var offset: float = ev.t - _buffered_tap_t
		_buffered_tap_t = NAN
		events.append(_resolve(TapJudge.grade(offset, stats.perfect_window, stats.good_window)))
	else:
		_late_open = true
		_since_touchdown = 0.0


func _resolve(grade: int) -> Dictionary:
	var ev := {"type": "graded", "grade": grade, "x": can.pos.x, "super": false}
	if grade == TapJudge.Grade.MISS:
		return ev
	can.rekick(grade == TapJudge.Grade.PERFECT)
	if grade == TapJudge.Grade.PERFECT:
		perfect_count += 1
		var every := int(stats.super_kick_every)
		if every > 0 and perfect_count % every == 0:
			can.vel.x = minf(can.vel.x * stats.super_kick_mult, stats.max_speed)
			ev.super = true
	return ev


## Street objects arrive in Task 17.
func _check_street(_prev: Vector2, _chunk: Array, _events: Array) -> void:
	pass


func _watchdog(used: float, events: Array) -> void:
	if ended:
		return
	var p := can.pos
	var v := can.vel
	if not (is_finite(p.x) and is_finite(p.y) and is_finite(v.x) and is_finite(v.y)):
		_end("watchdog", events)
		return
	if can.time >= stats.max_run_time:
		_end("watchdog", events)
		return
	if can.at_rest:
		return
	if p.x - _stall_x > 0.01:
		_stall_x = p.x
		_stall_t = 0.0
	else:
		_stall_t += used
		if _stall_t >= STALL_SECONDS:
			_end("watchdog", events)


func _end(reason: String, events: Array) -> void:
	ended = true
	events.append({"type": "run_end", "x": can.pos.x, "reason": reason})
```

- [ ] **Step 5: Run the tests to confirm they pass**

Run: `./run_tests.sh`
Expected: all pass. If `test_rest_waits_for_open_late_window` fails because the can rests before its first touchdown, change that test's launch to `s.can.launch(8.0, 0.08)` so it bounces once before rolling. Do not change `RunSim`.

- [ ] **Step 6: Commit**

```bash
git add scripts/core/tap_judge.gd scripts/core/run_sim.gd test/test_tap_judge.gd test/test_run_sim.gd
git commit -m "Add TapJudge and RunSim with buffered and late tap grading"
```

---

### Task 5: LaunchAim

**Files:**
- Create: `scripts/core/launch_aim.gd`, `test/test_launch_aim.gd`

**Interfaces:**
- Consumes: `CanPhysics` and the stats keys `drag_min_px`, `drag_max_px`, `angle_min`, `angle_max`.
- Produces:
  - `LaunchAim.from_drag(drag: Vector2, stats: Dictionary) -> Dictionary` returns `{"valid":bool,"angle":float(deg),"power":float(0..1)}`. `drag` is the finger's current position minus its press position, in screen pixels with y down. Pulling back (left/down) launches right/up.
  - `LaunchAim.preview(angle_deg: float, power01: float, stats: Dictionary, count: int = 18, dt: float = 0.06) -> PackedVector2Array` returns world points up to the first touchdown.

- [ ] **Step 1: Write the failing tests**

`test/test_launch_aim.gd`:
```gdscript
extends GutTest

var stats: Dictionary

func before_each():
	stats = GameData.load_all().tuning.duplicate()

func test_tiny_drag_is_invalid():
	var a := LaunchAim.from_drag(Vector2(-5, 5), stats)
	assert_false(a.valid)

func test_pull_down_left_launches_up_right_at_45():
	var a := LaunchAim.from_drag(Vector2(-40, 40), stats)
	assert_true(a.valid)
	assert_almost_eq(a.angle, 45.0, 0.01)
	assert_almost_eq(a.power, Vector2(40, 40).length() / stats.drag_max_px, 0.001)

func test_power_clamps_at_one():
	assert_eq(LaunchAim.from_drag(Vector2(-500, 100), stats).power, 1.0)

func test_angle_clamps_to_range():
	assert_eq(LaunchAim.from_drag(Vector2(-5, 100), stats).angle, stats.angle_max)
	assert_eq(LaunchAim.from_drag(Vector2(-100, 0), stats).angle, stats.angle_min)
	assert_eq(LaunchAim.from_drag(Vector2(-100, -30), stats).angle, stats.angle_min)

func test_preview_rises_then_ends_at_ground():
	var pts := LaunchAim.preview(45.0, 1.0, stats)
	assert_gt(pts.size(), 3)
	assert_lte(pts.size(), 18)
	assert_gt(pts[0].x, 0.0)
	assert_gt(pts[2].y, 0.0)
```

- [ ] **Step 2: Run them to confirm they fail**

Run: `./run_tests.sh -gtest=res://test/test_launch_aim.gd`
Expected: `LaunchAim` is not defined.

- [ ] **Step 3: Implement**

`scripts/core/launch_aim.gd`:
```gdscript
class_name LaunchAim
extends RefCounted
## Slingshot aim: pulling back from the press point sets launch angle and power.


static func from_drag(drag: Vector2, stats: Dictionary) -> Dictionary:
	var length := drag.length()
	if length < stats.drag_min_px:
		return {"valid": false, "angle": 0.0, "power": 0.0}
	# Screen y is down, world y is up, and the launch goes opposite the pull.
	var launch_dir := Vector2(-drag.x, drag.y)
	var deg := clampf(rad_to_deg(atan2(launch_dir.y, launch_dir.x)), stats.angle_min, stats.angle_max)
	return {"valid": true, "angle": deg, "power": clampf(length / stats.drag_max_px, 0.0, 1.0)}


static func preview(angle_deg: float, power01: float, stats: Dictionary, count: int = 18, dt: float = 0.06) -> PackedVector2Array:
	var c := CanPhysics.new(stats)
	c.launch(angle_deg, power01)
	var pts := PackedVector2Array()
	for i in count:
		var ev: Array = []
		c.step(dt, ev)
		pts.append(c.pos)
		if not ev.is_empty():
			break
	return pts
```

- [ ] **Step 4: Run the tests to confirm they pass**

Run: `./run_tests.sh`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/core/launch_aim.gd test/test_launch_aim.gd
git commit -m "Add slingshot LaunchAim with clamped angle, power and arc preview"
```

---

### Task 6: Procedural sound effects (SynthSfx + Sfx)

**Files:**
- Create: `scripts/audio/synth_sfx.gd`, `scripts/audio/sfx.gd`, `test/test_sfx.gd`

**Interfaces:**
- Produces:
  - `SynthSfx.make(f0: float, f1: float, dur: float, noise: float = 0.0, decay: float = 8.0, vol: float = 0.8, noise_seed: int = 1) -> AudioStreamWAV` builds a 16-bit mono WAV at 22050 Hz.
  - `Sfx` (Node) with `streams: Dictionary` and `play(name: String, pitch: float = 1.0) -> void`. The names are `kick, perfect, good, miss, helper, hazard, coin, ui`.
- Note: Godot 4.7's web export defaults `audio/general/default_playback_type.web` to **Sample**, which plays through Web Audio directly for low latency. Leave it at the default. Godot resumes the browser's audio context on the first input event.

- [ ] **Step 1: Write the failing tests**

`test/test_sfx.gd`:
```gdscript
extends GutTest

func test_make_has_expected_length_and_format():
	var w := SynthSfx.make(440.0, 440.0, 0.1)
	assert_eq(w.format, AudioStreamWAV.FORMAT_16_BITS)
	assert_eq(w.mix_rate, SynthSfx.MIX_RATE)
	assert_false(w.stereo)
	assert_eq(w.data.size(), int(0.1 * SynthSfx.MIX_RATE) * 2)

func test_make_starts_silent_to_avoid_click():
	var w := SynthSfx.make(440.0, 440.0, 0.1, 0.5)
	assert_lt(absi(w.data.decode_s16(0)), 200)

func test_make_stays_in_range():
	var w := SynthSfx.make(200.0, 50.0, 0.2, 1.0, 1.0, 1.0)
	var peak := 0
	for i in range(0, w.data.size(), 2):
		peak = maxi(peak, absi(w.data.decode_s16(i)))
	assert_lte(peak, 32767)
	assert_gt(peak, 1000)

func test_sfx_builds_all_streams_and_plays_safely():
	var s := Sfx.new()
	add_child_autofree(s)
	for k in ["kick", "perfect", "good", "miss", "helper", "hazard", "coin", "ui"]:
		assert_true(s.streams.has(k), k)
	s.play("kick", 1.2)
	s.play("nope")
	assert_true(true, "unknown sound did not crash")
```

- [ ] **Step 2: Run them to confirm they fail**

Run: `./run_tests.sh -gtest=res://test/test_sfx.gd`
Expected: the classes are not defined.

- [ ] **Step 3: Implement**

`scripts/audio/synth_sfx.gd`:
```gdscript
class_name SynthSfx
extends RefCounted
## Tiny procedural sound generator so v1 ships without audio assets.

const MIX_RATE := 22050


static func make(f0: float, f1: float, dur: float, noise: float = 0.0, decay: float = 8.0, vol: float = 0.8, noise_seed: int = 1) -> AudioStreamWAV:
	var n := int(dur * MIX_RATE)
	var data := PackedByteArray()
	data.resize(n * 2)
	var rng := RandomNumberGenerator.new()
	rng.seed = noise_seed
	var phase := 0.0
	for i in n:
		var t := float(i) / MIX_RATE
		phase += TAU * lerpf(f0, f1, t / dur) / MIX_RATE
		# A 2.5 ms attack ramp avoids a click at the start.
		var env := exp(-decay * t) * minf(1.0, t * 400.0)
		var s := (sin(phase) * (1.0 - noise) + rng.randf_range(-1.0, 1.0) * noise) * env * vol
		data.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.data = data
	return wav
```

`scripts/audio/sfx.gd`:
```gdscript
class_name Sfx
extends Node
## Round-robin voice pool over preloaded procedural sounds.

const VOICES := 6
# name: [f0, f1, dur, noise, decay, vol]
const SOUNDS := {
	"kick": [140.0, 60.0, 0.12, 0.25, 18.0, 0.9],
	"perfect": [660.0, 990.0, 0.14, 0.0, 14.0, 0.6],
	"good": [440.0, 520.0, 0.10, 0.05, 18.0, 0.5],
	"miss": [180.0, 90.0, 0.10, 0.5, 25.0, 0.5],
	"helper": [300.0, 700.0, 0.18, 0.0, 10.0, 0.5],
	"hazard": [120.0, 80.0, 0.20, 0.7, 12.0, 0.5],
	"coin": [1320.0, 1760.0, 0.12, 0.0, 16.0, 0.4],
	"ui": [880.0, 880.0, 0.05, 0.0, 30.0, 0.3],
}

var streams := {}
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for k in SOUNDS:
		var a: Array = SOUNDS[k]
		streams[k] = SynthSfx.make(a[0], a[1], a[2], a[3], a[4], a[5])
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


func play(sound: String, pitch: float = 1.0) -> void:
	if not streams.has(sound):
		push_warning("Sfx: unknown sound %s" % sound)
		return
	var p := _players[_next]
	_next = (_next + 1) % VOICES
	p.stream = streams[sound]
	p.pitch_scale = pitch
	p.play()
```

- [ ] **Step 4: Run the tests to confirm they pass**

Run: `./run_tests.sh`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/audio test/test_sfx.gd
git commit -m "Add procedural SFX generator and voice pool"
```

---

### Task 7: Juice (hit-stop, shake, popups, bursts)

**Files:**
- Create: `scripts/view/juice.gd`, `test/test_juice.gd`

**Interfaces:**
- Produces `Juice` (Node, process always):
  - `shake_offset: Vector2`
  - `hitstop(duration: float)`, `end_hitstop()`, `shake(px: float)`
  - `advance_real(sec: float)` (driven from `_process` with real time; public for tests)
  - `popup(text: String, screen_pos: Vector2, color: Color, size: int = 16) -> Label`
  - `burst(parent: Node, screen_pos: Vector2, color: Color, amount: int = 14) -> CPUParticles2D`
  - `HITSTOP_SCALE := 0.05`

- [ ] **Step 1: Write the failing tests**

`test/test_juice.gd`:
```gdscript
extends GutTest

var j: Juice

func before_each():
	j = Juice.new()
	add_child_autofree(j)

func after_each():
	Engine.time_scale = 1.0

func test_hitstop_slows_then_restores_on_real_time():
	j.hitstop(0.06)
	assert_eq(Engine.time_scale, Juice.HITSTOP_SCALE)
	j.advance_real(0.03)
	assert_eq(Engine.time_scale, Juice.HITSTOP_SCALE)
	j.advance_real(0.04)
	assert_eq(Engine.time_scale, 1.0)

func test_end_hitstop_restores_immediately():
	j.hitstop(10.0)
	j.end_hitstop()
	assert_eq(Engine.time_scale, 1.0)

func test_shake_decays_to_zero():
	j.shake(4.0)
	j.advance_real(0.01)
	assert_lte(absf(j.shake_offset.x), 4.0)
	j.advance_real(1.0)
	assert_eq(j.shake_offset, Vector2.ZERO)

func test_popup_and_burst_create_nodes():
	var l := j.popup("PERFECT!", Vector2(100, 100), Color.YELLOW)
	assert_eq(l.text, "PERFECT!")
	assert_eq(l.get_parent(), j.popup_layer)
	var host := Node2D.new()
	add_child_autofree(host)
	var p := j.burst(host, Vector2(50, 50), Color.WHITE)
	assert_eq(p.get_parent(), host)
	assert_true(p.emitting)
```

- [ ] **Step 2: Run them to confirm they fail**

Run: `./run_tests.sh -gtest=res://test/test_juice.gd`
Expected: `Juice` is not defined.

- [ ] **Step 3: Implement**

`scripts/view/juice.gd`:
```gdscript
class_name Juice
extends Node
## Hit-stop, screen shake and popups; uses real time so hit-stop never stalls itself.

const HITSTOP_SCALE := 0.05
const SHAKE_DECAY_PX_PER_S := 40.0

var shake_offset := Vector2.ZERO
var popup_layer: CanvasLayer
var _hitstop_left := 0.0
var _shake := 0.0
var _last_usec := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	popup_layer = CanvasLayer.new()
	popup_layer.layer = 5
	add_child(popup_layer)
	_last_usec = Time.get_ticks_usec()


func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	advance_real((now - _last_usec) / 1_000_000.0)
	_last_usec = now


func advance_real(sec: float) -> void:
	if _hitstop_left > 0.0:
		_hitstop_left -= sec
		if _hitstop_left <= 0.0:
			end_hitstop()
	_shake = maxf(0.0, _shake - sec * SHAKE_DECAY_PX_PER_S)
	shake_offset = Vector2(_rng.randf_range(-_shake, _shake), _rng.randf_range(-_shake, _shake)).round()


func hitstop(duration: float) -> void:
	_hitstop_left = maxf(_hitstop_left, duration)
	Engine.time_scale = HITSTOP_SCALE


func end_hitstop() -> void:
	_hitstop_left = 0.0
	Engine.time_scale = 1.0


func shake(px: float) -> void:
	_shake = maxf(_shake, px)


func popup(text: String, screen_pos: Vector2, color: Color, size: int = 16) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(120, 0)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color("2f3245"))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popup_layer.add_child(l)
	l.position = screen_pos - Vector2(60, size)
	var tw := l.create_tween().set_ignore_time_scale(true)
	tw.tween_property(l, "position:y", l.position.y - 24.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.3).set_delay(0.2)
	tw.tween_callback(l.queue_free)
	return l


func burst(parent: Node, screen_pos: Vector2, color: Color, amount: int = 14) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.45
	p.explosiveness = 1.0
	p.spread = 180.0
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.gravity = Vector2(0, 260)
	p.scale_amount_min = 1.5
	p.scale_amount_max = 3.0
	p.color = color
	p.position = screen_pos
	parent.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0, true, false, true).timeout.connect(p.queue_free)
	return p
```

- [ ] **Step 4: Run the tests to confirm they pass**

Run: `./run_tests.sh`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/view/juice.gd test/test_juice.gd
git commit -m "Add Juice: real-time hit-stop, shake, popups and bursts"
```

---
### Task 8: Playable slice: LatencyProbe, Hud, RunView, Main (M0)

**Files:**
- Create: `scripts/core/latency_probe.gd`, `scripts/ui/ui_theme.gd`, `scripts/ui/hud.gd`, `scripts/view/run_view.gd`, `test/test_latency_probe.gd`, `test/test_run_view.gd`
- Modify: `scripts/main.gd` (replace the placeholder)

**Interfaces:**
- Consumes: `RunSim`, `LaunchAim`, `TapJudge`, `Juice`, `Sfx`, `GameData`.
- Produces:
  - `LatencyProbe`:
    - `mark_input(usec: int)`, `mark_frame(usec: int)`
    - `input_avg_ms() -> float`, `input_max_ms() -> float`, `frame_avg_ms() -> float`, `frame_max_ms() -> float`
  - `UiTheme.make() -> Theme` (default font size 12)
  - `Hud` (CanvasLayer): `set_distance(m: float)`, `set_combo(n: int)`, `show_message(t: String)`, `show_info(t: String)`
  - `RunView` (Node2D):
    - signals: `sim_event(ev: Dictionary)` (also emits `{"type":"launch","angle","power"}`), `progressed(x: float)`, `run_ended(ev: Dictionary)`
    - fields: `state: String` (`"idle"|"aiming"|"flying"|"done"`), `sim: RunSim`, `stats`, `cam_x`, `ground_y`, `ppm`
    - methods:
      - `setup(juice: Juice, sfx: Sfx, probe: LatencyProbe)`
      - `start_aim(stats: Dictionary, street = null)`
      - `set_palette(hex: Dictionary)`
      - `static default_palette() -> Dictionary` (hex strings: `sky_top, sky_bottom, hills, sidewalk, road, lane` plus arrays `houses, roofs`)
      - `world_to_screen(w: Vector2) -> Vector2`, `screen_to_world(s: Vector2) -> Vector2`
      - `begin_drag(pos: Vector2)`, `update_drag(pos: Vector2)`, `end_drag()`
      - `tap_screen(pos: Vector2) -> Dictionary`
      - `tick(delta: float)` (called from `_process`; public for tests)

- [ ] **Step 1: Write the failing tests**

`test/test_latency_probe.gd`:
```gdscript
extends GutTest

func test_input_to_next_frame_latency():
	var p := LatencyProbe.new()
	p.mark_frame(0)
	p.mark_input(1_000)
	p.mark_frame(5_000)
	p.mark_frame(21_000)
	assert_almost_eq(p.input_avg_ms(), 4.0, 0.001)
	assert_almost_eq(p.input_max_ms(), 4.0, 0.001)
	assert_almost_eq(p.frame_avg_ms(), (5.0 + 16.0) / 2.0, 0.001)
	assert_almost_eq(p.frame_max_ms(), 16.0, 0.001)

func test_only_first_input_before_a_frame_counts():
	var p := LatencyProbe.new()
	p.mark_input(0)
	p.mark_input(3_000)
	p.mark_frame(10_000)
	assert_almost_eq(p.input_avg_ms(), 10.0, 0.001)

func test_empty_probe_reports_zero():
	var p := LatencyProbe.new()
	assert_eq(p.input_avg_ms(), 0.0)
	assert_eq(p.frame_max_ms(), 0.0)
```

`test/test_run_view.gd`:
```gdscript
extends GutTest

var view: RunView
var stats: Dictionary

func before_each():
	stats = GameData.load_all().tuning.duplicate()
	var juice := Juice.new()
	add_child_autofree(juice)
	var sfx := Sfx.new()
	add_child_autofree(sfx)
	view = RunView.new()
	add_child_autofree(view)
	view.setup(juice, sfx, LatencyProbe.new())
	view.start_aim(stats)

func after_each():
	Engine.time_scale = 1.0

func test_world_screen_round_trip():
	var w := Vector2(3.0, 2.0)
	assert_almost_eq(view.screen_to_world(view.world_to_screen(w)).x, w.x, 0.1)
	assert_almost_eq(view.screen_to_world(view.world_to_screen(w)).y, w.y, 0.1)

func test_tiny_drag_does_not_launch():
	view.begin_drag(Vector2(100, 300))
	view.update_drag(Vector2(96, 303))
	view.end_drag()
	assert_eq(view.state, "aiming")
	assert_false(view.sim.can.launched)

func test_pull_back_launches():
	watch_signals(view)
	view.begin_drag(Vector2(100, 300))
	view.update_drag(Vector2(40, 360))
	view.end_drag()
	assert_eq(view.state, "flying")
	assert_true(view.sim.can.launched)
	assert_signal_emitted(view, "sim_event")

func test_run_plays_out_to_end():
	watch_signals(view)
	view.begin_drag(Vector2(100, 300))
	view.update_drag(Vector2(40, 360))
	view.end_drag()
	for i in 6000:
		view.tick(1.0 / 60.0)
		if view.state == "done":
			break
	assert_eq(view.state, "done")
	assert_signal_emitted(view, "run_ended")
	assert_gt(view.cam_x, 0.0)

func test_tap_far_from_can_is_ignored():
	view.begin_drag(Vector2(100, 300))
	view.update_drag(Vector2(40, 360))
	view.end_drag()
	assert_eq(view.tap_screen(Vector2(269, 584)), {})
```

- [ ] **Step 2: Run them to confirm they fail**

Run: `./run_tests.sh -gtest=res://test/test_run_view.gd`
Expected: the classes are not defined.

- [ ] **Step 3: Implement LatencyProbe**

`scripts/core/latency_probe.gd`:
```gdscript
class_name LatencyProbe
extends RefCounted
## Rolling input→frame and frame-time samples for the tuning overlay.

const SAMPLES := 30

var _pending_usec := -1
var _last_frame_usec := -1
var _input_ms: Array[float] = []
var _frame_ms: Array[float] = []


func mark_input(usec: int) -> void:
	if _pending_usec < 0:
		_pending_usec = usec


func mark_frame(usec: int) -> void:
	if _last_frame_usec >= 0:
		_push(_frame_ms, (usec - _last_frame_usec) / 1000.0)
	_last_frame_usec = usec
	if _pending_usec >= 0:
		_push(_input_ms, (usec - _pending_usec) / 1000.0)
		_pending_usec = -1


func input_avg_ms() -> float:
	return _avg(_input_ms)


func input_max_ms() -> float:
	return _input_ms.max() if not _input_ms.is_empty() else 0.0


func frame_avg_ms() -> float:
	return _avg(_frame_ms)


func frame_max_ms() -> float:
	return _frame_ms.max() if not _frame_ms.is_empty() else 0.0


func _push(arr: Array[float], v: float) -> void:
	arr.append(v)
	if arr.size() > SAMPLES:
		arr.pop_front()


func _avg(arr: Array[float]) -> float:
	if arr.is_empty():
		return 0.0
	var s := 0.0
	for v in arr:
		s += v
	return s / arr.size()
```

- [ ] **Step 4: Implement UiTheme and Hud**

`scripts/ui/ui_theme.gd`:
```gdscript
class_name UiTheme
extends RefCounted
## Shared placeholder theme; the art pass swaps in a pixel font.

const INK := Color("2f3245")
const GOLD := Color("ffd166")
const PAPER := Color("fff6e0")


static func make() -> Theme:
	var t := Theme.new()
	t.default_font_size = 12
	t.set_color("font_color", "Label", INK)
	t.set_color("font_outline_color", "Label", PAPER)
	t.set_constant("outline_size", "Label", 3)
	return t
```

`scripts/ui/hud.gd`:
```gdscript
class_name Hud
extends CanvasLayer
## In-run readouts: distance, combo, info line and a bottom message.

var root: Control
var distance_label: Label
var combo_label: Label
var info_label: Label
var message_label: Label


func _ready() -> void:
	layer = 2
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UiTheme.make()
	add_child(root)
	distance_label = _label(Rect2(8, 8, 140, 20), HORIZONTAL_ALIGNMENT_LEFT, 16)
	combo_label = _label(Rect2(150, 8, 112, 20), HORIZONTAL_ALIGNMENT_RIGHT, 16)
	info_label = _label(Rect2(8, 30, 254, 16), HORIZONTAL_ALIGNMENT_LEFT, 10)
	message_label = _label(Rect2(10, 470, 250, 40), HORIZONTAL_ALIGNMENT_CENTER, 13)
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART


func _label(r: Rect2, align: HorizontalAlignment, size: int) -> Label:
	var l := Label.new()
	l.position = r.position
	l.size = r.size
	l.horizontal_alignment = align
	l.add_theme_font_size_override("font_size", size)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(l)
	return l


func set_distance(m: float) -> void:
	distance_label.text = "%.1f m" % m


func set_combo(n: int) -> void:
	combo_label.text = "x%d" % n if n > 0 else ""


func show_message(t: String) -> void:
	message_label.text = t


func show_info(t: String) -> void:
	info_label.text = t
```

- [ ] **Step 5: Implement RunView**

`scripts/view/run_view.gd`:
```gdscript
class_name RunView
extends Node2D
## Draws the street and can in code, turns touches into aim and taps, and forwards sim events.

signal sim_event(ev: Dictionary)
signal progressed(x: float)
signal run_ended(ev: Dictionary)

const CAN_SCREEN_X := 90.0
const KID_X := -0.9
const HOUSE_SPACING_M := 7.0
const RING_LEAD_S := 0.5
const CAMERA_FOLLOW := 8.0

var stats: Dictionary = {}
var sim: RunSim
var juice: Juice
var sfx: Sfx
var probe: LatencyProbe
var state := "idle"
var cam_x := 0.0
var ground_y := 410.0
var ppm := 14.0
var _pal := {}
var _drag_index := -1
var _drag_start := Vector2.ZERO
var _aim := {"valid": false}
var _preview := PackedVector2Array()
var _squash := 0.0


static func default_palette() -> Dictionary:
	return {
		"sky_top": "8fd3f4", "sky_bottom": "fbe3c4", "hills": "a8d5a2",
		"sidewalk": "d9d4cc", "road": "5d5f71", "lane": "e9e6ee",
		"houses": ["f7b267", "9ad1d4", "f4d35e", "f6bd60"],
		"roofs": ["e5676a", "4a6fa5", "ee964b", "84a59d"],
	}


func _ready() -> void:
	ground_y = roundf(get_viewport_rect().size.y * 0.7)
	if _pal.is_empty():
		set_palette(default_palette())


func setup(p_juice: Juice, p_sfx: Sfx, p_probe: LatencyProbe) -> void:
	juice = p_juice
	sfx = p_sfx
	probe = p_probe


func set_palette(hex: Dictionary) -> void:
	_pal = {}
	for k in hex:
		_pal[k] = hex[k].map(func(h): return Color(h)) if hex[k] is Array else Color(hex[k])
	queue_redraw()


func start_aim(p_stats: Dictionary, street = null) -> void:
	stats = p_stats
	ppm = stats.px_per_m
	sim = RunSim.new(stats)
	sim.street = street
	state = "aiming"
	cam_x = -CAN_SCREEN_X / ppm
	_aim = {"valid": false}
	_preview = PackedVector2Array()
	_drag_index = -1
	queue_redraw()


func world_to_screen(w: Vector2) -> Vector2:
	return Vector2(roundf((w.x - cam_x) * ppm), roundf(ground_y - w.y * ppm))


func screen_to_world(s: Vector2) -> Vector2:
	return Vector2(s.x / ppm + cam_x, (ground_y - s.y) / ppm)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if probe:
			probe.mark_input(Time.get_ticks_usec())
		if state == "aiming":
			if event.pressed and _drag_index == -1:
				_drag_index = event.index
				begin_drag(event.position)
			elif not event.pressed and event.index == _drag_index:
				end_drag()
			get_viewport().set_input_as_handled()
		elif state == "flying" and event.pressed:
			tap_screen(event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and state == "aiming" and event.index == _drag_index:
		update_drag(event.position)
		get_viewport().set_input_as_handled()


func begin_drag(pos: Vector2) -> void:
	_drag_start = pos
	_aim = {"valid": false}


func update_drag(pos: Vector2) -> void:
	_aim = LaunchAim.from_drag(pos - _drag_start, stats)
	_preview = LaunchAim.preview(_aim.angle, _aim.power, stats) if _aim.valid else PackedVector2Array()
	queue_redraw()


func end_drag() -> void:
	_drag_index = -1
	_preview = PackedVector2Array()
	if state != "aiming" or not _aim.valid:
		queue_redraw()
		return
	sim.launch(_aim.angle, _aim.power)
	state = "flying"
	sfx.play("kick")
	juice.hitstop(0.05)
	juice.shake(3.0)
	sim_event.emit({"type": "launch", "angle": _aim.angle, "power": _aim.power})


func tap_screen(pos: Vector2) -> Dictionary:
	if state != "flying":
		return {}
	var r := sim.tap(screen_to_world(pos))
	if not r.is_empty():
		_react(r)
		sim_event.emit(r)
	return r


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	if probe:
		probe.mark_frame(Time.get_ticks_usec())
	if juice:
		position = juice.shake_offset
	_squash = maxf(0.0, _squash - delta * 6.0)
	if state == "flying":
		for ev in sim.advance(delta):
			_react(ev)
			sim_event.emit(ev)
			if ev.type == "run_end":
				state = "done"
				run_ended.emit(ev)
		var target := sim.can.pos.x - CAN_SCREEN_X / ppm
		cam_x = maxf(cam_x, lerpf(cam_x, target, minf(1.0, delta * CAMERA_FOLLOW)))
		progressed.emit(sim.can.pos.x)
	queue_redraw()


func _react(ev: Dictionary) -> void:
	var at := world_to_screen(sim.can_center())
	match ev.type:
		"graded":
			_squash = 1.0
			match ev.grade:
				TapJudge.Grade.PERFECT:
					sfx.play("perfect", randf_range(0.97, 1.05))
					juice.hitstop(0.06)
					juice.shake(4.0)
					juice.popup("SUPER!" if ev.super else "PERFECT!", at + Vector2(0, -22), UiTheme.GOLD, 18)
					juice.burst(self, at, UiTheme.GOLD, 18)
				TapJudge.Grade.GOOD:
					sfx.play("good")
					juice.shake(2.0)
					juice.popup("GOOD", at + Vector2(0, -20), Color.WHITE, 14)
					juice.burst(self, at, Color.WHITE, 8)
				_:
					sfx.play("miss")
					juice.popup("miss", at + Vector2(0, -18), Color("9a9aa8"), 12)
		"air_kick":
			sfx.play("kick", 1.3)
			juice.shake(2.0)
			juice.popup("AIR!", at + Vector2(0, -20), Color.WHITE, 14)
		"touchdown":
			_squash = 1.0
			juice.burst(self, world_to_screen(sim.can.pos), _pal.get("sidewalk", Color.WHITE), 5)
		"helper":
			sfx.play("helper")
			juice.shake(3.0)
			juice.popup("BOING", at + Vector2(0, -20), Color.WHITE, 14)
		"hazard":
			sfx.play("helper" if ev.get("trampoline", false) else "hazard")
			juice.popup(str(ev.id).replace("_", " "), at + Vector2(0, -18), Color("9a9aa8"), 12)


func _draw() -> void:
	var size := get_viewport_rect().size
	_draw_sky(size)
	_draw_hills(size)
	_draw_houses(size)
	_draw_street(size)
	_draw_objects(size)
	if state != "idle":
		_draw_kid()
	if sim:
		_draw_shadow_and_ring()
		_draw_can()
	for i in _preview.size():
		draw_circle(world_to_screen(_preview[i]), 1.5 if i % 2 == 0 else 1.0, Color(1, 1, 1, 0.9))


func _draw_sky(size: Vector2) -> void:
	var bands := 10
	var h := (ground_y - 6.0) / bands
	for i in bands:
		draw_rect(Rect2(0, i * h, size.x, h + 1.0), _pal.sky_top.lerp(_pal.sky_bottom, float(i) / (bands - 1)))
	draw_circle(Vector2(size.x - 60, 110), 26.0, Color("fff4d6"))


func _draw_hills(size: Vector2) -> void:
	var base := ground_y - 6.0
	var pts := PackedVector2Array([Vector2(0, base)])
	var x := 0.0
	while x <= size.x + 6.0:
		var wx := x / ppm + cam_x * 0.3
		pts.append(Vector2(x, base - 50.0 - 14.0 * sin(wx * 0.35) - 8.0 * sin(wx * 0.9)))
		x += 6.0
	pts.append(Vector2(size.x + 6.0, base))
	draw_colored_polygon(pts, _pal.hills)


func _draw_houses(size: Vector2) -> void:
	var houses: Array = _pal.houses
	var roofs: Array = _pal.roofs
	var base := ground_y - 6.0
	var win := Color("fff6e0")
	var first := int(floor(cam_x / HOUSE_SPACING_M)) - 1
	var last := int(ceil((cam_x + size.x / ppm) / HOUSE_SPACING_M)) + 1
	for i in range(first, last + 1):
		var h := absi(hash(i))
		var x0 := (i * HOUSE_SPACING_M - cam_x) * ppm
		var w := 5.0 * ppm
		var ht := (3.0 + float(h % 17) / 10.0) * ppm
		draw_rect(Rect2(x0, base - ht, w, ht), houses[h % houses.size()])
		draw_colored_polygon(PackedVector2Array([
			Vector2(x0 - 4, base - ht), Vector2(x0 + w / 2, base - ht - 1.6 * ppm), Vector2(x0 + w + 4, base - ht)
		]), roofs[(h / 7) % roofs.size()])
		draw_rect(Rect2(x0 + 0.8 * ppm, base - ht + 0.8 * ppm, ppm, ppm), win)
		draw_rect(Rect2(x0 + w - 1.8 * ppm, base - ht + 0.8 * ppm, ppm, ppm), win)


func _draw_street(size: Vector2) -> void:
	draw_rect(Rect2(0, ground_y - 6, size.x, 16), _pal.sidewalk)
	draw_rect(Rect2(0, ground_y + 10, size.x, size.y - ground_y - 10), _pal.road)
	var dash := 4.0
	var wx := floorf(cam_x / dash) * dash
	while (wx - cam_x) * ppm < size.x:
		draw_rect(Rect2((wx - cam_x) * ppm, ground_y + 60, 1.6 * ppm, 3), _pal.lane)
		wx += dash


## Street objects arrive in Task 17.
func _draw_objects(_size: Vector2) -> void:
	pass


func _draw_kid() -> void:
	var f := world_to_screen(Vector2(KID_X, 0))
	var pants := Color("2f3245")
	draw_rect(Rect2(f.x - 5, f.y - 24, 10, 12), Color("3f8fd6"))
	draw_circle(f + Vector2(0, -29), 5.0, Color("f2c79a"))
	draw_rect(Rect2(f.x - 5, f.y - 35, 10, 4), Color("3d2c2e"))
	draw_rect(Rect2(f.x - 4, f.y - 12, 3, 12), pants)
	if state == "aiming":
		draw_rect(Rect2(f.x + 1, f.y - 12, 3, 12), pants)
	else:
		draw_set_transform(f + Vector2(2, -12), -0.9, Vector2.ONE)
		draw_rect(Rect2(0, 0, 3, 12), pants)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_shadow_and_ring() -> void:
	var g := world_to_screen(Vector2(sim.can.pos.x, 0))
	var k := 1.0 / (1.0 + sim.can.pos.y * 0.15)
	draw_set_transform(g, 0.0, Vector2(1.0, 0.35))
	draw_circle(Vector2.ZERO, 6.0 * k, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if state != "flying":
		return
	var ttd := sim.can.time_to_touchdown()
	if ttd < RING_LEAD_S:
		draw_arc(world_to_screen(sim.can_center()), 8.0 + ttd * 60.0, 0.0, TAU, 24, Color(1, 1, 1, 0.85), 1.0)


func _draw_can() -> void:
	var c := world_to_screen(sim.can_center())
	if c.y < 6.0:
		# Off the top of the screen: show a marker instead.
		draw_colored_polygon(PackedVector2Array([Vector2(c.x, 2), Vector2(c.x - 4, 9), Vector2(c.x + 4, 9)]), Color("e63946"))
		return
	var w: float = stats.can_radius * 2.0 * ppm
	var h: float = stats.can_half_height * 2.0 * ppm
	draw_set_transform(c, sim.can.angle, Vector2(1.0 + 0.35 * _squash, 1.0 - 0.35 * _squash))
	draw_rect(Rect2(-w / 2, -h / 2, w, h), Color("e63946"))
	draw_rect(Rect2(-w / 2, -h / 2, w, 2), Color("e6e6e6"))
	draw_rect(Rect2(-w / 2, h / 2 - 2, w, 2), Color("bdbdbd"))
	draw_rect(Rect2(-w / 2 + 1, -1, w - 2, 2), Color.WHITE)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
```

- [ ] **Step 6: Replace `scripts/main.gd` with the M0 loop**

```gdscript
extends Node2D
## M0 loop: aim → run → tap to kick again. Task 20 replaces this with the full game flow.

var data: GameData
var stats: Dictionary
var juice: Juice
var sfx: Sfx
var probe := LatencyProbe.new()
var run_view: RunView
var hud: Hud
var combo := 0
var _waiting_restart := false


func _ready() -> void:
	data = GameData.load_all()
	stats = data.tuning.duplicate()
	juice = Juice.new()
	add_child(juice)
	sfx = Sfx.new()
	add_child(sfx)
	run_view = RunView.new()
	add_child(run_view)
	run_view.setup(juice, sfx, probe)
	hud = Hud.new()
	add_child(hud)
	run_view.sim_event.connect(_on_sim_event)
	run_view.progressed.connect(hud.set_distance)
	run_view.run_ended.connect(_on_run_ended)
	_new_run()


func _new_run() -> void:
	combo = 0
	hud.set_combo(0)
	hud.set_distance(0.0)
	hud.show_message("Pull back and release to kick")
	run_view.start_aim(stats)


func _on_sim_event(ev: Dictionary) -> void:
	match ev.type:
		"launch":
			hud.show_message("")
		"graded":
			if ev.grade == TapJudge.Grade.PERFECT:
				combo += 1
			elif ev.grade == TapJudge.Grade.MISS:
				combo = 0
			hud.set_combo(combo)


func _on_run_ended(ev: Dictionary) -> void:
	hud.show_message("%.1f m. Tap to kick again" % ev.x)
	_waiting_restart = true


func _unhandled_input(event: InputEvent) -> void:
	if _waiting_restart and event is InputEventScreenTouch and event.pressed:
		_waiting_restart = false
		_new_run()
```

- [ ] **Step 7: Run all tests**

Run: `./run_tests.sh`
Expected: all pass, including `test_smoke.gd`.

- [ ] **Step 8: Visual sanity check on desktop**

Run: `./build_web.sh`. Then start the preview with `preview_start {name: "procrastican-web"}` and open it in the browser pane.
- Drag back from the left side and release: the can launches.
- The street scrolls and a ring tightens before each touchdown.
- Tapping the can near touchdown pops PERFECT or GOOD.
- No errors show in `read_console_messages`.

Take a screenshot for the task report.

- [ ] **Step 9: Commit**

```bash
git add scripts test
git commit -m "Add playable M0 slice: RunView, HUD, latency probe and main loop"
```

---

### Task 9: Tuning overlay

**Files:**
- Create: `scripts/ui/tuning_overlay.gd`, `test/test_tuning_overlay.gd`
- Modify: `scripts/main.gd` (add the overlay in `_ready`)

**Interfaces:**
- Consumes: the shared `stats` Dictionary (the same instance `RunSim` reads, so edits apply live) and `LatencyProbe`.
- Produces `TuningOverlay` (CanvasLayer):
  - `KEYS: Array[String]`
  - `setup(stats: Dictionary, probe: LatencyProbe)` (call **before** `add_child`)
  - `toggle()`, `set_value(key: String, v: float)`, `export_text() -> String` (JSON of `KEYS`), `readout_text() -> String`
- Opens with a three-finger touch or the F1 key.

- [ ] **Step 1: Write the failing test**

`test/test_tuning_overlay.gd`:
```gdscript
extends GutTest

var stats: Dictionary
var o: TuningOverlay

func before_each():
	stats = GameData.load_all().tuning.duplicate()
	o = TuningOverlay.new()
	o.setup(stats, LatencyProbe.new())
	add_child_autofree(o)

func test_starts_hidden_and_toggles():
	assert_false(o.visible)
	o.toggle()
	assert_true(o.visible)

func test_set_value_edits_shared_stats():
	o.set_value("gravity", 42.0)
	assert_eq(stats.gravity, 42.0)

func test_export_contains_every_key():
	var parsed = JSON.parse_string(o.export_text())
	for k in TuningOverlay.KEYS:
		assert_true(parsed.has(k), k)

func test_readout_mentions_latency():
	assert_string_contains(o.readout_text(), "input")
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `./run_tests.sh -gtest=res://test/test_tuning_overlay.gd`
Expected: `TuningOverlay` is not defined.

- [ ] **Step 3: Implement**

`scripts/ui/tuning_overlay.gd`:
```gdscript
class_name TuningOverlay
extends CanvasLayer
## Hidden live-tuning panel with latency readout; three-finger touch or F1 toggles it.

const KEYS: Array[String] = [
	"gravity", "air_drag", "launch_speed_max", "restitution_miss", "restitution_good",
	"restitution_perfect", "good_vx_keep", "perfect_vx_boost", "rekick_vy_min",
	"ground_friction", "perfect_window", "good_window", "tap_reach_m", "px_per_m",
]

var stats: Dictionary
var probe: LatencyProbe
var _readout: Label
var _export: TextEdit
var _value_labels := {}
var _touches := {}


func setup(p_stats: Dictionary, p_probe: LatencyProbe) -> void:
	stats = p_stats
	probe = p_probe


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.theme = UiTheme.make()
	panel.theme.default_font_size = 9
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.8)
	panel.add_theme_stylebox_override("panel", bg)
	add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	_readout = Label.new()
	_readout.add_theme_color_override("font_color", Color.WHITE)
	_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_readout)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(rows)
	for k in KEYS:
		_add_row(rows, k)
	_export = TextEdit.new()
	_export.custom_minimum_size = Vector2(0, 90)
	_export.editable = false
	box.add_child(_export)
	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	var copy := Button.new()
	copy.text = "Copy"
	copy.pressed.connect(func(): DisplayServer.clipboard_set(export_text()))
	buttons.add_child(copy)
	var close := Button.new()
	close.text = "Close"
	close.pressed.connect(toggle)
	buttons.add_child(close)
	_refresh_export()


func _add_row(rows: VBoxContainer, key: String) -> void:
	var base: float = stats[key]
	var label := Label.new()
	label.add_theme_color_override("font_color", Color.WHITE)
	rows.add_child(label)
	_value_labels[key] = label
	var slider := HSlider.new()
	slider.min_value = base * 0.25 if base > 0.0 else 0.0
	slider.max_value = base * 2.5 if base > 0.0 else 1.0
	slider.step = (slider.max_value - slider.min_value) / 200.0
	slider.value = base
	slider.value_changed.connect(func(v): set_value(key, v))
	rows.add_child(slider)
	_update_label(key)


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = true
			if _touches.size() >= 3:
				toggle()
		else:
			_touches.erase(event.index)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_F1:
		toggle()


func _process(_delta: float) -> void:
	if visible:
		_readout.text = readout_text()


func toggle() -> void:
	visible = not visible
	_touches.clear()
	if visible:
		_refresh_export()


func set_value(key: String, v: float) -> void:
	stats[key] = v
	_update_label(key)
	_refresh_export()


func export_text() -> String:
	var out := {}
	for k in KEYS:
		out[k] = stats[k]
	return JSON.stringify(out, "\t")


func readout_text() -> String:
	return "fps %d | frame avg %.1f max %.1f ms | input→frame avg %.1f max %.1f ms" % [
		int(Engine.get_frames_per_second()), probe.frame_avg_ms(), probe.frame_max_ms(),
		probe.input_avg_ms(), probe.input_max_ms()]


func _update_label(key: String) -> void:
	if _value_labels.has(key):
		_value_labels[key].text = "%s = %.3f" % [key, stats[key]]


func _refresh_export() -> void:
	if _export:
		_export.text = export_text()
```

- [ ] **Step 4: Wire it into `scripts/main.gd`**

Add a field `var overlay: TuningOverlay`. At the end of `_ready()`, before `_new_run()`, add:
```gdscript
	overlay = TuningOverlay.new()
	overlay.setup(stats, probe)
	add_child(overlay)
```

- [ ] **Step 5: Run all tests**

Run: `./run_tests.sh`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/tuning_overlay.gd scripts/main.gd test/test_tuning_overlay.gd
git commit -m "Add live tuning overlay with latency readout"
```

---

### Task 10: Web build and iPhone feel test (GO/NO-GO GATE)

**Files:**
- Create: `docs/feel-test-m0.md`

- [ ] **Step 1: Run the full suite and the build**

Run: `./run_tests.sh && ./build_web.sh`
Expected: all tests pass and "Web build ready in build/web" is printed.

- [ ] **Step 2: Smoke-test locally**

Use `preview_start {name: "procrastican-web"}`.
- Check `read_console_messages` for errors.
- Launch two runs with the mouse.
- Press F1 and confirm the overlay opens and the readout updates.
- Screenshot it.

- [ ] **Step 3: Write the result template**

`docs/feel-test-m0.md`:
```markdown
# M0 Feel Test (spec §6.1)

Device: ______  iOS: ______  Installed to home screen: yes / no

| Check | Pass? | Notes / overlay numbers |
|---|---|---|
| 1. Taps feel instant (input→frame avg/max) | | |
| 2. Kick SFX lands with the hit (no noticeable lag) | | |
| 3. Steady 60 fps (frame avg/max) | | |

Tuned values (paste from overlay "Copy"):

Decision: GO (web) / NO-GO (switch to native iOS export)
```

Commit:
```bash
git add docs/feel-test-m0.md
git commit -m "Add M0 feel-test record template"
```

- [ ] **Step 4: STOP and hand off to the user**

Do not deploy. Ask the user to run these steps themselves, from the repo:
1. `./build_web.sh` (already done), then `cd build/web && vercel link` (first time only; project name `procrastican`), then back in the repo root, `./deploy_web.sh`.
2. Open the URL in iPhone Safari, Share → Add to Home Screen, launch it from the home screen.
3. Play about 10 runs. Open the overlay with a three-finger tap and note its numbers. Judge the three checks.
4. If Vercel shows a login page, turn off Deployment Protection in the project settings.

Fill in `docs/feel-test-m0.md` from the user's answers. If they tuned values, copy them into `data/tuning.json`. Then commit.

**If NO-GO:** stop executing this plan. Report back so a native-iOS export task can be planned. **If GO:** continue to Phase B.

---
# Phase B — Progression (only after a GO in Task 10)

### Task 11: NumFmt

**Files:**
- Create: `scripts/core/num_fmt.gd`, `test/test_num_fmt.gd`

**Interfaces:**
- Produces: `NumFmt.format(n: float) -> String`. Below 1000 it prints the integer floor. Above that it prints one decimal plus a suffix (K M B T Qa Qi Sx Sp Oc No Dc). Beyond Dc it prints `m.mme<exp>`. Infinity prints `∞` and NaN prints `0`.

- [ ] **Step 1: Write the failing test**

`test/test_num_fmt.gd`:
```gdscript
extends GutTest

func test_small_numbers_are_plain_integers():
	assert_eq(NumFmt.format(0.0), "0")
	assert_eq(NumFmt.format(12.7), "12")
	assert_eq(NumFmt.format(999.0), "999")

func test_suffix_boundaries_round_up_cleanly():
	assert_eq(NumFmt.format(999.96), "1.0K")
	assert_eq(NumFmt.format(1000.0), "1.0K")
	assert_eq(NumFmt.format(1450.0), "1.4K")
	assert_eq(NumFmt.format(999_949.0), "999.9K")
	assert_eq(NumFmt.format(999_950.0), "1.0M")
	assert_eq(NumFmt.format(3.2e6), "3.2M")
	assert_eq(NumFmt.format(8.1e9), "8.1B")
	assert_eq(NumFmt.format(2.3e12), "2.3T")

func test_huge_and_special_values():
	assert_eq(NumFmt.format(1e30), "1.0No")
	assert_eq(NumFmt.format(1e40), "1.00e40")
	assert_eq(NumFmt.format(INF), "∞")
	assert_eq(NumFmt.format(NAN), "0")
	assert_eq(NumFmt.format(-1500.0), "-1.5K")
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `./run_tests.sh -gtest=res://test/test_num_fmt.gd`
Expected: `NumFmt` is not defined.

- [ ] **Step 3: Implement**

`scripts/core/num_fmt.gd`:
```gdscript
class_name NumFmt
extends RefCounted
## Idle-game number abbreviation: 1.2K, 34.5M, 8.1B …

const SUFFIXES: Array[String] = ["", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc"]


static func format(n: float) -> String:
	if is_nan(n):
		return "0"
	if is_inf(n):
		return "∞" if n > 0.0 else "-∞"
	var sign := "-" if n < 0.0 else ""
	var v := absf(n)
	if v < 999.95:
		return sign + str(int(floorf(v)))
	var tier := 0
	while v >= 999.95 and tier < SUFFIXES.size() - 1:
		v /= 1000.0
		tier += 1
	if v >= 999.95:
		var e := int(floorf(log(absf(n)) / log(10.0)))
		return sign + "%.2fe%d" % [absf(n) / pow(10.0, e), e]
	return sign + ("%.1f" % v) + SUFFIXES[tier]
```
*(Values in 999–999.95 print "999" through the integer branch. That's intended.)*

- [ ] **Step 4: Run the tests to confirm they pass**

Run: `./run_tests.sh`
Expected: all pass. Floating-point log can land `1e40` at exponent 39 with mantissa 10.00. If that happens, normalize after the computation: `if mantissa >= 9.995: mantissa /= 10; e += 1`.

- [ ] **Step 5: Commit**

```bash
git add scripts/core/num_fmt.gd test/test_num_fmt.gd
git commit -m "Add NumFmt big-number abbreviation"
```

---

### Task 12: Content data, GameData extension, StatResolver

**Files:**
- Create: `data/upgrades.json`, `data/cans.json`, `data/perks.json`, `data/modifiers.json`, `data/zones.json`, `data/objects.json`, `scripts/core/stat_resolver.gd`, `test/test_stat_resolver.gd`, `test/test_content_data.gd`
- Modify: `scripts/core/game_data.gd`

**Interfaces:**
- **Effect** shape (shared by upgrades, cans, perks and modifiers): `{"stat": String (a REQUIRED_STATS key), "op": "add"|"mul", "value": float}`
- Produces:
  - `StatResolver.resolve(base: Dictionary, effects: Array) -> Dictionary` returns a new dict: `(base + Σadd) × Πmul` per stat. It is order-independent, never mutates `base`, and warns on and skips unknown stats.
  - `GameData` gains:
    - `upgrades: Array`, `cans: Array`, `perks: Array`, `modifiers: Array`, `zones: Array`, `objects: Dictionary`
    - `upgrade(id: String) -> Dictionary`, `can(id: String) -> Dictionary` (each returns `{}` if not found)
- Data shapes:
  - upgrade: `{id, track: "gear"|"skills"|"luck", name, desc, base_cost, cost_growth, max_level, effects}`
  - can: `{id, name, desc, cost, effects}`
  - perk: `{id, name, desc, rarity: "common"|"rare"|"epic", effects}`
  - modifier: `{id, name, desc, weight, effects}`
  - zone: `{id, name, start_m, value, helpers_per_chunk, hazards_per_chunk, helpers: [ids], hazards: [ids], palette: {…RunView.default_palette() keys}}`
  - object, keyed by id:
    - helper: `{kind: "helper", height, bounce_vy, speed_mult, combo, color}`
    - hazard: `{kind: "hazard", width, speed_keep, color}`

- [ ] **Step 1: Write the content data**

`data/upgrades.json`:
```json
[
	{"id": "kick_power", "track": "gear", "name": "Kick Power", "desc": "Harder launch kick", "base_cost": 10, "cost_growth": 1.55, "max_level": 40,
	 "effects": [{"stat": "launch_speed_max", "op": "add", "value": 1.0}, {"stat": "max_speed", "op": "add", "value": 1.5}]},
	{"id": "sneakers", "track": "gear", "name": "Sneakers", "desc": "Bigger Perfect boost", "base_cost": 25, "cost_growth": 1.65, "max_level": 30,
	 "effects": [{"stat": "perfect_vx_boost", "op": "add", "value": 0.004}]},
	{"id": "timing", "track": "skills", "name": "Timing", "desc": "Wider Perfect and Good windows", "base_cost": 30, "cost_growth": 1.7, "max_level": 20,
	 "effects": [{"stat": "perfect_window", "op": "mul", "value": 1.05}, {"stat": "good_window", "op": "mul", "value": 1.04}]},
	{"id": "reach", "track": "skills", "name": "Reach", "desc": "Bigger tap area", "base_cost": 20, "cost_growth": 1.6, "max_level": 15,
	 "effects": [{"stat": "tap_reach_m", "op": "mul", "value": 1.06}]},
	{"id": "combo", "track": "skills", "name": "Combo", "desc": "Each combo step pays more", "base_cost": 40, "cost_growth": 1.7, "max_level": 30,
	 "effects": [{"stat": "combo_step", "op": "add", "value": 0.02}]},
	{"id": "air_kick", "track": "skills", "name": "Air Kick", "desc": "+1 mid-air kick per run", "base_cost": 200, "cost_growth": 2.2, "max_level": 5,
	 "effects": [{"stat": "air_kicks", "op": "add", "value": 1.0}]},
	{"id": "perk_odds", "track": "luck", "name": "Perk Odds", "desc": "Rare perks show up more", "base_cost": 100, "cost_growth": 1.8, "max_level": 20,
	 "effects": [{"stat": "rare_mult", "op": "mul", "value": 1.1}]},
	{"id": "coin_magnet", "track": "luck", "name": "Coin Magnet", "desc": "+8% coins (compounding)", "base_cost": 50, "cost_growth": 1.6, "max_level": 50,
	 "effects": [{"stat": "coin_mult", "op": "mul", "value": 1.08}]},
	{"id": "helpers", "track": "luck", "name": "Helpers", "desc": "More bouncy things on the street", "base_cost": 60, "cost_growth": 1.7, "max_level": 20,
	 "effects": [{"stat": "helper_freq", "op": "mul", "value": 1.06}]}
]
```

`data/cans.json`:
```json
[
	{"id": "soda", "name": "Soda Can", "desc": "Balanced. Trusty.", "cost": 0, "effects": []},
	{"id": "paint", "name": "Paint Can", "desc": "Heavy: keeps speed, bounces lower", "cost": 500,
	 "effects": [{"stat": "air_drag", "op": "mul", "value": 0.6}, {"stat": "ground_friction", "op": "mul", "value": 0.7},
	             {"stat": "restitution_good", "op": "mul", "value": 0.9}, {"stat": "restitution_perfect", "op": "mul", "value": 0.92}]},
	{"id": "lucky", "name": "Lucky Can", "desc": "+50% coins, a bit less bounce", "cost": 5000,
	 "effects": [{"stat": "coin_mult", "op": "mul", "value": 1.5}, {"stat": "restitution_good", "op": "mul", "value": 0.92},
	             {"stat": "restitution_perfect", "op": "mul", "value": 0.95}]}
]
```

`data/perks.json`:
```json
[
	{"id": "bouncy_hood", "name": "Bouncy Neighborhood", "desc": "Helper bounces +40% speed", "rarity": "common", "effects": [{"stat": "helper_speed_mult", "op": "mul", "value": 1.4}]},
	{"id": "long_legs", "name": "Long Legs", "desc": "Good window +25%", "rarity": "common", "effects": [{"stat": "good_window", "op": "mul", "value": 1.25}]},
	{"id": "lucky_penny", "name": "Lucky Penny", "desc": "+25% coins this run", "rarity": "common", "effects": [{"stat": "coin_mult", "op": "mul", "value": 1.25}]},
	{"id": "second_wind", "name": "Second Wind", "desc": "A steady tailwind", "rarity": "common", "effects": [{"stat": "tailwind", "op": "add", "value": 0.8}]},
	{"id": "super_kick", "name": "Super Kick", "desc": "Every 5th Perfect is a Super Kick", "rarity": "rare", "effects": [{"stat": "super_kick_every", "op": "add", "value": 5.0}]},
	{"id": "trampolines", "name": "Puddle Trampolines", "desc": "Puddles bounce you up", "rarity": "rare", "effects": [{"stat": "puddle_trampoline", "op": "add", "value": 1.0}]},
	{"id": "spare_kick", "name": "Spare Kick", "desc": "+1 air kick this run", "rarity": "rare", "effects": [{"stat": "air_kicks", "op": "add", "value": 1.0}]},
	{"id": "golden_touch", "name": "Golden Touch", "desc": "Perfect window +50%, coins +50%", "rarity": "epic", "effects": [{"stat": "perfect_window", "op": "mul", "value": 1.5}, {"stat": "coin_mult", "op": "mul", "value": 1.5}]}
]
```

`data/modifiers.json`:
```json
[
	{"id": "nice_day", "name": "Nice Day", "desc": "Nothing weird. Enjoy it.", "weight": 4, "effects": []},
	{"id": "downhill", "name": "Downhill", "desc": "The street slopes your way", "weight": 2, "effects": [{"stat": "tailwind", "op": "add", "value": 1.0}, {"stat": "ground_friction", "op": "mul", "value": 0.7}]},
	{"id": "windy", "name": "Windy", "desc": "Tailwind all run", "weight": 2, "effects": [{"stat": "tailwind", "op": "add", "value": 1.5}]},
	{"id": "garbage_day", "name": "Garbage Day", "desc": "Trash cans everywhere", "weight": 2, "effects": [{"stat": "helper_freq", "op": "mul", "value": 1.6}]},
	{"id": "rain_slick", "name": "Rain-Slick", "desc": "Slippery and dull bounces, +20% coins", "weight": 2, "effects": [{"stat": "ground_friction", "op": "mul", "value": 0.6}, {"stat": "restitution_good", "op": "mul", "value": 0.9}, {"stat": "restitution_perfect", "op": "mul", "value": 0.93}, {"stat": "coin_mult", "op": "mul", "value": 1.2}]}
]
```

`data/zones.json`:
```json
[
	{"id": "block", "name": "Your Block", "start_m": 0, "value": 1, "helpers_per_chunk": 1.2, "hazards_per_chunk": 0.6,
	 "helpers": ["mailbox", "trash_can", "dog"], "hazards": ["puddle", "grass"],
	 "palette": {"sky_top": "8fd3f4", "sky_bottom": "fbe3c4", "hills": "a8d5a2", "sidewalk": "d9d4cc", "road": "5d5f71", "lane": "e9e6ee",
	             "houses": ["f7b267", "9ad1d4", "f4d35e", "f6bd60"], "roofs": ["e5676a", "4a6fa5", "ee964b", "84a59d"]}},
	{"id": "downtown", "name": "Downtown", "start_m": 400, "value": 10, "helpers_per_chunk": 1.4, "hazards_per_chunk": 0.8,
	 "helpers": ["car", "trash_can", "pigeon"], "hazards": ["storm_drain", "puddle"],
	 "palette": {"sky_top": "a0c4e8", "sky_bottom": "f6d6c8", "hills": "9fb7c9", "sidewalk": "cfcac4", "road": "4f5163", "lane": "f4d35e",
	             "houses": ["b8c0d8", "e0a96d", "9ab8a8", "d7b49e"], "roofs": ["5c6784", "8d5a4a", "4a6b5d", "6b4f63"]}},
	{"id": "highway", "name": "Highway Shoulder", "start_m": 1200, "value": 100, "helpers_per_chunk": 1.0, "hazards_per_chunk": 1.0,
	 "helpers": ["guardrail", "truck"], "hazards": ["gravel", "storm_drain"],
	 "palette": {"sky_top": "f7c59f", "sky_bottom": "fde8c8", "hills": "c9b37e", "sidewalk": "b9b2a6", "road": "45474f", "lane": "ffffff",
	             "houses": ["d9c7a0", "a7b59a", "c9a27e", "b8a48c"], "roofs": ["7a6a55", "5f6e52", "8a5f43", "6e604f"]}}
]
```

`data/objects.json`:
```json
{
	"mailbox":     {"kind": "helper", "height": 1.3, "bounce_vy": 8.0,  "speed_mult": 1.10, "combo": 1, "color": "4a6fa5"},
	"trash_can":   {"kind": "helper", "height": 1.1, "bounce_vy": 9.0,  "speed_mult": 1.00, "combo": 1, "color": "7d8597"},
	"dog":         {"kind": "helper", "height": 0.6, "bounce_vy": 10.0, "speed_mult": 1.15, "combo": 2, "color": "c08552"},
	"car":         {"kind": "helper", "height": 1.6, "bounce_vy": 9.0,  "speed_mult": 1.20, "combo": 1, "color": "e63946"},
	"pigeon":      {"kind": "helper", "height": 2.5, "bounce_vy": 6.0,  "speed_mult": 1.05, "combo": 1, "color": "9aa5b1"},
	"guardrail":   {"kind": "helper", "height": 1.0, "bounce_vy": 7.0,  "speed_mult": 1.10, "combo": 1, "color": "c0c0c0"},
	"truck":       {"kind": "helper", "height": 3.0, "bounce_vy": 10.0, "speed_mult": 1.30, "combo": 2, "color": "f4a261"},
	"puddle":      {"kind": "hazard", "width": 2.5, "speed_keep": 0.55, "color": "6fa8dc"},
	"grass":       {"kind": "hazard", "width": 4.0, "speed_keep": 0.60, "color": "7fb069"},
	"storm_drain": {"kind": "hazard", "width": 1.0, "speed_keep": 0.40, "color": "2b2d42"},
	"gravel":      {"kind": "hazard", "width": 5.0, "speed_keep": 0.70, "color": "a39171"}
}
```

- [ ] **Step 2: Write the failing tests**

`test/test_stat_resolver.gd`:
```gdscript
extends GutTest

func test_adds_then_muls():
	var out := StatResolver.resolve({"a": 10.0}, [
		{"stat": "a", "op": "mul", "value": 2.0},
		{"stat": "a", "op": "add", "value": 5.0},
		{"stat": "a", "op": "mul", "value": 1.5},
	])
	assert_eq(out.a, (10.0 + 5.0) * 2.0 * 1.5)

func test_order_independent():
	var e1 := {"stat": "a", "op": "add", "value": 3.0}
	var e2 := {"stat": "a", "op": "mul", "value": 2.0}
	assert_eq(StatResolver.resolve({"a": 1.0}, [e1, e2]), StatResolver.resolve({"a": 1.0}, [e2, e1]))

func test_does_not_mutate_base_and_skips_unknown():
	var base := {"a": 1.0}
	var out := StatResolver.resolve(base, [{"stat": "zzz", "op": "add", "value": 1.0}, {"stat": "a", "op": "add", "value": 1.0}])
	assert_eq(base.a, 1.0)
	assert_eq(out.a, 2.0)
	assert_false(out.has("zzz"))
```

`test/test_content_data.gd`:
```gdscript
extends GutTest

var d: GameData

func before_each():
	d = GameData.load_all()

func _all_effects() -> Array:
	var out: Array = []
	for list in [d.upgrades, d.cans, d.perks, d.modifiers]:
		for item in list:
			out.append_array(item.effects)
	return out

func test_lists_loaded():
	assert_eq(d.upgrades.size(), 9)
	assert_eq(d.cans.size(), 3)
	assert_eq(d.perks.size(), 8)
	assert_eq(d.modifiers.size(), 5)
	assert_eq(d.zones.size(), 3)
	assert_eq(d.objects.size(), 11)

func test_every_effect_targets_a_real_stat():
	for e in _all_effects():
		assert_true(GameData.REQUIRED_STATS.has(e.stat), e.stat)
		assert_true(e.op in ["add", "mul"], e.op)

func test_ids_unique():
	for list in [d.upgrades, d.cans, d.perks, d.modifiers, d.zones]:
		var ids := list.map(func(x): return x.id)
		for id in ids:
			assert_eq(ids.count(id), 1, id)

func test_upgrades_well_formed():
	for u in d.upgrades:
		assert_true(u.track in ["gear", "skills", "luck"], u.id)
		assert_gt(float(u.base_cost), 0.0)
		assert_gt(float(u.cost_growth), 1.0)
		assert_gt(int(u.max_level), 0)

func test_zones_sorted_and_reference_real_objects():
	assert_eq(float(d.zones[0].start_m), 0.0)
	var keys := RunView.default_palette().keys()
	for i in d.zones.size():
		var z: Dictionary = d.zones[i]
		if i > 0:
			assert_gt(float(z.start_m), float(d.zones[i - 1].start_m))
		for k in keys:
			assert_true(z.palette.has(k), z.id + " palette " + k)
		for h in z.helpers:
			assert_eq(d.objects[h].kind, "helper", h)
		for h in z.hazards:
			assert_eq(d.objects[h].kind, "hazard", h)

func test_friction_always_beats_tailwind():
	var all_perks: Array = []
	for p in d.perks:
		all_perks.append_array(p.effects)
	for m in d.modifiers:
		for c in d.cans:
			var s := StatResolver.resolve(d.tuning, m.effects + c.effects + all_perks)
			assert_gt(s.ground_friction, s.tailwind, "%s + %s" % [m.id, c.id])

func test_lookups():
	assert_eq(d.upgrade("reach").name, "Reach")
	assert_eq(d.can("soda").cost, 0.0)
	assert_eq(d.upgrade("nope"), {})
```

- [ ] **Step 3: Run them to confirm they fail**

Run: `./run_tests.sh -gtest=res://test/test_content_data.gd`
Expected: they fail because the fields and `StatResolver` don't exist yet.

- [ ] **Step 4: Implement StatResolver**

`scripts/core/stat_resolver.gd`:
```gdscript
class_name StatResolver
extends RefCounted
## The one place modifiers stack: (base + Σadd) × Πmul per stat.


static func resolve(base: Dictionary, effects: Array) -> Dictionary:
	var out := base.duplicate()
	var adds := {}
	var muls := {}
	for e in effects:
		var s: String = e.stat
		if not out.has(s):
			push_warning("StatResolver: unknown stat %s" % s)
			continue
		if e.op == "add":
			adds[s] = adds.get(s, 0.0) + float(e.value)
		elif e.op == "mul":
			muls[s] = muls.get(s, 1.0) * float(e.value)
	for s in adds:
		out[s] = float(out[s]) + adds[s]
	for s in muls:
		out[s] = float(out[s]) * muls[s]
	return out
```

- [ ] **Step 5: Extend GameData**

In `scripts/core/game_data.gd`, add these fields after `var tuning`:
```gdscript
var upgrades: Array = []
var cans: Array = []
var perks: Array = []
var modifiers: Array = []
var zones: Array = []
var objects: Dictionary = {}
```
In `load_all`, before `return d`, add:
```gdscript
	d.upgrades = _array(dir + "/upgrades.json")
	d.cans = _array(dir + "/cans.json")
	d.perks = _array(dir + "/perks.json")
	d.modifiers = _array(dir + "/modifiers.json")
	d.zones = _array(dir + "/zones.json")
	var o = read_json(dir + "/objects.json")
	d.objects = o if o is Dictionary else {}
```
Add these functions:
```gdscript
static func _array(path: String) -> Array:
	var a = read_json(path)
	return a if a is Array else []


func upgrade(id: String) -> Dictionary:
	return _find(upgrades, id)


func can(id: String) -> Dictionary:
	return _find(cans, id)


func _find(list: Array, id: String) -> Dictionary:
	for x in list:
		if x.id == id:
			return x
	return {}
```
*(Godot's JSON parses every number as float, which is why the tests compare `cost` with `0.0`.)*

- [ ] **Step 6: Run the tests to confirm they pass**

Run: `./run_tests.sh`
Expected: all pass.

- [ ] **Step 7: Commit**

```bash
git add data scripts/core/stat_resolver.gd scripts/core/game_data.gd test/test_stat_resolver.gd test/test_content_data.gd
git commit -m "Add v1 content data and StatResolver"
```

---

### Task 13: SaveStore

**Files:**
- Create: `scripts/core/save_store.gd`, `test/test_save_store.gd`

**Interfaces:**
- Produces:
  - `SaveStore.VERSION := 1`, `SaveStore.DEFAULT_PATH := "user://save.json"`, `SaveStore.CODE_PREFIX := "PCAN1:"`
  - `SaveStore.defaults() -> Dictionary`, with keys:
    - `version: int`, `coins: float`, `levels: Dictionary{id: int}`
    - `owned_cans: Array[String]` (always contains `"soda"`), `equipped_can: String`
    - `best_distance: float`, `runs: int`, `lifetime_coins: float`
  - `SaveStore.normalize(raw: Variant) -> Dictionary` returns a clean save, or `{}` if `raw` isn't a recognizable save. Missing fields are filled from defaults; this is the migration path.
  - `SaveStore.load_from(path: String = DEFAULT_PATH) -> Dictionary` returns defaults when the file is missing. A corrupt file is renamed to `<path>.corrupt` and defaults are returned.
  - `SaveStore.save_to(data: Dictionary, path: String = DEFAULT_PATH) -> bool`
  - `SaveStore.export_code(data: Dictionary) -> String`, `SaveStore.import_code(code: String) -> Dictionary` (`{}` if invalid)

- [ ] **Step 1: Write the failing tests**

`test/test_save_store.gd`:
```gdscript
extends GutTest

const PATH := "user://test_save.json"

func after_each():
	for p in [PATH, PATH + ".corrupt"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

func test_missing_file_gives_defaults():
	assert_eq(SaveStore.load_from(PATH), SaveStore.defaults())

func test_round_trip():
	var d := SaveStore.defaults()
	d.coins = 1234.0
	d.levels = {"reach": 3}
	d.owned_cans = ["soda", "paint"]
	d.equipped_can = "paint"
	assert_true(SaveStore.save_to(d, PATH))
	var back := SaveStore.load_from(PATH)
	assert_eq(back.coins, 1234.0)
	assert_eq(back.levels.reach, 3)
	assert_eq(back.equipped_can, "paint")

func test_large_coins_round_trip():
	var d := SaveStore.defaults()
	d.coins = 1.5e40
	SaveStore.save_to(d, PATH)
	assert_almost_eq(SaveStore.load_from(PATH).coins / 1e40, 1.5, 1e-9)

func test_corrupt_file_is_set_aside_and_defaults_load():
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	f.store_string("{broken")
	f.close()
	assert_eq(SaveStore.load_from(PATH), SaveStore.defaults())
	assert_true(FileAccess.file_exists(PATH + ".corrupt"))

func test_normalize_fills_missing_and_repairs_bad_fields():
	var n := SaveStore.normalize({"version": 1, "coins": -5, "equipped_can": "lucky", "owned_cans": ["paint"]})
	assert_eq(n.coins, 0.0)
	assert_true(n.owned_cans.has("soda"))
	assert_eq(n.equipped_can, "soda")
	assert_eq(n.levels, {})

func test_normalize_rejects_future_versions_and_junk():
	assert_eq(SaveStore.normalize({"version": 99, "coins": 1}), {})
	assert_eq(SaveStore.normalize("hello"), {})
	assert_eq(SaveStore.normalize({"foo": 1}), {})

func test_export_import_round_trip():
	var d := SaveStore.defaults()
	d.coins = 77.0
	var code := SaveStore.export_code(d)
	assert_true(code.begins_with(SaveStore.CODE_PREFIX))
	assert_eq(SaveStore.import_code("  " + code + "\n").coins, 77.0)

func test_import_rejects_bad_codes():
	assert_eq(SaveStore.import_code(""), {})
	assert_eq(SaveStore.import_code("hello"), {})
	assert_eq(SaveStore.import_code(SaveStore.CODE_PREFIX + "!!!notbase64"), {})
	assert_eq(SaveStore.import_code(SaveStore.CODE_PREFIX + Marshalls.utf8_to_base64("[1,2]")), {})
```

- [ ] **Step 2: Run them to confirm they fail**

Run: `./run_tests.sh -gtest=res://test/test_save_store.gd`
Expected: `SaveStore` is not defined.

- [ ] **Step 3: Implement**

`scripts/core/save_store.gd`:
```gdscript
class_name SaveStore
extends RefCounted
## Versioned JSON save in user:// plus a copyable export code.

const VERSION := 1
const DEFAULT_PATH := "user://save.json"
const CODE_PREFIX := "PCAN1:"


static func defaults() -> Dictionary:
	return {
		"version": VERSION, "coins": 0.0, "levels": {}, "owned_cans": ["soda"],
		"equipped_can": "soda", "best_distance": 0.0, "runs": 0, "lifetime_coins": 0.0,
	}


static func normalize(raw: Variant) -> Dictionary:
	if not (raw is Dictionary) or not raw.has("version") or not raw.has("coins"):
		return {}
	if int(raw.version) > VERSION:
		return {}
	var d := defaults()
	d.coins = _nonneg(raw.get("coins", 0.0))
	d.best_distance = _nonneg(raw.get("best_distance", 0.0))
	d.lifetime_coins = _nonneg(raw.get("lifetime_coins", 0.0))
	d.runs = maxi(0, int(raw.get("runs", 0)))
	var levels = raw.get("levels", {})
	if levels is Dictionary:
		for k in levels:
			d.levels[str(k)] = maxi(0, int(levels[k]))
	var owned = raw.get("owned_cans", [])
	if owned is Array:
		for c in owned:
			if not d.owned_cans.has(str(c)):
				d.owned_cans.append(str(c))
	var eq := str(raw.get("equipped_can", "soda"))
	d.equipped_can = eq if d.owned_cans.has(eq) else "soda"
	return d


static func _nonneg(v: Variant) -> float:
	var f := float(v) if (v is float or v is int) else 0.0
	return f if is_finite(f) and f > 0.0 else 0.0


static func load_from(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		return defaults()
	var d := normalize(JSON.parse_string(FileAccess.get_file_as_string(path)))
	if d.is_empty():
		push_warning("SaveStore: corrupt save set aside at %s.corrupt" % path)
		DirAccess.rename_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".corrupt"))
		return defaults()
	return d


static func save_to(data: Dictionary, path: String = DEFAULT_PATH) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data))
	f.close()
	return true


static func export_code(data: Dictionary) -> String:
	return CODE_PREFIX + Marshalls.utf8_to_base64(JSON.stringify(data))


static func import_code(code: String) -> Dictionary:
	var c := code.strip_edges()
	if not c.begins_with(CODE_PREFIX):
		return {}
	var text := Marshalls.base64_to_utf8(c.substr(CODE_PREFIX.length()))
	if text.is_empty():
		return {}
	return normalize(JSON.parse_string(text))
```

- [ ] **Step 4: Run the tests to confirm they pass**

Run: `./run_tests.sh`
Expected: all pass. `JSON.parse_string` logs a parse error for junk input, which is expected; GUT doesn't fail on it. If `run_tests.sh`'s "SCRIPT ERROR" grep trips on it, check that the message isn't a `SCRIPT ERROR` line. JSON errors print as `ERROR:`, not `SCRIPT ERROR`.

- [ ] **Step 5: Commit**

```bash
git add scripts/core/save_store.gd test/test_save_store.gd
git commit -m "Add versioned SaveStore with corrupt fallback and export codes"
```

---

### Task 14: Economy

**Files:**
- Create: `scripts/core/economy.gd`, `test/test_economy.gd`

**Interfaces:**
- Consumes: `GameData` (Task 12), the save dict (Task 13).
- Produces (all static):
  - `Economy.cost(def: Dictionary, level: int) -> float`, which is `floor(base_cost × growth^level)`
  - `Economy.is_maxed(def: Dictionary, level: int) -> bool`
  - `Economy.level_of(save: Dictionary, id: String) -> int`
  - `Economy.effects_for(def: Dictionary, level: int) -> Array`: a `mul` value becomes `value^level`, an `add` value becomes `value×level`, and level 0 gives `[]`
  - `Economy.try_buy(save: Dictionary, def: Dictionary) -> bool` (mutates `save`)
  - `Economy.try_buy_can(save: Dictionary, can_def: Dictionary) -> bool` (buys and equips)
  - `Economy.equip_can(save: Dictionary, id: String) -> bool`
  - `Economy.profile_effects(save: Dictionary, data: GameData) -> Array` (upgrades plus the equipped can)
  - `Economy.meter_value(zone_value: float, combo: int, combo_step: float) -> float`
  - `Economy.run_coins(value_meters: float, coin_per_meter: float, coin_mult: float) -> float`

- [ ] **Step 1: Write the failing tests**

`test/test_economy.gd`:
```gdscript
extends GutTest

var d: GameData
var save: Dictionary

func before_each():
	d = GameData.load_all()
	save = SaveStore.defaults()

func test_cost_grows_geometrically():
	var u := {"base_cost": 10.0, "cost_growth": 1.6}
	assert_eq(Economy.cost(u, 0), 10.0)
	assert_eq(Economy.cost(u, 1), 16.0)
	assert_eq(Economy.cost(u, 5), floorf(10.0 * pow(1.6, 5)))

func test_effects_scale_with_level():
	var u := {"effects": [{"stat": "a", "op": "mul", "value": 1.1}, {"stat": "b", "op": "add", "value": 2.0}]}
	assert_eq(Economy.effects_for(u, 0), [])
	var e := Economy.effects_for(u, 3)
	assert_almost_eq(e[0].value, pow(1.1, 3), 1e-9)
	assert_eq(e[1].value, 6.0)

func test_try_buy_deducts_and_levels_up():
	var reach := d.upgrade("reach")
	save.coins = 100.0
	assert_true(Economy.try_buy(save, reach))
	assert_eq(save.coins, 100.0 - Economy.cost(reach, 0))
	assert_eq(Economy.level_of(save, "reach"), 1)

func test_try_buy_fails_without_coins_or_when_maxed():
	var reach := d.upgrade("reach")
	save.coins = 1.0
	assert_false(Economy.try_buy(save, reach))
	assert_eq(save.coins, 1.0)
	save.coins = 1e30
	save.levels["reach"] = int(reach.max_level)
	assert_false(Economy.try_buy(save, reach))

func test_buy_and_equip_cans():
	var paint := d.can("paint")
	save.coins = 499.0
	assert_false(Economy.try_buy_can(save, paint))
	save.coins = 500.0
	assert_true(Economy.try_buy_can(save, paint))
	assert_eq(save.equipped_can, "paint")
	assert_false(Economy.try_buy_can(save, paint))
	assert_true(Economy.equip_can(save, "soda"))
	assert_false(Economy.equip_can(save, "lucky"))

func test_profile_effects_include_upgrades_and_can():
	save.levels = {"kick_power": 2}
	save.owned_cans = ["soda", "lucky"]
	save.equipped_can = "lucky"
	var stats := StatResolver.resolve(d.tuning, Economy.profile_effects(save, d))
	assert_eq(stats.launch_speed_max, d.tuning.launch_speed_max + 2.0)
	assert_almost_eq(stats.coin_mult, 1.5, 1e-9)

func test_coin_formula():
	assert_eq(Economy.meter_value(10.0, 0, 0.1), 10.0)
	assert_almost_eq(Economy.meter_value(10.0, 5, 0.1), 15.0, 1e-9)
	assert_eq(Economy.run_coins(1234.0, 0.1, 2.0), 246.0)
```

- [ ] **Step 2: Run them to confirm they fail**

Run: `./run_tests.sh -gtest=res://test/test_economy.gd`
Expected: `Economy` is not defined.

- [ ] **Step 3: Implement**

`scripts/core/economy.gd`:
```gdscript
class_name Economy
extends RefCounted
## Shop prices, upgrade effects and the coin formula.


static func cost(def: Dictionary, level: int) -> float:
	return floorf(float(def.base_cost) * pow(float(def.cost_growth), level))


static func is_maxed(def: Dictionary, level: int) -> bool:
	return level >= int(def.max_level)


static func level_of(save: Dictionary, id: String) -> int:
	return int(save.levels.get(id, 0))


static func effects_for(def: Dictionary, level: int) -> Array:
	var out: Array = []
	if level <= 0:
		return out
	for e in def.effects:
		var v := float(e.value)
		out.append({"stat": e.stat, "op": e.op, "value": pow(v, level) if e.op == "mul" else v * level})
	return out


static func try_buy(save: Dictionary, def: Dictionary) -> bool:
	var lvl := level_of(save, def.id)
	if is_maxed(def, lvl):
		return false
	var price := cost(def, lvl)
	if save.coins < price:
		return false
	save.coins -= price
	save.levels[def.id] = lvl + 1
	return true


static func try_buy_can(save: Dictionary, can_def: Dictionary) -> bool:
	if save.owned_cans.has(can_def.id):
		return false
	var price := float(can_def.cost)
	if save.coins < price:
		return false
	save.coins -= price
	save.owned_cans.append(can_def.id)
	save.equipped_can = can_def.id
	return true


static func equip_can(save: Dictionary, id: String) -> bool:
	if not save.owned_cans.has(id):
		return false
	save.equipped_can = id
	return true


static func profile_effects(save: Dictionary, data: GameData) -> Array:
	var out: Array = []
	for def in data.upgrades:
		out.append_array(effects_for(def, level_of(save, def.id)))
	var c := data.can(save.equipped_can)
	if not c.is_empty():
		out.append_array(c.effects)
	return out


static func meter_value(zone_value: float, combo: int, combo_step: float) -> float:
	return zone_value * (1.0 + combo * combo_step)


static func run_coins(value_meters: float, coin_per_meter: float, coin_mult: float) -> float:
	return floorf(value_meters * coin_per_meter * coin_mult)
```

- [ ] **Step 4: Run the tests to confirm they pass**

Run: `./run_tests.sh`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/core/economy.gd test/test_economy.gd
git commit -m "Add Economy: geometric costs, compounding effects, coin formula"
```

---

### Task 15: RunState

**Files:**
- Create: `scripts/core/run_state.gd`, `test/test_run_state.gd`

**Interfaces:**
- Consumes: `Economy.meter_value`, `Economy.run_coins`, `TapJudge.Grade`, the zones list.
- Produces `RunState`:
  - `RunState.new(stats: Dictionary, zones: Array)`
  - fields: `distance`, `combo`, `best_combo`, `value_meters`, `zone_index`, `next_perk_at`, `perk_count`
  - `RunState.PERK_FIRST_M := 250.0`, `RunState.PERK_GROWTH := 1.6`
  - `static zone_index_at(zones: Array, x: float) -> int`
  - `on_distance(x: float) -> Array` of `{"type":"zone","index"}` / `{"type":"perk_due"}`
  - `on_grade(grade: int)`, `on_helper(combo: int)`, `coins() -> float`

- [ ] **Step 1: Write the failing tests**

`test/test_run_state.gd`:
```gdscript
extends GutTest

var d: GameData
var stats: Dictionary

func before_each():
	d = GameData.load_all()
	stats = d.tuning.duplicate()

func test_zone_lookup():
	assert_eq(RunState.zone_index_at(d.zones, 0.0), 0)
	assert_eq(RunState.zone_index_at(d.zones, 399.9), 0)
	assert_eq(RunState.zone_index_at(d.zones, 400.0), 1)
	assert_eq(RunState.zone_index_at(d.zones, 5000.0), 2)

func test_combo_rules():
	var r := RunState.new(stats, d.zones)
	r.on_grade(TapJudge.Grade.PERFECT)
	r.on_grade(TapJudge.Grade.PERFECT)
	r.on_grade(TapJudge.Grade.GOOD)
	assert_eq(r.combo, 2)
	r.on_helper(2)
	assert_eq(r.combo, 4)
	r.on_grade(TapJudge.Grade.MISS)
	assert_eq(r.combo, 0)
	assert_eq(r.best_combo, 4)

func test_distance_accumulates_value_with_combo_and_zone():
	var r := RunState.new(stats, d.zones)
	r.on_distance(100.0)
	assert_almost_eq(r.value_meters, 100.0, 1e-6)
	r.combo = 5
	r.on_distance(200.0)
	assert_almost_eq(r.value_meters, 100.0 + 100.0 * (1.0 + 5 * stats.combo_step), 1e-6)
	assert_eq(r.on_distance(150.0), [])

func test_zone_event_and_ten_x_value():
	var r := RunState.new(stats, d.zones)
	var ev := r.on_distance(401.0)
	assert_true(ev.any(func(e): return e.type == "zone" and e.index == 1))
	var before := r.value_meters
	r.on_distance(411.0)
	assert_almost_eq(r.value_meters - before, 10.0 * 10.0, 1e-6)

func test_perk_checkpoints_space_out():
	var r := RunState.new(stats, d.zones)
	assert_eq(r.on_distance(249.0).filter(func(e): return e.type == "perk_due").size(), 0)
	assert_eq(r.on_distance(251.0).filter(func(e): return e.type == "perk_due").size(), 1)
	assert_almost_eq(r.next_perk_at, 250.0 + 250.0 * 1.6, 1e-6)

func test_coins_use_formula():
	var r := RunState.new(stats, d.zones)
	r.on_distance(300.0)
	assert_eq(r.coins(), Economy.run_coins(r.value_meters, stats.coin_per_meter, stats.coin_mult))
```

- [ ] **Step 2: Run them to confirm they fail**

Run: `./run_tests.sh -gtest=res://test/test_run_state.gd`
Expected: `RunState` is not defined.

- [ ] **Step 3: Implement**

`scripts/core/run_state.gd`:
```gdscript
class_name RunState
extends RefCounted
## Per-run bookkeeping: distance, combo, coin value, zone and perk checkpoints.

const PERK_FIRST_M := 250.0
const PERK_GROWTH := 1.6

var stats: Dictionary
var zones: Array
var distance := 0.0
var combo := 0
var best_combo := 0
var value_meters := 0.0
var zone_index := 0
var next_perk_at := PERK_FIRST_M
var perk_count := 0


func _init(p_stats: Dictionary, p_zones: Array) -> void:
	stats = p_stats
	zones = p_zones


static func zone_index_at(p_zones: Array, x: float) -> int:
	var idx := 0
	for i in p_zones.size():
		if x >= float(p_zones[i].start_m):
			idx = i
	return idx


func zone_value() -> float:
	return float(zones[zone_index].value) if not zones.is_empty() else 1.0


func on_distance(x: float) -> Array:
	var events: Array = []
	if x <= distance:
		return events
	value_meters += (x - distance) * Economy.meter_value(zone_value(), combo, stats.combo_step)
	distance = x
	var zi := zone_index_at(zones, x)
	if zi != zone_index:
		zone_index = zi
		events.append({"type": "zone", "index": zi})
	while distance >= next_perk_at:
		perk_count += 1
		next_perk_at += PERK_FIRST_M * pow(PERK_GROWTH, perk_count)
		events.append({"type": "perk_due"})
	return events


func on_grade(grade: int) -> void:
	if grade == TapJudge.Grade.PERFECT:
		combo += 1
	elif grade == TapJudge.Grade.MISS:
		combo = 0
	best_combo = maxi(best_combo, combo)


func on_helper(add: int) -> void:
	combo += add
	best_combo = maxi(best_combo, combo)


func coins() -> float:
	return Economy.run_coins(value_meters, stats.coin_per_meter, stats.coin_mult)
```

- [ ] **Step 4: Run the tests to confirm they pass**

Run: `./run_tests.sh`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/core/run_state.gd test/test_run_state.gd
git commit -m "Add RunState for combo, coin value, zones and perk checkpoints"
```

---

### Task 16: PerkDeck and ModifierDeck

**Files:**
- Create: `scripts/core/perk_deck.gd`, `scripts/core/modifier_deck.gd`, `test/test_decks.gd`

**Interfaces:**
- Produces:
  - `PerkDeck.RARITY_WEIGHT := {"common": 10.0, "rare": 3.0, "epic": 1.0}`
  - `PerkDeck.weight(perk: Dictionary, rare_mult: float) -> float` (`rare_mult` scales only rare and epic)
  - `PerkDeck.draw(perks: Array, rng: RandomNumberGenerator, count: int, exclude: Array, rare_mult: float) -> Array` (weighted, without replacement)
  - `ModifierDeck.draw(mods: Array, rng: RandomNumberGenerator) -> Dictionary` (weighted by `weight`; `{}` if the list is empty)

- [ ] **Step 1: Write the failing tests**

`test/test_decks.gd`:
```gdscript
extends GutTest

var d: GameData

func before_each():
	d = GameData.load_all()

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r

func test_same_seed_same_draw():
	var a := PerkDeck.draw(d.perks, _rng(7), 3, [], 1.0)
	var b := PerkDeck.draw(d.perks, _rng(7), 3, [], 1.0)
	assert_eq(a.map(func(p): return p.id), b.map(func(p): return p.id))

func test_no_duplicates_and_exclude_respected():
	for s in 50:
		var picks := PerkDeck.draw(d.perks, _rng(s), 3, ["super_kick"], 1.0)
		var ids := picks.map(func(p): return p.id)
		assert_eq(ids.size(), 3)
		assert_false(ids.has("super_kick"))
		for id in ids:
			assert_eq(ids.count(id), 1)

func test_count_larger_than_pool():
	assert_eq(PerkDeck.draw(d.perks.slice(0, 2), _rng(1), 3, [], 1.0).size(), 2)

func test_rare_mult_raises_rare_share():
	var rng := _rng(42)
	var base := 0
	var boosted := 0
	for i in 3000:
		if PerkDeck.draw(d.perks, rng, 1, [], 1.0)[0].rarity != "common":
			base += 1
		if PerkDeck.draw(d.perks, rng, 1, [], 4.0)[0].rarity != "common":
			boosted += 1
	assert_gt(boosted, base * 1.5)

func test_modifier_draw_weighted_and_deterministic():
	var counts := {}
	var rng := _rng(3)
	for i in 4000:
		var m := ModifierDeck.draw(d.modifiers, rng)
		counts[m.id] = counts.get(m.id, 0) + 1
	assert_gt(counts.nice_day, counts.windy)
	assert_eq(ModifierDeck.draw(d.modifiers, _rng(9)).id, ModifierDeck.draw(d.modifiers, _rng(9)).id)
	assert_eq(ModifierDeck.draw([], _rng(1)), {})
```

- [ ] **Step 2: Run them to confirm they fail**

Run: `./run_tests.sh -gtest=res://test/test_decks.gd`
Expected: the classes are not defined.

- [ ] **Step 3: Implement**

`scripts/core/perk_deck.gd`:
```gdscript
class_name PerkDeck
extends RefCounted
## Weighted perk offers without replacement; luck boosts rare and epic weights.

const RARITY_WEIGHT := {"common": 10.0, "rare": 3.0, "epic": 1.0}


static func weight(perk: Dictionary, rare_mult: float) -> float:
	var w: float = RARITY_WEIGHT.get(perk.rarity, 1.0)
	return w if perk.rarity == "common" else w * rare_mult


static func draw(perks: Array, rng: RandomNumberGenerator, count: int, exclude: Array, rare_mult: float) -> Array:
	var pool := perks.filter(func(p): return not exclude.has(p.id))
	var out: Array = []
	while out.size() < count and not pool.is_empty():
		var total := 0.0
		for p in pool:
			total += weight(p, rare_mult)
		var r := rng.randf() * total
		var pick: Dictionary = pool[-1]
		for p in pool:
			r -= weight(p, rare_mult)
			if r < 0.0:
				pick = p
				break
		out.append(pick)
		pool.erase(pick)
	return out
```

`scripts/core/modifier_deck.gd`:
```gdscript
class_name ModifierDeck
extends RefCounted
## Picks one street modifier per run, weighted.


static func draw(mods: Array, rng: RandomNumberGenerator) -> Dictionary:
	if mods.is_empty():
		return {}
	var total := 0.0
	for m in mods:
		total += float(m.weight)
	var r := rng.randf() * total
	for m in mods:
		r -= float(m.weight)
		if r < 0.0:
			return m
	return mods[-1]
```

- [ ] **Step 4: Run the tests to confirm they pass**

Run: `./run_tests.sh`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/core/perk_deck.gd scripts/core/modifier_deck.gd test/test_decks.gd
git commit -m "Add weighted PerkDeck and ModifierDeck"
```

---
### Task 17: StreetGen, street objects in the sim, and their drawing

**Files:**
- Create: `scripts/core/street_gen.gd`, `test/test_street_gen.gd`
- Modify:
  - `scripts/core/can_physics.gd` (add `apply_helper`, `apply_hazard`)
  - `scripts/core/run_sim.gd` (implement `_check_street`)
  - `scripts/view/run_view.gd` (implement `_draw_objects`)
  - `test/test_run_sim.gd` (add street tests)

**Interfaces:**
- Consumes: zones and objects (Task 12), `RunState.zone_index_at` (Task 15).
- Produces:
  - `StreetGen.new(street_seed: int, zones: Array, objects: Dictionary, helper_freq: float)`
    - fields: `objects: Dictionary`, `CHUNK_M := 30.0`, `SAFE_START_M := 8.0`
    - `chunk(index: int) -> Array` of `{id: String, x: float}`, sorted by x and deterministic per (seed, index)
    - `objects_between(x0: float, x1: float) -> Array` of objects with `x0 < x <= x1`
  - `CanPhysics.apply_helper(def: Dictionary, helper_speed_mult: float)`, `CanPhysics.apply_hazard(id: String, def: Dictionary)`
  - `RunSim` events `{"type":"helper","id","x","combo":int}` and `{"type":"hazard","id","x","trampoline":bool}`
  - `RunSim.MAX_HAZARD_W := 6.0`

**Collision rules:**
- A **helper** triggers once when the can crosses its x at or below `def.height`. The height comes from linear interpolation over the step.
- A **hazard** triggers once when a touchdown lands inside `[x, x + width]`, or when the rolling can is inside that span.
- A hazard scales both `vel` and `last_impact_vel` by `speed_keep`, so a rekick on a puddle is still slowed.
- With `puddle_trampoline >= 1`, a puddle bounces the can up instead.

- [ ] **Step 1: Write the failing tests**

`test/test_street_gen.gd`:
```gdscript
extends GutTest

var d: GameData

func before_each():
	d = GameData.load_all()

func test_chunks_are_deterministic_and_sorted():
	var a := StreetGen.new(5, d.zones, d.objects, 1.0)
	var b := StreetGen.new(5, d.zones, d.objects, 1.0)
	for i in 10:
		assert_eq(a.chunk(i), b.chunk(i))
		var xs := a.chunk(i).map(func(o): return o.x)
		var sorted := xs.duplicate()
		sorted.sort()
		assert_eq(xs, sorted)

func test_different_seed_differs():
	var a := StreetGen.new(1, d.zones, d.objects, 1.0)
	var b := StreetGen.new(2, d.zones, d.objects, 1.0)
	var same := true
	for i in 10:
		same = same and a.chunk(i) == b.chunk(i)
	assert_false(same)

func test_launch_area_is_clear_and_objects_match_zone():
	var g := StreetGen.new(3, d.zones, d.objects, 1.0)
	for o in g.objects_between(-1.0, StreetGen.SAFE_START_M):
		fail_test("object in launch area at %f" % o.x)
	for o in g.objects_between(400.0, 1199.0):
		var z: Dictionary = d.zones[1]
		assert_true(z.helpers.has(o.id) or z.hazards.has(o.id), o.id)

func test_helper_freq_increases_helpers():
	var lo := StreetGen.new(9, d.zones, d.objects, 1.0)
	var hi := StreetGen.new(9, d.zones, d.objects, 3.0)
	var count := func(g): return g.objects_between(0.0, 3000.0).filter(func(o): return d.objects[o.id].kind == "helper").size()
	assert_gt(count.call(hi), count.call(lo))

func test_objects_between_is_half_open():
	var g := StreetGen.new(4, d.zones, d.objects, 2.0)
	var all := g.objects_between(0.0, 300.0)
	assert_gt(all.size(), 0)
	var x: float = all[0].x
	assert_false(g.objects_between(x, x + 0.001).any(func(o): return o.x == x))
	assert_true(g.objects_between(x - 0.001, x).any(func(o): return o.x == x))
```

Append to `test/test_run_sim.gd`:
```gdscript
class FakeStreet:
	var objects := {}
	var placed: Array = []
	func objects_between(x0: float, x1: float) -> Array:
		return placed.filter(func(o): return o.x > x0 and o.x <= x1)

func _street(id: String, def: Dictionary, x: float) -> FakeStreet:
	var f := FakeStreet.new()
	f.objects[id] = def
	f.placed = [{"id": id, "x": x}]
	return f

func test_low_can_hits_helper_and_bounces():
	var s := RunSim.new(stats)
	s.street = _street("trash_can", {"kind": "helper", "height": 50.0, "bounce_vy": 9.0, "speed_mult": 1.2, "combo": 1}, 3.0)
	s.launch(20.0, 1.0)
	var ev := _until_type(s, "helper")
	assert_eq(ev[-1].id, "trash_can")
	assert_eq(ev[-1].combo, 1)
	assert_gte(s.can.vel.y, 9.0)

func test_high_can_flies_over_helper():
	var s := RunSim.new(stats)
	s.street = _street("dog", {"kind": "helper", "height": 0.01, "bounce_vy": 9.0, "speed_mult": 1.2, "combo": 1}, 6.0)
	s.launch(60.0, 1.0)
	var ev := s.advance(0.6)
	assert_false(ev.any(func(e): return e.type == "helper"))

func test_touchdown_in_puddle_slows_can():
	var s := RunSim.new(stats)
	s.launch(45.0, 1.0)
	var c := CanPhysics.new(stats)
	c.launch(45.0, 1.0)
	var land := {}
	for i in 2000:
		var e: Array = []
		c.step(1.0 / 240.0, e)
		if not e.is_empty():
			land = e[0]
			break
	s.street = _street("puddle", {"kind": "hazard", "width": 4.0, "speed_keep": 0.5}, land.x - 2.0)
	var ev := _until_type(s, "hazard")
	assert_eq(ev[-1].id, "puddle")
	assert_false(ev[-1].trampoline)
	assert_almost_eq(s.can.last_impact_vel.x, c.last_impact_vel.x * 0.5, 0.2)

func test_trampoline_puddle_bounces_up():
	stats.puddle_trampoline = 1.0
	var s := RunSim.new(stats)
	s.launch(10.0, 0.3)
	s.street = _street("puddle", {"kind": "hazard", "width": 50.0, "speed_keep": 0.5}, 0.0)
	var ev := _until_type(s, "hazard")
	assert_true(ev[-1].trampoline)
	assert_gt(s.can.vel.y, 0.0)
```

- [ ] **Step 2: Run them to confirm they fail**

Run: `./run_tests.sh`
Expected: the new tests fail because `StreetGen` isn't defined and there are no helper or hazard events.

- [ ] **Step 3: Implement StreetGen**

`scripts/core/street_gen.gd`:
```gdscript
class_name StreetGen
extends RefCounted
## Seeded, chunked street layout of helpers and hazards per zone.

const CHUNK_M := 30.0
const SAFE_START_M := 8.0

var street_seed := 0
var zones: Array
var objects: Dictionary
var helper_freq := 1.0
var _cache := {}


func _init(p_seed: int, p_zones: Array, p_objects: Dictionary, p_helper_freq: float) -> void:
	street_seed = p_seed
	zones = p_zones
	objects = p_objects
	helper_freq = p_helper_freq


func chunk(index: int) -> Array:
	if _cache.has(index):
		return _cache[index]
	var out: Array = []
	if index >= 0 and not zones.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = hash([street_seed, index])
		var start := index * CHUNK_M
		var zone: Dictionary = zones[RunState.zone_index_at(zones, start)]
		_place(out, rng, start, zone.helpers, _count(rng, float(zone.helpers_per_chunk) * helper_freq))
		_place(out, rng, start, zone.hazards, _count(rng, float(zone.hazards_per_chunk)))
		out.sort_custom(func(a, b): return a.x < b.x)
	_cache[index] = out
	return out


func _count(rng: RandomNumberGenerator, expected: float) -> int:
	var n := int(floorf(expected))
	return n + (1 if rng.randf() < expected - n else 0)


func _place(out: Array, rng: RandomNumberGenerator, start: float, ids: Array, n: int) -> void:
	for i in n:
		var x := start + rng.randf_range(2.0, CHUNK_M - 2.0)
		if x < SAFE_START_M or ids.is_empty():
			continue
		out.append({"id": ids[rng.randi_range(0, ids.size() - 1)], "x": x})


func objects_between(x0: float, x1: float) -> Array:
	var out: Array = []
	if x1 <= x0:
		return out
	for i in range(int(floorf(x0 / CHUNK_M)), int(floorf(x1 / CHUNK_M)) + 1):
		for o in chunk(i):
			if o.x > x0 and o.x <= x1:
				out.append(o)
	return out
```

- [ ] **Step 4: Add the object reactions to CanPhysics**

Append to `scripts/core/can_physics.gd`:
```gdscript
const TRAMPOLINE_VY := 10.0


func apply_helper(def: Dictionary, helper_speed_mult: float) -> void:
	vel.y = maxf(vel.y, float(def.bounce_vy))
	vel.x = minf(vel.x * float(def.speed_mult) * helper_speed_mult, stats.max_speed)
	rolling = false
	at_rest = false


func apply_hazard(id: String, def: Dictionary) -> void:
	if id == "puddle" and stats.puddle_trampoline >= 1.0:
		vel.y = maxf(vel.y, TRAMPOLINE_VY)
		rolling = false
		at_rest = false
		return
	var keep := float(def.speed_keep)
	vel *= keep
	last_impact_vel *= keep
```

- [ ] **Step 5: Implement `_check_street` in RunSim**

Add `const MAX_HAZARD_W := 6.0` to `scripts/core/run_sim.gd`. Then replace the stub `_check_street` with:
```gdscript
func _check_street(prev: Vector2, chunk: Array, events: Array) -> void:
	if street == null:
		return
	var now := can.pos
	for obj in street.objects_between(prev.x, now.x):
		var def: Dictionary = street.objects[obj.id]
		if def.kind != "helper" or _used.has(obj.x):
			continue
		var t := 0.0 if is_equal_approx(now.x, prev.x) else (obj.x - prev.x) / (now.x - prev.x)
		if lerpf(prev.y, now.y, t) <= float(def.height):
			_used[obj.x] = true
			can.apply_helper(def, stats.helper_speed_mult)
			events.append({"type": "helper", "id": obj.id, "x": obj.x, "combo": int(def.get("combo", 0))})
	var probe_x := NAN
	for ev in chunk:
		if ev.type == "touchdown":
			probe_x = ev.x
	if is_nan(probe_x) and can.rolling:
		probe_x = now.x
	if is_nan(probe_x):
		return
	for obj in street.objects_between(probe_x - MAX_HAZARD_W, probe_x):
		var def: Dictionary = street.objects[obj.id]
		if def.kind != "hazard" or _used.has(obj.x) or probe_x > obj.x + float(def.width):
			continue
		_used[obj.x] = true
		var tramp: bool = obj.id == "puddle" and stats.puddle_trampoline >= 1.0
		can.apply_hazard(obj.id, def)
		events.append({"type": "hazard", "id": obj.id, "x": obj.x, "trampoline": tramp})
```
*(`_used` already exists from Task 4. Street events are appended before the chunk's touchdown event, so a hazard slows `last_impact_vel` before any rekick resolves.)*

- [ ] **Step 6: Draw street objects in RunView**

In `scripts/view/run_view.gd`, replace the `_draw_objects` stub:
```gdscript
func _draw_objects(size: Vector2) -> void:
	if sim == null or sim.street == null:
		return
	var x0 := cam_x - 6.0
	var x1 := cam_x + size.x / ppm + 2.0
	for o in sim.street.objects_between(x0, x1):
		var def: Dictionary = sim.street.objects[o.id]
		var col := Color(def.get("color", "ffffff"))
		var p := world_to_screen(Vector2(o.x, 0.0))
		if def.kind == "helper":
			var h := float(def.height) * ppm
			var w := maxf(6.0, h * 0.7)
			draw_rect(Rect2(p.x - w / 2, p.y - h, w, h), col)
			draw_rect(Rect2(p.x - w / 2, p.y - h, w, 2), col.lightened(0.3))
		else:
			draw_rect(Rect2(p.x, p.y - 1, float(def.width) * ppm, 3), col)
```

- [ ] **Step 7: Run all tests**

Run: `./run_tests.sh`
Expected: all pass. If `test_touchdown_in_puddle_slows_can` is flaky by a few cm, widen the puddle width in the test, not the code.

- [ ] **Step 8: Commit**

```bash
git add scripts test
git commit -m "Add StreetGen helpers and hazards with sim collisions and drawing"
```

---

### Task 18: Title, Perk-pick, Results and Settings screens

**Files:**
- Create: `scripts/ui/screen_base.gd`, `scripts/ui/title_screen.gd`, `scripts/ui/perk_pick_screen.gd`, `scripts/ui/results_screen.gd`, `scripts/ui/settings_screen.gd`, `test/test_screens.gd`
- Modify: `scripts/ui/ui_theme.gd` (button styles)

**Interfaces:**
- Consumes: `UiTheme`, `NumFmt`, `SaveStore`.
- Produces (all `Control` subclasses, full-rect, built in `_ready`, `process_mode = ALWAYS`):
  - `ScreenBase`: `add_title(text, size)`, `add_label(text, size) -> Label`, `add_button(text, cb: Callable) -> Button`, and a `box: VBoxContainer`
  - `TitleScreen`: signals `play`, `shop`, `settings`; `set_coins(c: float)`, `set_best(m: float)`
  - `PerkPickScreen`: signal `picked(perk: Dictionary)`; `show_perks(perks: Array)`; field `buttons: Array[Button]`
  - `ResultsScreen`: signals `again`, `shop`; `show_results(distance: float, best_combo: int, coins: float, record: bool)`; field `summary: Label`
  - `SettingsScreen`: signals `back`, `imported(save: Dictionary)`
    - `set_save(save: Dictionary)` refreshes the export code
    - fields `export_box: TextEdit`, `import_box: TextEdit`, `status: Label`
    - `try_import() -> bool` needs two presses within 3 s to confirm; a bad code leaves things untouched and shows an error

- [ ] **Step 1: Write the failing tests**

`test/test_screens.gd`:
```gdscript
extends GutTest

func _add(s: Control) -> Control:
	add_child_autofree(s)
	return s

func test_title_emits_signals_and_shows_coins():
	var t: TitleScreen = _add(TitleScreen.new())
	watch_signals(t)
	t.set_coins(12_500.0)
	assert_string_contains(t.coins_label.text, "12.5K")
	t.play_button.pressed.emit()
	assert_signal_emitted(t, "play")

func test_perk_pick_offers_and_emits_choice():
	var p: PerkPickScreen = _add(PerkPickScreen.new())
	watch_signals(p)
	var perks := GameData.load_all().perks.slice(0, 3)
	p.show_perks(perks)
	assert_eq(p.buttons.size(), 3)
	assert_string_contains(p.buttons[1].text, perks[1].name)
	p.buttons[1].pressed.emit()
	assert_signal_emitted_with_parameters(p, "picked", [perks[1]])

func test_results_show_numbers():
	var r: ResultsScreen = _add(ResultsScreen.new())
	r.show_results(512.3, 14, 3.2e6, true)
	assert_string_contains(r.summary.text, "512.3")
	assert_string_contains(r.summary.text, "3.2M")
	assert_string_contains(r.summary.text, "NEW RECORD")

func test_settings_export_then_import_with_confirm():
	var s: SettingsScreen = _add(SettingsScreen.new())
	watch_signals(s)
	var save := SaveStore.defaults()
	save.coins = 99.0
	s.set_save(save)
	assert_true(s.export_box.text.begins_with(SaveStore.CODE_PREFIX))
	s.import_box.text = s.export_box.text
	assert_false(s.try_import())
	assert_signal_not_emitted(s, "imported")
	assert_true(s.try_import())
	assert_signal_emitted(s, "imported")

func test_bad_import_leaves_save_untouched():
	var s: SettingsScreen = _add(SettingsScreen.new())
	watch_signals(s)
	s.set_save(SaveStore.defaults())
	s.import_box.text = "PCAN1:garbage"
	assert_false(s.try_import())
	assert_false(s.try_import())
	assert_signal_not_emitted(s, "imported")
	assert_string_contains(s.status.text, "isn't a valid")
```

- [ ] **Step 2: Run them to confirm they fail**

Run: `./run_tests.sh -gtest=res://test/test_screens.gd`
Expected: the classes are not defined.

- [ ] **Step 3: Extend UiTheme with button styles**

In `scripts/ui/ui_theme.gd`, add the following to `make()` before `return t`:
```gdscript
	var normal := StyleBoxFlat.new()
	normal.bg_color = INK
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 8
	normal.content_margin_right = 8
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var pressed := normal.duplicate()
	pressed.bg_color = INK.lightened(0.2)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(INK, 0.4)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", normal)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", PAPER)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_hover_color", "Button", PAPER)
	t.set_color("font_disabled_color", "Button", Color(PAPER, 0.5))
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("fbe3c4")
	t.set_stylebox("panel", "PanelContainer", panel)
```

- [ ] **Step 4: Implement the screens**

`scripts/ui/screen_base.gd`:
```gdscript
class_name ScreenBase
extends PanelContainer
## Full-screen menu panel with a centered column of labels and buttons.

var box: VBoxContainer


func _init() -> void:
	# Guard: subclasses call super(), and the base must only build once.
	if box:
		return
	set_anchors_preset(Control.PRESET_FULL_RECT)
	process_mode = Node.PROCESS_MODE_ALWAYS
	theme = UiTheme.make()
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	add_child(margin)
	box = VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	margin.add_child(box)


func add_title(text: String, size: int = 24) -> Label:
	var l := add_label(text, size)
	l.add_theme_color_override("font_color", UiTheme.INK)
	return l


func add_label(text: String, size: int = 12) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", size)
	box.add_child(l)
	return l


func add_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 40)
	b.pressed.connect(cb)
	box.add_child(b)
	return b
```
*(The UI is built in `_init`, so tests can use the fields straight after `new()`. Adding to the tree is still fine.)*

`scripts/ui/title_screen.gd`:
```gdscript
class_name TitleScreen
extends ScreenBase

signal play
signal shop
signal settings

var coins_label: Label
var best_label: Label
var play_button: Button


func _init() -> void:
	super()
	add_title("PROCRASTICAN", 28)
	add_label("Mild Littering", 12)
	coins_label = add_label("", 14)
	best_label = add_label("", 11)
	play_button = add_button("Kick a can", func(): play.emit())
	add_button("Shop", func(): shop.emit())
	add_button("Settings", func(): settings.emit())


func set_coins(c: float) -> void:
	coins_label.text = "%s ¢" % NumFmt.format(c)


func set_best(m: float) -> void:
	best_label.text = "Best: %.1f m" % m
```

`scripts/ui/perk_pick_screen.gd`:
```gdscript
class_name PerkPickScreen
extends ScreenBase

signal picked(perk: Dictionary)

var buttons: Array[Button] = []


func _init() -> void:
	super()
	add_title("Pick a perk", 20)


func show_perks(perks: Array) -> void:
	for b in buttons:
		b.queue_free()
	buttons.clear()
	for p in perks:
		var perk: Dictionary = p
		var b := add_button("%s (%s)\n%s" % [perk.name, perk.rarity, perk.desc], func(): picked.emit(perk))
		b.custom_minimum_size = Vector2(0, 56)
		buttons.append(b)
```

`scripts/ui/results_screen.gd`:
```gdscript
class_name ResultsScreen
extends ScreenBase

signal again
signal shop

var summary: Label


func _init() -> void:
	super()
	add_title("Can came to rest", 20)
	summary = add_label("", 14)
	add_button("Kick again", func(): again.emit())
	add_button("Shop", func(): shop.emit())


func show_results(distance: float, best_combo: int, coins: float, record: bool) -> void:
	summary.text = "%s%.1f m\nBest combo x%d\n+%s ¢" % [
		"NEW RECORD!\n" if record else "", distance, best_combo, NumFmt.format(coins)]
```

`scripts/ui/settings_screen.gd`:
```gdscript
class_name SettingsScreen
extends ScreenBase

signal back
signal imported(save: Dictionary)

const CONFIRM_SECONDS := 3.0

var export_box: TextEdit
var import_box: TextEdit
var status: Label
var _confirm_until_ms := 0


func _init() -> void:
	super()
	add_title("Settings", 20)
	add_label("Your save code (copy it somewhere safe):", 11)
	export_box = _text_box(false)
	add_button("Copy code", _copy)
	add_label("Paste a code to restore:", 11)
	import_box = _text_box(true)
	add_button("Import", try_import)
	status = add_label("", 11)
	add_button("Back", func(): back.emit())


func _text_box(editable: bool) -> TextEdit:
	var t := TextEdit.new()
	t.custom_minimum_size = Vector2(0, 60)
	t.editable = editable
	t.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	box.add_child(t)
	return t


func _copy() -> void:
	DisplayServer.clipboard_set(export_box.text)
	status.text = "Copied."


func set_save(save: Dictionary) -> void:
	export_box.text = SaveStore.export_code(save)
	status.text = ""


## The first press arms, a second press within 3 s replaces the save.
func try_import() -> bool:
	var data := SaveStore.import_code(import_box.text)
	if data.is_empty():
		_confirm_until_ms = 0
		status.text = "That isn't a valid save code."
		return false
	var now := Time.get_ticks_msec()
	if now > _confirm_until_ms:
		_confirm_until_ms = now + int(CONFIRM_SECONDS * 1000)
		status.text = "Tap Import again to replace your save."
		return false
	_confirm_until_ms = 0
	status.text = "Save imported."
	imported.emit(data)
	return true
```

- [ ] **Step 5: Run the tests to confirm they pass**

Run: `./run_tests.sh`
Expected: all pass.

- [ ] **Step 6: Commit**

```bash
git add scripts/ui test/test_screens.gd
git commit -m "Add title, perk pick, results and settings screens"
```

---

### Task 19: Shop screen

**Files:**
- Create: `scripts/ui/shop_screen.gd`, `test/test_shop_screen.gd`

**Interfaces:**
- Consumes: `Economy`, `GameData`, `NumFmt`, `ScreenBase`, the save dict.
- Produces `ShopScreen`:
  - signals `back`, `changed` (emitted after any purchase or equip, so Main can save)
  - `open(save: Dictionary, data: GameData)`, `show_track(track: String)` (`"gear"|"skills"|"luck"`)
  - fields `coins_label: Label`, `rows: Dictionary` (id → Button)
  - The Gear tab also lists the cans with Buy or Equip buttons.

- [ ] **Step 1: Write the failing test**

`test/test_shop_screen.gd`:
```gdscript
extends GutTest

var d: GameData
var save: Dictionary
var shop: ShopScreen

func before_each():
	d = GameData.load_all()
	save = SaveStore.defaults()
	shop = ShopScreen.new()
	add_child_autofree(shop)

func test_lists_track_upgrades_with_prices():
	save.coins = 0.0
	shop.open(save, d)
	shop.show_track("skills")
	assert_true(shop.rows.has("timing"))
	assert_false(shop.rows.has("kick_power"))
	assert_true(shop.rows.timing.disabled)
	assert_string_contains(shop.rows.timing.text, NumFmt.format(Economy.cost(d.upgrade("timing"), 0)))

func test_buying_updates_save_and_emits_changed():
	save.coins = 1000.0
	shop.open(save, d)
	shop.show_track("gear")
	watch_signals(shop)
	shop.rows.kick_power.pressed.emit()
	assert_eq(Economy.level_of(save, "kick_power"), 1)
	assert_signal_emitted(shop, "changed")
	assert_string_contains(shop.coins_label.text, NumFmt.format(save.coins))

func test_gear_tab_lists_cans_and_equips():
	save.coins = 600.0
	shop.open(save, d)
	shop.show_track("gear")
	assert_true(shop.rows.has("can_paint"))
	shop.rows.can_paint.pressed.emit()
	assert_eq(save.equipped_can, "paint")
	shop.rows.can_soda.pressed.emit()
	assert_eq(save.equipped_can, "soda")

func test_maxed_upgrade_is_disabled():
	save.coins = 1e30
	save.levels["air_kick"] = 5
	shop.open(save, d)
	shop.show_track("skills")
	assert_true(shop.rows.air_kick.disabled)
	assert_string_contains(shop.rows.air_kick.text, "MAX")
```

- [ ] **Step 2: Run it to confirm it fails**

Run: `./run_tests.sh -gtest=res://test/test_shop_screen.gd`
Expected: `ShopScreen` is not defined.

- [ ] **Step 3: Implement**

`scripts/ui/shop_screen.gd`:
```gdscript
class_name ShopScreen
extends ScreenBase
## Upgrade shop with Gear / Skills / Luck tabs; Gear also sells and equips cans.

signal back
signal changed

const TRACKS: Array[String] = ["gear", "skills", "luck"]

var save: Dictionary
var data: GameData
var coins_label: Label
var rows := {}
var _list: VBoxContainer
var _track := "gear"


func _init() -> void:
	super()
	box.alignment = BoxContainer.ALIGNMENT_BEGIN
	add_title("Shop", 20)
	coins_label = add_label("", 14)
	var tabs := HBoxContainer.new()
	box.add_child(tabs)
	for t in TRACKS:
		var track: String = t
		var b := Button.new()
		b.text = track.capitalize()
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func(): show_track(track))
		tabs.add_child(b)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)
	add_button("Back", func(): back.emit())


func open(p_save: Dictionary, p_data: GameData) -> void:
	save = p_save
	data = p_data
	show_track(_track)


func show_track(track: String) -> void:
	_track = track
	for c in _list.get_children():
		c.queue_free()
	rows.clear()
	coins_label.text = "%s ¢" % NumFmt.format(save.coins)
	for def in data.upgrades:
		if def.track == track:
			_upgrade_row(def)
	if track == "gear":
		for c in data.cans:
			_can_row(c)


func _upgrade_row(def: Dictionary) -> void:
	var lvl := Economy.level_of(save, def.id)
	var maxed := Economy.is_maxed(def, lvl)
	var price := Economy.cost(def, lvl)
	var b := _row_button("%s  Lv %d\n%s  %s" % [def.name, lvl, def.desc, "MAX" if maxed else NumFmt.format(price) + " ¢"])
	b.disabled = maxed or save.coins < price
	b.pressed.connect(_on_buy.bind(def))
	rows[def.id] = b


func _can_row(c: Dictionary) -> void:
	var owned: bool = save.owned_cans.has(c.id)
	var equipped: bool = save.equipped_can == c.id
	var action := "Equipped" if equipped else ("Equip" if owned else NumFmt.format(float(c.cost)) + " ¢")
	var b := _row_button("%s\n%s  %s" % [c.name, c.desc, action])
	b.disabled = equipped or (not owned and save.coins < float(c.cost))
	b.pressed.connect(_on_can.bind(c))
	rows["can_" + c.id] = b


func _on_buy(def: Dictionary) -> void:
	if Economy.try_buy(save, def):
		changed.emit()
		show_track(_track)


func _on_can(c: Dictionary) -> void:
	var ok := Economy.equip_can(save, c.id) if save.owned_cans.has(c.id) else Economy.try_buy_can(save, c)
	if ok:
		changed.emit()
		show_track(_track)


func _row_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.custom_minimum_size = Vector2(0, 48)
	b.add_theme_font_size_override("font_size", 11)
	_list.add_child(b)
	return b
```
*(In `test_gear_tab_lists_cans_and_equips` the soda row is "Equip" once paint is equipped, because rows are rebuilt after every change. The test re-reads `shop.rows`, which is a fresh dict.)*

- [ ] **Step 4: Run the tests to confirm they pass**

Run: `./run_tests.sh`
Expected: all pass.

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/shop_screen.gd test/test_shop_screen.gd
git commit -m "Add shop screen with upgrade tracks and cans"
```

---
### Task 20: Full game flow in Main (state machine, perks mid-run, saving, pause, toast)

**Files:**
- Modify: `scripts/main.gd` (full rewrite)
- Create: `test/test_main_flow.gd`

**Interfaces:**
- Consumes: everything above.
- Produces (for tests):
  - Main fields: `save_path: String` (set before `add_child`), `screen: int` (`Main.Screen`), `save: Dictionary`, `stats: Dictionary`, `run_state: RunState`, `modifier: Dictionary`, `run_perks: Array`
  - children: `run_view`, `hud`, `juice`, `title`, `perk_pick`, `results`, `shop`, `settings`, `toast_label`, `pause_label`
  - methods: `start_run()`, `show_title()`, `open_shop()`, `open_settings()`, `background_pause()`, `resume()`, `toast(text: String)`, `_persist()`, `_on_progressed(x: float)`
- `stats` is **one dictionary updated in place**. `RunSim` and `RunState` hold references to it, so a perk picked mid-run applies immediately.
- The tuning overlay now edits `data.tuning`, the base values, so its changes apply from the next run.

- [ ] **Step 1: Write the failing tests**

`test/test_main_flow.gd`:
```gdscript
extends GutTest

const SAVE := "user://test_main_save.json"
var main

func before_each():
	main = load("res://scenes/main.tscn").instantiate()
	main.save_path = SAVE
	add_child_autofree(main)

func after_each():
	get_tree().paused = false
	Engine.time_scale = 1.0
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))

func _launch_and_finish():
	main.run_view.begin_drag(Vector2(100, 300))
	main.run_view.update_drag(Vector2(40, 360))
	main.run_view.end_drag()
	for i in 20000:
		main.run_view.tick(1.0 / 60.0)
		if main.run_view.state == "done":
			return

func test_starts_on_title():
	assert_eq(main.screen, Main.Screen.TITLE)
	assert_true(main.title.visible)
	assert_false(main.hud.visible)

func test_start_run_rolls_modifier_and_aims():
	main.start_run()
	assert_eq(main.screen, Main.Screen.RUN)
	assert_eq(main.run_view.state, "aiming")
	assert_false(main.modifier.is_empty())
	assert_string_contains(main.hud.info_label.text, main.modifier.name)

func test_run_end_pays_out_saves_and_shows_results():
	main.start_run()
	_launch_and_finish()
	assert_eq(main.screen, Main.Screen.RESULTS)
	assert_gt(main.save.coins, 0.0)
	assert_eq(main.save.runs, 1)
	assert_true(FileAccess.file_exists(SAVE))

func test_perk_checkpoint_pauses_and_pick_applies():
	main.start_run()
	main._on_progressed(RunState.PERK_FIRST_M + 1.0)
	assert_eq(main.screen, Main.Screen.PERK)
	assert_true(get_tree().paused)
	main.perk_pick.buttons[0].pressed.emit()
	assert_eq(main.screen, Main.Screen.RUN)
	assert_eq(main.run_perks.size(), 1)
	assert_false(get_tree().paused)

func test_spare_kick_perk_adds_air_kick_mid_run():
	main.start_run()
	var before: int = main.run_view.sim.air_kicks_left
	main.perk_pick.picked.emit(GameData.load_all().perks.filter(func(p): return p.id == "spare_kick")[0])
	assert_eq(main.run_view.sim.air_kicks_left, before + 1)

func test_background_pause_restores_time_scale():
	main.start_run()
	main.juice.hitstop(5.0)
	main.background_pause()
	assert_eq(Engine.time_scale, 1.0)
	assert_true(get_tree().paused)
	assert_true(main.pause_label.visible)
	main.resume()
	assert_false(get_tree().paused)

func test_failed_save_shows_toast():
	main.save_path = "user://missing_dir/deeper/save.json"
	main._persist()
	assert_string_contains(main.toast_label.text, "Couldn't save")

func test_import_replaces_save_and_returns_to_title():
	var d := SaveStore.defaults()
	d.coins = 4242.0
	main.open_settings()
	main.settings.imported.emit(d)
	assert_eq(main.save.coins, 4242.0)
	assert_eq(main.screen, Main.Screen.TITLE)
```

- [ ] **Step 2: Run them to confirm they fail**

Run: `./run_tests.sh -gtest=res://test/test_main_flow.gd`
Expected: they fail because the M0 main has no `screen` or `start_run`.

- [ ] **Step 3: Rewrite `scripts/main.gd`**

```gdscript
class_name Main
extends Node2D
## Game flow: Title → Run (⇄ Perk pick) → Results → Shop / Settings, with saving and pause.

enum Screen { TITLE, RUN, PERK, RESULTS, SHOP, SETTINGS }

var save_path := SaveStore.DEFAULT_PATH
var data: GameData
var save: Dictionary
var stats: Dictionary = {}
var run_state: RunState
var modifier: Dictionary = {}
var run_perks: Array = []
var screen := Screen.TITLE
var juice: Juice
var sfx: Sfx
var probe := LatencyProbe.new()
var run_view: RunView
var hud: Hud
var overlay: TuningOverlay
var title: TitleScreen
var perk_pick: PerkPickScreen
var results: ResultsScreen
var shop: ShopScreen
var settings: SettingsScreen
var toast_label: Label
var pause_label: Label
var _rng := RandomNumberGenerator.new()
var _perks_pending := 0
var _bg_paused := false
var _toast_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	data = GameData.load_all()
	save = SaveStore.load_from(save_path)
	juice = Juice.new()
	add_child(juice)
	sfx = Sfx.new()
	add_child(sfx)
	run_view = RunView.new()
	run_view.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(run_view)
	run_view.setup(juice, sfx, probe)
	run_view.sim_event.connect(_on_sim_event)
	run_view.progressed.connect(_on_progressed)
	run_view.run_ended.connect(_on_run_ended)
	hud = Hud.new()
	add_child(hud)
	_build_menus()
	_build_notices()
	overlay = TuningOverlay.new()
	overlay.setup(data.tuning, probe)
	add_child(overlay)
	show_title()


func _build_menus() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 4
	add_child(layer)
	title = TitleScreen.new()
	perk_pick = PerkPickScreen.new()
	results = ResultsScreen.new()
	shop = ShopScreen.new()
	settings = SettingsScreen.new()
	for s in [title, perk_pick, results, shop, settings]:
		layer.add_child(s)
	title.play.connect(start_run)
	title.shop.connect(open_shop)
	title.settings.connect(open_settings)
	perk_pick.picked.connect(_on_perk_picked)
	results.again.connect(start_run)
	results.shop.connect(open_shop)
	shop.changed.connect(_persist)
	shop.back.connect(show_title)
	settings.back.connect(show_title)
	settings.imported.connect(_on_imported)


func _build_notices() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 6
	add_child(layer)
	var theme := UiTheme.make()
	toast_label = Label.new()
	toast_label.theme = theme
	toast_label.position = Vector2(10, 540)
	toast_label.size = Vector2(250, 20)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(toast_label)
	pause_label = Label.new()
	pause_label.theme = theme
	pause_label.text = "Paused. Tap to resume."
	pause_label.add_theme_font_size_override("font_size", 18)
	pause_label.position = Vector2(10, 260)
	pause_label.size = Vector2(250, 30)
	pause_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pause_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pause_label.visible = false
	layer.add_child(pause_label)


func _show(s: Screen) -> void:
	screen = s
	title.visible = s == Screen.TITLE
	perk_pick.visible = s == Screen.PERK
	results.visible = s == Screen.RESULTS
	shop.visible = s == Screen.SHOP
	settings.visible = s == Screen.SETTINGS
	hud.visible = s == Screen.RUN or s == Screen.PERK
	get_tree().paused = s == Screen.PERK


func show_title() -> void:
	title.set_coins(save.coins)
	title.set_best(save.best_distance)
	_show(Screen.TITLE)


func open_shop() -> void:
	shop.open(save, data)
	_show(Screen.SHOP)


func open_settings() -> void:
	settings.set_save(save)
	_show(Screen.SETTINGS)


func _resolve_stats() -> void:
	var effects: Array = Economy.profile_effects(save, data) + modifier.get("effects", [])
	for p in run_perks:
		effects += p.effects
	var fresh := StatResolver.resolve(data.tuning, effects)
	for k in fresh:
		stats[k] = fresh[k]


func start_run() -> void:
	_rng.seed = Time.get_ticks_usec()
	modifier = ModifierDeck.draw(data.modifiers, _rng)
	run_perks = []
	_perks_pending = 0
	_resolve_stats()
	run_state = RunState.new(stats, data.zones)
	var street := StreetGen.new(_rng.randi(), data.zones, data.objects, stats.helper_freq)
	run_view.set_palette(data.zones[0].palette)
	run_view.start_aim(stats, street)
	hud.set_distance(0.0)
	hud.set_combo(0)
	hud.show_info("%s: %s" % [modifier.get("name", ""), modifier.get("desc", "")])
	hud.show_message("Pull back and release to kick")
	_show(Screen.RUN)


func _on_sim_event(ev: Dictionary) -> void:
	match ev.type:
		"launch":
			hud.show_message("")
		"graded":
			run_state.on_grade(ev.grade)
			hud.set_combo(run_state.combo)
		"helper":
			run_state.on_helper(ev.combo)
			hud.set_combo(run_state.combo)


func _on_progressed(x: float) -> void:
	hud.set_distance(x)
	for ev in run_state.on_distance(x):
		if ev.type == "zone":
			var z: Dictionary = data.zones[ev.index]
			run_view.set_palette(z.palette)
			juice.popup("%s  x%s" % [z.name, NumFmt.format(float(z.value))], Vector2(135, 160), UiTheme.GOLD, 16)
			sfx.play("coin")
		elif ev.type == "perk_due":
			_perks_pending += 1
	if _perks_pending > 0 and screen == Screen.RUN:
		_offer_perk()


func _offer_perk() -> void:
	var taken := run_perks.map(func(p): return p.id)
	var offers := PerkDeck.draw(data.perks, _rng, 3, taken, stats.rare_mult)
	if offers.is_empty():
		_perks_pending = 0
		return
	_perks_pending -= 1
	juice.end_hitstop()
	perk_pick.show_perks(offers)
	_show(Screen.PERK)


func _on_perk_picked(perk: Dictionary) -> void:
	var old_kicks := int(stats.air_kicks)
	run_perks.append(perk)
	_resolve_stats()
	if run_view.sim:
		run_view.sim.air_kicks_left += int(stats.air_kicks) - old_kicks
	sfx.play("ui")
	_show(Screen.RUN)
	if _perks_pending > 0:
		_offer_perk()


func _on_run_ended(_ev: Dictionary) -> void:
	var coins := run_state.coins()
	var record: bool = run_state.distance > save.best_distance
	save.coins += coins
	save.lifetime_coins += coins
	save.runs += 1
	save.best_distance = maxf(save.best_distance, run_state.distance)
	_persist()
	results.show_results(run_state.distance, run_state.best_combo, coins, record)
	sfx.play("coin")
	_show(Screen.RESULTS)


func _on_imported(d: Dictionary) -> void:
	save = d
	_persist()
	show_title()
	toast("Save imported")


func _persist() -> void:
	if not SaveStore.save_to(save, save_path):
		toast("Couldn't save progress")


func toast(text: String) -> void:
	toast_label.text = text
	toast_label.modulate.a = 1.0
	if _toast_tween:
		_toast_tween.kill()
	_toast_tween = toast_label.create_tween().set_ignore_time_scale(true)
	_toast_tween.tween_interval(2.0)
	_toast_tween.tween_property(toast_label, "modulate:a", 0.0, 0.5)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		background_pause()


func background_pause() -> void:
	if juice:
		juice.end_hitstop()
	if screen == Screen.RUN and not _bg_paused:
		_bg_paused = true
		get_tree().paused = true
		pause_label.visible = true


func resume() -> void:
	_bg_paused = false
	pause_label.visible = false
	get_tree().paused = screen == Screen.PERK


func _unhandled_input(event: InputEvent) -> void:
	if _bg_paused and event is InputEventScreenTouch and event.pressed:
		resume()
		get_viewport().set_input_as_handled()
```
*(`_show(Screen.PERK)` sets `get_tree().paused = true`. `RunView` is `PAUSABLE` and freezes, while menus, Juice, Sfx and the overlay are `ALWAYS`.)*

- [ ] **Step 4: Run all tests**

Run: `./run_tests.sh`
Expected: all pass, including the Task 1 smoke test, which still instantiates `main.tscn`.

- [ ] **Step 5: Desktop check in the browser**

Run `./build_web.sh` and use `preview_start {name: "procrastican-web"}`. Walk through and screenshot:
- Title → Kick a can → aim and launch → (tap) → Results → Shop: buy something → Back → Kick again.
- Push a run past 250 m, raising `launch_speed_max` in the F1 overlay if needed, and confirm the perk screen pauses the run.
- Check that `read_console_messages` shows no errors.

- [ ] **Step 6: Commit**

```bash
git add scripts/main.gd test/test_main_flow.gd
git commit -m "Wire full game flow: runs, perks, results, shop, settings, saving, pause"
```

---

### Task 21: Balance simulation and data tuning

**Files:**
- Create: `test/test_balance.gd`
- Modify (only if needed): `data/*.json`

**Interfaces:**
- Consumes: `GameData`, `StatResolver`, `Economy`, `RunState`, `RunSim`, `StreetGen`, `PerkDeck`, `ModifierDeck`, `SaveStore`.
- The bot taps `BOT_TAP_LEAD` = 0.09 s before the predicted touchdown, which is a Good tap at base windows. Timing upgrades widen the Perfect window until those taps become Perfects, as they would for a real player. The bot picks the first perk offered and greedily buys the cheapest upgrade it can afford. It never buys cans.

- [ ] **Step 1: Write the balance test**

`test/test_balance.gd`:
```gdscript
extends GutTest
## Headless bot plays many runs with greedy shopping to catch progression walls (spec §6.2).

const RUNS := 150
const DT := 1.0 / 60.0
const BOT_TAP_LEAD := 0.09

var d: GameData

func before_all():
	d = GameData.load_all()

func _perk_effects(perks: Array) -> Array:
	var out: Array = []
	for p in perks:
		out.append_array(p.effects)
	return out

func _play_run(save: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var modifier := ModifierDeck.draw(d.modifiers, rng)
	var base_effects: Array = Economy.profile_effects(save, d) + modifier.effects
	var stats := StatResolver.resolve(d.tuning, base_effects)
	var state := RunState.new(stats, d.zones)
	var sim := RunSim.new(stats)
	sim.street = StreetGen.new(rng.randi(), d.zones, d.objects, stats.helper_freq)
	sim.launch(40.0, 1.0)
	var perks: Array = []
	var tapped := false
	var reason := ""
	var t := 0.0
	while not sim.ended and t < 900.0:
		if not tapped and sim.can.time_to_touchdown() <= BOT_TAP_LEAD:
			tapped = not sim.tap(sim.can_center()).is_empty()
		for ev in sim.advance(DT):
			match ev.type:
				"touchdown":
					tapped = false
				"graded":
					state.on_grade(ev.grade)
				"helper":
					state.on_helper(ev.combo)
				"run_end":
					reason = ev.reason
		for e in state.on_distance(sim.can.pos.x):
			if e.type == "perk_due":
				var offer := PerkDeck.draw(d.perks, rng, 1, perks.map(func(p): return p.id), stats.rare_mult)
				if not offer.is_empty():
					var old_kicks := int(stats.air_kicks)
					perks.append(offer[0])
					var fresh := StatResolver.resolve(d.tuning, base_effects + _perk_effects(perks))
					for k in fresh:
						stats[k] = fresh[k]
					sim.air_kicks_left += int(stats.air_kicks) - old_kicks
		t += DT
	return {"distance": state.distance, "coins": state.coins(), "zone": state.zone_index, "reason": reason}

func _shop(save: Dictionary) -> int:
	var bought := 0
	while true:
		var best := {}
		var best_cost := INF
		for u in d.upgrades:
			var lvl := Economy.level_of(save, u.id)
			if Economy.is_maxed(u, lvl):
				continue
			var c := Economy.cost(u, lvl)
			if c < best_cost:
				best_cost = c
				best = u
		if best.is_empty() or not Economy.try_buy(save, best):
			return bought
		bought += 1
	return bought

func _first_run_reaching(history: Array, zone: int) -> int:
	for i in history.size():
		if history[i].zone >= zone:
			return i
	return -1

func _mean_coins(rows: Array) -> float:
	var s := 0.0
	for r in rows:
		s += r.coins
	return s / maxf(1.0, rows.size())

func test_always_good_bot_progresses_exponentially():
	var save := SaveStore.defaults()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var history: Array = []
	var dry := 0
	var worst_dry := 0
	for i in RUNS:
		var r := _play_run(save, rng)
		save.coins += r.coins
		history.append(r)
		var bought := _shop(save)
		dry = 0 if bought > 0 else dry + 1
		if i < RUNS - 10:
			worst_dry = maxi(worst_dry, dry)
		if i % 10 == 9:
			gut.p("run %3d  dist %7.0f m  zone %d  coins %8s  bank %8s" % [
				i + 1, r.distance, r.zone, NumFmt.format(r.coins), NumFmt.format(save.coins)])
	assert_false(history.any(func(r): return r.reason == "watchdog"), "no watchdog endings")
	var downtown := _first_run_reaching(history, 1)
	var highway := _first_run_reaching(history, 2)
	gut.p("first Downtown run: %d, first Highway run: %d, worst dry streak: %d" % [downtown, highway, worst_dry])
	assert_between(downtown, 0, 59, "reaches Downtown within ~30 minutes (60 runs)")
	assert_between(highway, 0, RUNS - 1, "reaches Highway within 150 runs")
	assert_lte(worst_dry, 5, "never more than 5 runs in a row without a purchase")
	assert_gt(_mean_coins(history.slice(RUNS - 10)), _mean_coins(history.slice(0, 10)) * 100.0, "late runs earn 100x early runs")
```

- [ ] **Step 2: Run it**

Run: `./run_tests.sh -gtest=res://test/test_balance.gd`
Expected: it may fail at first. Read the printed progression table.

- [ ] **Step 3: Tune data until it passes**

Change **only `data/*.json`**. Never change code, and never loosen assertions without asking the user. Change one knob at a time and rerun after each change. Likely knobs:
- `zones.json` `start_m` (spec says "~400 m / ~1,200 m"; tunable)
- `tuning.json` `coin_per_meter`
- `upgrades.json` `base_cost` / `cost_growth`, and the effect sizes of `kick_power` and `timing`

Record each change and the before/after table in the task report.

- [ ] **Step 4: Run the full suite**

Run: `./run_tests.sh`
Expected: all pass, and the other tests still pass with the tuned data. `test_content_data` checks the zone order and the friction rule.

- [ ] **Step 5: Commit**

```bash
git add test/test_balance.gd data
git commit -m "Add balance bot and tune progression data" -m "<one line: key data changes>"
```

---

### Task 22: Final build and play check (USER GATE)

- [ ] **Step 1: Run the full suite and the build**

Run: `./run_tests.sh && ./build_web.sh`
Expected: all green and the build is ready.

- [ ] **Step 2: Local walkthrough**

Use `preview_start {name: "procrastican-web"}`. Do one complete loop (title → run → perk → results → shop → settings export) and check that the console has no errors. Take screenshots.

- [ ] **Step 3: STOP and hand off**

Ask the user to run `./deploy_web.sh` and play on iPhone from the home screen. Collect their feedback on feel, pacing and anything broken. Do not push or merge. The user decides how to integrate the branch (via superpowers:finishing-a-development-branch).
