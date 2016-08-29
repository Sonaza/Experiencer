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