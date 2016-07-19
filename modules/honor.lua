------------------------------------------------------------
-- Experiencer by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME, Addon = ...;
local _;

local module = {};
Addon:RegisterModule("honor", module);

module.recentReputations = {};

function module:Initialize()
	
end

function module:IsDisabled()
	return false;
end

function module:Update()
	
end

function module:GetText()
	local outputText = {};
	
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
