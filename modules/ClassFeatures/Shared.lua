local addonName, ns = ...

-- ===========================================================================
-- CLASS FEATURES: SHARED UTILITIES
-- Loaded first. Exports helpers to ns.CF for DeathKnight.lua and Mage.lua.
-- Supported classes: Death Knight (6) · Mage (8)
-- ===========================================================================

local _, _, CLASS_ID = UnitClass("player")

-- Expose class ID so sibling files can guard themselves.
ns.CF = { CLASS_ID = CLASS_ID }

if CLASS_ID ~= 6 and CLASS_ID ~= 8 then return end

local LCG = LibStub and LibStub("LibCustomGlow-1.0", true)
ns.CF.LCG = LCG

-- ---------------------------------------------------------------------------
-- EnumerateFrames scan — finds CDM buttons by texture string ID
-- ---------------------------------------------------------------------------

local function ScanFramesByTexture(texStrings, callback)
    local frame = EnumerateFrames()
    while frame do
        if frame.Icon and type(frame.Icon) == "table" and frame.Icon.GetTexture then
            local ok, matched = pcall(function()
                local tex = frame.Icon:GetTexture()
                if tex then
                    local texStr = tostring(tex)
                    for _, t in ipairs(texStrings) do
                        if texStr == t then return true end
                    end
                end
                return false
            end)
            if ok and matched then callback(frame) end
        end
        frame = EnumerateFrames(frame)
    end
end

-- ---------------------------------------------------------------------------
-- Overlay helpers
-- ---------------------------------------------------------------------------

-- Overlay parented directly to CDM frame (moves with it).
local function CreateOverlay(cdmFrame)
    local ov = CreateFrame("Frame", nil, cdmFrame)
    ov:SetFrameStrata("TOOLTIP")
    ov:SetAllPoints(cdmFrame)
    ov:SetFrameLevel(cdmFrame:GetFrameLevel() + 10)
    ov._targetFrame = cdmFrame
    ov._glowActive  = false
    ov:Hide()
    return ov
end

-- Same colour and function as CDMGlow so all addon glows look identical.
local GLOW_COLOR = { 1, 0.82, 0, 0.9 }

local function StartGlow(overlay)
    if overlay._glowActive then return end
    overlay._glowActive = true
    overlay:Show()
    if LCG and LCG.ProcGlow_Start then
        LCG.ProcGlow_Start(overlay, { color = GLOW_COLOR, startAnim = false })
    end
end

local function StopGlow(overlay)
    if not overlay._glowActive then return end
    overlay._glowActive = false
    if LCG and LCG.ProcGlow_Stop then LCG.ProcGlow_Stop(overlay) end
    overlay:Hide()
end

-- Red × cross (two diagonal lines, 5px thick).
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

-- ---------------------------------------------------------------------------
-- Export
-- ---------------------------------------------------------------------------

local CF = ns.CF
CF.ScanFramesByTexture = ScanFramesByTexture
CF.CreateOverlay       = CreateOverlay
CF.StartGlow           = StartGlow
CF.StopGlow            = StopGlow
CF.AttachXCross        = AttachXCross
CF.ShowXCross          = ShowXCross
CF.HideXCross          = HideXCross