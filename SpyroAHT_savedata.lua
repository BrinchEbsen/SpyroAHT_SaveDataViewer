-----------Controls------------
---Edit these to your liking---
KEY_PRINT_MAPS = "K"
KEY_PRINT_OBJECTIVES = "L"
KEY_PRINT_TASKS = "O"
-------------------------------

console.clear();
memory.usememorydomain("RAM")

--Table that holds save data
local gGameState = 0x463b38
local gGameState_Objectives	= gGameState + 0x2150
local gGameState_Tasks		= gGameState + 0x2190
local gGameState_BitHeap	= gGameState + 0x21AC
local gGameState_MapStates	= gGameState + 0x6434

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
	[0] = "   ",
	[1] = "[ ]",
	[2] = "[?]",
	[3] = "[X]"
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

--Table of .edb hashcodes
local geoHashes = require("SpyroAHT_objlist_geoDef")
local EXHashcodes = require("SpyroAHT_hashcodes")

local textOffset = 0
local textAreaWidth = 350
client.setwindowsize(1)
client.SetClientExtraPadding(textAreaWidth, 0, 0, 0)
gui.use_surface("client")

function setObjective(o)
	local o_bit_index = bit.band(o, 0xFFFFFF)-1
	if o_bit_index > 0x200 then return end
	local o_bit = bit.band(o_bit_index, 0x1f)
	local o_index = bit.rshift(o_bit_index, 5)
	
	local c = memory.read_u32_be(gGameState_Objectives + (o_index * 4))
	memory.write_u32_be(gGameState_Objectives + (o_index * 4), bit.bor(c, bit.lshift(1, o_bit)))
end

function resetObjective(o)
	local o_bit_index = bit.band(o, 0xFFFFFF)-1
	if o_bit_index > 0x200 then return end
	local o_bit = bit.band(o_bit_index, 0x1f)
	local o_index = bit.rshift(o_bit_index, 5)
	
	local c = memory.read_u32_be(gGameState_Objectives + (o_index * 4))
	if not bit.check(c, o_bit) then return end
	memory.write_u32_be(gGameState_Objectives + (o_index * 4), bit.bxor(c, bit.lshift(1, o_bit)))
end

local function stringPad(s, targetLen)
	if string.len(s) >= targetLen then return s end
	
	local out = s
	for pad = 1, targetLen-string.len(s) do
		out = out .. " "
	end
	return out
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

local function initMapGlobals()
	for i = 0, numberOfMaps do
		local cur = bit.band(memory.read_u32_be(gMapList + (i * 0x4)), 0xFFFFFF)
		mapList[i] = {}
		
		mapList[i].addr = cur
		mapList[i].realm_nr = memory.read_u32_be(cur + 0x8C)
		mapList[i].level_nr = memory.read_u32_be(cur + 0x90)
		mapList[i].geoHash = memory.read_u32_be(cur + 0xDC)
		mapList[i].levelID = memory.read_u32_be(cur + 0xC8)
		mapList[i].filename = geoHashes[mapList[i].geoHash]
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
		
		if block[3] ~= 0xFFFFFFFF and block[4] ~= 0xFFFFFFFF and block[5] ~= 0xFFFFFFFF then
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

local function printMapsToConsole()
	local str = ""
	
	str = str .. string.format("Number of Maps: %d\n\n", numberOfMaps)
	for i = 0, numberOfMaps do
		str = str..string.format("Map ID %d:\n", mapList[i].levelID)
		str = str..string.format("  Hash: 0x0%x (%s)\n", mapList[i].geoHash, mapList[i].filename)
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
				local msg = string.format("Objective cleared: %s (0x%x)", hashStr, hash)
				gui.addmessage(msg)
				console.log(msg)
				
				msgSent = msgSent + 1
			end
			if msgSent == maxMsg then
				msg = "Message cap reached!"
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
				local msg = string.format("New task: %s (0x%x)", hashStr, hash)
				gui.addmessage(msg)
				console.log(msg)
				
				msgSent = msgSent + 1
			elseif (tasks[i].State == 1) and taskState == 3 then
				local msg = string.format("Task completed: %s (0x%x)", hashStr, hash)
				gui.addmessage(msg)
				console.log(msg)
				
				msgSent = msgSent + 1
			elseif (tasks[i].State == 0) and taskState == 3 then
				local msg = string.format("Task found+completed: %s (0x%x)", hashStr, hash)
				gui.addmessage(msg)
				console.log(msg)
				
				msgSent = msgSent + 1
			end
			
			if msgSent == maxMsg then
				msg = "Message cap reached!"
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

initObjectives()
initTasks()
initMapGlobals()
initMapStates()

while true do
	currInput = input.get()
	
	currObjectiveHash = memory.hash_region(gGameState_Objectives, objectiveTableSize * 4)
	if currObjectiveHash ~= lastObjectiveHash then updateObjectives() end
	lastObjectiveHash = currObjectiveHash
	
	currTaskHash = memory.hash_region(gGameState_Tasks, taskTableSize * 4)
	if currTaskHash ~= lastTaskHash then updateTasks() end
	lastTaskHash = currTaskHash
	
	currentMap = bit.band(memory.read_u32_be(gpCurrentMap), 0xFFFFFF)
	if currentMap ~= 0 then updateMapStates() end
	
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
	
	--if currInput[KEY_PRINT_MAPS] and lastInput[KEY_PRINT_MAPS] ~= true then
	--	printMapsToConsole()
	--elseif currInput[KEY_PRINT_OBJECTIVES] and lastInput[KEY_PRINT_OBJECTIVES] ~= true then
	--	printObjectivesToConsole()
	--elseif currInput[KEY_PRINT_TASKS] and lastInput[KEY_PRINT_TASKS] ~= true then
	--	printTasksToConsole()
	--end

	lastInput = input.get()

	emu.frameadvance()
end
