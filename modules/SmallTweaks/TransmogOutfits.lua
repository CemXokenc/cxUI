local addonName, ns = ...

-- ===========================================================================
-- SMALL TWEAKS: TRANSMOG OUTFITS
-- Ported from the standalone "Transmog Outfits" addon (Vampyr78) into cxUI
-- as a single module. Behaviour changes from the standalone version:
--   * Outfits now live in CXUI_DB (cxUI's own account-wide SavedVariables,
--     see cxUI.toc's `## SavedVariables: CXUI_DB`) instead of a per-
--     character table, so the same list shows up on every character.
--   * The toolbar above the outfit grid was trimmed down to just
--     "Create" (was "Create New") and the "TransmogOutfits" / "Close"
--     toggle button (was "Addon Outfits" / "Close"). Sort, Save Changes,
--     Select Random, and the search box/button are gone.
--   * The grid is rebuilt and sorted A-Z every time the window is opened
--     (no manual sort button anymore).
--   * Buttons are reskinned with a dark backdrop + gold border/text in
--     place of the plain Blizzard button look.
--
-- NOTE on visual theme: this reskins buttons in cxUI's own dark/gold
-- accent style. I don't have EllesmereUI's actual button textures/skin
-- code here (it isn't bundled in what I have access to), so this is an
-- approximation rather than a pixel-perfect match — send over
-- EllesmereUI's button skin file if you want it matched exactly.
-- ===========================================================================

local function IsEnabled()
    return CXUI_DB.transmogOutfits
end

-- ---------------------------------------------------------------------------
-- Storage — account-wide via CXUI_DB
-- ---------------------------------------------------------------------------
local function GetOutfits()
    CXUI_DB.transmogOutfitsList = CXUI_DB.transmogOutfitsList or {}
    return CXUI_DB.transmogOutfitsList
end

-- One-time best-effort import from the old standalone "Transmog Outfits"
-- addon, if it happens to still be enabled/loaded alongside cxUI this
-- session (works whether that addon was using its old per-character
-- storage or the newer account-wide variant). Guarded so it only ever
-- runs once; safe to leave in permanently.
local function ImportFromStandaloneAddon()
    if CXUI_DB.transmogOutfitsImported then return end
    CXUI_DB.transmogOutfitsImported = true
    local legacy = _G.transmogOutfitOutfitsAccount or _G.transmogOutfitOutfits
    if type(legacy) ~= "table" or #legacy == 0 then return end
    local outfits = GetOutfits()
    local imported = 0
    for i = 1, #legacy do
        local old = legacy[i]
        local exists = false
        for j = 1, #outfits do
            if outfits[j]["name"] == old["name"] then
                exists = true
                break
            end
        end
        if not exists then
            table.insert(outfits, old)
            imported = imported + 1
        end
    end
    if imported > 0 then
        print(("|cff0070ddcx|cffffff00UI|r: Imported %d outfit(s) from the standalone Transmog Outfits addon. You can disable/remove that addon now."):format(imported))
    end
end

-- ---------------------------------------------------------------------------
-- Camera translation tables (unchanged from the standalone addon)
-- ---------------------------------------------------------------------------
local MaleTranslate = {["Human"]              = {-0.05, -2.3 ,  1.5 },
                        ["Orc"]                = { 0.05, -3.6 ,  1.5 },
                        ["Dwarf"]              = {-0.07, -2.5 ,  1.1 },
                        ["Scourge"]            = {-0.15, -2.2 ,  1.4 },
                        ["NightElf"]           = {-0.15, -2.8 ,  1.9 },
                        ["Tauren"]             = {-0.12, -4.1 ,  1.9 },
                        ["Gnome"]              = { 0   , -1.5 ,  0.7 },
                        ["Troll"]              = { 0.17, -2.7 ,  1.7 },
                        ["Draenei"]            = {-0.2 , -3.5 ,  1.8 },
                        ["BloodElf"]           = {-0.05, -2.1 ,  1.6 },
                        ["Worgen"]             = { 0.05, -3.5 ,  1.7 },
                        ["Goblin"]             = { 0   , -1.8 ,  0.8 },
                        ["Pandaren"]           = {-0.35, -3.8 ,  1.6 },
                        ["VoidElf"]            = {-0.05, -2.1 ,  1.6 },
                        ["Nightborne"]         = { 0   , -2.8 ,  1.9 },
                        ["LightforgedDraenei"] = {-0.2,  -3.5 ,  1.8 },
                        ["HighmountainTauren"] = {-0.12, -4.1 ,  1.9 },
                        ["DarkIronDwarf"]      = {-0.12, -2.5 ,  1.1 },
                        ["MagharOrc"]          = { 0.05, -3.6 ,  1.5 },
                        ["KulTiran"]           = { 0   , -2.8 ,  2   },
                        ["ZandalariTroll"]     = {-0.05, -2.95,  2.15},
                        ["Mechagnome"]         = {-0.07, -1.6 ,  0.7 },
                        ["Vulpera"]            = {-0.22, -2.1 ,  0.8 },
                        ["Dracthyr"]           = {-0.97, -3.3 ,  2.2 },
                        ["EarthenDwarf"]       = {-0.07, -2.5 ,  1.1 },
                        ["Harronir"]           = {-0.15, -1.9 ,  1.95}}

local FemaleTranslate = {["Human"]              = {-0.05, -1.8 ,  1.5 },
                          ["Orc"]                = {-0.2 , -2.2 ,  1.55},
                          ["Dwarf"]              = {-0.1 , -2   ,  1.07},
                          ["Scourge"]            = { 0.07, -1.8 ,  1.45},
                          ["NightElf"]           = {-0.05, -2.05,  1.85},
                          ["Tauren"]             = {-0.35, -3.3 ,  1.9 },
                          ["Gnome"]              = {-0.22, -1.7 ,  0.65},
                          ["Troll"]              = {-0.12, -2.1 ,  1.9 },
                          ["Draenei"]            = {-0.15, -1.55,  1.9 },
                          ["BloodElf"]           = {-0.05, -1.8 ,  1.5 },
                          ["Worgen"]             = {-0.1 , -2.7 ,  1.8 },
                          ["Goblin"]             = {-0.22, -2   ,  0.87},
                          ["Pandaren"]           = {-0.3 , -3.2 ,  1.6 },
                          ["VoidElf"]            = {-0.05, -1.8 ,  1.5 },
                          ["Nightborne"]         = { 0  ,  -2.05,  1.85},
                          ["LightforgedDraenei"] = {-0.15, -1.8 ,  1.9 },
                          ["HighmountainTauren"] = {-0.35, -3.3 ,  1.9 },
                          ["DarkIronDwarf"]      = {-0.07, -2   ,  1.07},
                          ["MagharOrc"]          = {-0.2 , -2.2 ,  1.55},
                          ["KulTiran"]           = {-0.07, -2.1 ,  2   },
                          ["ZandalariTroll"]     = {-0.25, -2.4 ,  2.3 },
                          ["Mechagnome"]         = {-0.17, -1.6 ,  0.65},
                          ["Vulpera"]            = {-0.22, -2.1 ,  0.85},
                          ["Dracthyr"]           = {-0.97, -3.3 ,  2.2 },
                          ["EarthenDwarf"]       = {-0.1 , -2   ,  1.07},
                          ["Harronir"]           = {-0.05, -1.7 ,  1.8 }}

-- ---------------------------------------------------------------------------
-- Theme: flat text-only buttons — no texture, no border box, no underline.
-- Matches the look of the Wardrobe's own tabs (Items/Sets/Custom Sets/...)
-- instead of a boxed Blizzard button: gold label at rest, white on hover.
-- Width auto-fits the label so nothing gets clipped.
-- ---------------------------------------------------------------------------
local GOLD  = {1, 0.82, 0}
local WHITE = {1, 1, 1}

-- ===========================================================================
-- Module state / frame table — must exist before SetupButton below, since
-- SetupButton's OnClick handler closes over TO as an upvalue. Declaring it
-- any later would make that reference resolve to a (nil) global instead.
-- ===========================================================================
local TO = {
    FoundOutfits = {},
    Select       = false,
    Page         = 1,
    NumPages     = 1,
    CurrentOutfit = 1,
    HookedSlots  = {},
}

local function SetupButton(button, text, minWidth)
    button:SetHeight(20)
    button:SetNormalFontObject("GameFontNormal")
    button:SetHighlightFontObject("GameFontHighlight")
    button:SetText(text)
    local fs = button:GetFontString()
    fs:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    button:SetWidth(math.max(fs:GetStringWidth() + 16, minWidth or 0))
    button:SetScript("OnClick", TO.ButtonOnClick)
    button:HookScript("OnEnter", function(self)
        local t = self:GetFontString()
        if t then t:SetTextColor(WHITE[1], WHITE[2], WHITE[3]) end
    end)
    button:HookScript("OnLeave", function(self)
        local t = self:GetFontString()
        if t then t:SetTextColor(GOLD[1], GOLD[2], GOLD[3]) end
    end)
    button:Show()
end

local function SetupPopupFrame(frame, width, height)
    frame:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background",
                        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                        tile = true,
                        tileSize = 16,
                        edgeSize = 16,
                        insets = {left = 1, right = 1, top = 1, bottom = 1}})
    frame:SetFrameStrata("TOOLTIP")
    frame:SetBackdropColor(0, 0, 0, 1)
    frame:SetWidth(width)
    frame:SetHeight(height)
    frame:Hide()
