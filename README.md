<div align="center">

# cxUI

**Minimalist interface addon for World of Warcraft**

</div>

---

## Installation

1. Extract the `cxUI` folder into `World of Warcraft\_retail_\Interface\AddOns\`
2. Restart the game or `/reload`
3. Configure via **ESC → Options → AddOns → cxUI**

---

## Settings window

* **Home page** — the title and one large button per module (module name in blue, description in yellow).
* **Module page** — module list on the left, that module's options on the right. Every option is two rows:
  `[x] Name` and a short description under it. Hover an option for a longer explanation when it has one.
* Options marked **(Requires Reload)\*** only take full effect after `/reload`. Everything else applies immediately.

### Choosing sounds

Features that play a single sound (Ready Check, Group Invite, Queue Pop, Low Health, Potion Reminder, External Cooldown, Dispellable Debuff,
Execute Alert) have **Play** and **Change** buttons on the name line. *Play* previews the current sound; *Change* opens a list
of every available sound with a search box. Each row has **Play** and **Set**; the first row restores the shipped default.
The list contains cxUI's own sounds, everything registered in SharedMedia (if installed) and Blizzard's built-in sound kits
(Dispellable Debuff Alert only accepts files, so kits are not offered there). Choices are stored in `CXUI_DB.soundChoices`.

To make a feature's sound selectable, give it a default: `M:NewFeature{ ..., sound = { kind = "file", value = ns.Media("Folder", "Feature.ogg"), name = "..." } }`
and call `F:PlaySound()` where the sound should play.

### Premium (random sounds)

Execute Alert and Low Health Sound can play a **random** sound instead of always the same one.
It is a hidden switch: `/cx premium` toggles it (the chat says `ON` and lists the registered files, or `OFF`).

* While it is **on**, the sound picker of those two features gets a **Premium** button (left of *Close*).
  It opens a small window with one checkbox per registered Premium file (each with a **Play** button).
  The files are the same for both features, but the ticks are stored **per feature**.
* The feature's pool is *the sound it currently has* (your choice, or the shipped default) **plus** the ticked files.
  Each play picks one at random, never the same one twice in a row; a file that fails to play is skipped.
  With nothing ticked the pool is just that one sound, so nothing changes.
* Turning Premium **off** only stops the randomness. The ticks stay in `CXUI_DB.premiumPicks` and come back
  when it is turned on again.
* The main sound list is unchanged: Premium files are only offered in the Premium window.

To add a Premium sound: drop the `.ogg` into `media/Premium/` and add its file name as one more line in
`modules/PremiumSounds.lua` (WoW cannot list a folder, so files are registered by hand).
To let another feature use it, add `premium = true` to that feature's `sound` table.

The window is generated from the module registry — adding a module or feature never requires touching `options.lua`.

---

## Structure

```
cxUI/
├── cxUI.toc
├── core.lua                 # SavedVariables defaults + startup
├── options.lua              # settings window (built from the registry)
├── media/                   # one sub-folder per feature that owns files, files named after the feature (.ogg)
│   ├── CDMGlow/             #   pixel-glow textures
│   ├── DispelAlert/DispelAlert.ogg
│   ├── ExecuteAlert/ExecuteAlert.ogg
│   ├── ExternalAlert/ExternalAlert.ogg
│   ├── LowHealthSound/LowHealthSound.ogg
│   └── Premium/             #   extra sounds for the Premium random pools (registered in PremiumSounds.lua)
└── modules/
    ├── Modules.lua          # module registry + feature lifecycle (shared by all modules)
    ├── PremiumSounds.lua    # hand-edited list of the files in media/Premium/
    ├── <Module>/
    │   ├── <Module>.lua     # registers the module + helpers shared by its features
    │   └── <Feature>.lua    # exactly one file per feature
    └── ...
```

Load order in `cxUI.toc` matters in one place: **CDM before ClassFeatures** (ClassFeatures uses the CDM glow engine).
Media paths are built with `ns.Media("Folder", "file.ogg")`.

---

## How features work (the lifecycle)

Every option is a *feature* object registered in its module:

```lua
local M = ns:GetModule("Sounds")

local F = M:NewFeature{
    key  = "myOption",              -- CXUI_DB key (also the default = true)
    name = "My Option",
    desc = "One short line shown under the checkbox.",
    -- default = false,             -- start disabled
    -- reload = true,               -- only (de)activated at login
    -- class  = "WARRIOR",          -- only ever runs on this class
}

