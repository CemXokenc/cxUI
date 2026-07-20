local addonName, ns = ...

-- ===========================================================================
-- CLASS FEATURES: SHARED UTILITIES
-- Loaded first. Exports helpers to ns.CF for DeathKnight.lua and Mage.lua.
-- ===========================================================================

local _, _, CLASS_ID = UnitClass("player")

ns.CF = { CLASS_ID = CLASS_ID }
local CF = ns.CF

-- ===========================================================================
-- NO MOVEMENT TRACKER (all classes)
-- Shows "NO <SPELL> (X.Xs)" when the class movement ability is on cooldown.
-- ===========================================================================

local TRACKER_X         =  0
local TRACKER_Y         =  100
local TRACKER_FONT_SIZE =  16
local TRACKER_R, TRACKER_G, TRACKER_B = 1, 1, 1

local MOVEMENT_ABILITIES = {
    DEATHKNIGHT = {48265},                   -- death's advance
    DEMONHUNTER = {195072, 189110, 1234796}, -- fel rush, infernal strike, shift
    DRUID       = {252216, 102401},          -- tiger dash, wild charge
    EVOKER      = {358267},                  -- hover
    HUNTER      = {781},                     -- disengage
    MAGE        = {212653, 1953},            -- shimmer, blink
    MONK        = {109132, 115008},          -- roll, chi torpedo
    PALADIN     = {190784},                  -- divine steed
    PRIEST      = {121536},                  -- angelic feather
    ROGUE       = {36554, 195457},           -- shadowstep, grappling hook
    SHAMAN      = {192063},                  -- gust of wind
    WARLOCK     = {48020},                   -- demonic circle teleport
    WARRIOR     = {100, 6544},               -- heroic leap, charge
}

local NAME_OVERRIDES = {
    [48265]  = "DA",       [195072] = "rush",    [189110] = "leap",
    [252216] = "dash",     [102401] = "charge",  [115008] = "torpedo",
    [190784] = "steed",    [121536] = "feather", [36554]  = "step",
    [195457] = "grapple",  [192063] = "gust",    [48020]  = "circle",
    [6544]   = "leap"
}

local MOVEMENT_SPELL_ID   = nil
local MOVEMENT_SPELL_NAME = nil

-- Time Spiral (Evoker) grants everyone nearby a free use of their movement
-- ability, even on cooldown. The game signals this itself by glowing the
-- ability's own action button (SPELL_ACTIVATION_OVERLAY_GLOW_SHOW/HIDE) --
-- same detection MovementAlertDisplay.lua uses (IsValidTimeSpiralProc), just
-- matched against our single MOVEMENT_SPELL_ID instead of a spec list. Not
-- restricted to the evoker's own class in any way -- this fires on whichever
-- class receives the glow, i.e. whoever Time Spiral just affected.
local FREE_MOVEMENT_DURATION = 10
local freeMovementUntil = nil
local glowProcDebounce = 0

local function IsFreeMovementGlow(spellId)
    if not spellId or not MOVEMENT_SPELL_ID then return false end
    if spellId == MOVEMENT_SPELL_ID then return true end
    if C_Spell.GetOverrideSpell then
        local ok, overrideId = pcall(C_Spell.GetOverrideSpell, MOVEMENT_SPELL_ID)
        if ok and overrideId and overrideId == spellId then return true end
    end
    return false
end

local movementText = UIParent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
do
    local fontName = movementText:GetFont()
    movementText:SetFont(fontName, TRACKER_FONT_SIZE, "OUTLINE")
end
movementText:SetTextColor(TRACKER_R, TRACKER_G, TRACKER_B, 1)
movementText:SetShadowColor(0, 0, 0, 0)
movementText:SetPoint("CENTER", UIParent, "CENTER", TRACKER_X, TRACKER_Y)
movementText:SetJustifyH("CENTER")
movementText:Hide()

local freeMovementText = UIParent:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
do
    local fontName = freeMovementText:GetFont()
    freeMovementText:SetFont(fontName, TRACKER_FONT_SIZE, "OUTLINE")
