# cemxokenc UI Suite

A lightweight, high-performance modular addon for World of Warcraft (Retail) designed to declutter the interface and enhance combat awareness.

## Key Features

* **Dynamic UI Hiding**: Automatically fades out Action Bars, Stance/Pet bars, Micro Menu, and Bags. 
* **Intelligent Hover Logic**: Elements become visible only when your cursor is nearby, keeping the screen clean for immersion.
* **Quest Tracker Management**: The Objective Tracker is hidden by default and only shows up when you hover over its designated area.
* **Absorb Display**: Shows your total shield/absorb amount in the center of the screen for easy tracking.
* **CDM Glow Engine**: Custom spell activation highlights (procs) integrated for Cooldown Manager (CDM) and Blizzard bars.
* **Alert Suppression**: Hides annoying talent-related alerts and notifications (Module 4).
* **Zero-Lag Performance**: Optimized event-driven code with a tiny memory footprint.

## How It Works

The addon is divided into five main functional modules:

1.  **Action Bar Module**: Tracks mouse position and combat status. Prevents bars from showing during combat to avoid accidental clicks and tooltip clutter.
2.  **UI Group Module**: Handles the Micro Menu and Bag bar separately to ensure accessibility.
3.  **Objective Tracker Module**: Creates an invisible trigger frame over the quest log area.
4.  **Absorb Display Module**: Monitors your shield amounts and displays them prominently on screen.
5.  **CDM Glow Engine**: Scans your UI for specific Spell IDs and applies a high-visibility "spell alert" animation when a proc is detected.
6.  **Hide Alerts Module**: Suppresses annoying in-game notifications like "You have unspent talent points", "Choose your hero talents", and similar help tips.

## Customization: Adding Spells for Highlighting

The CDM Glow Engine is class-aware. By default, it is configured for Death Knights (Sudden Doom/Death Coil procs). To add your own spells, follow these steps:

1.  Open `Module_CDMGlow.lua`.
2.  Locate the `PROC_CONFIG` table at the top of the file.
3.  Add your class and spell IDs in the following format:

    ```lua
    local PROC_CONFIG = {
        CLASS_NAME = { 
            [Aura_Spell_ID] = { Target_Spell_ID_1, Target_Spell_ID_2 } 
        }
    }
    ```

    * **Aura_Spell_ID**: The ID of the buff (proc) you are tracking.
    * **Target_Spell_ID**: The ID of the spell on your bar that should glow when the buff is active.

4.  Example for a Paladin (Art of War):

    ```lua
    PALADIN = { [59578] = { 879 } } -- 59578 is Art of War, 879 is Exorcism
    ```

## In-Game Settings

Access settings through the game's Interface Options menu (ESC → Options → AddOns → cxUI).

The addon includes the following toggleable options:

### Module 1: Transparency & Auto-hide
- **Action Bar Auto-hide**: Hides action bars out of combat, shows on mouseover
- **Micro Menu Auto-hide**: Hides Micro Menu and Bags, shows on mouseover
- **Quest Tracker Hover**: Quest tracker only visible on mouseover (requires reload)

### Module 2: Absorb Display
- **Enable Absorb Display**: Shows total shield amount in screen center (requires reload)

### Module 3: CDM Glow
- **Enable CDM Proc Glow**: Special highlights for class-specific procs

### Module 4: Hide Alerts
- **Hide Talent Alerts**: Suppresses annoying notifications like "You have unspent talent points", "Choose your hero talents", and other help tips (requires reload)

*Note: Options marked with red asterisk require `/reload` to take effect.*

## Installation

1. Download the latest release.
2. Extract the `cemxokenc` folder into your `World of Warcraft/_retail_/Interface/AddOns/` directory.
3. Restart the game or type `/reload`.

## Commands

- `/cdmglow on` - Enable CDM Glow
- `/cdmglow off` - Disable CDM Glow
- `/cdmglow rescan` - Rescan action bars for tracked spells

## Support

For issues, suggestions, or contributions, please visit the addon's repository or contact cemxokenc.