end

local function SetupEditBox(editBox, width)
    editBox:SetWidth(width)
    editBox:SetHeight(25)
    editBox:ClearAllPoints()
    editBox:Show()
end

local function SetupNameFrame(frame, text)
    frame:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background",
                        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                        tile = true,
                        tileSize = 16,
                        edgeSize = 16,
                        insets = {left = 1, right = 1, top = 1, bottom = 1}})
    frame:SetBackdropColor(0, 0, 0, 1)
    frame:SetWidth(300)
    frame:SetHeight(25)
    text:ClearAllPoints()
    text:SetAllPoints(frame)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
    text:SetText("No Outfit")
    frame:Show()
end

local function SetupModelFrame(frame, bg, text, x, y)
    frame.actor = frame:CreateActor("actor")
    frame:SetWidth(180)
    frame:SetHeight(230)
    frame:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background",
                        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                        tile = true,
                        tileSize = 16,
                        edgeSize = 16,
                        insets = {left = 1, right = 1, top = 1, bottom = 1}})
    frame:SetBackdropColor(0, 0, 0, 1)
    frame:Show()
    frame:SetCameraOrientationByAxisVectors(0, 1, 0, -1, 0, 0, 0, 0, 1)
    frame.actor:SetYaw(-1.5)
    frame.actor:Show()
    frame:SetPoint("CENTER", TO.SelectFrame, "CENTER", x, y)
    frame:EnableMouse(true)
    frame:SetScript("OnMouseDown", TO.ModelFrameOnClick)
    bg:SetWidth(180)
    bg:SetHeight(25)
    bg:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background",
                     edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
                     tile = true,
                     tileSize = 16,
                     edgeSize = 16,
                     insets = {left = 1, right = 1, top = 1, bottom = 1}})
    bg:SetBackdropColor(0, 0, 0, 0.8)
    bg:SetPoint("TOP", frame, "TOP", 0, 0)
    text:ClearAllPoints()
    text:SetPoint("CENTER", bg, "CENTER", 0, 0)
    text:SetJustifyH("CENTER")
    text:SetJustifyV("MIDDLE")
