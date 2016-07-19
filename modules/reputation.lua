------------------------------------------------------------
-- Experiencer by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME, Addon = ...;
local _;

local module = {};
Addon:RegisterModule("reputation", module);

module.savedvars = {
	char = {
		
	},
	global = {
		ShowGainedRep = true,
		AutoWatch = {
			Enabled = false,
			IgnoreGuild = true,
			IgnoreInactive = true,
			IgnoreBodyguard = true,
		},
	},
};

module.recentReputations = {};

local BODYGUARD_FACTIONS = {
	[1738] = "Defender Illona",
	[1740] = "Aeda Brightdawn",
	[1733] = "Delvar Ironfist",
	[1739] = "Vivianne",
	[1737] = "Talonpriest Ishaal",
	[1741] = "Leorajh",
	[1736] = "Tormmok",
};

function module:Initialize()
	module:RegisterEvent("UPDATE_FACTION");
	module:RegisterEvent("CHAT_MSG_COMBAT_FACTION_CHANGE");
end

function module:IsDisabled()
	return false;
end

function module:Update()
	
end

function module:GetText()
	if(not Addon:HasWatchedReputation()) then
		return "No active watched reputation";
	end
	
	local outputText = {};
	
	local rep_text = {};
	
	local name, standing, minReputation, maxReputation, currentReputation, factionID = GetWatchedFactionInfo();
	local remainingReputation = maxReputation - currentReputation;
	
	local progress = (currentReputation - minReputation) / (maxReputation - minReputation);
	local color = Addon:GetProgressColor(progress);
	
	local standingText = "";
	local friendLevel = select(7, GetFriendshipReputation(factionID));
	
	if(not friendLevel) then
		standingText = module:GetStandingColorText(standing);
	else
		standingText = friendLevel;
	end
	
	tinsert(outputText, string.format("%s (%s): %s%s|r (%s%d|r%%)", name, standingText, color, BreakUpLargeNumbers(remainingReputation), color, 100 - progress * 100));
	
	if(self.db.global.ShowGainedRep and module.recentReputations[name]) then
		tinsert(outputText, string.format("+%s |cffffcc00rep|r", BreakUpLargeNumbers(module.recentReputations[name].amount)));
	end
	
	ExperiencerBarText:SetText(table.concat(rep_text, "  "));
	
	return table.concat(outputText, "  ");
end

function module:GetBarData()
	local data    = {};
	
	local name, standing, minReputation, maxReputation, currentReputation, factionID = GetWatchedFactionInfo();
	
	data.min  	  = minReputation;
	data.max  	  = maxReputation;
	data.current  = currentReputation;
	data.rested   = nil;
	data.visual   = nil;
	
	return data;
end

function module:GetOptionsMenu()
	
end

------------------------------------------

function module:HasWatchedReputation()
	return GetWatchedFactionInfo() ~= nil;
end

function module:GetStandingColorText(standing)
	local colors = {
		[1] = {r=0.80, g=0.13, b=0.13}, -- hated
		[2] = {r=1.00, g=0.25, b=0.00}, -- hostile
		[3] = {r=0.93, g=0.40, b=0.13}, -- unfriendly
		[4] = {r=1.00, g=1.00, b=0.00}, -- neutral
		[5] = {r=0.00, g=0.70, b=0.00}, -- friendly
		[6] = {r=0.00, g=1.00, b=0.00}, -- honoured
		[7] = {r=0.00, g=0.60, b=1.00}, -- revered
		[8] = {r=0.00, g=1.00, b=1.00}, -- exalted
	}
	
	return string.format('|cff%02x%02x%02x%s|r', colors[standing].r * 255, colors[standing].g * 255, colors[standing].b * 255, _G['FACTION_STANDING_LABEL' .. standing]);
end

function module:UPDATE_FACTION(event, ...)
	local set_value = false;
	
	local name = GetWatchedFactionInfo();
	if(name and Addon:IsBarEnabled() and not Addon.IsVisible) then
		Addon:ShowBar();
	end
	
	if(name ~= Addon.CurrentRep) then
		set_value = true;
	end
	
	Addon:RefreshBar(set_value);
	Addon.GainUpdateTimer = 0;
end

function module:CHAT_MSG_COMBAT_FACTION_CHANGE(event, message, ...)
	local reputation, amount = message:match("Reputation with (.-) increased by (%d*)%.");
	if(not reputation or not module.recentReputations) then return end
	
	if(module.recentReputations[reputation] == nil) then
		module.recentReputations[reputation] = {
			amount = 0,
		};
	end
	
	module.recentReputations[reputation].amount = module.recentReputations[reputation].amount + amount;
	
	if(self.db.global.AutoWatch.Enabled) then
		if(Addon.CurrentRep ~= reputation) then
			Addon:UpdateAutoWatch(reputation);
		end
	end
end

function module:UpdateAutoWatch(reputation)
	if(self.db.global.AutoWatch.IgnoreGuild and reputation == GUILD) then return end
		
	local factionListIndex, factionID = Addon:GetReputationID(reputation);
	if(not factionListIndex) then return end
	
	if(self.db.global.AutoWatch.IgnoreInactive and IsFactionInactive(factionListIndex)) then return end
	if(self.db.global.AutoWatch.IgnoreBodyguard and BODYGUARD_FACTIONS[factionID] ~= nil) then return end
	
	SetWatchedFactionIndex(factionListIndex);
end
