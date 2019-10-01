## 3.1.3
* Actually really probably maybe fixed the artifact module getting randomly disabled.

## 3.1.2
* Fixed artifact module getting randomly disabled when changing zones.

## 3.1.1
* Fixed changed Recruit-A-Friend check function call. Can't find specs on the level ranges so now it just calculates bonuses for anything up to level 120.
* Fixed initial game load spouting total garbage values for everything, causing the addon think some bars were inactive/disabled. Selected bars shouldn't reset on game startup now.
* Updated Ace3 dependencies.

## 3.1.0
* Patch 8.2.5.
* Fixed modules attempting to use resources before their initialization.

## 3.0.6
* Patch 8.2.0.
* Attempted blind fix for artifact module GetItemInfo error.

## 3.0.5
* Fixed reputation module menu not properly changing reputations.
* Fixed xp visualizer calculating experience rewards for hidden quests.
* Added option to include the XP from account wide quests (pet battles). Disabled by default considering most players probably aren't doing these quests to level up.
* Fixed heirloom and Recruit-a-Friend XP multipliers.

## 3.0.4
* Added counter that shows amount of Artifact Power gained in current session.
* Fixed bug where Experiencer bars would still show when map was maximized.

## 3.0.3
* Fixed yesterday's fix that broke everything.

## 3.0.2
* Fixed update issues with reputation bar while auto watch is enabled.

## 3.0.1
* Now auto watch automatically tracks reputation with largest gain when multiple reputations are earned at same time.

## 3.0.0
* Updated for Battle for Azeroth.
* Artifact module now tracks Heart of Azeroth once player receives it.
* Honor module tracks current honor level progress. Prestige has been removed.
* New conquest module tracks conquest reward track progress once player reaches level 120.

## 2.4.1
* Fixed artifact module text with overloaded artifacts.

## 2.4.0
* TOC bump for patch 7.3.0.
* Updated artifact module to support tallying Artifact Power tokens that reward billions of AP. Support is lacking for Spanish and Russian localizations (and the rest are Google translated and may be incorrect anyway).
* Fixed guild reputation name in recent reputations list.

## 2.3.1
* Added a new keybind for honor bar: Shift middle-click will now toggle honor talents frame or FlashTalent (separate addon) honor talent window if it is installed.
* Fixed artifact module causing hangs in loading screen. This time it should work (famous last words).
* Fixed reputation options menu generation on characters with unusual API response.
* Added current reputation values to reputation menu.

## 2.3.0
* You can now split Experiencer bar in up to three different sections allowing you to display more information at once.
  * DataBroker module will continue sourcing its text label from the leftmost bar.
* Reputation module now supports scrolling recent reputations by holding down shift key and scrolling mouse wheel.
* Added abbreviation for large number values for artifact bar. This is enabled by default but can optionally be disabled in artifact bar options.
* Added support for shared media fonts and optional font scaling. You can now change font face and scale via frame options menu.
* Attempted fix for hangs in loading screens due to artifact module.

## 2.2.1
* Fixed reputation module paragon reputations after reaching reward level.

## 2.2.0
* Added new keybind for artifact bar: Shift middle-click will now open artifact talent window while artifact module is active.
* Reputation module now supports paragon reputations.
* Fixed weird bar animations.

## 2.1.3
* Fixed debug related bug left in the previous version.

## 2.1.2
* Fixed AP counter not calculating millions properly.
* Fixed quest XP visualization bar not updating when picking up or abandoning quests.

## 2.1.1
* Fixed one more bug introduced by the recent patch.

## 2.1.0
* Merged artifact bar fix submitted by Superfat72. Thanks!
* TOC bump for patch 7.2.0.

## 2.0.11
* Fixed nil error with artifact power inventory scanner.
* TOC bump for patch 7.1.0.

## 2.0.10
* Fixed options menu not working if player had discovered Conjurer Margoss reputation.
* Added display of currently unspent artifact power tokens in player inventory.
* Total artifact power text now displays the spent and currently accumulated power instead of spent only.
* Fixed artifact power level up animation.
* Number of unspent trait points available for an artifact is now calculated in the total rank number.
* Honor chat message now tells remaining honor instead of percentage.

## 2.0.9
* Improvements to artifact bar text.

## 2.0.8
* Fixed error when viewing artifact bar without an artifact weapon equipped.

## 2.0.7
* Fixed chat message error with artifact weapons.
* Fixed flashing bar with artifact weapon level up.
* Added information about total artifact power and unspent points for the artifact bar.
* Fixed animating bar sometimes scrolling about even when it wasn't supposed to.

## 2.0.6
* Changed bar updates to be buffered to make several consequential gains update properly.
* Made animations even nicer.
* Fixed percentage showing remaining number instead of current value when using current & max value text mode.
* Fixed text not updating when resetting experience session.

## 2.0.5
* Clamp drop down menu within screen area.
* Fixed experience bar for when expansion releases (to work without relogin or reload, obviously untested though).

## 2.0.4
* Fixed bug with experience module when reaching level cap.

## 2.0.3
* Attempted fix to reputation animation not playing for first reputation gain after login.
* Fixed error with animation speed when leveling up.

## 2.0.2
* Fixed the small gap when anchoring to the top of the screen.

## 2.0.1
* Fixed reputation module glitchiness when not tracking any reputations.

## 2.0.0
* Legion update
	* The addon has been practically rewritten and previously configured settings are unfortunately lost. You can reconfigure settings by right clicking the Experiencer bar.
	* Keybindings have changed:
		* Control left-click now toggles visiblity.
		* Shift left-click and shift control left-click send current stats to chat.
		* Holding control while using mousewheel will scroll through available bars in following order: experience, reputation, artifact power and honor.
	* Added support for Honor and Artifact Power.
	* You can now choose custom bar color from the options. This color will be shared globally across all of your characters.
	* Options menu has been restructured; now each bar has its own submenu.
	* The visual look of the bar has been improved with flashier animations and more.
	* Added a DataBroker module for the display of current text. Right clicking the DataBroker module will open options menu.
	* Disclaimer: honor and artifact power modules have not actually been tested (because I do not have beta).
