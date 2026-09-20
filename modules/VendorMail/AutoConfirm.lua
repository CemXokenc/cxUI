local addonName, ns = ...

-- ===========================================================================
-- VENDOR & MAIL: AUTO CONFIRM
-- Clicks "confirm purchase" (token items) and "this item will become
-- non-refundable" (mail) popups automatically.
-- ===========================================================================

local VM = ns:GetModule("VendorMail")

local F = VM:NewFeature{
    key  = "autoConfirm",
    name = "Auto Confirm Purchases & Mail Warnings",
    desc = "Automatically accepts the 'confirm purchase' and 'non-refundable' (mail) popups.",
}

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

local function TryAutoConfirm(which)
    Debug("StaticPopup_Show fired, which =", tostring(which))

    if not WHITELIST[which] then
        Debug("  -> skip: '", tostring(which), "' not in WHITELIST")
        return
    end

    -- Blizzard's own lookup instead of scanning StaticPopup1..N manually.
    -- StaticPopup_Visible() returns the FRAME NAME (e.g. "StaticPopup1").
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

function F:OnEnable()
    if self:Hook("StaticPopup_Show", TryAutoConfirm) then
        Debug("hooksecurefunc(StaticPopup_Show) installed")
    end
end

SLASH_CXAUTOCONFIRM1 = "/cxautoconfirm"
SlashCmdList["CXAUTOCONFIRM"] = function(msg)
    msg = (msg or ""):lower():trim()
    if msg == "debug" then
        CXUI_AutoConfirmDebug = not CXUI_AutoConfirmDebug
        print("|cff33ccff[cxUI AutoConfirm]|r debug", CXUI_AutoConfirmDebug and "ON" or "OFF")
    elseif msg == "status" then
        print("|cff33ccff[cxUI AutoConfirm]|r enabled:", F:IsOn() and "yes" or "no")
    else
        print("|cff33ccff[cxUI AutoConfirm]|r usage: /cxautoconfirm debug | /cxautoconfirm status")
    end
end
