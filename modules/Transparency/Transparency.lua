local addonName, ns = ...

-- ===========================================================================
-- MODULE: TRANSPARENCY
-- Shared helpers for ActionBars.lua / MicroMenu.lua / QuestTracker.lua:
--   * one 0.1s tick driver (its OnUpdate exists only while a feature is on)
--   * SetAlpha guard so other code can't un-hide a managed frame
-- ===========================================================================

local T = ns:NewModule("Transparency", {
    name  = "Transparency",
    desc  = "Auto-hide action bars, micro menu and quest tracker",
    order = 1,
})

-- ---------------------------------------------------------------------------
-- Tick driver
-- ---------------------------------------------------------------------------
local UPDATE_INTERVAL = 0.1
local ticks = {}
local sinceLast = 0
local driver = CreateFrame("Frame")

local function OnUpdate(_, elapsed)
    sinceLast = sinceLast + elapsed
    if sinceLast < UPDATE_INTERVAL then return end
    sinceLast = 0
    for _, fn in pairs(ticks) do fn() end
end

function T.AddTick(id, fn)
    ticks[id] = fn
    driver:SetScript("OnUpdate", OnUpdate)
end

function T.RemoveTick(id)
    ticks[id] = nil
    if not next(ticks) then driver:SetScript("OnUpdate", nil) end
end

-- ---------------------------------------------------------------------------
-- Alpha guard
-- Installed once per frame. getWanted() returns the alpha to enforce, or nil
-- when the owning feature is off (then nothing is enforced).
-- ---------------------------------------------------------------------------
local guards, busy = {}, {}

function T.GuardAlpha(frame, getWanted)
    if not frame or guards[frame] then return end
    guards[frame] = getWanted
    hooksecurefunc(frame, "SetAlpha", function(self, alpha)
        if busy[self] then return end
        local wanted = guards[self]()
        if wanted == nil then return end
        if alpha ~= wanted then
            busy[self] = true
            self:SetAlpha(wanted)
            busy[self] = false
        end
    end)
end
