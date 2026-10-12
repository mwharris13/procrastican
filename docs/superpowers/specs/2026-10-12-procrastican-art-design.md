# Procrastican — Art Pass Design

**Date:** 2026-10-12 · **Builds on:** `2026-10-12-procrastican-design.md` (v1) · **Status:** approved 2026-10-12

## 1. Intent

Replace v1's code-drawn placeholder shapes with real pixel art without changing how the game plays.
Everything visible gets art: the run scene, every street object, all UI screens with a pixel font, effects, and the app icon/splash.

**Success:** the game reads as one coherent "Golden Hour Skip-Day" pixel-art world at 270 px wide, still holds 60 fps on the
user's iPhone, and no gameplay behavior or balance changes. The kid and can designs are accepted as drawn for now and get
their own polish pass later (user decision).

**Visual source of truth:** the approved mockups in `docs/superpowers/specs/art-mockups/`:
`art-direction.html` (direction B), `zones.html`, `cast.html`, `ui.html`. Open them in a browser; sprite shapes, proportions
and colors follow them.

## 2. Decisions (from brainstorming)

| Topic | Decision |
|---|---|
| Art source | Claude authors every sprite as small vector SVGs; a bake step snaps them to pixels and to the palette. No asset packs, no AI images. |
| Direction | **B · Golden Hour Skip-Day**: warm sunset palette, long shadows, rim light, lit windows; kid with backpack + headphones. No outlines on world sprites. |
| Zones | Time advances with distance: Block = golden hour, Downtown = dusk, Highway Shoulder = night. Smooth 40 m blend before each boundary. |
| Cast | Kid (teal hoodie, red backpack, headphones) and the three cans as in `cast.html`; revisit in a later polish pass. |
| Font | **Press Start 2P** (SIL OFL), used only at 8 px and 16 px. |
| Pipeline | Approach 1: SVG sources → headless Godot bake → palette-snapped PNG sheets committed to the repo. |
| Screen scaling | Keep v1's `viewport` stretch with fractional scale (no letterboxing). Revisit only if uneven pixel columns are visible on the phone. |

## 3. Art pipeline

### 3.1 Sources
- `art/src/<sheet>/<name>.svg` — one sprite per file, authored in **game pixels** (viewBox = sprite size, e.g. `0 0 24 60`).
- Bake options live as attributes on the root `<svg>`:
  - `data-palette="shared,golden"` — palette groups this sprite may snap to (required).
  - `data-anchor="bottom-center"` — `bottom-center` (default), `center`, or `top-left`.
  - `data-spin="16"` — optional; render N evenly spaced rotation frames instead of one.
  - `data-frames="2"` — optional; the file holds N frames side by side, each `width/N` wide (e.g. idle scroll/blink).
- `art/palette.json` — named colors grouped by palette (§3.4).

### 3.2 Bake (`tools/bake_art.gd`, run via `./bake_art.sh`)
Headless Godot script (`godot --headless --script`). For each sheet directory:
1. Rasterize each SVG with `Image.load_svg_from_string()` at scale 1 (spin frames: wrap content in `<g transform="rotate(a cx cy)">`
   on a canvas grown to the rotated bounding box).
2. **Alpha harden:** alpha ≥ 50% → 255, else 0.
3. **Palette snap:** each opaque pixel → nearest color (RGB distance) among the sprite's declared palette groups.
4. Pack all frames of the sheet with a simple shelf packer (1 px transparent gutter) into `assets/sprites/<sheet>.png`.
5. Write `assets/sprites/<sheet>.json`: `{ "<name>[#i]": {"x","y","w","h","ax","ay"} }` where `ax/ay` is the anchor in frame pixels.
   Spin/frame sprites get `#0…#N-1` suffixes.
Sheets: `kid`, `cans`, `block`, `downtown`, `highway`, `street`, `objects`, `fx`, `ui`, `icons`, `app`.
Baked PNG/JSON are committed; the bake is re-run by hand after editing sources. `.import` settings use nearest filter, no mipmaps.

### 3.3 SpriteBank (`scripts/view/sprite_bank.gd`)
`RefCounted`; loads each sheet's texture + JSON once (cached statically).
- `frame(sheet, name) -> Dictionary` → `{tex, region: Rect2, anchor: Vector2}`.
- `draw(ci: CanvasItem, sheet, name, pos: Vector2, modulate := Color.WHITE)` — draws the region with its anchor at `pos` (rounded).
- Unknown names `push_error` once per name and draw nothing (no crash, no silent purple box).

