# Spyro: A Hero's Tail - Save Data Veiwer Lua Script for BizHawk
This is a Lua script for CasualPokePlayer's Dolphin branch of BizHawk, you can get it here: https://tasvideos.org/Forum/Topics/23347.
<br>This was made for the GameCube NTSC version of Spyro: A Hero's Tail.

### Setup
To run the script, open BizHawk's Lua console and open 'SpyroAHT_savedata.lua'. Make sure 'SpyroAHT_hashcodes.lua' is in the same folder, as this contains hashcode numbers the game uses to identify assets. These were copied from https://github.com/eurotools/hashcodes/blob/main/spyro/albert/hashcodes.h.

This script will push messages to the screen with BizHawk's messages system. I recommend setting the message location to one of the right corners in BizHawk's settings so it doesn't cover up the other text.

### Usage
On the left of the screen will be information about the current map you're in, as well as how many objectives/tasks you've completed in the game.
<br>A message will pop up (and be logged) if an objective has been cleared, or if a task has been added to the tasklist or completed.

You can make the script print various info to the Lua console by pressing a key:
<br>'K' -> Print information about all the game's maps.
<br>'L' -> Print the table of game objectives.
<br>'O' -> Print the tasklist entries.
<br>Make sure to edit the keys (listed at the very top of the script) if it conflicts with other hotkeys you've set.

There are public functions to set/reset objectives. Type setObjective(hash) or resetObjective(hash) into the Lua console, with the argument being the hashcode of the objective you want to modify (in hex, for example '0x44000032'). This will always spit back an error, but it will still work.

You can cycle through level startpoints using the arrow keys. Up will increase the startpoint number, Down will decrease it. Left/Right will swap between using hashcodes and simply counting from 0 (used to respawn at shop pads). The checkpoint for a level will be 0xFFFFFFFF if one hasn't yet been set.
