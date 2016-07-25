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
	text = "Experiencer Text Display",
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

function Addon:UpdateDataBrokerText(text)
	Addon.BrokerModule.text = text;
end
