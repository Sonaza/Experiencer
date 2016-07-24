------------------------------------------------------------
-- Experiencer by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME, Addon = ...;
local _;

local module = Addon:NewModule("honor");

module.name     = "Honor";
module.order    = 3;

local HONOR_UNLOCK_LEVEL = 110;

module.savedvars = {
	global = {
		ShowHonorLevel  = true,
		ShowPrestige    = true,
		ShowRemaining   = true
	}
}

function module:Initialize()
	self:RegisterEvent("HONOR_XP_UPDATE");
	self:RegisterEvent("HONOR_LEVEL_UPDATE");
	self:RegisterEvent("HONOR_PRESTIGE_UPDATE");
end

function module:IsDisabled()
	return UnitLevel("player") < HONOR_UNLOCK_LEVEL;
end

function module:Update(elapsed)
	if(not CanPrestige()) then
		module.levelUpRequiresAction = false;
	else
		module.levelUpRequiresAction = true;
	end
end

function module:GetText()
	local outputText = {};
	
	local honorlevel 	    = UnitHonorLevel("player");
	local prestige          = UnitPrestige("player");
	local honor, honormax   = UnitHonor("player"), UnitHonorMax("player");
	local remaining         = honormax - honor;
	
	local exhaustionThreshold = GetHonorExhaustion() or 0;
	local exhaustionStateID, exhaustionStateName, exhaustionStateMultiplier = GetHonorRestState();
	
	local restedPercentage  = math.ceil(exhaustionThreshold / honormax * 100);
	
	local progress          = honor / (honormax > 0 and honormax or 1);
	local progressColor     = Addon:GetProgressColor(progress);
	
	if(self.db.global.ShowHonorLevel) then
		tinsert(outputText, 
			("|cffffd200Honor Level|r %d"):format(honorlevel)
		);
	end
	
	if(self.db.global.ShowPrestige and prestige > 0) then
		tinsert(outputText, 
			("|cffffd200Prestige|r %d"):format(prestige)
		);
	end
	
	if(self.db.global.ShowRemaining) then
		tinsert(outputText,
			("%s%s|r (%s%d|r%%)"):format(progressColor, BreakUpLargeNumbers(remaining), progressColor, 100 - progress * 100)
		);
	else
		tinsert(outputText,
			("%s%s|r / %s (%s%d|r%%)"):format(progressColor, BreakUpLargeNumbers(honor), BreakUpLargeNumbers(honormax), progressColor, 100 - progress * 100)
		);
	end
	
	if(exhaustionThreshold > 0) then
		tinsert(outputText,
			string.format("%d%% |cff6fafdfrested|r", restedPercentage)
		);
		tinsert(outputText,
			string.format("%d%% |cff6fafdfmultiplier|r", exhaustionStateMultiplier * 100)
		);
	end
	
	if(CanPrestige()) then
		tinsert(outputText, 
			"|cff86ff36Can prestige!|r"
		);
	end
	
	return table.concat(outputText, "  ");
end

function module:HasChatMessage()
	return true, "Derp.";
end

function module:GetChatMessage()
	local level 	        = UnitHonorLevel("player");
	local prestige          = UnitPrestige("player");
	local honor, honormax   = UnitHonor("player"), UnitHonorMax("player");
	local remaining         = honormax - honor;
	
	local exhaustionThreshold = GetHonorExhaustion() or 0;
	local exhaustionStateID, exhaustionStateName, exhaustionStateMultiplier = GetHonorRestState();
	
	local progress          = honor / (honormax > 0 and honormax or 1);
	
	local leveltext = ("Currently honor level %d"):format(level);
	
	if(prestige > 0) then
		leveltext = ("%s (%d prestige)"):format(leveltext, prestige);
	end
	
	return ("%s at %s/%s (%d%%) with %d%% to go."):format(
		leveltext,
		BreakUpLargeNumbers(honor),	
		BreakUpLargeNumbers(honormax),
		math.ceil(progress * 100),
		math.ceil((1-progress) * 100)
	);
end

function module:GetBarData()
	local level 	        = UnitHonorLevel("player");
    local levelmax          = GetMaxPlayerHonorLevel();
    
	local honor, honormax   = UnitHonor("player"), UnitHonorMax("player");
	local remaining         = honormax - honor;
	
	local exhaustionThreshold = GetHonorExhaustion() or 0;
	local exhaustionStateID, exhaustionStateName, exhaustionStateMultiplier = GetHonorRestState();
	
	local progress          = honor / (honormax > 0 and honormax or 1);
	local progressColor     = Addon:GetProgressColor(progress);
	
	local data    = {};
	data.level    = level;
	
	if(level ~= levelmax) then
		data.min  	  = 0;
		data.max  	  = honormax;
		data.current  = honor;
	else
		data.min  	  = 0;
		data.max  	  = 1;
		data.current  = 1;
	end
	
	data.rested   = data.current + exhaustionThreshold;
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
		{
			text = "Show prestige level",
			func = function() self.db.global.ShowPrestige = not self.db.global.ShowPrestige; module:RefreshText(); end,
			checked = function() return self.db.global.ShowPrestige; end,
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

function module:HONOR_PRESTIGE_UPDATE()
	module:Refresh();
end
