--VARIABLES
local SpyroPoint = {
	gameFrameDelay = 3,
	gameFOV = 58.5,
	
	screen_EmuYOffset = 0,
	screen_Aspect = 1.3,
	screen_YStretch = 0.978,
	screen_XOffset = 0,
	screen_NearClippingPlane = 0.3,
	screen_Dim = {X = 600, Y = 400},
	screen_Scale = 1,
	screen_RenderDistanceLimit = 100,
	
	pointSizeMin = 4,
	defaultPointColor = 0xFFFF0000,
	
	camMatAddress = 0x48A1A0,
	camMat = {
		X = {X = 1, Y = 0, Z = 0},
		Y = {X = 0, Y = 1, Z = 0},
		Z = {X = 0, Y = 0, Z = 1}
	},
	camMatBuffer = {},
	
	camPosAddress = 0x750878,
	camPos = {X = 0, Y = 0, Z = 0},
	camPosBuffer = {},
	
	fovMultAddress = 0x750874,
	fovMult = 1,
	fovMultBuffer = {}
}


--BUFFER SETUP
--	Matrix
for i = 1, SpyroPoint.gameFrameDelay do
	SpyroPoint.camMatBuffer[i] = {
		X = {X = 1, Y = 0, Z = 0},
		Y = {X = 0, Y = 1, Z = 0},
		Z = {X = 0, Y = 0, Z = 1}
	}
end

SpyroPoint.camMatBuffer_rotate = function(inputBuffer)
	local outputBuffer = {}
	
	for i = 1, SpyroPoint.gameFrameDelay do
		outputBuffer[i] = {
			X = {X = 1, Y = 0, Z = 0},
			Y = {X = 0, Y = 1, Z = 0},
			Z = {X = 0, Y = 0, Z = 1}
		}
	end
	
	for i = SpyroPoint.gameFrameDelay, 2, -1 do
		outputBuffer[i].X = inputBuffer[i-1].X
		outputBuffer[i].Y = inputBuffer[i-1].Y
		outputBuffer[i].Z = inputBuffer[i-1].Z
	end
	
	return outputBuffer
end

SpyroPoint.camMat_update = function()
	SpyroPoint.camMatBuffer = SpyroPoint.camMatBuffer_rotate(SpyroPoint.camMatBuffer)
	
	SpyroPoint.camMatBuffer[1].X.X = memory.readfloat(SpyroPoint.camMatAddress     , true)
	SpyroPoint.camMatBuffer[1].Y.X = memory.readfloat(SpyroPoint.camMatAddress+0x4 , true)
	SpyroPoint.camMatBuffer[1].Z.X = memory.readfloat(SpyroPoint.camMatAddress+0x8 , true)
	
	SpyroPoint.camMatBuffer[1].X.Y = memory.readfloat(SpyroPoint.camMatAddress+0x10, true)
	SpyroPoint.camMatBuffer[1].Y.Y = memory.readfloat(SpyroPoint.camMatAddress+0x14, true)
	SpyroPoint.camMatBuffer[1].Z.Y = memory.readfloat(SpyroPoint.camMatAddress+0x18, true)
	
	SpyroPoint.camMatBuffer[1].X.Z = memory.readfloat(SpyroPoint.camMatAddress+0x20, true)
	SpyroPoint.camMatBuffer[1].Y.Z = memory.readfloat(SpyroPoint.camMatAddress+0x24, true)
	SpyroPoint.camMatBuffer[1].Z.Z = memory.readfloat(SpyroPoint.camMatAddress+0x28, true)
	
	SpyroPoint.camMat.X.X = SpyroPoint.camMatBuffer[SpyroPoint.gameFrameDelay].X.X
	SpyroPoint.camMat.Y.X = SpyroPoint.camMatBuffer[SpyroPoint.gameFrameDelay].Y.X
	SpyroPoint.camMat.Z.X = SpyroPoint.camMatBuffer[SpyroPoint.gameFrameDelay].Z.X
	
	SpyroPoint.camMat.X.Y = SpyroPoint.camMatBuffer[SpyroPoint.gameFrameDelay].X.Y
	SpyroPoint.camMat.Y.Y = SpyroPoint.camMatBuffer[SpyroPoint.gameFrameDelay].Y.Y
	SpyroPoint.camMat.Z.Y = SpyroPoint.camMatBuffer[SpyroPoint.gameFrameDelay].Z.Y
	
	SpyroPoint.camMat.X.Z = SpyroPoint.camMatBuffer[SpyroPoint.gameFrameDelay].X.Z
	SpyroPoint.camMat.Y.Z = SpyroPoint.camMatBuffer[SpyroPoint.gameFrameDelay].Y.Z
	SpyroPoint.camMat.Z.Z = SpyroPoint.camMatBuffer[SpyroPoint.gameFrameDelay].Z.Z
