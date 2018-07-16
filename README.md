# Experiencer
Experience bar replacement for World of Warcraft.

## Description
Experiencer is a minimum configuration required experience bar addon. It adds multi purpose experience, reputation, artifact power, honor and conquest progress bar to the bottom or the top of the screen. The bar can also be split in up to three different sections to display multiple data sources simultaneously. 

Note that because the Experiencer bar can **only be anchored to the top or the bottom of the screen** it may overlap with other frames positioned in those places.

When tracking experience the addon will display your current rested percentage, remaining xp required to level and percentage of the same value. Once you start gaining experience it will display the total sum gained during the active session, experience per hour value, estimated time and number of quests to level. Additionally the number of experience points player will gain after turning in all completed quests (and optionally incomplete quests) is displayed with an accompanying visualizer bar. Session values are saved even when you log out, to reset them you must do so from the options menu.

Once you have reached the maximum level experiencer will change to displaying reputation progress. It displays the current level, reputation required to next level and percentage of the same value. By default the Experiencer will also attempt to automatically track the faction with whom you have last gained reputation.

If available Experiencer can also track artifact power, honor and conquest.
* Artifact power tracking will unlock after you gain the Heart of Azeroth.
* Conquest tracking unlocks at level 120.

**Note!** Experiencer *will not* hide the existing experience bar by Blizzard and you need to use a separate addon to do that. Usually an action bar replacement addon (Dominos or Bartender) will allow you to hide it and using one with this addon is recommended anyway.

By default the bar is colored the class color of the character you are playing but it can be changed in the options.

Experiencer also adds a DataBroker module that displays current text if you wish to place it elsewhere. To freely place it anywhere check out my DataBroker display addon [Candy](http://www.curse.com/addons/wow/candy). In case Experiencer is split in to more than one section the left most bar will be used as the data source for DataBroker text.

### Usage and Shortcuts

Experiencer options can be accessed by right clicking the bar or the DataBroker module. In order to make things smoother there are a few useful shortcuts.

* Control left-click toggles bar visiblity. There will always be a slightly translucent black bar where the bar is anchored.
* Middle-click toggles text visibility if text is not set to be always hidden.
* Holding control while scrolling with mouse wheel lets you browse through available bars in following order: experience, reputation, artifact power and honor.
* Shift left-click pastes current statistics to chat editbox. Shift control left-click for quick paste.

* **Reputation:** Holding shift while scrolling with mouse wheel over reputation bar will cycle through recent reputations.

## Dependencies
Experiencer uses Ace3, LibSharedMedia and LibDataBroker which are included in the /libs directory.
