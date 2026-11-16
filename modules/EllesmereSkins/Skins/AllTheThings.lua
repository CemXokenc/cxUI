local addonName, ns = ...

-- ===========================================================================
-- SKIN: AllTheThings
-- Buttons only: the Blizzard-style action buttons on AllTheThings' settings
-- pages (UIPanelButtonTemplate). The mini lists, the main list, the minimap
-- button and the rest of the settings are AllTheThings' own drawing and stay
-- as they are.
--
-- AllTheThings keeps every settings page in AllTheThings.Settings.Objects and
-- every page keeps its widgets in its own .Objects, so the buttons are found
-- there and skinned each time a page is shown.
-- The pages are built during AllTheThings' own start-up, which may come after
-- the skin runs, so the skin retries for a few seconds.
-- ===========================================================================

local Sk = ns.ESkin

local function SkinObjects(S, holder, depth)
    for _, object in ipairs(holder.Objects or {}) do
        if type(object) == "table" and object.IsObjectType and object:IsObjectType("Button") and Sk.IsPanelButton(object) then
            S.Button(object)
            S.StateButtonLabel(object)
        end
        if depth < 5 and type(object) == "table" and object.Objects then SkinObjects(S, object, depth + 1) end
    end
end

Sk.NewSkin{
    addon = "AllTheThings",
    apply = function(S)
        local hooked, tries = {}, 0

        local function HookPage(page)
            if hooked[page] or not page.HookScript then return end
            hooked[page] = true
            page:HookScript("OnShow", Sk.Safe(function() SkinObjects(S, page, 1) end))
            SkinObjects(S, page, 1)
        end

        local function Try()
            local settings = _G.AllTheThings and _G.AllTheThings.Settings
            local pages = settings and settings.Objects
            if pages and #pages > 0 then
                for _, page in ipairs(pages) do HookPage(page) end
                -- a page ATT builds after this point (it adds the last ones on demand)
                if not hooked[settings] then
                    hooked[settings] = true
                    Sk.SafeHook(settings, "CreateOptionsPage", function()
                        local list = settings.Objects
                        local newest = list and list[#list]
                        if newest then HookPage(newest) end
                    end)
                end
                return
            end
            tries = tries + 1
            if tries < 20 then C_Timer.After(0.5, Try) end
        end

        Try()
    end,
}