end

local function ModelFrames(parent)
    TO.Models = {}
    TO.ModelsBg = {}
    TO.ModelTexts = {}
    local index
    for i = 1, 3 do
        for j = 1, 3 do
            index = j + (i - 1) * 3
            TO.Models[index] = CreateFrame("ModelScene", tostring(index), parent, BackdropTemplateMixin and "BackdropTemplate")
            TO.ModelsBg[index] = CreateFrame("FRAME", nil, TO.Models[index], BackdropTemplateMixin and "BackdropTemplate")
            TO.ModelTexts[index] = TO.ModelsBg[index]:CreateFontString(nil, "OVERLAY", "GameFontWhite")
            SetupModelFrame(TO.Models[index], TO.ModelsBg[index], TO.ModelTexts[index], -200 + (j - 1) * 200, 260 - (i - 1) * 245)
        end
    end
end

function TO.ModelFrameOnClick(self, button, down)
    local index = TO.FoundOutfits[tonumber(self:GetName()) + 9 * (TO.Page - 1)].index
    if button == "LeftButton" then
        TO:ApplyOutfit(index)
    elseif button == "RightButton" then
        TO.CurrentOutfit = index
        TO:ContextMenu(self)
    end
end

-- ---------------------------------------------------------------------------
-- Outfit application / slot helpers (unchanged game logic)
-- ---------------------------------------------------------------------------
local function WeaponOption(categoryID)
    local spec = GetSpecializationInfo(GetSpecialization())
    if categoryID == 12 or categoryID == 13 or categoryID == 14 or categoryID == 15
        or categoryID == 16 or categoryID == 17 or categoryID == 28 then
        return Enum.TransmogOutfitSlotOption.OneHandedWeapon
    elseif categoryID == 20 or categoryID == 21 or categoryID == 22 or categoryID == 23 or categoryID == 24 then
        if spec == 72 then
            return Enum.TransmogOutfitSlotOption.FuryTwoHandedWeapon
        end
        return Enum.TransmogOutfitSlotOption.TwoHandedWeapon
    elseif categoryID == 25 or categoryID == 26 or categoryID == 27 then
        return Enum.TransmogOutfitSlotOption.RangedWeapon
    elseif categoryID == 19 then
        return Enum.TransmogOutfitSlotOption.OffHand
    elseif categoryID == 18 then
        return Enum.TransmogOutfitSlotOption.Shield
    else
        return 0
    end
end

