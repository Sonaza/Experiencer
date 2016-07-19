------------------------------------------------------------
-- Experiencer by Sonaza
-- All rights reserved
-- http://sonaza.com
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
	if(Addon.IsVisible) then
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