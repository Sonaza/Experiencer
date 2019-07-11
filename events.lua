------------------------------------------------------------
-- Experiencer by Sonaza (https://sonaza.com)
-- Licensed under MIT License
-- See attached license text in file LICENSE
------------------------------------------------------------

local ADDON_NAME, Addon = ...;
local _;

function Addon:PLAYER_REGEN_DISABLED()
	CloseMenus();
end

function Addon:UNIT_AURA()
	Addon:RefreshBar();
end

local hiddenForPetBattle = false;

function Addon:PET_BATTLE_OPENING_START(event)
	if(ExperiencerFrameBars:IsVisible()) then
		hiddenForPetBattle = true;
		Addon:HideBar();
	end
end

function Addon:PET_BATTLE_CLOSE(event)
	if(hiddenForPetBattle) then
		Addon:ShowBar();
	end
	
	hiddenForPetBattle = false;
end