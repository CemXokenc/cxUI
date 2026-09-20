local addonName, ns = ...

-- ===========================================================================
-- MODULE: CLASS FEATURES
-- Shared file. One file per feature lives next to this one:
--   EnemyCounter, NoMovement                       (all classes)
--   FesteringGlow, PutrefyCross, ReaperCross,
--   FrostBarSwap                                   (Death Knight)
--   FlurryCross                                    (Mage)
--   BurningRushReminder                            (Warlock)
--   ExecuteAlert                                   (Warrior)
--
-- Provided here:
--   * CDM overlay helpers (glow / red X cross on a CDM icon)
--   * CF.AddRescan / CF.RemoveRescan: one shared scheduler that tells features
--     when to re-find their CDM icons (login, zone change, spec change, CDM
--     re-anchor). Its events exist only while at least one feature listens.
--   * /cxaoe debug command (features add their own status line)
-- ===========================================================================

local CF = ns:NewModule("ClassFeatures", {
    name  = "Class Features",
    desc  = "Class-specific overlays and alerts",
    order = 3,
})

local CDM = ns:GetModule("CDM")

CF.ScanFramesBySpellID = CDM.ScanFramesBySpellID

-- ---------------------------------------------------------------------------
-- Overlay helpers (delegate to the single CDM glow engine)
-- ---------------------------------------------------------------------------
function CF.CreateOverlay(cdmFrame)
    local ov = CDM.GetOrCreateOverlay(cdmFrame)
    ov._targetFrame = cdmFrame
    ov._glowActive  = false
    ov:Hide()
    return ov
end

function CF.StartGlow(overlay)
    if overlay._glowActive then return end
    overlay._glowActive = true
    overlay:Show()
    ns.CXUI_Glow_Start(overlay, CDM.glowColor)
end

function CF.StopGlow(overlay)
    if not overlay._glowActive then return end
    overlay._glowActive = false
    ns.CXUI_Glow_Stop(overlay)
    overlay:Hide()
end

local X_THICK = 5

function CF.AttachXCross(overlay)
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

function CF.ShowXCross(overlay)
    CF.AttachXCross(overlay)
    if overlay._xl1 then overlay._xl1:Show(); overlay._xl2:Show() end
    overlay:Show()
end

function CF.HideXCross(overlay)
    if overlay._xl1 then overlay._xl1:Hide(); overlay._xl2:Hide() end
    overlay:Hide()
end

-- ---------------------------------------------------------------------------
-- Rescan scheduler
-- Features that decorate CDM icons register a rescan function. It runs shortly
-- after login / zone change (with retries, CDM builds its icons late), after a
-- spec change, and after the CDM re-anchors its icons.
-- ---------------------------------------------------------------------------
local listeners = {}
local pending   = {} -- [id] = { timer, ... } so RemoveRescan can cancel them
local RETRY_DELAYS = { 3, 6, 10, 15 }

local function Run(id, fn)
    if listeners[id] ~= fn then return end -- removed or replaced meanwhile
    pcall(fn)
end

local function Later(id, fn, delay)
    local list = pending[id]
    if not list then list = {}; pending[id] = list end
    list[#list + 1] = C_Timer.NewTimer(delay, function() Run(id, fn) end)
end

local function ScheduleOne(id, fn, firstDelay, retry)
    Later(id, fn, firstDelay)
    if retry then
        for _, delay in ipairs(RETRY_DELAYS) do Later(id, fn, delay) end
    end
end

local function ScheduleAll(firstDelay, retry)
    for id, fn in pairs(listeners) do ScheduleOne(id, fn, firstDelay, retry) end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_ENTERING_WORLD" then
        ScheduleAll(1, true)
    else -- PLAYER_SPECIALIZATION_CHANGED
        ScheduleAll(2, false)
    end
end)

function CF.AddRescan(id, fn)
    local first = not next(listeners)
    listeners[id] = fn
    if first then
        events:RegisterEvent("PLAYER_ENTERING_WORLD")
        events:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
    end
    CDM.AddReanchorListener("ClassFeatures:" .. id, fn)
    ScheduleOne(id, fn, 1, true)
end

function CF.RemoveRescan(id)
    listeners[id] = nil
    for _, t in ipairs(pending[id] or {}) do t:Cancel() end
    pending[id] = nil
    CDM.RemoveReanchorListener("ClassFeatures:" .. id)
    if not next(listeners) then events:UnregisterAllEvents() end
end

function CF.RescanAll()
    for id, fn in pairs(listeners) do Run(id, fn) end
end

-- ---------------------------------------------------------------------------
-- /cxaoe  (Death Knight debug helper; features register status providers)
-- ---------------------------------------------------------------------------
local statusProviders, debugToggles = {}, {}
function CF.RegisterStatus(fn) statusProviders[#statusProviders + 1] = fn end
function CF.OnDebugToggle(fn) debugToggles[#debugToggles + 1] = fn end

SLASH_CXAOEDEBUG1 = "/cxaoe"
SlashCmdList["CXAOEDEBUG"] = function(msg)
    local cmd = (msg or ""):lower()
    if cmd == "scan" or cmd == "status" then
        if cmd == "scan" then CF.RescanAll() end
        ns.Print("spec=" .. tostring(GetSpecialization()) .. "  barpage=" .. tostring(GetActionBarPage()))
        for _, fn in ipairs(statusProviders) do
            local line = fn()
            if line then ns.Print(line) end
        end
    elseif cmd == "debug" then
        CXUI_DB.cxaoeDebugFestering = not CXUI_DB.cxaoeDebugFestering
        for _, fn in ipairs(debugToggles) do pcall(fn, CXUI_DB.cxaoeDebugFestering) end
        ns.Print("festering debug logging " .. (CXUI_DB.cxaoeDebugFestering and "ON" or "OFF"))
    else
        ns.Print("/cxaoe [scan|status|debug]")
    end
end
