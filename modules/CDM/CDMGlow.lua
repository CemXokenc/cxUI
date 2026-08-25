local addonName, ns = ...

-- ===========================================================================
-- MODULE: CDM GLOW LOGIC
-- ===========================================================================

CDMProcGlowDB = CDMProcGlowDB or { enabled = true }
local DB = CDMProcGlowDB

-- nil = no color tint applied = renders Blizzard's native gold/yellow proc glow
local GLOW_COLOR = nil

-- ---------------------------------------------------------------------------
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

-- Shipped alongside this addon: cxUI/media/glow-dash-h.tga (64x8) and
-- glow-dash-v.tga (8x64) — a single dash spanning 50% of the tile with a
-- soft 1px anti-aliased fade at each end, tiled with REPEAT.
local floor = math.floor
local PIXELGLOW_TEX_H = [[Interface\AddOns\cxUI\media\glow-dash-h.tga]]
local PIXELGLOW_TEX_V = [[Interface\AddOns\cxUI\media\glow-dash-v.tga]]
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



-- ---------------------------------------------------------------------------
-- PROC CONFIG
-- ---------------------------------------------------------------------------
-- Key types:
--   [numericAuraID] = { spellID, ... }     glow when aura is active on player
--   ["cdm:spellID"] = { spellID }          glow whenever frame is visible in CDM
--   ["overlay:spellID"] = { spellID }      glow driven by SPELL_ACTIVATION_OVERLAY_GLOW_SHOW/HIDE
--   ["ready:spellID"] = { spellID }        glow when spell is not on cooldown and IsSpellUsable
-- ---------------------------------------------------------------------------

