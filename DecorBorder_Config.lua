-- DecorBorder Config Panel
-- Safe against missing SavedVariables / missing tables

local function EnsureColorTable(key, dr, dg, db)
	DecorBorderDB = DecorBorderDB or {}

	if type(DecorBorderDB[key]) ~= "table" then
		DecorBorderDB[key] = { r = dr, g = dg, b = db }
	else
		DecorBorderDB[key].r = DecorBorderDB[key].r or dr
		DecorBorderDB[key].g = DecorBorderDB[key].g or dg
		DecorBorderDB[key].b = DecorBorderDB[key].b or db
	end

	return DecorBorderDB[key]
end

local function GetColor(tbl)
	if type(tbl) ~= "table" then
		return 1, 1, 1
	end
	return tbl.r or 1, tbl.g or 1, tbl.b or 1
end

local function OpenColorPicker(title, colorTable, callback)
	if type(colorTable) ~= "table" then return end

	local r, g, b = GetColor(colorTable)

	ColorPickerFrame.hasOpacity = false
	ColorPickerFrame.previousValues = {r, g, b}

	ColorPickerFrame.func = function()
		local nr, ng, nb = ColorPickerFrame:GetColorRGB()
		colorTable.r, colorTable.g, colorTable.b = nr, ng, nb
		if callback then callback() end
	end

	ColorPickerFrame:SetColorRGB(r, g, b)
	ColorPickerFrame:Show()
end

local function CreateDecorBorderOptions()
	-- Ensure the three tables exist even if main file didn't init them yet
	local collected      = EnsureColorTable("colorCollected",      0, 1, 0) -- green
	local collectedEmpty = EnsureColorTable("colorCollectedEmpty", 1, 1, 0) -- yellow
	local uncollected    = EnsureColorTable("colorUncollected",    1, 0, 0) -- red

	local panel = CreateFrame("Frame", "DecorBorderOptionsPanel")
	panel.name = "DecorBorder"

	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("DecorBorder")

	local function CreateColorOption(labelText, yOffset, colorTable)
		local label = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		label:SetPoint("TOPLEFT", 16, yOffset)
		label:SetText(labelText)

		local button = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
		button:SetSize(140, 22)
		button:SetPoint("LEFT", label, "RIGHT", 20, 0)
		button:SetText("Pick Color")

		local swatch = panel:CreateTexture(nil, "OVERLAY")
		swatch:SetSize(18, 18)
		swatch:SetPoint("LEFT", button, "RIGHT", 10, 0)

		local function UpdateSwatch()
			swatch:SetColorTexture(GetColor(colorTable))
		end

		button:SetScript("OnClick", function()
			OpenColorPicker(labelText, colorTable, UpdateSwatch)
		end)

		UpdateSwatch()
		return yOffset - 40
	end

	local y = -60
	y = CreateColorOption("Collected (in storage)", y, collected)
	y = CreateColorOption("Collected (0 in storage)", y, collectedEmpty)
	y = CreateColorOption("Uncollected", y, uncollected)

	-- Register into Blizzard Settings UI
	if Settings and Settings.RegisterCanvasLayoutCategory then
		local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
		Settings.RegisterAddOnCategory(category)
	else
		InterfaceOptions_AddCategory(panel)
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", CreateDecorBorderOptions)
