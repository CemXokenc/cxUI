local addonName, ns = ...

-- ===========================================================================
-- SKIN: RCLootCouncil
-- Buttons only. Every RCLootCouncil button (session, voting, loot, history,
-- sync, trade windows) comes out of RCLootCouncil:CreateButton, which builds a
-- UIPanelButtonTemplate button, so that one function is wrapped: each button
-- it returns is skinned. The windows, the voting list and everything else are
-- RCLootCouncil's own and stay as they are.
--
-- Buttons created before the skin ran are skinned the same way as soon as the
-- addon makes its next one (windows build lazily); the one button RCLootCouncil
-- makes directly (the history window's second button) is picked up from its
-- window the first time the history opens.
-- ===========================================================================

local Sk = ns.ESkin

Sk.NewSkin{
    addon = "RCLootCouncil",
    apply = function(S)
        local ace = LibStub and LibStub("AceAddon-3.0", true)
        local rc = ace and ace:GetAddon("RCLootCouncil", true)
        if not rc or type(rc.CreateButton) ~= "function" or rc.cxUIButtonsSkinned then return end
        rc.cxUIButtonsSkinned = true

        local function SkinButton(button)
            if button and button.IsObjectType and button:IsObjectType("Button") then
                S.Button(button)
                S.StateButtonLabel(button)
            end
        end

        local original = rc.CreateButton
        rc.CreateButton = function(self, ...)
            local button = original(self, ...)
            xpcall(function() SkinButton(button) end, geterrorhandler())
            return button
        end
    end,
}
