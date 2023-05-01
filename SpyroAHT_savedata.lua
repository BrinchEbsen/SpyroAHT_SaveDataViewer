console.clear()
memory.usememorydomain("RAM")

local geoHashes = require("SpyroAHT_objlist_geoDef")
local EXHashcodes = require("SpyroAHT_hashcodes")
local ESHashcodes = require("SpyroAHT_soundhashes")
local BH_MiniMapSizes = require("SpyroAHT_BH_MiniMapSizes")

local doObjectives = true
local doTasks = true
local doMinimaps = true
local doTriggerstates = true

--Table that holds save data
local gGameState			   = 0x463b38
local gGameState_PlayerState   = gGameState + 0x2018 -- = 0x465B50
local gGameState_Objectives	   = gGameState + 0x2150 -- = 0x465C88
local gGameState_Tasks		   = gGameState + 0x2190 -- = 0x465CC8
local gGameState_Minimaps	   = gGameState + 0x21AC -- = 0x465CE4
local gGameState_Triggerstates = gGameState + 0x27AE -- = 0x4662E6
local gGameState_MapStates	   = gGameState + 0x6434 -- = 0x469F6C

local bitHeapSize               = 0x4000 -- 0x465CE4 to 0x469F76
local bitHeapSize_Used          = 0x10CC -- 0x465CE4 to 0x466DB0
local bitHeapSize_Minimaps      = 0x602  -- 0x465CE4 to 0x4662E6
local bitHeapSize_Triggerstates = 0xACA  -- 0x4662E6 to 0x466DB0

local currMinimapBlock = memory.read_bytes_as_array(gGameState_Minimaps, bitHeapSize_Minimaps)
local lastMinimapBlock = memory.read_bytes_as_array(gGameState_Minimaps, bitHeapSize_Minimaps)
local currTriggerStateBlock = memory.read_bytes_as_array(gGameState_Triggerstates, bitHeapSize_Triggerstates)
local lastTriggerStateBlock = memory.read_bytes_as_array(gGameState_Triggerstates, bitHeapSize_Triggerstates)

local playerState
local playerStateSize = 0x94

local currPlayerStateHash = memory.hash_region(gGameState_PlayerState, playerStateSize)
local lastPlayerStateHash = 0

local MinimapBitsTotal = 0
for k, v in ipairs(BH_MiniMapSizes) do
	MinimapBitsTotal = MinimapBitsTotal + v.Size
end

local MinimapHeap = {}

local currMinimapHash = memory.hash_region(gGameState_Minimaps, bitHeapSize)
local lastMinimapHash = 0

local currTriggerStateHash = memory.hash_region(gGameState_Triggerstates, bitHeapSize_Triggerstates)
local currTriggerStateHash = 0

local gpCurrentMap = 0x4CB60C
local gNumMaps = 0x4cb608
local gMapList = 0x46EE54
local currentMap = bit.band(memory.read_u32_be(gpCurrentMap), 0xFFFFFF)
local numberOfMaps = memory.read_u32_be(gNumMaps)-1

local currInput = {}
local lastInput = {}

local objectives = {}
local numOfObjectives = 0x200
local objectiveTableSize = numOfObjectives/0x20
local objectivesCleared = 0

local tasks = {}
local numOfTasks = 0x50
local taskTableSize = numOfTasks/0x10
local tasksFound = 0
local tasksCleared = 0

local taskStates = {
	[0] = "   ", --Invisible, Not done
	[1] = "[ ]", --Visible,   Not done
	[2] = "[?]", --Invisible, Done (impossible normally)
	[3] = "[X]"  --Visible,   Done
}

local mapList = {}
local mapStates = {}
local mapStatesBlockSize = 0x64

local currObjectiveHash = 0
local lastObjectiveHash = 0

local currTaskHash = 0
local lastTaskHash = 0

local currMapStateHash = {}
local lastMapStateHash = {}

local eggNames = {
	[1] = "Concept Art",
	[2] = "Model Viewer",
	[3] = "Ember",
	[4] = "Flame",
	[5] = "Sgt. Byrd",
	[6] = "Spyro Turret",
	[7] = "Sparx",
	[8] = "Blink"
}

local textOffset = 0
local textAreaWidth = 350
client.setwindowsize(1)
client.SetClientExtraPadding(textAreaWidth, 0, 0, 0)
gui.use_surface("client")

--TOGGLES WINDOW
forms.destroyall()
local togglesWindow = forms.newform(150, 150, "Toggles")
forms.setlocation(togglesWindow, client.xpos()+client.screenwidth(), client.ypos())

local labelUpdate = forms.label(togglesWindow, "Update:", 2, 5, 150, 14)

local checkObjectives = forms.checkbox(togglesWindow, "Objectives", 2, 25)
forms.setproperty(checkObjectives, "Checked", true)

local checkTasks = forms.checkbox(togglesWindow, "Tasks", 2, 45)
forms.setproperty(checkTasks, "Checked", true)

local checkMinimaps = forms.checkbox(togglesWindow, "Mini-Maps", 2, 65)
forms.setproperty(checkMinimaps, "Checked", true)

local checkTriggerstates = forms.checkbox(togglesWindow, "Trigger-States", 2, 85)
--forms.setproperty(checkTriggerstates, "Checked", true)

local labelShowMiniMap = forms.label(togglesWindow, "Display Minimap in Console:", 2, 110, 150, 14)
local checkShowMiniMap = forms.checkbox(togglesWindow, "Enable", 2, 125)

function table.shallow_copy(t)
  local t2 = {}
  for k,v in pairs(t) do
    t2[k] = v
  end
  return t2
end

function setObjective(o)
	local o_bit_index = bit.band(o, 0xFFFFFF)-1
	if o_bit_index > 0x200 then
		console.clear()
		console.log("Invalid objective hash!")
		return
	end
	local o_bit = bit.band(o_bit_index, 0x1f)
	local o_index = bit.rshift(o_bit_index, 5)
	
	local c = memory.read_u32_be(gGameState_Objectives + (o_index * 4))
	memory.write_u32_be(gGameState_Objectives + (o_index * 4), bit.bor(c, bit.lshift(1, o_bit)))
	
	console.clear()
	console.log("Set objective 0x" .. bizstring.hex(o))
