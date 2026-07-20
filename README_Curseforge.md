# cxUI - Minimalist Interface Suite

**cxUI** is a performance-focused, modular addon designed to declutter your World of Warcraft interface while enhancing combat awareness. Built with a "clean screen, full control" philosophy, it intelligently manages UI elements so you can focus on gameplay.

## 🎯 Core Features

### 🌫️ Smart Auto-Hide System
- **Action Bars**: Automatically fade out of combat, reveal on mouseover
- **Micro Menu & Bags**: Hidden until you need them
- **Quest Tracker**: Only visible when hovering over its area
- Perfect for immersive gameplay and screenshot-friendly UI

### 🛡️ Combat Absorb Display
- Real-time shield tracking in screen center
- Only shows during combat to avoid clutter
- Auto-abbreviated numbers (1.2K, 450K, etc.)
- Essential for tanks and healers

### ✨ CDM Glow - Proc Highlighting
- Visual glow effects when key abilities proc
- Automatically scans your action bars
- Works with Blizzard Cooldown Viewer and custom bars
- Easy to configure for any class/spec
- **Pre-configured for Death Knights** (Sudden Doom → Death Coil)

### ❤️ Low Health Alerts
- Audio alert at critical HP
- Helps maintain situational awareness
- Automatically disables when dead

### ⚔️ Class Features — Unholy DK Enemy Counter
- Live enemy count displayed above the Death Coil CDM button during combat
- Instantly see when to swap from Death Coil to Epidemic (3+ enemies)
- Event-driven — reacts immediately to nameplate changes
- Zero performance cost outside combat

## 🔧 Quality of Life Tweaks
- Hide annoying talent notifications ("You have unspent talent points")
- Mega Macro button integration
- Plays ready check sound through the Master channel — audible when alt-tabbed
- **Group Invite Sound**: plays the dungeon finder alarm through Master on any group invite
- **Pull Timer Countdown**: audio at 10, 5, 4, 3, 2, 1 seconds + "Go" at zero — works with `/pull`, BigWigs, DBM, and BG/arena timers. Requires SharedMedia_Causese
- Block Right-Click Targeting in Combat (Dungeons & Raids)

## ⚙️ Easy Configuration

Access settings via: **ESC → Options → AddOns → cxUI**

All modules can be toggled independently. Some features require `/reload` — clearly marked in settings panel.

## 🎨 Customization: Add Your Own Procs

Want to highlight your class procs? It's simple:

1. Open `Module_CDMGlow.lua`
2. Add your spells to the `PROC_CONFIG` table:
```lua
PALADIN = { [59578] = { 879 } },  -- Art of War → Exorcism
WARRIOR = { [85739] = { 100 } },  -- Slam proc → Mortal Strike
```
3. `/reload` and you're done!

**Commands:**
- `/cdmglow on` - Enable proc highlighting
- `/cdmglow off` - Disable proc highlighting
- `/cdmglow rescan` - Rebuild action bar cache
- `/cxaoe scan` - Verify Enemy Counter frame detection
- `/cxaoe status` - Show live Enemy Counter diagnostics

## 🚀 Performance
- **Zero lag**: Event-driven architecture, no polling
- **Tiny footprint**: ~500KB memory usage
- **Optimized updates**: Frame updates limited to 10 FPS where appropriate
- **Modular**: Only active features consume resources

## 📦 What's Included
- **Module 1**: Transparency & Auto-Hide
- **Module 2**: Absorb Display
- **Module 3**: CDM Glow (Proc Highlighting)
- **Module 4**: Small Tweaks (UI Cleanup)
- **Module 5**: Health Safety (Low Health Alert)
- **Module 6**: Class Features (Unholy DK Enemy Counter)

## 🔗 Compatibility
- **Game Version**: Retail (11.0.7+)
- **Works with**: ElvUI, Bartender, Dominos, most major addons
- **Recommended**: Blizzard Cooldown Viewer (for full CDM Glow and Enemy Counter functionality)
- **Optional**: Mega Macro (for macro button override)

## 💡 Philosophy

cxUI follows three principles:
1. **Clean by default** — Hide what you don't need right now
2. **Instant access** — Everything appears when you need it
3. **Zero compromise** — Performance and functionality go hand-in-hand

Perfect for players who want a minimalist interface without sacrificing functionality.

## 🐛 Support & Feedback

Found a bug? Have a feature request? Visit the [GitHub Issues](https://github.com/CemXokenc/cxUI/issues) page.

For questions and discussion, leave a comment below!

---

**Enjoy a cleaner WoW experience!** 🎮