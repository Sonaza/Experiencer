------------------------------------------------------------
-- Experiencer by Sonaza (https://sonaza.com)
-- Licensed under MIT License
-- See attached license text in file LICENSE
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
	if (Addon.BrokerModule ~= nil) then
		Addon.BrokerModule.text = text;
	end
end