end

function resetObjective(o)
	local o_bit_index = bit.band(o, 0xFFFFFF)-1
	if o_bit_index > 0x200 then
		console.clear()
		console.log("Invalid objective hash!")
		return
	end
	local o_bit = bit.band(o_bit_index, 0x1f)
	local o_index = bit.rshift(o_bit_index, 5)
	
	local c = memory.read_u32_be(gGameState_Objectives + (o_index * 4))
	if not bit.check(c, o_bit) then
		console.clear()
		console.log("Objective already not set.")
		return
	end
	memory.write_u32_be(gGameState_Objectives + (o_index * 4), bit.bxor(c, bit.lshift(1, o_bit)))
	
	console.clear()
	console.log("Reset objective 0x" .. bizstring.hex(o))
end

local function getPlayTime(i)
	return {
		Seconds = math.floor(i % 60),
		Minutes = math.floor((i / 60) % 60),
		Hours   = math.floor((i / 60) / 60)
	}
end

local function isBitSet(byteTable, index)
    local byteIndex = math.floor(index / 8) + 1
    local bitPos = index % 8
    
	return bit.check(byteTable[byteIndex], bitPos)
end

local function stringPad(s, targetLen)
    local sLen = string.len(s)
    if sLen >= targetLen then return s end

    return s .. string.rep(" ", targetLen - sLen)
end

local function convertByteArrayToIntArray(inputArray, arraySize)
	local intArraySize = arraySize/4
	local outputArray = {}
	
	for i = 0, intArraySize-1 do
		local index = i*4
		outputArray[i+1] = inputArray[index+1]*0x1000000 + inputArray[index+2]*0x10000 + inputArray[index+3]*0x100 + inputArray[index+4]
	end
	
	return outputArray
end

--INIT
local function initPlayerState()
	playerState = {
		dateYear              = memory.read_u16_be(gGameState_PlayerState),
		dateMonth             = memory.read_u8(    gGameState_PlayerState + 0x2),
		dateDay               = memory.read_u8(    gGameState_PlayerState + 0x3),
		dateHour              = memory.read_u8(    gGameState_PlayerState + 0x4),
		dateMinute            = memory.read_u8(    gGameState_PlayerState + 0x5),
		dateSecond            = memory.read_u8(    gGameState_PlayerState + 0x6),
		playTime              = memory.readfloat(  gGameState_PlayerState + 0x8, true),
		breathSelected        = memory.read_u32_be(gGameState_PlayerState + 0x10),
		health                = memory.read_u32_be(gGameState_PlayerState + 0x14),
		gemCount              = memory.read_u32_be(gGameState_PlayerState + 0x18),
		lockPickCount         = memory.read_u8(    gGameState_PlayerState + 0x20),
		lockPickLimit         = memory.read_u8(    gGameState_PlayerState + 0x21),
		ammoFire = {          
			amount            = memory.read_u8(    gGameState_PlayerState + 0x24),
			carryLimit        = memory.read_u8(    gGameState_PlayerState + 0x25),
			magLimit          = memory.read_u8(    gGameState_PlayerState + 0x26),
			magAmount         = memory.read_u8(    gGameState_PlayerState + 0x27)
		},                    
		ammoIce = {           
			amount            = memory.read_u8(    gGameState_PlayerState + 0x28),
			carryLimit        = memory.read_u8(    gGameState_PlayerState + 0x29),
			magLimit          = memory.read_u8(    gGameState_PlayerState + 0x2A),
			magAmount         = memory.read_u8(    gGameState_PlayerState + 0x2B)
		},                    
		ammoWater = {         
			amount            = memory.read_u8(    gGameState_PlayerState + 0x2C),
			carryLimit        = memory.read_u8(    gGameState_PlayerState + 0x2D),
			magLimit          = memory.read_u8(    gGameState_PlayerState + 0x2E),
			magAmount         = memory.read_u8(    gGameState_PlayerState + 0x2F)
		},                    
		ammoElectric = {      
			amount            = memory.read_u8(    gGameState_PlayerState + 0x30),
			carryLimit        = memory.read_u8(    gGameState_PlayerState + 0x31),
			magLimit          = memory.read_u8(    gGameState_PlayerState + 0x32),
			magAmount         = memory.read_u8(    gGameState_PlayerState + 0x33)
		},                    
		fireArrows            = memory.read_u16_be(gGameState_PlayerState + 0x34),
		fireArrowsLimit       = memory.read_u16_be(gGameState_PlayerState + 0x36),
		playerFlags           = memory.read_u32_be(gGameState_PlayerState + 0x38),
		blinkCooldown         = memory.readfloat(  gGameState_PlayerState + 0x3C, true),
		superchargeCooldown   = memory.readfloat(  gGameState_PlayerState + 0x40, true),
		invincibilityCooldown = memory.readfloat(  gGameState_PlayerState + 0x48, true),
		cooldownLimit         = memory.readfloat(  gGameState_PlayerState + 0x4C, true),
		sgtByrdBoost          = memory.readfloat(  gGameState_PlayerState + 0x58, true),
		sgtByrdBombs          = memory.read_u16_be(gGameState_PlayerState + 0x5C),
		sgtByrdMissiles       = memory.read_u16_be(gGameState_PlayerState + 0x5E),
		lightGemAmount        = memory.read_u8(    gGameState_PlayerState + 0x66),
		darkGemAmount         = memory.read_u8(    gGameState_PlayerState + 0x67),
		dragonEggAmount       = memory.read_u8(    gGameState_PlayerState + 0x68),
		playerSpawnX          = memory.readfloat(  gGameState_PlayerState + 0x70, true),
		playerSpawnY          = memory.readfloat(  gGameState_PlayerState + 0x74, true),
		playerSpawnZ          = memory.readfloat(  gGameState_PlayerState + 0x78, true),
		playerSpawnPitch      = memory.readfloat(  gGameState_PlayerState + 0x80, true),
		playerSpawnYaw        = memory.readfloat(  gGameState_PlayerState + 0x84, true),
		playerSpawnRoll       = memory.readfloat(  gGameState_PlayerState + 0x88, true),
		characterUI           = memory.read_u32_be(gGameState_PlayerState + 0x90)
	}
