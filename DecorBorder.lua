-- DecorBorder Addon
-- Version 1.1.4
-- Event-driven merchant-only execution (no background leaks)

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

DecorBorderDB = CopyDefaults(defaults, DecorBorderDB)

-- ============================================================
-- Housing Catalog Init (request once per session)
-- ============================================================

local CatalogRequested = false

local function RequestCatalog()
	local catalogSearcher = C_HousingCatalog.CreateCatalogSearcher();
	catalogSearcher:GetCatalogSearchResults();
end

-- ============================================================
-- Decor Helpers
-- ============================================================

local function _isDecor(itemID)
	local itemName, itemLink, _, _, _, itemType, itemSubType, _, _, _, _, classID = C_Item.GetItemInfo(itemID)
	-- Housing decor classID currently = 20 in your build
	return (classID == 20)
end

-- Returns true = learned, false = not learned, nil = not a catalog item yet
local function ColorItemButton(itemID)
	if not DecorBorderDB.enableColoring then return nil end
	if not itemID then return nil end
	if not C_HousingCatalog or not C_HousingCatalog.GetCatalogEntryInfoByItem then return nil end

	local info = C_HousingCatalog.GetCatalogEntryInfoByItem(itemID, true)
	if not info then return nil end

	-- Ownership logic:
	-- learned if any stored OR placed copies exist
	local numPlaced  = tonumber(info.numPlaced)  or 0
	local numStored  = tonumber(info.numStored)  or 0
	local quantity   = tonumber(info.quantity)   or 0

	local total = 0

	total = numPlaced + numStored + quantity

	-- Debug if you want it
	--Print("%s placed:%d stored:%d qty:%d total:%d", info.name, numPlaced, numStored, quantity, total)

	if total > 0 then
		return true
	else
		return false
	end
end

-- ============================================================
-- Merchant Coloring Function
-- Runs ONLY when merchant frame is open
-- ============================================================

local function DecorBorder_MerchantUpdate()
	if not MerchantFrame or not MerchantFrame:IsShown() then return end

	for i = 1, MERCHANT_ITEMS_PER_PAGE do
		local merchantButton = _G["MerchantItem"..i]
		local itemButton     = _G["MerchantItem"..i.."ItemButton"]

		local index = ((MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE) + i
		local itemID = GetMerchantItemID(index)

		if merchantButton and itemButton and itemID and _isDecor(itemID) then
			local learned = ColorItemButton(itemID)

			if learned == true then
				SetItemButtonNameFrameVertexColor(merchantButton, unpack(DecorBorderDB.colorLearned))
				SetItemButtonSlotVertexColor(merchantButton, unpack(DecorBorderDB.colorLearned))
				SetItemButtonTextureVertexColor(itemButton, unpack(DecorBorderDB.colorLearned))
				SetItemButtonNormalTextureVertexColor(itemButton, unpack(DecorBorderDB.colorLearned))

			elseif learned == false then
				SetItemButtonNameFrameVertexColor(merchantButton, unpack(DecorBorderDB.colorUnlearned))
				SetItemButtonSlotVertexColor(merchantButton, unpack(DecorBorderDB.colorUnlearned))
				SetItemButtonTextureVertexColor(itemButton, unpack(DecorBorderDB.colorUnlearned))
				SetItemButtonNormalTextureVertexColor(itemButton, unpack(DecorBorderDB.colorUnlearned))
			end
		end
	end
end

-- ============================================================
-- Event Controller
-- ============================================================

local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("PLAYER_LOGIN")
EventFrame:RegisterEvent("MERCHANT_SHOW")
EventFrame:RegisterEvent("MERCHANT_UPDATE")
EventFrame:RegisterEvent("MERCHANT_CLOSED")
EventFrame:RegisterEvent("HOUSING_STORAGE_UPDATED")
EventFrame:RegisterEvent("HOUSING_STORAGE_ENTRY_UPDATED")

local MerchantHooked = false

EventFrame:SetScript("OnEvent", function(_, event)

	-- Request catalog once when player logs in
	if event == "PLAYER_LOGIN" then
		RequestCatalog()
		return
	end

	-- Merchant opened
	if event == "MERCHANT_SHOW" then
		-- Hook Blizzard update once per session
		RequestCatalog()
		if not MerchantHooked then
			hooksecurefunc("MerchantFrame_UpdateMerchantInfo", DecorBorder_MerchantUpdate)
			MerchantHooked = true
		end
		DecorBorder_MerchantUpdate()
		return
	end

	-- Merchant contents refreshed
	if event == "MERCHANT_UPDATE" then
		RequestCatalog()
		DecorBorder_MerchantUpdate()
		return
	end

	-- Merchant closed → do nothing, no background work continues
	if event == "MERCHANT_CLOSED" then
		return
	end
end)