function F:OnEnable()
    local ev = self:NewEventFrame()                 -- events/OnUpdate are removed automatically on disable
    ev:RegisterEvent("READY_CHECK")
    ev:SetScript("OnEvent", function() ... end)

    self:NewTicker(1, function() ... end)           -- timers are cancelled automatically on disable
    self:After(2, function() ... end)
    self:Hook("SomeBlizzardFunc", function() ... end)          -- installed once, inert while the option is off
    self:HookScript(SomeFrame, "OnShow", function() ... end)
end

function F:OnDisable()
    -- undo anything *visible* (hide frames, restore alpha/anchors, remove engine-side registrations)
end
```

**Guarantee:** an option that is off has no events, no timers and no `OnUpdate` scripts. Blizzard hooks (`hooksecurefunc`)
cannot be removed, so they are installed only if the option has been on at some point in the session, and return
immediately while it is off. Use `F:IsOn()` in any callback you write yourself.

`(Requires Reload)` features are only activated at login (their code does nothing at all if the option is off then).

---

## Modules

### 1. Transparency — `modules/Transparency/`

Auto-hide action bars, micro menu and quest tracker.  
Shared file: `Transparency.lua`

| File | Option | What it does | Reload |
|---|---|---|---|
| `ActionBars.lua` | Action Bar Auto-hide | Hides bars out of combat. Hover to reveal. | — |
| `MicroMenu.lua` | Micro Menu Auto-hide | Hides Micro Menu and Bags. Hover to reveal. | — |
| `QuestTracker.lua` | Quest Tracker Hover | Quest tracker only visible on mouseover. | — |

### 2. CDM — `modules/CDM/`

Glow effects for Cooldown Manager icons.  
Shared file: `CDM.lua`

| File | Option | What it does | Reload |
|---|---|---|---|
| `CDMGlow.lua` | Enable CDM Proc Glow | Special highlights for class-specific procs. | — |
| `SuppressBlizzardGlow.lua` | Suppress Blizzard Glow on CDM | Hides all Blizzard proc glows on CDM frames. Action bars unaffected. | — |

### 3. Class Features — `modules/ClassFeatures/`

Class-specific overlays and alerts. Each class is its own submenu in the settings window.  
Shared file: `ClassFeatures.lua`

| File | Option | What it does | Reload |
|---|---|---|---|
| `BlightfallSwap.lua` | Blightfall Swap — Unholy DK | Swaps the Dark Transformation CDM icon to Blightfall + glow, starting 13s after Dark Transformation is cast, until you cast Blightfall. | — |
| `BurningRushReminder.lua` | Burning Rush Reminder — Warlock | Pulsing on-screen alert while Burning Rush is active. | — |
| `ExecuteAlert.lua` | Execute Alert — Warrior | Sound + on-screen 'EXECUTE!' when your target enters execute range. Supports Premium random sounds. | — |
| `FesteringGlow.lua` | Festering Strike Glow — Unholy DK | White glow on Festering Strike when the buff has <5s left. | — |
| `FlurryCross.lua` | Flurry Cross — Frost Mage | Red x on Flurry CDM after Flurry is cast, until Ice Lance or 6s pass. | — |
| `FrostBarSwap.lua` | Swap ST/AOE — Frost DK | Swaps Obliterate/Frostscythe icons on the CDM when the action bar page changes. | — |
| `PutrefyCross.lua` | Putrefy Cross — Unholy DK | Red x on Putrefy CDM when Dark Transformation has <9s CD. | — |
| `ReaperCross.lua` | Reaper Cross — Unholy DK | Red x on Reaper CDM for 6s right after Dark Transformation is cast. | — |

### 4. Combat — `modules/Combat/`

Absorb, enemy counter, movement alert, input safety, resurrection.  
Shared file: `Combat.lua`

| File | Option | What it does | Reload |
|---|---|---|---|
| `AbsorbDisplay.lua` | Enable Absorb Display | Shows total shield amount in screen center. | — |
| `EnemyCounter.lua` | Enemy Counter | Shows nearby enemy count in the center of the screen. Works for all classes. | — |
| `NoMovement.lua` | No Movement | Shows movement ability cooldown when unavailable. Works for all classes. | — |
| `AutoAcceptResurrection.lua` | Auto-Accept Resurrection | Automatically accepts resurrection requests, but not while the resurrecting unit is in combat. | — |
| `AutoReleasePvP.lua` | Auto-Release in PvP | Automatically releases your spirit in battlegrounds and supported world PvP zones, unless you can self-resurrect. | — |
| `BlockRightClick.lua` | Block Right-Click in Combat | Prevents accidental right-click targeting in dungeons and raids. | — |
| `BlockSpaceCast.lua` | Block Space Bar During Cast | Disables the Space bar while casting to prevent accidental jumps. | — |

### 5. Interface — `modules/Interface/`

Blizzard UI cleanup and behaviour tweaks.  
Shared file: `Interface.lua`

| File | Option | What it does | Reload |
|---|---|---|---|
| `HideDurabilityMount.lua` | Hide Durability & Mount Seats | Hides the durability figure and the seat indicator shown on mounts that can carry passengers. | — |
| `HideExtraActionDecor.lua` | Hide Extra Action Button Decor | Removes the decorative ring texture from ExtraActionButton1 and ZoneAbilityFrame. | — |
| `HideHelpTips.lua` | Hide Talent Alerts | Hides annoying talent-related notifications. | — |
| `MacroOverride.lua` | Macro Window Override | Opens the cxUI macro window (module 10) instead of Blizzard's when you press the 'Macros' menu button. Only active while Macro Manager is managing macros. | — |
| `NoAutoClose.lua` | No Auto Close | Opening a panel (map, bags, character...) no longer closes other open panels. ESC still closes them properly. | yes |
| `TransmogOutfits.lua` | Transmog Outfits (Account-Wide) | Adds a 'TransmogOutfits' button to the Wardrobe that saves outfits shared by every character. | yes |

### 6. Sounds — `modules/Sounds/`

Audio alerts for ready checks, invites, queues and pulls.  
Shared file: `Sounds.lua`

| File | Option | What it does | Reload |
|---|---|---|---|
| `GroupInviteSound.lua` | Group Invite Sound | Plays a sound through Master when a group invite arrives. | — |
| `LowHealthSound.lua` | Low Health Sound Alert | Plays a custom sound when your health is low. Supports Premium random sounds. | — |
| `PotionReminder.lua` | Potion Reminder | Plays a sound and flashes 'POTION READY' when your potion is ready again. Raids and active M+ keys only; silent for 5 s after a resurrection, encounter end or key start. | — |
| `PullTimerSound.lua` | Pull Timer Countdown Sound | Plays audio for the preparation countdown (10, 5, 4, 3, 2, 1). | — |
| `QueuePopSound.lua` | Queue Pop Sound | Plays a sound the moment a dungeon/raid, battleground, or arena queue pops. | — |
| `ReadyCheckSound.lua` | Ready Check Alert | Plays ready check sound through Master channel. Audible when alt-tabbed. | — |

### 7. Group Finder — `modules/GroupFinder/`

Dungeon Finder filters and layout.  
Shared file: `GroupFinder.lua`

| File | Option | What it does | Reload |
|---|---|---|---|
| `ApplicantSort.lua` | Sort Applicants by M+ Rating | Sorts the pending applicants to your Mythic+ listing by: highest key timed on the listed dungeon, then overall M+ rating, then item level (a group application is ranked by its leader). Raid / non-dungeon listings keep Blizzard's order. | — |
| `DungeonFilter.lua` | Dungeon Finder: Advanced Filters | Adds party-fit, Bloodlust/Battle Res and same-spec filters to the Dungeon Finder search list. | yes |
| `MoveResetButton.lua` | Move 'Reset Filter' Button | Shifts the Dungeon Browser's 'Reset Filter' button to the left side to avoid overlap. | — |

**Applicant sort and EllesmereUI Group Finder.** The sort reorders Blizzard's applicant list. EllesmereUI's Group Finder (9.x) draws its own list ordered by `displayOrderID`, so while that list is shown the sort has no visible effect (it works with Ellesmere's Group Finder off). cxUI exposes `CXUI_SortApplicantList(list)` for addons that want to use it; EllesmereUI does not call it. `/cxsort debug` prints what was sorted.

### 8. Vendor & Mail — `modules/VendorMail/`

Vendor window, purchases and mailbox helpers.  
Shared file: `VendorMail.lua`

| File | Option | What it does | Reload |
|---|---|---|---|
| `AutoConfirm.lua` | Auto Confirm Purchases & Mail Warnings | Automatically accepts the 'confirm purchase' and 'non-refundable' (mail) popups. | — |
| `BuyEmAll.lua` | Buy Em All | Shift-Click a vendor item to open a Max/Stack purchase window instead of Blizzard's default popup. | — |
| `ExpandVendorWindow.lua` | Expand Vendor Window (5x10 Grid) | Shows 5 columns x 10 rows of items on vendors instead of Blizzard's default 2x5. | yes |
| `FavoriteContacts.lua` | Favorite Contacts (Mailbox) | Adds a panel of favorite recipients next to the mailbox. Click one to fill in 'To'. | — |
| `RememberRecipient.lua` | Mail: Remember Last Recipient | Keeps the last recipient in the mailbox 'To' field after sending until the mailbox is closed. | — |

### 9. Mythic+ — `modules/MythicPlus/`

Alerts, teleports and timer add-ons for dungeons.  
Shared file: `MythicPlus.lua`

| File | Option | What it does | Reload |
|---|---|---|---|
| `BossTimerPreview.lua` | Boss PB Preview (EllesmereUI M+ Timer) | Shows your best split for each upcoming boss in EllesmereUIMythicTimer. Needs EllesmereUI. | — |
| `DispelAlert.lua` | Dispellable Debuff Alert | Plays a sound when a party member gets a debuff your spec can dispel. Dungeons only. | — |
| `ESCTeleports.lua` | ESC Menu Dungeon Teleports | Adds clickable dungeon-teleport buttons for the current M+ season next to the Game Menu (ESC). | — |
| `ExternalAlert.lua` | External Cooldown Alert | Plays a sound whenever an external defensive (Pain Suppression, Guardian Spirit, etc.) is cast on you. | — |

### 10. Macros — `modules/Macros/`

A replacement for Mega Macro. The macros live in cxUI's own SavedVariable (`CXUI_MacroDB`), grouped by *scope*; the ones that belong to the character you are playing are copied into the game's native macro slots. Open the window with `/cxm` (or `/m`).

**How it works.** Every macro has an id, and each id owns at most one native macro slot, recognised by a `#NNN` tag on its first line. A slot is never deleted when its macro goes away (it is blanked), so a button on your action bar keeps pointing at the same slot while the *content* changes with your spec. Ids are the same as Mega Macro's, so existing tags keep working.

