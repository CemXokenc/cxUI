local addonName, ns = ...
-- ===========================================================================
-- MODULE: SMALL TWEAKS -> AUTO CONFIRM (debug build)
-- ===========================================================================

CXUI_AutoConfirmDebug = CXUI_AutoConfirmDebug or false

local function Debug(...)
    if CXUI_AutoConfirmDebug then
        print("|cff33ccff[cxUI AutoConfirm]|r", ...)
    end
end

local WHITELIST = {
    CONFIRM_PURCHASE_TOKEN_ITEM    = true,
    CONFIRM_MAIL_ITEM_UNREFUNDABLE = true,
}

local function IsAutoConfirmEnabled()
    return CXUI_DB and CXUI_DB.autoConfirm
end

local function TryAutoConfirm(which)
    Debug("StaticPopup_Show fired, which =", tostring(which))

    if not IsAutoConfirmEnabled() then
        Debug("  -> skip: autoConfirm is OFF in CXUI_DB")
        return
    end
    if not WHITELIST[which] then
        Debug("  -> skip: '", tostring(which), "' not in WHITELIST")
        return
    end

    -- Use Blizzard's own lookup instead of manually scanning StaticPopup1..N.
    -- More robust against skinning addons, popup pooling changes, or delayed
    -- :Show() calls.
    -- StaticPopup_Visible() returns the FRAME NAME as a string (e.g.
    -- "StaticPopup1"), not the frame object itself. Resolve it.
    local dialogName = StaticPopup_Visible(which)
    local dialog = dialogName and _G[dialogName]

    if not dialog then
        Debug("  -> StaticPopup_Visible returned nil, falling back to manual scan")
        local i = 1
        while true do
            local d = _G["StaticPopup" .. i]
            if not d then break end
            Debug("     scanning StaticPopup" .. i, "which=", tostring(d.which), "shown=", tostring(d:IsShown()))
            if d.which == which and d:IsShown() then
                dialog = d
                break
            end
            i = i + 1
        end
    end

    if not dialog then
        Debug("  -> FAILED: no matching visible dialog found at all")
        return
    end

    Debug("  -> found dialog", dialog:GetName() or "?", "-- clicking button1")
    local ok, err = pcall(StaticPopup_OnClick, dialog, 1)
    if not ok then
        Debug("  -> StaticPopup_OnClick ERRORED:", err)
    else
        Debug("  -> click dispatched OK")
    end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon ~= addonName then return end
    self:UnregisterEvent("ADDON_LOADED")
    hooksecurefunc("StaticPopup_Show", function(which)
        TryAutoConfirm(which)
    end)
    Debug("hooksecurefunc(StaticPopup_Show) installed")
end)

SLASH_CXAUTOCONFIRM1 = "/cxautoconfirm"
SlashCmdList["CXAUTOCONFIRM"] = function(msg)
    msg = (msg or ""):lower():trim()
    if msg == "debug" then
        CXUI_AutoConfirmDebug = not CXUI_AutoConfirmDebug
        print("|cff33ccff[cxUI AutoConfirm]|r debug", CXUI_AutoConfirmDebug and "ON" or "OFF")
    elseif msg == "status" then
        print("|cff33ccff[cxUI AutoConfirm]|r enabled:", IsAutoConfirmEnabled() and "yes" or "no")
    else
        print("|cff33ccff[cxUI AutoConfirm]|r usage: /cxautoconfirm debug | /cxautoconfirm status")
    end
end