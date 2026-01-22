-- DecorBorder Addon
-- Version 1.2.0
-- Tooltip-based ownership detection (authoritative Blizzard data)
-- Runs only while merchant window is open (no background work / no leaks)

DecorBorder = {}
DecorBorderDB = DecorBorderDB or {}
local OwnedCache = {}   -- [itemID] = state
local defaults = {
	enableColoring = true,

	colorCollected      = { r = 0, g = 1, b = 0 }, -- green
	colorCollectedEmpty = { r = 1, g = 1, b = 0 }, -- yellow
	colorUncollected    = { r = 1, g = 0, b = 0 }, -- red
}

local function GetColor(tbl)
	return tbl.r, tbl.g, tbl.b
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

local function OpenColorPicker(title, colorTable, callback)
	local r, g, b = colorTable.r, colorTable.g, colorTable.b

	local function ColorCallback(restore)
		local nr, ng, nb
		if restore then
			nr, ng, nb = unpack(restore)
		else
			nr, ng, nb = ColorPickerFrame:GetColorRGB()
		end

		colorTable.r, colorTable.g, colorTable.b = nr, ng, nb
		if callback then callback() end
	end

	ColorPickerFrame.func = ColorCallback
	ColorPickerFrame.hasOpacity = false
	ColorPickerFrame.previousValues = { r, g, b }
	ColorPickerFrame:SetColorRGB(r, g, b)
	ColorPickerFrame:Hide()
	ColorPickerFrame:Show()

	ColorPickerFrame.Title:SetText(title)
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
-- Returns:
-- state = 0 → uncollected
-- state = 1 → collected but storage empty
-- state = 2 → collected and in storage
-- also returns placed, storage, owned for debugging if needed

local function GetOwnedFromTooltip(itemID)
	if not itemID then return 0,0,0,0 end

	ScanTooltip:ClearLines()
	ScanTooltip:SetItemByID(itemID)

	local numLines = ScanTooltip:NumLines()

	for i = 1, numLines do
		local line = _G["DecorBorderScanTooltipTextLeft"..i]
		if line then
			local text = line:GetText()

			-- Fast reject: almost all tooltip lines won't contain this word
			if text and text:find("Owned", 1, true) then

				-- Only now strip color codes
				text = StripColorCodes(text)

				local owned, placed, storage = text:match(
					"Owned:%s*(%d+)%s*%(%s*Placed:%s*(%d+),%s*Storage:%s*(%d+)%)"
				)

				if owned then
					local numOwned  = tonumber(owned) or 0
					local numStored = tonumber(storage) or 0

					local state
					if numOwned == 0 then
						-- Uncollected
						state = 0

					elseif numOwned > 0 and numStored == 0 then
						-- Collected but nothing in storage
						state = 1

					else
						-- Collected and storage > 0
						state = 2
					end
					return state
				end
			end
		end
	end
	-- No Owned line at all → uncollected
	return 0, 0, 0, 0
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

			local state = GetOwnedFromTooltip(itemID)

			-- state:
			-- 0 = uncollected
			-- 1 = collected but empty storage
			-- 2 = collected and in storage

			if state == 2 then
				-- Collected + in storage → GREEN
				SetItemButtonNameFrameVertexColor(merchantButton, GetColor(DecorBorderDB.colorCollected))
				SetItemButtonSlotVertexColor(merchantButton, GetColor(DecorBorderDB.colorCollected))
				SetItemButtonTextureVertexColor(itemButton, GetColor(DecorBorderDB.colorCollected))
				SetItemButtonNormalTextureVertexColor(itemButton, GetColor(DecorBorderDB.colorCollected))

			elseif state == 1 then
				-- Collected but storage empty → YELLOW
				SetItemButtonNameFrameVertexColor(merchantButton, GetColor(DecorBorderDB.colorCollectedEmpty))
				SetItemButtonSlotVertexColor(merchantButton, GetColor(DecorBorderDB.colorCollectedEmpty))
				SetItemButtonTextureVertexColor(itemButton, GetColor(DecorBorderDB.colorCollectedEmpty))
				SetItemButtonNormalTextureVertexColor(itemButton, GetColor(DecorBorderDB.colorCollectedEmpty))

			else
				-- Uncollected → RED
				SetItemButtonNameFrameVertexColor(merchantButton, GetColor(DecorBorderDB.colorUncollected))
				SetItemButtonSlotVertexColor(merchantButton, GetColor(DecorBorderDB.colorUncollected))
				SetItemButtonTextureVertexColor(itemButton, GetColor(DecorBorderDB.colorUncollected))
				SetItemButtonNormalTextureVertexColor(itemButton, GetColor(DecorBorderDB.colorUncollected))
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
		--RequestCatalog()
		--CreateDecorBorderOptions()
		return
	end
	
	if event == "MERCHANT_SHOW" then
		if not MerchantHooked then
			--RequestCatalog()
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