### 3.4 Palette (`art/palette.json`)
Values extracted from the approved mockups. Groups:

- **shared** — ink `3b2d4a`, deep ink `2b2140`, paper `fff4e6`, paper2 `f6dcc6`, accent `e5676a`, accent dark `8a3b4a`,
  gold `ffd166`, coin rim `b88a2a`, white `ffffff`, teal `5aa9a0`, teal shade `468a83`, pants `3d3a5c`, skin `efbf94`,
  hair `2e2230`, shoe `f4ece6`, can red `e63946`, can light `ff7a83`, can dark `b52a36`, rim light `e6e6e6`, rim dark `bdbdbd`,
  lucky gold `e0b13f`, lucky light `fff1b8`, lucky dark `b88a2a`, clover `3f9a5c`, clover dark `2f7a47`, paint gray `9aa7b8`,
  paint light `c8d0dc`, paint dark `7a8798`, metal `7b8a8f`, metal light `93a3a8`, metal dark `5f6d72`, dog `c98a4b`,
  dog dark `7a4f2a`, glass `9fd0e0`, tire `2e2230`, hub `9a9aa8`, pigeon `8d8fa8`, pigeon neck `6fb0a0`, beak `e0a33f`,
  feet `e07a5f`, screen glow `bfe6ff`.
- **golden** (Block) — sky `6c6fb4` `c995c0` `f2a8a6` `ffd6a0`, sun `ffe9b0`, cloud `f7c6c0`, hills `c98fa8` `a7799b`,
  house bodies `e8a47a` `8fb3c0` `e2c06a` `b39ccf`, house shades `c9825e` `7193a3` `c3a04f` `957fb4`,
  roofs `b9566a` `4b5a8a` `c87444` `6a5687`, window `ffe08a`, door `5b4352`, bush `7f8f6a`, grass `6f8b55`, rim `ffe3c0`,
  sidewalk `d8b9a8`, curb `b89a8f`, road `4b4560`, lane `e8d6d0`, shadow `3b2d4a`, puddle `9fa6c9`, puddle shine `f2c4c7`.
- **dusk** (Downtown) — sky `2f3a6b` `6b5a9a` `c77fa4` `f0a58c`, low sun `ffc18a`, skyline `4a4377`, window lit `ffd98a`,
  window dark `3d3560`, brick `a35b4f` `8a4a40`, stucco `d7c1a3` `bfa88a`, blue `6f7fa6` `5a6a91`, tan `b98a6a` `9e7253`,
  awnings `2f6f6a` `c74b5b` `e0a33f`, sign `2e2440`, neon `ff8fb1`, shopfront glow `ffcf7a`, sidewalk `c4a9a6`, curb `a58e8c`,
  road `3c3652`, lane `f4d35e`, lamp `fff1b8`, drain `2a2440` `5c5478`.
- **night** (Highway) — sky `0f1433` `1d2552` `3a3a6e` `6b4a6e`, moon `f3ecd2`, city glow `b5658a`, far `2b2652` `232046`,
  shoulder `5a5070`, road `26243a`, edge line `ffffff`, lane `f4d35e`, sodium `ffa64d` `ffd08a`, pole `3a3555`,
  guardrail `9aa0b8` `c8cde0` `6c7088`, truck `d7d3e0` `ecebf2`, cab `c74b5b`, tire `1a1828`, gravel `8a84a0`.

Zone sky stops also move into `data/zones.json` (`palette.sky`, 4 hex stops) so `ZoneLook` reads them from data.

## 4. Asset inventory (~45 sprites)