end

--	Position
for i = 1, SpyroPoint.gameFrameDelay do
	SpyroPoint.camPosBuffer[i] = {X = 0, Y = 0, Z = 0}
end

SpyroPoint.camPosBuffer_rotate = function(inputBuffer)
	local outputBuffer = {}
	
	for i = 1, SpyroPoint.gameFrameDelay do
		outputBuffer[i] = {
			X = 0,
			Y = 0,
			Z = 0
		}
	end
	
	for i = SpyroPoint.gameFrameDelay, 2, -1 do
		outputBuffer[i].X = inputBuffer[i-1].X
		outputBuffer[i].Y = inputBuffer[i-1].Y
		outputBuffer[i].Z = inputBuffer[i-1].Z
	end
	
	return outputBuffer
end

SpyroPoint.camPos_update = function()
	SpyroPoint.camPosBuffer = SpyroPoint.camPosBuffer_rotate(SpyroPoint.camPosBuffer)
	
	SpyroPoint.camPosBuffer[1].X = memory.readfloat(SpyroPoint.camPosAddress    , true)
	SpyroPoint.camPosBuffer[1].Y = memory.readfloat(SpyroPoint.camPosAddress+0x4, true)
	SpyroPoint.camPosBuffer[1].Z = memory.readfloat(SpyroPoint.camPosAddress+0x8, true)
	
	SpyroPoint.camPos.X = SpyroPoint.camPosBuffer[SpyroPoint.gameFrameDelay].X
	SpyroPoint.camPos.Y = SpyroPoint.camPosBuffer[SpyroPoint.gameFrameDelay].Y
	SpyroPoint.camPos.Z = SpyroPoint.camPosBuffer[SpyroPoint.gameFrameDelay].Z
end

--	FOV multiplier
for i = 1, SpyroPoint.gameFrameDelay do
	SpyroPoint.fovMultBuffer[i] = 1
end

SpyroPoint.fovMultBuffer_rotate = function(inputBuffer)
	local outputBuffer = {}
	
	for i = 1, SpyroPoint.gameFrameDelay do
		outputBuffer[i] = 0
	end
	
	for i = SpyroPoint.gameFrameDelay, 2, -1 do
		outputBuffer[i] = inputBuffer[i-1]
	end
	
	return outputBuffer
end

SpyroPoint.fovMult_update = function()
	SpyroPoint.fovMultBuffer = SpyroPoint.fovMultBuffer_rotate(SpyroPoint.fovMultBuffer)
	
	SpyroPoint.fovMultBuffer[1] = memory.readfloat(SpyroPoint.fovMultAddress, true)
	
	SpyroPoint.fovMult = SpyroPoint.fovMultBuffer[SpyroPoint.gameFrameDelay]
end


--DRAW FUNCTIONS
SpyroPoint.updateScreen = function()
	SpyroPoint.screen_Dim.X = client.screenwidth()-SpyroPoint.screen_XOffset
	SpyroPoint.screen_Dim.Y = client.screenheight()
	
	if (SpyroPoint.screen_Dim.X/SpyroPoint.screen_Dim.Y) < SpyroPoint.screen_Aspect then
		SpyroPoint.screen_Dim.Y = SpyroPoint.screen_Dim.X/SpyroPoint.screen_Aspect
		SpyroPoint.screen_EmuYOffset = math.floor((client.screenheight()-SpyroPoint.screen_Dim.Y)/2)
	else
		SpyroPoint.screen_EmuYOffset = 0
	end
end

