local addonName, ns = ...

-- ===========================================================================
-- SMALL TWEAKS: MAIL
-- Ported from EnhanceQoL (mailboxRememberLastRecipient).
-- ===========================================================================

local lastRecipient

local function rememberRecipientEnabled() return CXUI_DB.mailRememberRecipient end

local function clearRememberedRecipient() lastRecipient = nil end

local function captureRememberedRecipient()
    if not rememberRecipientEnabled() then return end
    if not SendMailNameEditBox then return end
    local name = SendMailNameEditBox:GetText()
    lastRecipient = (name and name ~= "") and name or nil
end

local function restoreRememberedRecipient()
    if not rememberRecipientEnabled() then return end
    if not MailFrame or not MailFrame:IsShown() then return end
    if not SendMailNameEditBox then return end
    if lastRecipient and lastRecipient ~= "" then
        SendMailNameEditBox:SetText(lastRecipient)
        SendMailNameEditBox:HighlightText(0, 0)
    end
end

local hooksAttached = false
local function TryAttachHooks()
    if hooksAttached then return end
    if type(SendMailFrame_SendMail) ~= "function" or type(SendMailFrame_Reset) ~= "function" then return end
    hooksecurefunc("SendMailFrame_SendMail", captureRememberedRecipient)
    hooksecurefunc("SendMailFrame_Reset", restoreRememberedRecipient)
    hooksAttached = true
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("MAIL_SHOW")
f:RegisterEvent("MAIL_CLOSED")
f:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= "Blizzard_MailFrame" then return end
        if CXUI_DB.mailRememberRecipient then TryAttachHooks() end
    elseif event == "MAIL_SHOW" then
        if CXUI_DB.mailRememberRecipient then TryAttachHooks() end
    elseif event == "MAIL_CLOSED" then
        clearRememberedRecipient()
    end
end)
