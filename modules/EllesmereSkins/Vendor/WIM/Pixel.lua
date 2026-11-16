local _, cxns = ...
-- Vendored from EllesmereSkin_WIM/Pixel.lua, unchanged.
-- Wrapped in a function so cxUI can run it once the addon it skins has loaded
-- (see Sk.RunChunks in EllesmereSkins.lua). Its own header follows.
local chunks = cxns.ESkin.chunks
chunks.WIM = chunks.WIM or {}
table.insert(chunks.WIM, function(...)
-------------------------------------------------------------------------------
--  EllesmereSkin_WIM -- Pixel.lua
--
--  The 1px border engine. Two backends, same public API:
--
--    bridged    -> delegate straight to EllesmereUI.PanelPP.CreateBorder. The
--                  border is then literally the same object type as every other
--                  border in the user's UI, and is re-snapped by EUI's own
--                  global resnap passes on UI-scale / resolution changes.
--    standalone -> a faithful port of EUI's algorithm:
--                    * 4 WHITE8X8 texture strips, NOT a BackdropTemplate
--                      (NineSlice corners render as black boxes on some frames)
--                    * SetSnapToPixelGrid(false) + SetTexelSnappingBias(0) so a
--                      1px strip never rounds to 0 and vanishes at fractional
--                      scales
--                    * edge size = 768/physicalHeight / effectiveScale, i.e. one
--                      TRUE physical pixel regardless of UI scale
--                    * a 2-tick OnUpdate re-snap to catch the final effective
--                      scale after layout settles
--                    * re-snap on UI_SCALE_CHANGED / DISPLAY_SIZE_CHANGED
--
--  WIM windows are user-resizable, so borders must also re-snap on size change;
--  that is wired up by the caller via Pixel.Attach().
-------------------------------------------------------------------------------
local ADDON_NAME, ns = ...

local Pixel = {}
ns.Pixel = Pixel

local WHITE = "Interface\\Buttons\\WHITE8X8"

-------------------------------------------------------------------------------
--  Standalone pixel maths (mirrors EllesmereUI's PP.perfect / PP.mult)
-------------------------------------------------------------------------------
local PP = { perfect = 1/768, mult = 1 }

local function RecalcScale()
    local physicalHeight = select(2, GetPhysicalScreenSize())
    if not physicalHeight or physicalHeight <= 0 then physicalHeight = 768 end
    PP.perfect = 768 / physicalHeight
    local uiScale = (UIParent and UIParent:GetScale()) or 1
    if uiScale <= 0 then uiScale = 1 end
    PP.mult = PP.perfect / uiScale
end

local function DisablePixelSnap(tx)
    if not tx then return end
    if tx.SetSnapToPixelGrid then tx:SetSnapToPixelGrid(false) end
    if tx.SetTexelSnappingBias then tx:SetTexelSnappingBias(0) end
end

-- Registry of standalone borders so we can resnap them globally. Weak keys:
-- a collected WIM window must not be kept alive by this table.
local registry = setmetatable({}, { __mode = "k" })

local function SnapBorder(container, frame, borderSize)
    if not container or not frame then return end
    if not container.GetEffectiveScale then return end
    local ok, es = pcall(container.GetEffectiveScale, container)
    if not ok or not es or es <= 0 then return end

    local onePixel = PP.perfect / es
    local bs = borderSize or 1
    local edge = math.max(onePixel, math.floor(bs + 0.5) * onePixel)

    local t, b, l, r = container._top, container._bottom, container._left, container._right
    if not t then return end

    t:ClearAllPoints()
    t:SetPoint("TOPLEFT",  frame, "TOPLEFT",  0, 0)
    t:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    t:SetHeight(edge)

    b:ClearAllPoints()
    b:SetPoint("BOTTOMLEFT",  frame, "BOTTOMLEFT",  0, 0)
    b:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    b:SetHeight(edge)

    -- Sides inset by one edge so corners meet flush with no overdraw notch.
    l:ClearAllPoints()
    l:SetPoint("TOPLEFT",    frame, "TOPLEFT",    0, -edge)
    l:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0,  edge)
    l:SetWidth(edge)

    r:ClearAllPoints()
    r:SetPoint("TOPRIGHT",    frame, "TOPRIGHT",    0, -edge)
    r:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0,  edge)
    r:SetWidth(edge)
end