end
freeMovementText:SetTextColor(1, 0.82, 0, 1) -- gold, to stand out from the "No X" line
freeMovementText:SetShadowColor(0, 0, 0, 0)
freeMovementText:SetPoint("BOTTOM", movementText, "TOP", 0, 4)
freeMovementText:SetJustifyH("CENTER")
freeMovementText:Hide()

local function CacheMovementSpell()
    MOVEMENT_SPELL_ID   = nil
    MOVEMENT_SPELL_NAME = nil
    local _, playerClass = UnitClass("player")
    local abilities = MOVEMENT_ABILITIES[playerClass]
    if not abilities then return end
    for _, spellID in ipairs(abilities) do
        if C_SpellBook.IsSpellKnown(spellID) then
            MOVEMENT_SPELL_ID = spellID
            MOVEMENT_SPELL_NAME = NAME_OVERRIDES[spellID]
                or (function()
                    local info = C_Spell.GetSpellInfo(spellID)
                    return info and string.lower(info.name) or "movement"
                end)()
            return
        end
    end
end

local function UpdateMovementAlert()
    if not CXUI_DB or not CXUI_DB.noMovement or not MOVEMENT_SPELL_ID then
        movementText:Hide()
        freeMovementText:Hide()
        return
    end
    local cdInfo = C_Spell.GetSpellCooldown(MOVEMENT_SPELL_ID)
    if cdInfo and cdInfo.timeUntilEndOfStartRecovery
       and not cdInfo.isOnGCD and cdInfo.isOnGCD ~= nil then
        movementText:SetText(string.format(
            "No %s %.1f", MOVEMENT_SPELL_NAME, cdInfo.timeUntilEndOfStartRecovery))
        movementText:Show()
    else
        movementText:Hide()
    end

    if freeMovementUntil then
        local remaining = freeMovementUntil - GetTime()
        if remaining > 0 then
            freeMovementText:SetText(string.format("FREE MOVEMENT %.1f", remaining))
            freeMovementText:Show()
        else
            freeMovementUntil = nil
            freeMovementText:Hide()
        end
    else
        freeMovementText:Hide()
    end
end

local movementFrame = CreateFrame("Frame", "CXUI_MovementTrackerFrame", UIParent)
local movementTimer = 0
movementFrame:SetScript("OnUpdate", function(self, elapsed)
    movementTimer = movementTimer + elapsed
    if movementTimer >= 0.1 then
        UpdateMovementAlert()
        movementTimer = 0
    end
end)
movementFrame:RegisterEvent("PLAYER_LOGIN")
movementFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
movementFrame:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
movementFrame:RegisterEvent("PLAYER_TALENT_UPDATE")
movementFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
movementFrame:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
movementFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        CacheMovementSpell()
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
        local spellId = ...
        if IsFreeMovementGlow(spellId) then
            local now = GetTime()
            if (now - glowProcDebounce) >= 0.12 then
                glowProcDebounce = now
                freeMovementUntil = now + FREE_MOVEMENT_DURATION
                UpdateMovementAlert()
            end
        end
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        local spellId = ...
        if IsFreeMovementGlow(spellId) then
            freeMovementUntil = nil
            UpdateMovementAlert()
        end
    else
        C_Timer.After(0.5, CacheMovementSpell)
    end
end)

-- ===========================================================================
-- ENEMY COUNTER (all classes)
-- Shows nearby enemy count at a fixed screen position while in combat.
-- Edit constants below to adjust position and appearance.
-- ===========================================================================

local COUNTER_X         =  -120
local COUNTER_Y         =  -100
local COUNTER_FONT_SIZE =  20
local COUNTER_R, COUNTER_G, COUNTER_B = 1, 1, 1

local counterText = UIParent:CreateFontString(nil, "OVERLAY")
do
    counterText:SetFont("Fonts\\FRIZQT__.TTF", COUNTER_FONT_SIZE, "OUTLINE")
end
counterText:SetTextColor(COUNTER_R, COUNTER_G, COUNTER_B, 1)
counterText:SetPoint("CENTER", UIParent, "CENTER", COUNTER_X, COUNTER_Y)
counterText:SetJustifyH("CENTER")
counterText:Hide()

local npActive = {}

