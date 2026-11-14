-- Settings window: /qt or /qt config, or the minimap button.
--
-- Look (accepted mock-up "Option A: Classic Options", after WoW Forever's own Options window, with Option B's on/off
-- switches and colour swatches):
--   title bar with the addon name and Forever's red close button; a category list on the left (gold group headers
--   Quest Tracker / RXP Tracker / Settings window, gold page names, the open page highlighted); a search box above
--   a dark page panel with the page title, a red "Defaults" button, and label-left / control-right rows: on/off
--   switches, < value > pickers that also open a list, sliders with a diamond thumb and step arrows, colour swatches
--   with a custom-colour button; a bottom bar with the version and a red "Close" button.
-- Artwork is drawn with plain textures (colours from the mock-up); buttons, the close button, the search box and the
-- scroll frame are Forever's native templates, each with a plain fallback if a template is missing.
local ADDON, root = ...; local ns = root.tracker
if ns.disabled then return end
local api = ns.api

local frame, panel, scroll, content, scrollbar, searchBox, pageTitle, defaultsButton, footer
local items = {}
local loading = false
local activePage = "questlist"
local declaringPage = "questlist"
local MIN_W, MIN_H, MAX_W, MAX_H = 720, 480, 1400, 1100
local DEFAULT_W, DEFAULT_H = 880, 660
local SIDEBAR_W = 196

-- colours from the accepted mock-up
local C = {
	window = { 0.086, 0.071, 0.055 }, edge = { 0.29, 0.243, 0.184 },
	titleTop = { 0.176, 0.153, 0.122 }, titleBottom = { 0.102, 0.082, 0.067 }, titleLine = { 0.247, 0.204, 0.157 },
	headTop = { 0.2, 0.169, 0.129 }, headBottom = { 0.106, 0.086, 0.071 }, headEdge = { 0.31, 0.259, 0.196 },
	headText = { 0.949, 0.902, 0.784 },
	panel = { 0.059, 0.047, 0.039 }, panelEdge = { 0.231, 0.192, 0.157 },
	label = { 0.69, 0.663, 0.612 }, subLabel = { 0.6, 0.573, 0.522 }, pageTitle = { 0.941, 0.902, 0.824 },
	value = { 0.847, 0.812, 0.749 },
	ctrlTop = { 0.173, 0.149, 0.125 }, ctrlBottom = { 0.082, 0.067, 0.055 }, ctrlEdge = { 0.353, 0.298, 0.227 },
	arrow = { 0.784, 0.69, 0.478 },
	track = { 0.082, 0.067, 0.051 }, trackEdge = { 0.302, 0.255, 0.2 }, thumb = { 0.71, 0.58, 0.39 },
	on = { 0.788, 0.635, 0.29 }, onKnob = { 0.102, 0.071, 0.035 }, off = { 0.22, 0.188, 0.153 },
	offKnob = { 0.56, 0.525, 0.463 }, ring = { 0.953, 0.875, 0.659 },
	list = { 0.02, 0.016, 0.012 }, listText = { 0.941, 0.902, 0.824 },
}
-- preset colours offered next to the custom-colour button
local SWATCHES = {
	{ "Green", { 0.2, 0.85, 0.55 } }, { "Gold", { 1, 0.82, 0 } }, { "Blue", { 0.31, 0.64, 1 } },
	{ "Purple", { 0.69, 0.53, 1 } }, { "White", { 1, 1, 1 } },
}
local CIRCLE = "Interface\\CHARACTERFRAME\\TempPortraitAlphaMask"
local ARROW = "Interface\\ChatFrame\\ChatFrameExpandArrow" -- points right

---------------------------------------------------------------------------------------------------------------------
-- Drawing helpers
---------------------------------------------------------------------------------------------------------------------
local function create(kind, name, parent, template)
	if template then
		local ok, f = pcall(CreateFrame, kind, name, parent, template)
		if ok and f then return f, true end
	end
	return CreateFrame(kind, name, parent), false
end

local function solid(parent, layer, c, a, sub)
	local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub)
	t:SetColorTexture(c[1], c[2], c[3], a or 1)
	return t
end

-- vertical gradient (top colour, bottom colour); a flat middle colour where gradients are missing
local function gradient(t, top, bottom, alphaTop, alphaBottom)
	t:SetColorTexture(1, 1, 1, 1)
	local ok = false
	if t.SetGradient and CreateColor then
		ok = pcall(t.SetGradient, t, "VERTICAL",
			CreateColor(bottom[1], bottom[2], bottom[3], alphaBottom or 1), CreateColor(top[1], top[2], top[3], alphaTop or 1))
	end
	if not ok then
		t:SetColorTexture((top[1] + bottom[1]) / 2, (top[2] + bottom[2]) / 2, (top[3] + bottom[3]) / 2, alphaTop or 1)
	end
end
local function hGradient(t, c, alphaLeft, alphaRight)
	t:SetColorTexture(1, 1, 1, 1)
	local ok = false
	if t.SetGradient and CreateColor then
		ok = pcall(t.SetGradient, t, "HORIZONTAL", CreateColor(c[1], c[2], c[3], alphaLeft), CreateColor(c[1], c[2], c[3], alphaRight))
	end
	if not ok then t:SetColorTexture(c[1], c[2], c[3], (alphaLeft + alphaRight) / 2) end
end

local function border(parent, c, size, layer, a)
	local list = {}
	local function edge(p1, p2, w, h)
		local t = parent:CreateTexture(nil, layer or "BORDER")
		t:SetColorTexture(c[1], c[2], c[3], a or 1)
		t:SetPoint(p1)
		t:SetPoint(p2)
		if w then t:SetWidth(w) end
		if h then t:SetHeight(h) end
		list[#list + 1] = t
	end
	size = size or 1
	edge("TOPLEFT", "TOPRIGHT", nil, size)
	edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, size)
	edge("TOPLEFT", "BOTTOMLEFT", size, nil)
	edge("TOPRIGHT", "BOTTOMRIGHT", size, nil)
	return list
end

-- A filled circle: the addon's anti-aliased 256 px circle (Textures/CircleHD.tga, white), tinted by paint. Drawn with
-- trilinear filtering so it stays smooth at any size; the game's 64 px portrait mask made jagged edges.
local CIRCLE_HD = "Interface\\AddOns\\" .. ADDON .. "\\Textures\\CircleHD"
local CIRCLE_SHADOW = "Interface\\AddOns\\" .. ADDON .. "\\Textures\\CircleShadow"
local function tinted(parent, file, layer, sub)
	local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub)
	if not pcall(t.SetTexture, t, file, "CLAMP", "CLAMP", "TRILINEAR") then t:SetTexture(file) end
	t.qtsTinted = true
	return t
end
local function circle(parent, layer, sub) return tinted(parent, CIRCLE_HD, layer, sub) end
local function paint(t, c, a)
	if t.qtsTinted then t:SetVertexColor(c[1], c[2], c[3], a or 1) else t:SetColorTexture(c[1], c[2], c[3], a or 1) end
end

-- control background: dark gradient with an edge, as on the Options window's pickers
local function controlBg(f)
	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	gradient(bg, C.ctrlTop, C.ctrlBottom)
	border(f, C.ctrlEdge, 1, "BORDER")
	local hl = f:CreateTexture(nil, "HIGHLIGHT")
	hl:SetAllPoints()
	hl:SetColorTexture(1, 0.9, 0.6, 0.08)
end

local function arrowTexture(parent, left, size)
	local t = parent:CreateTexture(nil, "ARTWORK")
	t:SetTexture(ARROW)
	t:SetSize(size, size)
	t:SetVertexColor(C.arrow[1], C.arrow[2], C.arrow[3])
	if left then t:SetTexCoord(1, 0, 0, 1) end
	return t
end

local function sound(on)
	if not (PlaySound and SOUNDKIT) then return end
	local id = on and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF
	if id then pcall(PlaySound, id) end
end

-- Settings text size: every label registers with its own base font; the size option scales them all and the rows
-- grow with them.
local fontList = {}
-- the window's text size, 80-125 % (larger sizes no longer fit the window's layout)
local TEXT_MIN, TEXT_MAX = 0.8, 1.25
local function ts()
	local k = tonumber(ns.db and ns.db.configTextSize) or 1
	return math.min(math.max(k, TEXT_MIN), TEXT_MAX)
