local addonName, ns = ...

-- ===========================================================================
-- MODULE: CDM (Cooldown Manager)
-- Shared file: the ONE glow engine of the whole addon (Proc Glow + Pixel
-- Glow), the per-icon overlay helper, CDM frame scanning helpers, the CDM
-- re-anchor listener and the glow-style setting.
--   CDMGlow.lua               proc / cooldown-ready glows on CDM icons
--   SuppressBlizzardGlow.lua  hides Blizzard's own proc glow on CDM frames
-- ClassFeatures.lua uses this file too (ns.CXUI_Glow_Start / _Stop,
-- CDM.GetOrCreateOverlay, CDM.ScanFramesBySpellID).
-- ===========================================================================

local CDM = ns:NewModule("CDM", {
    name  = "CDM",
    desc  = "Glow effects for Cooldown Manager icons",
    order = 2,
})

-- nil = no color tint applied = renders Blizzard's native gold/yellow proc glow
local GLOW_COLOR = nil

-- UNIFIED GLOW ENGINE (Proc Glow + Pixel Glow)
-- ---------------------------------------------------------------------------
-- We intentionally do NOT use LibStub("LibCustomGlow-1.0") here.
--
-- LibCustomGlow stores its glow frames in shared pools (ProcGlowPool,
-- GlowFramePool) that live on the LibStub-registered lib object. ElvUI
-- embeds its own copy of LibCustomGlow-1.0 — when it loads, LibStub swaps
-- the pool references on that SAME shared object our LCG local would point
-- to. Frames we already acquired from the old pool become unknown to the
-- new pool, and ProcGlow_Stop then either silently no-ops (glow gets stuck
-- showing) or throws "object doesn't belong to this pool" — which is
-- exactly what causes our CDM proc glows (Frostbane, ready-CDs, etc.) to
-- randomly vanish or spam errors once ElvUI is loaded.
--
-- Solution: a private, self-contained pool. 100% isolated from LibStub —
-- can never be invalidated by another addon.
--
-- This is the SINGLE canonical glow engine for the whole addon. CDM icon
-- glows (this file) and class-feature overlay glows (Shared.lua, used by
-- DeathKnight.lua's Festering Strike glow etc.) both call into the exact
-- same CXUI_Glow_Start/CXUI_Glow_Stop exported below via `ns`, so every
-- glow in cxUI is guaranteed to look identical and respect the same
-- CXUI_DB.cdmGlowStyle selector. Shared.lua used to keep its own separate
-- copy of an older, unfixed version of this engine — that duplication is
-- exactly how it drifted out of sync and is why it's gone now.
--
-- Both engines below are ported from EllesmereUI's real glow rendering
-- (EllesmereUI_Glows.lua): the Proc Glow is its "Modern WoW Glow" style
-- (a single continuously-looping FlipBook, no separate start-burst phase —
-- the burst+loop handoff was what caused ours to visually freeze), and the
-- Pixel Glow is its "Procedural Ants" style (4 static edge textures using
-- a tileable dash texture, animated purely via SetTexCoord scrolling —
-- much cheaper and smoother than moving individual segments with SetPoint).
-- ---------------------------------------------------------------------------

local CXUI_CDMGlowParent = CreateFrame("Frame", "CXUI_CDMGlowParent", UIParent)
CXUI_CDMGlowParent:SetAllPoints()
CXUI_CDMGlowParent:Hide() -- invisible container; children are shown individually

-- =============================================================================
-- PROC GLOW ("Modern WoW Glow" — continuous flipbook loop + shimmer overlay)
-- =============================================================================

local PROC_TEX_PADDING = 1.4 -- matches EllesmereUI's texPadding for this atlas

local function CDMGlowPoolResetter(_, f)
    f:ClearAllPoints()
    f:SetParent(CXUI_CDMGlowParent)
    f:SetScript("OnUpdate", nil)
    f._rawW, f._rawH = nil, nil
    if f.ag and f.ag:IsPlaying() then f.ag:Stop() end
    if f.antsAg and f.antsAg:IsPlaying() then f.antsAg:Stop() end
    f:Hide()
end

local CXUI_CDMGlowPool = CreateFramePool("Frame", CXUI_CDMGlowParent, nil, CDMGlowPoolResetter)

local function InitCDMGlowFrame(f)
    -- Main tinted layer
    f.tex = f:CreateTexture(nil, "OVERLAY", nil, 7)
    f.tex:SetAtlas("UI-HUD-ActionBar-Proc-Loop-Flipbook")
    f.tex:SetPoint("CENTER")

    f.ag = f.tex:CreateAnimationGroup()
    f.ag:SetLooping("REPEAT")
    f.anim = f.ag:CreateAnimation("FlipBook")
    -- NOTE: FlipBook rows/columns/frames/frameWidth/frameHeight are configured
    -- in CXUI_CDMGlow_Start (every time, AFTER SetSize), not here. frameWidth/
    -- frameHeight of 0 means "auto-compute from the texture's current size" —
    -- and at Init time the texture is still 0x0 (SetSize hasn't happened yet),
    -- so configuring "auto" here bakes in a permanent 0x0 sub-frame and the
    -- animation just sits frozen on its first (degenerate) frame forever,
    -- no matter what we resize the texture to afterwards. This exact ordering
    -- bug was the "frozen" glow.

    -- Shimmer accent: same animation, additive, low alpha, never desaturated —
    -- this second layer is what gives the modern glow its "alive" look.
    f.ants = f:CreateTexture(nil, "OVERLAY", nil, 7)
    f.ants:SetAtlas("UI-HUD-ActionBar-Proc-Loop-Flipbook")
    f.ants:SetPoint("CENTER")
    f.ants:SetBlendMode("ADD")

    f.antsAg = f.ants:CreateAnimationGroup()
    f.antsAg:SetLooping("REPEAT")
    f.antsAnim = f.antsAg:CreateAnimation("FlipBook")
end

-- nil color = no tint = renders Blizzard's native gold/yellow proc glow.
-- The shimmer layer is always neutral white at low alpha regardless of tint.
local function ApplyCDMGlowColor(f, color)
    if color then
        f.tex:SetDesaturated(1)
        f.tex:SetVertexColor(color[1], color[2], color[3], color[4] or 1)
    else
        f.tex:SetDesaturated(nil)
        f.tex:SetVertexColor(1, 1, 1, 1)
    end
    f.ants:SetDesaturated(nil)
    f.ants:SetVertexColor(1, 1, 1, 1)
    f.ants:SetAlpha(0.35)
end

-- Self-healing: keeps the wrapper anchored and the flipbook textures sized
-- to the parent's CURRENT size, every frame, instead of computing this once
-- at creation. Needed because the parent (CDM icon) can still be 0x0 at the
-- exact moment CXUI_CDMGlow_Start first runs — e.g. under EllesmereUI's CDM
-- module, icons get resized/repositioned by its own reflow pass sometime
-- after Blizzard creates them, and if our glow attaches before that reflow
-- finishes, a one-time size snapshot bakes in 0x0 (or the 36x36 fallback)
-- forever. Cheap: two GetSize comparisons per frame, no allocation.
local function CDMGlow_OnUpdate(self, elapsed)
    local parent = self:GetParent()
    if not parent then return end
    self:SetAllPoints(parent)
    self:SetFrameStrata(parent:GetFrameStrata())

    local w, h = parent:GetSize()
    if not w or not h or w <= 0 or h <= 0 then return end
    if w == self._rawW and h == self._rawH then return end
    self._rawW, self._rawH = w, h

    local texW, texH = w * PROC_TEX_PADDING, h * PROC_TEX_PADDING
    self.tex:SetSize(texW, texH)
    self.ants:SetSize(texW, texH)
    -- Re-derive FlipBook geometry from the new texture size — "auto" (0)
    -- snapshots the CURRENT texture size when set, so it must be re-set
    -- every time the texture is resized, not just once at Init.
    self.anim:SetFlipBookFrameWidth(0)
    self.anim:SetFlipBookFrameHeight(0)
    self.antsAnim:SetFlipBookFrameWidth(0)
    self.antsAnim:SetFlipBookFrameHeight(0)
end

local function CXUI_CDMGlow_Start(parent, color)
    if parent._CXUI_CDMGlow then
        parent._CXUI_CDMGlow:SetFrameStrata(parent:GetFrameStrata())
        parent._CXUI_CDMGlow:SetFrameLevel(parent:GetFrameLevel() + 8)
        ApplyCDMGlowColor(parent._CXUI_CDMGlow, color)
        return
    end

    local f, isNew = CXUI_CDMGlowPool:Acquire()
    if isNew then InitCDMGlowFrame(f) end

    parent._CXUI_CDMGlow = f
    f:SetParent(parent)
    f:SetFrameStrata(parent:GetFrameStrata())
    f:SetFrameLevel(parent:GetFrameLevel() + 8)
    f:SetAllPoints(parent)

    -- FlipBook frames have transparent padding baked in — scale the texture
    -- itself up rather than expanding the wrapper's anchors. Textures aren't
    -- clipped by their parent frame, so this overflows the icon naturally.
    local w, h = parent:GetSize()
    if not w or w <= 0 then w = 36 end
    if not h or h <= 0 then h = 36 end
    local texW, texH = w * PROC_TEX_PADDING, h * PROC_TEX_PADDING
    f.tex:SetSize(texW, texH)
    f.ants:SetSize(texW, texH)
    f._rawW, f._rawH = w, h

    -- Configure FlipBook geometry AFTER sizing, every single Start call —
    -- frameWidth/Height = 0 ("auto") is computed from the texture's size at
    -- the moment these are set, so this must happen post-SetSize or the
    -- animation locks onto a degenerate 0x0 sub-frame (see note in Init).
    f.anim:SetFlipBookRows(6)
    f.anim:SetFlipBookColumns(5)
    f.anim:SetFlipBookFrames(30)
    f.anim:SetDuration(1.0)
    f.anim:SetFlipBookFrameWidth(0)
    f.anim:SetFlipBookFrameHeight(0)

    f.antsAnim:SetFlipBookRows(6)
    f.antsAnim:SetFlipBookColumns(5)
    f.antsAnim:SetFlipBookFrames(30)
    f.antsAnim:SetDuration(1.0)
    f.antsAnim:SetFlipBookFrameWidth(0)
    f.antsAnim:SetFlipBookFrameHeight(0)

    ApplyCDMGlowColor(f, color)

    if f.ag:IsPlaying() then f.ag:Stop() end
    f.ag:Play()
    if f.antsAg:IsPlaying() then f.antsAg:Stop() end
    f.antsAg:Play()

    f:SetScript("OnUpdate", CDMGlow_OnUpdate)
    f:Show()
end

local function CXUI_CDMGlow_Stop(parent)
    local f = parent._CXUI_CDMGlow
    if not f then return end
    parent._CXUI_CDMGlow = nil
    -- CDMGlowPoolResetter handles Hide + animation stop
    CXUI_CDMGlowPool:Release(f)
end

-- =============================================================================
-- PIXEL GLOW ("Procedural Ants" — scrolling dash texture along 4 static edges)
-- =============================================================================

-- Shipped alongside this addon: cxUI/media/CDMGlow/glow-dash-h.tga (64x8) and
-- glow-dash-v.tga (8x64) — a single dash spanning 50% of the tile with a
-- soft 1px anti-aliased fade at each end, tiled with REPEAT.
local floor = math.floor
local PIXELGLOW_TEX_H = ns.Media("CDMGlow", "glow-dash-h.tga")
local PIXELGLOW_TEX_V = ns.Media("CDMGlow", "glow-dash-v.tga")
local PIXELGLOW_N      = 8 -- number of dashes around the full perimeter
local PIXELGLOW_TH     = 2 -- border thickness in pixels
local PIXELGLOW_PERIOD = 4 -- seconds per full revolution

local function PixelGlowPoolResetter(_, f)
    f:SetScript("OnUpdate", nil)
    f:ClearAllPoints()
    f:SetParent(CXUI_CDMGlowParent)
    -- NOTE: the pool's resetterFunc runs on Acquire() as well as Release()
    -- (per FramePoolMixin docs: "all three functions apply the pool's
    -- resetterFunc to affected widgets during each operation"). On a brand
    -- new frame's very first Acquire, top/bottom/left/right don't exist yet
    -- (InitPixelGlowFrame hasn't run), so these must be nil-guarded or the
    -- pool throws here and CXUI_PixelGlow_Start aborts before ever creating
    -- the textures — this was the exact cause of the pixel glow never
    -- rendering.
    if f.top then f.top:Hide() end
    if f.bottom then f.bottom:Hide() end
    if f.left then f.left:Hide() end
    if f.right then f.right:Hide() end
    f:Hide()
end

local CXUI_PixelGlowPool = CreateFramePool("Frame", CXUI_CDMGlowParent, nil, PixelGlowPoolResetter)

local function InitPixelGlowFrame(f)
    local function mk(p1, p2)
        local t = f:CreateTexture(nil, "OVERLAY", nil, 7)
        t:SetPoint(p1, f, p1)
        t:SetPoint(p2, f, p2)
        return t
    end
    f.top    = mk("TOPLEFT", "TOPRIGHT")
    f.bottom = mk("BOTTOMLEFT", "BOTTOMRIGHT")
    f.left   = mk("TOPLEFT", "BOTTOMLEFT")
    f.right  = mk("TOPRIGHT", "BOTTOMRIGHT")

    -- true,true = tile horizontally/vertically. Using the classic boolean
    -- form here rather than string wrap-mode constants ("REPEAT") since the
    -- latter's acceptance varies across client API revisions — if SetTexture
    -- silently rejects it, the texture never gets applied and nothing renders.
    f.top:SetTexture(PIXELGLOW_TEX_H, true, true)
    f.bottom:SetTexture(PIXELGLOW_TEX_H, true, true)
    f.left:SetTexture(PIXELGLOW_TEX_V, true, true)
    f.right:SetTexture(PIXELGLOW_TEX_V, true, true)

    f.timer = 0
    f.w, f.h = 0, 0
    f._rawW, f._rawH = 0, 0
end

local function ApplyPixelGlowColor(f, color)
    local r, g, b, a = 1, 0.82, 0, 1 -- native-ish gold default (our own convention)
    if color then r, g, b, a = color[1], color[2], color[3], color[4] or 1 end
    f.top:SetVertexColor(r, g, b, a)
    f.bottom:SetVertexColor(r, g, b, a)
    f.left:SetVertexColor(r, g, b, a)
    f.right:SetVertexColor(r, g, b, a)
end

-- One physical screen pixel, expressed in the given frame's LOCAL coordinate
-- units. Same math as EllesmereUI's PP.perfect / PP.SnapForES (768 divided by
-- the physical screen height gives "1 UI-unit == 1 pixel" at UIParent scale 1;
-- dividing further by the frame's own effective scale gives the size of one
-- physical pixel in THIS frame's local units). Self-contained so it works with
-- or without EllesmereUI loaded.
local function CXUI_OnePixel(frame)
    local _, screenH = GetPhysicalScreenSize()
    if not screenH or screenH <= 0 then screenH = 768 end
    local perfect = 768 / screenH
    local es = frame:GetEffectiveScale()
    if not es or es <= 0 then es = 1 end
    return perfect / es
end

-- Snaps w/h AND border thickness to a whole number of physical pixels at the
-- frame's current effective scale. Without this, SetHeight(2)/SetWidth(2) on
-- 4 independently-anchored edge textures round to different physical-pixel
-- counts whenever the effective scale isn't an exact integer (near-universal
-- for CDM icons, which are almost never at scale 1.0) — some edges rasterize
-- 1px thicker than others. This is exactly the fix EllesmereUI's own
-- _AntsResolveSize applies (PP.perfect / GetEffectiveScale, floor+0.5 round),
-- ported here without depending on EllesmereUI being loaded.
local function PixelGlow_ResolveSize(self)
    local w, h = self:GetSize()
    if not w or not h or w <= 0 or h <= 0 then return false end
    local onePixel = CXUI_OnePixel(self)
    w = floor(w / onePixel + 0.5) * onePixel
    h = floor(h / onePixel + 0.5) * onePixel
    local th = floor(PIXELGLOW_TH / onePixel + 0.5) * onePixel
    -- Never let the border round down to a single physical pixel — at small
    -- effective scales (e.g. EllesmereUI's global UI scale of 0.65 vs ~1.0
    -- without it) PIXELGLOW_TH=2 can legitimately round down to 1 physical
    -- pixel, making the glow measurably (confirmed: exactly half) thinner
    -- than under stock Blizzard UI scale. Enforce a 2-physical-pixel floor
    -- so thickness stays visually consistent across UI scales.
    if th < 2 * onePixel then th = 2 * onePixel end
    self.top:SetHeight(th); self.bottom:SetHeight(th)
    self.left:SetWidth(th); self.right:SetWidth(th)
    self.w, self.h = w, h
    local k = PIXELGLOW_N / (2 * (w + h))
    self.wk   = w * k
    self.whk  = (w + h) * k
    self.wwhk = (2 * w + h) * k
    return true
end

-- Scrolls the 4 edge textures' TexCoords so the dash pattern marches
-- clockwise around the border, staying continuous through every corner.
local function PixelGlow_OnUpdate(self, elapsed)
    local parent = self:GetParent()
    if parent then
        self:SetAllPoints(parent)
        self:SetFrameStrata(parent:GetFrameStrata())
    end

    self.timer = self.timer + elapsed
    if self.timer >= PIXELGLOW_PERIOD then self.timer = self.timer % PIXELGLOW_PERIOD end

    local w, h = self:GetSize()
    if not w or not h or w <= 0 or h <= 0 then return end
    if w ~= self._rawW or h ~= self._rawH then
        self._rawW, self._rawH = w, h
        if not PixelGlow_ResolveSize(self) then return end
    end

    local o = (self.timer / PIXELGLOW_PERIOD) * PIXELGLOW_N
    local wk, whk, wwhk = self.wk, self.whk, self.wwhk
    self.top:SetTexCoord(-o, wk - o, 0, 1)
    self.right:SetTexCoord(0, 1, wk - o, whk - o)
    self.bottom:SetTexCoord(wwhk - o, whk - o, 0, 1)
    self.left:SetTexCoord(0, 1, PIXELGLOW_N - o, wwhk - o)
end

local function CXUI_PixelGlow_Start(parent, color)
    if parent._CXUI_PixelGlow then
        parent._CXUI_PixelGlow:SetFrameStrata(parent:GetFrameStrata())
        parent._CXUI_PixelGlow:SetFrameLevel(parent:GetFrameLevel() + 8)
        ApplyPixelGlowColor(parent._CXUI_PixelGlow, color)
        return
    end

    local f, isNew = CXUI_PixelGlowPool:Acquire()
    if isNew then InitPixelGlowFrame(f) end

    parent._CXUI_PixelGlow = f
    f:SetParent(parent)
    f:SetFrameStrata(parent:GetFrameStrata())
    f:SetFrameLevel(parent:GetFrameLevel() + 8)
    f:SetAllPoints(parent)

    ApplyPixelGlowColor(f, color)
    f.top:Show(); f.bottom:Show(); f.left:Show(); f.right:Show()

    f.timer = 0
    f.w, f.h = 0, 0       -- force perimeter recompute on first tick
    f._rawW, f._rawH = 0, 0 -- force pixel-snap recompute on first tick
    PixelGlow_OnUpdate(f, 0)
    f:SetScript("OnUpdate", PixelGlow_OnUpdate)
    f:Show()
end

local function CXUI_PixelGlow_Stop(parent)
    local f = parent._CXUI_PixelGlow
    if not f then return end
    parent._CXUI_PixelGlow = nil
    -- PixelGlowPoolResetter handles Hide + OnUpdate teardown
    CXUI_PixelGlowPool:Release(f)
end

-- =============================================================================
-- Dispatcher — picks proc vs pixel per CXUI_DB.cdmGlowStyle, and is exported
-- on `ns` so Shared.lua (DK/Mage class-feature glows) uses this exact same
-- engine instead of keeping its own separate copy.
-- =============================================================================

local function CXUI_Glow_Start(parent, color)
    if CXUI_DB.cdmGlowStyle == "pixel" then
        pcall(CXUI_CDMGlow_Stop, parent)
        pcall(CXUI_PixelGlow_Start, parent, color)
    else
        pcall(CXUI_PixelGlow_Stop, parent)
        pcall(CXUI_CDMGlow_Start, parent, color)
    end
end

local function CXUI_Glow_Stop(parent)
    pcall(CXUI_CDMGlow_Stop, parent)
    pcall(CXUI_PixelGlow_Stop, parent)
end

ns.CXUI_Glow_Start = CXUI_Glow_Start
ns.CXUI_Glow_Stop  = CXUI_Glow_Stop

-- Overlay frame helpers (per-CDM-icon container for the glow texture)
-- ---------------------------------------------------------------------------

local cdmOverlays = {}

local STRATA_NAMES = { "BACKGROUND", "LOW", "MEDIUM", "HIGH", "DIALOG", "FULLSCREEN", "FULLSCREEN_DIALOG", "TOOLTIP" }
local STRATA_ORDER = { BACKGROUND=1, LOW=2, MEDIUM=3, HIGH=4, DIALOG=5, FULLSCREEN=6, FULLSCREEN_DIALOG=7, TOOLTIP=8 }

local function GetOrCreateCDMOverlay(frame)
    local ov = cdmOverlays[frame]
    if not ov then
        ov = CreateFrame("Frame", nil, frame)
        cdmOverlays[frame] = ov
    end
    -- Re-sync every call, not just on creation: some CDM implementations
    -- (e.g. EllesmereUI's cooldown manager module) reassign icon:SetFrameLevel()
    -- dynamically as icons change position within the active-cooldown rotation.
    -- A level cached only at first creation goes stale the moment the icon's
    -- level changes afterward. No-op cost on stock Blizzard CDM, where icon
    -- levels never change after creation.
    ov:SetAllPoints(frame)
    ov:SetFrameLevel(frame:GetFrameLevel() + 2)
    -- Strata trumps level entirely (a HIGH-strata frame always draws over
    -- every MEDIUM-strata frame regardless of level numbers). Jumping a
    -- strata tier above whatever the icon currently uses is what actually
    -- guarantees we render on top, regardless of what else EllesmereUI (or
    -- anything else) puts in the icon's own strata.
    local idx = (STRATA_ORDER[frame:GetFrameStrata() or "MEDIUM"] or 3) + 1
    ov:SetFrameStrata(STRATA_NAMES[math.min(idx, #STRATA_NAMES)])
    return ov
end

-- Exported so Shared.lua's class-feature overlays (Festering Wound glow,
-- Putrefy cross, etc.) use this exact function instead of keeping their own
-- copy — that duplication is exactly how the CDM-icon overlay drifted out
-- of sync with the strata/level fixes made here (see ScanCDMOverlays in
-- DeathKnight.lua / CreateOverlay in Shared.lua).
ns.CXUI_GetOrCreateCDMOverlay = GetOrCreateCDMOverlay

CDM.glowColor = GLOW_COLOR
CDM.overlays  = cdmOverlays
CDM.GetOrCreateOverlay = GetOrCreateCDMOverlay
ns.CXUI_GetOrCreateCDMOverlay = GetOrCreateCDMOverlay

-- ---------------------------------------------------------------------------
-- Frame scanning helpers (identify CDM icons by frame.spellID, never by
-- texture: comparing a CDM icon's live texture is a blocked secret value)
-- ---------------------------------------------------------------------------
CDM.VIEWER_NAMES = {
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
    "BuffIconCooldownViewer",
    "CooldownViewer",
    "BlizzardCooldownFrame",
}

function CDM.IsSafeFrame(frame)
    if not frame then return false end
    local ok, forbidden = pcall(function()
        return frame.IsForbidden and frame:IsForbidden()
    end)
    if not ok then return false end
    if forbidden then return false end
    return true
end

-- Blizzard's Secret Values can look like numbers but can't be used as table
-- keys or compared; issecretvalue() is the supported detector.
function CDM.IsSecret(v)
    if issecretvalue then
        local ok, secret = pcall(issecretvalue, v)
        return ok and secret
    end
    return false
end

function CDM.GetButtonSpellID(frame)
    if not CDM.IsSafeFrame(frame) then return nil end

    local ok, sid = pcall(function()
        return frame.spellID or frame.spellId or frame.spellid
    end)
    if ok and type(sid) == "number" and not CDM.IsSecret(sid) then return sid end

    local ok2, v = pcall(function()
        if frame.GetSpellID then return frame:GetSpellID() end
        return nil
    end)
    if ok2 and type(v) == "number" and not CDM.IsSecret(v) then return v end

    return nil
end

local function ScanCDMFrameTree(root, spellIDSet, callback, seen, depth)
    if not root or seen[root] or depth > 20 then return end
    if not CDM.IsSafeFrame(root) then return end
    seen[root] = true

    local sid = CDM.GetButtonSpellID(root)
    if sid and spellIDSet[sid] then callback(root, sid) end

    local ok2, children = pcall(function()
        return root.GetChildren and { root:GetChildren() }
    end)
    if ok2 and children then
        for i = 1, #children do
            ScanCDMFrameTree(children[i], spellIDSet, callback, seen, depth + 1)
        end
    end
end

-- callback(frame, spellID) is called once per CDM frame showing one of spellIDs.
function CDM.ScanFramesBySpellID(spellIDs, callback)
    local spellIDSet = {}
    for _, sid in ipairs(spellIDs) do spellIDSet[sid] = true end
    local seen = {}
    for _, name in ipairs(CDM.VIEWER_NAMES) do
        local viewer = _G[name]
        if viewer then ScanCDMFrameTree(viewer, spellIDSet, callback, seen, 0) end
    end
end

-- ---------------------------------------------------------------------------
-- CDM re-anchor listeners (Ayije_CDM calls ForceReanchor when icons move).
-- The Blizzard hook is installed once, the first time somebody listens, and
-- does nothing while nobody is registered.
-- ---------------------------------------------------------------------------
local reanchorListeners = {}
local reanchorHooked = false

local function TryHookReanchor()
    if reanchorHooked then return end
    local cdm = _G["Ayije_CDM"]
    if not (cdm and cdm.ForceReanchor) then return end
    reanchorHooked = true
    hooksecurefunc(cdm, "ForceReanchor", function()
        if not next(reanchorListeners) then return end
        C_Timer.After(0.25, function()
            for _, fn in pairs(reanchorListeners) do pcall(fn) end
        end)
    end)
end

-- Ayije_CDM may load after us, so retry on PLAYER_ENTERING_WORLD while listening.
local reanchorEvents = CreateFrame("Frame")
reanchorEvents:SetScript("OnEvent", function()
    if reanchorHooked or not next(reanchorListeners) then
        reanchorEvents:UnregisterAllEvents()
        return
    end
    C_Timer.After(1.5, TryHookReanchor)
end)

function CDM.AddReanchorListener(id, fn)
    reanchorListeners[id] = fn
    TryHookReanchor()
    if not reanchorHooked then reanchorEvents:RegisterEvent("PLAYER_ENTERING_WORLD") end
end

function CDM.RemoveReanchorListener(id)
    reanchorListeners[id] = nil
    if not next(reanchorListeners) then reanchorEvents:UnregisterAllEvents() end
end

-- ---------------------------------------------------------------------------
-- Glow style setting (applies to every glow in the addon)
-- ---------------------------------------------------------------------------
local styleListeners = {}
function CDM.OnStyleChange(fn) styleListeners[#styleListeners + 1] = fn end

CDM:NewChoice{
    key     = "cdmGlowStyle",
    name    = "Glow Style",
    desc    = "Visual style used for every glow in cxUI.",
    default = "proc",
    order   = 100,
    choices = {
        { value = "proc",  name = "Proc Glow (Blizzard style)", desc = "The default gold flipbook glow, same as Blizzard's proc glow." },
        { value = "pixel", name = "Pixel Glow (marching ants)", desc = "A ring of small pixels travelling around the icon border." },
    },
    onChange = function(value)
        for _, fn in ipairs(styleListeners) do pcall(fn, value) end
    end,
}

CDM:NewNote("|cffff0000* If you are using MiniCC, set its glow-type option (Misc tab) to anything other than proc glow.|r", 101)

-- ---------------------------------------------------------------------------
-- /cdmglow  (subcommands are added by CDM.lua and CDMGlow.lua)
-- ---------------------------------------------------------------------------
CDM.slash = {}

-- Standalone test frame, not tied to any real CDM icon.
local testFrame
CDM.slash.test = function()
    if not testFrame then
        testFrame = CreateFrame("Frame", "CXUI_GlowTestFrame", UIParent)
        testFrame:SetSize(48, 48)
        testFrame:SetPoint("CENTER")
        testFrame:SetFrameStrata("HIGH")
        local bg = testFrame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0.6)
        local label = testFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        label:SetPoint("TOP", testFrame, "BOTTOM", 0, -4)
        label:SetText("cxUI glow test")
    end
    testFrame:Show()
    -- Bypass the pcall-wrapped dispatcher on purpose so real errors are visible.
    if CXUI_DB.cdmGlowStyle == "pixel" then
        pcall(CXUI_CDMGlow_Stop, testFrame)
        local ok, err = pcall(CXUI_PixelGlow_Start, testFrame, nil)
        if not ok then ns.Print("|cffff2020pixel glow error:|r " .. tostring(err)) end
    else
        pcall(CXUI_PixelGlow_Stop, testFrame)
        local ok, err = pcall(CXUI_CDMGlow_Start, testFrame, nil)
        if not ok then ns.Print("|cffff2020proc glow error:|r " .. tostring(err)) end
    end
    ns.Print(("test glow shown at screen center, style = %s"):format(tostring(CXUI_DB.cdmGlowStyle)))
    ns.Print("pixel glow textures: " .. PIXELGLOW_TEX_H .. " / " .. PIXELGLOW_TEX_V)
    ns.Print("/cdmglow testoff to hide it")
end

CDM.slash.testoff = function()
    if testFrame then
        CXUI_Glow_Stop(testFrame)
        testFrame:Hide()
    end
    ns.Print("test glow hidden")
end

SLASH_CDMGLOWDEBUG1 = "/cdmglow"
SlashCmdList["CDMGLOWDEBUG"] = function(msg)
    local cmd = ((msg or ""):match("^(%S+)") or ""):lower()
    local fn = CDM.slash[cmd]
    if fn then
        fn()
    else
        ns.Print("/cdmglow debug   - CDM frames in viewers")
        ns.Print("/cdmglow diag    - dump scale/level/strata chain for real CDM icons")
        ns.Print("/cdmglow test    - show a test glow at screen center (current style)")
        ns.Print("/cdmglow testoff - hide the test glow")
    end
end