end

local function initMapGlobals()
	for i = 0, numberOfMaps do
		local cur = bit.band(memory.read_u32_be(gMapList + (i * 0x4)), 0xFFFFFF)
		mapList[i] = {}
		
		mapList[i].addr = cur
		mapList[i].realm_nr = memory.read_u32_be(cur + 0x8C)
		mapList[i].level_nr = memory.read_u32_be(cur + 0x90)
		mapList[i].sbHash = ESHashcodes[memory.read_u32_be(cur + 0xB0)]
		mapList[i].levelID = memory.read_u32_be(cur + 0xC8)
		mapList[i].geoHash = memory.read_u32_be(cur + 0xDC)
		mapList[i].thing = memory.read_u32_be(cur + 0xf0)
		mapList[i].filename = geoHashes[mapList[i].geoHash]
		mapList[i].filehash = EXHashcodes[mapList[i].geoHash]
	end
end

local function initMapStates()
	for i = 0, 200 do
		local cur = gGameState_MapStates + (i * mapStatesBlockSize)
		local block = convertByteArrayToIntArray(memory.read_bytes_as_array(cur, mapStatesBlockSize), mapStatesBlockSize)
		
		currMapStateHash[i] = memory.hash_region(cur, mapStatesBlockSize)
		lastMapStateHash[i] = currMapStateHash[i]
		
		mapStates[i] = {}
		
		mapStates[i].startpoint = block[1]
		
		if (block[3] ~= 0xFFFFFFFF) and (block[4] ~= 0xFFFFFFFF) and (block[5] ~= 0xFFFFFFFF) then
			mapStates[i].totalDG = block[3]
			mapStates[i].totalDE = block[4]
			mapStates[i].totalLG = block[5]
		else
			mapStates[i].totalDG = 0
			mapStates[i].totalDE = 0
			mapStates[i].totalLG = 0
		end
		
		mapStates[i].tallyDG = block[13]
		mapStates[i].tallyLG = block[14]
		
		mapStates[i].tallyDE = {}
		mapStates[i].tallyDE[1] = block[15]
		mapStates[i].tallyDE[2] = block[16]
		mapStates[i].tallyDE[3] = block[17]
		mapStates[i].tallyDE[4] = block[18]
		mapStates[i].tallyDE[5] = block[19]
		mapStates[i].tallyDE[6] = block[20]
		mapStates[i].tallyDE[7] = block[21]
		mapStates[i].tallyDE[8] = block[22]
		
		mapStates[i].tallyDE.all = 0
		for j = 1, 8 do
			mapStates[i].tallyDE.all = mapStates[i].tallyDE.all + mapStates[i].tallyDE[j]
		end
	end
end

local function initObjectives()
	for i = 1, numOfObjectives do
		objectives[i] = {}
		objectives[i].Name = ""
		objectives[i].State = false
		objectives[i].Index = 0x0
		objectives[i].Bit = 0
	end
end

local function initTasks()
	for i = 1, numOfTasks do
		tasks[i] = {}
		tasks[i].Name = ""
		tasks[i].State = 0
		tasks[i].Index = 0x0
		tasks[i].Bit = 0
	end
end

local function initMiniMaps()
	local index = 0
	
	for k, v in ipairs(BH_MiniMapSizes) do
		MinimapHeap[k] = {}
		
		for i = 0, v.Size do
			local y = math.floor(i / v.X) + 1
			if not MinimapHeap[k][y] then
				MinimapHeap[k][y] = {}
			end
			local x = (i % v.X) + 1
			
			if isBitSet(currMinimapBlock, i+index) then
				MinimapHeap[k][y][x] = true
			else
				MinimapHeap[k][y][x] = false
			end
		end
		
		index = index + v.Size
	end
end

