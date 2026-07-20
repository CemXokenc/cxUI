<div align="center">

# cxUI

**Minimalist interface addon for World of Warcraft**

A lightweight, performance-focused suite that declutters your screen and enhances combat awareness.

[![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)](https://github.com/CemXokenc/cxUI)
[![Game Version](https://img.shields.io/badge/game-12.0.0-orange.svg)](https://worldofwarcraft.com)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)

</div>

---

## 📦 Installation

1. **Download** the latest release or clone this repository
2. **Extract** the `cxUI` folder into:
   ```
   World of Warcraft\_retail_\Interface\AddOns\
   ```
3. **Restart** the game or type `/reload`
4. **Configure** via ESC → Options → AddOns → cxUI

---

## 🗂️ Structure

```
cxUI/
├── core.lua                        # Settings DB & options panel
├── cxUI.toc
├── libs/
│   └── LibCustomGlow-1.0.lua
├── media/
│   └── lowhp.ogg
└── modules/
    ├── Transparency/               # Module 1 — auto-hide bars & tracker
    │   └── Transparency.lua
    ├── CDM/                        # Module 2 — CDM proc/pixel glow
    │   └── CDMGlow.lua
    ├── SmallTweaks/                # Module 3 — one file per tweak
    │   ├── Absorb.lua              #   absorb display
    │   ├── Alerts.lua              #   suppress talent notifications
    │   ├── MacroOverride.lua       #   redirect Macros → Mega Macro
    │   ├── Sounds.lua              #   ready check / invite / pull timer / low health
    │   ├── RCM.lua                 #   block right-click targeting in combat
    │   ├── MogMountFlyingInGround.lua #   flying mount in MogMount's ground slot
    │   ├── Death.lua               #   auto-accept resurrection / auto-release in PvP
    │   ├── LFG.lua                 #   Dungeon Finder advanced filters / reset button position
    │   └── Mail.lua                #   remember last mail recipient
    └── ClassFeatures/              # Module 4 — class-specific overlays
        ├── Shared.lua              #   frame scan & overlay helpers (loads first)
        ├── DeathKnight.lua         #   enemy counter, festering glow, putrefy cross, frost swap
        └── Mage.lua                #   flurry cross
```

Every module lives in its own folder for consistent structure. Modules with multiple independent features (`SmallTweaks`, `ClassFeatures`) have one file per feature so each can be edited or disabled without touching anything else.

Shared helpers between `DeathKnight.lua` and `Mage.lua` (frame scan, overlay creation, glow/cross utilities) live in `Shared.lua` and are exported via the `ns.CF` addon namespace table.

---

## 🎯 Modules

### 🌫️ Module 1: Transparency & Auto-Hide — `Module_Transparency.lua`

Intelligently fades UI elements based on context and mouse position.

| Feature | Behaviour |
|---|---|
| Action Bars | Hide out of combat, reveal on mouseover |
| Micro Menu & Bags | Fade until hovered |
| Quest Tracker | Only visible on mouseover |

---

### 🛡️ Absorb Display

Displays total shield amount in the center of the screen during combat. Auto-scales numbers (1.2K, 450K, …) and hides when out of combat. Lives in `modules/SmallTweaks/Absorb.lua`, toggled as part of Module 3 below.

---

### ✨ Module 2: CDM Glow — `modules/CDM/CDMGlow.lua`

Custom glow effects when class procs activate. Scans action bars automatically and works with Blizzard Cooldown Viewer and custom bar addons.

**Default:** Death Knight — Sudden Doom → Death Coil glow.

#### Glow Style

Pick which visual style is used for every proc glow, via **ESC → Options → AddOns → cxUI**:

| Style | Description |
|---|---|
| **Proc Glow** (default) | Blizzard's native gold flipbook glow — same animation as the standard action bar proc glow |
| **Pixel Glow** | A ring of small pixels ("marching ants") travelling around the frame border, à la WeakAuras pixel glow |

Both engines are fully self-contained (isolated frame pools, no `LibStub`), so switching styles — or having ElvUI loaded — can never break or desync the glow. Switching takes effect immediately on any currently-active glow, no reload needed.

#### Adding your own spells

Open `CDMGlow.lua` and edit the `PROC_CONFIG` table:

```lua
local PROC_CONFIG = {
    DEATHKNIGHT = { [81340] = { 47541, 207317 } },
    PALADIN = { [59578] = { 879 } },   -- Art of War → Exorcism
    WARRIOR = { [85739] = { 100 } },   -- Slam proc → Mortal Strike
}
```

- `[Aura_Spell_ID]` — the buff/proc you're tracking
- `{ Target_Spell_ID, … }` — abilities that should glow

Spell IDs are in Wowhead URLs or via `/dump GetSpellInfo("Name")` in-game.

**Commands:**
```
/cdmglow on       Enable
/cdmglow off      Disable
/cdmglow rescan   Force rescan of action bars
```

---

### 🔧 Module 3: Small Tweaks — `modules/SmallTweaks/`

Quality-of-life improvements, one file per feature. Everything here is independent — enable only what you need.

| File | Feature | What it does |
|---|---|---|
| `Absorb.lua` | Enable Absorb Display | Shows total shield amount in screen center during combat |
| `Alerts.lua` | Hide Help Tips | Suppresses "You have unspent talent points" and similar notifications |
| `MacroOverride.lua` | Mega Macro Override | Redirects the default Macros button to Mega Macro (if installed) |
| `Sounds.lua` | Ready Check Alert | Plays ready check sound through Master — audible when alt-tabbed |
| `Sounds.lua` | Group Invite Sound | Plays dungeon-finder alarm through Master on any group invite |
| `Sounds.lua` | Pull Timer Countdown | Audio at 10, 5, 4, 3, 2, 1 s for `/pull`, BigWigs, DBM, BG/arena timers. Requires `SharedMedia_Causese` |
| `Sounds.lua` | Low Health Alert | Plays a custom sound when your health drops critically low |
| `RCM.lua` | Block Right-Click Targeting | Prevents accidental right-click targeting in Dungeons & Raids during combat |
| `MogMountFlyingInGround.lua` | MogMount: Flying in Ground | Allows picking a flying mount in MogMount's ground slot. Requires MogMount addon |
| `Death.lua` | Auto-Accept Resurrection | Automatically accepts resurrection requests, but not while the resurrecting unit is in combat |
| `Death.lua` | Auto-Release in PvP | Automatically releases your spirit in battlegrounds and supported world PvP zones, unless you can self-resurrect |
| `LFG.lua` | Dungeon Finder: Advanced Filters | Adds party-fit, Bloodlust/Battle Res, and same-spec filters to the Dungeon Finder search list |
| `LFG.lua` | Move 'Reset Filter' Button | Shifts the Dungeon Browser's "Reset Filter" button to the left side to avoid overlap |
| `Mail.lua` | Remember Last Recipient | Keeps the last recipient in the mailbox "To" field after sending, until the mailbox is closed |

To disable a single tweak without a reload, you can comment out its line in `cxUI.toc`.

---

### ⚔️ Module 4: Class Features — `modules/ClassFeatures/`

Contextual combat overlays for specific class mechanics. Only the file matching your class runs; the others return immediately.

**`Shared.lua`** loads first and exports frame-scan and overlay utilities (`ns.CF`) used by both class files.

#### Death Knight (`DeathKnight.lua`)

| Feature | DB key | Description |
|---|---|---|
| Enemy Counter | `cdmEnemyCounter` | Live enemy count above the Death Coil CDM button. Helps decide DC vs Epidemic (3+ enemies). Unholy only. |
| Festering Strike Glow | `cdmFesteringGlow` | White glow on Festering Strike/Scythe CDM when buff has <5 s left. Unholy only. |
| Putrefy Cross | `cdmPutrefyCross` | Red × on Putrefy CDM when Dark Transformation has <9 s CD. Unholy only. |
| Frost Bar Swap | `cdmFrostBarSwap` | Swaps Obliterate/Scythe and FS/GA icons on CDM after action bar page changes. Frost only. |

**Debug commands:**
```
/cxaoe scan     Rescan CDM frames and print counts
/cxaoe status   Print spec, enemy count, glow/cross state
```

#### Mage (`Mage.lua`)

| Feature | DB key | Description |
|---|---|---|
| Flurry Cross | `cdmFlurryCross` | Red × on Flurry CDM when both procs (190446 & 1247729) are active. Cleared on Ice Lance cast. |

**Debug commands:**
```
/cxmage scan    Rescan CDM frames
/cxmage force   Force-show the cross for testing
```

---

## ⚙️ Settings

```
ESC → Options → AddOns → cxUI
```

Options marked **`(Requires Reload)*`** need `/reload` to take effect.

| Module | Setting | Reload |
|---|---|---|
| Transparency | Action Bar Auto-hide | ❌ |
| Transparency | Micro Menu Auto-hide | ❌ |
| Transparency | Quest Tracker Hover | ✅ |
| CDM Glow | Enable Proc Glow | ❌ |
| CDM Glow | Suppress Untracked Glows | ❌ |
| CDM Glow | Glow Style (Proc / Pixel) | ❌ |
| Small Tweaks | Enable Absorb Display | ✅ |
| Small Tweaks | Hide Talent Alerts | ✅ |
| Small Tweaks | Mega Macro Override | ❌ |
| Small Tweaks | Ready Check Alert | ❌ |
| Small Tweaks | Group Invite Sound | ❌ |
| Small Tweaks | Pull Timer Countdown Sound | ❌ |
| Small Tweaks | Low Health Sound Alert | ❌ |
| Small Tweaks | Block Right-Click Targeting | ❌ |
| Small Tweaks | MogMount: Flying in Ground | ❌ |
| Small Tweaks | Auto-Accept Resurrection | ❌ |
| Small Tweaks | Auto-Release in PvP | ❌ |
| Small Tweaks | Dungeon Finder: Advanced Filters | ✅ |
| Small Tweaks | Move 'Reset Filter' Button | ✅ |
| Small Tweaks | Mail: Remember Last Recipient | ❌ |
| Class Features | Enemy Counter — Unholy DK | ❌ |
| Class Features | Festering Strike Glow — Unholy DK | ❌ |
| Class Features | Putrefy Cross — Unholy DK | ❌ |
| Class Features | Flurry Cross — Frost Mage | ❌ |
| Class Features | Swap ST/AOE — Frost DK | ❌ |

---

## 🚀 Performance

- Event-driven architecture — no polling
- Class files early-return for non-matching classes
- Minimal memory footprint (~500 KB)
- Frame updates only on relevant events

---

## 🐛 Troubleshooting

**Settings panel not showing?**
Try `/reload`. Make sure the addon is enabled on the character select screen.

**CDM Glow not working?**
Verify spell IDs, then run `/cdmglow rescan`. Check that Blizzard Cooldown Viewer is enabled.

**Enemy Counter not appearing?**
Must be Unholy Death Knight (spec 3), in active combat, with enemies on nameplates. Run `/cxaoe scan` out of combat to verify the Death Coil CDM frame is found. If `counter=0`, try `/reload` — CDM may not have fully initialized yet.

**Pull Timer not playing sounds?**
`SharedMedia_Causese` must be installed. Supported sources: `/pull`, BigWigs, DBM, BG/arena preparation timers.

**Festering or Putrefy overlays not showing?**
Run `/cxaoe scan` to rebuild CDM frame references, then check `/cxaoe status` for state.

---

## 📝 Credits

**Author:** cemxokenc  
**Inspiration:** Minimalist UI philosophy, ElvUI, LortiUI

---

## 📄 License

Open source under the MIT License.

---

<div align="center">

**[Report an Issue](https://github.com/CemXokenc/cxUI/issues)** • **[Request a Feature](https://github.com/CemXokenc/cxUI/issues/new)**

Made with ❤️ for the WoW community

</div>
