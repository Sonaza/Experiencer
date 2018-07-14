------------------------------------------------------------
-- Experiencer by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME, Addon = ...;

local module = Addon:RegisterModule("honor", {
	label       = "Honor",
	order       = 4,
	savedvars   = {
		global = {
			ShowHonorLevel  = true,
			ShowPrestige    = true,
			ShowRemaining   = true
		},
	},
});

module.levelUpRequiresAction = true;
module.hasCustomMouseCallback = false;

local HONOR_UNLOCK_LEVEL = 110;

function module:Initialize()
	self:RegisterEvent("HONOR_XP_UPDATE");
	self:RegisterEvent("HONOR_LEVEL_UPDATE");
end

function module:IsDisabled()
	return UnitLevel("player") < HONOR_UNLOCK_LEVEL;
end

function module:Update(elapsed)
	
end

function module:OnMouseDown(button)
	
end

function module:CanLevelUp()
	return false;
end

function module:GetText()
	local primaryText = {};
	
	local honorlevel 	    = UnitHonorLevel("player");
	local honor, honormax   = UnitHonor("player"), UnitHonorMax("player");
	local remaining         = honormax - honor;
	
	local progress          = honor / (honormax > 0 and honormax or 1);
	local progressColor     = Addon:GetProgressColor(progress);
	
	if(self.db.global.ShowHonorLevel) then
		tinsert(primaryText, 
			("|cffffd200Honor Level|r %d"):format(honorlevel)
		);
	end
	
	if(self.db.global.ShowRemaining) then
		tinsert(primaryText,
			("%s%s|r (%s%.1f|r%%)"):format(progressColor, BreakUpLargeNumbers(remaining), progressColor, 100 - progress * 100)
		);
	else
		tinsert(primaryText,
			("%s%s|r / %s (%s%.1f|r%%)"):format(progressColor, BreakUpLargeNumbers(honor), BreakUpLargeNumbers(honormax), progressColor, progress * 100)
		);
	end
	
	return table.concat(primaryText, "  "), nil;
end

function module:HasChatMessage()
	return true, "Derp.";
end

function module:GetChatMessage()
	local level 	        = UnitHonorLevel("player");
	local honor, honormax   = UnitHonor("player"), UnitHonorMax("player");
	local remaining         = honormax - honor;
	
	local progress          = honor / (honormax > 0 and honormax or 1);
	
	local leveltext = ("Currently honor level %d"):format(level);
	
	return ("%s at %s/%s (%d%%) with %s to go"):format(
		leveltext,
		BreakUpLargeNumbers(honor),	
		BreakUpLargeNumbers(honormax),
		math.ceil(progress * 100),
		BreakUpLargeNumbers(remaining)
	);
end

function module:GetBarData()
	local level 	        = UnitHonorLevel("player");
	local honor, honormax   = UnitHonor("player"), UnitHonorMax("player");
	local remaining         = honormax - honor;
	
	local progress          = honor / (honormax > 0 and honormax or 1);
	local progressColor     = Addon:GetProgressColor(progress);
	
	local data    = {};
	data.id       = nil;
	data.level    = level;
	
	data.min  	  = 0;
	data.max  	  = honormax;
	data.current  = honor;
	
	data.visual   = nil;
	
	return data;
end

function module:GetOptionsMenu()
	local menudata = {
		{
			text = "Honor Options",
			isTitle = true,
			notCheckable = true,
		},
		{
			text = "Show remaining honor",
			func = function() self.db.global.ShowRemaining = true; module:RefreshText(); end,
			checked = function() return self.db.global.ShowRemaining == true; end,
		},
		{
			text = "Show current and max honor",
			func = function() self.db.global.ShowRemaining = false; module:RefreshText(); end,
			checked = function() return self.db.global.ShowRemaining == false; end,
		},
		{
			text = " ", isTitle = true, notCheckable = true,
		},
		{
			text = "Show honor level",
			func = function() self.db.global.ShowHonorLevel = not self.db.global.ShowHonorLevel; module:RefreshText(); end,
			checked = function() return self.db.global.ShowHonorLevel; end,
			isNotRadio = true,
		},
	};
	
	return menudata;
end

------------------------------------------

function module:HONOR_XP_UPDATE()
	module:Refresh();
end

function module:HONOR_LEVEL_UPDATE()
	module:Refresh();
end