--PRINT
local function printPlayerStateToConsole()
	local padLen = 24
	local str = ""
	
	str=str..stringPad("Date:", padLen)..tostring(playerState.dateDay)
	.."/"..tostring(playerState.dateMonth)
	.."/"..tostring(playerState.dateYear)
	..", "..tostring(playerState.dateHour)
	..":"..tostring(playerState.dateMinute)
	..":"..tostring(playerState.dateSecond).."\n"
	
	str=str..stringPad("Played:", padLen)
	     ..tostring(getPlayTime(playerState.playTime).Hours)
	..":"..tostring(getPlayTime(playerState.playTime).Minutes)
	..":"..tostring(getPlayTime(playerState.playTime).Seconds).."\n\n"
	
	local breaths = {
		[1] = "Fire",
		[2] = "Water",
		[4] = "Ice",
		[8] = "Electricity"
	}
	
	if breaths[playerState.breathSelected] then
		str=str..stringPad("Breath Selected:", padLen)..breaths[playerState.breathSelected].."\n"
	else
		str=str..stringPad("Breath Selected:", padLen).."None"
	end
	
	str=str..stringPad("Health:", padLen)..tostring(playerState.health).."\n"
	str=str..stringPad("Gems:", padLen)..tostring(playerState.gemCount).."\n"
	str=str..stringPad("Lockpicks:", padLen)..tostring(playerState.lockPickCount)
	.."/"..tostring(playerState.lockPickLimit).."\n\n"
	
	str=str.."Ammo:\n"
	str=str..stringPad("   Fire:", padLen)
	..stringPad("Amt: "..tostring(playerState.ammoFire.amount)
	.."/"              ..tostring(playerState.ammoFire.carryLimit), 10).." | "
	.."Mag: "          ..tostring(playerState.ammoFire.magAmount)
	.."/"              ..tostring(playerState.ammoFire.magLimit).."\n"
	str=str..stringPad("   Ice:", padLen)
	..stringPad("Amt: "..tostring(playerState.ammoIce.amount)
	.."/"              ..tostring(playerState.ammoIce.carryLimit), 10).." | "
	.."Mag: "          ..tostring(playerState.ammoIce.magAmount)
	.."/"              ..tostring(playerState.ammoIce.magLimit).."\n"
	str=str..stringPad("   Water:", padLen)
	..stringPad("Amt: "..tostring(playerState.ammoWater.amount)
	.."/"              ..tostring(playerState.ammoWater.carryLimit), 10).." | "
	.."Mag: "          ..tostring(playerState.ammoWater.magAmount)
	.."/"              ..tostring(playerState.ammoWater.magLimit).."\n"
	str=str..stringPad("   Electric:", padLen)
	..stringPad("Amt: "..tostring(playerState.ammoElectric.amount)
	.."/"              ..tostring(playerState.ammoElectric.carryLimit), 10).." | "
	.."Mag: "          ..tostring(playerState.ammoElectric.magAmount)
	.."/"              ..tostring(playerState.ammoElectric.magLimit).."\n\n"
	
	str=str..stringPad("Fire Arrows:", padLen)
	..tostring(playerState.fireArrows)
	.."/"..tostring(playerState.fireArrowsLimit).."\n"
	str=str..stringPad("Player Flags:", padLen)
	..bizstring.binary(playerState.playerFlags).."\n"
	
	str=str..stringPad("Blink Laser Cooldown:", padLen)
	..tostring(playerState.blinkCooldown/60).." seconds\n"
	str=str..stringPad("Supercharge Cooldown:", padLen)
	..tostring(playerState.superchargeCooldown/60).." seconds\n"
	str=str..stringPad("Invincibility Cooldown:", padLen)
	..tostring(playerState.invincibilityCooldown/60).." seconds\n"
	str=str..stringPad("Cooldown Limit:", padLen)
	..tostring(playerState.cooldownLimit/60).." seconds\n\n"
	
	str=str..stringPad("Sgt. Byrd Boost:", padLen)
	..tostring(playerState.sgtByrdBoost).."\n"
	str=str..stringPad("Sgt. Byrd Bombs:", padLen)
	..tostring(playerState.sgtByrdBombs).."\n"
	str=str..stringPad("Sgt. Byrd Missiles:", padLen)
	..tostring(playerState.sgtByrdMissiles).."\n\n"
	
	str=str..stringPad("Light Gems:", padLen)
	..tostring(playerState.lightGemAmount).."\n"
	str=str..stringPad("Dark Gems:", padLen)
	..tostring(playerState.darkGemAmount).."\n"
	str=str..stringPad("Dragon Eggs:", padLen)
	..tostring(playerState.dragonEggAmount).."\n\n"
	
	str=str.."Spawn Position:\n"
	str=str..stringPad("   X:", padLen)..tostring(playerState.playerSpawnX).."\n"
	str=str..stringPad("   Y:", padLen)..tostring(playerState.playerSpawnY).."\n"
	str=str..stringPad("   Z:", padLen)..tostring(playerState.playerSpawnZ).."\n"
	str=str..stringPad("   Pitch:", padLen)..tostring(playerState.playerSpawnPitch).."\n"
	str=str..stringPad("   Yaw:", padLen)..tostring(playerState.playerSpawnYaw).."\n"
	str=str..stringPad("   Roll:", padLen)..tostring(playerState.playerSpawnRoll).."\n\n"
	
	local characters = {
		[0] = "None",
		[1] = "Spyro",
		[2] = "Hunter",
		[3] = "Sparx",
		[4] = "Blink",
		[5] = "Sgt. Byrd",
		[6] = "Ball Gadget"
	}
	
	str=str..stringPad("Character UI:", padLen)..characters[playerState.characterUI]
	
	console.clear()
	console.log(str)
end

local function printMapsToConsole()
	local str = ""
	
	str = str .. string.format("Number of Maps: %d\n\n", numberOfMaps)
	for i = 0, numberOfMaps do
		str = str..string.format("Map ID %d:\n", mapList[i].levelID)
		str = str..string.format("  Hash: 0x0%x (%s)\n", mapList[i].geoHash, mapList[i].filename)
		if mapList[i].sbHash then
			str = str.."  SoundBank: " .. mapList[i].sbHash.."\n"
		else
			str = str.."  SoundBank: None\n"
		end
		str = str..string.format("  Base Address: 0x%x\n", mapList[i].addr)
		str = str..string.format("  Realm: %d\n", mapList[i].realm_nr)
		str = str..string.format("  Level: %d\n", mapList[i].level_nr)
		
		if mapStates[i].startpoint ~= 0xFFFFFFFF then
			str = str..string.format("  Startpoint Hash: %x\n", mapStates[mapList[i].levelID].startpoint)
		end
		
		str = str..string.format("  Dark Gems  :  %d/%d\n", mapStates[mapList[i].levelID].tallyDG,mapStates[mapList[i].levelID].totalDG)
		str = str..string.format("  Dragon Eggs:  %d/%d\n", mapStates[mapList[i].levelID].tallyDE.all,mapStates[mapList[i].levelID].totalDE)
		str = str..string.format("  Light Gems :  %d/%d\n", mapStates[mapList[i].levelID].tallyLG,mapStates[mapList[i].levelID].totalLG)
	end
	
	console.clear()
	console.log(str)
end

local function printObjectivesToConsole()
	local divider = "------------------------------------------"
	local str = "Hash       | Index  / Bit   | State | Name\n" .. divider .. "\n"
	
	local amount = 0
	
	for h, o in ipairs(objectives) do
		local sta = ""
		if o.State then sta=sta.."  X  " else sta=sta.."     " end
		
		str = str ..
		"0x"..bizstring.hex(bit.bor(h, 0x44000000)) ..
		" | " ..
		stringPad(string.format("i: 0x%x / b: %d", o.Index, o.Bit), 14) ..
		" | " ..
		sta ..
		" | " ..
		o.Name ..
		"\n"
		
		if o.State then amount = amount + 1 end
	end
	
	str = str..divider.."\nObjectives Cleared: "..tostring(amount)
	
	console.clear()
	console.log(str)
