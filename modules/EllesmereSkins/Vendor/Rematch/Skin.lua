local _, cxns = ...
-- Vendored from Rematch_EllesmereUI_Skin/Rematch_EllesmereUI_Skin.lua, unchanged.
-- Wrapped in a function so cxUI can run it once the addon it skins has loaded
-- (see Sk.RunChunks in EllesmereSkins.lua). Its own header follows.
local chunks = cxns.ESkin.chunks
chunks.Rematch = chunks.Rematch or {}
table.insert(chunks.Rematch, function(...)
--[[----------------------------------------------------------------------------
	Rematch EllesmereUI Skin

	Reskins Gello's Rematch to match EllesmereUI, following whatever style the
	user has EllesmereUI set to rather than a look of our own.

	The structure of this file, and most of its helpers, come from the
	MountsJournal EllesmereUI Skin, whose SKINNING_NOTES.md records why each of
	them is shaped the way it is. The map of which Rematch frames need
	treatment was drawn fresh against Rematch 5.3.1; the old Rematch ElvUI
	skin (nihilistzsche, GPLv3) targets Rematch 4's frame names and served as
	a checklist of what a Rematch skin has to reach, not as a path map.

	Everything routes through a skinning facade (the `S` table), so frames
	track the user's live theme, window style, accent colour, UI font, panel
	fill, without this file ever knowing what that theme is. Backend.lua
	supplies that facade from EllesmereUI's own skinning API where its
	dispatcher is live (8.6.8+ with the Blizzard Skin child addon), and
	rebuilds it from the public helpers where it is not; this file reads the
	same either way. On the api backend three primitives stay local, Shell,
	ScrollBar and Checkbox, because the engine's versions do not reproduce
	this skin's look; see Backend.lua's HYBRID FACADE.

	Rematch draws almost nothing with Blizzard templates. Its buttons, tabs,
	edit boxes, headers and scroll bars are its own XML with its own art, and
	its mixins re-set TexCoords, textures and label colours from their mouse
	scripts. Two consequences shape this file:

	  - Art is faded with SetAlpha(0), never SetTexture(""). Rematch's mixins
	    call SetTexture and SetTexCoord on that art at runtime, and neither
	    touches alpha, so a fade holds where a cleared texture would come back
	    (and a cleared texture draws WHITE, not nothing).
	  - Label colour is re-asserted from the same scripts Rematch uses to set
	    it. Its panel buttons paint gold on OnLeave and OnEnable; hooking those
	    is the only thing that keeps a white label white.

	Cost model: one-time texture setup plus hooks. No OnUpdate, no polling, no
	per-frame work.
------------------------------------------------------------------------------]]

local ADDON_NAME, ns = ...
local select, ipairs, pairs, type = select, ipairs, pairs, type
local hooksecurefunc, CreateFrame = hooksecurefunc, CreateFrame

-- Preconditions, captured before the early-out below so that the diagnostic can
-- still report which one failed. An addon that goes inert silently is exactly
-- what made the first round of the MountsJournal skin so hard to pin down.
--
-- Note what is NOT a precondition: EllesmereUI.RegisterSkin. Backend.lua
-- supplies the facade whether or not the API is live. See its header.
-- Nor is EllesmereUI itself, at load: the suite or any one standalone module
-- will do, so Backend.lua finds it at PLAYER_LOGIN (ns.Host()) and simply
-- never calls us back if there is none. See its WHICH ELLESMEREUI.
local haveRematch = RematchFrame ~= nil

-- EllesmereUI's skin facade, captured when our callback fires. Rematch builds
-- a lot of its UI lazily (pooled list buttons, dialogs laid out per use, menu
-- frames created on demand), so we keep `S` and call primitives from those
-- frames' own hooks. Every primitive is idempotent, which is what makes that
-- safe.
local S

-- EllesmereUI's house border grey. These are engine constants (the window
-- engine's Theme.brd*), not user settings, so unlike the accent colour they
-- cannot drift out from under us and are safe to state here.
local BRD_R, BRD_G, BRD_B = .2, .2, .2

-- Blizzard's gold, which is what Rematch paints on every label it owns when
-- the mouse leaves. Read from the global so a client retune carries us along.
local function gold()
	local c = NORMAL_FONT_COLOR
	return c and c.r or 1, c and c.g or .82, c and c.b or 0
end


--[[ FAILURE ISOLATION ---------------------------------------------------------
	EllesmereUI runs our whole skin callback inside one pcall, which is the
	right call for it (a broken third-party skin must never take the suite
	down), but it means a single bad call anywhere in here abandons everything
	after it. With scriptErrors off, as it is by default, that failure is also
	completely invisible: the window just comes up half skinned and nothing
	says why.

	So every stage runs inside stage(), which records what happened instead of
	unwinding, and /rmeuiskin repeats it back. A failure now costs one section
	rather than the whole addon, and reports itself.
------------------------------------------------------------------------------]]
local stages, failures = {}, {}

local function stage(name, fn, ...)
	local ok, err = pcall(fn, ...)
	stages[#stages + 1] = {name = name, ok = ok}
	if not ok then failures[#failures + 1] = name .. ": " .. tostring(err) end
	return ok
end


-- hooksecurefunc raises if the field is not a function, and several Rematch
-- methods only exist once a panel has registered itself. A missing hook should
-- cost that one feature, not the addon.
local function hook(obj, method, fn)
	if obj and type(obj[method]) == "function" then
		hooksecurefunc(obj, method, fn)
		return true
	end
	failures[#failures + 1] = ("hook %s: missing"):format(tostring(method))
	return false
end


--[[ SETTINGS ------------------------------------------------------------------
	Border style and size for the windows we skin, so users get the same
	border/glow/shadow choice EllesmereUI gives them everywhere else in the
	suite. Account-wide.
------------------------------------------------------------------------------]]
local DEFAULTS = {
	-- "auto" follows EllesmereUIDB's own window border, texture and size,
	-- including size 0 meaning none, so the window carries whatever border
	-- the rest of the suite is carrying without being told twice.
	borderStyle = "auto",
	borderSize = 2,
	-- "fill" paints the window in EllesmereUI's Dark Mode colour and alpha,
	-- the value the user's whole UI shares, and the only one that can be
	-- transparent at all. "blizz" uses EllesmereUI's own window art instead, to
	-- match the Blizzard windows either side of this one in journal mode.
	backdrop = "fill",
	-- Follow the Dark Mode alpha rather than an explicit override.
	followOpacity = true,
	opacity = 90,
	-- The window's outermost edge. "line" is a crisp 1px edge in the dark
	-- window-edge tone; "art" is EllesmereUI's frame atlas; "none" is none.
	windowBorder = "line",
}
local db = DEFAULTS


--[[ ITERATE CHILDREN WITHOUT ALLOCATING ---------------------------------------
	{frame:GetChildren()} builds a table every call. Free once at skin time,
	not free from a list's refresh, which fires on every scroll tick. Passing
	the children straight through as varargs allocates nothing.
------------------------------------------------------------------------------]]
local function eachChild(fn, ...)
	for i = 1, select("#", ...) do
		fn((select(i, ...)))
	end
end


-- Defined down in the border section, forward-declared because the diagnostic
-- below is registered at file scope, ahead of them, and closes over these
-- names. Without this the closure would bind a global instead.
local hostBorder, resolveBorder

-- Also forward-declared: defined with the shared widget helpers, used above
-- them by the slider frames and the diagnostic.
local editBox

-- And the Collections suppression pair, defined at the end of the file with
-- the rest of the backdrop logic but hooked from the main window's scripts.
local fadeCollections, suppressBehind


--[[ DIAGNOSTICS --------------------------------------------------------------
	Registered at file scope, before anything that can fail and before the skin
	callback exists, so it answers even when nothing else ran.
------------------------------------------------------------------------------]]

-- Assigned further down, once the suppression registry exists.
local isSuppressed


local function texDesc(tex)
	local ok, atlas = pcall(function() return tex.GetAtlas and tex:GetAtlas() end)
	if ok and atlas then return "atlas:" .. atlas end
	local ok2, file = pcall(function() return tex.GetTexture and tex:GetTexture() end)
	if ok2 and type(file) == "string" then
		return (file:match("[^\\/]+$")) or file
	elseif ok2 and file then
		return "fileID:" .. tostring(file)
	end
	return "colour"
end


-- Name if it has one, otherwise the parentKey chain, so unnamed Blizzard and
-- EllesmereUI frames can still be identified in the output.
local function framePath(frame, depth)
	if not frame or (depth or 0) > 6 then return "?" end
	local ok, name = pcall(function() return frame.GetName and frame:GetName() end)
	if ok and name then return name end
	local ok2, parent = pcall(function() return frame:GetParent() end)
	if not (ok2 and parent) then return "?" end
	local key
	pcall(function()
		for k, v in pairs(parent) do
			if type(k) == "string" and v == frame then key = k; break end
		end
	end)
	return framePath(parent, (depth or 0) + 1) .. "." .. (key or "?")
end


local function rectOf(obj)
	local ok, l, b, w, h = pcall(function()
		return obj:GetLeft(), obj:GetBottom(), obj:GetWidth(), obj:GetHeight()
	end)
	if not ok or not l or not w then return nil end
	if issecretvalue and (issecretvalue(l) or issecretvalue(w)) then return nil end
	return math.floor(l), math.floor(b or 0), math.floor(w), math.floor(h or 0)
end


-- True while Rematch has taken the Pet Journal's seat inside Collections.
-- This is Rematch's own test for it (rematch.journal:IsActive), reproduced
-- here because that namespace is private to it.
local function journalActive()
	return CollectionsJournal ~= nil and RematchFrame ~= nil
		and RematchFrame:GetParent() == CollectionsJournal
end


--[[ WHAT IS DRAWING BEHIND US ------------------------------------------------
	/rmeuiskin behind, run with Rematch open in the journal.

	Reasoning cannot settle what is showing through a transparent backdrop:
	the answer depends on what a particular EllesmereUI build skinned, in what
	order, on this user's settings. So walk everything behind the window and
	report each visible texture with its screen rect, biggest first.
------------------------------------------------------------------------------]]
local function reportBehind()
	local win = RematchFrame
	if not (win and win:IsShown()) then
		print("  |cffff5555Open Rematch first, then run this again.|r")
		return
	end
	if not journalActive() then
		print("  Rematch is standalone (parented to UIParent). Nothing sits behind")
		print("  it but the world; this report is for journal mode.")
		return
	end

	local l, b, w, h = rectOf(win)
	print(("  our window: %dx%d at %d,%d"):format(w or 0, h or 0, l or 0, b or 0))
	for _, f in ipairs({CollectionsJournal, PetJournal}) do
		if f then
			local fl, fb, fw, fh = rectOf(f)
			print(("  %s: %dx%d at %d,%d shown=%s"):format(framePath(f),
				fw or 0, fh or 0, fl or 0, fb or 0, tostring(f:IsShown())))
		end
	end

	local skip = {[win] = true}
	local found = {}
	local function walk(frame, depth)
		if depth > 5 or skip[frame] then return end
		local shown = frame.IsShown and frame:IsShown()
		if shown == false then return end
		if frame.GetRegions then
			for i = 1, select("#", frame:GetRegions()) do
				local r = select(i, frame:GetRegions())
				local okType = r and r.IsObjectType and r:IsObjectType("Texture")
				if okType and r:IsShown() and (r:GetAlpha() or 0) > .05 then
					local rl, rb, rw, rh = rectOf(r)
					if rw and (rw > 80 or rh > 80) then
						found[#found + 1] = {
							area = rw * rh, w = rw, h = rh, x = rl, y = rb,
							alpha = r:GetAlpha(), desc = texDesc(r),
							owner = framePath(frame),
							known = isSuppressed and isSuppressed(r),
						}
					end
				end
			end
		end
		if frame.GetChildren then
			for i = 1, select("#", frame:GetChildren()) do
				local c = select(i, frame:GetChildren())
				if c and not c:IsForbidden() then walk(c, depth + 1) end
			end
		end
	end
	if CollectionsJournal then walk(CollectionsJournal, 1) end

	table.sort(found, function(x, y) return x.area > y.area end)
	if #found == 0 then
		print("  |cff44ff44Nothing visible behind the window.|r")
		return
	end

	print(("  |cffffff00%d visible textures behind the window|r (largest first):"):format(#found))
	for i = 1, math.min(#found, 20) do
		local e = found[i]
		print(("   %dx%d at %d,%d a=%.2f  %s  <%s>%s")
			:format(e.w, e.h, e.x, e.y, e.alpha, e.desc, e.owner,
				e.known and " |cffff5555[we faded this, it came back]|r" or ""))
	end
end


--[[ HOW DOES THE ROW NEXT TO US ACTUALLY LOOK ---------------------------------
	/rmeuiskin tabs. In journal mode Rematch hangs its Pets / Teams / Queue /
	Options tabs below the window's right edge, and Collections hangs Mounts /
	Pets / Toys below the left. Whether those two rows match depends on what
	EllesmereUI did to Collections' row on this client, so print both rather
	than guess.
------------------------------------------------------------------------------]]
local function dumpTab(label, tab)
	if not tab then
		print(("  %s: |cffff5555missing|r"):format(label))
		return
	end
	local bits = {}
	for i = 1, select("#", tab:GetRegions()) do
		local r = select(i, tab:GetRegions())
		if r and r.IsObjectType and r:IsObjectType("FontString") then
			local ok, cr, cg, cb, ca = pcall(r.GetTextColor, r)
			local text = (r.GetText and r:GetText()) or ""
			if ok and cr then
				bits[#bits + 1] = ("'%s' %.2f/%.2f/%.2f a=%.2f")
					:format(text, cr, cg, cb, ca or 1)
			end
		end
	end
	-- Geometry first: where the frame sits and how big it is, so two rows
	-- can be compared for spacing and height by subtraction, not by eye.
	local l, b, w, h = rectOf(tab)
	print(("  %s [%s] %sx%s at %s,%s: %s"):format(label,
		tab:IsShown() and "shown" or "hidden",
		tostring(w), tostring(h), tostring(l), tostring(b),
		#bits > 0 and table.concat(bits, "  ") or "no FontString"))

	local tex = {}
	for i = 1, select("#", tab:GetRegions()) do
		local r = select(i, tab:GetRegions())
		if r and r.IsObjectType and r:IsObjectType("Texture")
			and r:IsShown() and (r:GetAlpha() or 0) > .01 then
			local _, _, w, h = rectOf(r)
			local okC, cr, cg, cb, ca = pcall(r.GetVertexColor, r)
			local col = okC and cr
				and ("%.2f/%.2f/%.2f a=%.2f"):format(cr, cg, cb, ca or 1)
				or "?"
			tex[#tex + 1] = ("%s %sx%s regionA=%.2f rgba %s")
				:format(texDesc(r), tostring(w), tostring(h), r:GetAlpha(), col)
		end
	end
	if #tex > 0 then print("      art: " .. table.concat(tex, " | ")) end
end


local function reportTabs()
	print("  |cffffff00Collections' own row|r:")
	local collect = CollectionsJournal
	if collect then
		for _, key in ipairs({"MountsTab", "PetsTab", "ToysTab", "HeirloomsTab",
			"WardrobeTab", "WarbandScenesTab"}) do
			if collect[key] then dumpTab("CollectionsJournal." .. key, collect[key]) end
		end
	end

	print("  |cffffff00Ours|r (the Rematch tab, then the Blizzard face on it):")
	local tabs = RematchFrame and RematchFrame.PanelTabs
	if tabs then
		local i = 0
		for _, tab in ipairs({tabs:GetChildren()}) do
			i = i + 1
			dumpTab(("PanelTabs[%d] view=%s"):format(i, tostring(tab.view)), tab)
			for _, child in ipairs({tab:GetChildren()}) do
				if child.TabTextures then dumpTab("   face", child) end
			end
		end
	end
	if RematchFrame then
		local l, b, w, h = rectOf(RematchFrame)
		print(("  window: %sx%s at %s,%s"):format(tostring(w), tostring(h), tostring(l), tostring(b)))
	end
end


local function slashHandler(msg)
	local function yn(v) return v and "|cff44ff44yes|r" or "|cffff5555NO|r" end
	print("|cff0bd29dRematch EllesmereUI Skin|r")

	if type(msg) == "string" and msg:lower():find("behind") then
		reportBehind()
		return
	end
	if type(msg) == "string" and msg:lower():find("tabs") then
		reportTabs()
		return
	end

	-- Versions, so a bug report carries the one variable every path-based
	-- stage depends on. Deliberately above the inert bail-out.
	do
		local getMeta = C_AddOns and C_AddOns.GetAddOnMetadata or GetAddOnMetadata
		if getMeta then
			local function ver(name)
				local ok, v = pcall(getMeta, name, "Version")
				return (ok and v) or "?"
			end
			-- A standalone module carries its own copy of EllesmereUI, so name
			-- the folder: that is the version its framework is.
			local host = ns.HostFolder() or "EllesmereUI"
			print(("  versions: skin %s, Rematch %s, EllesmereUI %s%s"):format(
				ver(ADDON_NAME), ver("Rematch"), ver(host),
				ns.HostIsStandalone() and (" (standalone: " .. host .. ")") or ""))
		end
	end

	-- The 12.1 compatibility shim, which is the other half of what this addon
	-- is for. Report whether the global exists at all, and whether ours is
	-- the one supplying it, so "the window is blank" can be answered in one
	-- line.
	do
		local have = type(MouseIsOver) == "function"
		local ours = have and ns.CompatSuppliedMouseIsOver
		print("  MouseIsOver:", have and "present" or "|cffff5555MISSING|r",
			ours and "(restored by this addon)"
				or (have and "(supplied by the client or another addon)" or ""))
	end

	-- The second 12.1 shim: inside instances the client hides NPC names from
	-- addons and Rematch's name lookup throws, blanking the window. Report
	-- whether the guard is in place and how often it has had to step in, so
	-- "my target says Unknown" and "blank window in a dungeon" are both
	-- answered by the same line.
	do
		local wrapped = ns.CompatWrappedGetNpcName
		local n = ns.CompatHiddenNames or 0
		print("  NPC names:", wrapped and "guarded" or "not guarded",
			n > 0 and ("(%d hidden by the game this session)"):format(n)
				or "(none hidden this session)")
	end

	local haveEUI = ns.Host() ~= nil
	if not (haveEUI and haveRematch) then
		print("  |cffff5555Skin is inert. A precondition was missing.|r")
		print("  EllesmereUI running:", yn(haveEUI),
			haveEUI and "" or "(neither the suite nor a standalone module)")
		print("  Rematch loaded:", yn(haveRematch))
		return
	end

	local backendNote
	if ns.GetBackend() == "api" then
		backendNote = "(EllesmereUI's skinning API; shell, scroll bars and checkboxes drawn locally)"
	elseif ns.HostIsStandalone() then
		backendNote = "(standalone EllesmereUI, which has no Blizz UI Enhanced; using public helpers)"
	elseif ns.HasAPI() then
		backendNote = "(API stub present but EllesmereUIBlizzardSkin is not running; using public helpers)"
	else
		backendNote = "(rebuilt from EllesmereUI's public helpers)"
	end
	print("  backend:", ns.GetBackend(), backendNote)

	if not S then
		print("  |cffff5555The skin callback never ran.|r")
		print("  It is dispatched at PLAYER_LOGIN. On the api backend, check")
		print("  EllesmereUI options > Blizz UI Enhanced > Blizzard Window")
		print("  Skins > Third-Party Addons.")
		return
	end

	print("  style:", S.GetStyle(), " skinning enabled:", yn(S.IsEnabled()))
	print("  RematchFrame:", yn(RematchFrame), " skinned:", yn(RematchFrame and RematchFrame.euiSkinned),
		" journal mode:", yn(journalActive()))
	do
		local key, size = resolveBorder()
		local hostKey, hostSize = hostBorder()
		print(("  border: %s %s -> %s %s   (EllesmereUI's own: %s %s)"):format(
			tostring(db.borderStyle), tostring(db.borderSize),
			tostring(key), tostring(size), tostring(hostKey), tostring(hostSize)))
	end

	if ns.CanStyleShell and ns.CanStyleShell() and ns.GetShellAppearance then
		local floor = math.floor
		local mode, alpha, r, g, b, a, edge = ns.GetShellAppearance()
		print(("  backdrop: %s at %d%% opacity, edge: %s")
			:format(mode, floor(alpha * 100 + .5), tostring(edge)))
		print(("  EllesmereUI Dark Mode fill: #%02x%02x%02x at %d%%"):format(
			floor(r * 255 + .5), floor(g * 255 + .5), floor(b * 255 + .5),
			floor((a or 0) * 100 + .5)))
	end

	local line = "  stages:"
	for i = 1, #stages do
		line = line .. " " .. stages[i].name .. (stages[i].ok and "=ok" or "=|cffff5555FAIL|r")
	end
	print(line)

	if #failures == 0 then
		print("  no failures recorded")
	else
		print("  |cffff5555failures:|r")
		for i = 1, #failures do print("   ", failures[i]) end
	end

	print("  |cff888888/rmeuiskin behind|r lists what is still drawing behind")
	print("  |cff888888the window in journal mode, largest first.|r")
	print("  |cff888888/rmeuiskin tabs|r compares our tab labels against")
	print("  |cff888888Collections' own row beside them.|r")
end

SLASH_RMEUISKIN1 = "/rmeuiskin"
SLASH_RMEUISKIN2 = "/rematchskin"
SlashCmdList.RMEUISKIN = slashHandler


-- Registering a skin is free, so this is the only gate we need. Rematch is a
-- hard TOC dependency. EllesmereUI is not, because a standalone module has no
-- "EllesmereUI" addon to depend on: without one, Backend.lua never calls the
-- callback below, which is gate enough. The diagnostic above is already
-- registered either way, so an inert addon can still say so.
if not haveRematch then return end


local function resolveDB()
	if type(RematchEllesmereUISkinDB) ~= "table" then
		RematchEllesmereUISkinDB = {}
	end
	db = RematchEllesmereUISkinDB
	for k, v in pairs(DEFAULTS) do
		if db[k] == nil then db[k] = v end
	end
end


-- Push the window appearance into the backend. Safe to call before any window
-- exists: it records the choice, and the shell reads it as it is built.
local function applyShell()
	if not (ns.CanStyleShell and ns.CanStyleShell()) then return end
	local alpha
	if not db.followOpacity then alpha = (tonumber(db.opacity) or 90) / 100 end
	ns.SetShellAppearance(db.backdrop, alpha, db.windowBorder)
end


--[[ BORDER STYLE --------------------------------------------------------------
	EllesmereUI's shared border engine, the same texture list, size steps and
	Glow/Shadow entries as the Border Style pickers in Damage Meters and the
	unit frames. ApplyBorderStyle draws onto a host frame the *caller* owns, so
	each window we border gets an empty frame of ours pinned over it.
------------------------------------------------------------------------------]]
-- Weak keys throughout these registries: several are keyed by pooled frames
-- Rematch recycles, and a strong key would pin a released widget alive.
local borderHosts = setmetatable({}, {__mode = "k"})


--[[ FOLLOW THE USER'S OWN WINDOW BORDER ----------------------------------------
	  EllesmereUIDB.windowBorderTexture   "solid", "glow", "shadow", "sm:<name>"
	  EllesmereUIDB.windowBorderSize      step 1-4; 0 means no border at all

	Read-only, and re-read on every call. Size 0 is a real answer, not a
	missing one: plenty of setups run with no window border. A standalone
	module's settings table (ns.HostDB) never carries these keys, so there
	"auto" reads as no border, which is what that host draws on its windows.
------------------------------------------------------------------------------]]
function hostBorder()
	local edb = ns.HostDB()
	if type(edb) ~= "table" then return "none", 2 end
	local size = tonumber(edb.windowBorderSize)
	local tex = edb.windowBorderTexture
	if size == nil and tex == nil then return "none", 2 end
	if (size or 0) <= 0 then return "none", 2 end
	return tex or "solid", math.max(1, math.min(4, size))
end


function resolveBorder()
	if db.borderStyle == "auto" then return hostBorder() end
	return db.borderStyle, db.borderSize or 2
end


local function applyBorder(frame)
	local host = borderHosts[frame]
	if not host then
		host = CreateFrame("Frame", nil, frame)
		host:SetAllPoints(frame)
		host:EnableMouse(false)
		borderHosts[frame] = host
	end

	local EUI = ns.Host()
	if not (EUI and EUI.ApplyBorderStyle) then return end

	local key, size = resolveBorder()
	if not key or key == "none" then
		EUI.ApplyBorderStyle(host, 0, 0, 0, 0, 1, "solid")
		host:Hide()
		return
	end

	local colour, behind = EUI.GetBorderStyleSelectDefaults(key)
	local level = frame:GetFrameLevel()
	-- Shadow only reads as depth when it sits *under* the window it hugs;
	-- everything else goes above EllesmereUI's own window border overlay.
	host:SetFrameLevel(behind and (level > 0 and level - 1 or 0) or level + 7)
	host:Show()
	EUI.ApplyBorderStyle(host, size, colour.r, colour.g, colour.b, 1, key)
end


-- Windows opt in as they are skinned; the picker replays over all of them.
local function addBorder(frame)
	if frame and not borderHosts[frame] then applyBorder(frame) end
end


local function refreshBorders()
	for frame in pairs(borderHosts) do applyBorder(frame) end
end


--[[ LIVE-COLOURED ELEMENTS ----------------------------------------------------
	Anything we colour ourselves via the getters has to be repainted when the
	user changes their accent or theme, so each such element goes into one of
	these registries and S.OnLooksChanged replays them.
------------------------------------------------------------------------------]]

-- Selection tints (accent wash behind a checked or selected element).
local washes = setmetatable({}, {__mode = "k"})

local function paintWash(tex, alpha)
	local r, g, b = S.GetAccentColor()
	tex:SetColorTexture(r, g, b, alpha)
end

local function addWash(tex, alpha)
	if not tex then return end
	alpha = alpha or .25
	washes[tex] = alpha
	paintWash(tex, alpha)
end


--[[ THE ACCENT BAR ------------------------------------------------------------
	The line under a selected tab is not the accent colour. EllesmereUI's
	window engine draws it from a separate "accent bar" setting in Global
	Options, which can be a custom colour or switched off, and falls back
	to the live accent only when no custom colour is set. Collections' own
	tab row follows that setting, so ours reads the same keys.
------------------------------------------------------------------------------]]
local function accentBar()
	local edb = ns.HostDB()
	local c = edb and edb.blizzWinAccentBar
	local shown = not (c and c.enabled == false)
	if c and c.useCustom then
		local col = c.color
		if col then return col.r or 1, col.g or 1, col.b or 1, shown end
		return 1, 1, 1, shown
	end
	local r, g, b = S.GetAccentColor()
	return r, g, b, shown
end


-- A +/- glyph in the house style: two thin bars drawn as textures rather
-- than a font glyph, so it is crisp, centred exactly, and the same size
-- whatever font the user has chosen. SetExpanded(true) shows a minus.
local function newPlusMinus(parent, size)
	size = size or 10
	local g = {}
	-- Each bar carries a 1px drop shadow one sub-level below it, the same
	-- offset the UI font's shadow uses, so the glyph reads like the text
	-- beside it against any plate.
	g.h = parent:CreateTexture(nil, "OVERLAY", nil, 2)
	g.h:SetSize(size, 2)
	g.v = parent:CreateTexture(nil, "OVERLAY", nil, 2)
	g.v:SetSize(2, size)
	g.hs = parent:CreateTexture(nil, "OVERLAY", nil, 1)
	g.hs:SetSize(size, 2)
	g.hs:SetPoint("TOPLEFT", g.h, "TOPLEFT", 1, -1)
	g.vs = parent:CreateTexture(nil, "OVERLAY", nil, 1)
	g.vs:SetSize(2, size)
	g.vs:SetPoint("TOPLEFT", g.v, "TOPLEFT", 1, -1)
	g.hs:SetColorTexture(0, 0, 0, .7)
	g.vs:SetColorTexture(0, 0, 0, .7)
	function g:SetPoint(...)
		self.h:ClearAllPoints(); self.v:ClearAllPoints()
		self.h:SetPoint(...); self.v:SetPoint(...)
	end
	function g:SetExpanded(expanded)
		self.v:SetShown(not expanded)
		self.vs:SetShown(not expanded)
	end
	function g:SetColor(r, gg, b, a)
		self.h:SetColorTexture(r, gg, b, a or 1)
		self.v:SetColorTexture(r, gg, b, a or 1)
		self.hs:SetAlpha(a or 1); self.vs:SetAlpha(a or 1)
	end
	function g:SetShown(shown)
		self.h:SetShown(shown); self.hs:SetShown(shown)
		if not shown then self.v:Hide(); self.vs:Hide() end
	end
	g:SetColor(1, 1, 1, .9)
	return g
end


-- Repaint callbacks for elements that read the accent live rather than
-- registering a texture: the tab sections and the level-25 badge add to it,
-- looksChanged runs it. Declared up here because those sections come later.
local tabRepaints = {}

-- Accent-coloured glyphs and strips (tab underlines, thumbs we draw).
local accents = setmetatable({}, {__mode = "k"})

local function paintAccent(tex, alpha)
	local r, g, b = S.GetAccentColor()
	tex:SetColorTexture(r, g, b, alpha or 1)
end

local function addAccent(tex, alpha)
	if not tex then return end
	accents[tex] = alpha or 1
	paintAccent(tex, alpha)
end


-- Borders whose colour carries information: pet quality, current selection,
-- hover. Rows that encode state in their border need one we can repaint.
local stateBorders = setmetatable({}, {__mode = "k"})


-- The strips live on a child frame of ours rather than directly on the host.
-- EllesmereUI re-fades every unprotected region of a frame it registered
-- whenever Collections is shown (its global Restrip), and only regions it
-- knows about survive. One level down puts ours out of reach entirely, the
-- same shape the suite's own PP border container uses.
-- Where the edge draws in the stack. An edge around an ICON must sit above
-- the icon and below whatever the row lays over it (level badge, favourite
-- star, status cross), so it takes the draw layer one step above the
-- icon's, on a host at the parent's own frame level, where regions from
-- the two frames interleave by layer (the engine's border container does
-- the same). An edge around a whole frame keeps the old top-of-everything
-- placement.
local NEXT_LAYER = {BACKGROUND = "BORDER", BORDER = "ARTWORK", ARTWORK = "OVERLAY"}

local function newEdges(parent, region, pad)
	pad = pad or 0
	local host = CreateFrame("Frame", nil, parent)
	host:SetAllPoints(region)
	host:EnableMouse(false)

	local layer, sub = "OVERLAY", 7
	local level = parent:GetFrameLevel() + 1
	local iconLayer = region ~= parent and region.GetDrawLayer and region:GetDrawLayer()
	if iconLayer and NEXT_LAYER[iconLayer] then
		layer, sub = NEXT_LAYER[iconLayer], 0
		level = parent:GetFrameLevel()
	end
	host:SetFrameLevel(level)

	local edges = {}
	for i = 1, 4 do
		local t = host:CreateTexture(nil, layer, nil, sub)
		t:SetColorTexture(BRD_R, BRD_G, BRD_B, 1)
		edges[i] = t
	end
	local top, bottom, left, right = edges[1], edges[2], edges[3], edges[4]
	top:SetPoint("TOPLEFT", host, "TOPLEFT", -pad, pad)
	top:SetPoint("TOPRIGHT", host, "TOPRIGHT", pad, pad)
	top:SetHeight(1)
	bottom:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", -pad, -pad)
	bottom:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", pad, -pad)
	bottom:SetHeight(1)
	left:SetPoint("TOPLEFT", host, "TOPLEFT", -pad, pad)
	left:SetPoint("BOTTOMLEFT", host, "BOTTOMLEFT", -pad, -pad)
	left:SetWidth(1)
	right:SetPoint("TOPRIGHT", host, "TOPRIGHT", pad, pad)
	right:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", pad, -pad)
	right:SetWidth(1)
	edges.host = host
	return edges
end


--[[ ROUND BADGES -------------------------------------------------------------
	A small circle: a ring in the border grey, a dark fill one pixel inside
	it, and a number in the UI font. Both discs are plain colour textures
	cut round by Blizzard's portrait mask, the same file Rematch uses for
	its own round buttons. Drawn on a host at the widget's own frame level
	in OVERLAY just under any text the widget lays there, so it sits over
	an icon's edge and under nothing that matters.
------------------------------------------------------------------------------]]
local CIRCLE_MASK = "Interface\\CharacterFrame\\TempPortraitAlphaMask"

local function newCircleBadge(parent, size)
	local host = CreateFrame("Frame", nil, parent)
	host:EnableMouse(false)
	-- One level above the parent, not level with it. A frame's HIGHLIGHT
	-- layer (the hover wash on every row and slot) is drawn above the
	-- regions of child frames that share its frame level, so a badge seated
	-- level with its row was washed over on hover. One level up puts it
	-- over the wash, and still over the icon edges, which sit level with
	-- the row.
	host:SetFrameLevel(parent:GetFrameLevel() + 1)
	host:SetSize(size, size)

	local function disc(sub, inset)
		local t = host:CreateTexture(nil, "OVERLAY", nil, sub)
		t:SetPoint("TOPLEFT", host, "TOPLEFT", inset, -inset)
		t:SetPoint("BOTTOMRIGHT", host, "BOTTOMRIGHT", -inset, inset)
		local m = host:CreateMaskTexture()
		m:SetTexture(CIRCLE_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		m:SetAllPoints(t)
		t:AddMaskTexture(m)
		return t
	end
	local b = {host = host}
	b.ring = disc(-3, 0)
	b.ring:SetColorTexture(BRD_R, BRD_G, BRD_B, 1)
	b.fill = disc(-2, 1)
	b.fill:SetColorTexture(.03, .03, .03, .97)

	b.text = host:CreateFontString(nil, "OVERLAY")
	local fontPath, fontFlag = S.GetFont()
	b.text:SetFont(fontPath, 9, fontFlag or "")
	b.text:SetTextColor(1, 1, 1)
	-- One pixel right of true centre: the font's shadow sits down-right of
	-- the glyphs, which pulls the perceived centre of the number left.
	b.text:SetPoint("CENTER", host, "CENTER", 1, 0)

	function b:SetRing(r, g, bb) self.ring:SetColorTexture(r, g, bb, 1) end
	function b:SetShown(shown) self.host:SetShown(shown) end
	return b
end


--[[ LEVEL BADGE ---------------------------------------------------------------
	Rematch marks a pet's level with a 19px bubble texture at the icon's
	bottom-right corner and a tiny FontString off-centre inside it. Both
	are faded and a round badge of ours takes the number, centred on the
	corner. Rematch shows, hides and rewrites its own text on every fill;
	the badge follows through hooks on those calls.
------------------------------------------------------------------------------]]
local function levelBadge(widget, icon)
	local text, bubble = widget.LevelText, widget.LevelBubble
	if not text or widget.euiBadge then return end
	widget.euiBadge = true
	if bubble then bubble:SetAlpha(0) end
	text:SetAlpha(0)

	local badge = newCircleBadge(widget, 16)
	badge.host:SetPoint("CENTER", icon or text, icon and "BOTTOMRIGHT" or "CENTER", icon and -1 or 0, icon and 1 or 0)

	local function follow()
		badge.text:SetText(text:GetText() or "")
		badge:SetShown(text:IsShown())
	end
	hook(text, "SetText", follow)
	hook(text, "Show", follow)
	hook(text, "Hide", follow)
	hook(text, "SetShown", follow)
	follow()
end


--[[ THE LEVEL 25 FILTER BADGE ------------------------------------------------
	The type bar's max-level filter is a 19px texture from Rematch's levels
	sheet, a gold ring shown over it while the filter is active, and a
	re-crop to a blue "rare" variant while it filters rares. The texture is
	also a mouse target and a highlighter target, so it is CLEARED rather
	than faded (a cleared texture is what the highlighter copies, so no
	ghost) and left in place to keep its clicks. Our badge sits over it:
	ring in the accent while active, number in the rare blue while rare.
------------------------------------------------------------------------------]]
local function level25Badge(bar)
	local btn, glow = bar.Level25Button, bar.Level25Highlight
	if not btn or bar.euiLevel25 then return end
	bar.euiLevel25 = true
	btn:SetTexture(0)
	if glow then glow:SetAlpha(0) end

	local badge = newCircleBadge(bar, 16)
	-- Rematch's 19px button hangs 1px down from the bar's top, so its centre
	-- sits 10.5px down; the 24px tabs beside it are centred at 12. A drop of
	-- 1.5 puts the badge level with the tab labels, and, the badge being 16
	-- tall, lands both its edges on whole pixels instead of halves.
	badge.host:SetPoint("CENTER", btn, "CENTER", 0, -1.5)
	badge.text:SetText("25")

	local function paint()
		local active = glow and glow:IsShown()
		if active then badge:SetRing(S.GetAccentColor()) else badge:SetRing(BRD_R, BRD_G, BRD_B) end
		-- Rematch crops to the sheet's right-hand cell for the rare variant.
		local ok, left = pcall(btn.GetTexCoord, btn)
		if ok and left and left > .5 then
			badge.text:SetTextColor(.2, .56, .99)
		else
			badge.text:SetTextColor(1, 1, 1)
		end
	end
	if glow then
		hook(glow, "Show", paint)
		hook(glow, "Hide", paint)
		hook(glow, "SetShown", paint)
	end
	hook(btn, "SetTexCoord", paint)
	paint()
	-- The accent ring repaints with the rest of the accent-coloured elements.
	tabRepaints[#tabRepaints + 1] = paint
end


local function paintState(state)
	local r, g, b
	if state.hovered then
		r, g, b = 1, 1, 1
	elseif state.selected then
		r, g, b = S.GetAccentColor()
	elseif state.quality then
		r, g, b = state.quality[1], state.quality[2], state.quality[3]
	else
		r, g, b = BRD_R, BRD_G, BRD_B
	end
	local edges = state.edges
	for i = 1, 4 do edges[i]:SetColorTexture(r, g, b, 1) end
end


local function newState(parent, region, pad)
	local state = {edges = newEdges(parent, region, pad)}
	stateBorders[state] = true
	return state
end


local function bindHover(btn, state)
	btn:HookScript("OnEnter", function() state.hovered = true; paintState(state) end)
	btn:HookScript("OnLeave", function() state.hovered = nil; paintState(state) end)
end


-- A texture whose vertex colour is the row's quality border: mirror its colour
-- onto our edges and fade the original, so quality still reads without
-- Rematch's own border art.
local function bindQuality(state, qualityBorder)
	if not qualityBorder then return end
	qualityBorder:SetAlpha(0)
	local function pull()
		if qualityBorder:IsShown() then
			local r, g, b = qualityBorder:GetVertexColor()
			state.quality = {r, g, b}
		else
			state.quality = nil
		end
		paintState(state)
	end
	hook(qualityBorder, "SetVertexColor", pull)
	hook(qualityBorder, "Show", pull)
	hook(qualityBorder, "Hide", pull)
	pull()
end


--[[ SLIDERS -------------------------------------------------------------------
	TODO(api-v2): EllesmereUI's API v1 has no slider primitive (re-verified
	against 9.1.8). Hand-rolled from the documented getters until one ships.
	Track takes a light tint, thumb the accent, and both repaint from
	S.OnLooksChanged so a live accent change reaches them.
------------------------------------------------------------------------------]]
local sliders = setmetatable({}, {__mode = "k"})


local function paintSlider(slider)
	local track = sliders[slider]
	if track then track:SetColorTexture(1, 1, 1, .18) end
	local thumb = slider.GetThumbTexture and slider:GetThumbTexture()
	if thumb then
		local r, g, b = S.GetAccentColor()
		thumb:SetColorTexture(r, g, b, 1)
	end
end


local function skinSlider(slider)
	if not slider or sliders[slider] then return end

	local thumb = slider.GetThumbTexture and slider:GetThumbTexture()

	local function fade(frame)
		if not frame or not frame.GetRegions then return end
		for i = 1, select("#", frame:GetRegions()) do
			local r = select(i, frame:GetRegions())
			if r ~= thumb and r.IsObjectType and r:IsObjectType("Texture") then
				r:SetAlpha(0)
			end
		end
	end
	fade(slider)
	for i = 1, select("#", slider:GetChildren()) do
		fade(select(i, slider:GetChildren()))
	end
	-- Rematch's options sliders inherit BackdropTemplate for their trough.
	if slider.SetBackdropBorderColor then slider:SetBackdropBorderColor(0, 0, 0, 0) end
	if slider.SetBackdropColor then slider:SetBackdropColor(0, 0, 0, 0) end

	local track = slider:CreateTexture(nil, "BACKGROUND")
	track:SetPoint("LEFT")
	track:SetPoint("RIGHT")
	track:SetHeight(4)
	sliders[slider] = track

	if thumb then thumb:SetSize(8, 16) end
	paintSlider(slider)
end


local function looksChanged()
	for tex, alpha in pairs(washes) do paintWash(tex, alpha) end
	for tex, alpha in pairs(accents) do paintAccent(tex, alpha) end
	for state in pairs(stateBorders) do paintState(state) end
	for slider in pairs(sliders) do paintSlider(slider) end
	for _, fn in ipairs(tabRepaints) do fn() end
end


--[[ SHARED WIDGET HELPERS -----------------------------------------------------]]

-- Rematch crops its own icons to .075/.925 in XML already, so S.SquareIcon's
-- fixed .08/.92 would be nearly right but would still overwrite the coords
-- of anything drawn from a sprite sheet (pet type decals, source icons).
-- Trim a proportion of whatever rect the texture already has instead, which
-- is correct for both cases and idempotent.
local function squareIcon(tex)
	if not (tex and tex.GetTexCoord and tex.SetTexCoord) then return end
	if tex.euiSquared then return end

	local ok, ulx, uly, llx, lly, urx, ury, lrx, lry = pcall(tex.GetTexCoord, tex)
	if not ok or ulx == nil then return end

	if ulx == 0 and uly == 0 and llx == 0 and lly == 1 and urx == 1 and ury == 0 then
		tex.euiSquared = true
		S.SquareIcon(tex)
		return
	end

	-- Axis-aligned coords only; anything else is rotated or flipped.
	if ulx ~= llx or urx ~= lrx or uly ~= ury or lly ~= lry then return end
	local left, right = ulx, urx
	local top, bottom = uly, lly
	if not (right > left and bottom > top) then return end

	-- Already inside the bevel (Rematch's .075 crop): leave it.
	if left >= .07 and top >= .07 then
		tex.euiSquared = true
		return
	end

	tex.euiSquared = true
	local iw, ih = (right - left) * .08, (bottom - top) * .08
	tex:SetTexCoord(left + iw, right - iw, top + ih, bottom - ih)
end


-- Several Rematch frames inherit BackdropTemplate and draw their edge through
-- SetBackdrop rather than as texture regions. No fade can reach that, so it
-- reads as a second border sitting outside the house one. Cleared by colour
-- alpha, which keeps to the alpha-only policy.
local function clearBackdrop(frame)
	if frame and frame.SetBackdropBorderColor then
		frame:SetBackdropBorderColor(0, 0, 0, 0)
	end
	if frame and frame.SetBackdropColor then
		frame:SetBackdropColor(0, 0, 0, 0)
	end
end


-- Fade every texture in a parentArray (Rematch's Back[1..3], Highlight[1..3]).
local function fadeArray(arr)
	if type(arr) ~= "table" then return end
	for i = 1, #arr do
		local t = arr[i]
		if t and t.SetAlpha then t:SetAlpha(0) end
	end
end


--[[ PLATES THE HIGHLIGHTER WOULD RESURRECT --------------------------------------
	Rematch's hover effect (utils/textureHighlight.lua) does not tint a
	texture; it makes a COPY of it, same file, same coords, one sub-level up,
	in ADD blend, and shows that copy whenever the original IsShown(). Alpha
	is never consulted. So a plate faded to alpha 0 comes back as a ghost of
	itself the moment the cursor arrives, which is exactly the class of bug
	the MountsJournal notes call "a runtime path is overwriting you".

	The one thing the copy does honour is visibility. So the plates the
	highlighter targets are HIDDEN as well as faded, a deliberate exception
	to the alpha-only rule, and it is safe because Rematch never calls Show()
	on any of them: a grep of every Show/SetShown against a Back or Background
	texture finds only the pet card's content back and the dialog edit box,
	neither of which is a highlight target. Everything else in this file
	stays alpha-only.
------------------------------------------------------------------------------]]
local function hidePlate(tex)
	if not tex or not tex.SetAlpha then return end
	tex:SetAlpha(0)
	tex:Hide()
end


--[[ WHITE LABELS THAT STAY WHITE ----------------------------------------------
	Rematch paints its labels gold on OnLeave, OnEnable and inside its own
	Update methods, so a one-shot SetTextColor lasts until the first hover.
	Re-white from hooks on the same scripts, which run after Rematch's.
	Disabled stays grey: Rematch's own OnDisable already does that and we do
	not override it.
------------------------------------------------------------------------------]]
local function keepWhite(btn, label)
	label = label or btn.Text or (btn.GetFontString and btn:GetFontString())
	if not label then return end
	if btn.euiWhite then return end
	btn.euiWhite = true
	local function white()
		if not btn.IsEnabled or btn:IsEnabled() then S.White(label) end
	end
	white()
	btn:HookScript("OnLeave", white)
	btn:HookScript("OnEnable", white)
	btn:HookScript("OnShow", white)
end


-- RematchPanelButtonTemplate: the red three-slice button. Back[] and
-- Highlight[] are parentArrays, so S.Button's keyed fade never sees them.
local function panelButton(btn)
	if not btn or btn.euiSkinned then return end
	btn.euiSkinned = true
	clearBackdrop(btn)
	fadeArray(btn.Back)
	fadeArray(btn.Highlight)
	S.Button(btn)
	-- The pushed nudge (-1,-2) is Rematch's own and reads fine on a flat
	-- block, so it is left alone.
	keepWhite(btn)
end


-- RematchGreyPanelButtonTemplate and RematchFilterButtonTemplate: a grey
-- plate with a white label and, on the filter variant, an arrow.
local function greyButton(btn)
	if not btn or btn.euiSkinned then return end
	btn.euiSkinned = true
	clearBackdrop(btn)
	if btn.Back then btn.Back:SetAlpha(0) end
	if btn.Highlight then btn.Highlight:SetAlpha(0) end
	S.Button(btn, {"Arrow"})
	if btn.Arrow then btn.Arrow:SetVertexColor(1, 1, 1, .9) end
	keepWhite(btn)
end


-- RematchSmallGreyButtonTemplate: a 24px grey plate whose content is a
-- parentKey Icon glyph. Named through, or it renders as an empty block.
-- Its mixin highlights (Back, Icon) on hover, so the plate is a highlighter
-- target and is hidden, not faded; see hidePlate below.
local function smallGreyButton(btn)
	if not btn or btn.euiSkinned then return end
	btn.euiSkinned = true
	if btn.Back then btn.Back:SetAlpha(0); btn.Back:Hide() end
	S.Button(btn, {"Icon"})
end


-- RematchCheckButtonTemplate and RematchRadioButtonTemplate: Blizzard's
-- checkbox art with a gold label to the right.
local function checkButton(cb)
	if not cb or cb.euiSkinned then return end
	cb.euiSkinned = true
	S.Checkbox(cb)
	keepWhite(cb)
end


-- RematchEditBoxTemplate / RematchSearchBoxTemplate: Back[] three-slice art
-- from Rematch's controls sheet, a Clear button, and on the search variant a
-- magnifier plus placeholder. S.EditBox's fade takes the magnifier with the
-- border art, so restore it afterwards.
function editBox(eb)
	if not eb or eb.euiSkinned then return end
	eb.euiSkinned = true
	clearBackdrop(eb)
	fadeArray(eb.Back)
	S.EditBox(eb)
	if eb.SearchIcon then
		eb.SearchIcon:SetAlpha(.6)
		-- Rematch already anchors it 6px in with a 24px text inset, which is
		-- right for a flat box too; only the alpha needed restoring.
	end
	if eb.Instructions then eb.Instructions:SetAlpha(1) end
end


--[[ TITLE BAR BUTTONS ---------------------------------------------------------
	RematchTitlebarButtonTemplate is a red round button whose glyph is baked
	into the same texture as the disc, selected by TexCoord, so the disc
	cannot be faded without the glyph going with it. Replace the glyph
	instead: the house close X for "close", EllesmereUI's own arrows for the
	mode buttons, and font glyphs for minimise/maximise, which no shipped
	atlas covers. Rematch swaps icons at runtime through SetIcon (minimise
	<-> maximise, lock <-> unlock), so the glyph follows that.
------------------------------------------------------------------------------]]
-- The EllesmereUI entries are relative to the host's media folder, which a
-- standalone module keeps under its own name: resolve through ns.HostMedia.
local ARROW_TEX = {
	left = "icons\\eui-arrow-left.png",
	right = "icons\\eui-arrow-right.png",
}
local LOCK_TEX = {
	lock = "Interface\\Buttons\\LockButton-Locked-Up",
	unlock = "Interface\\Buttons\\LockButton-Unlocked-Up",
}
-- If the padlock files are not there (SetTexture reports a missing file by
-- returning false), fall back to the one lock glyph EllesmereUI ships, and
-- mark the locked state by tinting it with the accent.
local LOCK_FALLBACK = "icons\\eui-unlocked-small.png"
local GLYPH_TEXT = {minimize = "\226\128\147", maximize = "+", pin = "\226\128\162", flip = "<>"}

local function titleButton(btn)
	if not btn or btn.euiSkinned then return end
	btn.euiSkinned = true

	for _, getter in ipairs({"GetNormalTexture", "GetPushedTexture",
		"GetDisabledTexture", "GetHighlightTexture"}) do
		local fn = btn[getter]
		local t = fn and fn(btn)
		if t then t:SetAlpha(0) end
	end

	if btn.icon == "close" then
		S.CloseButton(btn)
		return
	end

	local tex = btn:CreateTexture(nil, "OVERLAY")
	tex:SetPoint("CENTER")
	tex:SetSize(14, 14)
	local fs = btn:CreateFontString(nil, "OVERLAY")
	fs:SetPoint("CENTER", 0, 1)
	local fontPath, fontFlag = S.GetFont()
	fs:SetFont(fontPath, 16, fontFlag or "")
	fs:SetTextColor(1, 1, 1)

	local function reflect()
		local a = (not btn.IsEnabled or btn:IsEnabled()) and .8 or .3
		if btn:IsMouseOver() and (not btn.IsEnabled or btn:IsEnabled()) then a = 1 end
		tex:SetAlpha(a)
		fs:SetAlpha(a)
	end

	local function apply()
		local icon = btn.icon
		tex:Hide(); fs:Hide()
		if ARROW_TEX[icon] then
			tex:SetTexture(ns.HostMedia(ARROW_TEX[icon]))
			tex:SetTexCoord(0, 1, 0, 1)
			tex:SetSize(12, 12)
			tex:Show()
		elseif LOCK_TEX[icon] then
			tex:SetVertexColor(1, 1, 1)
			if tex:SetTexture(LOCK_TEX[icon]) then
				-- The padlock sits in the centre of a 32px sheet with a
				-- plate around it; crop to the lock.
				tex:SetTexCoord(.25, .75, .25, .75)
				tex:SetSize(16, 16)
			else
				tex:SetTexture(ns.HostMedia(LOCK_FALLBACK))
				tex:SetTexCoord(0, 1, 0, 1)
				tex:SetSize(12, 12)
				if icon == "lock" then tex:SetVertexColor(S.GetAccentColor()) end
			end
			tex:Show()
		elseif GLYPH_TEXT[icon] then
			fs:SetText(GLYPH_TEXT[icon])
			fs:Show()
		end
		reflect()
	end
	apply()
	if type(btn.SetIcon) == "function" then hooksecurefunc(btn, "SetIcon", apply) end
	btn:HookScript("OnEnter", reflect)
	btn:HookScript("OnLeave", reflect)
	btn:HookScript("OnEnable", reflect)
	btn:HookScript("OnDisable", reflect)
end


--[[ TABS ----------------------------------------------------------------------
	Collections' bottom row, the one ours sits beside in journal mode, is
	stock 12.x Blizzard PanelTabButtonTemplate tabs, and on this client the
	thing that restyles them is NOT EllesmereUI: /fstack showed an unnamed
	child frame carrying a `Center` texture one level below each tab, the
	signature of a BackdropTemplate plate, and the addon that hangs one on
	CollectionsJournalTab1..6 is atrocityEssentials
	(Skinning/Frames/Collectables.lua, through its private S.Tab). Its
	recipe, read from its SkinningAPI: strip every texture, a backdrop
	plate inset 2px in the control colour with a 1px black edge one frame
	level below the tab, a grey 15% hover over the plate, the theme font
	at 12pt outlined, and a brand-coloured 35% plate inset 1px inside the
	backdrop while selected. Blizzard's own label and its gold-to-white
	colouring are kept.

	Each Rematch tab therefore carries a real PanelTabButtonTemplate button
	as its face, parented to it so it shows, hides and moves with it, sized
	by Blizzard's TabResize, selected and deselected by Blizzard's own
	helpers, clicking through to the Rematch tab; and the face is dressed
	in that same recipe, with the colours and font read live from the
	public atrocityEssentials.Theme table. Without atrocityEssentials the
	face gets EllesmereUI's own tab primitive instead, which is what the
	Collections row wears when EllesmereUI is the one skinning it.
------------------------------------------------------------------------------]]
local panelTabs = setmetatable({}, {__mode = "k"})

-- What atrocityEssentials paints with. Its skin palette is private; these
-- are its documented constants, with the three that its public Theme table
-- carries (border, brand, font) read from there so a user recolour lands.
local AE_CONTROL = {.055, .055, .055, .90}
local AE_HOVER = {.851, .851, .851, .15}
local AE_SELECTED_A = .35

local function aeTheme()
	local ae = _G.atrocityEssentials
	return ae and type(ae.Theme) == "table" and ae.Theme or nil
end

local function aeBrand()
	local t = aeTheme()
	local b = t and t.brand
	if type(b) == "table" and b[1] then return b[1], b[2], b[3] end
	return .451, .506, 1
end

local function aeBorder()
	local t = aeTheme()
	local b = t and t.border
	if type(b) == "table" and b[1] then return b[1], b[2], b[3], b[4] or 1 end
	return 0, 0, 0, 1
end


-- Dress a Blizzard tab face the way atrocityEssentials dresses Collections'.
local function dressFaceAtrocity(face)
	local d = {}
	for _, t in ipairs(face.TabTextures or {}) do t:SetAlpha(0) end
	for _, k in ipairs({"Left", "Middle", "Right", "LeftActive", "MiddleActive", "RightActive",
		"LeftHighlight", "MiddleHighlight", "RightHighlight"}) do
		if face[k] then face[k]:SetAlpha(0) end
	end
	if face.SetPushedTextOffset then face:SetPushedTextOffset(0, 0) end

	local bd = CreateFrame("Frame", nil, face, "BackdropTemplate")
	bd:SetPoint("TOPLEFT", face, "TOPLEFT", 2, -2)
	bd:SetPoint("BOTTOMRIGHT", face, "BOTTOMRIGHT", -2, 2)
	local lvl = face:GetFrameLevel()
	bd:SetFrameLevel(lvl > 0 and lvl - 1 or 0)
	bd:SetBackdrop({bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1})
	bd:SetBackdropColor(AE_CONTROL[1], AE_CONTROL[2], AE_CONTROL[3], AE_CONTROL[4])
	bd:SetBackdropBorderColor(aeBorder())
	d.bd = bd

	local hover = face:CreateTexture(nil, "HIGHLIGHT")
	hover:SetColorTexture(AE_HOVER[1], AE_HOVER[2], AE_HOVER[3], AE_HOVER[4])
	hover:SetPoint("TOPLEFT", bd, "TOPLEFT", 1, -1)
	hover:SetPoint("BOTTOMRIGHT", bd, "BOTTOMRIGHT", -1, 1)
	d.hover = hover

	local sel = face:CreateTexture(nil, "ARTWORK")
	local br, bg, bb = aeBrand()
	sel:SetColorTexture(br, bg, bb, AE_SELECTED_A)
	sel:SetPoint("TOPLEFT", bd, "TOPLEFT", 1, -1)
	sel:SetPoint("BOTTOMRIGHT", bd, "BOTTOMRIGHT", -1, 1)
	sel:Hide()
	d.sel = sel

	local t = aeTheme()
	local fontPath = t and t.fontFace
	local size = (t and t.fontSizeNormal) or 12
	local outline = (t and t.fontOutline) or "OUTLINE"
	if face.Text and fontPath then
		-- Blizzard's three state font objects carry the gold/white colours;
		-- only the face, size and outline change, per state, so the colour
		-- state machine keeps working. They are kept on the dress record
		-- because PanelTemplates_SelectTab overwrites the disabled one with
		-- Blizzard's own small font on every selection, which is what made
		-- the selected label change size; paint re-pins them after it.
		d.fonts = {}
		for _, pair in ipairs({{"GetNormalFontObject", "SetNormalFontObject"},
			{"GetHighlightFontObject", "SetHighlightFontObject"},
			{"GetDisabledFontObject", "SetDisabledFontObject"}}) do
			local get, set = face[pair[1]], face[pair[2]]
			local cur = get and get(face)
			if cur and set then
				local obj = CreateFont("RematchEUISkinTabFont" .. pair[1] .. tostring(face):gsub("%W", ""))
				obj:CopyFontObject(cur)
				obj:SetFont(fontPath, size, outline)
				obj:SetShadowOffset(0, 0)
				d.fonts[pair[2]] = obj
				pcall(set, face, obj)
			end
		end
	end
	return d
end


local function repinFonts(face)
	local dress = face.euiDress
	if not (dress and dress.fonts) then return end
	for setter, obj in pairs(dress.fonts) do
		local set = face[setter]
		if set then pcall(set, face, obj) end
	end
end


--[[ WHICH LOOK DOES THE ROW BESIDE US WEAR ------------------------------------
	Three possibilities on a given client, decided without needing the
	Collections window to have been opened:

	  "atrocity"  atrocityEssentials is loaded: it skins Collections, and
	              its recipe above is what the row wears.
	  "eui"       no atrocityEssentials, and EllesmereUI's window skin for
	              Collections is on: the row wears the engine's own Tab
	              primitive, so the face gets S.Tab.
	  "blizzard"  neither: the row is stock, and so is the face. This is
	              what the MountsJournal skin does with its own tab row.
------------------------------------------------------------------------------]]
-- Measured, not inferred: with atrocityEssentials off, the Collections row
-- on this client is plain 12.x Blizzard art (dark, the selected tab taller)
-- even though EllesmereUI's Collections skin is on, so the engine's window
-- style says nothing about the tabs. The one thing that does is the row
-- itself: a tab the engine's Tab primitive has dressed carries two labels
-- (Blizzard's hidden one and its own), a stock tab carries one. Until the
-- Collections window exists the answer is "stock", and paint re-asks.
local function collectionsTabStyle()
	if _G.atrocityEssentials then return "atrocity" end
	local ref = CollectionsJournal and CollectionsJournal.MountsTab
	if ref and ref.GetRegions then
		local labels = 0
		for i = 1, select("#", ref:GetRegions()) do
			local r = select(i, ref:GetRegions())
			if r and r.IsObjectType and r:IsObjectType("FontString") then labels = labels + 1 end
		end
		if labels >= 2 then return "eui" end
	end
	return "blizzard"
end


local function dressFace(face)
	local style = collectionsTabStyle()
	if style == "atrocity" then return dressFaceAtrocity(face) end
	if style == "eui" then S.Tab(face) end
	return {style = style}
end


-- A template name cannot be tested for existence from Lua (it is not a
-- global), so the creation is tried and the bottom template is the
-- fallback for a client without the top one.
local function newFace(tab, top)
	if top then
		local ok, face = pcall(CreateFrame, "Button", nil, tab, "PanelTopTabButtonTemplate")
		if ok and face then return face end
	end
	return CreateFrame("Button", nil, tab, "PanelTabButtonTemplate")
end


-- The Blizzard face for a Rematch tab, created on first use per orientation.
local function tabFace(tab, top)
	local d = panelTabs[tab]
	local key = top and "top" or "bottom"
	if d[key] then return d[key] end
	local face = newFace(tab, top)
	local near = top and "BOTTOMLEFT" or "TOPLEFT"
	face:SetPoint(near, tab, near, 0, 0)
	face:SetFrameLevel(tab:GetFrameLevel() + 1)
	face:SetScript("OnClick", function() tab:Click() end)
	face:SetText(tab.Text and tab.Text:GetText() or "")
	if PanelTemplates_TabResize then PanelTemplates_TabResize(face, 0) end
	face.euiDress = dressFace(face)
	d[key] = face
	return face
end


local function paintPanelTab(tab)
	local d = panelTabs[tab]
	if not d then return end
	local top = tab.isTopTab and true or false
	local face = tabFace(tab, top)
	local other = d[top and "bottom" or "top"]
	if other then other:Hide() end
	face:Show()
	local sel = tab.isSelected and true or false
	-- The engine's tab primitive (fallback path) reads selection off the
	-- face's own flag; mirror Rematch's onto it.
	face.isSelected = sel
	if sel then
		if PanelTemplates_SelectTab then PanelTemplates_SelectTab(face) end
	else
		if PanelTemplates_DeselectTab then PanelTemplates_DeselectTab(face) end
	end
	repinFonts(face)
	local dress = face.euiDress
	-- A stock face is left entirely to Blizzard: its art, its per-state
	-- label offsets, its taller selected tab. That is what the row beside
	-- it does without atrocityEssentials. It is promoted to the engine's
	-- look if the Collections row turns out to wear it once that window
	-- exists (see collectionsTabStyle).
	if dress and dress.style == "blizzard" and collectionsTabStyle() == "eui" then
		dress.style = "eui"
		S.Tab(face)
	end
	if dress and dress.style ~= "blizzard" and face.Text then
		-- Blizzard offsets the label per state to sit on its own art; with
		-- the art gone the label is centred, as the row beside us has it.
		face.Text:ClearAllPoints()
		face.Text:SetPoint("CENTER", face, "CENTER", 0, 0)
	end
	if dress and dress.sel then dress.sel:SetShown(sel) end
	if dress and dress.bd and dress.bd.SetBackdropBorderColor then
		dress.bd:SetBackdropBorderColor(aeBorder())
	end
	if dress and dress.style == "eui" then S.Tab(face) end
	local w, h = face:GetSize()
	if w and w > 0 and h and h > 0 then tab:SetSize(w, h) end
end


-- Repainted from the looks hook.
tabRepaints[#tabRepaints + 1] = function()
	for tab in pairs(panelTabs) do if not tab:IsForbidden() then paintPanelTab(tab) end end
end


--[[ SEATING THE ROW ------------------------------------------------------------
	Rematch's tabs are a fixed 68 wide seated every 64, so they overlap into
	one strip; Blizzard's are sized to their label. Rematch re-seats its row
	from panelTabs:Configure on every layout change, so the correction runs
	from a hook on that, after it. The order comes from the x offset Rematch
	just assigned, not from GetLeft, which is stale during Configure.
	Chained on the edge nearest the window, flush with the row's own edge
	there, which Rematch places 2px inside the window, as Blizzard seats
	its rows. With the atrocity plate inset 2px on each side, a 3px overlap
	of the frames leaves a 1px seam between plates.
------------------------------------------------------------------------------]]
local function seatPanelTabs(row)
	local shown = {}
	for i = 1, select("#", row:GetChildren()) do
		local tab = select(i, row:GetChildren())
		if tab and panelTabs[tab] and tab:IsShown() then
			local _, _, _, x = tab:GetPoint(1)
			shown[#shown + 1] = {tab = tab, x = x or 0}
		end
	end
	if #shown == 0 then return end
	table.sort(shown, function(a, b) return a.x < b.x end)

	local below = not row.tabsAtTop
	local edge = below and "TOPLEFT" or "BOTTOMLEFT"
	local edgeR = below and "TOPRIGHT" or "BOTTOMRIGHT"
	local style = collectionsTabStyle()
	-- atrocity: 2px-inset plates with a 1px seam. eui: the engine's 1px
	-- seam. blizzard: the +3 Blizzard's own PanelTemplates code uses when
	-- it re-chains a tab row at runtime (the -16 in the Collections XML is
	-- overridden by that code and, tried here, stacked the tabs on top of
	-- each other).
	local overlap = (style == "atrocity" and -3) or (style == "eui" and 1) or 3
	-- atrocityEssentials settles each Collections tab so its plate's top
	-- sits exactly one pixel below the window's bottom edge. Our row's
	-- near edge is 2px inside the window and the plate is inset 2px, so
	-- without this the plate touched the window; one pixel outward matches.
	local seat = style == "atrocity" and (below and -1 or 1) or 0
	local total, prev = 0, nil
	for _, e in ipairs(shown) do
		local tab = e.tab
		paintPanelTab(tab)
		tab:ClearAllPoints()
		if prev then
			tab:SetPoint(edge, prev, edgeR, overlap, 0)
			total = total + overlap
		else
			tab:SetPoint(edge, row, edge, 0, seat)
		end
		total = total + (tab:GetWidth() or 0)
		prev = tab
	end
	row:SetWidth(total)
end


local function panelTab(tab)
	if not tab or panelTabs[tab] then return end
	-- Rematch's plate and its ADD-blend hover copy; the highlighter is not
	-- involved here (the mixin shows Highlight itself), so alpha suffices.
	if tab.Back then tab.Back:SetAlpha(0) end
	if tab.Highlight then tab.Highlight:SetAlpha(0) end
	if tab.Text then tab.Text:SetTextColor(0, 0, 0, 0) end

	local d = {}
	panelTabs[tab] = d
	local orig = tab.Text
	if orig then
		hooksecurefunc(orig, "SetText", function()
			for _, k in ipairs({"top", "bottom"}) do
				if d[k] then
					d[k]:SetText(orig:GetText() or "")
					if PanelTemplates_TabResize then PanelTemplates_TabResize(d[k], 0) end
				end
			end
		end)
	end
	-- Rematch's own Update runs from OnLoad, mouse scripts and
	-- panelTabs:Update (selection); it is where isSelected is consumed, so
	-- it is where the face is repainted.
	if type(tab.Update) == "function" then hooksecurefunc(tab, "Update", paintPanelTab) end
	paintPanelTab(tab)
end


-- RematchStretchTabTemplate: the pet type bar's tabs. Same idea, but the
-- selected state is written through SetSelected rather than a field.
local stretchTabs = setmetatable({}, {__mode = "k"})

local function paintStretchTab(tab)
	local d = stretchTabs[tab]
	if not d then return end
	local sel = tab.isSelected and true or false
	if sel or tab:IsMouseOver() then
		d.label:SetTextColor(1, 1, 1, 1)
	else
		d.label:SetTextColor(gold())
	end
	local r, g, b, shown = accentBar()
	d.underline:SetColorTexture(r, g, b, 1)
	d.underline:SetShown(sel and shown)
	d.label:ClearAllPoints()
	d.label:SetPoint("CENTER", tab, "CENTER", 0, 0)
end

-- Repainted from the looks hook: the underline colour is read live.
tabRepaints[#tabRepaints + 1] = function()
	for tab in pairs(stretchTabs) do if not tab:IsForbidden() then paintStretchTab(tab) end end
end


local function stretchTab(tab)
	if not tab or stretchTabs[tab] then return end
	for _, k in ipairs({"Left", "Mid", "Right"}) do
		if tab[k] then tab[k]:SetAlpha(0) end
	end
	fadeArray(tab.Highlights)

	local d = {}
	d.bg = tab:CreateTexture(nil, "BACKGROUND", nil, -6)
	d.bg:SetColorTexture(.068, .056, .052, 1)
	d.bg:SetAllPoints()

	d.hover = tab:CreateTexture(nil, "HIGHLIGHT")
	d.hover:SetAllPoints()
	d.hover:SetColorTexture(1, 1, 1, .06)

	-- HasStuff is meaningful: it marks a tab whose types are filtered. Keep
	-- it as an accent wash rather than Blizzard's yellow glow.
	if tab.HasStuff then
		tab.HasStuff:SetAlpha(0)
		local wash = tab:CreateTexture(nil, "BACKGROUND", nil, -5)
		wash:SetAllPoints()
		addWash(wash, .2)
		wash:Hide()
		d.hasStuff = wash
		hook(tab.HasStuff, "Show", function() wash:Show() end)
		hook(tab.HasStuff, "Hide", function() wash:Hide() end)
		hook(tab.HasStuff, "SetShown", function(_, shown) wash:SetShown(shown) end)
		wash:SetShown(tab.HasStuff:IsShown())
	end

	local orig = tab.Text
	if orig then orig:SetTextColor(0, 0, 0, 0) end
	d.label = tab:CreateFontString(nil, "OVERLAY")
	local fontPath, fontFlag = S.GetFont()
	d.label:SetFont(fontPath, 11, fontFlag or "")
	d.label:SetText(orig and orig:GetText() or "")
	if orig then
		hooksecurefunc(orig, "SetText", function() d.label:SetText(orig:GetText() or "") end)
	end

	d.underline = tab:CreateTexture(nil, "OVERLAY", nil, 6)
	d.underline:SetHeight(1)
	d.underline:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 0)
	d.underline:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, 0)
	d.underline:Hide()

	stretchTabs[tab] = d
	if type(tab.SetSelected) == "function" then hooksecurefunc(tab, "SetSelected", paintStretchTab) end
	tab:HookScript("OnEnter", paintStretchTab)
	tab:HookScript("OnLeave", paintStretchTab)
	paintStretchTab(tab)
end


-- RematchAllButtonTemplate: the +/- All toggle above expandable lists. Its
-- Back carries the +/- glyph AND the plate in one texture, so the plate
-- goes (it is a highlighter target too) and the glyph is redrawn as ours,
-- following the expanded/collapsed state Rematch writes through Update.
-- The label sits 7px right of centre in the template to leave room for
-- the glyph on the left, which is where ours goes.
local function allButton(btn)
	if not btn or btn.euiSkinned then return end
	btn.euiSkinned = true
	hidePlate(btn.Back)
	if btn.Highlight then btn.Highlight:SetAlpha(0) end
	S.Button(btn)
	local glyph = newPlusMinus(btn, 10)
	glyph:SetPoint("CENTER", btn, "LEFT", 13, 0)
	local function paint()
		glyph:SetExpanded(btn.isExpanded)
		glyph:SetColor(1, 1, 1, btn:IsEnabled() and .8 or .3)
	end
	if type(btn.Update) == "function" then hooksecurefunc(btn, "Update", paint) end
	paint()
end


-- Rematch's inset templates draw their frame as eight named atlas pieces plus
-- a Back tile, all regions of the frame itself. Fade the chrome by name so a
-- meaningful sibling region (a badge, a status icon) is left standing.
local INSET_PIECES = {"TopLeft", "TopRight", "BottomLeft", "BottomRight",
	"Top", "Bottom", "Left", "Right", "Back", "InsetBack",
	"InsetBg", "InsetBorderTopLeft", "InsetBorderTopRight", "InsetBorderBottomLeft",
	"InsetBorderBottomRight", "InsetBorderTop", "InsetBorderBottom",
	"InsetBorderLeft", "InsetBorderRight", "Bg", "TopTileStreaks"}

local function fadeInset(frame)
	if not frame then return end
	for _, k in ipairs(INSET_PIECES) do
		local r = frame[k]
		if r and r.SetAlpha and r.IsObjectType and r:IsObjectType("Texture") then
			r:SetAlpha(0)
		end
	end
end


--[[ A PLATE UNDER A FRAME WE CANNOT FLATTEN ------------------------------------
	S.Panel fades every texture region of the frame it paints. That is right
	for a header bar and wrong for a loadout slot, whose regions include the
	pet's type decal, its health bar and its badges. For those, the house
	plate and border go on a child frame one level BELOW the host, so they
	draw under the host's own regions, and the host's chrome is faded by
	name instead. Same trick ElvUI's backdrops use.
------------------------------------------------------------------------------]]
local plates = setmetatable({}, {__mode = "k"})

local function plateUnder(frame, opts)
	if not frame or plates[frame] then return plates[frame] end
	local host = CreateFrame("Frame", nil, frame)
	host:SetAllPoints(frame)
	host:EnableMouse(false)
	local level = frame:GetFrameLevel()
	host:SetFrameLevel(level > 0 and level - 1 or 0)
	S.Panel(host, opts)
	plates[frame] = host
	return host
end


-- Header bars: the RematchPanelInsetFrameTemplate strip along the top of
-- every panel. Nothing meaningful lives in its regions, so it can be
-- flattened outright.
local function headerBar(frame)
	if not frame or frame.euiSkinned then return end
	frame.euiSkinned = true
	fadeInset(frame)
	S.Panel(frame)
end


--[[ MAIN WINDOW ---------------------------------------------------------------
	RematchFrame is a RematchDefaultPanelTemplate: metal corner and edge
	atlases, a rock tile, the top streaks and a title. All plain regions, so
	S.Shell's fade reaches them; the named pieces are faded as well so a
	layout Configure, which re-anchors every panel, cannot bring one back.
------------------------------------------------------------------------------]]
local function skinWindow()
	local win = RematchFrame
	if win.euiSkinned then return end
	win.euiSkinned = true

	fadeInset(win)
	S.Shell(win)
	addBorder(win)

	-- The template's own title and close button are unused: the title bar
	-- carries both. Rematch hides the close button itself.
	if win.Title then win.Title:SetAlpha(0) end

	-- In journal mode Rematch seats the window at (-1, 0) from Collections'
	-- bottom-left corner: its stock metal edge is drawn a pixel inside the
	-- frame, and the -1 lines that edge up with the Blizzard window's. Our
	-- shell is painted to the frame's own rect, so the same -1 shows as a
	-- one-pixel overhang past the Collections tab row. Configure is where
	-- Rematch sets that anchor, on every layout change, so the correction
	-- runs from a hook on it, after it. The window is 606 tall, the same as
	-- Collections, so only the x offset needs changing.
	local function seatInJournal()
		if not journalActive() then return end
		win:ClearAllPoints()
		win:SetPoint("BOTTOMLEFT", CollectionsJournal, "BOTTOMLEFT", 0, 0)
	end
	hook(win, "Configure", seatInJournal)
	seatInJournal()

	-- Suppress whatever Collections is drawing behind us while we sit in its
	-- seat, and hand it straight back when we leave. Standalone, nothing is
	-- behind us but the world, and journalActive() keeps both paths inert.
	win:HookScript("OnShow", function()
		if journalActive() then suppressBehind() end
		if S.RefreshLooks then S.RefreshLooks() end
	end)
	win:HookScript("OnHide", function() fadeCollections(false) end)
	if CollectionsJournal then
		CollectionsJournal:HookScript("OnShow", function()
			if win:IsShown() and journalActive() then suppressBehind() end
		end)
	end
	if win:IsShown() and journalActive() then suppressBehind() end
end


--[[ CHROME --------------------------------------------------------------------
	Title bar, toolbar, bottom bar, panel tabs and team tabs. Rematch's
	Configure re-anchors and re-shows all of these on every layout change,
	so nothing here depends on a position: only art and colour are touched.
------------------------------------------------------------------------------]]
local function skinTitleBar()
	local bar = RematchFrame.TitleBar
	if not bar or bar.euiSkinned then return end
	bar.euiSkinned = true

	if bar.Title then S.Font(bar.Title); S.White(bar.Title) end

	-- The journal-mode portrait: a masked icon and a metal corner. EllesmereUI
	-- removes the portrait from every window it shells, so it goes here too.
	if bar.Portrait then S.FadeRegions(bar.Portrait) end

	for _, k in ipairs({"CloseButton", "MinimizeButton", "LockButton",
		"PrevModeButton", "NextModeButton"}) do
		titleButton(bar[k])
	end
end


local function skinToolbar()
	local bar = RematchFrame.ToolBar
	if not bar or bar.euiSkinned then return end
	bar.euiSkinned = true

	-- InsetFrameTemplate: a Bg and a NineSlice box. Rematch also reparents the
	-- window's top streaks in here at login; fadeInset above already caught
	-- them on the window, and the key still resolves from there.
	S.Inset(bar)
	S.FadeRegions(bar)

	local totals = bar.TotalsButton
	if totals then
		hidePlate(totals.Back)
		if totals.Highlight then totals.Highlight:SetAlpha(0) end
		if totals.Border then totals.Border:SetAlpha(0) end
		S.Button(totals)
		keepWhite(totals)
	end

	-- The achievement plate is deliberately left alone: its wings and shield
	-- read as an achievement, exactly as they do in the Pet Journal, and its
	-- art is unnamed so nothing could be named through a flatten anyway.

	-- Toolbar buttons: the icon carries the meaning and Rematch swaps it at
	-- runtime (SetTexture per item), the vertical Border is a divider drawn
	-- to make the row read as inset. Fade the divider, square the icon, and
	-- give it the 1px edge every other icon in the skin has. Left as a
	-- SecureActionButton with its own hover, which highlights the icon
	-- itself and so needs no guard.
	for _, btn in ipairs(bar.Buttons or {}) do
		if btn and not btn.euiSkinned then
			btn.euiSkinned = true
			if btn.Border then btn.Border:SetAlpha(0) end
			if btn.Icon then
				squareIcon(btn.Icon)
				newEdges(btn, btn.Icon, 1)
			end
		end
	end
end


local function skinBottomBar()
	local bar = RematchFrame.BottomBar
	if not bar or bar.euiSkinned then return end
	bar.euiSkinned = true
	-- The template makes these 23 tall on a 22-tall bar, anchored at the
	-- bottom, so the top pixel stands proud of the bar and a pixel closer
	-- to the list above than the rest of the row. Flat, that pixel shows.
	-- Shaved from the top only: the bottom anchor is where it should be,
	-- and Rematch sets widths on layout changes but never heights.
	for _, k in ipairs({"SummonButton", "FindBattleButton", "SaveAsButton", "SaveButton"}) do
		local btn = bar[k]
		panelButton(btn)
		if btn then btn:SetHeight(22) end
	end
	checkButton(bar.UseRematchCheckButton)
end


local function skinPanelTabs()
	local tabs = RematchFrame.PanelTabs
	if not tabs then return end
	-- Every tab is created during Rematch's own layout registration, which
	-- runs at load, so the row is complete by the time we are dispatched.
	eachChild(function(tab)
		if tab and tab.Text and tab.Back then panelTab(tab) end
	end, tabs:GetChildren())
	hook(tabs, "Configure", seatPanelTabs)
	seatPanelTabs(tabs)
end


local function skinTeamTabs()
	local tabs = RematchFrame.TeamTabs
	if not tabs or tabs.euiSkinned then return end
	tabs.euiSkinned = true

	-- Rematch builds Tabs in its own PLAYER_LOGIN handler, whose event frame
	-- predates ours, so the row exists on both backends by the time we run.
	for _, tab in ipairs(tabs.Tabs or {}) do
		if tab and not tab.euiSkinned then
			tab.euiSkinned = true
			-- The tab plate is a 44px texture on a 36px button, drawn to
			-- overhang into the window with a shadow strip beneath. Flat, the
			-- button's own rect is the tab. The plate is a highlighter target
			-- (Show(Icon, Background)), hence hidden rather than faded.
			hidePlate(tab.Background)
			S.Button(tab, {"Icon"})
			if tab.Icon then
				-- Rematch seats a 30px icon at 2,-5 inside a 36x44 button
				-- drawn for its plate art. Flat, an icon inside a square inside
				-- a rectangle read as three nested shapes, so the icon now
				-- fills the button to a 1px inset and IS the button, with the
				-- house edge around it. The rounded mask follows the icon.
				tab.Icon:ClearAllPoints()
				tab.Icon:SetPoint("TOPLEFT", tab, "TOPLEFT", 1, -1)
				tab.Icon:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", -1, 1)
				newEdges(tab, tab.Icon, 1)
			end
		end
	end
end


local function skinChrome()
	stage("chrome:titlebar", skinTitleBar)
	stage("chrome:toolbar", skinToolbar)
	stage("chrome:bottombar", skinBottomBar)
	stage("chrome:paneltabs", skinPanelTabs)
	stage("chrome:teamtabs", skinTeamTabs)
end


--[[ PET TYPE BAR --------------------------------------------------------------
	Three tabs (Rematch's own RematchTypeBarTabTemplate, not the stretch
	tab) over a row of ten pet family icons, framed by one 267x54 texture
	whose cutout moves under the selected tab. The tabs get the house
	treatment; the frame art is faded and a plain inset plate goes under the
	icon row. The family icons, the Level 25 toggle and the selection
	overlays are meaning and stay exactly as Rematch draws them.
------------------------------------------------------------------------------]]
local typeTabs = setmetatable({}, {__mode = "k"})

local function paintTypeTab(tab)
	local d = typeTabs[tab]
	if not d then return end
	local sel = tab.Selected and tab.Selected:IsShown()
	if sel or tab:IsMouseOver() then
		d.label:SetTextColor(1, 1, 1, 1)
	else
		d.label:SetTextColor(gold())
	end
	local r, g, b, shown = accentBar()
	d.underline:SetColorTexture(r, g, b, 1)
	d.underline:SetShown(sel and shown)
	d.label:ClearAllPoints()
	d.label:SetPoint("CENTER", tab, "CENTER", 0, 0)
end

-- Repainted from the looks hook: the underline colour is read live.
tabRepaints[#tabRepaints + 1] = function()
	for tab in pairs(typeTabs) do if not tab:IsForbidden() then paintTypeTab(tab) end end
end


local function typeTab(tab)
	if not tab or typeTabs[tab] then return end
	if tab.Selected then tab.Selected:SetAlpha(0) end
	if tab.Highlight then tab.Highlight:SetAlpha(0) end

	local d = {}
	d.bg = tab:CreateTexture(nil, "BACKGROUND", nil, -6)
	d.bg:SetColorTexture(.068, .056, .052, 1)
	d.bg:SetAllPoints()

	d.hover = tab:CreateTexture(nil, "HIGHLIGHT")
	d.hover:SetAllPoints()
	d.hover:SetColorTexture(1, 1, 1, .06)

	if tab.HasStuff then
		tab.HasStuff:SetAlpha(0)
		local wash = tab:CreateTexture(nil, "BACKGROUND", nil, -5)
		wash:SetAllPoints()
		addWash(wash, .2)
		wash:SetShown(tab.HasStuff:IsShown())
		hook(tab.HasStuff, "Show", function() wash:Show() end)
		hook(tab.HasStuff, "Hide", function() wash:Hide() end)
		hook(tab.HasStuff, "SetShown", function(_, shown) wash:SetShown(shown) end)
	end

	local orig = tab.Text
	if orig then orig:SetTextColor(0, 0, 0, 0) end
	d.label = tab:CreateFontString(nil, "OVERLAY")
	local fontPath, fontFlag = S.GetFont()
	d.label:SetFont(fontPath, 11, fontFlag or "")
	d.label:SetText(orig and orig:GetText() or "")
	if orig then
		hooksecurefunc(orig, "SetText", function() d.label:SetText(orig:GetText() or "") end)
	end

	d.underline = tab:CreateTexture(nil, "OVERLAY", nil, 6)
	d.underline:SetHeight(1)
	d.underline:SetPoint("BOTTOMLEFT", tab, "BOTTOMLEFT", 0, 0)
	d.underline:SetPoint("BOTTOMRIGHT", tab, "BOTTOMRIGHT", 0, 0)
	d.underline:Hide()

	typeTabs[tab] = d
	if tab.Selected then
		hook(tab.Selected, "Show", function() paintTypeTab(tab) end)
		hook(tab.Selected, "Hide", function() paintTypeTab(tab) end)
		hook(tab.Selected, "SetShown", function() paintTypeTab(tab) end)
	end
	tab:HookScript("OnEnter", paintTypeTab)
	tab:HookScript("OnLeave", paintTypeTab)
	paintTypeTab(tab)
end


local function skinTypeBar(bar)
	if not bar or bar.euiSkinned then return end
	bar.euiSkinned = true
	if bar.TabbedBorder then bar.TabbedBorder:SetAlpha(0) end
	for _, tab in ipairs(bar.Tabs or {}) do typeTab(tab) end
	level25Badge(bar)

	-- The icon row: a darker inset plate with the house border, on a child
	-- frame so it sits under the family icons rather than over them.
	local row = CreateFrame("Frame", nil, bar)
	row:SetPoint("TOPLEFT", bar, "TOPLEFT", 0, -24)
	row:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
	row:EnableMouse(false)
	local level = bar:GetFrameLevel()
	row:SetFrameLevel(level > 0 and level - 1 or 0)
	S.Panel(row, {inset = true})
end


--[[ PANELS --------------------------------------------------------------------]]
local function skinPetsPanel()
	local panel = RematchFrame.PetsPanel
	if not panel or panel.euiSkinned then return end
	panel.euiSkinned = true

	local top = panel.Top
	if top then
		headerBar(top)
		smallGreyButton(top.ToggleButton)
		greyButton(top.FilterButton)
		editBox(top.SearchBox)
		skinTypeBar(top.TypeBar)
	end
	if panel.ResultsBar then
		headerBar(panel.ResultsBar)
		if panel.ResultsBar.NumPets then S.White(panel.ResultsBar.NumPets) end
		if panel.ResultsBar.Filters then S.White(panel.ResultsBar.Filters) end
	end
end


local function skinTeamsPanel()
	local panel = RematchFrame.TeamsPanel
	if not panel or panel.euiSkinned then return end
	panel.euiSkinned = true
	local top = panel.Top
	if top then
		headerBar(top)
		allButton(top.AllButton)
		greyButton(top.TeamsButton)
		editBox(top.SearchBox)
	end
end


local function skinTargetsPanel()
	local panel = RematchFrame.TargetsPanel
	if not panel or panel.euiSkinned then return end
	panel.euiSkinned = true
	local top = panel.Top
	if top then
		headerBar(top)
		allButton(top.AllButton)
		editBox(top.SearchBox)
	end
end


local function skinQueuePanel()
	local panel = RematchFrame.QueuePanel
	if not panel or panel.euiSkinned then return end
	panel.euiSkinned = true
	if panel.PreferencesFrame then
		headerBar(panel.PreferencesFrame)
		smallGreyButton(panel.PreferencesFrame.PreferencesButton)
	end
	local top = panel.Top
	if top then
		headerBar(top)
		greyButton(top.QueueButton)
		if top.Label then S.White(top.Label) end
	end
	if panel.StatusBar then
		headerBar(panel.StatusBar)
		if panel.StatusBar.Text then S.White(panel.StatusBar.Text) end
	end
end


local function skinOptionsPanel()
	local panel = RematchFrame.OptionsPanel
	if not panel or panel.euiSkinned then return end
	panel.euiSkinned = true
	local top = panel.Top
	if top then
		headerBar(top)
		allButton(top.AllButton)
		editBox(top.SearchBox)
	end
	-- The two option widgets that are real buttons. The options list's
	-- checkboxes are a texture on each row, recoloured by Rematch to show
	-- state and dependency, and are left to it.
	local scale = panel.UseCustomScaleWidget
	if scale then greyButton(scale.ScaleButton) end
	local mgmt = panel.OptionsManagementWidget
	if mgmt then
		greyButton(mgmt.ResetButton)
		greyButton(mgmt.ExportButton)
	end
end


--[[ LOADED TEAM AND TARGET ----------------------------------------------------]]
local function skinLoadedTeamPanel()
	local panel = RematchFrame.LoadedTeamPanel
	if not panel or panel.euiSkinned then return end
	panel.euiSkinned = true

	for _, k in ipairs({"PreferencesFrame", "NotesFrame"}) do
		local f = panel[k]
		if f then
			headerBar(f)
			smallGreyButton(f.PreferencesButton or f.NotesButton)
		end
	end

	-- The team name plate: a gold tile with two unnamed doodads either end
	-- and the favourite star. The star is named through; the doodads are
	-- unnamed regions and go with the tile.
	local btn = panel.TeamButton
	if btn then
		-- Its hover highlights Back, so that one is hidden as well as faded.
		hidePlate(btn.Back)
		fadeInset(btn)
		S.Button(btn, {"Favorite"})
		if btn.Name then keepWhite(btn, btn.Name) end
	end
end


local function skinLoadedTargetPanel()
	local panel = RematchFrame.LoadedTargetPanel
	if not panel or panel.euiSkinned then return end
	panel.euiSkinned = true

	-- Its regions mix chrome (inset pieces, the marble back, the underline)
	-- with the target badge, so the chrome is faded by name and the plate
	-- goes underneath.
	fadeInset(panel)
	if panel.Underline then panel.Underline:SetAlpha(0) end
	plateUnder(panel)
	if panel.Name then S.White(panel.Name) end

	greyButton(panel.BigLoadSaveButton)
	greyButton(panel.MediumLoadButton)
	smallGreyButton(panel.SmallRandomButton)
	smallGreyButton(panel.SmallTeamsButton)
	smallGreyButton(panel.SmallSaveButton)

	-- Portrait: a round target portrait with a gold ring. The ring is an
	-- unnamed overlay region; the Border is a named one shown for saved
	-- targets. Both are chrome; the portrait itself stays.
	local portrait = panel.Portrait
	if portrait then
		for i = 1, select("#", portrait:GetRegions()) do
			local r = select(i, portrait:GetRegions())
			if r and r ~= portrait.Texture and r.IsObjectType and r:IsObjectType("Texture") then
				r:SetAlpha(0)
			end
		end
		if portrait.Texture then newEdges(portrait, portrait.Texture, 1) end
	end

	-- The enemy and ally team strips keep their borders: that art encodes
	-- how many pets are shown and the ally/enemy split, and reads as a
	-- pet-battle element rather than window chrome.
	local ally = panel.AllyTeam
	if ally then
		smallGreyButton(ally.PrevTeamButton)
		smallGreyButton(ally.NextTeamButton)
	end
end


--[[ LOADOUTS ------------------------------------------------------------------
	The three loadout slots, and their mini-mode counterparts. Each is an
	inset frame whose regions mix a lot of meaning (type decal, status bars,
	badges, notes button, the pet's rarity border) with chrome (inset pieces,
	the PetJournal plate, the status bar borders, the ability bar frame). So
	chrome is faded by name, the house plate goes underneath, and the pet's
	rarity border is mirrored onto an edge of ours.
------------------------------------------------------------------------------]]
local function abilityButton(btn)
	if not btn or btn.euiSkinned then return end
	btn.euiSkinned = true
	if btn.Icon then
		squareIcon(btn.Icon)
		newEdges(btn, btn.Icon, 1)
	end
end


local function abilityBar(bar)
	if not bar or bar.euiSkinned then return end
	bar.euiSkinned = true
	if bar.AbilitiesBorder then bar.AbilitiesBorder:SetAlpha(0) end
	for _, btn in ipairs(bar.Abilities or {}) do abilityButton(btn) end
end


-- The pet slot inside a loadout: icon plus a rarity Border whose vertex
-- colour is the pet's quality. Mirror it onto our edges, exactly as the
-- MountsJournal skin does for its pet rows.
local function petSlot(slot, iconKey, borderKey, hoverOn)
	if not slot or slot.euiSkinned then return end
	slot.euiSkinned = true
	local icon, border = slot[iconKey or "Icon"], slot[borderKey or "Border"]
	if not icon then return end
	squareIcon(icon)
	local state = newState(slot, icon, 1)
	if hoverOn and hoverOn.HookScript then bindHover(hoverOn, state) end
	bindQuality(state, border)
	levelBadge(slot, icon)
end


local function abilityFlyout(fly)
	if not fly or fly.euiSkinned then return end
	fly.euiSkinned = true
	if fly.Border then fly.Border:SetAlpha(0) end
	plateUnder(fly)
	for _, btn in ipairs(fly.Abilities or {}) do abilityButton(btn) end
	-- The "this one is loaded" overlays are meaning; recolour to the accent.
	for _, sel in ipairs(fly.AbilitySelecteds or {}) do
		if sel then
			local r, g, b = S.GetAccentColor()
			sel:SetVertexColor(r, g, b)
		end
	end
end


local function skinLoadout(loadout)
	if not loadout or loadout.euiSkinned then return end
	loadout.euiSkinned = true

	-- The notes badge highlights (itself, parent.Back) on hover, which would
	-- ghost the PetJournal plate back; FillSpecial only recolours Back and
	-- never shows it, so hiding is safe.
	hidePlate(loadout.Back)
	fadeInset(loadout)
	if loadout.Highlight then loadout.Highlight:SetAlpha(0) end
	for _, k in ipairs({"XpBarBorder", "HpBarBorder"}) do
		if loadout[k] then loadout[k]:SetAlpha(0) end
	end
	plateUnder(loadout)

	local hover = loadout:CreateTexture(nil, "HIGHLIGHT")
	hover:SetAllPoints()
	hover:SetColorTexture(1, 1, 1, .04)

	petSlot(loadout.Pet, "Icon", "Border", loadout.Pet)
	abilityBar(loadout.AbilityBar)
	if loadout.SpecialButton and loadout.SpecialButton.Icon then
		-- badge art, not an Interface/Icons bevel: leave its coords.
	end
	for _, k in ipairs({"PetName", "HealthText"}) do
		if loadout[k] then S.White(loadout[k]) end
	end
end


local function skinMiniLoadout(loadout)
	if not loadout or loadout.euiSkinned then return end
	loadout.euiSkinned = true

	hidePlate(loadout.Back)
	fadeInset(loadout)
	for _, k in ipairs({"TopStatusBarBorder", "BottomStatusBarBorder"}) do
		if loadout[k] then loadout[k]:SetAlpha(0) end
	end
	plateUnder(loadout)

	-- The mini slot IS the pet button (the fill mixin is on the slot itself),
	-- so its Icon and Border are direct regions.
	if loadout.Icon then
		squareIcon(loadout.Icon)
		local state = newState(loadout, loadout.Icon, 1)
		bindHover(loadout, state)
		bindQuality(state, loadout.Border)
		levelBadge(loadout, loadout.Icon)
	end
	abilityBar(loadout.AbilityBar)
	if loadout.HealthText then S.White(loadout.HealthText) end
end


local function skinLoadoutPanels()
	local panel = RematchFrame.LoadoutPanel
	if panel and not panel.euiSkinned then
		panel.euiSkinned = true
		for _, loadout in ipairs(panel.Loadouts or {}) do skinLoadout(loadout) end
		abilityFlyout(panel.AbilityFlyout)
	end
	local mini = RematchFrame.MiniLoadoutPanel
	if mini and not mini.euiSkinned then
		mini.euiSkinned = true
		for _, loadout in ipairs(mini.Loadouts or {}) do skinMiniLoadout(loadout) end
		abilityFlyout(mini.AbilityFlyout)
	end
end


local function skinPanels()
	stage("panels:pets", skinPetsPanel)
	stage("panels:teams", skinTeamsPanel)
	stage("panels:targets", skinTargetsPanel)
	stage("panels:queue", skinQueuePanel)
	stage("panels:options", skinOptionsPanel)
	stage("panels:loadedteam", skinLoadedTeamPanel)
	stage("panels:loadedtarget", skinLoadedTargetPanel)
	stage("panels:loadouts", skinLoadoutPanels)
end


--[[ DROPDOWNS -----------------------------------------------------------------
	RematchDropDownTemplate is a three-slice control from Rematch's controls
	sheet plus an arrow, and all four are highlighter targets, so all four
	are hidden. S.Dropdown is not used: its fade would take the Icon with
	it, and the Icon is the current choice's picture, hidden in XML and
	shown by Rematch when the selection has one. The combo-box variant's
	Text is an EditBox rather than a FontString and gets the edit-box skin.
------------------------------------------------------------------------------]]
local function dropdown(dd)
	if not dd or dd.euiSkinned then return end
	dd.euiSkinned = true
	for _, k in ipairs({"Left", "Right", "Middle", "DropDownButton"}) do hidePlate(dd[k]) end

	local r, g, b, a = S.GetPanelColor()
	local fill = dd:CreateTexture(nil, "BACKGROUND", nil, -6)
	fill:SetColorTexture(r, g, b, a)
	fill:SetAllPoints(dd)
	newEdges(dd, dd, 0)

	local hover = dd:CreateTexture(nil, "HIGHLIGHT")
	hover:SetAllPoints(dd)
	hover:SetColorTexture(1, 1, 1, .05)

	-- The house arrow, sized to the atlas's native 62x44 aspect.
	local arrow = dd:CreateTexture(nil, "OVERLAY")
	arrow:SetAtlas("Azerite-PointingArrow")
	arrow:SetSize(14, 10)
	arrow:SetPoint("RIGHT", dd, "RIGHT", -6, 0)
	arrow:SetVertexColor(1, 1, 1, .9)

	if dd.Text then
		if dd.Text.IsObjectType and dd.Text:IsObjectType("EditBox") then
			-- Combo box: the edit box carries the controls-sheet slices of
			-- its own template, and those go too. No border of its own,
			-- the dropdown's edge already frames it.
			fadeArray(dd.Text.Back)
			dd.Text.euiSkinned = true
		else
			S.White(dd.Text)
		end
	end
end


--[[ SCROLL BARS OF THE CLASSIC SHAPE -------------------------------------------
	Rematch's two multi-line editors (dialog and notes) use Blizzard's
	MinimalScrollFrameTemplate, whose bar is the classic slider: a thumb
	texture, a trackBG, and up/down buttons Rematch reaches by global name.
	S.ScrollBar recolours the thumb of that shape; the rest is done here.
	The arrows are EllesmereUI's left arrow rotated, the same way the
	facade draws the MinimalScrollBar's step buttons.
------------------------------------------------------------------------------]]
local function scrollArrow(btn, rotation)
	if not btn or btn.euiSkinned then return end
	btn.euiSkinned = true
	S.FadeRegions(btn)
	for _, g in ipairs({"GetNormalTexture", "GetPushedTexture",
		"GetDisabledTexture", "GetHighlightTexture"}) do
		local fn = btn[g]
		local t = fn and fn(btn)
		if t then t:SetAlpha(0) end
	end
	local tex = btn:CreateTexture(nil, "OVERLAY")
	tex:SetTexture(ns.HostMedia(ARROW_TEX.left))
	tex:SetSize(10, 10)
	tex:SetPoint("CENTER")
	tex:SetRotation(rotation)
	local function reflect() tex:SetAlpha(btn:IsEnabled() and .75 or .2) end
	btn:HookScript("OnEnter", function() if btn:IsEnabled() then tex:SetAlpha(1) end end)
	btn:HookScript("OnLeave", reflect)
	btn:HookScript("OnEnable", reflect)
	btn:HookScript("OnDisable", reflect)
	reflect()
end


local function classicScrollBar(sb)
	if not sb or sb.euiSkinned then return end
	sb.euiSkinned = true
	S.ScrollBar(sb)
	if sb.trackBG then sb.trackBG:SetAlpha(0) end
	local name = sb.GetName and sb:GetName()
	local up = sb.ScrollUpButton or sb.Back or (name and _G[name .. "ScrollUpButton"])
	local down = sb.ScrollDownButton or sb.Forward or (name and _G[name .. "ScrollDownButton"])
	scrollArrow(up, -math.pi / 2)
	scrollArrow(down, math.pi / 2)
end


--[[ LISTS ---------------------------------------------------------------------
	Every list in Rematch is one RematchAutoScrollBoxTemplate: a marble Back
	and eight inset pieces on the list frame, a WowScrollBoxList, a
	MinimalScrollBar, and two small scroll-to-end chevrons. Rows are pooled
	by Blizzard's view and recycled on every scroll, so they are skinned
	from a hook on the scroll box's Update, which is also what catches the
	full rebuild a compact-mode toggle causes. Each row is recognised by
	shape rather than template, since five templates share three shapes.
------------------------------------------------------------------------------]]

-- A label Rematch paints gold by default, and by rarity or state otherwise.
-- White only replaces the default; a coloured name keeps its colour.
local function whiteIfGold(fs)
	if not fs or not fs.GetTextColor then return end
	local r, g, b = fs:GetTextColor()
	local gr, gg, gb = gold()
	if r and math.abs(r - gr) < .02 and math.abs(g - gg) < .02 and math.abs(b - gb) < .02 then
		fs:SetTextColor(1, 1, 1)
	end
end


-- Pet rows (pets, queue, dialog pet buttons): Icon plus a rarity Border.
local function petRow(row)
	if row.euiSkinned then return end
	row.euiSkinned = true
	hidePlate(row.Back)
	local hover = row:CreateTexture(nil, "HIGHLIGHT")
	hover:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	hover:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
	hover:SetColorTexture(1, 1, 1, .05)
	if row.Icon then
		squareIcon(row.Icon)
		local state = newState(row, row.Icon, 1)
		bindHover(row, state)
		bindQuality(state, row.Border)
		levelBadge(row, row.Icon)
	end
end


-- Team and target rows: three pet textures under one team-border frame.
local function teamRow(row)
	if row.euiSkinned then return end
	row.euiSkinned = true
	hidePlate(row.Back)
	local hover = row:CreateTexture(nil, "HIGHLIGHT")
	hover:SetAllPoints(row)
	hover:SetColorTexture(1, 1, 1, .05)
	-- The team border is one texture framing all three slots, re-cropped and
	-- re-anchored on every fill to match how many pets there are. Faded,
	-- and each pet texture gets its own edge instead, which follows the
	-- texture wherever the fill puts it.
	if row.Border then row.Border:SetAlpha(0) end
	for _, pet in ipairs(row.Pets or {}) do
		if pet then
			squareIcon(pet)
			newEdges(row, pet, 1)
		end
	end
end


-- Group headers: a plate, the +/- glyph, an optional group icon with a
-- gold ring, and badges.
-- The +/- disc is a highlighter target (headers highlight Back and
-- ExpandIcon together), so it is hidden and redrawn as the house glyph.
-- Its state arrives through SetExpanded(isExpanded, isSearching), which
-- Rematch calls on every fill; while searching it shows a blank square,
-- and ours shows nothing.
local function headerRow(row)
	if row.euiSkinned then return end
	row.euiSkinned = true
	hidePlate(row.Back)
	hidePlate(row.ExpandIcon)
	if row.Border then row.Border:SetAlpha(0) end
	S.Button(row, {"Icon"})
	local glyph = newPlusMinus(row, 10)
	glyph:SetPoint("CENTER", row, "LEFT", 13, 0)
	local function paint(_, isExpanded, isSearching)
		glyph:SetShown(not isSearching)
		if not isSearching then glyph:SetExpanded(isExpanded) end
	end
	if type(row.SetExpanded) == "function" then hooksecurefunc(row, "SetExpanded", paint) end
end


-- Option rows carry no plate of their own; a dropdown parked in one is
-- the only thing to catch. Rematch re-parents its dropdown frames into the
-- row on every fill, so look each time.
local function optionRow(row)
	if row.euiSkinned then return end
	row.euiSkinned = true
	local hover = row:CreateTexture(nil, "HIGHLIGHT")
	hover:SetAllPoints(row)
	hover:SetColorTexture(1, 1, 1, .04)
end

local function optionRowRefresh(row)
	for i = 1, select("#", row:GetChildren()) do
		local child = select(i, row:GetChildren())
		if child and child.DropDown and child.DropDown.DropDownButton then
			dropdown(child.DropDown)
			if child.Label then S.White(child.Label) end
		elseif child and child.ScaleButton then
			greyButton(child.ScaleButton)
		end
	end
end


-- Group-picker rows (dialog): a plate, a circle-masked group icon and a
-- gold ring. The ring is not a quality border, so no state edge here, or
-- every row would wear a white square around a round icon.
local function groupRow(row)
	if row.euiSkinned then return end
	row.euiSkinned = true
	hidePlate(row.Back)
	if row.Border then row.Border:SetAlpha(0) end
	local hover = row:CreateTexture(nil, "HIGHLIGHT")
	hover:SetAllPoints(row)
	hover:SetColorTexture(1, 1, 1, .05)
end


local function skinRow(row)
	if not row or row:IsForbidden() then return end
	if row.ExpandIcon then
		headerRow(row)
		if row.Text then whiteIfGold(row.Text) end
	elseif row.IconMask and row.Icon then
		groupRow(row)
		if row.Text then whiteIfGold(row.Text) end
	elseif row.Pets and row.Border then
		teamRow(row)
		if row.Name then whiteIfGold(row.Name) end
	elseif row.Icon and row.Border then
		petRow(row)
		if row.PetName then whiteIfGold(row.PetName) end
	elseif row.Check then
		optionRow(row)
		optionRowRefresh(row)
	end
end


local function scrollRows(scrollBox)
	if not scrollBox or not scrollBox.ScrollTarget then return end
	eachChild(skinRow, scrollBox.ScrollTarget:GetChildren())
end


--[[ THE SCROLL COLUMN --------------------------------------------------------
	The template seats its bar 5px in from the list's right edge, against
	inset border art that used to end 18px in, and parks a scroll-to-end
	button above and below it (a 17x8 bar-and-arrow glyph that reads as a
	small rectangle at each end). With the art faded, the column the eye
	sees runs from the rows' right edge (the ScrollBox ends 22px in) to our
	1px border, and the bar sat right of its middle with a stub at each end.

	Two changes. The bar is re-anchored so its centre lands on the column's
	midline, the offset worked out from its own width so both edges stay on
	whole pixels. And the scroll-to-end buttons are hidden, the bar taking
	their room: it now runs the height of the rows, 4px in at top and
	bottom like the ScrollBox, with the bar's own arrows at its ends.
	Rematch only ever touches those buttons' alpha and their Highlight
	from its scroll callback, never shows them, so Hide() holds; the
	callback also dims the bar's own arrows at the ends, which still works.
------------------------------------------------------------------------------]]
local SCROLL_COLUMN = 22 + 1  -- ScrollBox inset plus the border
local SCROLL_INSET_Y = 4      -- the ScrollBox's own top and bottom inset

local function centreScrollColumn(list)
	local sb = list.ScrollBar
	if not sb then return end
	for _, key in ipairs({"ScrollToTopButton", "ScrollToBottomButton"}) do
		if list[key] then list[key]:Hide() end
	end
	local w = sb:GetWidth()
	if not w or w == 0 or (issecretvalue and issecretvalue(w)) then return end
	local right = -math.floor(SCROLL_COLUMN / 2 - w / 2)
	sb:ClearAllPoints()
	sb:SetPoint("TOPRIGHT", list, "TOPRIGHT", right, -SCROLL_INSET_Y)
	sb:SetPoint("BOTTOMRIGHT", list, "BOTTOMRIGHT", right, SCROLL_INSET_Y)
end


local function skinList(list)
	if not list or list.euiSkinned then return end
	list.euiSkinned = true

	fadeInset(list)
	S.Panel(list, {inset = true})
	if list.ScrollBar then
		S.ScrollBar(list.ScrollBar)
		centreScrollColumn(list)
	end

	local box = list.ScrollBox
	if box then
		hook(box, "Update", scrollRows)
		-- Belt and braces: a data-provider swap can reach the base Update
		-- directly rather than through the method the hook wraps, so also
		-- listen for the view handing out a frame. Rematch registers its
		-- own callbacks on this box the same way, so the path is live.
		local event = ScrollBoxListMixin and ScrollBoxListMixin.Event
			and ScrollBoxListMixin.Event.OnAcquiredFrame or "OnAcquiredFrame"
		pcall(box.RegisterCallback, box, event, function(_, frame) skinRow(frame) end, list)
		scrollRows(box)
	end
end


local function skinLists()
	for _, key in ipairs({"PetsPanel", "TeamsPanel", "TargetsPanel", "QueuePanel", "OptionsPanel"}) do
		local panel = RematchFrame[key]
		if panel and panel.List then stage("lists:" .. key, skinList, panel.List) end
	end
end


--[[ CARDS ---------------------------------------------------------------------
	The pet card and the notes card share a shape, and a trap. Both are
	RematchDefaultPanelTemplate windows whose Content child carries
	ignoreParentAlpha, because the card manager shows a card in "tooltip"
	mode by setting the WHOLE card to alpha 0 and letting only Content draw.
	So a shell painted on the card would vanish in that mode and the
	tooltip would be see-through. Content gets its own panel instead, and
	the card's title strip, the only part of the card outside Content, gets
	a plate of its own that may disappear with it.
------------------------------------------------------------------------------]]
local function cardChrome(card)
	if not card or card.euiSkinned then return end
	card.euiSkinned = true
	fadeInset(card)
	S.FadeRegions(card)
	if card.Title then S.Font(card.Title); S.White(card.Title) end

	local strip = CreateFrame("Frame", nil, card)
	strip:SetPoint("TOPLEFT", card, "TOPLEFT", 0, 0)
	strip:SetPoint("TOPRIGHT", card, "TOPRIGHT", 0, 0)
	strip:SetHeight(22)
	strip:EnableMouse(false)
	local level = card:GetFrameLevel()
	strip:SetFrameLevel(level > 0 and level - 1 or 0)
	S.Panel(strip, {noBorder = true})

	for _, k in ipairs({"CloseButton", "MinimizeButton", "PinButton", "FlipButton", "LockButton"}) do
		titleButton(card[k])
	end

	local content = card.Content
	if content then
		S.Panel(content)
		addBorder(content)
	end
end


-- Fade every texture region of a frame except the ones named (a key may
-- also be a parentArray, every texture in it is kept), plus any drawn from
-- one of the files listed. For frames whose meaningful art is unnamed (the
-- ability badges, the breed table's stat icons).
--
-- A texture set from XML reports its file as a NUMBER (a fileDataID), not
-- the path, so a path can only be matched by resolving it the same way: a
-- probe texture is pointed at the path and asked what ID it got. Where the
-- client offers GetTextureFilePath the string is compared as well.
local fileProbe
local function fileID(path)
	fileProbe = fileProbe or UIParent:CreateTexture()
	fileProbe:SetTexture(path)
	return fileProbe:GetTexture()
end

local function fadeExcept(frame, keepKeys, keepFiles)
	if not frame or not frame.GetRegions then return end
	local keep = {}
	for _, k in ipairs(keepKeys or {}) do
		local v = frame[k]
		if type(v) == "table" and not v.GetObjectType then
			for _, t in ipairs(v) do keep[t] = true end
		elseif v then
			keep[v] = true
		end
	end
	local keepIDs = {}
	for _, path in ipairs(keepFiles or {}) do
		local id = fileID(path)
		if id then keepIDs[id] = true end
	end
	for i = 1, select("#", frame:GetRegions()) do
		local r = select(i, frame:GetRegions())
		if r and r.IsObjectType and r:IsObjectType("Texture") and not keep[r] then
			local keepIt = false
			if keepFiles then
				local id = r.GetTexture and r:GetTexture()
				if id ~= nil and keepIDs[id] then keepIt = true end
				local path = r.GetTextureFilePath and r:GetTextureFilePath()
				if not keepIt and type(path) == "string" then
					for _, want in ipairs(keepFiles) do
						if path:lower():find(want:lower(), 1, true) then keepIt = true; break end
					end
				end
			end
			if not keepIt then r:SetAlpha(0) end
		end
	end
end


local function skinPetCard()
	local card = RematchPetCard
	if not card or card.euiSkinned then return end
	cardChrome(card)

	local content = card.Content
	if not content then return end

	local top = content.Top
	if top then
		if top.Back then top.Back:SetAlpha(0) end
		if top.Name then S.Font(top.Name) end
	end

	local front = content.Front
	if front then
		S.FadeRegions(front)
		local abilities = front.Abilities
		if abilities then
			fadeExcept(abilities, {})
			for _, btn in ipairs(abilities.Buttons or {}) do
				if btn and not btn.euiSkinned then
					btn.euiSkinned = true
					if btn.Border then btn.Border:SetAlpha(0) end
					if btn.Icon then
						squareIcon(btn.Icon)
						newEdges(btn, btn.Icon, 1)
					end
				end
			end
		end
		local stats = front.Stats
		if stats then
			-- The rock tile and the corner shadow are unnamed; the three art
			-- backgrounds, the pennant and the mask are named and stay.
			fadeExcept(stats, {"ExpansionBackground", "PetBackground", "TypeBackground",
				"LevelPennant", "FadeMask"})
			for _, k in ipairs({"HpBar", "XpBar"}) do
				local bar = stats[k]
				if bar and bar.Border then bar.Border:SetAlpha(0) end
			end
			local btable = stats.BreedTable
			if btable then
				clearBackdrop(btable)
				if btable.Shadow then btable.Shadow:SetAlpha(0) end
				plateUnder(btable)
				addBorder(btable)
			end
		end
	end

	local back = content.Back
	if back then
		S.FadeRegions(back)
		local racial = back.Racial
		if racial then
			fadeExcept(racial, {"StrongBadge", "WeakBadge", "StrongType", "WeakType", "TypeIcon"})
		end
		if back.Source then fadeExcept(back.Source, {}) end
		local lore = back.Lore
		if lore then
			-- The parchment. Its lore font is black because it sits on
			-- parchment; on the house panel it has to be light, and the font
			-- object (which carries the colour) is re-applied on every
			-- update, so recolour from a hook on that.
			fadeExcept(lore, {})
			local function light()
				if lore.Text then lore.Text:SetTextColor(.9, .9, .9) end
			end
			light()
			if type(lore.Update) == "function" then hooksecurefunc(lore, "Update", light) end
		end
	end
end


local function skinNotesCard()
	local card = RematchNotesCard
	if not card or card.euiSkinned then return end
	cardChrome(card)

	local content = card.Content
	if not content then return end
	local top = content.Top
	if top then
		fadeExcept(top, {"LeftIcon", "RightIcon"})
		if top.Name then S.Font(top.Name) end
	end
	local bottom = content.Bottom
	if bottom then
		fadeExcept(bottom, {})
		for _, k in ipairs({"DeleteButton", "UndoButton", "SaveButton"}) do
			panelButton(bottom[k])
		end
	end
	local scroll = content.ScrollFrame
	if scroll and scroll.ScrollBar then classicScrollBar(scroll.ScrollBar) end
end


local function skinCards()
	stage("cards:pet", skinPetCard)
	stage("cards:notes", skinNotesCard)
end


--[[ DIALOGS -------------------------------------------------------------------
	One physical dialog. Every "dialog" Rematch shows is a layout of
	RematchDialog.Canvas's children, laid out afresh on each show, so the
	children are skinned once here and their positions are left to
	Rematch. Widgets created on demand (colour swatches, top-team rows,
	list items, bar-chart bars) are text and icons on plain frames and need
	nothing.
------------------------------------------------------------------------------]]
local function skinDialog()
	local dlg = RematchDialog
	if not dlg or dlg.euiSkinned then return end
	dlg.euiSkinned = true

	fadeInset(dlg)
	S.Shell(dlg)
	addBorder(dlg)
	if dlg.Title then S.Font(dlg.Title); S.White(dlg.Title) end
	titleButton(dlg.CloseButton)
	titleButton(dlg.MinimizeButton)
	panelButton(dlg.CancelButton)
	panelButton(dlg.AcceptButton)
	panelButton(dlg.OtherButton)
	if dlg.Prompt then
		S.FadeRegions(dlg.Prompt)
		if dlg.Prompt.Text then S.White(dlg.Prompt.Text) end
	end

	local c = dlg.Canvas
	if not c then return end

	if c.EditBox then
		editBox(c.EditBox.EditBox)
		if c.EditBox.Label then S.White(c.EditBox.Label) end
	end

	local ml = c.MultiLineEditBox
	if ml then
		fadeInset(ml)
		S.Panel(ml, {inset = true})
		if ml.ScrollFrame and ml.ScrollFrame.ScrollBar then
			classicScrollBar(ml.ScrollFrame.ScrollBar)
		end
	end

	if c.CheckButton then checkButton(c.CheckButton.Check) end
	if c.IncludeCheckButtons then
		checkButton(c.IncludeCheckButtons.IncludePreferences)
		checkButton(c.IncludeCheckButtons.IncludeNotes)
	end
	if c.ConflictRadios then
		checkButton(c.ConflictRadios.CreateCopyRadio)
		checkButton(c.ConflictRadios.OverwriteRadio)
	end

	if c.DropDown then
		dropdown(c.DropDown.DropDown)
		if c.DropDown.Label then S.White(c.DropDown.Label) end
	end
	if c.BarChartDropDown then dropdown(c.BarChartDropDown.DropDown) end
	if c.ComboBox then
		dropdown(c.ComboBox.ComboBox)
		if c.ComboBox.Label then S.White(c.ComboBox.Label) end
	end

	local tabs = c.LayoutTabs
	if tabs then
		for _, k in ipairs({"LeftBorder", "RightBorder"}) do
			if tabs[k] then tabs[k]:SetAlpha(0) end
		end
		for _, tab in ipairs(tabs.Tabs or {}) do stretchTab(tab) end
	end

	local prefs = c.Preferences
	if prefs then
		for _, k in ipairs({"MaxLevel", "MinLevel", "MaxHealth", "MinHealth"}) do
			editBox(prefs[k])
			if prefs[k] and prefs[k].Label then S.White(prefs[k].Label) end
		end
		checkButton(prefs.AllowMM)
		if prefs.ExpectedDamage and prefs.ExpectedDamage.Borders then
			prefs.ExpectedDamage.Borders:SetAlpha(0)
		end
	end
	local ro = c.PreferencesReadOnly
	if ro and ro.ExpectedDamage and ro.ExpectedDamage.Borders then
		ro.ExpectedDamage.Borders:SetAlpha(0)
	end

	if c.Line then S.FadeRegions(c.Line) end

	local picker = c.IconPicker
	if picker then
		-- The frame around the chosen icon is an unnamed overlay region.
		fadeExcept(picker, {"Icon"})
		if picker.Icon then newEdges(picker, picker.Icon, 1) end
		editBox(picker.SearchBox)
		skinList(picker.List)
	end

	local tp = c.TeamPicker
	if tp then
		if tp.Lister then
			local top = tp.Lister.Top
			if top then
				headerBar(top)
				for _, k in ipairs({"AddButton", "DeleteButton", "UpButton", "DownButton"}) do
					greyButton(top[k])
				end
			end
			skinList(tp.Lister.List)
		end
		if tp.Picker then
			local top = tp.Picker.Top
			if top then
				headerBar(top)
				allButton(top.AllButton)
				greyButton(top.CancelButton)
				editBox(top.SearchBox)
			end
			skinList(tp.Picker.List)
		end
	end

	local gp = c.GroupPicker
	if gp then
		if gp.Top then
			headerBar(gp.Top)
			greyButton(gp.Top.CancelButton)
			if gp.Top.Label then S.White(gp.Top.Label) end
		end
		skinList(gp.List)
	end

	-- The group selector: a header-shaped button with unnamed plate
	-- slices and ADD-blend highlight copies of them.
	local gs = c.GroupSelect
	if gs and gs.Button and not gs.Button.euiSkinned then
		local btn = gs.Button
		btn.euiSkinned = true
		fadeExcept(btn, {"Icon", "Badges"})
		fadeArray(btn.Highlights)
		if btn.Border then btn.Border:SetAlpha(0) end
		plateUnder(btn)
		local hover = btn:CreateTexture(nil, "HIGHLIGHT")
		hover:SetAllPoints(btn)
		hover:SetColorTexture(1, 1, 1, .06)
		if btn.Name then keepWhite(btn, btn.Name) end
		if gs.Label then S.White(gs.Label) end
	end

	local wr = c.WinRecord
	if wr then
		for _, k in ipairs({"Wins", "Losses", "Draws"}) do
			editBox(wr[k])
			if wr[k] and wr[k].Label then S.White(wr[k].Label) end
		end
		for _, k in ipairs({"WinsMinus", "WinsPlus", "LossesMinus", "LossesPlus",
			"DrawsMinus", "DrawsPlus"}) do
			smallGreyButton(wr[k])
		end
	end

	local slider = c.Slider and c.Slider.Slider
	if slider then
		-- MinimalSliderWithSteppersTemplate: the slider itself plus two
		-- stepper buttons.
		skinSlider(slider.Slider or slider)
		if slider.Back then S.PageButton(slider.Back, "<") end
		if slider.Forward then S.PageButton(slider.Forward, ">") end
	end

	local ps = c.PetSummary
	if ps then
		for _, k in ipairs({"LeftCap", "RightCap", "MidBorder"}) do
			if ps[k] then ps[k]:SetAlpha(0) end
		end
	end

	local herder = c.PetHerderPicker
	if herder and herder.Border then
		herder.Border:SetAlpha(0)
		plateUnder(herder, {inset = true})
	end

	-- Top-team rows are created as the summary fills; catch them there.
	local tt = c.TopTeams
	if tt and type(tt.Fill) == "function" then
		local function rows()
			for _, row in ipairs(tt.Buttons or {}) do
				if row and not row.euiSkinned then
					row.euiSkinned = true
					hidePlate(row.Back)
					if row.Border then row.Border:SetAlpha(0) end
					for _, pet in ipairs(row.Pets or {}) do
						if pet then squareIcon(pet); newEdges(row, pet, 1) end
					end
					local hover = row:CreateTexture(nil, "HIGHLIGHT")
					hover:SetAllPoints(row)
					hover:SetColorTexture(1, 1, 1, .05)
				end
			end
		end
		hooksecurefunc(tt, "Fill", rows)
		rows()
	end

	-- Pet and team previews inside the dialog reuse the list row templates.
	if c.Pet and c.Pet.ListButtonPet then skinRow(c.Pet.ListButtonPet) end
	if c.Team and c.Team.ListButtonTeam then skinRow(c.Team.ListButtonTeam) end
	if c.MultiTeam then
		if c.MultiTeam.ListButtonTeam then skinRow(c.MultiTeam.ListButtonTeam) end
		smallGreyButton(c.MultiTeam.PrevTeamButton)
		smallGreyButton(c.MultiTeam.NextTeamButton)
	end
	for _, key in ipairs({"TeamWithAbilities", "OtherTeamWithAbilities"}) do
		local twa = c[key]
		for _, pwa in ipairs(twa and twa.Pets or {}) do
			if pwa and pwa.Pet then petSlot(pwa.Pet, "Icon", "Border", pwa.Pet) end
			if pwa and pwa.AbilityBar then abilityBar(pwa.AbilityBar) end
		end
	end
	if c.TeamWarning then
		for _, pet in ipairs(c.TeamWarning.Pets or {}) do petSlot(pet, "Icon", "Border", pet) end
	end
end


local function skinDialogs()
	stage("dialogs:main", skinDialog)
end


--[[ MENUS ---------------------------------------------------------------------
	Menu frames are created on demand by a function private to Rematch,
	parented to UIParent and unnamed, so there is nothing to address at
	login. What they do have is a template that inherits BackdropTemplate,
	whose OnLoad runs the OnBackdropLoaded method copied onto the frame
	from BackdropTemplateMixin at creation. Hooking that mixin entry before
	any menu exists means every menu created afterwards arrives through the
	hook, and the isRematchMenu key it carries picks ours out of every
	other backdrop frame in the UI. The items themselves need nothing:
	their highlight is a plain white plate and their check and arrow art
	is meaning.
------------------------------------------------------------------------------]]
local function skinMenuFrame(menu)
	if not menu or menu.euiSkinned then return end
	menu.euiSkinned = true
	clearBackdrop(menu)
	if menu.Shadow then menu.Shadow:SetAlpha(0) end
	S.Panel(menu)
	addBorder(menu)
	if menu.Title then S.FadeRegions(menu.Title) end
end


local function skinMenus()
	if type(BackdropTemplateMixin) ~= "table"
		or type(BackdropTemplateMixin.OnBackdropLoaded) ~= "function" then return end
	hooksecurefunc(BackdropTemplateMixin, "OnBackdropLoaded", function(frame)
		if frame and frame.isRematchMenu then skinMenuFrame(frame) end
	end)
	-- Menus already open at dispatch (none in practice, but cheap to cover).
	for i = 1, select("#", UIParent:GetChildren()) do
		local child = select(i, UIParent:GetChildren())
		if child and child.isRematchMenu then skinMenuFrame(child) end
	end
end


--[[ TOOLTIPS ------------------------------------------------------------------
	Rematch's tooltips are hand-rolled frames on its shadow backdrop, not
	GameTooltips. The ability tooltip is a small card: three plates, two
	round icons with gold rings, and a rock tile behind the text.
------------------------------------------------------------------------------]]
local function skinTooltips()
	local tip = RematchTooltip
	if tip and not tip.euiSkinned then
		tip.euiSkinned = true
		clearBackdrop(tip)
		if tip.Shadow then tip.Shadow:SetAlpha(0) end
		S.Panel(tip)
		addBorder(tip)
	end
	local gt = RematchGameTooltip
	if gt and not gt.euiSkinned then
		gt.euiSkinned = true
		clearBackdrop(gt)
		if gt.Shadow then gt.Shadow:SetAlpha(0) end
	end

	local at = RematchAbilityTooltip
	if at and not at.euiSkinned then
		at.euiSkinned = true
		clearBackdrop(at)
		S.Panel(at)
		addBorder(at)
		if at.Top then
			fadeExcept(at.Top, {"AbilityIcon", "TypeIcon"})
			if at.Top.Name then S.Font(at.Top.Name) end
		end
		if at.Hints then
			fadeExcept(at.Hints, {"StrongType", "WeakType"}, {
				"Interface\\PetBattles\\BattleBar-AbilityBadge-Strong",
				"Interface\\PetBattles\\BattleBar-AbilityBadge-Weak",
			})
		end
		if at.Details then
			fadeExcept(at.Details, {"IconBackground", "TypeBackground", "FadeMask"})
		end
	end
end


--[[ THE JOURNAL'S OWN "REMATCH" CHECK ------------------------------------------
	When the user has switched back to Blizzard's Pet Journal, Rematch
	leaves a "Rematch" check button beside its Summon button to switch
	back. It is created when Blizzard_Collections loads, which may be
	before or after us, and it is unnamed and unkeyed: a RematchCheckButton
	child of PetJournal carrying Rematch's tooltip fields.
------------------------------------------------------------------------------]]
local function skinJournalCheck()
	if not PetJournal then return false end
	local found = false
	for i = 1, select("#", PetJournal:GetChildren()) do
		local child = select(i, PetJournal:GetChildren())
		if child and child.Text and child.tooltipTitle and child.GetChecked
			and not child.euiSkinned then
			checkButton(child)
			found = true
		end
	end
	return found
end


local function skinJournalSeat()
	if skinJournalCheck() then return end
	local waiter = CreateFrame("Frame")
	waiter:RegisterEvent("ADDON_LOADED")
	waiter:SetScript("OnEvent", function(self, _, name)
		if name == "Blizzard_Collections" then
			-- Rematch creates the button from its own ADDON_LOADED handler,
			-- which runs before ours only if it registered first. Defer a
			-- frame so either order works.
			C_Timer.After(0, function() stage("journal:check", skinJournalCheck) end)
			self:UnregisterAllEvents()
		end
	end)
end


--[[ COLLECTIONS BACKDROP ------------------------------------------------------
	In journal mode Rematch hides PetJournal and parents its own window into
	CollectionsJournal, anchored to its bottom-left corner and sized to the
	same seat, with a frame level 600 above it. It never hides
	CollectionsJournal itself, so the Collections shell, which EllesmereUI
	paints, sits directly behind our window. With an opaque backdrop that is
	invisible; with the Dark Mode fill it stacks, two 90% plates reading as
	one near-black one, and the user's transparency is gone.

	The MountsJournal skin met exactly this and its answer is carried over:
	while our window is up, fade whatever sits behind it, and hand it all
	back when it closes. Matching is by GEOMETRY, not texture identity,
	because every attempt to recognise the engine's chrome by what it was
	made of got it wrong (a colour plate reports a fileID of -666, a border
	strip reports WHITE8X8's positive one). Anything sizeable inside our
	window's rect, on a frame behind us, is chrome we are covering. That rule
	also protects Collections' tab row automatically: it hangs below the
	window and does not overlap it.

	Two things this has to survive:

	1. The window engine re-raises its own backdrop alpha whenever it
	   restyles, and re-runs its Collections pack on every Collections show.
	   A one-shot fade loses that race, so suppression re-asserts on regions
	   it already owns and is replayed after the engine has had its turn.
	2. Blizzard's own PetJournal is hidden by Rematch, so unlike the
	   MountsJournal case there is no second Blizzard frame behind us; only
	   Collections' own regions and the engine's child-frame border.

	Alpha only, regions only, fully reversible, nothing Hide()n, reparented or
	rescripted. Regions only is load-bearing: CollectionsJournal is our parent
	in journal mode, and dropping the alpha of the FRAME would take our own
	window with it.
------------------------------------------------------------------------------]]
local collectionsArt = setmetatable({}, {__mode = "k"})

-- Fills in the forward declaration up by the diagnostic.
function isSuppressed(region) return collectionsArt[region] ~= nil end

local SHELL_ATLAS = "AdventureMap_TopBorder"
local SHELL_FILE = "modern_blizz"
local PLATE_MIN = 120


local function isShellArt(region)
	if not (region.IsObjectType and region:IsObjectType("Texture")) then return false end
	if region.GetAtlas and region:GetAtlas() == SHELL_ATLAS then return true end
	local file = region.GetTexture and region:GetTexture()
	return type(file) == "string" and file:find(SHELL_FILE, 1, true) ~= nil
end


local function overlaps(ax, ay, aw, ah, bx, by, bw, bh)
	return ax < bx + bw and bx < ax + aw and ay < by + bh and by < ay + ah
end


-- win = {x, y, w, h} of our own window, in screen coordinates.
local function isChrome(region, win)
	if not (region.IsObjectType and region:IsObjectType("Texture")) then return false end
	if not win then return false end
	local x, y, w, h = rectOf(region)
	if not (x and w and h) then return false end
	-- Plates and hairline border strips alike: sizeable in at least one axis.
	if w < PLATE_MIN and h < PLATE_MIN then return false end
	return overlaps(x, y, w, h, win.x, win.y, win.w, win.h)
end


local function stash(region)
	if not (region and region.GetAlpha and region.SetAlpha) then return end
	if collectionsArt[region] then
		-- Already ours. Re-assert rather than return: the engine puts its own
		-- backdrop alpha back whenever it restyles.
		region:SetAlpha(0)
		return
	end
	local a = region:GetAlpha()
	if a and a > 0 then
		collectionsArt[region] = a
		region:SetAlpha(0)
	end
end


local function stashOwnArt(frame)
	if not (frame and frame.GetRegions) then return end
	for i = 1, select("#", frame:GetRegions()) do
		stash((select(i, frame:GetRegions())))
	end
	if frame.NineSlice then stash(frame.NineSlice) end
	if frame.PortraitContainer then stash(frame.PortraitContainer) end
end


-- Chrome parked in child frames: the engine's border overlay and its plates.
local function stashShellArt(frame, depth, skip, win)
	if depth > 4 or not frame.GetChildren then return end
	for i = 1, select("#", frame:GetChildren()) do
		local child = select(i, frame:GetChildren())
		if child and child.GetRegions and not child:IsForbidden() and not skip[child] then
			for j = 1, select("#", child:GetRegions()) do
				local r = select(j, child:GetRegions())
				if r and (isShellArt(r) or isChrome(r, win)) then stash(r) end
			end
			stashShellArt(child, depth + 1, skip, win)
		end
	end
end


function fadeCollections(fade)
	local collect = CollectionsJournal

	if not fade then
		for region, alpha in pairs(collectionsArt) do
			if region.SetAlpha then region:SetAlpha(alpha) end
		end
		wipe(collectionsArt)
		return
	end

	if not (collect and journalActive()) then return end

	-- Our own window is ours to draw, and with the Blizzard-art backdrop
	-- selected our shell is made of the same textures the sweep matches on.
	-- Rematch's cards, menus and dialogs are parented to UIParent, not to us,
	-- so they are never in this walk.
	local skip = {[RematchFrame] = true}

	local wx, wy, ww, wh = rectOf(RematchFrame)
	local win = wx and {x = wx, y = wy, w = ww, h = wh} or nil

	stashOwnArt(collect)
	if collect.CloseButton then stash(collect.CloseButton) end
	if CollectionsJournalTitleText then stash(CollectionsJournalTitleText) end
	stashShellArt(collect, 1, skip, win)
end


-- Suppress, then suppress again after the engine has had its turn. Its
-- Collections re-skin is debounced onto a later frame, so whichever of us runs
-- first, this makes us last.
function suppressBehind()
	fadeCollections(true)
	if not C_Timer then return end
	for _, delay in ipairs({0, .1, .5}) do
		C_Timer.After(delay, function()
			if RematchFrame:IsShown() and journalActive() then fadeCollections(true) end
		end)
	end
end


--[[ SETTINGS PANEL ------------------------------------------------------------
	Window backdrop and opacity, then border style and size, the last two
	offering EllesmereUI's own texture list so users see the same names,
	including Glow and Shadow, that they get in the rest of the suite.
	Registered through Blizzard's Settings API. Wrapped in a stage: if the
	Settings API signature ever shifts, the panel quietly does not appear
	rather than throwing on load, and the saved choices still apply.
------------------------------------------------------------------------------]]
local function buildOptions()
	if not (Settings and Settings.RegisterVerticalLayoutCategory
		and Settings.RegisterAddOnSetting and Settings.CreateDropdown) then return end

	local category = Settings.RegisterVerticalLayoutCategory("Rematch EllesmereUI Skin")

	if ns.CanStyleShell and ns.CanStyleShell() then
		local bgSetting = Settings.RegisterAddOnSetting(category,
			"RMEUISkin_Backdrop", "backdrop", db, Settings.VarType.String,
			"Window backdrop", DEFAULTS.backdrop)
		bgSetting:SetValueChangedCallback(applyShell)

		Settings.CreateDropdown(category, bgSetting, function()
			local container = Settings.CreateControlTextContainer()
			container:Add("fill", "EllesmereUI Dark Mode",
				"The colour and transparency your unit frames, bars and panels use.")
			container:Add("blizz", "Blizzard window art",
				"EllesmereUI's own window texture, matching Mounts and Toy Box. Always opaque.")
			return container:GetData()
		end, "What the Rematch window is painted with.")

		local makeCheckbox = Settings.CreateCheckbox or Settings.CreateCheckBox
		if makeCheckbox then
			local followSetting = Settings.RegisterAddOnSetting(category,
				"RMEUISkin_FollowOpacity", "followOpacity", db,
				Settings.VarType.Boolean, "Follow EllesmereUI opacity",
				DEFAULTS.followOpacity)
			followSetting:SetValueChangedCallback(applyShell)
			makeCheckbox(category, followSetting,
				"Use your Dark Mode transparency. Turn off to set it yourself below.")
		end

		local edgeSetting = Settings.RegisterAddOnSetting(category,
			"RMEUISkin_WindowBorder", "windowBorder", db, Settings.VarType.String,
			"Window edge", DEFAULTS.windowBorder)
		edgeSetting:SetValueChangedCallback(applyShell)

		Settings.CreateDropdown(category, edgeSetting, function()
			local container = Settings.CreateControlTextContainer()
			container:Add("line", "Thin dark line",
				"A crisp 1px edge, as dark as the other windows read, with no inner shading.")
			container:Add("art", "EllesmereUI window frame",
				"The exact frame EllesmereUI draws on its own windows. Carries a soft inner falloff.")
			container:Add("none", "None", "No edge of our own.")
			return container:GetData()
		end, "The outermost edge of the Rematch window.")

		local opacitySetting = Settings.RegisterAddOnSetting(category,
			"RMEUISkin_Opacity", "opacity", db, Settings.VarType.Number,
			"Opacity", DEFAULTS.opacity)
		opacitySetting:SetValueChangedCallback(applyShell)

		if Settings.CreateSlider and Settings.CreateSliderOptions then
			local options = Settings.CreateSliderOptions(0, 100, 1)
			if MinimalSliderWithSteppersMixin then
				options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
			end
			Settings.CreateSlider(category, opacitySetting, options,
				"Ignored while Follow EllesmereUI opacity is on. Has no effect on Blizzard window art, which cannot be made transparent.")
		end
	end

	local styleSetting = Settings.RegisterAddOnSetting(category,
		"RMEUISkin_BorderStyle", "borderStyle", db, Settings.VarType.String,
		"Border style", DEFAULTS.borderStyle)
	styleSetting:SetValueChangedCallback(refreshBorders)

	Settings.CreateDropdown(category, styleSetting, function()
		local container = Settings.CreateControlTextContainer()
		container:Add("auto", "Follow EllesmereUI",
			"Use the window border set in EllesmereUI's own options, including its size.")
		container:Add("none", "None")
		local EUI = ns.Host()
		if EUI and EUI.GetBorderTextureList then
			for _, entry in ipairs(EUI.GetBorderTextureList()) do
				container:Add(entry.key, entry.name)
			end
		end
		return container:GetData()
	end, "Border drawn around the Rematch windows. Uses EllesmereUI's own border list.")

	local sizeSetting = Settings.RegisterAddOnSetting(category,
		"RMEUISkin_BorderSize", "borderSize", db, Settings.VarType.Number,
		"Border size", DEFAULTS.borderSize)
	sizeSetting:SetValueChangedCallback(refreshBorders)

	if Settings.CreateSlider and Settings.CreateSliderOptions then
		local options = Settings.CreateSliderOptions(1, 4, 1)
		if MinimalSliderWithSteppersMixin then
			options:SetLabelFormatter(MinimalSliderWithSteppersMixin.Label.Right)
		end
		Settings.CreateSlider(category, sizeSetting, options,
			"Border thickness, 1 (thin) to 4 (heavy).")
	end

	Settings.RegisterAddOnCategory(category)
end


--[[ REGISTRATION --------------------------------------------------------------
	One callback, fired once at PLAYER_LOGIN. Every step is staged so that a
	failure in any one of them costs that step alone.
------------------------------------------------------------------------------]]
ns.RegisterSkin(ADDON_NAME, function(skin)
	-- Our own view of the facade, not the facade itself. On the api backend
	-- that table is EllesmereUI's own, shared with every other addon it
	-- skins, and writing to it would change their primitives too.
	S = setmetatable({
		-- Many of Rematch's panels are BackdropTemplate frames that draw
		-- their fill and edge through SetBackdrop rather than as texture
		-- regions. No region fade can reach that, so clear it wherever a
		-- panel is painted rather than remembering it at every call site.
		Panel = function(frame, opts)
			clearBackdrop(frame)
			return skin.Panel(frame, opts)
		end,

		-- The engine's FadeRegions walks frame:GetRegions() with no type
		-- check, so a bare Texture reaching it is a hard error; the compat
		-- shim silently does nothing. Absorb the difference once: a Texture
		-- goes to alpha 0, which is what fading its regions would have done.
		FadeRegions = function(frame, keep)
			if not frame then return end
			if not frame.GetRegions then
				if frame.IsObjectType and frame:IsObjectType("Texture") then
					frame:SetAlpha(0)
				end
				return
			end
			return skin.FadeRegions(frame, keep)
		end,
	}, {__index = skin})

	stage("db", resolveDB)
	-- Before anything builds a window, so the shell is painted right the first
	-- time rather than repainted after the fact.
	stage("shell", applyShell)
	stage("looksHook", function() S.OnLooksChanged(looksChanged) end)

	-- Rematch registers its PLAYER_LOGIN handlers from its files, and the
	-- window, tabs and panels are all built by then. EllesmereUI dispatches
	-- us at PLAYER_LOGIN too, after Rematch's own handlers (it loaded first,
	-- as our dependency), so everything static exists. Anything built later
	-- (dialogs, menus, pooled rows) is caught from its own hooks.
	stage("window", skinWindow)
	stage("chrome", skinChrome)
	stage("panels", skinPanels)
	stage("lists", skinLists)
	stage("cards", skinCards)
	stage("dialogs", skinDialogs)
	stage("menus", skinMenus)
	stage("tooltips", skinTooltips)
	stage("journal", skinJournalSeat)

	stage("options", buildOptions)
end)
end)