function TO:GetTransmog(slot, type)
    local option = 0
    if slot == Enum.TransmogOutfitSlot.WeaponMainHand then
        option = TransmogFrame.CharacterPreview:GetSlotFrame(slot, type).slotData.currentWeaponOptionInfo.weaponOption
    elseif slot == Enum.TransmogOutfitSlot.WeaponOffHand then
        option = TransmogFrame.CharacterPreview:GetSlotFrame(Enum.TransmogOutfitSlot.WeaponMainHand, type).slotData.currentWeaponOptionInfo.weaponOption
        if option ~= 2 and option ~= 3 then
            option = TransmogFrame.CharacterPreview:GetSlotFrame(slot, type).slotData.currentWeaponOptionInfo.weaponOption
        end
    end
    local slotinfo = C_TransmogOutfitInfo.GetViewedOutfitSlotInfo(slot, type, option)
    return slotinfo.transmogID
end

function TO:SetTransmog(slot, type, transmog)
    local option = 0
    local display = 1
    local info = C_TransmogCollection.GetSourceInfo(transmog)
    if info == nil then
        return
    end
    if info.isHideVisual then
        display = 3
    end
    if slot == Enum.TransmogOutfitSlot.WeaponMainHand or slot == Enum.TransmogOutfitSlot.WeaponOffHand then
        option = WeaponOption(info.categoryID)
    end
    C_TransmogOutfitInfo.SetPendingTransmog(slot, type, option, transmog, display)
end

local function SetTransmogInfo(model, appearanceID, secondaryAppearanceID, illusionID, slotID)
    if appearanceID == nil then
        return
    end
    local itemTransmogInfo = ItemUtil.CreateItemTransmogInfo(appearanceID, secondaryAppearanceID, illusionID)
    model:SetItemTransmogInfo(itemTransmogInfo, slotID)
end

local function HookSlotScript(slot, type, index)
    if TO.HookedSlots[index] == nil or TO.HookedSlots[index] == false then
        local slotFrame = TransmogFrame.CharacterPreview:GetSlotFrame(slot, type)
        if slotFrame ~= nil then
            slotFrame:HookScript("OnClick", function() TO:WardrobeSlotOnClick() end)
            TO.HookedSlots[index] = true
        else
            TO.HookedSlots[index] = false
        end
    end
end

function TO:ApplyOutfit(index)
    local outfit = GetOutfits()[index]
    if outfit ~= nil then
        C_TransmogOutfitInfo.ClearAllPendingTransmogs()
        self.NameText:SetText(outfit["name"])
        self:SetTransmog(Enum.TransmogOutfitSlot.Head, Enum.TransmogType.Appearance, outfit[1])
        self:SetTransmog(Enum.TransmogOutfitSlot.ShoulderRight, Enum.TransmogType.Appearance, outfit[3])
        if outfit[33] ~= nil then
            self:SetTransmog(Enum.TransmogOutfitSlot.ShoulderLeft, Enum.TransmogType.Appearance, outfit[33])
        end
        self:SetTransmog(Enum.TransmogOutfitSlot.Body, Enum.TransmogType.Appearance, outfit[4])
        self:SetTransmog(Enum.TransmogOutfitSlot.Chest, Enum.TransmogType.Appearance, outfit[5])
        self:SetTransmog(Enum.TransmogOutfitSlot.Waist, Enum.TransmogType.Appearance, outfit[6])
        self:SetTransmog(Enum.TransmogOutfitSlot.Legs, Enum.TransmogType.Appearance, outfit[7])
        self:SetTransmog(Enum.TransmogOutfitSlot.Feet, Enum.TransmogType.Appearance, outfit[8])
        self:SetTransmog(Enum.TransmogOutfitSlot.Wrist, Enum.TransmogType.Appearance, outfit[9])
        self:SetTransmog(Enum.TransmogOutfitSlot.Hand, Enum.TransmogType.Appearance, outfit[10])
        self:SetTransmog(Enum.TransmogOutfitSlot.Back, Enum.TransmogType.Appearance, outfit[15])
        self:SetTransmog(Enum.TransmogOutfitSlot.WeaponMainHand, Enum.TransmogType.Appearance, outfit[16])
        self:SetTransmog(Enum.TransmogOutfitSlot.WeaponOffHand, Enum.TransmogType.Appearance, outfit[17])
        self:SetTransmog(Enum.TransmogOutfitSlot.Tabard, Enum.TransmogType.Appearance, outfit[19])
        self:SetTransmog(Enum.TransmogOutfitSlot.WeaponMainHand, Enum.TransmogType.Illusion, outfit["enchant1"])
        self:SetTransmog(Enum.TransmogOutfitSlot.WeaponOffHand, Enum.TransmogType.Illusion, outfit["enchant2"])
    end
end