local function IsValidEnemy(unit)
    return UnitExists(unit)
        and not UnitIsDead(unit)
        and UnitCanAttack("player", unit)
end

local function GetEnemyCount()
    local count = 0
    local targetCounted = false
    local hasTarget = UnitExists("target")
    for unit in pairs(npActive) do
        if IsValidEnemy(unit) then
            if UnitAffectingCombat(unit) or UnitThreatSituation("player", unit) ~= nil then
                count = count + 1
                if not targetCounted and hasTarget and UnitIsUnit(unit, "target") then
                    targetCounted = true
                end
            end
        end
    end
    if not targetCounted and hasTarget and IsValidEnemy("target") then
        if UnitAffectingCombat("target") or UnitThreatSituation("player", "target") ~= nil then
            count = count + 1
        end
    end
    return count
end

local counterLastCount = -1
local counterTicker    = nil

local function UpdateCounter()
    if not CXUI_DB or not CXUI_DB.cdmEnemyCounter
       or not UnitAffectingCombat("player") then
        counterText:Hide()
        counterLastCount = -1
        return
    end
    local count = GetEnemyCount()
    if count == counterLastCount then return end
    counterLastCount = count
    if count > 0 then
        counterText:SetText(tostring(count))
        counterText:Show()
    else
        counterText:Hide()
    end
end

local function StartCounterTicker()
    if counterTicker then return end
    counterTicker = C_Timer.NewTicker(1.0, UpdateCounter)
end

local function StopCounterTicker()
    if counterTicker then counterTicker:Cancel(); counterTicker = nil end
    counterText:Hide()
    counterLastCount = -1
end

local counterFrame = CreateFrame("Frame", "CXUI_EnemyCounterFrame", UIParent)
counterFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
counterFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
counterFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
counterFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
counterFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
counterFrame:RegisterEvent("UNIT_FLAGS")
counterFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
counterFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "PLAYER_REGEN_DISABLED" then
        StartCounterTicker()
        UpdateCounter()
    elseif event == "PLAYER_REGEN_ENABLED" then
        StopCounterTicker()
    elseif event == "PLAYER_TARGET_CHANGED" then
        if UnitAffectingCombat("player") then UpdateCounter() end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        if not UnitIsFriend("player", unit) then
            npActive[unit] = true
            if UnitAffectingCombat("player") then UpdateCounter() end
        end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        npActive[unit] = nil
        if UnitAffectingCombat("player") then UpdateCounter() end
    elseif event == "UNIT_FLAGS" then
        if npActive[unit] and UnitIsFriend("player", unit) then
            npActive[unit] = nil
            if UnitAffectingCombat("player") then UpdateCounter() end
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        wipe(npActive)
        StopCounterTicker()
    end
end)

-- ===========================================================================
-- EARLY RETURN FOR NON-DK/MAGE
-- Everything below only runs for Death Knight (6) and Mage (8).
-- ===========================================================================

if CLASS_ID ~= 6 and CLASS_ID ~= 8 then return end

-- ===========================================================================
-- ISOLATED PROC GLOW ENGINE
-- ---------------------------------------------------------------------------
-- Why we don't use LibStub("LibCustomGlow-1.0") here:
--
--   LibCustomGlow stores glow frames in pools (ProcGlowPool, GlowFramePool)
--   that live on the shared lib table. If any other addon (e.g. MiniCC)
--   embeds a higher-version copy, LibStub replaces those pool references on
--   the *same* object that our local `LCG` variable already points to.
--   Frames we acquired from the old pool are then unknown to the new pool;
--   ProcGlow_Stop tries to Release() them back into the wrong pool and either
--   silently hides them or throws "object doesn't belong to this pool".
--   That is what causes our festering/coil glows to vanish mid-arena.
--
--   Solution: build a minimal, self-contained ProcGlow engine that owns its
--   own private FramePool. It is 100% isolated from LibStub and can never be
--   invalidated by another addon loading a newer version of LCG.
--
--   The visual output is identical to LCG ProcGlow (same atlases, same
--   flipbook animations, same sizing math) because we copied the relevant
--   logic from LibCustomGlow-1.0 r24.
-- ===========================================================================