| Scope | Slots | Ids | Written to native slots when |
|---|---|---|---|
| General | 60 | 1–60 | always (account-wide space) |
| Class | 30 | 61–90 | you play that class |
| Spec | 30 | 91–120 | you play that spec |
| Character | 30 | 121–150 | you are that character (per-character space) |
| Archive | 60 | — | never: storage only |

Class / spec keys are `classFile` / `specID` (not localised names) and characters are stored by GUID, so changing the client language loses nothing.

**The window**

* Scope tabs along the top; the *Class* and *Spec* tabs add a class icon strip, the *Spec* tab a spec strip, the *Character* tab a list of your characters. Your own class / spec / character is marked. Everything can be browsed and edited, but only what belongs to the character you are playing is also written to the native slots (the header says `active` / `not active (editing only)` / `storage only`).
* Slot grid on the left (8 columns). Click a slot to edit it; drag an *active* slot onto an action bar. Hover shows the macro text.
* Editor on the right: icon (click to open the icon picker), name (up to 32 characters; the native slot gets the first 18), macro text with a live character counter. Macros are limited to **250 characters** (255 minus the `#NNN` tag).
* **Save** / **Revert** / **Delete** (asks "Sure?" first) / **Copy** / **Cut** / **Paste**. Copy / Cut / Paste move macros between any scope, class or spec. Unsaved edits are saved automatically when you switch slot or tab, or close the window.
* Syntax colouring for `#showtooltip`, commands, `[conditions]`, `@units`, spells, chat and Lua lines. It is purely visual: the real (almost transparent) edit box sits on top of a coloured copy, and the window draws its own caret. If the editor ever misbehaves (caret, click-to-place, arrow keys), `/cxm plain` switches to a normal uncoloured edit box.
* Icon picker: searches spell names (indexed in the background the first time it is opened), spell IDs and file IDs. "Automatic" keeps the `?` icon so `#showtooltip` shows the real one.
* Footer buttons appear only when useful: **Import Mega Macro** (when Mega Macro's data is present) and **Adopt N native** (when there are native macros without a tag).
* Everything that touches native macros is blocked in combat, so it is queued and replayed when combat ends (the status line says so).

**Files** (load order matters, see `cxUI.toc`)

| File | Purpose |
|---|---|
| `Macros.lua` | module registration + constants (scopes, limits, ids) |
| `Store.lua` | `CXUI_MacroDB` access, class / spec / character helpers |
| `Slots.lua` | native slot engine: scan, create, edit, sync, release; combat queue |
| `Highlight.lua` | macro syntax colouring |
| `Icons.lua` | icon lists + spell-name index for the icon search |
| `UI.lua` | small flat widgets in the cxUI look (button, box, edit box, slider) |
| `IconPicker.lua` | icon picker window |
| `Import.lua` | Mega Macro import + adopting untagged native macros |
| `Window.lua` | the macro window (scope tabs, strips, grid, editor) |
| `MacroManager.lua` | the feature: events (login, spec change, leaving combat) + slash commands |

| File | Option | What it does | Reload |
|---|---|---|---|
| `MacroManager.lua` | Macro Manager | Writes the macros of your character / class / spec into the native macro slots and swaps them when you change spec. Needs Mega Macro disabled. With it off you can still browse and edit, but nothing is written to the game's slots. | — |
| `Interface/MacroOverride.lua` | Macro Window Override | Opens this window instead of Blizzard's when you press the *Macros* button of the game menu. Only while Macro Manager is managing macros. | — |

**Commands**

```
/cxm  (or /m)     open / close the window
/cxm import       copy Mega Macro's data into cxUI (Mega Macro must be enabled for this session)
/cxm adopt        take over native macros that have no #NNN tag (they go to General / Character)
/cxm sync         rewrite the native slots from the database
/cxm release      strip the cxUI tags from the native macros (turn Macro Manager off before reloading)
/cxm plain        toggle the plain-text editor (no colouring, normal caret)
```

**Migrating from Mega Macro:** enable it for one session, run `/cxm import` on each character (nothing in Mega Macro is changed, identical macros are skipped, macros that had no `#show...` get `#showtooltip` as Mega Macro did), then disable Mega Macro and `/reload`. cxUI stays idle while Mega Macro is loaded; the red banner in the window says so.

### 11. EllesmereUI Skins — `modules/EllesmereSkins/`

Gives other addons the EllesmereUI look through EllesmereUI's official skinning API (`EllesmereUI.RegisterSkin`, documented in `SKINNING_API.md` in the EllesmereUI folder) and fixes bugs that stop those addons from working. Needs EllesmereUI and EllesmereUI Blizzard Skin+; without them every option here does nothing. Skins can't be removed live, so every option needs a reload.

A skin checkbox registers the skin for its addon **and** applies the fixes that addon needs. The master **Fix addon issues** applies every fix whether or not the addon has a skin ticked. All fixes are idempotent and step aside when not needed.

Remove the old skin packs (EUIAddonSkins, EllesmereUI_AddonSkins, EllesmereSkin_WIM, Rematch_EllesmereUI_Skin): EllesmereUI keeps the *first* skin registered under a name, so they would win over this module.

Shared files: `EllesmereSkins.lua` (module + helpers in `ns.ESkin`), `Compat.lua` (the named fixes).

| File | Option | What it does | Reload |
|---|---|---|---|
| `FixAddonIssues.lua` | Fix addon issues | Restores `MouseIsOver` and `GetItemInfoInstant` (removed in 12.1: Rematch, CollectionLog, M33kAuras options, BtWQuests) and rescues Rematch's window from NPC names hidden inside instances. | yes |
| `Skins/ArenaAnalytics.lua` | ArenaAnalytics | Stock widgets in the history window; the import dialog as a house window. | yes |
| `Skins/Auctionator.lua` | Auctionator | Auction House tabs, dialogs, lists, option widgets. | yes |
| `Skins/BetterWardrobe.lua` | BetterWardrobe | Stock widgets in its collection list and popups (not the Blizzard journal itself). | yes |
| `Skins/BtWQuests.lua` | BtWQuests | Quest Journal window border and plate, expansion cards and View All / Load AddOn buttons. | yes |
| `Skins/BugSack.lua` | BugSack | Sack window, tabs, options. | yes |
| `Skins/CollectionLog.lua` | Collection Log | Stock widgets only (buttons, checkboxes, edit boxes, dropdowns, scroll bars); also applies the `GetItemInfoInstant` fix. | yes |
| `Skins/CooldownManagerProfiles.lua` | CooldownManagerProfiles | Stock widgets in the profile manager. | yes |
| `Skins/HomeBound.lua` | HomeBound | Main window, popups, tooltips and previews, plus the stock widgets inside. (Its settings window is a page of the Blizzard AddOns tab and is not touched.) | yes |
| `Skins/PetTracker.lua` | PetTracker | The "Pets" header and progress bar in the objective tracker (header styled by EllesmereUI's tracker skin). | yes |
| `Skins/RareScanner.lua` | RareScanner | The found-something popup and the explorer window. | yes |
| `Skins/RCLootCouncil.lua` | RCLootCouncil | Buttons only: every button made by `RCLootCouncil:CreateButton`. | yes |
| `Skins/Rematch.lua` | Rematch | The full window skin from Rematch_EllesmereUI_Skin (vendored), plus the `MouseIsOver` and hidden-NPC-name fixes, and hides PetTracker's Rivals tab (it collides with Rematch's journal). Needs `Rematch` loaded before cxUI (OptionalDeps). | yes |
| `Skins/SimpleAddonManager.lua` | SimpleAddonManager | Window, search, buttons, addon and category lists. | yes |
| `Skins/Simulationcraft.lua` | SimulationCraft | Export window. | yes |
| `Skins/TargetedSpells.lua` | TargetedSpells | The Designer window and its stock widgets. | yes |
| `Skins/TomTom.lua` | TomTom | The waypoint paste window. | yes |
| `Skins/WIM.lua` | WIM | WIM's "EllesmereUI" skin from EllesmereSkin_WIM (vendored; pick it in WIM as before, /wim -> Skin), and the History Viewer: the skins get a `history_viewer` section (WIM 3.19 draws the viewer from it) and the window is skinned through EllesmereUI when it opens. | yes |

Vendored code (`Vendor/`): the WIM and Rematch skins are the files of the EllesmereSkin_WIM and Rematch_EllesmereUI_Skin addons, kept as their authors wrote them and wrapped in a function so they can run after WIM / Rematch have loaded. Rematch_EllesmereUI_Skin is GPL-3.0 (its `LICENSE` file travels with the project it came from); EllesmereSkin_WIM ships no license file. Keep that in mind before sharing this module.

**Scope: separate windows only.** Nothing on the pages of the Blizzard options window (Game Menu > Options > AddOns) is skinned, whatever addon it belongs to: partial skinning there (some widgets flat, Blizzard's own buttons and sliders stock) looks worse than none. What is skinned is every addon's own windows, popups and panels, and, where an addon shares widgets between its own window and its options page (Auctionator), only the instances in its own window.

Diagnostics: `/esk mouse` prints what the frame under the mouse is (its type, which stock-template parts it has, its normal texture) and what this module would do with it Widgets that are not skinned are almost always not stock ones (custom art, sliders, Ace checkboxes); `/esk mouse` says which.

Adding an addon: create `Skins/<Addon>.lua` with `Sk.NewSkin{ addon = "<FolderName>", fixes = { "<FixId>" }, apply = function(S) ... end }` (`Sk = ns.ESkin`), add it to `cxUI.toc`, and add a row above. A new fix is `Sk.DefineFix(id, text, fn)` in `Compat.lua`.

---

---

## Commands

```
/cdmglow test | testoff | debug | diag     CDM glow engine / CDM frames
/cxaoe scan | status | debug               Death Knight CDM overlays
/cxmage scan | force                       Flurry cross
/cxwarlock show | hide | status            Burning Rush reminder
/cxexternal debug | scan | status          External cooldown alert
/cxdispel debug | status                   Dispellable debuff alert
/cxautoconfirm debug | status              Auto confirm
/cxpotion [item <id|link|auto> | test | debug]  Potion reminder status / pin item
/cx premium                                Toggle the Premium random sounds (Execute Alert, Low Health)
/cxm [import | adopt | sync | release | plain]  Macro window / copy Mega Macro data / take over native macros / rewrite slots / strip tags / plain-text editor
/cxsort [debug]                            Applicant sort status / debug output
/esk mouse                                What is under the mouse and how EllesmereUI Skins treats it
```

## Customising

* **CDM proc glow spells** — edit `PROC_CONFIG` in `modules/CDM/CDMGlow.lua`.
* **ESC teleport list** — edit `DUNGEONS` in `modules/MythicPlus/ESCTeleports.lua` each season.
* **Dispel spell-ID list** — `SPELLS_BY_TYPE` in `modules/MythicPlus/DispelAlert.lua`.
* **Premium sounds** — put the `.ogg` in `media/Premium/` and add its file name to `modules/PremiumSounds.lua`.

---

## License

Open source under the MIT License.