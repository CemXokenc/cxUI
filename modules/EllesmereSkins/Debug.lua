local addonName, ns = ...

-- ===========================================================================
-- ELLESMEREUI SKINS: /esk, a look inside the widgets this module decides about
--   /esk mouse   the frame under the mouse: what it is, which stock-template parts
--                it has, and what the module would do with it
-- Prints to the chat window. Nothing here changes anything.
-- ===========================================================================

local Sk = ns.ESkin

local PARTS = { "Left", "Middle", "Center", "Right", "LeftActive", "RightActive", "LeftDisabled", "RightDisabled",
                "Text", "Icon", "icon", "Track", "ScrollBar", "ScrollUpButton", "ScrollDownButton",
                "NineSlice", "Bg", "Border", "SetupMenu", "Button" }

local function Say(text) print("|cff7fd6ffesk|r " .. text) end

local function Name(frame)
    if not frame then return "nil" end
    local name = frame.GetName and frame:GetName()
    return name or ("<" .. (frame.GetObjectType and frame:GetObjectType() or "?") .. ">")
end

local function Describe(frame)
    local chain, parent, depth = {}, frame, 0
    while parent and depth < 5 do
        chain[#chain + 1] = Name(parent)
        parent = parent.GetParent and parent:GetParent()
        depth = depth + 1
    end
    Say("frame: " .. table.concat(chain, " < "))
    Say("type: " .. (frame.GetObjectType and frame:GetObjectType() or "?")
        .. (frame.IsMultiLine and frame:IsObjectType("EditBox") and (frame:IsMultiLine() and ", multi-line" or ", single-line") or ""))

    local have = {}
    for _, part in ipairs(PARTS) do
        local value = frame[part]
        if value ~= nil then have[#have + 1] = part .. (type(value) == "function" and "()" or "") end
    end
    Say("parts: " .. (#have > 0 and table.concat(have, ", ") or "none of the stock-template keys"))

    local normal = frame.GetNormalTexture and frame:GetNormalTexture()
    if normal then
        local path = normal.GetTexture and normal:GetTexture()
        local atlas = normal.GetAtlas and normal:GetAtlas()
        Say("normal texture: " .. tostring(atlas or path))
    end

    local ok, kind = pcall(Sk.Classify, frame)
    Say("this module would treat it as: " .. ((ok and kind) and kind or "not a stock widget (left alone)"))
end

SLASH_ESKINS1 = "/esk"
SlashCmdList["ESKINS"] = function(message)
    local command = (message or ""):lower():match("^%s*(%S*)")
    if command == "mouse" then
        local frame
        if GetMouseFoci then frame = GetMouseFoci()[1] elseif GetMouseFocus then frame = GetMouseFocus() end
        if not frame then Say("no frame under the mouse"); return end
        Describe(frame)
    else
        Say("/esk mouse: what is under the mouse and how it is treated")
    end
end