end

local function printTasksToConsole()
	local divider = "----------------------------------------------"
	local str = "Hash       | Index  / Bit   | State | Name\n" .. divider .. "\n"
	
	local found = 0
	local cleared = 0
	
	for h, t in ipairs(tasks) do
		str = str ..
		string.format("0x%x", bit.bor(h, 0x45000000)) ..
		" | " ..
		stringPad(string.format("i: 0x%x / b: %d", t.Index, t.Bit), 14) ..
		" | " ..
		" "..taskStates[t.State].." " ..
		" | " ..
		t.Name ..
		"\n"
		
		if t.State == 1 or t.State == 3 then found=found+1 end
		if t.State == 3 then cleared=cleared+1 end
	end
	
	str = str..divider.."\nTasks Cleared/Found: "..tostring(cleared).."/"..tostring(found)
	
	console.clear()
	console.log(str)
end

local function getPrintMiniMap(map)
	local mapName = BH_MiniMapSizes[map].Name
	local mapX =    BH_MiniMapSizes[map].X
	local mapY =    BH_MiniMapSizes[map].Y
	local str = " "..mapName..string.rep("-", mapX*2-string.len(mapName)).."\n"
	
	for y = mapY, 1, -1 do
		str=str.."|"
		for x = 1, mapX do
			if MinimapHeap[map][y][x] then
				str=str.."XX"
			else
				str=str.."  "
			end
		end
		str=str.."|\n"
	end
	str=str.." "..string.rep("-", mapX*2).."\n"
	
	return str
end

local function printAllMiniMapsToConsole()
	str = ""
	
	for k, v in ipairs(BH_MiniMapSizes) do
		str=str..getPrintMiniMap(k)
	end
	
	console.clear()
	console.log(str)
end

--UPDATE
local function getGameCompletion()
	LG_Count = playerState.lightGemAmount
	DG_Count = playerState.darkGemAmount
	DE_Count = playerState.dragonEggAmount
	local defeatedMechaRed
	if objectives[0x84].State then
		defeatedMechaRed = 1
	else
		defeatedMechaRed = 0
	end
	
	local sum = LG_Count + DG_Count + DE_Count + defeatedMechaRed
	
	return (sum / 221) * 100
end

local function updatePlayerState()
	playerState.dateYear                = memory.read_u16_be(gGameState_PlayerState)
	playerState.dateMonth               = memory.read_u8(    gGameState_PlayerState + 0x2)
	playerState.dateDay                 = memory.read_u8(    gGameState_PlayerState + 0x3)
	playerState.dateHour                = memory.read_u8(    gGameState_PlayerState + 0x4)
	playerState.dateMinute              = memory.read_u8(    gGameState_PlayerState + 0x5)
	playerState.dateSecond              = memory.read_u8(    gGameState_PlayerState + 0x6)
	playerState.playTime                = memory.readfloat(  gGameState_PlayerState + 0x8, true)
	playerState.breathSelected          = memory.read_u32_be(gGameState_PlayerState + 0x10)
	playerState.health                  = memory.read_u32_be(gGameState_PlayerState + 0x14)
	playerState.gemCount                = memory.read_u32_be(gGameState_PlayerState + 0x18)
	playerState.lockPickCount           = memory.read_u8(    gGameState_PlayerState + 0x20)
	playerState.lockPickLimit           = memory.read_u8(    gGameState_PlayerState + 0x21)
	playerState.ammoFire.amount         = memory.read_u8(    gGameState_PlayerState + 0x24)
	playerState.ammoFire.carryLimit     = memory.read_u8(    gGameState_PlayerState + 0x25)
	playerState.ammoFire.magLimit       = memory.read_u8(    gGameState_PlayerState + 0x26)
	playerState.ammoFire.magAmount      = memory.read_u8(    gGameState_PlayerState + 0x27)
	playerState.ammoIce.amount          = memory.read_u8(    gGameState_PlayerState + 0x28)
	playerState.ammoIce.carryLimit      = memory.read_u8(    gGameState_PlayerState + 0x29)
	playerState.ammoIce.magLimit        = memory.read_u8(    gGameState_PlayerState + 0x2A)
	playerState.ammoIce.magAmount       = memory.read_u8(    gGameState_PlayerState + 0x2B)
	playerState.ammoWater.amount        = memory.read_u8(    gGameState_PlayerState + 0x2C)
	playerState.ammoWater.carryLimit    = memory.read_u8(    gGameState_PlayerState + 0x2D)
	playerState.ammoWater.magLimit      = memory.read_u8(    gGameState_PlayerState + 0x2E)
	playerState.ammoWater.magAmount     = memory.read_u8(    gGameState_PlayerState + 0x2F)
	playerState.ammoElectric.amount     = memory.read_u8(    gGameState_PlayerState + 0x30)
	playerState.ammoElectric.carryLimit = memory.read_u8(    gGameState_PlayerState + 0x31)
	playerState.ammoElectric.magLimit   = memory.read_u8(    gGameState_PlayerState + 0x32)
	playerState.ammoElectric.magAmount  = memory.read_u8(    gGameState_PlayerState + 0x33)
	playerState.fireArrows              = memory.read_u16_be(gGameState_PlayerState + 0x34)
	playerState.fireArrowsLimit         = memory.read_u16_be(gGameState_PlayerState + 0x36)
	playerState.playerFlags             = memory.read_u32_be(gGameState_PlayerState + 0x38)
	playerState.blinkCooldown           = memory.readfloat(  gGameState_PlayerState + 0x3C, true)
	playerState.superchargeCooldown     = memory.readfloat(  gGameState_PlayerState + 0x40, true)
	playerState.invincibilityCooldown   = memory.readfloat(  gGameState_PlayerState + 0x48, true)
	playerState.cooldownLimit           = memory.readfloat(  gGameState_PlayerState + 0x4C, true)
	playerState.sgtByrdBoost            = memory.readfloat(  gGameState_PlayerState + 0x58, true)
	playerState.sgtByrdBombs            = memory.read_u16_be(gGameState_PlayerState + 0x5C)
	playerState.sgtByrdMissiles         = memory.read_u16_be(gGameState_PlayerState + 0x5E)
	playerState.lightGemAmount          = memory.read_u8(    gGameState_PlayerState + 0x66)
	playerState.darkGemAmount           = memory.read_u8(    gGameState_PlayerState + 0x67)
	playerState.dragonEggAmount         = memory.read_u8(    gGameState_PlayerState + 0x68)
	playerState.playerSpawnX            = memory.readfloat(  gGameState_PlayerState + 0x70, true)
	playerState.playerSpawnY            = memory.readfloat(  gGameState_PlayerState + 0x74, true)
	playerState.playerSpawnZ            = memory.readfloat(  gGameState_PlayerState + 0x78, true)
	playerState.playerSpawnPitch        = memory.readfloat(  gGameState_PlayerState + 0x80, true)
	playerState.playerSpawnYaw          = memory.readfloat(  gGameState_PlayerState + 0x84, true)
	playerState.playerSpawnRoll         = memory.readfloat(  gGameState_PlayerState + 0x88, true)
	playerState.characterUI             = memory.read_u32_be(gGameState_PlayerState + 0x90)