| Sheet | Sprites |
|---|---|
| kid | `idle` (2 frames: scroll, blink), `aim_light`, `aim_strong`, `kick`, `watch`, `cheer`, `shrug` — ~24×60 px drawn into a 40×66 frame |
| cans | `soda`, `paint`, `lucky` — 18×26 px, `data-spin="16"` |
| block | `house_a`…`house_d` (incl. lit windows, rim light), `bush`, `hills_far`, `hills_near`, `cloud_a`, `cloud_b`, `sun_low`, `house_shadow` |
| downtown | `store_cafe`, `store_books`, `store_plain_a`, `store_plain_b` (awnings, lit shopfronts), `skyline`, `streetlight` |
| highway | `lamp_sodium`, `guardrail_seg`, `city_far`, `moon`, `star_a`, `star_b` |
| street | per zone: `sidewalk_<zone>`, `curb_<zone>`, `road_<zone>` tiles; `dash_white`, `dash_yellow`, `edge_line` |
| objects | one per id in `objects.json`: `mailbox`, `trash_can`, `dog`, `car`, `pigeon`, `guardrail`, `truck`, `puddle`, `grass`, `storm_drain`, `gravel` |
| fx | `coin`, `dust`, `spark`, `perfect_burst` (3 frames), `ring`, `can_shadow`, `light_pool` |
| ui | `panel` (9-slice), `panel_rare`, `button_normal/pressed/disabled`, `button_primary_normal/pressed`, `tab_on`, `tab_off`, `chip`, `pip_on`, `pip_off`, `coin_icon`, `new_best_stamp` |
| icons | 16×16 for every id in `upgrades.json`, `cans.json`, `perks.json` (`icon_<id>`) |
| app | `icon_512` (scaled to 180/192 at export), `splash` |

Object sprites are drawn at roughly their gameplay footprint (`width × px_per_m` for hazards); collision data is unchanged.

## 5. Run scene

`RunView` keeps immediate-mode `_draw()`; only the `_draw_*` helpers change to draw sprites via `SpriteBank`.
Physics, input, camera, `RunSim` and all their tests are untouched.

