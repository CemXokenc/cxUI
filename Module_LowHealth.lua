local addonName, ns = ...

-- ===========================================================================
-- MODULE: LOW HEALTH ALERT
-- ===========================================================================

local function OnLowHealthShow()
    -- English: Logic directly from provided LHH code
    if CXUI_DB and CXUI_DB.lowHealthAlert then
        -- English: Using your custom path and "Master" channel as requested
        PlaySoundFile("Interface\\AddOns\\cxUI\\Media\\lowhp.ogg", "Master")
    end
end

-- English: Implementation of LHH:CreateMainFrame() hook logic
-- English: We hook the Blizzard's own LowHealthFrame just like the original addon
if LowHealthFrame then
    LowHealthFrame:HookScript("OnShow", OnLowHealthShow)
end