end

local function updateObjectives()
	local block = convertByteArrayToIntArray(memory.read_bytes_as_array(gGameState_Objectives, objectiveTableSize * 4), objectiveTableSize * 4)
	
	local msgSent = 0
	local maxMsg = 10
	
	objectivesCleared = 0
	
	for i = 1, numOfObjectives do --Iterates through all hashcodes from 44000001 to 44000200 (which are the bounds the game itself checks for)
		local o_bit_index = i-1 --Index starts at 0
		
		local o_bit = bit.band(o_bit_index, 0x1f)
		local o_index = bit.rshift(o_bit_index, 5)
		
		local hash = bit.bor(0x44000000, i)
		local hashStr = ""
		
		if EXHashcodes[hash] ~= nil then
			hashStr = EXHashcodes[hash]
		else
			hashStr = "UNK_" .. tostring(i)
		end
		
		local objectiveState = bit.check(block[o_index+1], o_bit) --Outputs True if objective is set, False if not.
		
		if msgSent < maxMsg then
			if (objectives[i].State == false) and objectiveState then
				local msg = string.format("OB| Objective cleared: %s (0x%x)", hashStr, hash)
				gui.addmessage(msg)
				console.log(msg)
				
				msgSent = msgSent + 1
			end
			if msgSent == maxMsg then
				msg = "OB| Message cap reached!"
				gui.addmessage(msg)
				console.log(msg)
			end
		end
		
		objectives[i].Name = hashStr
		objectives[i].State = objectiveState
		objectives[i].Index = o_index
		objectives[i].Bit = o_bit
		
		if objectiveState then objectivesCleared = objectivesCleared + 1 end
	end
end

local function updateTasks()
	local block = convertByteArrayToIntArray(memory.read_bytes_as_array(gGameState_Tasks, taskTableSize * 4), taskTableSize * 4)
	
	local msgSent = 0
	local maxMsg = 10
	
	tasksFound = 0
	tasksCleared = 0
	
	for i = 1, numOfTasks do
		local t_bit_index = (i-1) * 2
		
		local t_bit = bit.band(t_bit_index, 0x1f)
		local t_index = bit.rshift(t_bit_index, 5)
		
		local hash = bit.bor(0x45000000, i)
		local hashStr = ""
		
		if EXHashcodes[hash] ~= nil then
			hashStr = EXHashcodes[hash]
		else
			hashStr = "UNK_" .. tostring(i)
		end
		
		local taskState = bit.rshift(bit.band(block[t_index+1], bit.lshift(3, t_bit)), t_bit)
		
		if msgSent < maxMsg then
			if (tasks[i].State == 0) and taskState == 1 then
				local msg = string.format("TA| New task: %s (0x%x)", hashStr, hash)
				gui.addmessage(msg)
				console.log(msg)
				
				msgSent = msgSent + 1
			elseif (tasks[i].State == 1) and taskState == 3 then
				local msg = string.format("TA| Task completed: %s (0x%x)", hashStr, hash)
				gui.addmessage(msg)
				console.log(msg)
				
				msgSent = msgSent + 1
			elseif (tasks[i].State == 0) and taskState == 3 then
				local msg = string.format("TA| Task found+completed: %s (0x%x)", hashStr, hash)
				gui.addmessage(msg)
				console.log(msg)
				
				msgSent = msgSent + 1
			end
			
			if msgSent == maxMsg then
				local msg = "TA| Message cap reached!"
				gui.addmessage(msg)
				console.log(msg)
			end
		end
		
		tasks[i].Name = hashStr
		tasks[i].State = taskState
		tasks[i].Index = t_index
		tasks[i].Bit = t_bit
		
		if taskState == 1 or taskState == 3 then tasksFound = tasksFound + 1 end
		if taskState == 3 then tasksCleared = tasksCleared + 1 end
	end
end