local function CreateBorderStandalone(frame, r, g, b, a, borderSize, drawLayer, subLevel)
    if registry[frame] then return registry[frame].container end

    r = r or 0; g = g or 0; b = b or 0; a = a or 1
    borderSize = borderSize or 1
    drawLayer  = drawLayer or "OVERLAY"
    subLevel   = subLevel or 0

    local container = CreateFrame("Frame", nil, frame)
    container:SetAllPoints(frame)
    container:SetFrameLevel(frame:GetFrameLevel() + 1)

    local function MakeTex()
        local tx = container:CreateTexture(nil, drawLayer, nil, subLevel)
        tx:SetTexture(WHITE)
        tx:SetVertexColor(r, g, b, a)
        DisablePixelSnap(tx)
        return tx
    end
    container._top    = MakeTex()
    container._bottom = MakeTex()
    container._left   = MakeTex()
    container._right  = MakeTex()
    container._color  = { r, g, b, a }

    registry[frame] = { container = container, borderSize = borderSize }

    SnapBorder(container, frame, borderSize)

    -- Re-snap for 2 frames: effective scale is not final until layout settles.
    local ticks = 0
    container:SetScript("OnUpdate", function(self)
        ticks = ticks + 1
        SnapBorder(self, frame, borderSize)
        if ticks >= 2 then self:SetScript("OnUpdate", nil) end
    end)

    return container
end

-------------------------------------------------------------------------------
--  Public API
-------------------------------------------------------------------------------

--- Create a 1px border around `frame`. Idempotent per frame.
function Pixel.CreateBorder(frame, r, g, b, a, borderSize, drawLayer, subLevel)
    if not frame then return nil end

    local E = _G.EllesmereUI
    local EPP = E and (E.PanelPP or E.PP)
    if EPP and EPP.CreateBorder then
        local ok, container = pcall(EPP.CreateBorder, frame, r, g, b, a,
                                    borderSize or 1, drawLayer or "OVERLAY", subLevel or 7)
        if ok and container then return container end
        -- If EUI's engine errored for any reason, fall through to standalone
        -- rather than leaving the window borderless.
    end

    return CreateBorderStandalone(frame, r, g, b, a, borderSize, drawLayer, subLevel)
end

--- Recolour an existing border (bridged or standalone).
function Pixel.SetBorderColor(frame, r, g, b, a)
    if not frame then return end
    a = a or 1

    local E = _G.EllesmereUI
    local EPP = E and (E.PanelPP or E.PP)
    if EPP and EPP.SetBorderColor and EPP.GetBorders and EPP.GetBorders(frame) then
        pcall(EPP.SetBorderColor, frame, r, g, b, a)
        return
    end

    local entry = registry[frame]
    if not entry then return end
    local c = entry.container
    c._color = { r, g, b, a }
    for _, tx in ipairs({ c._top, c._bottom, c._left, c._right }) do
        if tx then tx:SetVertexColor(r, g, b, a) end
    end
end

--- Force a re-snap of a single frame's border. Call after a resize.
function Pixel.Resnap(frame)
    if not frame then return end

    local E = _G.EllesmereUI
    local EPP = E and (E.PanelPP or E.PP)
    if EPP and EPP.GetBorders and EPP.GetBorders(frame) then
        -- EUI recomputes geometry inside SetBorderSize; re-asserting 1 is the
        -- cheapest public way to force a snap without touching its internals.
        if EPP.SetBorderSize then pcall(EPP.SetBorderSize, frame, 1) end
        return
    end

    local entry = registry[frame]
    if entry then
        SnapBorder(entry.container, frame, entry.borderSize)
    end
end

--- Attach live re-snapping to a resizable frame.
function Pixel.Attach(frame)
    if not frame or frame._eskwimAttached then return end
    frame._eskwimAttached = true
    frame:HookScript("OnSizeChanged", function(self)
        Pixel.Resnap(self)
    end)
end

--- Size of ONE physical screen pixel in `frame`'s own coordinate space.
--  Used to lay out pixel-art glyphs on the true pixel grid, so a "2px" cell is
--  exactly 2 screen pixels at any UI scale / window scale.
function Pixel.OnePixel(frame)
    if not frame or not frame.GetEffectiveScale then return nil end
    local ok, es = pcall(frame.GetEffectiveScale, frame)
    if not ok or not es or es <= 0 then return nil end
    return PP.perfect / es
end

Pixel.DisablePixelSnap = DisablePixelSnap

-------------------------------------------------------------------------------
--  Global resnap on scale / resolution change (standalone borders only --
--  EllesmereUI already runs its own global pass for bridged ones).
-------------------------------------------------------------------------------
local watcher = CreateFrame("Frame")
watcher:RegisterEvent("PLAYER_LOGIN")
watcher:RegisterEvent("UI_SCALE_CHANGED")
watcher:RegisterEvent("DISPLAY_SIZE_CHANGED")
watcher:SetScript("OnEvent", function()
    RecalcScale()
    for frame, entry in pairs(registry) do
        if frame and entry and entry.container then
            SnapBorder(entry.container, frame, entry.borderSize)
        end
    end
end)

RecalcScale()
end)
