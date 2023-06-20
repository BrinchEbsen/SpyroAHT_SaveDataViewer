# Spyro: A Hero's Tail - Save Data Veiwer Lua Script for BizHawk
This is a Lua script for CasualPokePlayer's Dolphin branch of BizHawk, you can get it here: https://github.com/CasualPokePlayer/BizHawk/releases.
<br>This was made for the GameCube NTSC version of Spyro: A Hero's Tail.

### Setup
To run the script, open BizHawk's Lua console and open 'SpyroAHT_savedata.lua'. Make sure the other lua files are in the same folder. The hashcodes were mostly copied from https://github.com/eurotools/hashcodes/tree/main/spyro.

This script will push messages to the screen with BizHawk's messages system. I recommend setting the message location to one of the right corners in BizHawk's settings so it doesn't cover up the other text.

### Usage
On the left of the screen will be information about the current map you're in, as well as how many objectives/tasks you've completed in the game.
<br>A message will pop up (and be logged) if an objective has been cleared, or if a task has been added to the tasklist or completed. A completion percentage is also displayed using the same calculation the game itself uses.
<br>Whenever a trigger state gets updated, a message will appear in the console that lists exactly where in the BitHeap the update occoured, as well as which trigger initiated the change.

There's a window with tickboxes for updating various information, so you can focus on the ones you want.
<br>By default, updating the triggerstates is turned off, as it hitches the game quite a bit when updating and is only useful in some cases.

You can make the script render points to the screen that show the location of triggers in the world. You can also click on the points to print information about that trigger. Otherwise you can also just type "printTrigger(index)" into the console, "index" being the trigger's index listed next to the point on-screen.
<br>The text can overlap quite a bit, so you can also filter the trigger types to only render those you want.

You can make the script print various info to the Lua console by clicking a button in the "Print to console" window:
<br>"Player State" -> Print various basic information about the current save file.
<br>"Map Info" -> Print information about all the game's maps.
<br>"Objectives" -> Print the table of game objectives.
<br>"Tasks" -> Print the tasklist entries.
<br>"Mini-Maps" -> Print a bunch of ASCII representations of the minimaps' fog-of-war that has been uncovered.
<br>"Triggerlist" -> Print a simplified list of all the triggers in the level.

By ticking "Display Minimap in Console" the script will update the minimap ASCII representation of the current map in the console, as long as minimaps are set to update.

You can cycle through level startpoints using the arrow keys. Up will increase the startpoint number, Down will decrease it. Left/Right will swap between using hashcodes and simply counting from 0 (used to respawn at shop pads). The checkpoint for a level will be 0xFFFFFFFF if one hasn't yet been set.

### Public Functions
These are functions you can type into the Lua console to test things in real-time.
<br><br>setObjective(hash): Sets the objective with the given hashcode (for example "setObjective(0x44000032)").
<br><br>resetObjective(hash): Resets the objective with the given hashcode (for example "resetObjective(0x44000032)").
<br><br>getBitHeapBit(index): Returns the value of the bit at the given BitHeap index (either 0 or 1).
<br><br>setBitHeapBit(index, value): Sets the bit at the given BitHeap index to the given value (either 0 or 1).
<br><br>setStartPoint(hash): Sets the current map's startpoint to the given startpoint hashcode.
<br><br>tpToTrigger(index): Sets the player's position equal to the position of the trigger with the given index. Might not be able to move the player through walls.
<br><br>printTrigger(index): Prints various information about the trigger with the given index. Same as clicking on the point on the screen representing the trigger's position.