local function updateMapStates()
	for i = 0, 200 do
		local cur = gGameState_MapStates + (i * mapStatesBlockSize)
		
		currMapStateHash[i] = memory.hash_region(cur, mapStatesBlockSize)
		
		--Only update the table when it changes
		if currMapStateHash[i] ~= lastMapStateHash[i] then
			local block = convertByteArrayToIntArray(memory.read_bytes_as_array(cur, mapStatesBlockSize), mapStatesBlockSize)

			mapStates[i].startpoint = block[1]
			
			mapStates[i].tallyDG = block[13]
			mapStates[i].tallyLG = block[14]
			
			mapStates[i].tallyDE[1] = block[15]
			mapStates[i].tallyDE[2] = block[16]
			mapStates[i].tallyDE[3] = block[17]
			mapStates[i].tallyDE[4] = block[18]
			mapStates[i].tallyDE[5] = block[19]
			mapStates[i].tallyDE[6] = block[20]
			mapStates[i].tallyDE[7] = block[21]
			mapStates[i].tallyDE[8] = block[22]
			
			mapStates[i].tallyDE.all = 0
			for j = 1, 8 do
				mapStates[i].tallyDE.all = mapStates[i].tallyDE.all + mapStates[i].tallyDE[j]
			end
		end
		
		lastMapStateHash[i] = memory.hash_region(cur, 0x64)
	end
end

local function updateMinimaps()
	currMinimapBlock = memory.read_bytes_as_array(gGameState_Minimaps, bitHeapSize_Minimaps)
	local changes = 0
	local index = 0
	
	for k, v in ipairs(BH_MiniMapSizes) do
		for i = 0, v.Size do
			if isBitSet(currMinimapBlock, i+index) and isBitSet(lastMinimapBlock, i+index) == false then
				local y = math.floor(i / v.X) + 1
				local x = (i % v.X) + 1
				if forms.ischecked(checkShowMiniMap) then
					local str = ""
					str=str.."Current Minimap:\n"
					str=str..getPrintMiniMap(k)
					
					console.clear()
					console.log(str)
				end
				MinimapHeap[k][y][x] = true
			end
		end
		
		index = index + v.Size
	end
	
	lastMinimapBlock = memory.read_bytes_as_array(gGameState_Minimaps, bitHeapSize_Minimaps)
end

local function updateTriggerStates()
	currTriggerStateBlock = memory.read_bytes_as_array(gGameState_Triggerstates, bitHeapSize_Triggerstates)
	local changes = 0
	
	for i = 1, bitHeapSize_Triggerstates do
		local BH_index = bitHeapSize_Minimaps + i - 1
		local currByte = currTriggerStateBlock[i]
		local lastByte = lastTriggerStateBlock[i]
		
		for b = 0, 7 do
			local set   = bit.check(currByte, b) and (bit.check(lastByte, b) == false)
			local reset = bit.check(lastByte, b) and (bit.check(currByte, b) == false)
			
			if set or reset then
				changes = changes + 1
				
				local msg = ""
				if set then msg=msg.."TR| Bit set - "
				else        msg=msg.."TR| Bit reset - " end
				
				msg=msg.."byte: 0x"..bizstring.hex(gGameState_Triggerstates+(i-1))..stringPad(" (0x"..bizstring.hex(BH_index)..")", 9).." | bit: "..tostring(b).." (index "..tostring((BH_index)*8+b)..")"
				
				console.log(msg)
			end
		end
		
		if changes > 20 then
			console.log("TR| Message cap reached!")
			break
		end
	end
	
	lastTriggerStateBlock = memory.read_bytes_as_array(gGameState_Triggerstates, bitHeapSize_Triggerstates)
end

--STARTPOINT
local function cycleFairyStartPoints(i, currentStartPoint, startPointInit)
	if currInput["Up"] and lastInput["Up"] ~= true then
		if startPointInit == false then
			memory.write_u32_be(gGameState_MapStates + (mapList[i].levelID * 0x64), 0x4A000000)
		end
		
		memory.write_u32_be(gGameState_MapStates + (mapList[i].levelID * 0x64), currentStartPoint + 0x1)
	elseif currInput["Down"] and lastInput["Down"] ~= true then
		if startPointInit == false then
			memory.write_u32_be(gGameState_MapStates + (mapList[i].levelID * 0x64), 0x4A000000)
		end
		
		if currentStartPoint > 0x4A000000 then
			memory.write_u32_be(gGameState_MapStates + (mapList[i].levelID * 0x64), currentStartPoint - 0x1)
		end
	end
end

local function cycleShopStartPoints(i, currentStartPoint, startPointInit)
	if currInput["Up"] and lastInput["Up"] ~= true then
		if startPointInit == false then
			memory.write_u32_be(gGameState_MapStates + (mapList[i].levelID * 0x64), 0x0)
		end
		
		memory.write_u32_be(gGameState_MapStates + (mapList[i].levelID * 0x64), currentStartPoint + 0x1)
	elseif currInput["Down"] and lastInput["Down"] ~= true then
		if startPointInit == false then
			memory.write_u32_be(gGameState_MapStates + (mapList[i].levelID * 0x64), 0x0)
		end
		
		if currentStartPoint > 0x0 then
			memory.write_u32_be(gGameState_MapStates + (mapList[i].levelID * 0x64), currentStartPoint - 0x1)
		end
	end
end

local function switchStartPointMode(i, currentStartPoint, startPointInit, isFairyStartPoint)
	if (currInput["Left"] and lastInput["Left"] ~= true) or (currInput["Right"] and lastInput["Right"] ~= true) then
		if isFairyStartPoint == true then
			memory.write_u32_be(gGameState_MapStates + (mapList[i].levelID * 0x64), 0x0)
		else
			memory.write_u32_be(gGameState_MapStates + (mapList[i].levelID * 0x64), 0x4A000000)
		end
	end
end

local function cycleStartPoints(i)
	local startPointInit = true
	local isFairyStartPoint = false
	local currentStartPoint = mapStates[mapList[i].levelID].startpoint
	if currentStartPoint == 0xFFFFFFFF then
		startPointInit = false
	elseif bit.band(currentStartPoint, 0x4A000000) == 0x4A000000 then
		isFairyStartPoint = true
	end
	
	if isFairyStartPoint then
		cycleFairyStartPoints(i, currentStartPoint, startPointInit)
	else
		cycleShopStartPoints(i, currentStartPoint, startPointInit)
	end
	switchStartPointMode(i, currentStartPoint, startPointInit, isFairyStartPoint)
end