local PROC_CONFIG = {
    DEATHKNIGHT = {
        -- Procs
        [81340] = { 47541, 207317, 1242174, 383269 },    -- Sudden Doom            → Death Coil, Epidemic, Necrotic Coil, Graveyard
        --[51124] = { 49020, 207230 },                     -- Killing Machine        → Obliterate, Frostscythe
        --["overlay:49184"] = { 49184 },                   -- Rime                   → Howling Blast
        ["cdm:1228433"]   = { 1228433 },                 -- Frostbane              → always glow if present in CDM
        -- CDs
        ["ready:42650"]   = { 42650 },                   -- Army of the Dead       → glow when ready
        ["ready:1249658"] = { 1249658 },                 -- Breath of Sindragosa   → glow when ready
        -- Utility
        -- ["ready:47528"] = { 47528 },                     -- Mind Freeze            → glow when ready
        -- ["ready:49576"] = { 49576 },                     -- Death Grip             → glow when ready
    },
    MAGE = {
        -- Procs
        --[44544]  = { 30455 },                            -- Fingers of Frost       → Ice Lance
        --[190446] = { 44614 },                            -- Brain Freeze           → Flurry
        --[270232] = { 190356 },                           -- Freezing Rain          → Blizzard
        --["cdm:199786"] = { 199786 },                     -- Glacial Spike          → always glow if present in CDM
        -- CDs
        ["ready:84714"] = { 84714 },                     -- Frozen Orb             → glow when ready
        -- Utility
        -- ["ready:2139"] = { 2139 },                       -- Counterspell           → glow when ready
        ["ready:475"]  = { 475 },                        -- Remove Curse           → glow when ready
        ["ready:30449"]  = { 30449 },                        -- Spellsteal           → glow when ready
		
    },
    WARLOCK = {
        -- Procs
        --[264173] = { 264178 },                           -- Demonic Core           → Demonbolt
        --["cdm:434635"]  = { 434635 },                    -- Ruination              → always glow if present in CDM
        --["cdm:434506"]  = { 434506 },                    -- Infernal Bolt          → always glow if present in CDM
        -- CDs
        ["ready:105174"] = { 105174 },                   -- Hand of Gul'dan        → glow when ready
        ["ready:104316"] = { 104316 },                   -- Call Dreadstalkers     → glow when ready
        ["ready:265187"] = { 265187 },                   -- Summon Demonic Tyrant  → glow when ready
        ["cdm:1276452"]  = { 1276452 },                  -- Grimoire: Imp Lord     → always glow if present in CDM
        ["cdm:1276467"]  = { 1276467 },                  -- Grimoire: Fel Ravager  → always glow if present in CDM
        -- Utility
        -- ["ready:119914"] = { 119914 },                   -- Axe Toss              → glow when ready
        -- ["ready:119910"] = { 119910 },                   -- Spell Lock             → glow when ready
        -- ["ready:89808"] = { 89808 },                   -- Singe Magic            → glow when ready
        -- ["ready:19505"] = { 19505 },                   -- Devour Magic            → glow when ready
    },
    WARRIOR = {
		-- Procs
		--[29725] = { 281000 },                     -- Sudden Death        → Execute
		-- CDs
		-- ["ready:12294"]  = { 12294 },                    -- Mortal Strike                → glow when ready
		["ready:446035"]  = { 446035 },                    -- Bladestorm               → glow when ready
		["ready:260708"]  = { 260708 },                    -- Sweeping Strikes               → glow when ready
		-- Utility
		-- ["ready:6552"]  = { 6552 },                    -- Pummel                → glow when ready
		["ready:64382"]  = { 64382 },                    -- Shattering Throw                → glow when ready
	}, 
	PALADIN = {
		-- Procs
        -- CDs        
        -- Utility
		-- ["ready:96231"] = { 96231 },                   -- Rebuke        → glow when ready
		["ready:4987"] = { 4987 },                   -- Cleanse        → glow when ready
		["ready:213644"] = { 213644 },                   -- Cleanse Toxins        → glow when ready
	}, 
	HUNTER = {
		-- Procs
        -- CDs        
        -- Utility
		-- ["ready:147362"] = { 147362 },                   -- Counter Shot        → glow when ready		
		["ready:19801"] = { 19801 },                   -- Tranquilizing Shot        → glow when ready		
		["ready:212640"] = { 212640 },                   -- Mending Bandage      → glow when ready		
	}, 
	ROGUE = {
		-- Procs
        -- CDs        
        -- Utility
		-- ["ready:1766"]  = { 1766 },                    -- Kick                → glow when ready
		["ready:5938"]  = { 5938 },                    -- Shiv                → glow when ready
	},
    PRIEST = {
        -- Procs
        --[375981] = { 8092, 450983 },                     -- Shadowy Insight        → Mind Blast, Void Blast
        --[373204] = { 335467 },                           -- Mind Devourer          → Shadow Word: Madness
        -- CDs
        ["ready:228260"]  = { 228260 },                  -- Voidform               → glow when ready
        ["ready:1242173"] = { 1242173 },                 -- Void Volley            → glow when ready
        ["ready:120644"]  = { 120644 },                  -- Halo                   → glow when ready
        ["ready:120517"]  = { 120517 },                  -- Halo (Holy)            → glow when ready
        ["ready:263165"]  = { 263165 },                  -- Void Torrent           → glow when ready
        ["ready:450983"]  = { 450983 },                  -- Void Blast             → glow when ready
        -- Utility
        -- ["ready:15487"]  = { 15487 },                    -- Silence                → glow when ready
        ["ready:32375"] = { 32375 },                   -- Mass Dispel        → glow when ready
        ["ready:213634"] = { 213634 },                   -- Purify Disease         → glow when ready
        ["ready:527"]    = { 527 },                      -- Purify                 → glow when ready
        ["ready:528"]    = { 528 },                      -- Dispel Magic           → glow when ready
    },
    SHAMAN = {
		-- Procs		
        -- CDs
		-- ["ready:452201"]  = { 452201 },                    -- Tempest            → glow when ready
		["ready:191634"]  = { 191634 },                    -- Poison Cleansing Totem            → glow when ready
		-- ["ready:114050"]  = { 114050 },                    -- Ascendance            → glow when ready
		["ready:462620"]  = { 462620 },                    -- Earth Quake            → glow when ready
		["ready:117014"]  = { 117014 },                    -- Elemental Blast            → glow when ready
        -- Utility
		-- ["ready:57994"]  = { 57994 },                    -- Wind Shear            → glow when ready
		["ready:8166"]  = { 8166 },                    -- Poison Cleansing Totem            → glow when ready
		["ready:51886"]  = { 51886 },                    -- Cleanse Spirit                → glow when ready
		["ready:77130"]  = { 77130 },                    -- Purify Spirit               → glow when ready
		["ready:370"]  = { 370 },                    -- Purge                → glow when ready
	},
    MONK = {
        -- Procs
        --[438443] = { 101546 },                           -- Dance of Chi-Ji            → Spinning Crane Kick
        --[443112] = { 124682 },                           -- Strength of the Black Ox  → Enveloping Mist
        -- CDs		
        -- Utility
		-- ["ready:116705"] = { 116705 },                   -- Spear Hand Strike        → glow when ready
		["ready:218164"] = { 218164 },                   -- Detox        → glow when ready
		["ready:115450"] = { 115450 },                   -- Detox        → glow when ready
    },
    DRUID = {
		-- Procs
        -- CDs  
		["ready:204066"] = { 204066 },                 -- Lunar Beam     → glow when ready		
		["ready:202770"] = { 202770 },                 -- Fury of Elune     → glow when ready		
		["ready:1261867"] = { 1261867 },                 -- Heart of the Wild     → glow when ready
        -- Utility
		-- ["ready:106839"]  = { 106839 },                    -- Skull Bash                → glow when ready
		-- ["ready:78675"]  = { 78675 },   		               -- Solar Beam	        → glow when ready		
		-- ["ready:106839"]  = { 106839 },   		               -- Skull Bash	        → glow when ready		
		["ready:2782"]  = { 2782 },   		               -- Remove Corruption	        → glow when ready
		["ready:88423"]  = { 88423 },   		               -- Nature's Cure        → glow when ready
		["ready:2908"]  = { 2908 },   		               -- Soothe        	        → glow when ready
	},
    DEMONHUNTER = {
        -- Procs
        --["cdm:1225826"] = { 1225826 },                   -- Eradicate              → always glow if present in CDM
        --["cdm:1221150"] = { 1221150 },                   -- Collapsing Star        → always glow if present in CDM
        -- CDs
        ["ready:1217605"] = { 1217605 },                 -- Void Metamorphosis     → glow when ready
        ["ready:191427"]  = { 191427 },                  -- Metamorphosis          → glow when ready
        ["ready:473728"]  = { 473728 },                  -- Void Ray               → glow when ready
        -- Utility
        -- ["ready:183752"] = { 183752 },                   -- Disrupt                → glow when ready
        ["ready:278326"] = { 278326 },                   -- Consume Magic          → glow when ready
        ["ready:205604"] = { 205604 },                   -- Reverse Magic        → glow when ready
    },
    EVOKER = {
		-- Procs
        -- CDs        
        -- Utility
		-- ["ready:351338"] = { 351338 },                   -- Quell        → glow when ready
		["ready:374251"] = { 374251 },                   -- Cauterizing Flame         → glow when ready
		["ready:365585"] = { 365585 },                   -- Expunge         → glow when ready
		["ready:360823"] = { 360823 },                   -- Naturalize         → glow when ready		
		["ready:372048"] = { 372048 },                   -- Oppressing Roar         → glow when ready		
	},
}

