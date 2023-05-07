# Spyro: A Hero's Tail - Save Data Veiwer Lua Script for BizHawk
This is a Lua script for CasualPokePlayer's Dolphin branch of BizHawk, you can get it here: https://github.com/CasualPokePlayer/BizHawk/releases.
<br>This was made for the GameCube NTSC version of Spyro: A Hero's Tail.

### Setup
To run the script, open BizHawk's Lua console and open 'SpyroAHT_savedata.lua'. Make sure the other lua files are in the same folder, as these contain hashcode numbers the game uses to identify assets. These were mostly copied from https://github.com/eurotools/hashcodes/tree/main/spyro.

This script will push messages to the screen with BizHawk's messages system. I recommend setting the message location to one of the right corners in BizHawk's settings so it doesn't cover up the other text.

### Usage
On the left of the screen will be information about the current map you're in, as well as how many objectives/tasks you've completed in the game.
<br>A message will pop up (and be logged) if an objective has been cleared, or if a task has been added to the tasklist or completed. A completion percentage is also displayed using the same calculation the game itself uses.
<br>Whenever a trigger state gets updated, a message will appear in the console that lists exactly where in the BitHeap the update occoured.

There's a window with tickboxes for updating various information, so you can focus on the ones you want.
<br>By default, updating the triggerstates is turned off, as it hitches the game quite a bit when updating and isn't terribly useful at the moment.

You can make the script print various info to the Lua console by clicking a button in the "Print to console" window:
<br>"Player State" -> Print various basic information about the current save file.
<br>"Map Info" -> Print information about all the game's maps.
<br>"Objectives" -> Print the table of game objectives.
<br>"Tasks" -> Print the tasklist entries.
<br>"Mini-Maps" -> Print a bunch of ASCII representations of the minimaps' fog-of-war that has been uncovered.

By ticking "Display Minimap in Console" the script will update the minimap ASCII representation of the current map in the console.

There are public functions to set/reset objectives. Type setObjective(hash) or resetObjective(hash) into the Lua console, with the argument being the hashcode of the objective you want to modify (in hex, for example '0x44000032'). This will always spit back an error, but it will still work.

You can cycle through level startpoints using the arrow keys. Up will increase the startpoint number, Down will decrease it. Left/Right will swap between using hashcodes and simply counting from 0 (used to respawn at shop pads). The checkpoint for a level will be 0xFFFFFFFF if one hasn't yet been set.