-- ---------------------------------------------------------------------------
-- Outfit list management
-- ---------------------------------------------------------------------------
local function FindName(name)
    local outfits = GetOutfits()
    for i = 1, #outfits do
        if outfits[i]["name"] == name then
            return i
        end
    end
    return nil
end

-- Rebuilds TO.FoundOutfits from CXUI_DB's outfit list, always sorted A-Z.
-- Called every time the window is opened, and after any add/rename/remove.
local function RefreshOutfitsList()
    local outfits = GetOutfits()
    TO.FoundOutfits = {}
    for i = 1, #outfits do
        TO.FoundOutfits[i] = { index = i, name = outfits[i]["name"] }
    end
    table.sort(TO.FoundOutfits, function(o1, o2) return string.lower(o1.name) < string.lower(o2.name) end)
    if TO.SelectFrame and TO.SelectFrame:IsVisible() then
        TO.SelectFrame:Hide()
        TO.SelectFrame:Show()
    end
end

function TO:NewOutfit()
    local name = self.NewNameBox:GetText()
    local outfits = GetOutfits()
    self.NewNameBox:SetText("")
    if name ~= "" and FindName(name) == nil then
        local outfit = {}
        self.NameText:SetText(name)
        outfit["name"] = name
        outfit[1] = self:GetTransmog(Enum.TransmogOutfitSlot.Head, Enum.TransmogType.Appearance)
        outfit[3] = self:GetTransmog(Enum.TransmogOutfitSlot.ShoulderRight, Enum.TransmogType.Appearance)
        if TransmogFrame.CharacterPreview:GetSlotFrame(Enum.TransmogOutfitSlot.ShoulderLeft, Enum.TransmogType.Appearance) ~= nil then
            outfit[33] = self:GetTransmog(Enum.TransmogOutfitSlot.ShoulderLeft, Enum.TransmogType.Appearance)
        end
        outfit[4] = self:GetTransmog(Enum.TransmogOutfitSlot.Body, Enum.TransmogType.Appearance)
        outfit[5] = self:GetTransmog(Enum.TransmogOutfitSlot.Chest, Enum.TransmogType.Appearance)
        outfit[6] = self:GetTransmog(Enum.TransmogOutfitSlot.Waist, Enum.TransmogType.Appearance)
        outfit[7] = self:GetTransmog(Enum.TransmogOutfitSlot.Legs, Enum.TransmogType.Appearance)
        outfit[8] = self:GetTransmog(Enum.TransmogOutfitSlot.Feet, Enum.TransmogType.Appearance)
        outfit[9] = self:GetTransmog(Enum.TransmogOutfitSlot.Wrist, Enum.TransmogType.Appearance)
        outfit[10] = self:GetTransmog(Enum.TransmogOutfitSlot.Hand, Enum.TransmogType.Appearance)
        outfit[15] = self:GetTransmog(Enum.TransmogOutfitSlot.Back, Enum.TransmogType.Appearance)
        outfit[16] = self:GetTransmog(Enum.TransmogOutfitSlot.WeaponMainHand, Enum.TransmogType.Appearance)
        outfit[17] = self:GetTransmog(Enum.TransmogOutfitSlot.WeaponOffHand, Enum.TransmogType.Appearance)
        outfit[19] = self:GetTransmog(Enum.TransmogOutfitSlot.Tabard, Enum.TransmogType.Appearance)
        outfit["enchant1"] = self:GetTransmog(Enum.TransmogOutfitSlot.WeaponMainHand, Enum.TransmogType.Illusion)
        outfit["enchant2"] = self:GetTransmog(Enum.TransmogOutfitSlot.WeaponOffHand, Enum.TransmogType.Illusion)
        table.insert(outfits, outfit)
    end
    self.NewFrame:Hide()
    RefreshOutfitsList()
end

function TO:RenameDone()
    local outfits = GetOutfits()
    if self.RenameNameBox:GetText() ~= "" then
        if self.NameText:GetText() == outfits[self.CurrentOutfit]["name"] then
            self.NameText:SetText(self.RenameNameBox:GetText())
        end
        outfits[self.CurrentOutfit]["name"] = self.RenameNameBox:GetText()
        RefreshOutfitsList()
        self.RenameFrame:Hide()
    end
end

function TO:RemoveOutfit()
    local outfits = GetOutfits()
    local name = outfits[self.CurrentOutfit]["name"]
    self.RemoveFrame:Show()
    self.RemoveText:SetText("\n\nDo you really want to remove outfit\nnamed " .. name .. "?")
end

function TO:RemoveYes()
    local outfits = GetOutfits()
    if self.NameText:GetText() == outfits[self.CurrentOutfit]["name"] then
        self.NameText:SetText("No Outfit")
    end
    table.remove(outfits, self.CurrentOutfit)
    RefreshOutfitsList()
    self.RemoveFrame:Hide()