-- Private parent for all our glow frames (keeps them off UIParent's children list)
local CXUI_GlowParent = CreateFrame("Frame", "CXUI_GlowParent", UIParent)
CXUI_GlowParent:SetAllPoints()
CXUI_GlowParent:Hide() -- invisible container; children are shown individually

-- nil = no tint → renders Blizzard's native gold/yellow proc glow
local GLOW_COLOR = nil

-- ---------------------------------------------------------------------------
-- Private pool resetter — mirrors LCG's ProcGlowResetter
-- ---------------------------------------------------------------------------
local function GlowPoolResetter(_, f)
    f:ClearAllPoints()
    f:SetParent(CXUI_GlowParent)
    if f.ProcStartAnim and f.ProcStartAnim:IsPlaying() then
        f.ProcStartAnim:Stop()
    end
    if f.ProcLoopAnim and f.ProcLoopAnim:IsPlaying() then
        f.ProcLoopAnim:Stop()
    end
    if f.ProcStart then f.ProcStart:Hide() end
    if f.ProcLoop  then f.ProcLoop:Hide()  end
    f:Hide()
end

local CXUI_ProcGlowPool = CreateFramePool("Frame", CXUI_GlowParent, nil, GlowPoolResetter)

-- ---------------------------------------------------------------------------
-- Build the flipbook textures + animations on a fresh pool frame.
-- Mirrors LCG's InitProcGlow exactly so the visual is identical.
-- ---------------------------------------------------------------------------
local function InitGlowFrame(f)
    -- Start flash (plays once on Show when startAnim=true)
    f.ProcStart = f:CreateTexture(nil, "ARTWORK")
    f.ProcStart:SetBlendMode("ADD")
    f.ProcStart:SetAtlas("UI-HUD-ActionBar-Proc-Start-Flipbook")
    f.ProcStart:SetAlpha(1)
    f.ProcStart:SetSize(150, 150)
    f.ProcStart:SetPoint("CENTER")
    f.ProcStart:Hide()

    -- Loop glow (runs continuously after start)
    f.ProcLoop = f:CreateTexture(nil, "ARTWORK")
    f.ProcLoop:SetAtlas("UI-HUD-ActionBar-Proc-Loop-Flipbook")
    f.ProcLoop:SetAlpha(0)
    f.ProcLoop:SetAllPoints()
    f.ProcLoop:Hide()

    -- Loop animation group
    f.ProcLoopAnim = f:CreateAnimationGroup()
    f.ProcLoopAnim:SetLooping("REPEAT")
    f.ProcLoopAnim:SetToFinalAlpha(true)

    local alphaRepeat = f.ProcLoopAnim:CreateAnimation("Alpha")
    alphaRepeat:SetChildKey("ProcLoop")
    alphaRepeat:SetFromAlpha(1)
    alphaRepeat:SetToAlpha(1)
    alphaRepeat:SetDuration(0.001)
    alphaRepeat:SetOrder(0)

    local flipbookRepeat = f.ProcLoopAnim:CreateAnimation("FlipBook")
    flipbookRepeat:SetChildKey("ProcLoop")
    flipbookRepeat:SetDuration(1)
    flipbookRepeat:SetOrder(0)
    flipbookRepeat:SetFlipBookRows(6)
    flipbookRepeat:SetFlipBookColumns(5)
    flipbookRepeat:SetFlipBookFrames(30)
    flipbookRepeat:SetFlipBookFrameWidth(0)
    flipbookRepeat:SetFlipBookFrameHeight(0)
    f.ProcLoopAnim.flipbookRepeat = flipbookRepeat

    -- Start animation group (plays ProcStart flipbook, then hands off to loop)
    f.ProcStartAnim = f:CreateAnimationGroup()
    f.ProcStartAnim:SetToFinalAlpha(true)

    local alphaIn = f.ProcStartAnim:CreateAnimation("Alpha")
    alphaIn:SetChildKey("ProcStart")
    alphaIn:SetDuration(0.001)
    alphaIn:SetOrder(0)
    alphaIn:SetFromAlpha(1)
    alphaIn:SetToAlpha(1)

    local flipbookStart = f.ProcStartAnim:CreateAnimation("FlipBook")
    flipbookStart:SetChildKey("ProcStart")
    flipbookStart:SetDuration(0.7)
    flipbookStart:SetOrder(1)
    flipbookStart:SetFlipBookRows(6)
    flipbookStart:SetFlipBookColumns(5)
    flipbookStart:SetFlipBookFrames(30)
    flipbookStart:SetFlipBookFrameWidth(0)
    flipbookStart:SetFlipBookFrameHeight(0)

    local alphaOut = f.ProcStartAnim:CreateAnimation("Alpha")
    alphaOut:SetChildKey("ProcStart")
    alphaOut:SetDuration(0.001)
    alphaOut:SetOrder(2)
    alphaOut:SetFromAlpha(1)
    alphaOut:SetToAlpha(0)

    f.ProcStartAnim:SetScript("OnFinished", function(self)
        local parent = self:GetParent()
        parent.ProcLoop:Show()
        parent.ProcLoopAnim:Play()
    end)

    -- Hide anims when frame is hidden (e.g. pool reset)
    f:SetScript("OnHide", function(self)
        if self.ProcStartAnim:IsPlaying() then self.ProcStartAnim:Stop() end
        if self.ProcLoopAnim:IsPlaying()  then self.ProcLoopAnim:Stop()  end
    end)
end

-- ---------------------------------------------------------------------------
-- Apply color tint to an already-initialised glow frame
-- ---------------------------------------------------------------------------
local function ApplyGlowColor(f, color)
    if color then
        f.ProcStart:SetDesaturated(1)
        f.ProcStart:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
        f.ProcLoop:SetDesaturated(1)
        f.ProcLoop:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    else
        f.ProcStart:SetDesaturated(nil)
        f.ProcStart:SetVertexColor(1, 1, 1, 1)
        f.ProcLoop:SetDesaturated(nil)
        f.ProcLoop:SetVertexColor(1, 1, 1, 1)
    end
end

-- ---------------------------------------------------------------------------
-- Public: start glow on `parent`, storing the frame as parent._CXUI_ProcGlow
-- ---------------------------------------------------------------------------
local function CXUI_ProcGlow_Start(parent, color)
    if parent._CXUI_ProcGlow then
        -- Already glowing — just refresh color in case it changed
        ApplyGlowColor(parent._CXUI_ProcGlow, color)
        return
    end

    local f, isNew = CXUI_ProcGlowPool:Acquire()
    if isNew then InitGlowFrame(f) end

    parent._CXUI_ProcGlow = f
    f:SetParent(parent)
    f:SetFrameLevel(parent:GetFrameLevel() + 8)

    local w, h = parent:GetSize()
    local xOff = w * 0.2
    local yOff = h * 0.2
    f:SetPoint("TOPLEFT",     parent, "TOPLEFT",     -xOff,  yOff)
    f:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT",  xOff, -yOff)

    ApplyGlowColor(f, color)

    -- Skip start animation (startAnim = false, same as cxUI default)
    f.ProcStart:Hide()
    f.ProcLoop:Show()
    if not f.ProcLoopAnim:IsPlaying() then
        f.ProcLoopAnim:Play()
    end

    f:Show()
end

-- ---------------------------------------------------------------------------
-- Public: stop glow on `parent` and return frame to pool
-- ---------------------------------------------------------------------------
local function CXUI_ProcGlow_Stop(parent)
    local f = parent._CXUI_ProcGlow
    if not f then return end
    parent._CXUI_ProcGlow = nil
    -- GlowPoolResetter handles Hide + animation stop
    CXUI_ProcGlowPool:Release(f)
end

-- Export so DeathKnight.lua / Mage.lua can reference for debug if needed
CF.LCG = nil  -- intentionally nil: we do NOT expose the shared LCG object

-- ===========================================================================
-- EnumerateFrames scan
-- ===========================================================================

-- ===========================================================================
-- CDM-scoped scan (was: EnumerateFrames() over the entire UI)
-- ===========================================================================
-- EnumerateFrames() walked every frame in the game, including nameplates and
-- other addons' unit frames (Platynator, UnhaltedUnitFrames, etc). Reading
-- .Icon on those frames taints our call with whatever addon owns them.
-- On top of that, walking literally every frame in the game on every
-- DKRescan() call is expensive enough on its own to matter.
--
-- We only ever care about our own Cooldown Manager icons, so we scan just
-- those frame trees instead.
--
-- IMPORTANT: this used to identify frames by comparing Icon:GetTexture()
-- against known texture strings. Confirmed via /console taintLog 1 that
-- ANY comparison of a CDM icon's live texture — even our own, not just a
-- foreign frame's — is now blocked as a "secret value" comparison,
-- unconditionally, every single time. That's not a taint side-effect, it's
-- a blanket protection on Cooldown Manager icon textures. Texture-string
-- identification is a dead end and can't be worked around with pcall.
--
-- Identifying frames by frame.spellID instead (same safe pattern already
-- used for Death Coil in CDMGlowLogic.lua) sidesteps this entirely — that
-- field is never treated as a secret value in any of our testing.
-- ===========================================================================

local CDM_VIEWER_NAMES = {
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
    "BuffIconCooldownViewer",
    "CooldownViewer",
    "BlizzardCooldownFrame",
}

local function IsSafeFrame(frame)
    if not frame then return false end
    local ok, forbidden = pcall(function()
        return frame.IsForbidden and frame:IsForbidden()
    end)
    if not ok then return false end
    if forbidden then return false end
    return true
end

-- Blizzard's Secret Values system (Midnight/12.0) can return numbers that
-- LOOK like normal Lua numbers (type(sid) == "number") but cannot legally be
-- used as table keys, compared, or otherwise operated on by addons. Using one
-- as a table key throws "attempted to index a table that cannot be indexed
-- with secret keys". issecretvalue() is the supported way to detect this.
local function IsSecretValue(v)
    if issecretvalue then
        local ok, secret = pcall(issecretvalue, v)
        return ok and secret
    end
    return false
end

local function GetButtonSpellID(frame)
    if not IsSafeFrame(frame) then return nil end

    local ok, sid = pcall(function()
        return frame.spellID or frame.spellId or frame.spellid
    end)
    if ok and type(sid) == "number" and not IsSecretValue(sid) then return sid end

    local ok2, v = pcall(function()
        if frame.GetSpellID then return frame:GetSpellID() end
        return nil
    end)
    if ok2 and type(v) == "number" and not IsSecretValue(v) then return v end

    return nil
end

local function ScanCDMFrameTree(root, spellIDSet, callback, seen, depth)
    if not root or seen[root] or depth > 20 then return end
    if not IsSafeFrame(root) then return end
    seen[root] = true

    local sid = GetButtonSpellID(root)
    if sid and not IsSecretValue(sid) and spellIDSet[sid] then
        callback(root, sid)
    end

    local ok2, children = pcall(function()
        return root.GetChildren and { root:GetChildren() }
    end)
    if ok2 and children then
        for i = 1, #children do
            ScanCDMFrameTree(children[i], spellIDSet, callback, seen, depth + 1)
        end
    end
end

-- callback(frame, spellID) — called once per matching frame found.
local function ScanFramesBySpellID(spellIDs, callback)
    local spellIDSet = {}
    for _, sid in ipairs(spellIDs) do spellIDSet[sid] = true end
    local seen = {}
    for _, name in ipairs(CDM_VIEWER_NAMES) do
        local viewer = _G[name]
        if viewer then
            ScanCDMFrameTree(viewer, spellIDSet, callback, seen, 0)
        end
    end
end

-- ===========================================================================
-- Overlay helpers
-- ===========================================================================

local function CreateOverlay(cdmFrame)
    local ov = CreateFrame("Frame", nil, cdmFrame)
    ov:SetAllPoints(cdmFrame)
    ov:SetFrameLevel(cdmFrame:GetFrameLevel() + 2)
    ov._targetFrame = cdmFrame
    ov._glowActive  = false
    ov:Hide()
    return ov
end

local function StartGlow(overlay)
    if overlay._glowActive then return end
    overlay._glowActive = true
    overlay:Show()
    CXUI_ProcGlow_Start(overlay, GLOW_COLOR)
end

local function StopGlow(overlay)
    if not overlay._glowActive then return end
    overlay._glowActive = false
    CXUI_ProcGlow_Stop(overlay)
    overlay:Hide()
end

local X_THICK = 5

local function AttachXCross(overlay)
    if overlay._xl1 then return end
    local l1 = overlay:CreateTexture(nil, "OVERLAY")
    l1:SetColorTexture(1, 0, 0, 0.9)
    l1:SetPoint("CENTER", overlay, "CENTER")
    overlay._xl1 = l1
    local l2 = overlay:CreateTexture(nil, "OVERLAY")
    l2:SetColorTexture(1, 0, 0, 0.9)
    l2:SetPoint("CENTER", overlay, "CENTER")
    overlay._xl2 = l2
    local function ApplySize()
        local w, h = overlay:GetSize()
        if not w or w < 4 then return end
        local diag  = math.sqrt(w * w + h * h)
        local angle = math.atan(h / w)
        l1:SetSize(diag, X_THICK); l1:SetRotation( angle)
        l2:SetSize(diag, X_THICK); l2:SetRotation(-angle)
    end
    overlay:SetScript("OnSizeChanged", function() ApplySize() end)
    ApplySize()
end

local function ShowXCross(overlay)
    AttachXCross(overlay)
    if overlay._xl1 then overlay._xl1:Show(); overlay._xl2:Show() end
    overlay:Show()
end

local function HideXCross(overlay)
    if overlay._xl1 then overlay._xl1:Hide(); overlay._xl2:Hide() end
    overlay:Hide()
end

-- ===========================================================================
-- CDM REANCHOR HOOK SYSTEM
-- ---------------------------------------------------------------------------
-- CDM (Ayije_CDM) calls ForceReanchor() whenever the user drags icons or the
-- layout changes. Modules (DeathKnight.lua, Mage.lua) register a callback
-- here so they are notified and can rescan after the reanchor settles.
--
-- Also provides CF.OnArenaReset — fires on PLAYER_REGEN_ENABLED so modules
-- can hard-reset glow state left active across arena rounds.
-- ===========================================================================

local reanchorCallbacks   = {}
local arenaResetCallbacks = {}
local cdmHookInstalled    = false

local function InstallCDMHook()
    if cdmHookInstalled then return end
    local cdm = _G["Ayije_CDM"]
    if not cdm or not cdm.ForceReanchor then return end
    hooksecurefunc(cdm, "ForceReanchor", function()
        -- Delay so CDM finishes moving frames before we rescan
        C_Timer.After(0.25, function()
            for i = 1, #reanchorCallbacks do
                pcall(reanchorCallbacks[i])
            end
        end)
    end)
    cdmHookInstalled = true
end

-- Module registration: rescan after user drags CDM icons
function CF.OnCDMReanchor(fn)
    reanchorCallbacks[#reanchorCallbacks + 1] = fn
end

-- Module registration: hard-reset glow state on combat end / arena round end
function CF.OnArenaReset(fn)
    arenaResetCallbacks[#arenaResetCallbacks + 1] = fn
end

local sharedHookFrame = CreateFrame("Frame")
sharedHookFrame:RegisterEvent("PLAYER_LOGIN")
sharedHookFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
sharedHookFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
sharedHookFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1.5, InstallCDMHook)
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Only reset on actual arena rounds ending — this used to fire on
        -- ANY combat exit (dungeon pulls, world combat, everything), which
        -- wiped Festering/Putrefy/Reaper state it should never have touched
        -- outside of arena.
        local ok, inArena = pcall(IsActiveBattlefieldArena)
        if ok and inArena then
            for i = 1, #arenaResetCallbacks do
                pcall(arenaResetCallbacks[i])
            end
        end
    end
end)

-- ===========================================================================
-- Export
-- ===========================================================================

CF.ScanFramesBySpellID = ScanFramesBySpellID
CF.CreateOverlay       = CreateOverlay
CF.StartGlow           = StartGlow
CF.StopGlow            = StopGlow
CF.AttachXCross        = AttachXCross
CF.ShowXCross          = ShowXCross
CF.HideXCross          = HideXCross