local addonName, ns = ...

-- ===========================================================================
-- VENDOR & MAIL: REMEMBER LAST RECIPIENT
-- Ported from EnhanceQoL (mailboxRememberLastRecipient).
-- ===========================================================================

local VM = ns:GetModule("VendorMail")

local F = VM:NewFeature{
    key  = "mailRememberRecipient",
    name = "Mail: Remember Last Recipient",
    desc = "Keeps the last recipient in the mailbox 'To' field after sending until the mailbox is closed.",
}

local lastRecipient

local function Capture()
    if not SendMailNameEditBox then return end
    local name = SendMailNameEditBox:GetText()
    lastRecipient = (name and name ~= "") and name or nil
end

local function Restore()
    if not MailFrame or not MailFrame:IsShown() then return end
    if not SendMailNameEditBox then return end
    if lastRecipient and lastRecipient ~= "" then
        SendMailNameEditBox:SetText(lastRecipient)
        SendMailNameEditBox:HighlightText(0, 0)
    end
end

local function TryAttachHooks()
    F:Hook("SendMailFrame_SendMail", Capture)
    F:Hook("SendMailFrame_Reset", Restore)
end

function F:OnEnable()
    VM.WatchMail(self, TryAttachHooks, function() lastRecipient = nil end)
    TryAttachHooks()
end

function F:OnDisable()
    lastRecipient = nil
end
