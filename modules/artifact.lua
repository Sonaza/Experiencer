------------------------------------------------------------
-- Experiencer by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME, Addon = ...;

local module = Addon:RegisterModule("artifact", {
	label       = "Artifact",
	order       = 3,
	savedvars   = {
		global = {
			ShowRemaining = true,
			AbbreviateLargeValues = true,
		},
	},
});

module.levelUpRequiresAction = true;
module.hasCustomMouseCallback = false;

function module:Initialize()
	self:RegisterEvent("AZERITE_ITEM_EXPERIENCE_CHANGED");
end

function module:IsDisabled()
	return not C_AzeriteItem.HasActiveAzeriteItem()
end

function module:Update(elapsed)
	
end

function module:CanLevelUp()
	return false;
end

function module:FormatNumber(value)
	assert(value ~= nil);
	if(self.db.global.AbbreviateLargeValues) then
		return Addon:FormatNumberFancy(value);
	end
	return BreakUpLargeNumbers(value);
end

function module:GetArtifactName()
	local azeriteItemLocation = C_AzeriteItem.FindActiveAzeriteItem(); 
	if (not azeriteItemLocation) then
		return "Azerite Artifact";
	end
	local itemID = GetInventoryItemID("player", azeriteItemLocation.equipmentSlotIndex);
	local name = GetItemInfo(itemID);
	if (not name) then
		self:RegisterEvent("GET_ITEM_INFO_RECEIVED");
	end
	return name;
end

function module:GetText()
	if(not C_AzeriteItem.HasActiveAzeriteItem()) then
		return "No artifact";
	end
	
	local primaryText = {};
	
	local data = self:GetBarData();
	local remaining         = data.max - data.current;
	local progress          = data.current / data.max;
	local progressColor     = Addon:GetProgressColor(progress);
	local name = module:GetArtifactName();
	
	tinsert(primaryText,
		("|cffffecB3%s|r (Level %d):"):format(name or "", data.level)
	);
	
	if(self.db.global.ShowRemaining) then
		tinsert(primaryText,
			("%s%s|r (%s%.1f|r%%)"):format(progressColor, module:FormatNumber(remaining), progressColor, 100 - progress * 100)
		);
	else
		tinsert(primaryText,
			("%s%s|r / %s (%s%.1f|r%%)"):format(progressColor, module:FormatNumber(data.current), module:FormatNumber(data.max), progressColor, progress * 100)
		);
	end
	
	return table.concat(primaryText, "  "), nil;
end

function module:HasChatMessage()
	return C_AzeriteItem.HasActiveAzeriteItem(), "No artifact.";
end

function module:GetChatMessage()
	local outputText = {};
	
	local data = self:GetBarData();
	local remaining  = data.max - data.current;
	local progress   = data.current / data.max;
	local name       = module:GetArtifactName();
	
	tinsert(outputText, ("%s is currently level %s"):format(
		name, data.level
	));
	
	tinsert(outputText, ("at %s/%s power (%.1f%%) with %s to go"):format(
		module:FormatNumber(data.current),	
		module:FormatNumber(data.max),
		progress * 100,
		module:FormatNumber(remaining)
	));
	
	return table.concat(outputText, " ");
end

function module:GetBarData()
	local data    = {};
	data.id       = nil;
	data.level    = 0;
	data.min  	  = 0;
	data.max  	  = 1;
	data.current  = 0;
	data.rested   = nil;
	data.visual   = nil;
	
	local azeriteItemLocation = C_AzeriteItem.FindActiveAzeriteItem();
	if(C_AzeriteItem.HasActiveAzeriteItem() and azeriteItemLocation) then
		local currentXP, totalLevelXP = C_AzeriteItem.GetAzeriteItemXPInfo(azeriteItemLocation);
		local currentLevel = C_AzeriteItem.GetPowerLevel(azeriteItemLocation); 
		
		data.id       = 1;
		data.level    = currentLevel;
		
		data.current  = currentXP;
		data.max  	  = totalLevelXP;
	end
	
	return data;
end

function module:GetOptionsMenu()
	local menudata = {
		{
			text = "Artifact Options",
			isTitle = true,
			notCheckable = true,
		},
		{
			text = "Show remaining artifact power",
			func = function() self.db.global.ShowRemaining = true; module:RefreshText(); end,
			checked = function() return self.db.global.ShowRemaining == true; end,
		},
		{
			text = "Show current and max artifact power",
			func = function() self.db.global.ShowRemaining = false; module:RefreshText(); end,
			checked = function() return self.db.global.ShowRemaining == false; end,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Abbreviate large numbers",
			func = function() self.db.global.AbbreviateLargeValues = not self.db.global.AbbreviateLargeValues; module:RefreshText(); end,
			checked = function() return self.db.global.AbbreviateLargeValues; end,
			isNotRadio = true,
		},
	};
	
	return menudata;
end

------------------------------------------

function module:GET_ITEM_INFO_RECEIVED()
	module:Refresh();
end

function module:AZERITE_ITEM_EXPERIENCE_CHANGED()
	module:Refresh();
end