**Draw order (back → front), with parallax factor vs. camera:**
1. Sky gradient — code-drawn bands from `ZoneLook.sky_stops` (0×).
2. Sky props — sun/moon/stars/clouds (0.1×).
3. Far layer — hills / skyline / city glow (0.3×), crossfaded during blends.
4. Buildings (1×) — slot every `HOUSE_SPACING_M`; each slot's art chosen deterministically from its world x
   (hash of slot index → variant; zone = zone at that slot's x), plus long shadow sprite in golden hour.
5. Street — tiled sidewalk/curb/road for the zone at each tile's x; lane dashes.
6. Light layer — child `Node2D` with additive `CanvasItemMaterial`: lamp `light_pool`s, shopfront glow (Downtown/Highway).
7. Objects — anchored bottom-center at world x; hazards lie on the road surface.
8. Kid, can shadow, landing ring, can.
9. Effects — particles and popups (via `Juice`).

**ZoneLook (`scripts/core/zone_look.gd`, RefCounted, unit-tested):**
- `blend_at(zones, x) -> {from: int, to: int, t: float}` — `t` ramps 0→1 over the 40 m before each zone's `start_m`; `t = 0` elsewhere.
- `sky_stops(zones, x) -> Array[Color]` — per-stop lerp of the two zones' `palette.sky`.
- `tint(zones, x) -> Color` — world tint for shared sprites (objects, kid): Block `ffffff`, Downtown `e9dcf2`, Highway `a9add8`,
  lerped; the can uses half strength (lerp toward white by 0.5) so it always stays readable.
- `zone_index_at` stays in `RunState`; `ZoneLook` reuses it.
The existing `zone` event no longer swaps a palette instantly; the view reads `ZoneLook` every frame from the camera's world x.

**Kid states:** `idle` (scroll frame; blink frame for 0.15 s every 3–5 s) before the first drag → `aim_light`/`aim_strong`
(strong when drag power ≥ 60%) while dragging → `kick` for 0.15 s after release → `watch` until off-screen.
Results screen shows `cheer` on a new best, else `shrug`. No sprite rotation of the kid.

**Can:** spin frame `posmod(roundi(angle_deg / 22.5), 16)`; existing squash/stretch scale is kept.

**Effects:** `Juice.burst` takes a sprite name (`coin`, `spark`, `dust`) instead of a flat color; Perfect plays `perfect_burst`.
Popups use the theme font at 16 px with a 4 px ink outline (PERFECT! gold, GOOD white, miss gray).

## 6. UI

**Font:** `assets/fonts/PressStart2P-Regular.ttf` + `assets/fonts/OFL.txt` (from `github.com/google/fonts`, `ofl/pressstart2p`;
download approved by the user). `FontFile` with antialiasing off, hinting none, subpixel positioning off. Sizes: 8 (body), 16 (headings, popups, logo uses 16 scaled ×2 via `Label.scale` integer).

**Theme:** `UiTheme.build() -> Theme` creates the default font/size, `StyleBoxTexture` 9-slices from the `ui` sheet for
`PanelContainer`, `Button` (normal/hover = normal, pressed, disabled, focus = empty) and tab buttons, and label outline settings.
`ScreenBase` applies it; color constants remain for code that needs them.

**Screens** (layouts per `ui.html`):
- **Title** — gold logo with plum outline, v1 tagline, coin chip, best distance, primary "Kick a can", "Shop", small "Settings"; live street with idle kid behind.
- **Results** — paper panel: rest message, distance + `new_best_stamp`, best combo, Perfects, zone; coins count up over ~0.8 s with `tick` sfx; kid cheer/shrug sprite; "Kick again" primary, "Shop".
- **Shop** — title + coin chip, Gear/Skills/Luck folder tabs, item rows with `icon_<id>`, name, description, level pips (max 5 shown + "+N"), price; unaffordable rows at 55% opacity.
- **Perk pick** — "Pick a perk!" heading, checkpoint distance, three cards with icons; rare cards use `panel_rare`; cards pop in 80 ms apart after the existing 400 ms arm delay.
- **HUD** — distance chip (left) and combo chip (right); modifier line in 8 px.
- **Settings** — restyled only. **Tuning overlay** — unchanged debug UI.

**Copy pass:** every `desc` in `upgrades.json`, `perks.json`, `modifiers.json`, `cans.json` must fit two 8 px lines at the
panel's inner width: ≤ 56 chars and no word > 28 chars. Rewrite longer ones keeping meaning.

**Sfx:** add a `tick` synth sound for the coin count-up (SynthSfx, same pattern as existing sounds).

## 7. App icon and splash
- `art/src/app/icon.svg` (can mid-kick on golden sky, rounded-square safe area) baked to `icon_512`; export preset uses it
  for PWA icons 144/180/512 and `apple-touch-icon`.
- Boot splash: `splash.png` (logo on dusk `2f3a6b`), `boot_splash/bg_color = 2f3a6b`, no Godot logo.

## 8. Error handling
- Missing sprite name → one `push_error` per name, nothing drawn, game continues.
- Missing sheet file → `SpriteBank` errors once and the view falls back to drawing nothing for that layer (sky gradient still draws).
- Bake: an SVG without `data-palette`, an unknown palette group, or an SVG that fails to parse aborts the bake with the file name; partial sheets are not written.

## 9. Testing
GUT (engine ERROR lines count as failures, so tests that expect errors use the existing error-assert pattern):
- **Bake:** fixture SVGs in `test/fixtures/art/` → alpha only 0/255; every opaque pixel in its declared palette; spin produces 16 frames with sane sizes; frame strips split correctly; JSON regions lie inside the PNG.
- **Coverage:** every object id, can id, upgrade id and perk id has its sprite/icon in the baked JSON; every zone has a 4-stop `palette.sky`.
- **ZoneLook:** `t` = 0 before the window, 0.5 mid-window, → 1 at `start_m`, 0 inside a zone; `sky_stops` endpoints equal the zone stops; building variant for a given x is stable.
- **Can spin index:** 0°, 11.24°, 11.26°, 359°, −22.5°, 720°.
- **SpriteBank:** known name returns region/anchor; unknown name errors once and returns empty.
- **Copy length:** all descriptions satisfy the §6 rule.
- **Visual check:** browser screenshots of each zone, both transitions, and every screen at 375×812.
- **User gate:** deploy + iPhone play check: looks right, still 60 fps, nothing broken.

## 10. Sequencing
0. Branch `art/v1` from `build/v1` (user skipped the v1 final review; no separate plan doc, implement from this spec).
1. Pipeline: `art/palette.json`, `tools/bake_art.gd`, `bake_art.sh`, `SpriteBank`, bake + bank tests.
2. Block art: kid, cans, block sheet, street, objects, fx basics; wire into `RunView` → contact sheet for a quick user OK.
3. Downtown + Highway sheets, `ZoneLook`, light layer → contact sheet + transition screenshots.
4. Effects: sprite particles, Perfect burst, popups.
5. UI: font, `UiTheme.build()`, all screens, icons sheet, copy pass, `tick` sfx → screenshots of every screen.
6. App icon + splash, final build → user deploys and plays (gate).

## 11. Out of scope
Kid/can redesign (later polish pass), new zones or objects, animation beyond the listed frames, music, gameplay or balance changes,
prestige.