end

-- ---------------------------------------------------------------------------
-- Frame show/hide + events
-- ---------------------------------------------------------------------------
function TO:ContextMenu(parent)
    MenuUtil.CreateContextMenu(parent, function(owner, root)
        root:CreateButton("Rename", function() self.RenameFrame:Show() end)
        root:CreateButton("Remove", function() self:RemoveOutfit() end)
    end)
end

function TO:WardrobeSlotOnClick()
    TO:HideSelectFrame()
end

function TO:ShowSelectFrame()
    RefreshOutfitsList()
    TransmogFrame.WardrobeCollection.TabContent:Hide()
    TransmogFrame.WardrobeCollection.TabHeaders:Hide()
    TO.SelectButton:SetText("Close")
    local _, race = UnitRace("player")
    local sex = UnitSex("player")
    local _, alteredForm = C_PlayerInfo.GetAlternateFormInfo()
    for i = 1, 9 do
        self.Models[i].actor:SetModelByUnit("player", false, true, false, not alteredForm)
        self.Models[i]:SetPaused(true)
        local file = self.Models[i].actor:GetModelFileID()
        if file == 1011653 or file == 1000764 or file == 4220448 then
            race = "Human"
        elseif file == 4395382 then
            race = "BloodElf"
        end
        if file == 1968587 then
            self.Models[i]:SetCameraPosition(-0.2, -3.6, 1.5)
        elseif sex == 2 then
            self.Models[i]:SetCameraPosition(MaleTranslate[race][1], MaleTranslate[race][2], MaleTranslate[race][3])
        elseif sex == 3 then
            self.Models[i]:SetCameraPosition(FemaleTranslate[race][1], FemaleTranslate[race][2], FemaleTranslate[race][3])
        end
    end
    self.SelectFrame:Show()
    self.Select = true
end

function TO:HideSelectFrame()
    self.SelectFrame:Hide()
    self.Select = false
    TransmogFrame.WardrobeCollection.TabContent:Show()
    TransmogFrame.WardrobeCollection.TabHeaders:Show()
    TO.SelectButton:SetText("TransmogOutfits")
end

function TO.ButtonOnClick(self)
    if self == TO.NewButton then
        TO.NewNameBox:SetText("")
        TO.NewFrame:Show()
    elseif self == TO.SelectButton then
        if TO.Select then
            TO:HideSelectFrame()
        else
            TO:ShowSelectFrame()
        end
    elseif self == TO.NewDoneButton then
        TO:NewOutfit()
    elseif self == TO.NewCancelButton then
        TO.NewFrame:Hide()
    elseif self == TO.RemoveYesButton then
        TO:RemoveYes()
    elseif self == TO.RemoveNoButton then
        TO.RemoveFrame:Hide()
    elseif self == TO.PrevPageButton then
        TO:PrevPage()
    elseif self == TO.NextPageButton then
        TO:NextPage()
    elseif self == TO.RenameDoneButton then
        TO:RenameDone()
    elseif self == TO.RenameCancelButton then
        TO.RenameFrame:Hide()
    end
end

function TO:PrevPage()
    if self.Page > 1 then
        self.Page = self.Page - 1
        self.SelectFrame:Hide()
        self.SelectFrame:Show()
    end
end

function TO:NextPage()
    if self.Page < self.NumPages then
        self.Page = self.Page + 1
        self.SelectFrame:Hide()
        self.SelectFrame:Show()
    end
end

