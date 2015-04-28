---------------------------------------
-- Class 377 Script --
---------------------------------------
--
-- (c) Railsimulator.com 2012
--

--include=..\..\..\..\Common\Scripts\CTA Util.lua

WHINE_ID = 1715
DYNAMIC_ID = 1716
CARCOUNT_ID = 1717
CARCOUNT_RET_ID = 1718
CARNUM_ID = 1719
CARNUM_RET_ID = 1720

MSG_ATO_SPEED_LIMIT = 42
MSG_SIGN_CHANGE = 43

CAR_COUNT_TIME = 1.0 -- seconds

local NUM_SIGNS = 0
local SIGNS = { }

local function addSign(texName, lightOn, lightColor, nextSign)
	local sign = { }
	local nSign = nextSign or NUM_SIGNS -- Same sign by default
	sign.id = texName
	sign.hasLight = lightOn
	sign.color = lightColor
	sign.nextSign = nSign
	SIGNS[NUM_SIGNS + 1] = sign
	NUM_SIGNS = NUM_SIGNS + 1
end

--     ( id, light, lightColor, [ nextSign ] )
addSign("a", false, nil)                   --[[  0 Off ]]
addSign("b",  true, { 255, 255, 255 })     --[[  1 NIS ]]
addSign("c",  true, { 255, 255, 255 })     --[[  2 Express ]]
addSign("d",  true, { 255,  31,  31 })     --[[  3 Red Howard ]]
addSign("e",  true, { 255,  31,  31 })     --[[  4 Red 95th ]]
addSign("f",  true, { 255,  31,  31 })     --[[  5 Red Roosevelt ]]
addSign("g",  true, { 255,  31,  31 })     --[[  6 Red 63rd ]]
addSign("h",  true, { 165,  95,  35 }, 8)  --[[  7 Brown Loop ]]
addSign("i",  true, { 165,  95,  35 })     --[[  8 Brown Kimball ]]
addSign("j",  true, { 165,  95,  35 })     --[[  9 Brown Belmont ]]
addSign("k",  true, { 255, 127,  63 }, 11) --[[ 10 Orange Loop ]]
addSign("l",  true, { 255, 127,  63 })     --[[ 11 Orange Midway ]]
addSign("m",  true, { 155,   0, 215 }, 14) --[[ 12 Purple Loop ]]
addSign("n",  true, { 155,   0, 215 })     --[[ 13 Purple Howard ]]
addSign("o",  true, { 155,   0, 215 })     --[[ 14 Purple Linden ]]
addSign("p",  true, { 235,  90, 185 }, 16) --[[ 15 Pink Loop ]]
addSign("q",  true, { 235,  90, 185 })     --[[ 16 Pink 54th/Cermak ]]
addSign("r",  true, {  31, 255,  31 })     --[[ 17 Green Harlem ]]
addSign("s",  true, { 191, 255, 191 })     --[[ 18 Green Cottage Grove ]]
addSign("t",  true, {  31, 255,  31 })     --[[ 19 Green Ashland/63rd ]]
addSign("u",  true, {  31, 255,  31 })     --[[ 20 Green Roosevelt ]]
addSign("v",  true, {   0,  95, 235 })     --[[ 21 Blue O'Hare ]]
addSign("w",  true, {   0,  95, 235 })     --[[ 22 Blue Forest Park ]]
addSign("x",  true, { 191, 191, 255 })     --[[ 23 Blue UIC ]]
addSign("y",  true, {   0,  95, 235 })     --[[ 24 Blue Rosemont ]]
addSign("z",  true, {   0,  95, 235 })     --[[ 25 Blue Jefferson Park ]]

function Initialise()
-- For AWS self test.
	gAWSReady = TRUE
	gAWSTesting = FALSE

-- Stores for checking when values have changed.
	gDriven = -1
	gHeadlight = -1
	gTaillight = -1
	gInitialised = FALSE
	
-- Control variables
	gWhine = 0
	gPrevWhine = 0
	gPrevDynamic = 0.0
	
-- Misc variables
	gTimeSinceCarCount = 0.0
	gBodyTilt = 0.0
	gCamInside = false
	gLastDir = 1
	gIsBCar = 0 -- Is this an "A" car or a "B" car?
	
-- Moving average for acceleration
	gMovingAvgSize = 50
	gMovingAvgList = { }
	gMovingAvgIndex = 0 -- 0 - 9
	gMovingAvg = 0

	Call( "BeginUpdate" )
end

function UpdateMovingAverage(value) -- Updates the moving average for acceleration
	local i = gMovingAvgIndex + 1
	gMovingAvg = gMovingAvg - (gMovingAvgList[i] or 0)
	gMovingAvgList[i] = value
	gMovingAvg = gMovingAvg + value
	gMovingAvgIndex = mod(gMovingAvgIndex + 1, gMovingAvgSize)
end

function GetMovingAverage()
	return gMovingAvg / gMovingAvgSize
end

function OnCameraEnter(camEnd, carriageCam)
	gCamInside = true
end

function OnCameraLeave()
	gCamInside = false
end

function Update(time)
	local trainSpeed = Call("GetSpeed") * MPS_TO_MPH
	local accel = Call("GetAcceleration") * MPS_TO_MPH
	local reverser = Call("*:GetControlValue", "Reverser", 0)

	if ( Call( "GetIsPlayer" ) == 1 ) then
		gTimeSinceCarCount = gTimeSinceCarCount + time
		if (gTimeSinceCarCount >= CAR_COUNT_TIME) then
			gTimeSinceCarCount = 0
			CountCars()
		end
			
		local whine = Call("*:GetControlValue", "TractionWhine", 0)
		local dynamic = Call("*:GetControlValue", "DynamicBrake", 0)

		if ( Call( "*:GetControlValue", "Active", 0 ) == 1 ) then
			if (whine ~= gPrevWhine) then
				Call( "SendConsistMessage", WHINE_ID, whine, 1 )
				Call( "SendConsistMessage", WHINE_ID, whine, 0 )
			end
			
			if (dynamic ~= gPrevDynamic) then
				Call( "SendConsistMessage", DYNAMIC_ID, dynamic, 1 )
				Call( "SendConsistMessage", DYNAMIC_ID, dynamic, 0 )
			end

			gPrevWhine = whine
			gPrevDynamic = dynamic
			
			Headlights = Call( "*:GetControlValue", "Headlights", 0 )
			if (Headlights > 0.5) then
				Call( "HeadlightL:Activate", 1 )
				Call( "HeadlightR:Activate", 1 )
			else
				Call( "HeadlightL:Activate", 0 )
				Call( "HeadlightR:Activate", 0 )
			end
			
			local cabSpeed = clamp(math.floor(math.abs(trainSpeed)), 0, 72)
			Call("*:SetControlValue", "CabSpeedIndicator", 0, cabSpeed)
		else
			Call( "HeadlightL:Activate", 0 )
			Call( "HeadlightR:Activate", 0 )
		end

		if gInitialised == FALSE then
			gInitialised = TRUE
		end

	-- Check if player is driving this engine.

		if ( Call( "GetIsEngineWithKey" ) == 1 ) then
			if gDriven ~= 1 then
				gDriven = 1
				Call( "*:SetControlValue", "Active", 0, 1 )
			end
		else
			if gDriven ~= 0 then
				gDriven = 0
				Call( "*:SetControlValue", "Active", 0, 0 )
				Call( "*:SetControlValue", "ATOActive", 0, 0 )
			end
		end
	else
		Call( "*:SetControlValue", "DestinationSign", 0, 0 )
	end
	
	-- Inverter whine based on current
	
	local tWhine = 1.0
	local dWhine = 1.2 * time
	local current = Call("*:GetControlValue", "Ammeter", 0)
	local tAccel = Call("*:GetControlValue", "TAccel", 0)
	if ( math.abs(current) < 0.0001 and tAccel >= 0.0 ) then
		tWhine = 0.0
	end
	
	if (gWhine < tWhine - dWhine) then
		gWhine = gWhine + dWhine
	elseif (gWhine > tWhine + dWhine) then
		gWhine = gWhine - dWhine
	else
		gWhine = tWhine
	end
	
	Call( "*:SetControlValue", "TractionWhine", 0, clamp(gWhine, 0.0, 1.0) )
	
	-- Direction
	local realAccel = Call("*:GetControlValue", "Acceleration", 0)
	if (math.abs(trainSpeed) > 0.01) then
		if (sign(accel) == sign(realAccel)) then
			gLastDir = -1
		else
			gLastDir = 1
		end
		if (Call("*:GetControlValue", "Active", 0) > 0) then
			Call("*:SetControlValue", "Direction", 0, sign(trainSpeed))
		end
	end
	
	Call("*:SetControlValue", "Accel2", 0, round(accel, 2))
	Call("*:SetControlValue", "Speed2", 0, round(trainSpeed, 2))
	
	-- Acceleration tilt
	
	UpdateMovingAverage(accel) -- MPH/s
	local accelAvg = GetMovingAverage() -- Smooth out acceleration
	accelAvg = accelAvg / 4.0 -- Max accel for animation is 3.25 MPH/s
	accelAvg = accelAvg * gLastDir
	accelAvg = accelAvg * Call("*:GetControlValue", "Direction", 0)
	if (mod(Call("*:GetControlValue", "CarNum", 0), 2) ~= 0) then
		accelAvg = -accelAvg
	end
	tBodyTilt = 1.0 + clamp(accelAvg, -1, 1)
	dBodyTilt = 0.025 * clamp(math.abs(gBodyTilt - tBodyTilt) / 0.65, 0.3, 1.0)
	if (gBodyTilt < tBodyTilt - dBodyTilt) then
		gBodyTilt = gBodyTilt + dBodyTilt
	elseif (gBodyTilt > tBodyTilt + dBodyTilt) then
		gBodyTilt = gBodyTilt - dBodyTilt
	else
		gBodyTilt = tBodyTilt
	end
		
	if gCamInside then -- Don't animate inside; camera movement already occurs
		Call("*:SetTime", "body_tilt", 1.0)
	else
		Call("*:SetTime", "body_tilt", gBodyTilt)
	end
	
	-- Destination sign
	
	DestSign = Call( "*:GetControlValue", "DestinationSign", 0 )
	IsEndCar = Call( "*:GetControlValue", "IsEndCar", 0 ) > 0
	RVNumber = Call("*:GetRVNumber")
	firstPart = "5001"
	if (string.len(RVNumber) == 5) then
		firstPart = string.sub(RVNumber, 1, 4)
	else
		Call("*:SetRVNumber", "5001a")
	end
	
	if (DestSign >= 0 and DestSign < NUM_SIGNS and SIGNS[DestSign + 1]) then
		local sign = SIGNS[DestSign + 1]
		local frontPart = IsEndCar and sign.id or SIGNS[1].id -- Middle cars are off
		Call("*:SetRVNumber", firstPart .. frontPart)
		
		if (SIGNS[DestSign + 1].hasLight and IsEndCar) then
			Call( "SignLightFront:Activate", 1 )
			Call( "SignLightFront:SetColour", SIGNS[DestSign + 1].color[1] / 255, SIGNS[DestSign + 1].color[2] / 255, SIGNS[DestSign + 1].color[3] / 255 )
		else
			Call( "SignLightFront:Activate", 0 )
		end
	else
		Call("*:SetRVNumber", firstPart .. "a")
		Call( "SignLightFront:Activate", 0 )
	end
end

function CountCars()
	-- Determine if we're the front/back car or a middle car
	local rev = Call( "SendConsistMessage", 0, 0, 1 )
	local fwd = Call( "SendConsistMessage", 0, 0, 0 )
	local endCar = false
	
	if (fwd + rev == 1) then
		Call("*:SetControlValue", "IsEndCar", 0, 1)
		endCar = true
	else
		Call("*:SetControlValue", "IsEndCar", 0, 0)
	end
	
	if (Call("*:GetControlValue", "Active", 0) > 0) then
		-- Determine the total number of cars in the consist

		Call( "*:SetControlValue", "NumCars", 0, 1 )
		Call( "SendConsistMessage", CARCOUNT_ID, 0, 0 )
		Call( "SendConsistMessage", CARCOUNT_ID, 0, 1 )
		
		-- Set "car ID" of each car
		--debugPrint("Setting car IDs...this car is " .. (endCar and "an" or "not an") .. " end car")
		if (endCar) then -- Already at end, send backwards
			Call( "SendConsistMessage", CARNUM_RET_ID, 0, 1 )
			Call( "*:SetControlValue", "CarNum", 0, 0 )
		else -- Not at end, send forwards so it bounces back from the end
			Call( "SendConsistMessage", CARNUM_ID, 0, 0 )
		end
	end
end

function OnConsistMessage ( msg, argument, direction )
	local cancel = false
	
	-- If this is not the driven vehicle then update the passed-down controls with values from the master engine
	if (Call("*:GetControlValue", "Active", 0) == 0) then
		if (msg == WHINE_ID) then
			--Call("*:SetControlValue", "TractionWhine", 0, argument)
		end
		
		if (msg == DYNAMIC_ID) then
			Call("*:SetControlValue", "DynamicBrake", 0, argument)
		end
		
		if (msg == CARCOUNT_ID) then -- Going down train counting cars
			cancel = true
			argument = tonumber(argument) + 1
			local sent = Call( "SendConsistMessage", msg, argument, direction )
			if (sent == 0) then
				Call( "SendConsistMessage", CARCOUNT_RET_ID, argument, reverseMsgDir(direction) )
			end
		end
	else
		if (msg == CARCOUNT_RET_ID) then
			local curCarCount = Call( "*:GetControlValue", "NumCars", 0 )
			Call("*:SetControlValue", "NumCars", 0, curCarCount + argument)
		end
	end
	
	if (msg == CARNUM_ID and Call("*:GetControlValue", "IsEndCar", 0) > 0) then -- End car, return back down the line
		Call("*:SetControlValue", "CarNum", 0, 0) -- First car, set to 0
		--debugPrint("CARNUM: Sending 0 to " .. reverseMsgDir(direction))
		Call("SendConsistMessage", CARNUM_RET_ID, 0, reverseMsgDir(direction)) -- Send return ID back down line
		cancel = true
	end
	
	if (msg == CARNUM_RET_ID) then
		local carNum = argument + 1
		--direction = reverseMsgDir(direction)
		Call("*:SetControlValue", "CarNum", 0, carNum)
		--debugPrint("CARNUM_RET: Sending " .. carNum .. " to " .. direction)
		Call("SendConsistMessage", CARNUM_RET_ID, carNum, direction)
		cancel = true
	end
	
	if not cancel then
		-- Pass message along in same direction.
		Call( "SendConsistMessage", msg, argument, direction )
	end
end

function OnCustomSignalMessage(argument)
	for msg, arg in string.gfind(tostring(argument), "([^=\n]+)=([^=\n]+)") do
		if (tonumber(msg) == MSG_ATO_SPEED_LIMIT) then
			local speedLimit = tonumber(arg)
			if (speedLimit) then
				Call("*:SetControlValue", "ATOSpeedLimit", 0, speedLimit)
			end
		elseif (tonumber(msg) == MSG_SIGN_CHANGE) then
			--debugPrint("Received sign change command")
			if (Call("*:GetControlValue", "Active", 0) > 0.5) then
				local curSignIndex = Call("*:GetControlValue", "DestinationSign", 0)
				--debugPrint("Current sign: " .. tostring(curSignIndex))
				if (curSignIndex < NUM_SIGNS and curSignIndex >= 0) then
					local curSign = SIGNS[curSignIndex + 1]
					--debugPrint("Changing to: " .. tostring(curSign.nextSign))
					Call("*:SetControlValue", "DestinationSign", 0, curSign.nextSign)
				end
			end
		end
	end
	
end

function OnControlValueChange ( name, index, value )
	--debugPrint("Control changed: " .. tostring(name) .. " (to: " .. tostring(value) .. ")")

	if Call( "*:ControlExists", name, index ) then
		Call( "*:SetControlValue", name, index, value )
		
		if (name == "DynamicBrake" and Call("*:GetControlValue", "Active", 0) > 0) then
			Call("SendConsistMessage", DYNAMIC_ID, value, 1)
			Call("SendConsistMessage", DYNAMIC_ID, value, 0)
		end
	end

end