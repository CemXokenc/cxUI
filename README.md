<div align="center">

# cxUI

**Minimalist interface addon for World of Warcraft**

A lightweight, performance-focused suite that declutters your screen and enhances combat awareness.

[![Version](https://img.shields.io/badge/version-1.1.0-blue.svg)](https://github.com/CemXokenc/cxUI)
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

## 🎯 Modules

cxUI consists of 6 independent modules, each addressing a specific aspect of UI optimization:

### 🌫️ **Module 1: Transparency & Auto-Hide**

Intelligently fades UI elements based on context and mouse position.

**Features:**
- **Action Bars**: Automatically hide out of combat, reveal on mouseover
- **Micro Menu & Bags**: Fade until hovered
- **Quest Tracker**: Only visible when you need it (mouseover)

**Use case:** Clean screen during exploration and questing, full accessibility during combat.

---

### 🛡️ **Module 2: Absorb Display**

Track your shield strength at a glance.

**Features:**
- Displays total absorb amount in the center of your screen
- Only visible during combat — automatically hides when out of combat
- Auto-scales numbers (1.2K, 450K, etc.)
- Updates in real-time

**Use case:** Essential for tanks and healers who rely on shields. Know your mitigation status without checking unit frames.

---

### ✨ **Module 3: CDM Glow**

Visual proc highlighting for class abilities.

**Features:**
- Custom glow effects when key procs activate
- Scans action bars automatically
- Works with Blizzard Cooldown Viewer and custom bars

**Default configuration:** Death Knight (Sudden Doom → Death Coil glow)

#### 🔧 How to Add Your Own Spells

1. Open `Module_CDMGlow.lua`
2. Find the `PROC_CONFIG` table near the top
3. Add your class and spell IDs:

```lua
local PROC_CONFIG = {
    DEATHKNIGHT = { [81340] = { 47541, 207317 } },
    PALADIN = { [59578] = { 879 } },  -- Art of War → Exorcism
    WARRIOR = { [85739] = { 100 } },  -- Slam proc → Mortal Strike
    -- Add more classes here
}
```

**Format explanation:**
- `[Aura_Spell_ID]` = The buff/proc you're tracking
- `{ Target_Spell_ID_1, Target_Spell_ID_2 }` = Abilities that should glow

**Finding Spell IDs:**
- Use `/dump GetSpellInfo("Spell Name")` in-game
- Or check [Wowhead](https://www.wowhead.com) spell pages (ID is in the URL)

**Commands:**
```
/cdmglow on       Enable the module
/cdmglow off      Disable the module
/cdmglow rescan   Force rescan of action bars
```

---

### 🔧 **Module 4: Small Tweaks**

Quality-of-life improvements and UI decluttering.

**Features:**
- **Hide Help Tips**: Suppresses notifications like "You have unspent talent points" and "Choose your hero talents"
- **Mega Macro Override**: Redirects the default Macros button to Mega Macro addon (if installed)
- **Ready Check Alert**: Plays ready check sound through the Master audio channel — audible even when alt-tabbed
- **Group Invite Sound**: Plays the dungeon finder alarm through Master when a group invite arrives — never miss an invite while alt-tabbed
- **Pull Timer Countdown**: Plays audio at 10, 5, 4, 3, 2, 1 seconds and "Go" on zero for any pull timer — `/pull` command, BigWigs, DBM, and BG/arena preparation timers all supported. Uses SharedMedia_Causese countdown sounds
- **Block Right-Click Targeting**: Prevents accidental right-click targeting in Dungeons & Raids during combat

**Use case:** Remove visual clutter, never miss invites or pull timers regardless of audio settings.

---

### ❤️ **Module 5: Health Safety**

Visual and audio warnings when your health drops dangerously low.

**Features:**
- Audio alert at critically low HP
- Automatic disable when dead/ghost

**Use case:** Stay aware of your health during intense combat without constantly watching your health bar.

---

### ⚔️ **Module 6: Class Features**

Contextual combat overlays tailored to specific class mechanics.

**Features:**
- **Enemy Counter — Unholy DK**: Displays a live enemy count above the Death Coil button in the CDM panel during combat. Helps decide when to swap from Death Coil to Epidemic (3+ enemies).

**Use case:** Removes the mental overhead of counting nearby enemies — the number is always visible, right where your eyes already are.

---

## ⚙️ Settings

Access the settings panel:
```
ESC → Options → AddOns → cxUI
```

**Options marked with `(Requires Reload)*` need `/reload` to take effect.**

### Available Toggles:

| Module | Setting | Reload Required |
|--------|---------|-----------------|
| Transparency | Action Bar Auto-hide | ❌ |
| Transparency | Micro Menu Auto-hide | ❌ |
| Transparency | Quest Tracker Hover | ✅ |
| Absorb | Enable Absorb Display | ✅ |
| CDM Glow | Enable Proc Glow | ❌ |
| CDM Glow | Suppress Untracked Glows | ❌ |
| Small Tweaks | Hide Talent Alerts | ✅ |
| Small Tweaks | Mega Macro Override | ❌ |
| Small Tweaks | Ready Check Alert | ❌ |
| Small Tweaks | Group Invite Sound | ❌ |
| Small Tweaks | Pull Timer Countdown Sound | ❌ |
| Small Tweaks | Block Right-Click Targeting | ❌ |
| Health Safety | Low Health Sound Alert | ❌ |
| Class Features | Enemy Counter — Unholy DK | ❌ |

---

## 🚀 Performance

cxUI is designed for **zero impact** on gameplay:

- Event-driven architecture (no polling)
- Minimal memory footprint (~500KB)
- Efficient frame updates (OnUpdate limited to 10 FPS)
- Conditional module loading

---

## 🐛 Troubleshooting

**Settings panel not showing?**
- Make sure the addon is enabled in the character select screen
- Try `/reload` after installation

**CDM Glow not working?**
- Verify spell IDs are correct
- Use `/cdmglow rescan` to rebuild the button cache
- Check that Blizzard Cooldown Viewer is enabled

**Enemy Counter not appearing?**
- Make sure you are playing Unholy Death Knight (spec 3)
- The counter only shows during active combat with enemies in range
- Run `/cxaoe scan` out of combat to verify the Death Coil CDM frame is found
- If `frames=0`, try `/reload` — CDM may not have fully initialized yet

**Pull Timer not playing sounds?**
- Make sure `SharedMedia_Causese` addon is installed (provides the countdown sound files)
- The setting requires `/reload` if toggled for the first time
- Supported sources: `/pull` command, BigWigs, DBM, BG/arena preparation timers

---

## 📝 Credits

**Author:** cemxokenc  
**Inspiration:** Minimalist UI philosophy, ElvUI, LortiUI

---

## 📄 License

This project is open source and available under the MIT License.

---

<div align="center">

**[Report an Issue](https://github.com/CemXokenc/cxUI/issues)** • **[Request a Feature](https://github.com/CemXokenc/cxUI/issues/new)**

Made with ❤️ for the WoW community

</div>
