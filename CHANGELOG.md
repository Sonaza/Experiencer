## 2.2.1
* Fixed reputation module paragon reputations after reaching reward level.

## 2.2.0
* Added new keybind for artifact bar: Shift + Middle Mouse will now open artifact talent window while artifact module is active.
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