-- ---------------------------------------------------------------------------
-- Classes that are exempt from Blizzard SpellActivationAlert suppression
-- (their native overlay always shows regardless of cdmGlowSuppressUntracked)
-- ---------------------------------------------------------------------------
local SUPPRESS_EXEMPT_CLASSES = {
    MAGE = true,
}

local CDMGlow = {
    spellsByAura       = {},
    trackedSpells      = {},
    spellToAura        = {},
    activeAuras        = {},
    overlayProcSpells  = {},
    readySpells        = {},
    baseCost           = {},
    activeGlowFrames   = {},
    frameSpellID       = {}, -- frame -> spellID currently shown there (refreshed every scan)
    lastCDMPresence    = {},
    _pendingUpdate    = false,
    _overlayUpdateGen = 0,
    _reanchorHooked   = false,
    _playerClass      = nil,
}

-- ---------------------------------------------------------------------------
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

-- Delegates to the shared dispatcher (same one Shared.lua uses) so CDM icon
-- glows and class-feature overlay glows can never drift out of sync again.
local function RequestGlow(frame, enabled, auraID, color)
    local overlay = GetOrCreateCDMOverlay(frame)
    if enabled then
        CXUI_Glow_Start(overlay, color or GLOW_COLOR)
    else
        CXUI_Glow_Stop(overlay)
    end
end

-- Called when the glow-style selector changes so already-active glows switch
-- engine immediately instead of waiting for their next aura state change.
-- (Attached to the CDMGlow table further below, once it exists.)

-- ---------------------------------------------------------------------------
-- NOTE: resource-based glow color (white when not enough Runic Power) was
-- attempted here and reverted. Confirmed via /console taintLog 1 that
-- comparing UnitPower("player", RunicPower) against any threshold is
-- UNCONDITIONALLY blocked as a "secret value" comparison — every single
-- call, not just when execution happens to carry taint. There is no
-- addon-visible number to compare against baseCost at all.
-- C_Spell.IsSpellUsable() was considered as a sanctioned alternative, but
-- it can't work either: the glow only shows while Sudden Doom is active,
-- and Sudden Doom is exactly what discounts Death Coil/Necrotic Coil's
-- cost (30 RP -> 15 RP) for that window, so IsSpellUsable would only ever
-- reflect the discounted cost, not the real 30 RP baseline — the one
-- case we'd want to flag as "actually low" always reads as "usable".
-- ---------------------------------------------------------------------------
-- ---------------------------------------------------------------------------
-- "ready:" spell check
-- ---------------------------------------------------------------------------

local function IsSpellReady(spellID)
    if not C_Spell then return false end
    local info = C_Spell.GetSpellCooldown and C_Spell.GetSpellCooldown(spellID)
    if not info then return false end
    local offCooldown = not info.isActive or info.isOnGCD
    if not offCooldown then return false end
    local ok, usable = pcall(C_Spell.IsSpellUsable, spellID)
    return ok and usable == true
end

-- ---------------------------------------------------------------------------
-- Shared spell registration helper
-- ---------------------------------------------------------------------------