function TO:SelectFrameOnShow()
    HookSlotScript(Enum.TransmogOutfitSlot.Head, Enum.TransmogType.Appearance, 1)
    HookSlotScript(Enum.TransmogOutfitSlot.ShoulderRight, Enum.TransmogType.Appearance, 3)
    HookSlotScript(Enum.TransmogOutfitSlot.ShoulderLeft, Enum.TransmogType.Appearance, 33)
    HookSlotScript(Enum.TransmogOutfitSlot.Body, Enum.TransmogType.Appearance, 4)
    HookSlotScript(Enum.TransmogOutfitSlot.Chest, Enum.TransmogType.Appearance, 5)
    HookSlotScript(Enum.TransmogOutfitSlot.Waist, Enum.TransmogType.Appearance, 6)
    HookSlotScript(Enum.TransmogOutfitSlot.Legs, Enum.TransmogType.Appearance, 7)
    HookSlotScript(Enum.TransmogOutfitSlot.Feet, Enum.TransmogType.Appearance, 8)
    HookSlotScript(Enum.TransmogOutfitSlot.Wrist, Enum.TransmogType.Appearance, 9)
    HookSlotScript(Enum.TransmogOutfitSlot.Hand, Enum.TransmogType.Appearance, 10)
    HookSlotScript(Enum.TransmogOutfitSlot.Back, Enum.TransmogType.Appearance, 15)
    HookSlotScript(Enum.TransmogOutfitSlot.WeaponMainHand, Enum.TransmogType.Appearance, 16)
    HookSlotScript(Enum.TransmogOutfitSlot.WeaponOffHand, Enum.TransmogType.Appearance, 17)
    HookSlotScript(Enum.TransmogOutfitSlot.Tabard, Enum.TransmogType.Appearance, 19)
    HookSlotScript(Enum.TransmogOutfitSlot.WeaponMainHand, Enum.TransmogType.Illusion, 16)
    HookSlotScript(Enum.TransmogOutfitSlot.WeaponOffHand, Enum.TransmogType.Illusion, 17)

    TO.NumPages = math.ceil(#TO.FoundOutfits / 9)
    if TO.NumPages <= 0 then
        TO.NumPages = 1
    end
    if TO.Page > TO.NumPages then
        TO.Page = TO.NumPages
    end
    TO.PagesText:SetText("Page " .. TO.Page .. "/" .. TO.NumPages)

    local outfits = GetOutfits()
    for i = 1, 9 do
        TO.Models[i]:Show()
        local outfit = TO.FoundOutfits[i + 9 * (TO.Page - 1)]
        if outfit ~= nil and outfits[outfit.index] then
            local sources = outfits[outfit.index]
            TO.Models[i].actor:Undress()
            SetTransmogInfo(TO.Models[i].actor, sources[1], nil, nil, 1)
            SetTransmogInfo(TO.Models[i].actor, sources[3], sources[33], nil, 3)
            SetTransmogInfo(TO.Models[i].actor, sources[4], nil, nil, 4)
            SetTransmogInfo(TO.Models[i].actor, sources[5], nil, nil, 5)
            SetTransmogInfo(TO.Models[i].actor, sources[6], nil, nil, 6)
            SetTransmogInfo(TO.Models[i].actor, sources[7], nil, nil, 7)
            SetTransmogInfo(TO.Models[i].actor, sources[8], nil, nil, 8)
            SetTransmogInfo(TO.Models[i].actor, sources[9], nil, nil, 9)
            SetTransmogInfo(TO.Models[i].actor, sources[10], nil, nil, 10)
            SetTransmogInfo(TO.Models[i].actor, sources[15], nil, nil, 15)
            SetTransmogInfo(TO.Models[i].actor, sources[16], nil, sources["enchant1"], 16)
            SetTransmogInfo(TO.Models[i].actor, sources[17], nil, sources["enchant2"], 17)
            SetTransmogInfo(TO.Models[i].actor, sources[19], nil, nil, 19)
            TO.ModelTexts[i]:SetText(outfit.name)
        else
            TO.Models[i]:Hide()
        end
    end
end

function TO:FrameCreate()
    RefreshOutfitsList()
    if self.SelectButton == nil then
        self.SelectButton = CreateFrame("BUTTON", nil, TransmogFrame.WardrobeCollection)
        SetupButton(self.SelectButton, "TransmogOutfits")
        self.SelectButton:SetPoint("TOPRIGHT", TransmogFrame.WardrobeCollection, "TOPRIGHT", -10, -8)

        self.SelectFrame = CreateFrame("FRAME", nil, TransmogFrame.WardrobeCollection, TransmogWardrobeCustomSetsMixin and "CollectionsBackgroundTemplate")
        self.SelectFrame:SetScript("OnShow", self.SelectFrameOnShow)
        self.SelectFrame:SetFrameStrata("HIGH")

        self.NameFrame = CreateFrame("FRAME", nil, self.SelectFrame, BackdropTemplateMixin and "BackdropTemplate")
        self.NameText = self.NameFrame:CreateFontString(nil, "OVERLAY", "GameFontWhite")
        self.NameFrame:SetPoint("BOTTOMLEFT", self.SelectFrame, "TOPLEFT", 0, 30)

        self.NewButton = CreateFrame("BUTTON", nil, self.SelectFrame)
        SetupButton(self.NewButton, "Create", 100)
        self.NewButton:SetPoint("BOTTOMLEFT", self.SelectFrame, "TOPLEFT", 0, 0)

        ModelFrames(self.SelectFrame)

        self.Pages = CreateFrame("FRAME", nil, self.SelectFrame, nil)
        self.Pages:SetPoint("BOTTOM", self.SelectFrame, "BOTTOM", 0, 0)
        self.Pages:SetFrameStrata("TOOLTIP")
        self.Pages:SetWidth(150)
        self.Pages:SetHeight(50)
        self.PagesText = self.Pages:CreateFontString(nil, "OVERLAY", "GameFontWhite")
        self.PagesText:ClearAllPoints()
        self.PagesText:SetAllPoints(self.Pages)
        self.PagesText:SetJustifyH("CENTER")
        self.PagesText:SetJustifyV("MIDDLE")
        self.PrevPageButton = CreateFrame("BUTTON", nil, self.Pages)
        SetupButton(self.PrevPageButton, "<", 25)
        self.PrevPageButton:SetPoint("LEFT", self.Pages, "LEFT", 0, 0)
        self.NextPageButton = CreateFrame("BUTTON", nil, self.Pages)
        SetupButton(self.NextPageButton, ">", 25)
        self.NextPageButton:SetPoint("RIGHT", self.Pages, "RIGHT", 0, 0)

        self.SelectFrame:Hide()
    end
    SetupNameFrame(self.NameFrame, self.NameText)
end

local function FrameOnEvent(frame, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 == "cxUI" then
            ImportFromStandaloneAddon()
        elseif arg1 == "Blizzard_Transmog" then
            if IsEnabled() then
                TO:FrameCreate()
            end
            frame:UnregisterEvent("ADDON_LOADED")
        end
    elseif event == "TRANSMOGRIFY_CLOSE" then
        if TO.SelectFrame then
            TO:HideSelectFrame()
            TO.NewFrame:Hide()
        end
    end
end

local eventFrame = CreateFrame("FRAME", nil, UIParent)
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:RegisterEvent("TRANSMOGRIFY_CLOSE")
eventFrame:SetScript("OnEvent", FrameOnEvent)

TO.NewFrame = CreateFrame("FRAME", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate")
SetupPopupFrame(TO.NewFrame, 250, 100)
TO.NewFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
TO.NewNameBox = CreateFrame("EDITBOX", nil, TO.NewFrame, "InputBoxTemplate")
SetupEditBox(TO.NewNameBox, 200)
TO.NewNameBox:SetPoint("CENTER", TO.NewFrame, "CENTER", 0, 25)
TO.NewDoneButton = CreateFrame("BUTTON", nil, TO.NewFrame)
SetupButton(TO.NewDoneButton, "Done", 100)
TO.NewDoneButton:SetPoint("CENTER", TO.NewFrame, "CENTER", -50, -25)
TO.NewCancelButton = CreateFrame("BUTTON", nil, TO.NewFrame)
SetupButton(TO.NewCancelButton, "Cancel", 100)
TO.NewCancelButton:SetPoint("CENTER", TO.NewFrame, "CENTER", 50, -25)

TO.RemoveFrame = CreateFrame("FRAME", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate")
SetupPopupFrame(TO.RemoveFrame, 250, 100)
TO.RemoveFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
TO.RemoveText = TO.RemoveFrame:CreateFontString(nil, "OVERLAY", "GameFontWhite")
TO.RemoveText:ClearAllPoints()
TO.RemoveText:SetAllPoints(TO.RemoveFrame)
TO.RemoveText:SetJustifyH("CENTER")
TO.RemoveText:SetJustifyV("TOP")
TO.RemoveYesButton = CreateFrame("BUTTON", nil, TO.RemoveFrame)
SetupButton(TO.RemoveYesButton, "Yes", 100)
TO.RemoveYesButton:SetPoint("CENTER", TO.RemoveFrame, "CENTER", -55, -25)
TO.RemoveNoButton = CreateFrame("BUTTON", nil, TO.RemoveFrame)
SetupButton(TO.RemoveNoButton, "No", 100)
TO.RemoveNoButton:SetPoint("CENTER", TO.RemoveFrame, "CENTER", 55, -25)

TO.RenameFrame = CreateFrame("FRAME", nil, UIParent, BackdropTemplateMixin and "BackdropTemplate")
SetupPopupFrame(TO.RenameFrame, 250, 100)
TO.RenameFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
TO.RenameNameBox = CreateFrame("EDITBOX", nil, TO.RenameFrame, "InputBoxTemplate")
SetupEditBox(TO.RenameNameBox, 200)
TO.RenameNameBox:SetPoint("CENTER", TO.RenameFrame, "CENTER", 0, 25)
TO.RenameDoneButton = CreateFrame("BUTTON", nil, TO.RenameFrame)
SetupButton(TO.RenameDoneButton, "Done", 100)
TO.RenameDoneButton:SetPoint("CENTER", TO.RenameFrame, "CENTER", -50, -25)
TO.RenameCancelButton = CreateFrame("BUTTON", nil, TO.RenameFrame)
SetupButton(TO.RenameCancelButton, "Cancel", 100)
TO.RenameCancelButton:SetPoint("CENTER", TO.RenameFrame, "CENTER", 50, -25)