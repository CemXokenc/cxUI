# cemxokenc UI Suite

A lightweight, high-performance modular addon for World of Warcraft (Retail) designed to declutter the interface and enhance combat awareness.

## Key Features

* **Dynamic UI Hiding**: Automatically fades out Action Bars, Stance/Pet bars, Micro Menu, and Bags. 
* **Intelligent Hover Logic**: Elements become visible only when your cursor is nearby, keeping the screen clean for immersion.
* **Quest Tracker Management**: The Objective Tracker is hidden by default and only shows up when you hover over its designated area.
* **CDM Glow Engine**: Custom spell activation highlights (procs) integrated for Cooldown Manager (CDM) and Blizzard bars.
* **Zero-Lag Performance**: Optimized event-driven code with a tiny memory footprint.

## How It Works

The addon is divided into four main functional modules:
1.  **Action Bar Module**: Tracks mouse position and combat status. Prevents bars from showing during combat to avoid accidental clicks and tooltip clutter.
2.  **UI Group Module**: Handles the Micro Menu and Bag bar separately to ensure accessibility.
3.  **Objective Tracker Module**: Creates an invisible trigger frame over the quest log area.
4.  **Glow Engine**: Scans your UI for specific Spell IDs and applies a high-visibility "spell alert" animation when a proc is detected.

## Customization: Adding Spells for Highlighting

The CDM Glow Engine is class-aware. By default, it is configured for Death Knights (Sudden Doom/Death Coil procs). To add your own spells, follow these steps:

1.  Open `cxUI.lua`.
2.  Locate the `PROC_CONFIG` table at the top of **Module 4**.
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

## Installation
1. Download the latest release.
2. Extract the `cemxokenc` folder into your `World of Warcraft/_retail_/Interface/AddOns/` directory.
3. Restart the game or type `/reload`.