local function RegisterClassSpells(class)
    if not PROC_CONFIG[class] then return end
    for auraID, spells in pairs(PROC_CONFIG[class]) do
        CDMGlow.spellsByAura[auraID] = spells
        for i = 1, #spells do
            CDMGlow.trackedSpells[spells[i]] = true
            if type(auraID) == "number" then
                CDMGlow.spellToAura[spells[i]] = auraID
            end
            if type(auraID) == "string" and auraID:sub(1, 6) == "ready:" then
                local sid = tonumber(auraID:sub(7))
                if sid then CDMGlow.readySpells[sid] = true end
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Frame scanning
-- ---------------------------------------------------------------------------
-- Every touch of a frame we don't own (IsForbidden, GetName, GetParent,
-- GetObjectType, GetChildren, raw field reads like frame.spellID) is now
-- wrapped in pcall. Forbidden/protected frames can throw on ANY field
-- access in current WoW clients, including the very first "is this safe"
-- check — so IsSafeFrame itself must be inside a pcall, not just the
-- checks that come after it. This mirrors the pattern Shared.lua already
-- uses for its CDM scanning (Shared.lua now identifies frames by spellID
-- this problem while Death Coil did: more CDM icons active at once in a
-- dungeon means ScanFrameTree walks more (and more varied) frames per
-- pass, so the odds of hitting one bad node — and silently aborting the
-- whole scan mid-recursion — go up a lot compared to a solo dummy.
-- ---------------------------------------------------------------------------

local function IsSecret(v)
    return type(_G.issecretvalue) == "function" and _G.issecretvalue(v) or false
end

local function IsSafeFrame(frame)
    if not frame then return false end
    local ok, forbidden = pcall(function()
        return frame.IsForbidden and frame:IsForbidden()
    end)
    if not ok then return false end
    if forbidden then return false end
    return true
end

local function GetButtonSpellID(frame)
    if not IsSafeFrame(frame) then return nil end

    local ok, sid = pcall(function()
        return frame.spellID or frame.spellId or frame.spellid
    end)
    if ok and type(sid) == "number" and not IsSecret(sid) then return sid end

    local ok2, v = pcall(function()
        if frame.GetSpellID then return frame:GetSpellID() end
        return nil
    end)
    if ok2 and type(v) == "number" and not IsSecret(v) then return v end

    return nil
end

local function ScanFrameTree(root, results, seen, depth)
    if not root or seen[root] or depth > 20 then return end
    if not IsSafeFrame(root) then return end
    seen[root] = true

    local ok, ot = pcall(function()
        return root.GetObjectType and root:GetObjectType()
    end)
    if ok and ot and (ot == "Button" or ot == "Frame") then
        local spellID = GetButtonSpellID(root)
        if spellID and CDMGlow.trackedSpells[spellID] then
            results[#results + 1] = { frame = root, spellID = spellID }
        end
    end

    local ok2, children = pcall(function()
        return root.GetChildren and { root:GetChildren() }
    end)
    if ok2 and children then
        for i = 1, #children do
            ScanFrameTree(children[i], results, seen, depth + 1)
        end
    end
end

local CDM_VIEWER_NAMES = {
    "EssentialCooldownViewer",
    "UtilityCooldownViewer",
    "BuffIconCooldownViewer",
    "CooldownViewer",
    "BlizzardCooldownFrame",
}

local function IsInCDMViewer(frame)
    local f = frame
    for i = 1, 10 do
        if not IsSafeFrame(f) then break end

        local ok, name = pcall(function()
            return f.GetName and f:GetName()
        end)
        if ok and name then
            for _, vname in ipairs(CDM_VIEWER_NAMES) do
                if name == vname then return true end
            end
        end

        local ok2, parent = pcall(function() return f:GetParent() end)
        if not ok2 or not parent then break end
        f = parent
    end
    return false
end

local function FindCurrentCDMFrames()
    local found = {}
    for auraID in pairs(CDMGlow.spellsByAura) do found[auraID] = {} end

    local results, seen = {}, {}
    for _, name in ipairs(CDM_VIEWER_NAMES) do
        if _G[name] then ScanFrameTree(_G[name], results, seen, 0) end
    end

    local smallest = {}
    for _, entry in ipairs(results) do
        local area = 999999
        pcall(function()
            local w, h = entry.frame:GetSize()
            area = w * h
        end)
        local prev = smallest[entry.spellID]
        if not prev or area < prev.area then
            smallest[entry.spellID] = { frame = entry.frame, area = area }
        end
    end

    local deduped = {}
    for spellID, entry in pairs(smallest) do
        deduped[#deduped + 1] = { frame = entry.frame, spellID = spellID }
    end

    table.wipe(CDMGlow.frameSpellID)
    for _, entry in ipairs(deduped) do
        CDMGlow.frameSpellID[entry.frame] = entry.spellID
        for auraID, spells in pairs(CDMGlow.spellsByAura) do
            for _, sid in ipairs(spells) do
                if sid == entry.spellID then
                    table.insert(found[auraID], entry.frame)
                end
            end
        end
    end

    return found
end

-- ---------------------------------------------------------------------------
-- Glow state management
-- ---------------------------------------------------------------------------

local function ApplyGlowState(auraID, hasAura, currentFrames)
    local newSet = {}
    if currentFrames then
        for _, f in ipairs(currentFrames) do newSet[f] = true end
    end

    local hasNewFrames = currentFrames and #currentFrames > 0

    if hasAura and hasNewFrames then
        for frame, fAuraID in pairs(CDMGlow.activeGlowFrames) do
            if fAuraID == auraID and not newSet[frame] then
                RequestGlow(frame, false, auraID)
                CDMGlow.activeGlowFrames[frame] = nil
            end
        end
        for _, frame in ipairs(currentFrames) do
            if CDMGlow.activeGlowFrames[frame] ~= auraID then
                RequestGlow(frame, true, auraID)
                CDMGlow.activeGlowFrames[frame] = auraID
            end
        end
    elseif hasAura and not hasNewFrames then
        -- keep existing glows alive during ForceReanchor
    elseif not hasAura then
        for frame, fAuraID in pairs(CDMGlow.activeGlowFrames) do
            if fAuraID == auraID then
                RequestGlow(frame, false, auraID)
                CDMGlow.activeGlowFrames[frame] = nil
            end
        end
    end
end

function CDMGlow:UpdateGlows()
    if not CXUI_DB.cdmGlow or not DB.enabled then
        for frame in pairs(self.activeGlowFrames) do
            RequestGlow(frame, false, "disabled")
        end
        table.wipe(self.activeGlowFrames)
        return
    end

    local currentFrames = FindCurrentCDMFrames()
    local now = GetTime()

    for auraID in pairs(self.spellsByAura) do
        local hasAura = false

        if type(auraID) == "string" and auraID:sub(1, 4) == "cdm:" then
            local hasFrames = currentFrames[auraID] ~= nil and #currentFrames[auraID] > 0
            if hasFrames then
                self.lastCDMPresence[auraID] = now
                hasAura = true
            elseif self.lastCDMPresence[auraID] then
                local age = now - self.lastCDMPresence[auraID]
                if age < 1.0 then
                    hasAura = true
                else
                    self.lastCDMPresence[auraID] = nil
                end
            end

        elseif type(auraID) == "string" and auraID:sub(1, 8) == "overlay:" then
            hasAura = self.overlayProcSpells[auraID] == true

        elseif type(auraID) == "string" and auraID:sub(1, 6) == "ready:" then
            local sid = tonumber(auraID:sub(7))
            hasAura = sid ~= nil and IsSpellReady(sid)

        else
            if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
                local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, auraID)
                hasAura = (ok and aura ~= nil)
            end
            if not hasAura and self.overlayProcSpells[auraID] then
                hasAura = true
            end
            if not hasAura and self:HasProcViaCost(auraID) then
                hasAura = true
            end
        end

        self.activeAuras[auraID] = hasAura
        ApplyGlowState(auraID, hasAura, currentFrames[auraID])
    end
end

-- Called when the glow-style selector changes so already-active glows switch
-- engine immediately instead of waiting for their next aura state change.
function CDMGlow:RefreshGlowStyle()
    for frame, auraID in pairs(self.activeGlowFrames) do
        RequestGlow(frame, true, auraID)
    end
end
ns.CDMGlow_RefreshStyle = function() if CDMGlow.RefreshGlowStyle then CDMGlow:RefreshGlowStyle() end end

function CDMGlow:UpdateGlowsAfterRescan()
    self:UpdateGlows()
end

-- ---------------------------------------------------------------------------
-- Runic power cost fallback
-- ---------------------------------------------------------------------------

local function GetSpellRunicCost(spellID)
    local rpType = (Enum and Enum.PowerType and Enum.PowerType.RunicPower) or 6
    if C_Spell and C_Spell.GetSpellPowerCost then
        local ok, costs = pcall(C_Spell.GetSpellPowerCost, spellID)
        if ok and costs then
            for i = 1, #costs do
                if costs[i].type == rpType then return costs[i].cost or costs[i].minCost end
            end
        end
    end
    return nil
end

function CDMGlow:UpdateBaselineCosts()
    for auraID, spells in pairs(self.spellsByAura) do
        for i = 1, #spells do
            local cost = GetSpellRunicCost(spells[i])
            if cost then self.baseCost[spells[i]] = math.max(self.baseCost[spells[i]] or 0, cost) end
        end
    end
end

function CDMGlow:HasProcViaCost(auraID)
    local spells = self.spellsByAura[auraID]
    if not spells then return false end
    for i = 1, #spells do
        local base    = self.baseCost[spells[i]]
        local current = GetSpellRunicCost(spells[i])
        if base and current and current <= (base - 1) then return true end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Rescan scheduler
-- ---------------------------------------------------------------------------

local rescanGen = 0

function CDMGlow:ScheduleRescan(delay)
    rescanGen = rescanGen + 1
    local gen = rescanGen
    C_Timer.After(delay or 0.2, function()
        if gen ~= rescanGen then return end
        self:UpdateGlowsAfterRescan()
    end)
end

-- ---------------------------------------------------------------------------
-- Combat safeguard ticker
-- ---------------------------------------------------------------------------

local safeguardTicker = nil

function CDMGlow:StartSafeguardTicker()
    if safeguardTicker then return end
    safeguardTicker = C_Timer.NewTicker(10, function()
        table.wipe(CDMGlow.lastCDMPresence)
        CDMGlow:ScheduleRescan(0.1)
    end)
end

function CDMGlow:StopSafeguardTicker()
    if safeguardTicker then safeguardTicker:Cancel(); safeguardTicker = nil end
end

-- ---------------------------------------------------------------------------
-- Full state reset (used on spec/hero-tree change)
-- ---------------------------------------------------------------------------

local function FullReset()
    for frame in pairs(CDMGlow.activeGlowFrames) do
        RequestGlow(frame, false, "reset")
    end
    table.wipe(CDMGlow.activeGlowFrames)
    table.wipe(CDMGlow.frameSpellID)
    table.wipe(CDMGlow.spellsByAura)
    table.wipe(CDMGlow.trackedSpells)
    table.wipe(CDMGlow.spellToAura)
    table.wipe(CDMGlow.activeAuras)
    table.wipe(CDMGlow.overlayProcSpells)
    table.wipe(CDMGlow.readySpells)
    table.wipe(CDMGlow.baseCost)
    table.wipe(CDMGlow.lastCDMPresence)
end

-- ---------------------------------------------------------------------------
-- Hook CDM
-- ---------------------------------------------------------------------------

function CDMGlow:HookCDM()
    if self._reanchorHooked then return end

    local cdm = _G["Ayije_CDM"]
    if cdm and cdm.ForceReanchor then
        hooksecurefunc(cdm, "ForceReanchor", function()
            CDMGlow:ScheduleRescan(0.2)
        end)
        self._reanchorHooked = true
    end

    local alertMgr = _G.ActionButtonSpellAlertManager
    if alertMgr and alertMgr.ShowAlert then
        hooksecurefunc(alertMgr, "ShowAlert", function(_, frame)
            if not CXUI_DB.cdmGlowSuppressUntracked then return end
            -- Classes in SUPPRESS_EXEMPT_CLASSES keep their native Blizzard overlay
            if SUPPRESS_EXEMPT_CLASSES[CDMGlow._playerClass] then return end
            if not IsSafeFrame(frame) then return end

            local alert = frame.SpellActivationAlert
            if alert then alert:SetAlpha(0); alert:Hide() end

            local spellID = GetButtonSpellID(frame)
            local inCDM = IsInCDMViewer(frame)

            if cdm and cdm.Glow and inCDM and spellID then
                pcall(function() cdm.Glow:StopGlow(frame) end)
            end
        end)
    end
end

-- ---------------------------------------------------------------------------
-- Slash commands
-- ---------------------------------------------------------------------------

SLASH_CDMGLOWDEBUG1 = "/cdmglow"
-- Standalone test frame — not tied to any real CDM icon, so you can verify
-- both glow styles instantly without waiting for a real proc.
local cxuiGlowTestFrame

local function GetOrCreateGlowTestFrame()
    if cxuiGlowTestFrame then return cxuiGlowTestFrame end
    local f = CreateFrame("Frame", "CXUI_GlowTestFrame", UIParent)
    f:SetSize(48, 48)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0, 0, 0, 0.6)
    local label = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    label:SetPoint("TOP", f, "BOTTOM", 0, -4)
    label:SetText("cxUI glow test")
    f.label = label
    cxuiGlowTestFrame = f
    return f
end

SlashCmdList["CDMGLOWDEBUG"] = function(msg)
    local cmd = (msg:match("^(%S+)") or msg):lower()

    if cmd == "debug" then
        local count = 0
        for _, name in ipairs(CDM_VIEWER_NAMES) do
            local viewer = _G[name]
            if viewer and viewer.GetChildren then
                local ok, children = pcall(function() return { viewer:GetChildren() } end)
                if ok and children then
                    for _, child in ipairs(children) do
                        if IsSafeFrame(child) then
                            local sid = GetButtonSpellID(child)
                            if sid then
                                count = count + 1
                                local fw, fh = child:GetSize()
                                local alert = child.SpellActivationAlert
                                local aw, ah = alert and alert:GetSize()
                                print(string.format(
                                    "|cff0070ddcxUI:|r [%d] spell=%-8s  frame=%dx%d  alert=%s",
                                    count, tostring(sid),
                                    math.floor(fw or 0), math.floor(fh or 0),
                                    alert and string.format("%dx%d", math.floor(aw or 0), math.floor(ah or 0)) or "none"
                                ))
                            end
                        end
                    end
                end
            end
        end
        if count == 0 then print("|cff0070ddcxUI:|r no CDM frames found") end

    elseif cmd == "diag" then
        local AddOnLoaded = (C_AddOns and C_AddOns.IsAddOnLoaded) or IsAddOnLoaded
        print("|cff0070ddcxUI:|r === glow diag ===")
        print(("|cff0070ddcxUI:|r EllesmereUI loaded=%s  ElvUI global=%s  EllesmereUI global=%s"):format(
            tostring(AddOnLoaded and AddOnLoaded("EllesmereUI")),
            tostring(_G.ElvUI ~= nil),
            tostring(_G.EllesmereUI ~= nil)
        ))

        local function DumpChain(f, label)
            print(("|cff0070ddcxUI:|r -- %s --"):format(label))
            local n, depth = f, 0
            while n and depth < 12 do
                local ok, name = pcall(function() return n.GetName and n:GetName() end)
                if not ok then name = nil end
                local w, h = 0, 0
                pcall(function() w, h = n:GetSize() end)
                local scale, es = 1, 1
                pcall(function() scale = n:GetScale() end)
                pcall(function() es = n:GetEffectiveScale() end)
                local strata, level = "?", "?"
                pcall(function() strata = n:GetFrameStrata() end)
                pcall(function() level = n:GetFrameLevel() end)
                print(("  [%d] %-28s size=%s x %s  scale=%.4f  effScale=%.4f  strata=%s  level=%s"):format(
                    depth, tostring(name or "<anon>"),
                    tostring(w and string.format("%.1f", w)), tostring(h and string.format("%.1f", h)),
                    scale or 1, es or 1, tostring(strata), tostring(level)
                ))
                -- Anchor point detail for the first 2 levels only (target
                -- frame + its direct parent) — this tells us whether
                -- SetAllPoints actually took effect, and if not, what points
                -- (if any) the frame actually has instead.
                if depth <= 1 then
                    local ok3, numPoints = pcall(function() return n:GetNumPoints() end)
                    if ok3 and numPoints then
                        print(("      numPoints=%d"):format(numPoints))
                        for i = 1, numPoints do
                            local ok4, point, relTo, relPoint, x, y = pcall(function() return n:GetPoint(i) end)
                            if ok4 then
                                local relName = "?"
                                pcall(function() relName = (relTo and relTo.GetName and relTo:GetName()) or (relTo and tostring(relTo)) or "nil" end)
                                print(("        [%d] point=%s relativeTo=%s relativePoint=%s x=%s y=%s"):format(
                                    i, tostring(point), tostring(relName), tostring(relPoint), tostring(x), tostring(y)))
                            end
                        end
                    else
                        print("      (GetNumPoints failed or unavailable)")
                    end
                end
                local ok2, p = pcall(function() return n:GetParent() end)
                n = ok2 and p or nil
                depth = depth + 1
            end
        end

        local function DumpIconTexture(icon)
            local tex = icon.icon or icon.Icon or (icon.GetNormalTexture and icon:GetNormalTexture())
            if not tex then print("  (no icon texture found: tried icon.icon / icon.Icon / GetNormalTexture)"); return end
            local desat, alpha, blend = "?", "?", "?"
            pcall(function() desat = tex:IsDesaturated() end)
            pcall(function() alpha = tex:GetAlpha() end)
            pcall(function() blend = tex:GetBlendMode() end)
            local r, g, b, a = 1, 1, 1, 1
            pcall(function() r, g, b, a = tex:GetVertexColor() end)
            print(("  icon texture: desaturated=%s alpha=%s blend=%s vertexColor=%.2f,%.2f,%.2f,%.2f"):format(
                tostring(desat), tostring(alpha), tostring(blend), r, g, b, a))
        end

        local count = 0
        for frame, sid in pairs(CDMGlow.frameSpellID) do
            if IsSafeFrame(frame) then
                count = count + 1
                DumpChain(frame, ("production-selected icon spell=%s"):format(tostring(sid)))
                DumpIconTexture(frame)
                local overlay = cdmOverlays[frame]
                if overlay then
                    DumpChain(overlay, "our overlay child")
                    if overlay._CXUI_PixelGlow then
                        local pf = overlay._CXUI_PixelGlow
                        DumpChain(pf, "our pixel glow frame")
                        print(("   shown=%s alpha=%.2f"):format(tostring(pf:IsShown()), pf:GetAlpha()))
                    end
                    if overlay._CXUI_CDMGlow then
                        local cf = overlay._CXUI_CDMGlow
                        DumpChain(cf, "our proc glow frame")
                        print(("   shown=%s alpha=%.2f"):format(tostring(cf:IsShown()), cf:GetAlpha()))
                    end
                else
                    print("  (no cxUI overlay created yet for this icon)")
                end
                if count >= 4 then break end
            end
        end
        if count == 0 then print("|cff0070ddcxUI:|r no CDM frames found for diag (CDMGlow.frameSpellID empty — UpdateGlows hasn't run or found nothing)") end

        print("|cff0070ddcxUI:|r -- cdmOverlays cache (every icon that ever got a glow) --")
        local n = 0
        for iconFrame, overlay in pairs(cdmOverlays) do
            n = n + 1
            local sid = GetButtonSpellID(iconFrame)
            DumpChain(iconFrame, ("cached icon #%d spell=%s"):format(n, tostring(sid)))
            DumpIconTexture(iconFrame)
            DumpChain(overlay, "  -> overlay")
            if overlay._CXUI_PixelGlow then
                local pf = overlay._CXUI_PixelGlow
                DumpChain(pf, "  -> pixel glow frame")
                print(("     shown=%s alpha=%.2f"):format(tostring(pf:IsShown()), pf:GetAlpha()))
            end
            if overlay._CXUI_CDMGlow then
                local cf = overlay._CXUI_CDMGlow
                DumpChain(cf, "  -> proc glow frame")
                print(("     shown=%s alpha=%.2f"):format(tostring(cf:IsShown()), cf:GetAlpha()))
            end
        end
        if n == 0 then print("  (cdmOverlays cache is empty — no glow has ever been requested on a real icon this session)") end
        print("|cff0070ddcxUI:|r === end diag ===")

    elseif cmd == "test" then
        local f = GetOrCreateGlowTestFrame()
        f:Show()
        -- Bypass the pcall-wrapped dispatcher here on purpose: if something
        -- actually errors during setup, we want to SEE it, not have it
        -- silently swallowed like it would be in normal gameplay use.
        if CXUI_DB.cdmGlowStyle == "pixel" then
            pcall(CXUI_CDMGlow_Stop, f)
            local ok, err = pcall(CXUI_PixelGlow_Start, f, nil)
            if not ok then print("|cffff2020cxUI pixel glow error:|r " .. tostring(err)) end
        else
            pcall(CXUI_PixelGlow_Stop, f)
            local ok, err = pcall(CXUI_CDMGlow_Start, f, nil)
            if not ok then print("|cffff2020cxUI proc glow error:|r " .. tostring(err)) end
        end
        print(("|cff0070ddcxUI:|r test glow shown at screen center, style = %s"):format(tostring(CXUI_DB.cdmGlowStyle)))
        print("|cff0070ddcxUI:|r pixel glow expects these files to exist:")
        print("  " .. PIXELGLOW_TEX_H)
        print("  " .. PIXELGLOW_TEX_V)
        print("|cff0070ddcxUI:|r /cdmglow testoff to hide it")

    elseif cmd == "testoff" then
        if cxuiGlowTestFrame then
            CXUI_Glow_Stop(cxuiGlowTestFrame)
            cxuiGlowTestFrame:Hide()
        end
        print("|cff0070ddcxUI:|r test glow hidden")

    else
        print("|cff0070ddcxUI:|r /cdmglow debug     — CDM frames in viewers")
        print("|cff0070ddcxUI:|r /cdmglow diag      — dump scale/level/strata chain + icon texture state for real CDM icons")
        print("|cff0070ddcxUI:|r /cdmglow test      — show a test glow at screen center (current style)")
        print("|cff0070ddcxUI:|r /cdmglow testoff   — hide the test glow")
    end
end

-- ---------------------------------------------------------------------------
-- Event handler
-- ---------------------------------------------------------------------------

local procEventFrame = CreateFrame("Frame")
procEventFrame:RegisterEvent("PLAYER_LOGIN")
procEventFrame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LOGIN" then
        local _, class = UnitClass("player")
        CDMGlow._playerClass = class
        RegisterClassSpells(class)

        self:RegisterEvent("UNIT_AURA")
        self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
        self:RegisterEvent("PLAYER_TALENT_UPDATE")
        self:RegisterEvent("PLAYER_REGEN_DISABLED")
        self:RegisterEvent("PLAYER_REGEN_ENABLED")
        self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
        self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
        self:RegisterEvent("SPELL_UPDATE_COOLDOWN")
        self:RegisterEvent("SPELL_UPDATE_USABLE")
        self:RegisterEvent("PLAYER_ENTERING_WORLD")
        self:RegisterEvent("UNIT_PET")

        C_Timer.After(1.5, function()
            CDMGlow:HookCDM()
            CDMGlow:UpdateBaselineCosts()
            CDMGlow:UpdateGlows()
        end)

    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        FullReset()
        C_Timer.After(0.5, function()
            local _, class = UnitClass("player")
            CDMGlow._playerClass = class
            RegisterClassSpells(class)
            CDMGlow:UpdateBaselineCosts()
            CDMGlow:UpdateGlows()
        end)

    elseif event == "PLAYER_TALENT_UPDATE" then
        -- Hero talent tree changed within the same spec
        FullReset()
        C_Timer.After(0.5, function()
            local _, class = UnitClass("player")
            CDMGlow._playerClass = class
            RegisterClassSpells(class)
            CDMGlow:UpdateBaselineCosts()
            CDMGlow:UpdateGlows()
        end)

    elseif event == "PLAYER_REGEN_DISABLED" then
        CDMGlow:StartSafeguardTicker()

    elseif event == "PLAYER_REGEN_ENABLED" then
        CDMGlow:StopSafeguardTicker()
        table.wipe(CDMGlow.lastCDMPresence)
        CDMGlow:ScheduleRescan(0.3)

    elseif event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(1.0, function()
            CDMGlow:HookCDM()
            CDMGlow:UpdateGlows()
        end)

    elseif event == "UNIT_PET" then
        CDMGlow:ScheduleRescan(0.2)

    elseif event == "UNIT_AURA" and (...) == "player" then
        if not CDMGlow._pendingUpdate then
            CDMGlow._pendingUpdate = true
            C_Timer.After(0.1, function()
                CDMGlow._pendingUpdate = false
                CDMGlow:UpdateGlows()
            end)
        end

    elseif event == "SPELL_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_USABLE" then
        if next(CDMGlow.readySpells) then
            if not CDMGlow._pendingUpdate then
                CDMGlow._pendingUpdate = true
                C_Timer.After(0.1, function()
                    CDMGlow._pendingUpdate = false
                    CDMGlow:UpdateGlows()
                end)
            end
        end

    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
        local sid = ...
        local overlayKey = "overlay:" .. sid
        if CDMGlow.spellsByAura[overlayKey] then
            CDMGlow.overlayProcSpells[overlayKey] = true
            CDMGlow:UpdateGlows()
        else
            local auraID = CDMGlow.spellToAura[sid]
            if auraID then
                CDMGlow.overlayProcSpells[auraID] = true
                CDMGlow._overlayUpdateGen = CDMGlow._overlayUpdateGen + 1
                local gen = CDMGlow._overlayUpdateGen
                C_Timer.After(0.15, function()
                    if gen ~= CDMGlow._overlayUpdateGen then return end
                    CDMGlow:UpdateGlows()
                end)
            end
        end

    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        local sid = ...
        local overlayKey = "overlay:" .. sid
        if CDMGlow.spellsByAura[overlayKey] then
            CDMGlow.overlayProcSpells[overlayKey] = nil
            CDMGlow:UpdateGlows()
        else
            local auraID = CDMGlow.spellToAura[sid]
            if auraID and CDMGlow.overlayProcSpells[auraID] then
                local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, auraID)
                if ok and aura ~= nil then
                    if not CDMGlow._pendingUpdate then
                        CDMGlow._pendingUpdate = true
                        C_Timer.After(0.1, function()
                            CDMGlow._pendingUpdate = false
                            for aID in pairs(CDMGlow.overlayProcSpells) do
                                local ok2, aura2 = pcall(C_UnitAuras.GetPlayerAuraBySpellID, aID)
                                if ok2 and aura2 == nil then
                                    CDMGlow.overlayProcSpells[aID] = nil
                                end
                            end
                            CDMGlow:UpdateGlows()
                        end)
                    end
                else
                    CDMGlow.overlayProcSpells[auraID] = nil
                    CDMGlow:UpdateGlows()
                end
            end
        end
    end
end)