--PRINT WINDOW
local conprintWindow = forms.newform(150, 150, "Print To Console")
forms.setlocation(conprintWindow, client.xpos()+client.screenwidth(), client.ypos()+180)

local labelPrintToConsole = forms.label(conprintWindow, "Print to console:", 2, 5, 150, 14)
local buttonPrintPlayerState = forms.button( conprintWindow, "Player State", function()
	updatePlayerState()
	printPlayerStateToConsole()
end, 2, 20, 130, 25 )
local buttonPrintMaps = forms.button( conprintWindow, "Map Info", function()
	printMapsToConsole()
end, 2, 45, 130, 25 )
local buttonPrintObjectives = forms.button( conprintWindow, "Objectives", function()
	updateObjectives()
	printObjectivesToConsole()
end, 2, 70, 130, 25 )
local buttonPrintTasks = forms.button( conprintWindow, "Tasks", function()
	updateTasks()
	printTasksToConsole()
end, 2, 95, 130, 25 )
local buttonPrintMiniMaps = forms.button( conprintWindow, "Mini-Maps", function()
	updateMinimaps()
	printAllMiniMapsToConsole()
end, 2, 120, 130, 25 )

initPlayerState()
initMiniMaps()
initObjectives()
initTasks()
initMapGlobals()
initMapStates()

while true do
	--currInput = input.get()
	
	if forms.ischecked(checkObjectives)    then doObjectives   =true else doObjectives   =false end
	if forms.ischecked(checkTasks)         then doTasks        =true else doTasks        =false end
	if forms.ischecked(checkMinimaps)      then doMinimaps     =true else doMinimaps     =false end
	if forms.ischecked(checkTriggerstates) then doTriggerstates=true else doTriggerstates=false end
	
	--PLAYER STATE
	--Hash region is offset a bit so it doesn't check the playtimer that increases constantly.
	currPlayerStateHash = memory.hash_region(gGameState_PlayerState + 0xC, playerStateSize - 0xC)
	if currPlayerStateHash ~= lastPlayerStateHash then updatePlayerState() end
	lastPlayerStateHash = currPlayerStateHash
	
	--OBJECTIVES
	if doObjectives then
		currObjectiveHash = memory.hash_region(gGameState_Objectives, objectiveTableSize * 4)
		if currObjectiveHash ~= lastObjectiveHash then updateObjectives() end
		lastObjectiveHash = currObjectiveHash
	end
	
	--TASKS
	if doTasks then
		currTaskHash = memory.hash_region(gGameState_Tasks, taskTableSize * 4)
		if currTaskHash ~= lastTaskHash then updateTasks() end
		lastTaskHash = currTaskHash
	end
	
	--MAP STATES
	currentMap = bit.band(memory.read_u32_be(gpCurrentMap), 0xFFFFFF)
	if currentMap ~= 0 then updateMapStates() end
	
	--MINIMAPS
	if doMinimaps then
		currMinimapHash = memory.hash_region(gGameState_Minimaps, bitHeapSize_Minimaps)
		if currMinimapHash ~= lastMinimapHash then updateMinimaps() end
		lastMinimapHash = currMinimapHash
	end
	
	--TRIGGER STATES
	if doTriggerstates then
		currTriggerStateHash = memory.hash_region(gGameState_Triggerstates, bitHeapSize_Triggerstates)
		if currTriggerStateHash ~= lastTriggerStateHash then updateTriggerStates() end
		lastTriggerStateHash = currTriggerStateHash
	end
	
	textOffset = 20
	
	for i = 0, numberOfMaps do
		if currentMap == mapList[i].addr then
			gui.text( 0, textOffset, "CURRENT MAP:", nil)
			textOffset = textOffset + 20
			gui.text( 0, textOffset, "  Map ID: "..mapList[i].levelID)
			textOffset = textOffset + 20
			gui.text( 0, textOffset, "  Hash: 0x0"..bizstring.hex(mapList[i].geoHash).." ("..mapList[i].filename..")", nil)
			textOffset = textOffset + 20
			gui.text( 0, textOffset, "  Base Address: 0x"..bizstring.hex(mapList[i].addr), nil)
			textOffset = textOffset + 20
			gui.text( 0, textOffset, "  Realm: "..tostring(mapList[i].realm_nr))
			textOffset = textOffset + 20
			gui.text( 0, textOffset, "  Level: "..tostring(mapList[i].level_nr))
			textOffset = textOffset + 40
			
			gui.text( 0, textOffset, "  Startpoint: "..bizstring.hex(mapStates[mapList[i].levelID].startpoint), nil)
			textOffset = textOffset + 20
			gui.text( 0, textOffset, "  Dark Gems:   "..tostring(mapStates[mapList[i].levelID].tallyDG).."/"..tostring(mapStates[mapList[i].levelID].totalDG))
			textOffset = textOffset + 20
			gui.text( 0, textOffset, "  Dragon Eggs: "..tostring(mapStates[mapList[i].levelID].tallyDE.all).."/"..tostring(mapStates[mapList[i].levelID].totalDE))
			textOffset = textOffset + 20
			gui.text( 0, textOffset, "  Light Gems:  "..tostring(mapStates[mapList[i].levelID].tallyLG).."/"..tostring(mapStates[mapList[i].levelID].totalLG))
			textOffset = textOffset + 20
			
			cycleStartPoints(i)
		end
	end
	if currentMap == 0x0 then
		gui.text( 0, textOffset, "No map", "Red")
	end
	
	textOffset = textOffset + 40
	gui.text( 0, textOffset, "OBJECTIVES/TASKS:")
	textOffset = textOffset + 20
	gui.text( 0, textOffset, "  Objectives Cleared: "..tostring(objectivesCleared))
	textOffset = textOffset + 20
	
	gui.text( 0, textOffset, "  Tasks Done: "..tostring(tasksCleared).."/"..tostring(tasksFound))
	textOffset = textOffset + 40
	gui.text( 0, textOffset, "Completion: "..string.format("%.2f", getGameCompletion()).."%")

	--lastInput = input.get()

	emu.frameadvance()
end
