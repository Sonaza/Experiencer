------------------------------------------------------------
-- Experiencer by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME, Addon = ...;
local _;

local module = Addon:NewModule("artifact");

module.name     = "Artifact";
module.order    = 4;

function module:Initialize()
	
end

function module:IsDisabled()
	return true;
end

function module:Update(elapsed)
	
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
