# Tower Tiles: Nine Lives 🐱🏰

*A cozy-chaotic 3D tower defense game in **Godot 4.7**, built for the web.*

Your cat lives at the top of a cat tree. The neighborhood dogs want in. Build a squad of kittens along the road, upgrade them, grab perks between waves, and keep all nine lives.

![Gameplay](docs/screenshot.png)

## How to play

| Action | Mouse / touch | Keys |
| --- | --- | --- |
| Pick a kitten to build | Click a card in the bottom bar | `1`–`5` |
| Place it | Click a grass tile (tap twice on touch) | Hold `Shift` to keep placing |
| Select / upgrade / sell | Click a kitten | `U` upgrade · `X` sell · `T` target mode |
| Start the next wave early (bonus gold) | **Start Wave** button | `Space` |
| Giant Paw Slam | Paw button, then click the road | `Q` |
| Zoomies (2× attack speed) | Lightning button | `E` |
| Game speed 1×/2×/3× | Speed button | `F` |
| Pan / zoom | Right-drag · mouse wheel · pinch | `WASD` / arrows |
| Pause | Pause button | `Esc` |

### Kittens
| Kitten | Role |
| --- | --- |
| **Yarn Kitty** | Cheap, reliable single-target damage. Max level throws two yarn balls. |
| **Hiss Box** | Hisses in a ring, slowing every dog nearby. Max level stuns. |
| **Fish Cannon** | Lobs smelly fish that splash a whole group. |
| **Laser Kitty** | Locks on to one dog; damage ramps up the longer it stares. Max level chains. |
| **Fat Cat** | Naps on a pile of coins and pays out gold after every wave. |

Every kitten has 4 levels, targeting modes (First / Last / Strong / Close) and sells back for 70%.

### Dogs
Pups (fast, weak), Hounds, Greyhounds (very fast), Bulldogs (armored, cost 2 lives), Poodles (heal their friends), and two bosses: the **Alpha Hound** (howls to speed up the pack) and the **Vacuum 3000** (jams nearby kittens).

### Upgrades: three layers
1. **In-run:** level kittens up with gold.
2. **Purr-ks:** every 3 waves, pick 1 of 3 roguelite perks (Sharp Claws, Catfeine, Lucky Whiskers crits, Yarn Storm, Hoarder interest…). They stack.
3. **The Cat Tree (meta):** surviving waves earns 🐟 fish, which buy permanent upgrades on the main menu (starting gold, extra lives, damage, paw power, cooldowns, perk rerolls…). Refundable anytime.

Three maps unlock in order (The Backyard → Garden Maze → The Dog Park). Each run is 20 waves with a boss every 5; clear it to earn up to ★★★ (no lives lost), then keep going in **Endless Mode**.

## Juice
Screen shake with trauma falloff, hit-stop on big moments, white hit-flash, squash-and-stretch on everything, bouncing dogs that get *bonked* off the map, floating damage numbers and crits, kill combos, coins that fly into your gold counter, wave banners, cat reactions (puffing up, hissing, happy hops), a giant paw from the sky, a cat-eye iris transition, procedurally generated sound effects and music, and a live battle running behind the main menu.

## Web build & performance
- **Compatibility renderer** (WebGL 2) and a **single-threaded** export, so it runs on itch.io or GitHub Pages with no special server headers.
- All models are built in code from primitives and baked into **one vertex-colored mesh per model**, so each dog or kitten is one or two draw calls. Tiles, trees, rocks and flowers use `MultiMesh`.
- Health bars, damage numbers and flying coins are drawn by **one** 2D canvas item instead of hundreds of nodes.
- Particles and effect rings are pooled; nothing is allocated mid-fight.
- The game's own data is **under 1 MB**: no textures, two fonts, small WAV sound effects and OGG music. A low-quality mode (no shadows, 75% 3D resolution) is picked automatically on mobile browsers and can be toggled in Settings.

### Export it yourself
1. Install **Godot 4.7.2** and its export templates.
2. *Project → Export → Web → Export Project* (outputs to `build/web/`).
3. Serve the folder with any static web server, or upload it to itch.io as an HTML5 game.

### Auto-deploy to GitHub Pages
`.github/workflows/deploy-web.yml` builds the web export on every push to `main`. To turn it on, go to **Settings → Pages → Source: GitHub Actions**. The game will be at `https://<user>.github.io/<repo>/`.

## Project layout
```
autoload/   Save (progress + settings), Sfx (pooled audio + music), Transition (iris wipe)
game/       game.gd (the run), level, enemy, turret, projectile, cat rig, tower, fx, overlay, camera
            game_data.gd holds every number: kittens, dogs, perks, meta upgrades, maps, waves
ui/         HUD, theme/UI kit, vector icons, settings panel
scenes/     main_menu + game scenes
audio/      generated sfx (.wav) and music (.ogg)
tools/      gen_audio.py: regenerates all audio (python3 + numpy + ffmpeg)
```

### Add a map
Add an entry to `GameData.MAPS`: an ASCII grid where `.` is buildable grass, `#` is road, `S` is the dog house, `C` is your cat's tower, and `T`/`R` are trees and rocks. Roads must not touch sideways.

### Rebalance
All tuning lives in `game/game_data.gd`: kitten stats per level, dog stats, `hp_mult()` (wave scaling), `build_wave()` (wave composition), perks and meta costs.