end
local function reg(fs)
	local font, size, flags = fs:GetFont()
	if font and size then fontList[#fontList + 1] = { fs = fs, font = font, size = size, flags = flags } end
	return fs
end
local function text(parent, template, scale, c, layer)
	local fs = parent:CreateFontString(nil, layer or "OVERLAY", template or "GameFontHighlight")
	local font, size, flags = fs:GetFont()
	if font and size and scale and scale ~= 1 then fs:SetFont(font, size * scale, flags) end
	if c then fs:SetTextColor(c[1], c[2], c[3]) end
	return reg(fs)
end

-- Buttons grow to fit their label at any text size or font (no "..." cut-off).
local allButtons = {}
local function fitButton(button)
	local fs = rawget(button, "qtsText") or (button.GetFontString and button:GetFontString())
	if type(fs) ~= "table" then fs = nil end
	local textW = fs and fs.GetStringWidth and tonumber(fs:GetStringWidth()) or 0
	button:SetWidth(math.max(button.qtsBaseWidth or 0, math.ceil(textW + 28)))
end
-- Forever's red-and-gold panel button (UIPanelButtonTemplate), as "Defaults" and "Close" on the Options window
local function makeButton(parent, label, width, onClick)
	local button, templated = create("Button", nil, parent, "UIPanelButtonTemplate")
	button:SetSize(width, 24)
	button.qtsBaseWidth = width
	allButtons[#allButtons + 1] = button
	if templated then
		button:SetText(label)
	else
		local bg = button:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		gradient(bg, { 0.64, 0.094, 0.059 }, { 0.36, 0.043, 0.024 })
		border(button, { 0.72, 0.57, 0.25 })
		local highlight = button:CreateTexture(nil, "HIGHLIGHT")
		highlight:SetAllPoints()
		highlight:SetColorTexture(1, 1, 1, 0.15)
		local t = button:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		t:SetPoint("CENTER")
		t:SetText(label)
		button.qtsText = t
	end
	button:SetScript("OnClick", onClick)
	if label ~= "" then fitButton(button) end
	return button
end

-- The window's look for other windows of this addon (the prerequisites window, Prereqs.lua)
-- A standalone on/off switch in the settings' pill style (the Prerequisite Journal uses it): height h px; get() ->
-- on; set(on) after a click. Returns the button; button.redraw() after the state changes elsewhere.
local function makeSwitch(parent, h, get, set)
	local sw = CreateFrame("Button", nil, parent)
	local function pill(layer, sub)
		return { left = circle(sw, layer, sub), right = circle(sw, layer, sub), mid = sw:CreateTexture(nil, layer, nil, sub) }
	end
	local edge, fill = pill("BORDER", 0), pill("ARTWORK", 0)
	local knob = circle(sw, "OVERLAY")
	local function placePill(p, inset, c)
		local d = h - 2 * inset
		p.left:SetSize(d, d); p.left:ClearAllPoints(); p.left:SetPoint("LEFT", inset, 0)
		p.right:SetSize(d, d); p.right:ClearAllPoints(); p.right:SetPoint("RIGHT", -inset, 0)
		p.mid:ClearAllPoints()
		p.mid:SetPoint("TOPLEFT", inset + d / 2, -inset)
		p.mid:SetPoint("BOTTOMRIGHT", -(inset + d / 2), inset)
		paint(p.left, c); paint(p.right, c); paint(p.mid, c)
	end
	h = 2 * math.floor(h / 2 + 0.5)
	local w = math.floor(h * 40 / 22 + 0.5)
	sw:SetSize(w, h)
	function sw.redraw()
		local on = get() and true or false
		placePill(edge, 0, on and { 0.55, 0.43, 0.18 } or C.ctrlEdge)
		placePill(fill, 1, on and C.on or C.off)
		local ks = h - 6
		knob:SetSize(ks, ks)
		knob:ClearAllPoints()
		if on then knob:SetPoint("RIGHT", -3, 0) else knob:SetPoint("LEFT", 3, 0) end
		local kc = on and C.onKnob or C.offKnob
		if sw.qtsHover and not on then kc = C.value end
		paint(knob, kc)
	end
	sw:SetScript("OnClick", function()
		local v = not (get() and true or false)
		if PlaySound and SOUNDKIT then
			pcall(PlaySound, v and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON or SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_OFF)
		end
		set(v)
		sw.redraw()
	end)
	sw:HookScript("OnEnter", function(self) self.qtsHover = true; self.redraw() end)
	sw:HookScript("OnLeave", function(self) self.qtsHover = false; self.redraw() end)
	sw.redraw()
	return sw
end

api.themeKit = { C = C, create = create, solid = solid, gradient = gradient, border = border, makeButton = makeButton,
	text = text, makeSwitch = makeSwitch }

local function applyFonts()
	local k = ts()
	local chosen = api.fontPath and api.fontPath() -- the font chosen under Text and font (nil: as built)
	for _, entry in ipairs(fontList) do entry.fs:SetFont(chosen or entry.font, entry.size * k, entry.flags) end
	for _, button in ipairs(allButtons) do
		local fs = button.GetFontString and button:GetFontString()
		if fs and button.qtsBaseWidth then
			local _, size, flags = fs:GetFont()
			if chosen and size then pcall(fs.SetFont, fs, chosen, size, flags) end
		end
		if button.qtsBaseWidth and button:GetText() ~= "" then fitButton(button) end
	end
	-- the Prerequisite Journal follows the same text size and font
	if api.refreshPrereqsFonts then api.refreshPrereqsFonts() end
end
api.applyConfigFonts = function()
	if not frame then return end
	applyFonts()
	if frame.qtsArrangeOpacity then frame.qtsArrangeOpacity() end
	if frame.qtsArrangeSidebar then frame.qtsArrangeSidebar() end
end

---------------------------------------------------------------------------------------------------------------------
-- Pages and items (declared in display order; widgets are created once and re-positioned on every layout)
---------------------------------------------------------------------------------------------------------------------
local GROUPS = {
	{ key = "quests", title = "Quest Tracker", icon = "Interface\\GossipFrame\\AvailableQuestIcon" },
	-- RestedXP's classic logo (its default theme's rxp_logo-64, as on RestedXP's own windows)
	{ key = "guide", title = "RXP Tracker", icon = "Interface\\AddOns\\RXPGuides\\Textures\\rxp_logo-64" },
	{ key = "window", title = "Settings Window", icon = "Interface\\Buttons\\UI-OptionsButton" },
}
local pages, pageByKey = {}, {}
local function page(key, group, title)
	local p = { key = key, group = group, title = title }
	pages[#pages + 1] = p
	pageByKey[key] = p
	declaringPage = key
end

local declared = {}
local function declare(item) item.page = declaringPage; declared[#declared + 1] = item end
-- a sub-heading inside a page (e.g. "Upcoming steps")
local function heading(label) declare({ kind = "heading", label = label, full = true }) end
-- an on/off switch; sub: an optional grey second line under the label
local function check(label, get, set, enabled, indent, sub)
	declare({ kind = "check", label = label, get = get, set = set, enabled = enabled, indent = indent, sub = sub })
end
-- alpha: the opacity used when the saved colour has none (older saves)
local function color(label, get, set, enabled, indent, alpha)
	declare({ kind = "color", label = label, get = get, set = set, enabled = enabled, indent = indent, alpha = alpha })
end
local function slider(label, min, max, step, format, get, set, enabled, indent)
	declare({ kind = "slider", label = label, min = min, max = max, step = step, format = format,
		get = get, set = set, enabled = enabled, indent = indent })
end
-- full-width rows: a paragraph, a live status box, a row of buttons
local function note(label) declare({ kind = "note", label = label, full = true }) end
local function statusBox(label, read) declare({ kind = "status", label = label, read = read, full = true }) end
-- a < value > picker: options() -> { { value, label }, ... }
local function choice(label, options, get, set, enabled, indent, fontPreview)
	declare({ kind = "choice", label = label, options = options, get = get, set = set, enabled = enabled, indent = indent,
		fontPreview = fontPreview })
end
local function buttons(label, list, enabled) declare({ kind = "buttons", label = label, list = list, enabled = enabled, full = true }) end
-- a text box: label above, one line or several (lines > 1: scrolls); get() -> text, set(text) as it is typed
local function input(label, get, set, lines, hint)
	declare({ kind = "input", label = label, get = get, set = set, lines = lines or 1, hint = hint, full = true })
end
-- A scale/size slider in whole percent: stores a factor, shows "115%".
local function percent(label, min, max, get, set, enabled, indent, applyOnRelease)
	slider(label, min, max, 1, "%d%%", function() return math.floor((get() or 1) * 100 + 0.5) end,
		function(v) set(v / 100) end, enabled, indent)
	if applyOnRelease then declared[#declared].applyOnRelease = true end
end

---------------------------------------------------------------------------------------------------------------------
-- Rows: label on the left, control on the right
---------------------------------------------------------------------------------------------------------------------
local function indentOf(item) return item.indent and math.floor(math.min(item.indent, 48) * 0.75 + 0.5) or 0 end

local function rowLabel(item, parent)
	local fs = text(parent, "GameFontHighlight", 1.15, item.indent and C.subLabel or C.label)
	fs:SetJustifyH("LEFT")
	fs:SetJustifyV("TOP")
	fs:SetWordWrap(true)
	fs:SetText(item.label)
	item.text = fs
	if item.sub then
		local sub = text(parent, "GameFontDisableSmall", 1.05)
		sub:SetJustifyH("LEFT")
		sub:SetJustifyV("TOP")
		sub:SetWordWrap(true)
		sub:SetText(item.sub)
		item.subText = sub
	end
	return fs
end

-- Places the label and the control (ctrl, ctrlW x ctrlH) of a row at (x, y) in a page of width w; sets item.height.
local function placeRow(item, parent, x, y, w, ctrl, ctrlW, ctrlH)
	local k = ts()
	local indent = indentOf(item)
	local labelW = math.max(math.min(math.floor(w * 0.42), 300 * k), 140)
	local fs, sub = item.text, item.subText
	fs:SetWidth(labelW - indent)
	fs:SetHeight(0)
	local textH = fs:GetStringHeight() or 14
	if sub then
		sub:SetWidth(labelW - indent)
		sub:SetHeight(0)
		textH = textH + 2 + (sub:GetStringHeight() or 10)
	end
	local h = math.max(textH, ctrlH, 22 * k)
	fs:ClearAllPoints()
	fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x + indent, -y - math.floor((h - textH) / 2))
	if sub then
		sub:ClearAllPoints()
		sub:SetPoint("TOPLEFT", fs, "BOTTOMLEFT", 0, -2)
	end
	ctrl:ClearAllPoints()
	ctrl:SetPoint("TOPLEFT", parent, "TOPLEFT", x + labelW + 12, -y - math.floor((h - ctrlH) / 2))
	item.height = h + 8 * k
	item.ctrlMaxW = w - labelW - 12
end

local function rowEnabled(item, on, ...)
	local a = on and 1 or 0.4
	item.text:SetAlpha(a)
	if item.subText then item.subText:SetAlpha(a) end
	for i = 1, select("#", ...) do
		local f = select(i, ...)
		if f.SetEnabled then f:SetEnabled(on) end
		f:SetAlpha(a)
	end
end

-- On/off switch (Option B): a gold pill with a dark knob on the right when on; a dark pill, grey knob when off.
local function buildCheck(item, parent)
	rowLabel(item, parent)
	local sw = CreateFrame("Button", nil, parent)
	-- a pill: two circles and the rectangle between them; the edge pill sits 1 px outside the fill pill
	local function pill(layer, sub)
		return { left = circle(sw, layer, sub), right = circle(sw, layer, sub), mid = sw:CreateTexture(nil, layer, nil, sub) }
	end
	local edge, fill = pill("BORDER", 0), pill("ARTWORK", 0)
	local shade = tinted(sw, CIRCLE_SHADOW, "ARTWORK", 5)
	local knob = circle(sw, "OVERLAY")
	local shine = circle(sw, "OVERLAY", 1) -- a soft highlight on the knob's upper half
	local state = false
	local function placePill(p, w, h, inset, c)
		local d = h - 2 * inset
		p.left:SetSize(d, d); p.left:ClearAllPoints(); p.left:SetPoint("LEFT", inset, 0)
		p.right:SetSize(d, d); p.right:ClearAllPoints(); p.right:SetPoint("RIGHT", -inset, 0)
		p.mid:ClearAllPoints()
		p.mid:SetPoint("TOPLEFT", inset + d / 2, -inset)
		p.mid:SetPoint("BOTTOMRIGHT", -(inset + d / 2), inset)
		paint(p.left, c); paint(p.right, c); paint(p.mid, c)
	end
	local function draw()
		local k = ts()
		-- whole pixels, even height, so the round ends and the middle meet exactly
		local h = 2 * math.floor(11 * k + 0.5)
		local w = math.floor(h * 40 / 22 + 0.5)
		sw:SetSize(w, h)
		placePill(edge, w, h, 0, state and { 0.55, 0.43, 0.18 } or C.ctrlEdge)
		placePill(fill, w, h, 1, state and C.on or C.off)
		local ks = h - 6
		knob:SetSize(ks, ks)
		knob:ClearAllPoints()
		if state then knob:SetPoint("RIGHT", -3, 0) else knob:SetPoint("LEFT", 3, 0) end
		local kc = state and C.onKnob or C.offKnob
		if sw.qtsHover and not state then kc = C.value end
		paint(knob, kc)
		shade:SetSize(ks + 4, ks + 4)
		shade:ClearAllPoints()
		shade:SetPoint("CENTER", knob, "CENTER", 0, -1)
		paint(shade, { 0, 0, 0 }, 0.45)
		shine:SetSize(ks * 0.6, ks * 0.6)
		shine:ClearAllPoints()
		shine:SetPoint("CENTER", knob, "CENTER", 0, ks * 0.14)
		paint(shine, { 1, 1, 1 }, state and 0.08 or 0.14)
	end
	local function toggle()
		if loading then return end
		local v = not (item.get() and true or false)
		sound(v)
		item.set(v)
		api.refreshConfig()
	end
	sw:SetScript("OnClick", toggle)
	sw:SetScript("OnEnter", function(self) self.qtsHover = true; draw() end)
	sw:SetScript("OnLeave", function(self) self.qtsHover = false; draw() end)
	-- clicking the label toggles too
	local hit = CreateFrame("Button", nil, parent)
	hit:SetPoint("TOPLEFT", item.text, "TOPLEFT", -2, 2)
	hit:SetPoint("BOTTOMRIGHT", item.text, "BOTTOMRIGHT", 2, -2)
	hit:SetScript("OnClick", toggle)
	item.frame = sw
	item.refresh = function() state = item.get() and true or false; draw() end
	item.setEnabled = function(on) rowEnabled(item, on, sw, hit) end
	item.place = function(x, y, w)
		draw()
		placeRow(item, parent, x, y, w, sw, sw:GetWidth(), sw:GetHeight())
	end
	item.setShown = function(on)
		sw:SetShown(on); hit:SetShown(on); item.text:SetShown(on)
		if item.subText then item.subText:SetShown(on) end
	end
end

-- Slider: thin dark track, diamond thumb, step arrows at both ends, the value (typed in) on the right.
local function buildSlider(item, parent)
	rowLabel(item, parent)
	local holder = CreateFrame("Frame", nil, parent)
	local minus = CreateFrame("Button", nil, holder)
	local plus = CreateFrame("Button", nil, holder)
	local minusArrow, plusArrow = arrowTexture(minus, true, 12), arrowTexture(plus, false, 12)
	minusArrow:SetPoint("CENTER"); plusArrow:SetPoint("CENTER")
	local s = CreateFrame("Slider", nil, holder)
	s:SetOrientation("HORIZONTAL")
	local trackBg = s:CreateTexture(nil, "BACKGROUND")
	trackBg:SetPoint("LEFT"); trackBg:SetPoint("RIGHT"); trackBg:SetHeight(6)
	paint(trackBg, C.trackEdge)
	local track = s:CreateTexture(nil, "BORDER")
	track:SetPoint("LEFT", 1, 0); track:SetPoint("RIGHT", -1, 0); track:SetHeight(4)
	paint(track, C.track)
	local thumb = s:CreateTexture(nil, "OVERLAY")
	thumb:SetSize(12, 12)
	paint(thumb, C.thumb)
	if thumb.SetRotation then pcall(thumb.SetRotation, thumb, math.rad(45)) end
	s:SetThumbTexture(thumb)
	s:EnableMouse(true)
	s:SetMinMaxValues(item.min, item.max)
	s:SetValueStep(item.step)
	if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
	item.sliderFrame = s
	-- the value can also be typed: click it, enter a number, press Enter (Escape cancels)
	local value = CreateFrame("EditBox", nil, holder)
	value:SetAutoFocus(false)
	value:SetFontObject("GameFontHighlight")
	reg(value)
	value:SetTextColor(C.value[1], C.value[2], C.value[3])
	value:SetJustifyH("LEFT")
	value:SetTextInsets(4, 2, 0, 0)
	-- the value box is always shown (dark, thin edge) so it reads as typeable; brighter on hover and while typing
	local IDLE, ACTIVE = 0.45, 0.7
	local valueHl = value:CreateTexture(nil, "BACKGROUND")
	valueHl:SetAllPoints()
	valueHl:SetColorTexture(0, 0, 0, IDLE)
	local valueEdge = border(value, C.trackEdge, 1, "BORDER")
	local function edgeColor(c) for _, t in ipairs(valueEdge) do t:SetColorTexture(c[1], c[2], c[3], 1) end end
	value:SetScript("OnEnter", function() valueHl:SetColorTexture(0, 0, 0, ACTIVE) end)
	value:SetScript("OnLeave", function() if not value:HasFocus() then valueHl:SetColorTexture(0, 0, 0, IDLE) end end)

	local function show(v)
		if value:HasFocus() then return end
		local f = item.format
		value:SetText(type(f) == "function" and f(v) or f:format(v))
	end
	local function snap(v)
		v = math.min(math.max(v, item.min), item.max)
		return math.floor(v / item.step + 0.5) * item.step
	end
	local function commit(self)
		local t = self:GetText() or ""
		local number = tonumber((t:gsub(",", ".")):match("[-+]?%d*%.?%d+"))
		if t:lower():find("auto", 1, true) then number = 0 end
		self:ClearFocus()
		if number then s:SetValue(snap(number)) end
		show(s:GetValue())
	end
	value:SetScript("OnEditFocusGained", function(self)
		self:SetText(snap(s:GetValue()) .. "")
		self:HighlightText()
		valueHl:SetColorTexture(0, 0, 0, ACTIVE)
		edgeColor(C.thumb)
	end)
	value:SetScript("OnEnterPressed", commit)
	value:SetScript("OnEscapePressed", function(self) self:ClearFocus(); show(s:GetValue()) end)
	value:SetScript("OnEditFocusLost", function()
		show(s:GetValue())
		valueHl:SetColorTexture(0, 0, 0, IDLE)
		edgeColor(C.trackEdge)
	end)
	-- applyOnRelease: while the left mouse button is held (dragging the thumb or holding on the track) only the shown
	-- value follows; the setting changes once the button is released. The button state is read directly: the game
	-- sends the slider no mouse-down when its thumb is grabbed (3.4.1 waited for one, and the loop went on).
	local pending
	local watcher
	local function applyPending()
		if pending == nil then return end
		local v = pending
		pending = nil
		item.set(v)
	end
	s:SetScript("OnValueChanged", function(_, v)
		v = snap(v)
		show(v)
		if loading then return end
		if item.applyOnRelease and IsMouseButtonDown("LeftButton") then
			pending = v
			if not watcher then
				watcher = CreateFrame("Frame", nil, s)
				watcher:SetScript("OnUpdate", function(self)
					if IsMouseButtonDown("LeftButton") then return end
					self:Hide()
					applyPending()
				end)
			end
			watcher:Show()
			return
		end
		item.set(v)
	end)
	if item.applyOnRelease then
		s:HookScript("OnHide", function()
			if watcher then watcher:Hide() end
			applyPending()
		end)
	end
	minus:SetScript("OnClick", function() s:SetValue(snap(s:GetValue() - item.step)) end)
	plus:SetScript("OnClick", function() s:SetValue(snap(s:GetValue() + item.step)) end)
	-- mouse wheel over the slider steps it (the page scrolls everywhere else)
	s:EnableMouseWheel(true)
	s:SetScript("OnMouseWheel", function(_, delta) s:SetValue(snap(s:GetValue() + delta * item.step)) end)

	item.frame = holder
	item.refresh = function()
		local v = item.get()
		s:SetValue(v)
		show(v)
	end
	item.setEnabled = function(on)
		rowEnabled(item, on, minus, plus)
		s:EnableMouse(on and true or false)
		value:EnableMouse(on and true or false)
		holder:SetAlpha(on and 1 or 0.4)
	end
	item.place = function(x, y, w)
		local k = ts()
		local h = math.floor(22 * k + 0.5)
		placeRow(item, parent, x, y, w, holder, 10, h)
		local valueW = math.floor(84 * k)
		local trackW = math.max(math.min(item.ctrlMaxW - valueW - 2 * (14 + 6), 220 * k), 60)
		holder:SetSize(14 + 6 + trackW + 6 + 14 + 6 + valueW, h)
		minus:SetSize(14, h); minus:ClearAllPoints(); minus:SetPoint("LEFT")
		s:SetSize(trackW, h); s:ClearAllPoints(); s:SetPoint("LEFT", minus, "RIGHT", 6, 0)
		plus:SetSize(14, h); plus:ClearAllPoints(); plus:SetPoint("LEFT", s, "RIGHT", 6, 0)
		value:SetSize(valueW, h); value:ClearAllPoints(); value:SetPoint("LEFT", plus, "RIGHT", 6, 0)
		thumb:SetSize(math.floor(12 * k), math.floor(12 * k))
	end
	item.setShown = function(on)
		holder:SetShown(on); item.text:SetShown(on)
		if item.subText then item.subText:SetShown(on) end
	end
end

-- Colour picker: Blizzard's ColorPickerFrame (new SetupColorPickerAndShow API, or the older field-based API).
local function openPicker(r, g, b, onChange)
	local picker = ColorPickerFrame
	if not picker then return end
	local function current()
		local nr, ng, nb = picker:GetColorRGB()
		onChange(nr, ng, nb)
	end
	local function cancel(previous)
		if type(previous) == "table" then
			onChange(previous.r or previous[1] or r, previous.g or previous[2] or g, previous.b or previous[3] or b)
		else
			onChange(r, g, b)
		end
	end
	if picker.SetupColorPickerAndShow then
		picker:SetupColorPickerAndShow({ r = r, g = g, b = b, hasOpacity = false, swatchFunc = current, cancelFunc = cancel })
	else
		picker.hasOpacity = false
		picker.previousValues = { r = r, g = g, b = b }
		picker.func = current
		picker.cancelFunc = cancel
		picker:SetColorRGB(r, g, b)
		picker:Hide()
		picker:Show()
	end
	if picker.SetFrameStrata then picker:SetFrameStrata("FULLSCREEN_DIALOG") end
end

local function sameColor(a, b)
	return math.abs(a[1] - b[1]) < 0.01 and math.abs(a[2] - b[2]) < 0.01 and math.abs(a[3] - b[3]) < 0.01
end

-- Colour swatches (Option B) plus a custom-colour button: a ring marks the current colour; a colour that is none of
-- the presets shows in the custom button.
local function buildColor(item, parent)
	rowLabel(item, parent)
	local holder = CreateFrame("Frame", nil, parent)
	local dots, presetOf = {}, {}
	local function makeDot(name, onClick)
		local b = CreateFrame("Button", nil, holder)
		b.ring = circle(b, "BACKGROUND")
		b.ring:SetAllPoints()
		b.gap = circle(b, "BORDER") -- a dark gap between ring and colour, as on the game's swatches
		b.fill = circle(b, "ARTWORK")
		b.shine = circle(b, "ARTWORK", 2)
		b:SetScript("OnClick", onClick)
		b:SetScript("OnEnter", function(self)
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			GameTooltip:SetText(name, 1, 1, 1)
			GameTooltip:Show()
		end)
		b:SetScript("OnLeave", function(self) if GameTooltip:GetOwner() == self then GameTooltip:Hide() end end)
		dots[#dots + 1] = b
		return b
	end
	-- the colour's opacity (its 4th value): kept when another colour is picked
	local function alphaOf(c) return tonumber(c and c[4]) or item.alpha or 1 end
	local function choose(c, a)
		if loading then return end
		item.set({ c[1], c[2], c[3], a or alphaOf(item.get()) })
		item.refresh()
	end
	for _, preset in ipairs(SWATCHES) do
		local c = preset[2]
		local b = makeDot(preset[1], function() sound(true); choose(c) end)
		presetOf[b] = c
	end
	local custom = makeDot("Custom colour...", function()
		local c = item.get()
		openPicker(c[1], c[2], c[3], function(r, g, b) choose({ r, g, b }) end)
	end)
	custom.plus = custom:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	custom.plus:SetPoint("CENTER", 0, 1)
	custom.plus:SetText("+")

	-- Opacity, under the swatches: a short slider (5-100 %) and its value
	local opacityLabel = text(holder, "GameFontHighlightSmall", 1.1, C.subLabel)
	opacityLabel:SetText("Opacity")
	local opacity = CreateFrame("Slider", nil, holder)
	opacity:SetOrientation("HORIZONTAL")
	opacity:SetMinMaxValues(5, 100)
	opacity:SetValueStep(5)
	if opacity.SetObeyStepOnDrag then opacity:SetObeyStepOnDrag(true) end
	local otrackBg = opacity:CreateTexture(nil, "BACKGROUND")
	otrackBg:SetPoint("LEFT"); otrackBg:SetPoint("RIGHT"); otrackBg:SetHeight(6)
	paint(otrackBg, C.trackEdge)
	local otrack = opacity:CreateTexture(nil, "BORDER")
	otrack:SetPoint("LEFT", 1, 0); otrack:SetPoint("RIGHT", -1, 0); otrack:SetHeight(4)
	paint(otrack, C.track)
	local othumb = opacity:CreateTexture(nil, "OVERLAY")
	othumb:SetSize(11, 11)
	paint(othumb, C.thumb)
	if othumb.SetRotation then pcall(othumb.SetRotation, othumb, math.rad(45)) end
	opacity:SetThumbTexture(othumb)
	opacity:EnableMouseWheel(true)
	opacity:SetScript("OnMouseWheel", function(self, delta) self:SetValue(self:GetValue() + delta * 5) end)
	local opacityValue = text(holder, "GameFontHighlightSmall", 1.1, C.value)
	opacityValue:SetJustifyH("LEFT")
	opacity:SetScript("OnValueChanged", function(_, v)
		v = math.floor(v / 5 + 0.5) * 5
		opacityValue:SetText(v .. "%")
		if loading or item.qtsDrawing then return end
		local c = item.get()
		item.set({ c[1], c[2], c[3], v / 100 })
		item.qtsDrawing = true
		item.refresh()
		item.qtsDrawing = false
	end)

	local function draw()
		local k = ts()
		local size = math.floor(22 * k + 0.5)
		local current = item.get()
		local matched = false
		for i, b in ipairs(dots) do
			b:SetSize(size, size)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", holder, "TOPLEFT", (i - 1) * (size + 6), 0)
			b.gap:ClearAllPoints()
			b.gap:SetPoint("TOPLEFT", 2, -2)
			b.gap:SetPoint("BOTTOMRIGHT", -2, 2)
			paint(b.gap, C.list)
			b.fill:ClearAllPoints()
			b.fill:SetPoint("TOPLEFT", 3, -3)
			b.fill:SetPoint("BOTTOMRIGHT", -3, 3)
			local inner = size - 6
			b.shine:SetSize(inner * 0.55, inner * 0.55)
			b.shine:ClearAllPoints()
			b.shine:SetPoint("CENTER", b, "CENTER", -inner * 0.12, inner * 0.14)
			paint(b.shine, { 1, 1, 1 }, 0.12)
			local selected
			local preset = presetOf[b]
			if preset then
				selected = sameColor(preset, current)
				if selected then matched = true end
				paint(b.fill, preset)
			end
			b.selected = selected
		end
		-- the custom button: the current colour when it is not a preset, else dark with a "+"
		custom.selected = not matched
		if matched then paint(custom.fill, C.off) else paint(custom.fill, current) end
		custom.plus:SetShown(matched)
		-- each swatch shows the opacity too
		local a = alphaOf(current)
		for _, b in ipairs(dots) do
			if b.selected then paint(b.ring, C.ring) else paint(b.ring, C.ctrlEdge) end
			b.fill:SetAlpha(b == custom and matched and 1 or math.max(a, 0.15))
		end
		local rowW = #dots * (size + 6)
		local lineH = math.floor(18 * k + 0.5)
		opacityLabel:ClearAllPoints()
		opacityLabel:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -(size + math.floor(10 * k + 0.5)))
		opacityLabel:SetHeight(lineH)
		local labelW = math.ceil(opacityLabel:GetStringWidth() or 40)
		opacity:ClearAllPoints()
		opacity:SetPoint("LEFT", opacityLabel, "LEFT", labelW + 8, 0)
		opacity:SetSize(math.max(rowW - labelW - 8 - 44 * k, 60), lineH)
		opacityValue:ClearAllPoints()
		opacityValue:SetPoint("LEFT", opacity, "RIGHT", 8, 0)
		if not item.qtsDrawing then
			item.qtsDrawing = true -- showing the saved value is not a change
			opacity:SetValue(math.floor(a * 100 / 5 + 0.5) * 5)
			item.qtsDrawing = false
		end
		opacityValue:SetText(math.floor(a * 100 / 5 + 0.5) * 5 .. "%")
		holder:SetSize(math.max(rowW, labelW + 8 + 60 + 52 * k), size + math.floor(10 * k + 0.5) + lineH)
	end
	item.frame = holder
	item.refresh = draw
	item.setEnabled = function(on)
		rowEnabled(item, on, unpack(dots))
		opacity:EnableMouse(on and true or false)
		local a = on and 1 or 0.4
		opacity:SetAlpha(a); opacityLabel:SetAlpha(a); opacityValue:SetAlpha(a)
	end
	item.place = function(x, y, w)
		draw()
		placeRow(item, parent, x, y, w, holder, holder:GetWidth(), holder:GetHeight())
	end
	item.setShown = function(on) holder:SetShown(on); item.text:SetShown(on) end
end

-- Picker (Option A): [<] value [>]; the arrows step through the choices, the value opens the list below it. The list is
-- its own top-level frame (the page is clipped by its scroll frame) and closes on a choice, a second click, or when
-- the picker is hidden.
local openPopup
local function buildChoice(item, parent)
	rowLabel(item, parent)
	local holder = CreateFrame("Frame", nil, parent)
	local prev = CreateFrame("Button", nil, holder)
	local nxt = CreateFrame("Button", nil, holder)
	controlBg(prev); controlBg(nxt)
	local pa, na = arrowTexture(prev, true, 14), arrowTexture(nxt, false, 14)
	pa:SetPoint("CENTER"); na:SetPoint("CENTER")
	local box = CreateFrame("Button", nil, holder)
	controlBg(box)
	local label = text(box, "GameFontHighlight", 1.1, C.value)
	label:SetPoint("LEFT", 8, 0)
	label:SetPoint("RIGHT", -8, 0)
	label:SetJustifyH("CENTER")
	label:SetWordWrap(true)

	local popup
	local function labelFont() return label:GetFont() end
	local function closePopup()
		if popup and popup.typed then popup.typed:ClearFocus() end
		if popup then popup:Hide() end
		if openPopup == popup then openPopup = nil end
	end
	local function labelFor(value)
		for _, option in ipairs(item.options()) do if option[1] == value then return option[2] end end
		return tostring(value)
	end
	local function pick(value)
		closePopup()
		if loading then return end
		sound(true)
		item.set(value)
		api.refreshConfig()
	end
	local function step(delta)
		local options = item.options()
		local index = 1
		for i, option in ipairs(options) do if option[1] == item.get() then index = i end end
		index = ((index - 1 + delta) % #options) + 1
		if options[index] then pick(options[index][1]) end
	end
	prev:SetScript("OnClick", function() step(-1) end)
	nxt:SetScript("OnClick", function() step(1) end)
	-- Long lists (fonts) get a type box at the top: typed letters filter the list and the first choice that starts
	-- with them is filled in (the rest highlighted); Enter picks it, Escape closes.
	local TYPE_AHEAD_MIN = 8
	local function typeAhead() return item.fontPreview or #item.options() >= TYPE_AHEAD_MIN end
	local filter, firstMatch = "", nil
	local fillRows -- below
	local function buildPopup()
		popup = CreateFrame("Frame", nil, UIParent)
		popup:SetFrameStrata("FULLSCREEN_DIALOG")
		popup:SetClampedToScreen(true)
		popup:EnableMouse(true)
		local bg = popup:CreateTexture(nil, "BACKGROUND")
		bg:SetAllPoints()
		paint(bg, C.list, 0.97)
		border(popup, C.ctrlEdge)
		popup.rows = {}
		-- the type box (shown for long lists)
		local typed = CreateFrame("EditBox", nil, popup)
		typed:SetAutoFocus(false)
		typed:SetFontObject("GameFontHighlight")
		typed:SetTextInsets(8, 8, 0, 0)
		local tbg = typed:CreateTexture(nil, "BACKGROUND")
		tbg:SetAllPoints()
		paint(tbg, { 0.047, 0.039, 0.031 })
		border(typed, C.trackEdge)
		local hint = typed:CreateFontString(nil, "OVERLAY", "GameFontDisable")
		hint:SetPoint("LEFT", 8, 0)
		hint:SetText("Type to search...")
		typed.hint = hint
		local lastLen = 0
		typed:SetScript("OnTextChanged", function(self, userInput)
			if not userInput then return end
			local text = self:GetText() or ""
			-- the part the user typed: the text before a highlighted suggestion (the cursor sits at its end)
			local cursor = self:GetCursorPosition() or #text
			local mine = text:sub(1, cursor)
			hint:SetShown(mine == "")
			filter = mine
			fillRows()
			-- suggest the rest of the first choice that starts with what was typed (not while deleting)
			if #mine > lastLen and firstMatch and firstMatch:lower():sub(1, #mine) == mine:lower() and #firstMatch > #mine then
				self:SetText(firstMatch) -- the choice's own spelling; the untyped rest is highlighted
				self:SetCursorPosition(#mine)
				self:HighlightText(#mine, #firstMatch)
			end
			lastLen = #mine
		end)
		typed:SetScript("OnEnterPressed", function(self)
			self:ClearFocus()
			if popup.firstValue ~= nil then pick(popup.firstValue) else closePopup() end
		end)
		typed:SetScript("OnEscapePressed", function(self) self:ClearFocus(); closePopup() end)
		typed:SetScript("OnEditFocusGained", function() lastLen = 0 end)
		popup.typed = typed
		popup.scroll = CreateFrame("ScrollFrame", nil, popup)
		popup.child = CreateFrame("Frame", nil, popup.scroll)
		popup.child:SetSize(1, 1)
		popup.scroll:SetScrollChild(popup.child)
		popup.track = popup:CreateTexture(nil, "ARTWORK")
		popup.track:SetWidth(4)
		paint(popup.track, C.track)
		popup.thumb = popup:CreateTexture(nil, "OVERLAY")
		popup.thumb:SetWidth(4)
		paint(popup.thumb, C.thumb)
		local function placeThumb()
			local range = popup.scroll:GetVerticalScrollRange() or 0
			local shown = range > 0.5
			popup.track:SetShown(shown)
			popup.thumb:SetShown(shown)
			if not shown then return end
			local trackH = popup.scroll:GetHeight() - 4
			local viewH = popup.scroll:GetHeight()
			local thumbH = math.max(16, trackH * viewH / (viewH + range))
			local pos = (popup.scroll:GetVerticalScroll() / range) * (trackH - thumbH)
			popup.thumb:SetHeight(thumbH)
			popup.thumb:ClearAllPoints()
			popup.thumb:SetPoint("TOPRIGHT", popup.scroll, "TOPRIGHT", -3, -2 - pos)
		end
		popup.placeThumb = placeThumb
		popup:EnableMouseWheel(true)
		popup:SetScript("OnMouseWheel", function(_, delta)
			local range = popup.scroll:GetVerticalScrollRange() or 0
			local value = popup.scroll:GetVerticalScroll() - delta * 44 * ts()
			popup.scroll:SetVerticalScroll(math.min(math.max(value, 0), range))
			placeThumb()
		end)
	end

	-- the rows for the current filter; sizes and places the popup
	function fillRows()
		local options = item.options()
		local width = box:GetWidth()
		local k = ts()
		local useType = typeAhead()
		local typeH = useType and math.floor(26 * k + 0.5) or 0
		local needle = filter:lower()
		local listH, shown = 4, 0
		popup.currentTop, popup.firstValue, firstMatch = nil, nil, nil
		for _, option in ipairs(options) do
			local label = tostring(option[2])
			local lower = label:lower()
			if needle == "" or lower:find(needle, 1, true) then
				shown = shown + 1
				-- prefer a choice that starts with what was typed for Enter and the suggestion
				if needle ~= "" and lower:sub(1, #needle) == needle and not firstMatch then
					firstMatch, popup.firstValue = label, option[1]
				end
				local row = popup.rows[shown]
				if not row then
					row = CreateFrame("Button", nil, popup.child)
					row.sel = row:CreateTexture(nil, "BACKGROUND")
					row.sel:SetAllPoints()
					hGradient(row.sel, { 1, 0.82, 0 }, 0.22, 0.02)
					local hl = row:CreateTexture(nil, "HIGHLIGHT")
					hl:SetAllPoints()
					hl:SetColorTexture(1, 0.9, 0.6, 0.1)
					row.text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
					row.text:SetPoint("LEFT", 12, 0)
					row.text:SetPoint("RIGHT", -12, 0)
					row.text:SetJustifyH("LEFT")
					row.text:SetWordWrap(true)
					popup.rows[shown] = row
				end
				local current = item.get() == option[1]
				local font, size, flags = labelFont()
				if item.fontPreview and option.path then font = option.path end
				if font and size then pcall(row.text.SetFont, row.text, font, size, flags) end
				row.text:SetText(label)
				local tc = current and { 1, 1, 1 } or C.listText
				row.text:SetTextColor(tc[1], tc[2], tc[3])
				row.sel:SetShown(current)
				row:SetScript("OnClick", function() pick(option[1]) end)
				row:ClearAllPoints()
				row:SetPoint("TOPLEFT", popup.child, "TOPLEFT", 1, -listH)
				row.text:SetHeight(0)
				local rowH = math.max(22 * k, math.ceil((row.text:GetStringHeight() or 12) + 8))
				row:SetHeight(rowH)
				if current then popup.currentTop = listH end
				listH = listH + rowH
				row:Show()
			end
		end
		if needle ~= "" and not firstMatch and shown > 0 then
			-- no choice starts with it: Enter takes the first one that contains it
			for _, option in ipairs(options) do
				if tostring(option[2]):lower():find(needle, 1, true) then popup.firstValue = option[1] break end
			end
		end
		for i = shown + 1, #popup.rows do popup.rows[i]:Hide() end
		-- at most about 12 rows or 60 % of the screen
		local screenH = UIParent:GetHeight() or 768
		local maxList = math.min(math.floor(screenH * 0.6) - typeH, math.floor(12 * 22 * k + 8))
		local fullH = math.max(listH + 4, math.floor(22 * k) + 8)
		local listView = math.min(fullH, maxList)
		local scrolls = fullH > maxList
		for i = 1, shown do popup.rows[i]:SetWidth(width - 2 - (scrolls and 10 or 0)) end
		popup.child:SetSize(width, fullH)
		popup.typed:SetShown(useType)
		popup.typed:ClearAllPoints()
		if useType then
			popup.typed:SetPoint("TOPLEFT", 4, -4)
			popup.typed:SetPoint("TOPRIGHT", -4, -4)
			popup.typed:SetHeight(typeH - 4)
		end
		popup.scroll:ClearAllPoints()
		popup.scroll:SetPoint("TOPLEFT", 0, -typeH)
		popup.scroll:SetPoint("BOTTOMRIGHT", 0, 0)
		popup:SetSize(width, listView + typeH)
		popup.scroll:UpdateScrollChildRect()
		local range = math.max(fullH - listView, 0)
		local target = 0
		if scrolls and needle == "" and popup.currentTop then
			target = math.min(math.max(popup.currentTop - listView / 2, 0), range)
		end
		popup.scroll:SetVerticalScroll(target)
		popup.placeThumb()
		popup.scrolls = scrolls
	end

	local function openList()
		if openPopup and openPopup ~= popup then openPopup:Hide() end
		if not popup then buildPopup() end
		filter = ""
		popup.typed:SetText("")
		popup.typed.hint:Show()
		fillRows()
		-- below the box, or above it when there is more room there
		local screenH = UIParent:GetHeight() or 768
		popup:ClearAllPoints()
		local scale = box:GetEffectiveScale() / UIParent:GetEffectiveScale()
		local below = (box:GetBottom() or 0) * scale
		local above = screenH - (box:GetTop() or 0) * scale
		if below < popup:GetHeight() + 8 and above > below then
			popup:SetPoint("BOTTOMLEFT", box, "TOPLEFT", 0, 2)
		else
			popup:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 0, -2)
		end
		popup:Show()
		if typeAhead() then popup.typed:SetFocus() end
		openPopup = popup
	end
	box:SetScript("OnClick", function()
		if popup and popup:IsShown() then closePopup() else openList() end
	end)
	box:HookScript("OnHide", closePopup)

	item.frame = holder
	item.refresh = function()
		label:SetText(labelFor(item.get()))
		if item.fontPreview then
			for _, option in ipairs(item.options()) do
				if option[1] == item.get() and option.path then
					local _, size, flags = label:GetFont()
					pcall(label.SetFont, label, option.path, size, flags)
				end
			end
		end
	end
	item.setEnabled = function(on)
		rowEnabled(item, on, prev, nxt, box)
		if not on then closePopup() end
	end
	item.place = function(x, y, w)
		local k = ts()
		local arrowW = math.floor(26 * k + 0.5)
		-- the box is as wide as the longest choice needs (up to the room there is), and grows down when it wraps
		placeRow(item, parent, x, y, w, holder, 10, 26 * k)
		local boxW = math.max(math.min(item.ctrlMaxW - 2 * (arrowW + 4), 260 * k), 100)
		label:SetWidth(boxW - 16)
		label:SetHeight(0)
		local h = math.max(math.floor(26 * k + 0.5), math.ceil((label:GetStringHeight() or 12) + 8))
		prev:SetSize(arrowW, math.floor(26 * k + 0.5))
		nxt:SetSize(arrowW, math.floor(26 * k + 0.5))
		box:SetSize(boxW, h)
		prev:ClearAllPoints(); prev:SetPoint("LEFT", holder, "LEFT", 0, 0)
		box:ClearAllPoints(); box:SetPoint("LEFT", prev, "RIGHT", 4, 0)
		nxt:ClearAllPoints(); nxt:SetPoint("LEFT", box, "RIGHT", 4, 0)
		holder:SetSize(arrowW * 2 + 8 + boxW, h)
		-- re-centre now that the real height is known
		placeRow(item, parent, x, y, w, holder, holder:GetWidth(), h)
	end
	item.setShown = function(on)
		holder:SetShown(on); item.text:SetShown(on)
		if item.subText then item.subText:SetShown(on) end
		if not on then closePopup() end
	end
end

local function buildHeading(item, parent)
	local fs = text(parent, "GameFontHighlightLarge", 1.2, C.pageTitle)
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(true)
	fs:SetText(item.label)
	item.place = function(x, y, w)
		local top = y > 0 and 14 * ts() or 0
		fs:ClearAllPoints()
		fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y - top)
		fs:SetWidth(math.max(w, 40))
		fs:SetHeight(0)
		item.height = top + (fs:GetStringHeight() or 18) + 10 * ts()
	end
	item.setShown = function(on) fs:SetShown(on) end
	item.refresh = function() end
	item.setEnabled = function() end
end

local function buildNote(item, parent)
	local fs = text(parent, "GameFontHighlight", 1.1, C.subLabel)
	fs:SetJustifyH("LEFT")
	fs:SetWordWrap(true)
	fs:SetText(item.label)
	item.place = function(x, y, w)
		fs:ClearAllPoints()
		fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y - 2)
		fs:SetWidth(math.max(w - 8, 40))
		fs:SetHeight(0)
		item.height = math.max(fs:GetStringHeight() or 14, 14) + 12
	end
	item.setShown = function(on) fs:SetShown(on) end
	item.refresh = function() end
	item.setEnabled = function() end
end

-- Label/value rows read from item.read() on every refresh (and once a second while its page is shown).
local function buildStatus(item, parent)
	local holder = CreateFrame("Frame", nil, parent)
	local bg = holder:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	gradient(bg, C.ctrlTop, C.ctrlBottom)
	border(holder, C.ctrlEdge)
	local rows, count = {}, 0
	local function row(i)
		if not rows[i] then
			local l = text(holder, "GameFontHighlight", 1.05, C.subLabel)
			local v = text(holder, "GameFontHighlight", 1.05)
			l:SetJustifyH("LEFT")
			v:SetJustifyH("LEFT")
			v:SetWordWrap(true)
			rows[i] = { label = l, value = v }
		end
		return rows[i]
	end
	local function arrange()
		local k = ts()
		local width = holder:GetWidth() or 200
		local y = 10
		for i = 1, count do
			local r = rows[i]
			r.label:ClearAllPoints()
			r.label:SetPoint("TOPLEFT", holder, "TOPLEFT", 12, -y)
			r.label:SetWidth(90 * k)
			r.value:ClearAllPoints()
			r.value:SetPoint("TOPLEFT", holder, "TOPLEFT", 12 + 96 * k, -y)
			r.value:SetWidth(math.max(width - 120 * k, 40))
			r.value:SetHeight(0)
			y = y + math.max(r.value:GetStringHeight() or 0, 13 * k) + 6
		end
		return y + 4
	end
	item.refresh = function()
		local list = item.read() or {}
		count = #list
		for i, pair in ipairs(list) do
			local r = row(i)
			r.label:SetText(pair[1])
			r.value:SetText(pair[2])
			local c = pair[3]
			if c then r.value:SetTextColor(c[1], c[2], c[3]) else r.value:SetTextColor(1, 1, 1) end
			r.label:Show()
			r.value:Show()
		end
		for i = count + 1, #rows do rows[i].label:Hide(); rows[i].value:Hide() end
		holder:SetHeight(arrange())
	end
	item.setEnabled = function() end
	item.place = function(x, y, w)
		holder:ClearAllPoints()
		holder:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
		holder:SetWidth(w - 8)
		holder:SetHeight(arrange())
		item.height = holder:GetHeight() + 10
	end
	item.setShown = function(on) holder:SetShown(on) end
	item.frame = holder
end

-- A row of red panel buttons: item.list = { { label, onClick, width }, ... }
local function buildInput(item, parent)
	local label = text(parent, "GameFontHighlight", 1.15, C.label)
	label:SetJustifyH("LEFT")
	label:SetText(item.label)
	local holder = CreateFrame("Frame", nil, parent)
	local bg = holder:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(0, 0, 0, 0.45)
	local edge = border(holder, C.trackEdge, 1, "BORDER")
	local function edgeColor(c) for _, t in ipairs(edge) do t:SetColorTexture(c[1], c[2], c[3], 1) end end
	local multi = (item.lines or 1) > 1
	local box = CreateFrame("EditBox", nil, multi and nil or holder)
	box:SetAutoFocus(false)
	box:SetFontObject("ChatFontNormal")
	box:SetMaxLetters(0)
	box:SetTextInsets(6, 6, 4, 4)
	local scrollFrame
	if multi then
		box:SetMultiLine(true)
		scrollFrame = CreateFrame("ScrollFrame", nil, holder)
		scrollFrame:SetPoint("TOPLEFT", 2, -2)
		scrollFrame:SetPoint("BOTTOMRIGHT", -2, 2)
		box:SetParent(scrollFrame)
		scrollFrame:SetScrollChild(box)
		scrollFrame:EnableMouseWheel(true)
		scrollFrame:SetScript("OnMouseWheel", function(self, delta)
			local range = self:GetVerticalScrollRange() or 0
			self:SetVerticalScroll(math.min(math.max((self:GetVerticalScroll() or 0) - delta * 20, 0), range))
		end)
		-- a click anywhere in the box starts typing
		holder:EnableMouse(true)
		holder:SetScript("OnMouseDown", function() box:SetFocus() end)
		box:SetScript("OnCursorChanged", function(_, _, y, _, h)
			local view = scrollFrame:GetHeight() or 0
			local at = scrollFrame:GetVerticalScroll() or 0
			y = -y
			if y < at then scrollFrame:SetVerticalScroll(y) elseif y + h > at + view then scrollFrame:SetVerticalScroll(y + h - view) end
		end)
	else
		box:SetAllPoints()
	end
	local hint = item.hint and text(holder, "GameFontDisable", 1.05)
	if hint then
		hint:SetPoint("TOPLEFT", 8, -6)
		hint:SetText(item.hint)
	end
	local function showHint() if hint then hint:SetShown((box:GetText() or "") == "" and not box:HasFocus()) end end
	box:SetScript("OnTextChanged", function(self, user)
		if user and item.set then item.set(self:GetText()) end
		showHint()
	end)
	box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
	if not multi then box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end) end
	box:SetScript("OnEditFocusGained", function(self) edgeColor(C.thumb); showHint(); if item.selectAll then self:HighlightText() end end)
	box:SetScript("OnEditFocusLost", function() edgeColor(C.trackEdge); showHint() end)
	item.edit = box
	item.refresh = function()
		if item.get and not box:HasFocus() then box:SetText(item.get() or "") end
		showHint()
	end
	item.place = function(x, y, w)
		local k = ts()
		label:ClearAllPoints()
		label:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y - 4)
		label:SetWidth(w - 8)
		local labelH = math.ceil(label:GetStringHeight() or 14) + 6
		local lineH = math.floor(16 * k + 0.5)
		local boxH = multi and (lineH * item.lines + 10) or math.floor(26 * k + 0.5)
		holder:ClearAllPoints()
		holder:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y - 4 - labelH)
		holder:SetSize(w - 8, boxH)
		if multi then box:SetWidth(w - 12) end
		item.height = 4 + labelH + boxH + 8
	end
	item.setShown = function(on) label:SetShown(on); holder:SetShown(on) end
	item.setEnabled = function(on)
		box:SetEnabled(on)
		holder:SetAlpha(on and 1 or 0.4)
	end
	item.frame = holder
end

local function buildButtons(item, parent)
	local list = {}
	for _, def in ipairs(item.list) do
		list[#list + 1] = makeButton(parent, def[1], def[3] or 150, function() def[2](); api.refreshConfig() end)
	end
	-- in a row, wrapping onto the next line when the page is too narrow for all of them
	item.place = function(x, y)
		local left, top, rows = x, y, 1
		local room = (parent:GetWidth() or 0) - 8
		for _, b in ipairs(list) do
			local w = b:GetWidth() or 0
			if left > x and room > 0 and left + w > room then
				left, top, rows = x, top + 32, rows + 1
			end
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", parent, "TOPLEFT", left, -top - 6)
			left = left + w + 8
		end
		item.height = 38 + (rows - 1) * 32
	end
	item.setShown = function(on) for _, b in ipairs(list) do b:SetShown(on) end end
	item.refresh = function() end
	item.setEnabled = function(on)
		for _, b in ipairs(list) do
			if b.SetEnabled then b:SetEnabled(on) end
			b:SetAlpha(on and 1 or 0.4)
		end
	end
end

-- Orphaned quests (Themes & guide): RestedXP's list of quests in your log the current guide does not use. Hover a quest
-- for its Abandon button; "Cleanup orphaned quests" abandons them all. Both ask once more (click again within 4 s):
-- abandoning cannot be undone.
local CONFIRM_SECONDS = 4
-- A quest's difficulty colour for you (grey, green, yellow, orange, red): the game's own GetQuestDifficultyColor, else
-- the same rule worked out from the level difference (green down to GetQuestGreenRange levels below you)
local DIFFICULTY = { red = { 1, 0.1, 0.1 }, orange = { 1, 0.5, 0.25 }, yellow = { 1, 1, 0 }, green = { 0.25, 0.75, 0.25 },
	grey = { 0.5, 0.5, 0.5 } }
local function questDifficultyColor(level)
	if type(level) ~= "number" or level <= 0 then return C.value end
	if GetQuestDifficultyColor then
		local ok, c = pcall(GetQuestDifficultyColor, level)
		if ok and type(c) == "table" and type(c.r) == "number" then return { c.r, c.g, c.b } end
	end
	local diff = level - (UnitLevel and UnitLevel("player") or level)
	if diff >= 5 then return DIFFICULTY.red end
	if diff >= 3 then return DIFFICULTY.orange end
	if diff >= -2 then return DIFFICULTY.yellow end
	local okRange, range = pcall(function() return GetQuestGreenRange and GetQuestGreenRange() end)
	if -diff <= ((okRange and tonumber(range)) or 8) then return DIFFICULTY.green end
	return DIFFICULTY.grey
end
local function buildOrphans(item, parent)
	local g = root.objectives and root.objectives.settings
	local holder = CreateFrame("Frame", nil, parent)
	local bg = holder:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	gradient(bg, C.ctrlTop, C.ctrlBottom)
	border(holder, C.ctrlEdge)
	local summary = text(holder, "GameFontHighlight", 1.05, C.subLabel)
	summary:SetJustifyH("LEFT")
	summary:SetWordWrap(true)
	local rows, list, signature, busy = {}, {}, nil, false
	local cleanup
	-- a button that asks once more before it acts: label, the "sure?" label, and what it does
	local function confirming(button, label, sureLabel, act)
		local token = 0
		local function reset()
			token = token + 1
			button.qtsSure = false
			button:SetText(label)
			if rawget(button, "qtsText") then button.qtsText:SetText(label) end
			fitButton(button)
		end
		button.qtsReset = reset
		button.qtsLabel = function(newLabel, newSure) label, sureLabel = newLabel, newSure or sureLabel; reset() end
		button:SetScript("OnClick", function()
			if button.qtsSure then reset(); act() return end
			button.qtsSure = true
			button:SetText(sureLabel)
			if rawget(button, "qtsText") then button.qtsText:SetText(sureLabel) end
			fitButton(button)
			token = token + 1
			local mine = token
			C_Timer.After(CONFIRM_SECONDS, function() if token == mine and button.qtsSure then reset() end end)
		end)
		reset()
	end
	local function finished()
		busy = false
		signature = nil
		item.refresh()
		if api.refreshConfig then api.refreshConfig() end
	end
	local function hoverOff(row)
		if row:IsMouseOver() then return end
		row.hl:Hide()
		if not row.abandon.qtsSure then row.abandon:Hide() end
	end
	local function row(i)
		local r = rows[i]
		if r then return r end
		r = CreateFrame("Frame", nil, holder)
		r:EnableMouse(true)
		r.hl = solid(r, "BACKGROUND", C.thumb, 0.14)
		r.hl:SetAllPoints()
		r.hl:Hide()
		r.zone = text(r, "GameFontHighlight", 1.05, C.subLabel)
		r.zone:SetJustifyH("LEFT")
		r.zone:SetWordWrap(false)
		r.label = text(r, "GameFontHighlight", 1.05, C.value)
		r.label:SetJustifyH("LEFT")
		r.label:SetWordWrap(false)
		r.abandon = makeButton(r, "Abandon", 80, function() end)
		r.abandon:SetHeight(20)
		r.abandon:Hide()
		confirming(r.abandon, "Abandon", "Sure? Click again", function()
			if busy or not r.questID then return end
			busy = true
			g.abandonOrphans({ r.questID }, finished)
		end)
		r:SetScript("OnEnter", function() r.hl:Show(); r.abandon:Show() end)
		r:SetScript("OnLeave", function() hoverOff(r) end)
		r.abandon:HookScript("OnLeave", function() C_Timer.After(0, function() hoverOff(r) end) end)
		r.abandon:HookScript("OnHide", function() if r.abandon.qtsSure then r.abandon.qtsReset() end end)
		rows[i] = r
		return r
	end
	local function arrange()
		local k = ts()
		local width = holder:GetWidth() or 300
		local y = 10
		summary:ClearAllPoints()
		summary:SetPoint("TOPLEFT", holder, "TOPLEFT", 12, -y)
		summary:SetWidth(math.max(width - 24, 40))
		summary:SetHeight(0)
		y = y + math.max(summary:GetStringHeight() or 0, 13 * k) + 8
		local h = math.floor(22 * k + 0.5)
		for i, q in ipairs(list) do
			local r = rows[i]
			r:ClearAllPoints()
			r:SetPoint("TOPLEFT", holder, "TOPLEFT", 6, -y)
			r:SetSize(math.max(width - 12, 40), h)
			r.abandon:ClearAllPoints()
			r.abandon:SetPoint("RIGHT", r, "RIGHT", -4, 0)
			-- the zone in a column on the left, the quest after it
			local zoneW = math.floor(math.min(math.max(width * 0.3, 110 * k), 190 * k) + 0.5)
			r.zone:ClearAllPoints()
			r.zone:SetPoint("LEFT", r, "LEFT", 8, 0)
			r.zone:SetWidth(zoneW)
			r.label:ClearAllPoints()
			r.label:SetPoint("LEFT", r, "LEFT", 8 + zoneW + 8, 0)
			r.label:SetPoint("RIGHT", r, "RIGHT", -96 * k, 0)
			y = y + h + 2
		end
		if cleanup then
			cleanup:ClearAllPoints()
			cleanup:SetPoint("TOPLEFT", holder, "TOPLEFT", 12, -(y + 4))
			if #list > 0 then y = y + 34 end
		end
		return y + 6
	end
	cleanup = makeButton(holder, "Cleanup orphaned quests", 190, function() end)
	confirming(cleanup, "Cleanup orphaned quests", "Abandon them all? Click again", function()
		if busy or #list == 0 then return end
		local ids = {}
		for _, q in ipairs(list) do ids[#ids + 1] = q.questID end
		busy = true
		g.abandonOrphans(ids, function(count)
			local say = root.objectives and root.objectives.say
			if say then say(("cleanup: %d orphaned quest%s abandoned."):format(count, count == 1 and "" or "s")) end
			finished()
		end)
	end)
	item.refresh = function()
		local addon = root.objectives and root.objectives.rxp
		local guide = addon and addon.currentGuide
		local now = (g and g.orphans and guide) and g.orphans() or {}
		-- sorted as chosen above the list: difficulty (level, low first), name, or zone; optionally reversed
		local db = ns.db or {}
		local by, reverse = db.orphanSort or "level", db.orphanReverse and true or false
		local function lower(v) return tostring(v or ""):lower() end
		local function before(x, y)
			local lx, ly = tonumber(x.level) or 0, tonumber(y.level) or 0
			local nx, ny = lower(x.title), lower(y.title)
			if by == "zone" then
				local zx, zy = lower(x.zone), lower(y.zone)
				if zx ~= zy then return zx < zy end
			elseif by == "name" then
				if nx ~= ny then return nx < ny end
			end
			if lx ~= ly then return lx < ly end
			if nx ~= ny then return nx < ny end
			return (x.questID or 0) < (y.questID or 0)
		end
		table.sort(now, function(x, y) if reverse then return before(y, x) end return before(x, y) end)
		local keys = {}
		for _, q in ipairs(now) do keys[#keys + 1] = q.questID end
		-- your level too: the difficulty colours change when you level up
		local sig = (guide and tostring(guide.key or guide.name) or "-") .. ":" .. table.concat(keys, ",") .. "@"
			.. tostring(UnitLevel and UnitLevel("player") or "") .. "/" .. by .. (reverse and "-" or "+")
		if sig == signature then return end
		signature = sig
		list = now
		if not guide then
			summary:SetText("Load a RestedXP guide to find orphaned quests.")
		elseif #list == 0 then
			summary:SetText("No orphaned quests: every unfinished quest in your log is part of " .. tostring(guide.name or "this guide") .. ".")
		else
			summary:SetText(("%d quest%s in your log %s not part of %s. Hover a quest to abandon just that one."):format(#list,
				#list == 1 and "" or "s", #list == 1 and "is" or "are", tostring(guide.name or "this guide")))
		end
		for i, q in ipairs(list) do
			local r = row(i)
			r.questID = q.questID
			r.zone:SetText(q.zone or "-")
			r.label:SetText((q.level and ("[%d] "):format(q.level) or "") .. q.title)
			local c = questDifficultyColor(q.level)
			r.label:SetTextColor(c[1], c[2], c[3])
			r:Show()
		end
		for i = #list + 1, #rows do rows[i].questID = nil; rows[i]:Hide() end
		cleanup.qtsLabel(("Cleanup orphaned quests (%d)"):format(#list), ("Abandon all %d? Click again"):format(#list))
		cleanup:SetShown(#list > 0 and holder:IsShown())
		holder:SetHeight(arrange())
	end
	item.setEnabled = function() end
	item.place = function(x, y, w)
		holder:ClearAllPoints()
		holder:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
		holder:SetWidth(w - 8)
		holder:SetHeight(arrange())
		item.height = holder:GetHeight() + 10
	end
	item.setShown = function(on)
		holder:SetShown(on)
		if cleanup then cleanup:SetShown(on and #list > 0) end
	end
	item.frame = holder
end

---------------------------------------------------------------------------------------------------------------------
-- Layout: the open page, or every matching setting while searching (under its page's name)
---------------------------------------------------------------------------------------------------------------------
local function matches(item, query)
	return query == "" or (item.label or ""):lower():find(query, 1, true) ~= nil
end

local nav = {} -- page key -> sidebar button
local sidebarFrame
local layout
local function query()
	return (searchBox and searchBox:GetText() or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
end

layout = function()
	if not frame or not content then return end
	local q = query()
	local width = math.max((scroll:GetWidth() or 400) - 6, 200)
	local y = 0
	-- hide only what leaves the view (hiding a shown picker would close its open list)
	local visible = {}
	if q == "" then
		for _, item in ipairs(items) do
			if item.page == activePage and not item.pageHead then visible[item] = true end
		end
	else
		for _, p in ipairs(pages) do
			local any = false
			for _, item in ipairs(items) do
				if item.page == p.key and not item.pageHead and item.kind ~= "heading" and
					(matches(item, q) or p.title:lower():find(q, 1, true)) then
					visible[item] = true
					any = true
				end
			end
			if any then visible[p.headItem] = true end
		end
	end
	for _, item in ipairs(items) do if not visible[item] then item.setShown(false) end end
	if q == "" then
		local p = pageByKey[activePage]
		pageTitle:SetText(p and p.title or "")
		for _, item in ipairs(items) do
			if visible[item] then
				item.setShown(true)
				item.place(0, y, width)
				y = y + item.height
			end
		end
	else
		pageTitle:SetText("Search results")
		for _, p in ipairs(pages) do
			local list = {}
			for _, item in ipairs(items) do
				if item.page == p.key and not item.pageHead and visible[item] then list[#list + 1] = item end
			end
			if #list > 0 then
				local head = p.headItem
				head.setShown(true)
				head.place(0, y, width)
				y = y + head.height
				for _, item in ipairs(list) do
					item.setShown(true)
					item.place(0, y, width)
					y = y + item.height
				end
			end
		end
		if y == 0 then pageTitle:SetText("No settings match") end
	end
	content:SetSize(width, math.max(y + 8, 10))
	local range = math.max(y - scroll:GetHeight(), 0)
	if scrollbar and scrollbar.qtsOwn then
		scrollbar:SetMinMaxValues(0, range)
		scrollbar:SetShown(range > 0)
	elseif scroll.UpdateScrollChildRect then
		scroll:UpdateScrollChildRect()
	end
	-- no scrollbar on a page with nothing to scroll
	if scrollbar and scrollbar.SetShown then scrollbar:SetShown(range > 0.5) end
	if scroll:GetVerticalScroll() > range then scroll:SetVerticalScroll(range) end
	-- "Defaults" resets the settings the open page shows (pageKeys)
	local p = pageByKey[activePage]
	if defaultsButton then defaultsButton:SetShown(q == "" and p ~= nil and p.reset ~= nil) end
end

local layoutPending
local function scheduleLayout()
	if layoutPending then return end
	layoutPending = true
	C_Timer.After(0, function() layoutPending = nil; layout() end)
end

---------------------------------------------------------------------------------------------------------------------
-- Settings
---------------------------------------------------------------------------------------------------------------------
-- "Track": the tracking modes, plus "Only quests in my zone" (all quests by zone, other zones hidden)
local TRACK_OPTIONS = {
	{ "game", "Game default" },
	{ "all", "All quests" },
	{ "allzones", "All quests, with zone headers" },
	{ "myzone", "Only quests in my zone" },
	{ "manual", "Manually tracked" },
	{ "manualzones", "Manually tracked, with zone headers" },
}
local function trackGet(db)
	if db.zoneFilter then return "myzone" end
	if api.modeIs("all", true) then return "allzones" end
	if api.modeIs("all", false) then return "all" end
	if api.modeIs("manual", true) then return "manualzones" end
	if api.modeIs("manual", false) then return "manual" end
	return "game"
end
local function trackSet(db, v)
	if v == "myzone" then
		api.setMode("all", true)
		if api.setZoneFilter then api.setZoneFilter(true) end
		return
	end
	if db.zoneFilter and api.setZoneFilter then api.setZoneFilter(false) end
	if v == "all" then api.setMode("all", false)
	elseif v == "allzones" then api.setMode("all", true)
	elseif v == "manual" then api.setMode("manual", false)
	elseif v == "manualzones" then api.setMode("manual", true)
	else api.setMode(nil, false) end
end

-- Which saved settings a page shows: each of its controls is read once while the two settings tables record the names
-- read (their values sit aside for that moment and go straight back), so the page's Defaults resets only those.
local questDb
local function recordReads(tbl, fn)
	if type(tbl) ~= "table" then fn() return {} end
	local values, seen, meta = {}, {}, getmetatable(tbl)
	for k, v in pairs(tbl) do values[k] = v end
	for k in pairs(values) do tbl[k] = nil end
	setmetatable(tbl, {
		__index = function(_, k) seen[k] = true return values[k] end,
		__newindex = function(_, k, v) values[k] = v end,
	})
	local ok = pcall(fn)
	setmetatable(tbl, meta)
	for k, v in pairs(values) do tbl[k] = v end
	return seen, ok
end
local function pageKeys(key)
	local guideDb = root.objectives and root.objectives.db
	local questKeys, guideKeys = {}, {}
	questKeys = recordReads(questDb, function()
		guideKeys = recordReads(guideDb, function()
			for _, item in ipairs(declared) do
				if item.page == key and type(item.get) == "function" then pcall(item.get) end
			end
		end)
	end)
	return questKeys, guideKeys
end
api.pageKeys = pageKeys

local function declareItems(db)
	questDb = db
	wipe(pages); wipe(pageByKey)
	local resetQuests = function() api.resetDefaults() end

	-- Quest Tracker ------------------------------------------------------------------------------------------------
	page("questlist", "quests", "Quest list")
	check("Lock tracker position", function() return db.locked end, function(v) api.setLocked(v) end,
		nil, nil, "unlocked shows a drag bar")
	slider("Extra length", 0, 1500, 1, function(v) return v == 0 and "Auto" or ("%d px"):format(v) end,
		function() return db.height end, function(v) db.height = v; api.applyLayout() end)
	note("Extra length sets how tall the quest list is; 0 is automatic.")
	check("Show scrollbar", function() return db.scrollbar end, function(v) api.setScrollbarShown(v) end)
	check("Only on mouseover", function() return db.scrollbarMouseover end,
		function(v) api.setScrollbarMouseover(v) end, function() return db.scrollbar end, 24)
	color("Scrollbar colour", function() return db.scrollbarColor or { 0.2, 0.85, 0.55 } end,
		function(v) db.scrollbarColor = v; if api.applyScrollbarColor then api.applyScrollbarColor() end end,
		function() return db.scrollbar end, 24, 0.85)
	slider("Scrollbar width", 2, 30, 1, "%d px", function() return db.scrollbarWidth or 10 end,
		function(v) if api.setScrollbarWidth then api.setScrollbarWidth(v) end end, function() return db.scrollbar end, 24)
	check("Usable quest items on the left", function() return db.itemsLeft ~= false end, function(v) api.setItemsLeft(v) end)
	-- the "31/40" quest count on the "Quests" header (MoreQuests.lua updateQuestCount)
	local function countChanged() if api.updateQuestCount then pcall(api.updateQuestCount) end end
	local function countOn() return db.questCount ~= false end
	check("Quest count on the header (N/40)", countOn, function(v) db.questCount = v and true or false; countChanged() end)
	slider("Quest count size", 0, 24, 1, function(v) return v == 0 and "Header's" or ("%d px"):format(v) end,
		function() return db.questCountSize or 0 end, function(v) db.questCountSize = v; countChanged() end, countOn, 24)
	check("Custom quest count colour", function() return db.questCountCustom end,
		function(v) db.questCountCustom = v and true or false; countChanged() end, countOn, 24,
		"replaces the green / yellow / orange / red warning of how full your quest log is")
	-- its opacity always applies; its colour only with the custom colour on
	color("Quest count colour and opacity", function() return db.questCountColor or { 1, 1, 1, 1 } end,
		function(v) db.questCountColor = v; countChanged() end, countOn, 24, 1)
	-- the "Quests" header's own colours (Extras.lua applyQuestsHeaderLook)
	local function headerLook()
		if api.applyQuestsHeaderLook then
			local ok, err = pcall(api.applyQuestsHeaderLook)
			if not ok then geterrorhandler()(err) end
		end
	end
	color("\"Quests\" header and collapse button", function()
		return type(db.questsHeaderColor) == "table" and db.questsHeaderColor or { 1, 0.82, 0, 1 }
	end, function(v) db.questsHeaderColor = v; headerLook() end, nil, nil, 1)
	color("Line under \"Quests\" header", function()
		return type(db.questsLineColor) == "table" and db.questsLineColor or { 1, 1, 1, 1 }
	end, function(v) db.questsLineColor = v; headerLook() end, nil, nil, 1)
	buttons("Game's header colours", {
		{ "Game's header colours", function() db.questsHeaderColor, db.questsLineColor = false, false; headerLook() end, 170 },
	})
	slider("\"Quests\" header padding", -50, 40, 1, "%+d px", function() return db.questsPadY or 0 end,
		function(v) db.questsPadY = v; if api.applyQuestsPad then api.applyQuestsPad() end end)
	slider("Scroll speed", 10, 200, 1, "%d px", function() return db.step end, function(v) db.step = v end)
	buttons("Reset position Scroll to top", {
		{ "Reset position", function() api.resetPosition() end, 120 },
		{ "Scroll to top", function() SlashCmdList.ALLTRACKERRXP("reset") end, 120 },
	})
	pageByKey.questlist.reset = resetQuests

	page("zoneheaders", "quests", "Zone headers")
	local sortOn = function() return db.zoneSort end
	note("Zone headers show when Track (Tracking and sorting) is set to a choice with zone headers.")
	check("Outline the zone header text", function() return db.zoneHeaderOutline end,
		function(v) db.zoneHeaderOutline = v; if api.applyZoneHeaders then api.applyZoneHeaders() end end, sortOn)
	color("Zone header colour", function() return db.zoneHeaderColor or { 0.2, 0.85, 0.55 } end,
		function(v) db.zoneHeaderColor = v; if api.applyZoneHeaders then api.applyZoneHeaders() end end, sortOn)
	slider("Space above zone headers", -30, 40, 1, "%d px", function() return db.zoneHeaderPadY or 6 end,
		function(v) db.zoneHeaderPadY = v; if api.applyZoneHeaders then api.applyZoneHeaders() end end, sortOn)
	percent("Zone header size", 70, 200, function() return db.zoneHeaderScale end,
		function(v) db.zoneHeaderScale = v; if api.applyZoneHeaders then api.applyZoneHeaders() end end, sortOn)
	slider("Zone header horizontal position", -20, 150, 1, "%+d px", function() return db.zoneHeaderX end,
		function(v) db.zoneHeaderX = v; if api.applyZoneHeaders then api.applyZoneHeaders() end end, sortOn)
	-- moves the header text only; "Space above zone headers" makes room for it
	slider("Zone header vertical position", -20, 40, 1, "%+d px", function() return db.zoneHeaderY or 0 end,
		function(v) db.zoneHeaderY = v; if api.applyZoneHeaders then api.applyZoneHeaders() end end, sortOn)
	pageByKey.zoneheaders.reset = resetQuests

	page("titles", "quests", "Quest titles")
	check("Word wrap titles and objectives", function() return db.wordWrap end,
		function(v) db.wordWrap = v; if api.applyWrap then api.applyWrap() end end)
	check("Experience reward after titles", function() return db.showXP end, function(v) api.setReward("xp", v) end)
	color("Experience colour", function() return db.xpColor or { 0.69, 0.53, 1 } end,
		function(v) db.xpColor = v; if api.applyExtras then api.applyExtras() end end, function() return db.showXP end, 24)
	check("Show xp orb", function() return db.xpOrb end,
		function(v) db.xpOrb = v; if api.applyExtras then api.applyExtras() end end, function() return db.showXP end, 24)
	check("Gold reward after titles", function() return db.showGold end, function(v) api.setReward("gold", v) end)
	check("Show coins instead", function() return db.goldCoins end,
		function(v) db.goldCoins = v; if api.applyExtras then api.applyExtras() end end, function() return db.showGold end, 24)
	-- the green check left of a finished quest's title (Extras.lua placeCheck)
	local function checksOn() return db.completeCheck ~= false end
	check("Checks on finished quests", checksOn,
		function(v) db.completeCheck = v; if api.applyExtras then api.applyExtras() end
			if api.rebuildMoreQuests then api.rebuildMoreQuests() end end, nil, nil, "a green tick left of the title")
	percent("Check scale", 50, 250, function() return db.completeCheckScale or 1 end,
		function(v) db.completeCheckScale = v; if api.applyExtras then api.applyExtras() end
			if api.rebuildMoreQuests then api.rebuildMoreQuests() end end, checksOn, 24)
	local function applyChecks()
		if api.applyExtras then api.applyExtras() end
		if api.rebuildMoreQuests then api.rebuildMoreQuests() end
	end
	color("Check colour and opacity", function()
		if api.checkColor then local r, g, b, a = api.checkColor(); return { r, g, b, a } end
		return { 0.27, 0.87, 0.47, 1 }
	end, function(v) db.completeCheckColor = v; applyChecks() end, checksOn, 24, 1)
	check("Outline the check", function() return db.completeCheckOutline end,
		function(v) db.completeCheckOutline = v; applyChecks() end, checksOn, 24, "a thin dark edge, as the zone header outline")
	check("Icons on Elite+ quests", function() return db.condense end,
		function(v) db.condense = v; if api.applyExtras then api.applyExtras() end end, nil, nil,
		"elite, group, dungeon, raid, PvP")
	if api.questieLoaded and api.questieLoaded() then -- raid attunement quests, from Questie's quest chains
		check("Star on raid attunement quests", function() return db.attunementStar ~= false end,
			function(v) db.attunementStar = v; if api.applyExtras then api.applyExtras() end
				if api.rebuildMoreQuests then api.rebuildMoreQuests() end end,
			function() return db.condense and db.questie ~= false end, 24, "from Questie")
	end
	percent("Icon size", 50, 250, function() return db.iconScale or 1 end,
		function(v) db.iconScale = v; if api.applyExtras then api.applyExtras() end end,
		function() return db.condense end, 24)
	percent("Icon opacity", 10, 100, function() return db.iconAlpha or 1 end,
		function(v) db.iconAlpha = v; if api.applyExtras then api.applyExtras() end
			if api.rebuildMoreQuests then api.rebuildMoreQuests() end end,
		function() return db.condense end, 24)
	slider("Spacing between quests", -10, 30, 1, "%+d px", function() return db.spacing end,
		function(v) db.spacing = v; if api.applyExtras then api.applyExtras() end end)
	slider("Quest titles horizontal position", -20, 150, 1, "%+d px", function() return db.questTitleX or 0 end,
		function(v) db.questTitleX = v; if api.applyExtras then api.applyExtras() end
			if api.applyZoneHeaders then api.applyZoneHeaders() end end)
	pageByKey.titles.reset = resetQuests

	page("tooltips", "quests", "Tooltips")
	check("Tooltips on quests", function() return db.tooltips end, function(v) db.tooltips = v end, nil, nil,
		"overview, gold, rewards")
	check("Show party progress", function() return db.partyProgress ~= false end, function(v) db.partyProgress = v end,
		function() return db.tooltips end, 24)
	check("Coin icons instead of g, s, c", function() return db.tooltipCoins end, function(v) db.tooltipCoins = v end,
		function() return db.tooltips end, 24)
	check("Experience orb instead of \"experience\"", function() return db.tooltipXpOrb end,
		function(v) db.tooltipXpOrb = v end, function() return db.tooltips end, 24)
	if api.questieLoaded and api.questieLoaded() then -- only with Questie installed and enabled
		heading("Questie")
		check("Use Questie data", function() return db.questie ~= false end,
			function(v) db.questie = v; if api.applyQuestie then api.applyQuestie() end end, nil, nil,
			"quest giver, turn-in, objective locations, chains, closest-quest sorting")
		local questieTips = function() return db.tooltips and db.questie ~= false end
		check("Follow-up quest and chain", function() return db.questieChain ~= false end,
			function(v) db.questieChain = v end, questieTips, 24, "hold Ctrl on the tooltip for the whole chain")
		check("Chain's final reward and totals", function() return db.questieChainReward end,
			function(v) db.questieChainReward = v end,
			function() return questieTips() and db.questieChain ~= false end, 48)
		check("What finishing the quest or its chain unlocks", function() return db.questieUnlocks ~= false end,
			function(v) db.questieUnlocks = v end, questieTips, 24, "hold Ctrl: the quests it opens, and new chains")
	end
	pageByKey.tooltips.reset = resetQuests

	page("tracking", "quests", "Tracking and sorting")
	choice("Track", function() return TRACK_OPTIONS end, function() return trackGet(db) end,
		function(v) trackSet(db, v) end)
	choice("Sort zones", function()
		return { { "closest", "Closest quest first" }, { "alpha", "Alphabetical (A to Z)" } }
	end, function() return db.zoneOrder or "closest" end,
		function(v) if api.setZoneOrder then api.setZoneOrder(v) end end, function() return db.zoneSort end)
	check("List quests past the tracking limit", function() return db.moreQuests ~= false end,
		function(v) db.moreQuests = v; if api.rebuildMoreQuests then api.rebuildMoreQuests() end end,
		function() return db.trackMode == "all" end)
	pageByKey.tracking.reset = resetQuests
	-- Zone headers: greyed while Track has no zone headers (still opens)
	pageByKey.zoneheaders.dimmed = function() return not db.zoneSort end

	-- RXP Tracker: every /rt option and command (Objectives/Settings.lua) ----------------------------------------
	local g = root.objectives.settings
	if not g then
		page("guidetracker", "guide", "Tracker settings")
		note(root.standaloneObjectives
			and "The separate AllObjectives RXP addon is running, so its settings are not shown here. Disable that addon in the AddOns list and /reload to use the built-in RXP Tracker."
			or "RestedXP Guides is not available, so the guide settings cannot be shown.")
	else
		local resetGuide = function() g.reset() end
		local function arrowOn() return g.get("arrowButton") end
		page("guidetracker", "guide", "Tracker settings")
		check("Show RestedXP steps in the tracker", function() return g.get("enabled") end,
			function(v) g.setEnabled(v) end, nil, nil, "off brings back RestedXP's own windows")
		check("Own window", function() return db.guideDetached end,
			function(v) if api.setGuideDetached then api.setGuideDetached(v) end end,
			function() return g.get("enabled") end, 24, "out of the quest tracker; drag its bar to move it")
		buttons("Window position", {
			{ "Reset window position", function() if api.resetGuideWindow then api.resetGuideWindow() end end, 170 },
		}, function() return db.guideDetached and g.get("enabled") end)
		-- one past the top number is "All"
		local allSteps = g.allSteps or g.maxSteps
		local function stepsFormat(v) return v >= allSteps and "All" or ("%d"):format(v) end
		slider("Steps shown ahead", 0, allSteps, 1, stepsFormat,
			function() return g.get("followingSteps") end, function(v) g.setSteps(v) end)
		slider("Steps shown at once", 1, allSteps, 1, stepsFormat, function() return g.get("upcomingShown") or 2 end,
			function(v) g.setUpcoming("upcomingShown", v) end)
		-- the "N/M" step counter in the header (Header.lua)
		local function countOn() return g.get("stepCountShown") ~= false end
		check("Step counter (N/total)", countOn, function(v) g.setUpcoming("stepCountShown", v and true or false) end,
			nil, nil, "in the RXP Tracker's header (Forever Style)")
		slider("Step counter size", 0, 24, 1, function(v) return v == 0 and "Header's" or ("%d px"):format(v) end,
			function() return g.get("stepCountSize") or 0 end, function(v) g.setUpcoming("stepCountSize", v) end, countOn, 24)
		check("Custom step counter colour", function() return type(g.get("stepCountColor")) == "table" end,
			function(v) g.setUpcoming("stepCountColor", v and { 0.85, 0.85, 0.85, 1 } or false) end, countOn, 24)
		color("Step counter colour", function()
			local c = g.get("stepCountColor")
			return type(c) == "table" and c or { 0.85, 0.85, 0.85, 1 }
		end, function(v) g.setUpcoming("stepCountColor", v) end,
			function() return countOn() and type(g.get("stepCountColor")) == "table" end, 48, 1)
		-- size and place of each group of steps (Rows.lua groupLook)
		local R = g.RANGES or {}
		local function lookSliders(prefix, name)
			local scaleR, xR, yR = R[prefix .. "Scale"] or { 0.5, 2 }, R[prefix .. "X"] or { -60, 120 }, R[prefix .. "Y"] or { -40, 60 }
			slider(name .. " scale", scaleR[1] * 100, scaleR[2] * 100, 5, "%d%%",
				function() return math.floor((g.get(prefix .. "Scale") or 1) * 100 + 0.5) end,
				function(v) g.setUpcoming(prefix .. "Scale", v / 100) end)
			slider(name .. " horizontal position", xR[1], xR[2], 1, "%+d px", function() return g.get(prefix .. "X") or 0 end,
				function(v) g.setUpcoming(prefix .. "X", v) end)
			slider(name .. " vertical position", yR[1], yR[2], 1, "%+d px", function() return g.get(prefix .. "Y") or 0 end,
				function(v) g.setUpcoming(prefix .. "Y", v) end)
		end
		heading("Current step(s)")
		lookSliders("current", "Current step")
		-- upcoming steps scroll (Rows.lua): this many at once, the mouse wheel over them shows the rest
		heading("Upcoming steps")
		lookSliders("upcoming", "Upcoming steps")
		check("Scrollbar", function() return g.get("upcomingScrollbar") ~= false end,
			function(v) g.setUpcoming("upcomingScrollbar", v) end, nil, nil, "beside the upcoming steps when there are more to scroll")
		check("Only on mouseover", function() return g.get("upcomingScrollbarMouseover") end,
			function(v) g.setUpcoming("upcomingScrollbarMouseover", v) end,
			function() return g.get("upcomingScrollbar") ~= false end, 24)
		color("Scrollbar colour", function() return g.get("upcomingScrollbarColor") or { 0.2, 0.85, 0.55, 0.85 } end,
			function(v) g.setUpcoming("upcomingScrollbarColor", v) end,
			function() return g.get("upcomingScrollbar") ~= false end, 24, 0.85)
		slider("Scrollbar width", 1, 12, 1, "%d px", function() return g.get("upcomingScrollbarWidth") or 3 end,
			function(v) g.setUpcoming("upcomingScrollbarWidth", v) end,
			function() return g.get("upcomingScrollbar") ~= false end, 24)
		note("Scroll the mouse wheel over the upcoming steps to see the rest.")
		note("Step buttons: Ctrl+drag to move them, Ctrl+right-drag to resize them (out of combat). Prerequisite Journal: the book icon before the guide name, or Ctrl+right-click the RXP Tracker.")
		buttons("Reset step buttons", {
			{ "Reset step buttons", function() g.resetCircles() end, 170 },
		})
		pageByKey.guidetracker.reset = resetGuide

		page("arrow", "guide", "Waypoint arrow")
		check("Use RestedXP's arrow as the objective button", arrowOn, function(v) g.setFlag("arrowButton", v) end)
		check("Small objective buttons around the arrow", function() return g.get("arrowSatellites") end,
			function(v) g.setFlag("arrowSatellites", v) end, arrowOn, 24)
		check("Collapse two or more into one +N badge", function() return g.get("arrowCollapse") end,
			function(v) g.setFlag("arrowCollapse", v) end, function() return arrowOn() and g.get("arrowSatellites") end, 48,
			"opens on hover")
		if g.setArrowScale then
			slider("Arrow scale", 20, 200, 5, "%d%%", function() return math.floor(g.getArrowScale() * 100 + 0.5) end,
				function(v) g.setArrowScale(v / 100) end)
		end
		-- colour of the arrow's body (the theme's when not chosen) and its opacity
		check("Custom arrow colour", function() return type(g.get("arrowColor")) == "table" end,
			function(v) g.setUpcoming("arrowColor", v and { 0.45, 0.55, 0.62, 1 } or false) end)
		color("Arrow colour", function()
			local c = g.get("arrowColor")
			return type(c) == "table" and c or { 0.45, 0.55, 0.62, 1 }
		end, function(v) g.setUpcoming("arrowColor", v) end, function() return type(g.get("arrowColor")) == "table" end, 24)
		slider("Arrow opacity", 10, 100, 5, "%d%%", function() return math.floor((g.get("arrowAlpha") or 1) * 100 + 0.5) end,
			function(v) g.setUpcoming("arrowAlpha", v / 100) end)
		check("Lock the arrow in place", function() return g.get("arrowLocked") or g.lockedByRestedXP() end,
			function(v) g.setFlag("arrowLocked", v) end, function() return arrowOn() and not g.lockedByRestedXP() end)
		pageByKey.arrow.reset = resetGuide

		page("guide", "guide", "Themes & guide")
		choice("Theme", function()
			return { { "forever", "Forever Style (default)" }, { "rxp", "RXP Style" } }
		end, function() return g.get("theme") == "rxp" and "rxp" or "forever" end, function(v) g.setTheme(v) end)
		statusBox("Guide status", function()
			local s = g.status()
			local progress
			if s.counter then
				progress = s.counter .. ", " .. s.active .. " active, " .. s.ahead .. " ahead"
			elseif not s.enabled then
				progress = "Turn on \"Show RestedXP steps\" to show them."
			elseif not s.guide then
				progress = "No RestedXP guide loaded."
			else
				progress = "No steps left to show."
			end
			return {
				{ "Status", s.enabled and "on, steps shown in the tracker" or "off, RestedXP's own windows shown",
					s.enabled and { 0.2, 1, 0.6 } or { 1, 0.5, 0.25 } },
				{ "Guide", s.guide or "none" },
				{ "Progress", progress },
				{ "Arrow", s.arrow },
			}
		end)
		if StaticPopupDialogs and not StaticPopupDialogs.RXPFOREVERTRACKER_RESET_PROGRESS then
			StaticPopupDialogs.RXPFOREVERTRACKER_RESET_PROGRESS = {
				text = "Clear your place in every RestedXP guide for this character? Each guide will start from its first step.",
				button1 = YES, button2 = NO, timeout = 0, whileDead = true, hideOnEscape = true,
				OnAccept = function() g.resetAllProgress() end,
			}
		end
		local row = {
			{ "Choose a guide...", function() g.showWelcome() end, 150 },
			{ "Print status to chat", function() g.printStatus() end, 160 },
		}
		if g.restartGuide then
			row[#row + 1] = { "Restart this guide", function() g.restartGuide() end, 150 }
			row[#row + 1] = { "Reset all guides", function() if StaticPopup_Show then StaticPopup_Show("RXPFOREVERTRACKER_RESET_PROGRESS") end end, 140 }
		end
		buttons("Choose a guide Print status to chat Restart this guide Reset all guides", row)
		if g.restartGuide then
			note("RestedXP returns to your saved place whenever a guide loads, so a guide that once ran to its end opens at its end again. Restart it here, or reset every guide.")
		end
		pageByKey.guide.reset = resetGuide
		-- its own page under Themes & guide: how the list is sorted, then the list
		if g.orphansAvailable and g.orphansAvailable() then
			page("orphans", "guide", "Orphaned quests")
			note("The same list as RestedXP's \"Cleanup Orphaned Quests\": quests in your log that the current guide does not use and no later guide turns in. Finished quests are never listed. Abandoning cannot be undone.")
			choice("Sort by", function()
				return { { "level", "Difficulty (level)" }, { "name", "Name (A-Z)" }, { "zone", "Zone (A-Z)" } }
			end, function() return db.orphanSort or "level" end, function(v) db.orphanSort = v; api.refreshConfig() end)
			check("Reverse the order", function() return db.orphanReverse and true or false end,
				function(v) db.orphanReverse = v and true or false; api.refreshConfig() end)
			declare({ kind = "orphans", label = "Orphaned quests abandon cleanup", full = true })
			pageByKey.orphans.reset = resetQuests
		end
	end

	-- Settings window ------------------------------------------------------------------------------------------------
	-- RXP Tracker pages: greyed when RestedXP Guides is not installed and loaded (they still open)
	local function noRestedXP()
		return not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("RXPGuides"))
	end
	for _, p in ipairs(pages) do
		if p.group == "guide" then p.dimmed = noRestedXP end
	end

	page("text", "window", "Text and font")
	-- applied when the thumb is released (it resizes this very slider: live it jumped under the cursor)
	percent("Text size", TEXT_MIN * 100, TEXT_MAX * 100, function() return ts() end,
		function(v)
			if db.configTextSize == v then return end
			db.configTextSize = v; applyFonts()
			if frame and frame.qtsFitText then frame.qtsFitText() end
			if sidebarFrame then sidebarFrame.arrange() end
			if frame and frame.qtsArrangeOpacity then frame.qtsArrangeOpacity() end
			scheduleLayout()
		end, nil, nil, true)
	-- one font for the quest tracker, the RXP Tracker and this window (Fonts.lua)
	choice("Font", function() return api.fontOptions() end,
		function() return db.font or "default" end, function(v) api.setFont(v); scheduleLayout() end, nil, nil, true)
	note("The font is used by the quest tracker, the RXP Tracker and this window.")
	pageByKey.text.reset = resetQuests

	page("sizing", "window", "Advanced")
	percent("General scale", 50, 150, function() return db.scale end, function(v) db.scale = v; api.applyScale() end)
	-- both multiply the general scale (100% = same size as the general scale)
	percent("RXP Tracker scale", 50, 150, function() return db.guideScale or 1 end,
		function(v) db.guideScale = v; api.applyGuideScale() end, nil, 24)
	percent("Quest Tracker scale", 50, 150, function() return db.questScale or 1 end,
		function(v) db.questScale = v; api.applyQuestScale() end, nil, 24)
	slider("General opacity", 10, 100, 5, "%d%%", function() return math.floor((db.trackerAlpha or 1) * 100 + 0.5) end,
		function(v) if api.setTrackerAlpha then api.setTrackerAlpha(v / 100, "trackerAlpha") end end)
	-- both multiply the general opacity (100% = the general opacity), as the two scales do
	slider("RXP Tracker opacity", 10, 100, 5, "%d%%", function() return math.floor((db.guideAlpha or 1) * 100 + 0.5) end,
		function(v) if api.setTrackerAlpha then api.setTrackerAlpha(v / 100, "guideAlpha") end end, nil, 24)
	slider("Quest Tracker opacity", 10, 100, 5, "%d%%", function() return math.floor((db.questAlpha or 1) * 100 + 0.5) end,
		function(v) if api.setTrackerAlpha then api.setTrackerAlpha(v / 100, "questAlpha") end end, nil, 24)
	slider("Extra width", 0, 300, 1, "+%d px", function() return db.widthExtra end,
		function(v) db.widthExtra = v; api.applyWidth() end)
	note("Extra width widens the tracker's frame. |cffff5a3cTo make text bigger or smaller use the scale sliders above (and the RXP Tracker's step scales in Tracker settings) instead, and turn on \"Word wrap titles and objectives\" (Quest titles) so long quest text wraps instead of being cut off.|r")
	-- last on the page: it changes how the tracker stacks with every other window
	heading("Layer")
	note("|cffff5a3cWarning: only change this if you know what you're doing.|r It sets which windows the tracker draws above or below; a wrong value can hide the tracker behind other frames or put it over windows you need. 1-25 behind the minimap, 51-75 normal, 76 and up on top. The Defaults button on this page puts it back.")
	slider("Layer", 1, 100, 1, "%d", function() return db.layer or api.currentLayerValue() end,
		function(v) db.layer = v; api.applyLevel() end)
	pageByKey.sizing.reset = resetQuests

	page("background", "window", "Background")
	check("Show a background behind the trackers", function() return db.background end,
		function(v) db.background = v and true or false; if api.applyBackground then api.applyBackground() end end, nil, nil,
		"behind the RXP Tracker and the quest list, down to the last quest shown")
	color("Background colour", function() return db.backgroundColor or { 0, 0, 0, 0.4 } end,
		function(v) db.backgroundColor = v; if api.applyBackground then api.applyBackground() end end,
		function() return db.background end, nil, 0.4)
	slider("Space around the trackers", 0, 30, 1, "%d px", function() return db.backgroundPad or 6 end,
		function(v) db.backgroundPad = v; if api.applyBackground then api.applyBackground() end end,
		function() return db.background end)
	pageByKey.background.reset = resetQuests

	-- Settings Window > Profiles (Profiles.lua) ---------------------------------------------------------------------
	page("profiles", "window", "Profiles")
	do
		local selected, newName, exportText, importText, importName, lastMessage = nil, "", "", "", "", nil
		local function names() return api.profileNames and api.profileNames() or {} end
		local function pick()
			local list = names()
			for _, n in ipairs(list) do if n == selected then return selected end end
			selected = api.activeProfile and api.activeProfile() or list[1]
			return selected
		end
		local function tell(ok, message)
			lastMessage = message and { message, ok and { 0.6, 0.9, 0.6 } or { 1, 0.45, 0.35 } } or nil
			if message then print("|cff33ff99RXP ForeverTracker|r " .. message) end
		end
		-- loading or deleting asks first: loading reloads the interface to apply every setting
		StaticPopupDialogs["RXPFT_LOAD_PROFILE"] = {
			text = "Load the profile \"%s\"?\n\nYour current settings stay saved in \"%s\". The interface reloads to apply the profile.",
			button1 = YES or "Yes", button2 = NO or "No", timeout = 0, whileDead = 1, hideOnEscape = 1,
			OnAccept = function(_, name)
				local ok, err = api.loadProfile(name)
				if ok then ReloadUI() else tell(false, err) end
			end,
		}
		StaticPopupDialogs["RXPFT_DELETE_PROFILE"] = {
			text = "Delete the profile \"%s\"? This cannot be undone.",
			button1 = YES or "Yes", button2 = NO or "No", timeout = 0, whileDead = 1, hideOnEscape = 1,
			OnAccept = function(_, name)
				tell(api.deleteProfile(name))
				selected = nil
				api.refreshConfig()
			end,
		}
		statusBox("Profiles", function()
			local rows = {
				{ "Active", api.activeProfile and api.activeProfile() or "Default", { 1, 0.82, 0 } },
				{ "Saved", tostring(#names()) },
			}
			if lastMessage then rows[#rows + 1] = { "Last", lastMessage[1], lastMessage[2] } end
			return rows
		end)
		note("Settings are kept in the active profile as you change them. Loading another profile reloads the interface. Profiles are shared by all your characters.")
		choice("Profile", function()
			local out = {}
			for _, n in ipairs(names()) do
				out[#out + 1] = { n, n .. (n == (api.activeProfile and api.activeProfile()) and "  (active)" or "") }
			end
			return out
		end, pick, function(v) selected = v end)
		buttons("Profile actions", {
			{ "Load", function()
				local name = pick()
				if name == api.activeProfile() then tell(true, "\"" .. name .. "\" is already the active profile.") return end
				local dialog = StaticPopup_Show("RXPFT_LOAD_PROFILE", name, api.activeProfile())
				if dialog then dialog.data = name end
			end, 110 },
			{ "Save over", function() tell(api.saveProfile(pick())) end, 120 },
			{ "Delete", function()
				local name = pick()
				if name == api.activeProfile() then tell(false, "The active profile cannot be deleted: load another one first.") return end
				local dialog = StaticPopup_Show("RXPFT_DELETE_PROFILE", name)
				if dialog then dialog.data = name end
			end, 110 },
			{ "Export", function()
				local text, err = api.exportProfile(pick())
				exportText = text or ""
				tell(text ~= nil, text and ("Exported \"" .. pick() .. "\": copy the string below with Ctrl+C.") or err)
			end, 110 },
		})
		heading("New profile")
		input("Name", function() return newName end, function(v) newName = v end, 1, "e.g. Raid, Questing, Alt")
		buttons("Save as new", {
			{ "Save current settings as new profile", function()
				local ok, message = api.saveProfile(newName)
				tell(ok, message)
				if ok then selected = newName:gsub("^%s+", ""):gsub("%s+$", ""); newName = "" end
			end, 290 },
		})
		heading("Export")
		input("Profile string (choose a profile above and press Export, then Ctrl+C)", function() return exportText end,
			function() end, 4)
		declared[#declared].selectAll = true
		heading("Import")
		input("Paste a profile string (Ctrl+V)", function() return importText end, function(v) importText = v end, 4)
		input("Save it as (empty: its own name)", function() return importName end, function(v) importName = v end, 1)
		buttons("Import", {
			{ "Import", function()
				local ok, message, name = api.importProfile(importText, importName)
				tell(ok, message)
				if ok then selected, importText, importName = name, "", "" end
			end, 120 },
		})
	end

	page("minimap", "window", "Minimap button")
	check("Show minimap button", function() return not db.minimap.hide end,
		function(v) if api.setMinimapShown then api.setMinimapShown(v) end end)
	pageByKey.minimap.reset = resetQuests

	-- page names, shown above each page's settings while searching
	for _, p in ipairs(pages) do
		declaringPage = p.key
		local head = { kind = "heading", label = p.title, pageHead = true, full = true }
		declare(head)
		p.headItem = head
	end
end

---------------------------------------------------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------------------------------------------------
local selectPage
local function groupOf(key) local p = pageByKey[key]; return p and p.group end

-- the category list grows with the text size (above 100 %), so its names don't crowd into extra lines
local function sidebarWidth() return math.floor(SIDEBAR_W * math.max(ts(), 1) + 0.5) end

local function buildSidebar(f, top)
	local sidebar = CreateFrame("Frame", nil, f)
	sidebar:SetPoint("TOPLEFT", f, "TOPLEFT", 14, top)
	sidebar:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 14, 50)
	sidebar:SetWidth(sidebarWidth())
	-- When the window is too short for the whole list it scrolls with the mouse wheel or its thin scrollbar (in the
	-- gap right of the list, shown only while the list does not fit), and a row that does not fit in full is hidden
	-- until it does. That is checked when the window is resized (and when the
	-- list scrolls or is laid out again), never every frame.
	local scroller = CreateFrame("ScrollFrame", nil, sidebar)
	scroller:SetAllPoints()
	local content = CreateFrame("Frame", nil, scroller)
	content:SetSize(sidebarWidth(), 1)
	scroller:SetScrollChild(content)
	sidebar.scroller, sidebar.content = scroller, content
	local headers, entries = {}, {}
	local rows = {} -- every header and entry, with its place in the list: { frame, top, bottom }
	for _, group in ipairs(GROUPS) do
		local list = {}
		for _, p in ipairs(pages) do if p.group == group.key then list[#list + 1] = p end end
		if #list > 0 then
			local head = CreateFrame("Frame", nil, content)
			local bg = head:CreateTexture(nil, "BACKGROUND")
			bg:SetAllPoints()
			gradient(bg, C.headTop, C.headBottom)
			border(head, C.headEdge)
			local icon
			if group.icon then
				icon = head:CreateTexture(nil, "ARTWORK")
				icon:SetTexture(group.icon)
				icon:SetPoint("LEFT", 8, 0)
			end
			local t = text(head, "GameFontNormalLarge", 1, C.headText)
			t:SetJustifyH("LEFT")
			t:SetText(group.title)
			headers[#headers + 1] = { frame = head, text = t, icon = icon, group = group }
			for _, p in ipairs(list) do
				local b = CreateFrame("Button", nil, content)
				b.sel = b:CreateTexture(nil, "BACKGROUND")
				b.sel:SetAllPoints()
				hGradient(b.sel, { 1, 0.82, 0 }, 0.24, 0.02)
				local hl = b:CreateTexture(nil, "HIGHLIGHT")
				hl:SetAllPoints()
				hGradient(hl, { 1, 0.9, 0.6 }, 0.1, 0.0)
				b.text = text(b, "GameFontNormal", 1.15)
				b.text:SetPoint("LEFT", 28, 0)
				b.text:SetPoint("RIGHT", -4, 0)
				b.text:SetJustifyH("LEFT")
				b.text:SetWordWrap(true)
				b.text:SetText(p.title)
				b:SetScript("OnClick", function()
					if PlaySound and SOUNDKIT and SOUNDKIT.IG_CHARACTER_INFO_TAB then pcall(PlaySound, SOUNDKIT.IG_CHARACTER_INFO_TAB) end
					selectPage(p.key)
				end)
				-- greyed (still clickable, the page still opens) when the page does not apply now: p.dimmed()
				b.setSelected = function(on)
					b.selected = on
					b.sel:SetShown(on)
					local dim = p.dimmed and p.dimmed()
					if dim then b.text:SetTextColor(0.5, 0.5, 0.5)
					elseif on then b.text:SetTextColor(1, 1, 1) else b.text:SetTextColor(1, 0.82, 0) end
				end
				b.page = p
				nav[p.key] = b
				entries[#entries + 1] = { frame = b, head = head }
			end
		end
	end
	sidebar.arrange = function()
		wipe(rows)
		local k = ts()
		sidebar:SetWidth(sidebarWidth())
		local y = 0
		local lastHead
		for _, e in ipairs(entries) do
			if e.head ~= lastHead then
				if lastHead then y = y + 14 end
				for _, h in ipairs(headers) do
					if h.frame == e.head then
						local hh = math.floor(30 * k + 0.5)
						h.frame:ClearAllPoints()
						h.frame:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
						rows[#rows + 1] = { h.frame, y, y + hh }
						h.frame:SetSize(sidebarWidth(), hh)
						if h.icon then h.icon:SetSize(hh - 10, hh - 10) end
						h.text:ClearAllPoints()
						h.text:SetPoint("LEFT", h.icon and (hh + 2) or 12, 0)
						h.text:SetPoint("RIGHT", -6, 0)
						y = y + hh
					end
				end
				lastHead = e.head
			end
			local b = e.frame
			b:SetWidth(sidebarWidth())
			b.text:SetHeight(0)
			local bh = math.max(math.floor(26 * k + 0.5), math.ceil((b.text:GetStringHeight() or 14) + 8))
			b:SetHeight(bh)
			b:ClearAllPoints()
			b:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
			rows[#rows + 1] = { b, y, y + bh }
			y = y + bh
		end
		content:SetSize(sidebarWidth(), math.max(y, 1))
		sidebar.fit()
	end
	-- grey the pages that do not apply now (and a group header whose pages all do not)
	sidebar.refreshDim = function()
		local groupDim = {}
		for _, e in ipairs(entries) do
			local b = e.frame
			if b.setSelected then b.setSelected(b.selected and true or false) end
			local dim = b.page and b.page.dimmed and b.page.dimmed() and true or false
			if groupDim[e.head] == nil then groupDim[e.head] = dim else groupDim[e.head] = groupDim[e.head] and dim end
		end
		for _, h in ipairs(headers) do
			local dim = groupDim[h.frame]
			if dim then h.text:SetTextColor(0.5, 0.5, 0.5) else h.text:SetTextColor(C.headText[1], C.headText[2], C.headText[3]) end
			if h.icon then
				if h.icon.SetDesaturated then h.icon:SetDesaturated(dim and true or false) end
				h.icon:SetAlpha(dim and 0.5 or 1)
			end
		end
	end
	-- keep the scroll within the list, and show only the rows that fit in full
	sidebar.fit = function()
		local viewH = scroller:GetHeight() or 0
		if viewH <= 1 then -- not laid out yet (first build): everything shows, the window's first size runs this again
			for _, row in ipairs(rows) do row[1]:Show() end
			return
		end
		local listH = content:GetHeight() or 0
		local maxScroll = math.max(listH - viewH, 0)
		local offset = math.min(math.max(scroller:GetVerticalScroll() or 0, 0), maxScroll)
		if math.abs((scroller:GetVerticalScroll() or 0) - offset) > 0.5 then scroller:SetVerticalScroll(offset) end
		for _, row in ipairs(rows) do
			row[1]:SetShown(row[2] >= offset - 0.5 and row[3] <= offset + viewH + 0.5)
		end
	end
	-- the list's own height changing is the moment to check (the window's OnSizeChanged runs before its children's
	-- sizes are updated, so a check there used the old height: rows hidden in a short window stayed hidden after
	-- making it taller)
	scroller:SetScript("OnSizeChanged", function() sidebar.fit() end)
	-- the scrollbar: a 6 px track with a draggable thumb, as the Prerequisite Journal's guide list has
	local BAR_W = 6
	local bar = CreateFrame("Frame", nil, sidebar)
	bar:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 4, 0)
	bar:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMRIGHT", 4, 0)
	bar:SetWidth(BAR_W)
	bar:Hide()
	solid(bar, "BACKGROUND", C.track, 1):SetAllPoints()
	local thumb = CreateFrame("Frame", nil, bar)
	thumb:SetWidth(BAR_W)
	thumb:EnableMouse(true)
	solid(thumb, "ARTWORK", C.thumb, 1):SetAllPoints()
	sidebar.bar = bar
	local function range() return math.max((content:GetHeight() or 0) - (scroller:GetHeight() or 0), 0) end
	local function placeThumb()
		local viewH, listH, max = scroller:GetHeight() or 0, content:GetHeight() or 0, range()
		if max <= 0.5 or viewH <= 1 then bar:Hide() return end
		bar:Show()
		local trackH = bar:GetHeight() or viewH
		local thumbH = math.max(16, trackH * viewH / listH)
		thumb:SetHeight(thumbH)
		thumb:ClearAllPoints()
		thumb:SetPoint("TOP", bar, "TOP", 0, -((scroller:GetVerticalScroll() or 0) / max) * (trackH - thumbH))
	end
	local function scrollTo(value)
		scroller:SetVerticalScroll(math.min(math.max(value, 0), range()))
		sidebar.fit()
	end
	local fitRows = sidebar.fit
	sidebar.fit = function()
		fitRows()
		placeThumb()
	end
	thumb:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" then return end
		local scale = self:GetEffectiveScale()
		local startY, startScroll = select(2, GetCursorPosition()) / scale, scroller:GetVerticalScroll() or 0
		self:SetScript("OnUpdate", function()
			if not IsMouseButtonDown("LeftButton") then self:SetScript("OnUpdate", nil) return end
			local trackH, thumbH = bar:GetHeight() or 1, self:GetHeight() or 1
			local moved = startY - select(2, GetCursorPosition()) / scale
			scrollTo(startScroll + moved * range() / math.max(trackH - thumbH, 1))
		end)
	end)
	thumb:SetScript("OnMouseUp", function(self) self:SetScript("OnUpdate", nil) end)
	thumb:SetScript("OnHide", function(self) self:SetScript("OnUpdate", nil) end)
	scroller:EnableMouseWheel(true)
	scroller:SetScript("OnMouseWheel", function(self, delta)
		if range() <= 0 then return end
		local step = math.floor(26 * ts() + 0.5)
		scrollTo((self:GetVerticalScroll() or 0) - delta * step)
	end)
	return sidebar
end

local function build()
	local db = ns.db
	local f = create("Frame", "RXPForeverTrackerConfig", UIParent)
	frame = f
	local size = db.configSize
	-- sizes saved by the older, narrower window are too small for the category list: start at the new size then
	if not (size and size[1] and size[1] >= MIN_W and size[2] and size[2] >= MIN_H) then size = nil end
	f:SetSize(size and size[1] or DEFAULT_W, size and size[2] or DEFAULT_H)
	f:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
	f:SetFrameStrata("DIALOG")
	f:SetToplevel(true)
	f:SetMovable(true)
	f:SetResizable(true)
	-- the smallest window grows with the text size, so larger text gets more room instead of running out of it; a
	-- window smaller than that is enlarged (within the screen)
	local function fitText()
		local k = math.max(ts(), 1)
		local screenW, screenH = tonumber(UIParent:GetWidth()) or 0, tonumber(UIParent:GetHeight()) or 0
		if screenW < 200 then screenW = MAX_W + 20 end -- not known yet
		if screenH < 200 then screenH = MAX_H + 20 end
		local minW = math.min(math.ceil(MIN_W * k), MAX_W, math.floor(screenW - 20))
		local minH = math.min(math.ceil(MIN_H * k), MAX_H, math.floor(screenH - 20))
		f.qtsMinW, f.qtsMinH = minW, minH
		if f.SetResizeBounds then
			f:SetResizeBounds(minW, minH, MAX_W, MAX_H)
		else
			if f.SetMinResize then f:SetMinResize(minW, minH) end
			if f.SetMaxResize then f:SetMaxResize(MAX_W, MAX_H) end
		end
		local w, h = f:GetWidth() or minW, f:GetHeight() or minH
		if w < minW or h < minH then f:SetSize(math.max(w, minW), math.max(h, minH)) end
	end
	f.qtsFitText = fitText
	fitText()
	f:EnableMouse(true)
	f:SetClampedToScreen(false) -- may be dragged partly off screen
	f:RegisterForDrag("LeftButton")
	f:SetScript("OnDragStart", f.StartMoving)
	f:SetScript("OnDragStop", f.StopMovingOrSizing)
	tinsert(UISpecialFrames, "RXPForeverTrackerConfig") -- Esc closes it

	-- window: dark body, bronze edge with a black inner line (no shadow outside the edge)
	local body = solid(f, "BACKGROUND", C.window, 0.98, -7)
	body:SetAllPoints()
	border(f, C.edge, 2, "BORDER")
	local inner = CreateFrame("Frame", nil, f)
	inner:SetPoint("TOPLEFT", 2, -2)
	inner:SetPoint("BOTTOMRIGHT", -2, 2)
	border(inner, { 0, 0, 0 }, 1, "BORDER")

	-- title bar
	local bar = CreateFrame("Frame", nil, f)
	bar:SetPoint("TOPLEFT", 2, -2)
	bar:SetPoint("TOPRIGHT", -2, -2)
	bar:SetHeight(32)
	local barBg = bar:CreateTexture(nil, "BACKGROUND")
	barBg:SetAllPoints()
	gradient(barBg, C.titleTop, C.titleBottom)
	local barLine = solid(bar, "BORDER", C.titleLine)
	barLine:SetPoint("BOTTOMLEFT")
	barLine:SetPoint("BOTTOMRIGHT")
	barLine:SetHeight(1)
	-- the title: a two-tone wordmark ("RXP" cream, "Forever" gold, "Tracker" pale gold) in the game font at a fixed
	-- size with a shadow, RestedXP's logo before it, a soft gold glow behind it and a fading gold rule with a small
	-- diamond on either side, in the window's bronze-and-gold palette
	local GOLD = { 1, 0.82, 0.25 }
	local glowL = bar:CreateTexture(nil, "ARTWORK")
	glowL:SetPoint("TOPRIGHT", bar, "TOP", 0, -3)
	glowL:SetPoint("BOTTOMLEFT", bar, "BOTTOM", -170, 3)
	hGradient(glowL, GOLD, 0, 0.16)
	local glowR = bar:CreateTexture(nil, "ARTWORK")
	glowR:SetPoint("TOPLEFT", bar, "TOP", 0, -3)
	glowR:SetPoint("BOTTOMRIGHT", bar, "BOTTOM", 170, 3)
	hGradient(glowR, GOLD, 0.16, 0)
	local title = bar:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	local titleFont = GameFontNormal and GameFontNormal:GetFont() or STANDARD_TEXT_FONT
	if titleFont then title:SetFont(titleFont, 17, "") end
	title:SetShadowColor(0, 0, 0, 1)
	title:SetShadowOffset(1, -1)
	title:SetText("|cfff2e6c8RXP|r |cffffd100Forever|r|cfff0cf86Tracker|r")
	local logo = bar:CreateTexture(nil, "OVERLAY")
	logo:SetSize(22, 22)
	logo:SetTexture("Interface\\AddOns\\RXPGuides\\Textures\\rxp_logo-64")
	local hasLogo = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("RXPGuides")
	logo:SetShown(hasLogo and true or false)
	-- logo + gap + text, centred together
	local logoW = hasLogo and (22 + 6) or 0
	title:SetPoint("CENTER", bar, "CENTER", logoW / 2, 0)
	logo:SetPoint("RIGHT", title, "LEFT", -6, 0)
	local rules = {}
	local function rule(side)
		local line = bar:CreateTexture(nil, "ARTWORK")
		rules[#rules + 1] = line
		line:SetHeight(1)
		local gem = bar:CreateTexture(nil, "OVERLAY")
		gem:SetSize(5, 5)
		gem:SetColorTexture(GOLD[1], GOLD[2], GOLD[3], 0.9)
		if gem.SetRotation then gem:SetRotation(math.rad(45)) end
		if side == "left" then
			gem:SetPoint("RIGHT", hasLogo and logo or title, "LEFT", -10, 0)
			line:SetPoint("RIGHT", gem, "LEFT", -3, 0)
			line:SetWidth(110)
			hGradient(line, GOLD, 0, 0.75)
		else
			gem:SetPoint("LEFT", title, "RIGHT", 10, 0)
			line:SetPoint("LEFT", gem, "RIGHT", 3, 0)
			line:SetWidth(110)
			hGradient(line, GOLD, 0.75, 0)
		end
	end
	rule("left")
	rule("right")
	-- the rules and glow shorten (down to nothing) so they never run under the opacity slider beside the close button
	f.qtsFitTitle = function(rightTaken)
		local half = (bar:GetWidth() or 0) / 2
		local textHalf = ((title:GetStringWidth() or 150) + logoW) / 2
		local room = half - textHalf - 18 - (rightTaken or 0) - 12
		local len = math.max(math.min(room, 110), 0)
		for _, line in ipairs(rules) do line:SetWidth(math.max(len, 1)); line:SetShown(len >= 12) end
		local glow = math.max(math.min(half - (rightTaken or 0) - 8, 170), textHalf)
		glowL:SetPoint("BOTTOMLEFT", bar, "BOTTOM", -glow, 3)
		glowR:SetPoint("BOTTOMRIGHT", bar, "BOTTOM", glow, 3)
	end
	-- a thin gold edge under the bar, brightest in the middle
	local underL = bar:CreateTexture(nil, "OVERLAY")
	underL:SetHeight(1)
	underL:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
	underL:SetPoint("BOTTOMRIGHT", bar, "BOTTOM", 0, 0)
	hGradient(underL, GOLD, 0, 0.45)
	local underR = bar:CreateTexture(nil, "OVERLAY")
	underR:SetHeight(1)
	underR:SetPoint("BOTTOMLEFT", bar, "BOTTOM", 0, 0)
	underR:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
	hGradient(underR, GOLD, 0.45, 0)
	local close = create("Button", nil, f, "UIPanelCloseButton")
	close:SetSize(28, 28)
	close:SetPoint("TOPRIGHT", -3, -4)
	close:SetFrameLevel(bar:GetFrameLevel() + 5)
	close:HookScript("OnClick", function() f:Hide() end) -- keep the template's own close behaviour

	-- items (declared first: the category list is built from the pages)
	wipe(declared)
	wipe(nav)
	declareItems(db)

	local top = -(32 + 12 + 26 + 10)
	sidebarFrame = buildSidebar(f, top)
	sidebarFrame.arrange()
	f.qtsArrangeSidebar = function() sidebarFrame.arrange(); scheduleLayout() end

	-- search box (Forever's SearchBoxTemplate) above the page, right-aligned
	local nativeSearch
	searchBox, nativeSearch = create("EditBox", "RXPForeverTrackerConfigSearch", f, "SearchBoxTemplate")
	searchBox:SetSize(320, 24)
	searchBox:SetPoint("TOPRIGHT", f, "TOPRIGHT", -16, -(32 + 12))
	searchBox:SetAutoFocus(false)
	if nativeSearch then
		if searchBox.Instructions then searchBox.Instructions:SetText("Search") end
	else
		searchBox:SetFontObject("ChatFontNormal")
		searchBox:SetTextInsets(10, 8, 0, 0)
		local sbg = searchBox:CreateTexture(nil, "BACKGROUND")
		sbg:SetAllPoints()
		paint(sbg, { 0.047, 0.039, 0.031 })
		border(searchBox, C.trackEdge)
		local hint = searchBox:CreateFontString(nil, "OVERLAY", "GameFontDisable")
		hint:SetPoint("LEFT", 10, 0)
		hint:SetText("Search")
		searchBox:HookScript("OnTextChanged", function(self) hint:SetShown(self:GetText() == "") end)
		searchBox:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
		searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
	end
	searchBox:HookScript("OnTextChanged", function()
		if scroll then scroll:SetVerticalScroll(0) end
		scheduleLayout()
	end)

	-- the window's own opacity (10-100 %), at the left above the category list, on the search box's line; only
	-- this window
	do
		local MIN_ALPHA = 0.1
		local function windowAlpha()
			local v = tonumber(db.configAlpha) or 1
			return math.min(math.max(v, MIN_ALPHA), 1)
		end
		local holder = CreateFrame("Frame", nil, f)
		-- left edge with the category list (x 14), centred on the search box's line (its top -44, 24 tall)
		holder:SetPoint("LEFT", f, "TOPLEFT", 14, -(32 + 12 + 12))
		holder:SetHeight(20)
		local label = text(holder, "GameFontHighlightSmall", 1.1, C.subLabel)
		label:SetText("Opacity")
		label:SetPoint("LEFT", holder, "LEFT", 0, 0)
		local slider = CreateFrame("Slider", nil, holder)
		slider:SetOrientation("HORIZONTAL")
		slider:SetMinMaxValues(MIN_ALPHA * 100, 100)
		slider:SetValueStep(5)
		if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
		slider:SetSize(90, 18)
		local trackBg = slider:CreateTexture(nil, "BACKGROUND")
		trackBg:SetPoint("LEFT"); trackBg:SetPoint("RIGHT"); trackBg:SetHeight(6)
		paint(trackBg, C.trackEdge)
		local track = slider:CreateTexture(nil, "BORDER")
		track:SetPoint("LEFT", 1, 0); track:SetPoint("RIGHT", -1, 0); track:SetHeight(4)
		paint(track, C.track)
		local thumb = slider:CreateTexture(nil, "OVERLAY")
		thumb:SetSize(11, 11)
		paint(thumb, C.thumb)
		if thumb.SetRotation then pcall(thumb.SetRotation, thumb, math.rad(45)) end
		slider:SetThumbTexture(thumb)
		local value = text(holder, "GameFontHighlightSmall", 1.1, C.value)
		value:SetJustifyH("LEFT")
		local function arrange()
			local labelW = math.ceil(label:GetStringWidth() or 40)
			slider:ClearAllPoints()
			slider:SetPoint("LEFT", holder, "LEFT", labelW + 8, 0)
			value:ClearAllPoints()
			value:SetPoint("LEFT", slider, "RIGHT", 8, 0)
			value:SetWidth(math.ceil(40 * ts()))
			holder:SetWidth(labelW + 8 + slider:GetWidth() + 8 + value:GetWidth())
			if f.qtsFitTitle then f.qtsFitTitle(31) end -- only the close button sits in the title bar now
		end
		local setting = false
		slider:SetScript("OnValueChanged", function(_, v)
			v = math.floor(v / 5 + 0.5) * 5
			value:SetText(v .. "%")
			f:SetAlpha(v / 100)
			if not setting then db.configAlpha = v / 100 end
		end)
		slider:EnableMouseWheel(true)
		slider:SetScript("OnMouseWheel", function(self, delta) self:SetValue(self:GetValue() + delta * 5) end)
		setting = true
		slider:SetValue(math.floor(windowAlpha() * 100 / 5 + 0.5) * 5)
		setting = false
		f:SetAlpha(windowAlpha())
		arrange()
		f.qtsArrangeOpacity = arrange -- the text size changes the label's width
		f:HookScript("OnSizeChanged", arrange) -- a narrower window shortens the title's rules
		bar:HookScript("OnSizeChanged", arrange) -- and again once the title bar itself has its new width
		f:HookScript("OnSizeChanged", function()
			-- once more on the next frame, when every size inside the window has followed
			C_Timer.After(0, function() if sidebarFrame and sidebarFrame.fit then sidebarFrame.fit() end end)
		end)
		-- the first time it opens its size is known only once it shows
		f:HookScript("OnShow", function()
			C_Timer.After(0, function() if sidebarFrame and sidebarFrame.fit then sidebarFrame.fit() end end)
		end)
	end

	-- page panel
	panel = CreateFrame("Frame", nil, f)
	-- beside the category list, whatever its width
	panel:SetPoint("TOPLEFT", sidebarFrame, "TOPRIGHT", 14, 0)
	panel:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -16, 50)
	local panelBg = solid(panel, "BACKGROUND", C.panel)
	panelBg:SetAllPoints()
	border(panel, C.panelEdge)
	pageTitle = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
	do
		local font, sz, flags = pageTitle:GetFont()
		if font and sz then pageTitle:SetFont(font, math.max(sz, 22), flags) end
	end
	reg(pageTitle)
	pageTitle:SetTextColor(C.pageTitle[1], C.pageTitle[2], C.pageTitle[3])
	pageTitle:SetPoint("TOPLEFT", 22, -14)
	pageTitle:SetPoint("RIGHT", panel, "RIGHT", -150, 0)
	pageTitle:SetJustifyH("LEFT")
	defaultsButton = makeButton(panel, "Defaults", 110, function()
		-- only the settings this page shows
		local p = pageByKey[activePage]
		if p and p.reset then
			local questKeys, guideKeys = pageKeys(activePage)
			local guide = root.objectives and root.objectives.settings
			if next(guideKeys) and guide and guide.reset then guide.reset(guideKeys) end
			if next(questKeys) then api.resetDefaults(questKeys, '"' .. tostring(p.title or activePage) .. '"')
			elseif next(guideKeys) then DEFAULT_CHAT_FRAME:AddMessage("|cff33ff99RXP ForeverTracker|r \"" .. tostring(p.title or activePage) .. "\" settings reset to defaults") end
		end
		api.refreshConfig()
		scheduleLayout()
	end)
	defaultsButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -18, -14)
	-- what it does, naming the open section (HookScript: the button's own hover look stays)
	defaultsButton:HookScript("OnEnter", function(self)
		local p = pageByKey[activePage]
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
		GameTooltip:SetText("Defaults", 1, 1, 1)
		GameTooltip:AddLine(("Puts every setting in this section (%s) back to its default."):format(
			tostring(p and p.title or "this section")), 1, 0.82, 0, true)
		GameTooltip:AddLine("Other sections, the tracker's position and your guide progress are not changed.", 0.75, 0.75, 0.75, true)
		GameTooltip:Show()
	end)
	defaultsButton:HookScript("OnLeave", function(self)
		if GameTooltip:GetOwner() == self then GameTooltip:Hide() end
	end)

	-- scroll area: Forever's UIPanelScrollFrameTemplate (its scroll bar sits just right of the frame)
	local nativeScroll
	scroll, nativeScroll = create("ScrollFrame", "RXPForeverTrackerConfigScroll", panel, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 22, -54)
	scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -30, 10)
	content = CreateFrame("Frame", nil, scroll)
	content:SetSize(10, 10)
	scroll:SetScrollChild(content)
	if nativeScroll then
		scrollbar = scroll.ScrollBar or _G.RXPForeverTrackerConfigScrollScrollBar
		scroll.scrollBarHideable = true -- the template then hides its bar itself when the range is zero
		-- and whenever the template shows it again, the bar goes if there is still nothing to scroll
		if scrollbar and scrollbar.HookScript then
			scrollbar:HookScript("OnShow", function(self)
				if (scroll:GetVerticalScrollRange() or 0) <= 0.5 then self:Hide() end
			end)
		end
	end
	if not scrollbar then
		scrollbar = CreateFrame("Slider", nil, panel)
		scrollbar.qtsOwn = true
		scrollbar:SetOrientation("VERTICAL")
		scrollbar:SetPoint("TOPLEFT", scroll, "TOPRIGHT", 8, 0)
		scrollbar:SetPoint("BOTTOMLEFT", scroll, "BOTTOMRIGHT", 8, 0)
		scrollbar:SetWidth(8)
		local strack = scrollbar:CreateTexture(nil, "BACKGROUND")
		strack:SetAllPoints()
		paint(strack, C.track)
		local sthumb = scrollbar:CreateTexture(nil, "OVERLAY")
		sthumb:SetSize(8, 40)
		paint(sthumb, { 0.36, 0.3, 0.22 })
		scrollbar:SetThumbTexture(sthumb)
		scrollbar:SetMinMaxValues(0, 0)
		scrollbar:SetValueStep(1)
		scrollbar:SetValue(0)
		scrollbar:SetScript("OnValueChanged", function(_, v) scroll:SetVerticalScroll(v) end)
	end

	-- Smooth wheel scrolling: each notch moves a target and the view eases towards it over a few frames. Notches in
	-- quick succession add up; dragging the scrollbar or switching pages cancels the glide.
	local WHEEL_STEP, EASE = 60, 14
	local glide = CreateFrame("Frame", nil, f)
	glide:Hide()
	local function setScroll(v)
		if scrollbar and scrollbar.qtsOwn then scrollbar:SetValue(v) else scroll:SetVerticalScroll(v) end
	end
	glide:SetScript("OnUpdate", function(self, elapsed)
		local target = self.target
		local current = scroll:GetVerticalScroll() or 0
		if not target then self:Hide() return end
		local diff = target - current
		if math.abs(diff) < 0.5 then
			setScroll(target)
			self.target = nil
			self:Hide()
			return
		end
		setScroll(current + diff * math.min(1, elapsed * EASE))
	end)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(_, delta)
		local max = scroll:GetVerticalScrollRange() or 0
		local from = glide.target or scroll:GetVerticalScroll() or 0
		glide.target = math.min(math.max(from - delta * WHEEL_STEP * math.max(1, ts()), 0), max)
		glide:Show()
	end)
	if scrollbar and scrollbar.HookScript then
		scrollbar:HookScript("OnMouseDown", function() glide.target = nil; glide:Hide() end)
	end
	f.qtsStopGlide = function() glide.target = nil; glide:Hide() end

	-- bottom bar: version and hint under the page (right of the category list), Close on the right
	footer = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	-- under the page panel, to the right of the category list (it ran into the list when the window was short)
	footer:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 2, -32)
	footer:SetPoint("RIGHT", f, "RIGHT", -160, 0)
	footer:SetWordWrap(false) -- one line; cut with "..." when the window is narrow
	footer:SetJustifyH("LEFT")
	local closeButton = makeButton(f, "Close", 110, function() f:Hide() end)
	closeButton:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -28, 13)

	-- resize grip
	local grip = CreateFrame("Button", nil, f)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", -4, 4)
	grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
	grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
	-- The window is resized by following the cursor while the button is held (as the tracker's drag bar moves it):
	-- the game's StartSizing made it snap and jump about in Forever (the window is anchored at its centre, and its
	-- re-layout and minimum size fought the built-in sizing). Its top-left corner stays put; it ends on button up.
	local sizing
	local function cursor()
		local scale = f:GetEffectiveScale()
		local x, y = GetCursorPosition()
		return x / scale, y / scale
	end
	local function stopSizing()
		if not sizing then return end
		sizing = nil
		grip:SetScript("OnUpdate", nil)
		grip:SetButtonState("NORMAL")
		db.configSize = { math.floor(f:GetWidth() + 0.5), math.floor(f:GetHeight() + 0.5) }
	end
	grip:SetScript("OnMouseDown", function(self, button)
		if button ~= "LeftButton" then return end
		local left, top = f:GetLeft(), f:GetTop()
		if not (left and top) then return end
		-- pin the top-left corner (in the window's own units) so only the right and bottom edges move
		f:ClearAllPoints()
		f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left * f:GetEffectiveScale() / UIParent:GetEffectiveScale(),
			top * f:GetEffectiveScale() / UIParent:GetEffectiveScale())
		local cx, cy = cursor()
		sizing = { x = cx, y = cy, w = f:GetWidth(), h = f:GetHeight() }
		self:SetButtonState("PUSHED", true)
		self:SetScript("OnUpdate", function()
			if not IsMouseButtonDown("LeftButton") then stopSizing() return end
			local x, y = cursor()
			local w = math.min(math.max(sizing.w + (x - sizing.x), f.qtsMinW or MIN_W), MAX_W)
			local h = math.min(math.max(sizing.h - (y - sizing.y), f.qtsMinH or MIN_H), MAX_H)
			if math.abs(w - f:GetWidth()) >= 1 or math.abs(h - f:GetHeight()) >= 1 then
				f:SetSize(math.floor(w + 0.5), math.floor(h + 0.5))
			end
		end)
	end)
	grip:SetScript("OnMouseUp", stopSizing)
	grip:SetScript("OnHide", stopSizing)
	-- HookScript, not SetScript: SetScript would drop the title and category list size hooks set up above
	f:HookScript("OnSizeChanged", scheduleLayout)

	wipe(items)
	for _, item in ipairs(declared) do
		if item.kind == "heading" then buildHeading(item, content)
		elseif item.kind == "check" then buildCheck(item, content)
		elseif item.kind == "color" then buildColor(item, content)
		elseif item.kind == "note" then buildNote(item, content)
		elseif item.kind == "status" then buildStatus(item, content)
		elseif item.kind == "orphans" then buildOrphans(item, content)
		elseif item.kind == "buttons" then buildButtons(item, content)
		elseif item.kind == "input" then buildInput(item, content)
		elseif item.kind == "choice" then buildChoice(item, content)
		else buildSlider(item, content) end
		items[#items + 1] = item
	end
	applyFonts()
	-- the guide status box follows the guide while its page is open
	local sinceStatus = 0
	f:HookScript("OnUpdate", function(_, elapsed)
		sinceStatus = sinceStatus + elapsed
		if sinceStatus < 1 then return end
		sinceStatus = 0
		for _, item in ipairs(items) do
			if (item.kind == "status" or item.kind == "orphans") and item.page == activePage then item.refresh(); scheduleLayout() end
		end
	end)
	f:Hide() -- new frames start shown; toggleConfig decides when to show
end

local HINTS = {
	quests = "/qt off then /reload restores Blizzard's tracker.",
	guide = "In chat: /qt toggle, 0-100 or all, arrow, satellites, badge, status, why.",
	window = "/qt or /qtrxp opens this window.",
}

-- the first page of a group ("quests", "guide", "window"), or a page key
local function resolvePage(key)
	if pageByKey[key] then return key end
	for _, p in ipairs(pages) do if p.group == key then return p.key end end
	return pages[1] and pages[1].key or "questlist"
end

selectPage = function(key)
	key = resolvePage(key)
	activePage = key
	if ns.db then
		ns.db.configPage = key
		ns.db.configTab = groupOf(key) -- "quests", "guide" or "window" (Shift-right-click on the tracker reads it)
	end
	for pageKey, b in pairs(nav) do b.setSelected(pageKey == key) end
	if footer then
		local version = C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ADDON, "Version")
		footer:SetText((version and ("Version " .. version .. "   ") or "") .. (HINTS[groupOf(key)] or ""))
	end
	if searchBox and searchBox:GetText() ~= "" then searchBox:SetText("") end
	if frame and frame.qtsStopGlide then frame.qtsStopGlide() end
	if scroll then scroll:SetVerticalScroll(0) end
	if openPopup then openPopup:Hide(); openPopup = nil end
	if frame and frame:IsShown() then
		api.refreshConfig()
		layout()
		scheduleLayout()
	end
end

function api.refreshConfig()
	if not frame then return end
	loading = true
	for _, item in ipairs(items) do
		item.refresh()
		if item.kind ~= "heading" then
			local on = true
			if item.enabled then on = item.enabled() and true or false end
			item.setEnabled(on)
		end
	end
	loading = false
	if sidebarFrame and sidebarFrame.refreshDim then sidebarFrame.refreshDim() end
end

function api.toggleConfig()
	if not frame then build(); selectPage(ns.db.configPage or ns.db.configTab or "questlist") end
	if frame:IsShown() then
		frame:Hide()
	else
		frame:Show()
		api.refreshConfig()
		layout()
		scheduleLayout() -- the scroll area has its real size one frame after showing
	end
end

-- /qt guide: open the window on a group ("quests", "guide", "window") or a page
function api.openConfigTab(key)
	if not frame then build() end
	selectPage(key)
	if not frame:IsShown() then api.toggleConfig() end
end

