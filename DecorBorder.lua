-- DecorBorder Addon
-- Version 1.1.5
-- Tooltip-based ownership detection (authoritative Blizzard data)
-- Runs only while merchant window is open (no background work / no leaks)

DecorBorder = {}
DecorBorderDB = DecorBorderDB or {}

local defaults = {
	enableColoring = true,
	colorLearned = {0, 1, 0},   -- green
	colorUnlearned = {1, 0, 0}, -- red
}

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

local function Print(text, ...)
	if text then
		if text:match("%%[dfqs%d%.]") then
			print("DECB " .. format(text, ...))
		else
			print("DECB " .. strjoin(" ", text, tostringall(...)))
		end
	end
end

DecorBorderDB = CopyDefaults(defaults, DecorBorderDB)


local function RequestCatalog()
	local catalogSearcher = C_HousingCatalog.CreateCatalogSearcher();
	catalogSearcher:GetCatalogSearchResults();
end


-- ============================================================
-- Hidden Tooltip Scanner
-- ============================================================

local ScanTooltip = CreateFrame("GameTooltip", "DecorBorderScanTooltip", UIParent, "GameTooltipTemplate")
ScanTooltip:SetOwner(UIParent, "ANCHOR_NONE")

local function StripColorCodes(text)
	-- removes |cAARRGGBB and |r and |cn... codes
	text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
	text = text:gsub("|cn.-:", "")
	text = text:gsub("|r", "")
	return text
end

-- Reads Blizzard's own "Owned:" tooltip line
-- Returns: learned(boolean), placed(number), storage(number)
local function GetOwnedFromTooltip(itemID)
	if not itemID then return nil end

	ScanTooltip:ClearLines()
	ScanTooltip:SetItemByID(itemID)

	local numLines = ScanTooltip:NumLines()
	for i = 1, numLines do
		local line = _G["DecorBorderScanTooltipTextLeft"..i]
		if line then
			local text = line:GetText()
			Print(text)
			if text then
				-- Match: Owned: 1 (Placed: 0, Storage: 1)
				--local owned, placed, storage = text:match("Owned:%s*(%d+)%s*%(%s*Placed:%s*(%d+),%s*Storage:%s*(%d+)%)")
				local owned, placed, storage = StripColorCodes(text):match(
					"Owned:%s*(%d+)%s*%(%s*Placed:%s*(%d+),%s*Storage:%s*(%d+)%)"
				)
				local numPlaced  = tonumber(placed)  or 0
				local numStored  = tonumber(storage)  or 0
				local quantity   = tonumber(owned)   or 0
				--Print("%d [o:%s P:%s S:%s]",itemID, quantity, numPlaced, numStored)
				if owned then
					return (tonumber(owned) > 0), tonumber(placed), tonumber(storage)
				end
			end
		end
	end

	-- If no Owned line exists → not owned
	return false, 0, 0
end

-- ============================================================
-- Decor filter helper
-- (keeps your existing classID test)
-- ============================================================

local function _isDecor(itemID)
	local _, _, _, _, _, _, _, _, _, _, _, classID = C_Item.GetItemInfo(itemID)
	-- Current housing decor classID in your build = 20
	return (classID == 20)
end

-- ============================================================
-- Merchant Coloring Function
-- ============================================================

local function DecorBorder_MerchantUpdate()
	if not MerchantFrame or not MerchantFrame:IsShown() then return end
	if not DecorBorderDB.enableColoring then return end

	for i = 1, MERCHANT_ITEMS_PER_PAGE do
		local merchantButton = _G["MerchantItem"..i]
		local itemButton     = _G["MerchantItem"..i.."ItemButton"]

		local index = ((MerchantFrame.page - 1) * MERCHANT_ITEMS_PER_PAGE) + i
		local itemID = GetMerchantItemID(index)

		if merchantButton and itemButton and itemID and _isDecor(itemID) then

			local learned = GetOwnedFromTooltip(itemID)

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
-- Event Controller (merchant-only execution)
-- ============================================================

local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("MERCHANT_SHOW")
EventFrame:RegisterEvent("MERCHANT_UPDATE")
EventFrame:RegisterEvent("MERCHANT_CLOSED")

local MerchantHooked = false

EventFrame:SetScript("OnEvent", function(_, event)

	if event == "PLAYER_LOGIN" then
		RequestCatalog()
		return
	end
	
	if event == "MERCHANT_SHOW" then
		if not MerchantHooked then
			hooksecurefunc("MerchantFrame_UpdateMerchantInfo", DecorBorder_MerchantUpdate)
			MerchantHooked = true
		end
		DecorBorder_MerchantUpdate()
		return
	end

	if event == "MERCHANT_UPDATE" then
		DecorBorder_MerchantUpdate()
		return
	end

	if event == "MERCHANT_CLOSED" then
		-- Nothing running in background
		return
	end
end)
