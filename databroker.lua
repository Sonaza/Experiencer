------------------------------------------------------------
-- Experiencer by Sonaza
-- All rights reserved
-- http://sonaza.com
------------------------------------------------------------

local ADDON_NAME, Addon = ...;
local _;

local LibDataBroker = LibStub("LibDataBroker-1.1");

local settings = {
	type = "data source",
	label = "Experiencer",
	text = "",
	icon = "Interface\\Icons\\Ability_Paladin_EmpoweredSealsRighteous",
	OnClick = function(frame, button)
		if(button == "RightButton") then
			Addon:OpenContextMenu(frame);
		end
	end,
};

function Addon:InitializeDataBroker()
	Addon.BrokerModule = LibDataBroker:NewDataObject("Experiencer", settings);
end

function Addon:UpdateDataBroker()
	local module = Addon:GetActiveModule();
	if(not module) then return end
	
	Addon.BrokerModule.text = module:GetText();
end
