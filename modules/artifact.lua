------------------------------------------------------------
-- Experiencer by Sonaza (https://sonaza.com)
-- Licensed under MIT License
-- See attached license text in file LICENSE
------------------------------------------------------------

local ADDON_NAME, Addon = ...;

local module = Addon:RegisterModule("artifact", {
	label       = "Artifact",
	order       = 3,
	savedvars   = {
		global = {
			ShowRemaining = true,
			ShowGainedAP = true,
			AbbreviateLargeValues = true,
		},
	},
});

module.levelUpRequiresAction = true;
module.hasCustomMouseCallback = false;

module.hasArtifact = true;

function module:Initialize()
	self:RegisterEvent("AZERITE_ITEM_EXPERIENCE_CHANGED");
	self:RegisterEvent("UNIT_INVENTORY_CHANGED");
	module.apInSession = 0;
	
	module:UpdateHasArtifact();
end

function module:UNIT_INVENTORY_CHANGED(event, unit)
	if (unit ~= "player") then return end
	module:UpdateHasArtifact();
	module:Refresh();
end

function module:IsDisabled()
	return not module.hasArtifact;
end

local HEART_OF_AZEROTH_ITEM_ID = 158075;
local HEART_OF_AZEROTH_QUEST_ID = 51211;
	
function module:UpdateHasArtifact()
	local playerLevel = UnitLevel("player");
	if (playerLevel < 110) then
		module.hasArtifact = false;
	else
		local hasArtifact = C_AzeriteItem.HasActiveAzeriteItem();
		if (not hasArtifact) then
			-- C_AzeriteItem.HasActiveAzeriteItem may return false
			-- during initial game loading, try a fallback to item id
			local itemId = GetInventoryItemID("player", 2);
			if (itemId == HEART_OF_AZEROTH_ITEM_ID) then
				hasArtifact = true;
			end
		end
		module.hasArtifact = hasArtifact;
	end
end

function module:AllowedToBufferUpdate()
	return true;
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
	--local azeriteItemLocation = C_AzeriteItem.FindActiveAzeriteItem(); 
	--if (not azeriteItemLocation) then
	--	return "Azerite Artifact";
	--end
	--local itemID = GetInventoryItemID("player", 2); -- can probably hardcode the neck with its slot id
	--if (itemID == nil) then return "Unknown" end
	
	local itemID = HEART_OF_AZEROTH_ITEM_ID;
		
	local name = GetItemInfo(itemID);
	if (not name) then
		self:RegisterEvent("GET_ITEM_INFO_RECEIVED");
	else
		self:UnregisterEvent("GET_ITEM_INFO_RECEIVED");
	end
	return name;
end

function module:GetText()
	if (module:IsDisabled()) then
		return "No artifact";
	end
	
	local primaryText = {};
	local secondaryText = {};
	
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
	
	if(self.db.global.ShowGainedAP and module.apInSession > 0) then
		tinsert(secondaryText, string.format("+%s |cffffcc00AP|r", BreakUpLargeNumbers(module.apInSession)));
	end
	
	return table.concat(primaryText, "  "), table.concat(secondaryText, "  ");
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
			text = "Show amount of Artififact Power gained in current session",
			func = function() self.db.global.ShowGainedAP = not self.db.global.ShowGainedAP; module:RefreshText(); end,
			checked = function() return self.db.global.ShowGainedAP; end,
			isNotRadio = true,
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

function module:AZERITE_ITEM_EXPERIENCE_CHANGED(_, _, oldAP, newAP)
	if (oldAP ~= nil and newAP ~= nil) then
		module.apInSession = module.apInSession + (newAP - oldAP);
	end
	module:Refresh();
end