SpyroPoint.updateCamera = function()
	SpyroPoint.camMat_update()
	SpyroPoint.camPos_update()
	SpyroPoint.fovMult_update()
end

SpyroPoint.worldSpcToScreenSpc = function(inputVect)
	local localVect = {
		X = inputVect.X - SpyroPoint.camPos.X,
		Y = inputVect.Y - SpyroPoint.camPos.Y,
		Z = inputVect.Z - SpyroPoint.camPos.Z
	}
	
	return {
		X = SpyroPoint.camMat.X.X * localVect.X + SpyroPoint.camMat.Y.X * localVect.Y + SpyroPoint.camMat.Z.X * localVect.Z,
		Y = SpyroPoint.camMat.X.Y * localVect.X + SpyroPoint.camMat.Y.Y * localVect.Y + SpyroPoint.camMat.Z.Y * localVect.Z,
		Z = SpyroPoint.camMat.X.Z * localVect.X + SpyroPoint.camMat.Y.Z * localVect.Y + SpyroPoint.camMat.Z.Z * localVect.Z
	}
end

SpyroPoint.screenSpcToScreenPos = function(inputVect)
	--trust me it works
	return {
		X = (SpyroPoint.screen_Dim.X/2)+SpyroPoint.screen_XOffset+((inputVect.X*(SpyroPoint.screen_Dim.Y/2))/inputVect.Z)/math.tan(math.rad(SpyroPoint.gameFOV*SpyroPoint.fovMult)/2),
		Y = (SpyroPoint.screen_Dim.Y/2)+((inputVect.Y*-(SpyroPoint.screen_Dim.Y/2))/inputVect.Z)/math.tan(math.rad(SpyroPoint.gameFOV*SpyroPoint.fovMult*SpyroPoint.screen_YStretch)/2)+SpyroPoint.screen_EmuYOffset
	}
end

SpyroPoint.isInRange = function(Vect3a, Vect3b, range)
	return math.sqrt( (Vect3a.X-Vect3b.X)^2 + (Vect3a.Y-Vect3b.Y)^2 + (Vect3a.Z-Vect3b.Z)^2 ) < range
end

SpyroPoint.renderPoint = function(vect, inputColor, index, labelsToDraw, markColor)
	--local renderDist
	--if tempRenderDist then
	--	renderDist = tempRenderDist
	--else
	--	renderDist = SpyroPoint.screen_RenderDistanceLimit
	--end
	
	--POINT SETUP
	local point = {
		Color = SpyroPoint.defaultPointColor,
		Pos = {
			X = 0,
			Y = 0
		},
		Size = 1
	}
	
	if inputColor then
		point.Color = inputColor
	end
	
	local screenObjPos = SpyroPoint.worldSpcToScreenSpc(vect)
	point.Pos = SpyroPoint.screenSpcToScreenPos(screenObjPos)
	
	point.Size = 200/(screenObjPos.Z/(1/math.tan(math.rad(SpyroPoint.gameFOV*SpyroPoint.fovMult))))
	if point.Size < SpyroPoint.pointSizeMin then
		point.Size = SpyroPoint.pointSizeMin
	end
	
	
	if (screenObjPos.Z > 0 and 
	--SpyroPoint.isInRange(SpyroPoint.camPos, vect, renderDist) and
	SpyroPoint.isInRange(SpyroPoint.camPos, vect, SpyroPoint.screen_NearClippingPlane) == false and
	point.Pos.X > SpyroPoint.screen_XOffset and
	point.Pos.X < SpyroPoint.screen_XOffset+SpyroPoint.screen_Dim.X) then
		gui.drawEllipse(math.floor(point.Pos.X-(point.Size/2)), math.floor(point.Pos.Y-(point.Size/2)), point.Size, point.Size, 0xFF000000, point.Color)
		
		if index then
			gui.text(math.floor(point.Pos.X)+10, math.floor(point.Pos.Y)-10, tostring(index), markColor)
		end
		for i, v in pairs(labelsToDraw) do
			gui.text(math.floor(point.Pos.X)-20, math.floor(point.Pos.Y)+((i-1)*14)+5, v, markColor)
		end
	end
	
	return point
end

return SpyroPoint