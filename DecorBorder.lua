-- DecorBorder Addon
-- Version 1.1.3
-- Uses C_HousingCatalog.GetCatalogEntryInfoByItem(itemID)
-- Ownership detection updated:
-- learned = (numStored + numPlaced) > 0
-- Falls back to quantity if numPlaced not present

DecorBorder = {}
DecorBorderDB = DecorBorderDB or {}

local defaults = {
	enableColoring = true,
	colorLearned = {0, 1, 0},   -- green
	colorUnlearned = {1, 0, 0}, -- red
}
local function Print(text, ...)
		if text then
			if text:match("%%[dfqs%d%.]") then
				print("DECB " .. format(text, ...))
			else
				print("DECB " .. strjoin(" ", text, tostringall(...)))
			end
		end
	end
	
local function CopyDefaults(src, dst)
	if type(dst) ~= "table" then dst = {} end
	for k, v in pairs(src) do
		if type(v) == "table" then
			dst[k] = CopyDefaults(v, dst[k])
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
	return dst
end

local CatalogReady = false

local function RequestCatalog()
	local catalogSearcher = C_HousingCatalog.CreateCatalogSearcher();
	catalogSearcher:GetCatalogSearchResults();
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("HOUSING_STORAGE_UPDATED")
eventFrame:RegisterEvent("PLAYER_LOGIN")

eventFrame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		RequestCatalog()
	elseif event == "HOUSING_STORAGE_UPDATED" then
		CatalogReady = true
	end
end)

DecorBorderDB = CopyDefaults(defaults, DecorBorderDB)

-- ============================================================
-- Housing Catalog Helpers
-- ============================================================

local function _isDecor(itemID)

	local itemName, itemLink, _, _, _, itemType, itemSubType, _, _, _, _, classID, subclassID, _, _, _, _, _ = C_Item.GetItemInfo(itemID)
	if (classID == 20) then
		return true
	else
		return false
	end
end

local function ColorItemButton(itemID)
	if not DecorBorderDB.enableColoring then
		return false
	end
	if not itemID then return false end
	if not C_HousingCatalog or not C_HousingCatalog.GetCatalogEntryInfoByItem then return false end

	local info = C_HousingCatalog.GetCatalogEntryInfoByItem(itemID,true)
	if not info then return false end
	-- Debug Print
	--Print("%s %s",	info.name,	info.firstAcquisitionBonus	)
	if info.firstAcquisitionBonus == 0 then
		return true
	else
		return false
	end
	
	return false
end
	
-- ============================================================
-- Merchant Hook
-- ============================================================

if type(MerchantFrame_UpdateMerchantInfo) == "function" then
	hooksecurefunc("MerchantFrame_UpdateMerchantInfo", function()
		if not MerchantFrame or not MerchantFrame.page then return end
		if not CatalogReady then RequestCatalog() end
		for i = 1, MERCHANT_ITEMS_PER_PAGE do
			local button = _G["MerchantItem"..i.."ItemButton"]
			local merchantButton = _G["MerchantItem"..i]
			local index = ((MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE) + i
			local itemID = GetMerchantItemID(index)

			if button then
				if itemID then
					if _isDecor( itemID ) then
						learned = ColorItemButton(itemID)
						if learned then
							SetItemButtonNameFrameVertexColor(merchantButton, DecorBorderDB.colorLearned[1], DecorBorderDB.colorLearned[2], DecorBorderDB.colorLearned[3])
							SetItemButtonSlotVertexColor(merchantButton, DecorBorderDB.colorLearned[1], DecorBorderDB.colorLearned[2], DecorBorderDB.colorLearned[3])
							SetItemButtonTextureVertexColor(itemButton, 0.9*DecorBorderDB.colorLearned[1], 0.9*DecorBorderDB.colorLearned[2], 0.9*DecorBorderDB.colorLearned[3])
							SetItemButtonNormalTextureVertexColor(itemButton, 0.9*DecorBorderDB.colorLearned[1], 0.9*DecorBorderDB.colorLearned[2], 0.9*DecorBorderDB.colorLearned[3])
						else
							SetItemButtonNameFrameVertexColor(merchantButton, DecorBorderDB.colorUnlearned[1], DecorBorderDB.colorUnlearned[2], DecorBorderDB.colorUnlearned[3])
							SetItemButtonSlotVertexColor(merchantButton, DecorBorderDB.colorUnlearned[1], DecorBorderDB.colorUnlearned[2], DecorBorderDB.colorUnlearned[3])
							SetItemButtonTextureVertexColor(itemButton, 0.9*DecorBorderDB.colorUnlearned[1], 0.9*DecorBorderDB.colorUnlearned[2], 0.9*DecorBorderDB.colorUnlearned[3])
							SetItemButtonNormalTextureVertexColor(itemButton, 0.9*DecorBorderDB.colorUnlearned[1], 0.9*DecorBorderDB.colorUnlearned[2], 0.9*DecorBorderDB.colorUnlearned[3])
						end
					end
				end
			end
		end
	end)
end

-- ============================================================
-- Options Panel
-- ============================================================

local panel = CreateFrame("Frame", "DecorBorderOptionsPanel")
panel.name = "DecorBorder"

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", 16, -16)
title:SetText("DecorBorder Settings")

local enableCheck = CreateFrame("CheckButton", nil, panel, "InterfaceOptionsCheckButtonTemplate")
enableCheck:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
enableCheck.Text:SetText("Enable coloring of décor items")

panel:SetScript("OnShow", function()
	enableCheck:SetChecked(DecorBorderDB.enableColoring and true or false)
end)

enableCheck:SetScript("OnClick", function(self)
	DecorBorderDB.enableColoring = self:GetChecked() and true or false
end)

if Settings and Settings.RegisterCanvasLayoutCategory then
	local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
	Settings.RegisterAddOnCategory(category)
else
	InterfaceOptions_AddCategory(panel)
end
