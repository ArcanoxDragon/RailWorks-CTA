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
CARPOWERCOUNT_ID = 1721
CARPOWERCOUNT_RET_ID = 1722

MSG_ATO_SPEED_LIMIT = 42
MSG_SIGN_CHANGE = 43
MSG_THIRD_RAIL_OFF = 50
MSG_THIRD_RAIL_ON = 51

SIGNAL_THIRD_RAIL_OFF = 30
SIGNAL_THIRD_RAIL_ON = 31

CAR_COUNT_TIME = 0.5 -- seconds

LAST_CLASS_LIGHT_L = -1
LAST_CLASS_LIGHT_R = -1

CLASS_LIGHTS_L = { { "classlight_red_l", 	"classlight_red_l_on" },
				   { "classlight_yellow_l", "classlight_yellow_l_on" },
				   { "classlight_green_l", 	"classlight_green_l_on" },
				   { "classlight_white_l", 	"classlight_white_l_on" } }

CLASS_LIGHTS_R = { { "classlight_red_r", 	"classlight_red_r_on" },
				   { "classlight_yellow_r", "classlight_yellow_r_on" },
				   { "classlight_green_r", 	"classlight_green_r_on" },
				   { "classlight_white_r", 	"classlight_white_r_on" } }
				   
local function setClassLight(classLight, on)
	Call("*:ActivateNode", classLight[1], on and 0 or 1)
	Call("*:ActivateNode", classLight[2], on and 1 or 0)
end

-- 0 = off
-- 1 = red
-- 2 = yellow
-- 3 = green
-- 4 = white
local function setClassLights(left, right)
	if left == LAST_CLASS_LIGHT_L and right == LAST_CLASS_LIGHT_R then -- Save on some iterations and Call()s
		return
	end
	
	--debugPrint("Setting class lights to: " .. tostring(left) .. ", " .. tostring(right))

	for i = 1, 4 do
		setClassLight(CLASS_LIGHTS_L[i], false)
		setClassLight(CLASS_LIGHTS_R[i], false)
	end
	
	if left and left > 0 and left <= 4 then
		setClassLight(CLASS_LIGHTS_L[left], true)
	end
	
	if right and right > 0 and right <= 4 then
		setClassLight(CLASS_LIGHTS_R[right], true)
	end
	
	LAST_CLASS_LIGHT_L = left
	LAST_CLASS_LIGHT_R = right
end

local NUM_SIGNS = 0
local SIGNS = { }

local function addSign(texName, lightOn, lightColor, lMarker, rMarker, nextSign) -- lMarker and rMarker are left/right marker/class lights, left is when looking *towards* front of train car
	local sign = { }
	local nSign = nextSign or NUM_SIGNS -- Same sign by default
	sign.id = texName
	sign.hasLight = lightOn
	sign.color = lightColor
	sign.nextSign = nSign
	sign.lMarker = lMarker
	sign.rMarker = rMarker
	
	SIGNS[NUM_SIGNS + 1] = sign
	NUM_SIGNS = NUM_SIGNS + 1
end

local function getSignIndex(letter)
	--debugPrint("Getting sign index for: " .. letter)
	for i = 1, NUM_SIGNS do
		if SIGNS[i].id == letter then
			--debugPrint("Returning sign index " .. tostring(i))
			return i
		end
	end
	
	debugPrint("Sign not found")
	return 0
end

--     ( id, light, lightColor, lMarker, rMarker, [ nextSign ] )
								--[[ Marker lights:
									0 - Off
									1 - Red
									2 - Yellow
									3 - Green
									4 - White
								  ]]
addSign("a", false, nil, 0, 0)             		 --[[  0 Off ]]
addSign("b",  true, { 100, 100, 100 }, 4, 4)     --[[  1 NIS ]]
addSign("c",  true, { 100, 100, 100 }, 4, 4)     --[[  2 Express ]] -- This has special marker light behavior (flashing) but we code it in anyways for consistency
addSign("d",  true, { 255,  31,  31 }, 2, 2)     --[[  3 Red Howard ]]
addSign("e",  true, { 255,  31,  31 }, 2, 2)     --[[  4 Red 95th ]]
addSign("f",  true, { 255,  31,  31 }, 2, 2)     --[[  5 Red Roosevelt ]]
addSign("g",  true, { 255,  31,  31 }, 2, 3)     --[[  6 Red 63rd ]]
addSign("h",  true, { 165,  95,  35 }, 3, 1, 8)  --[[  7 Brown Loop ]]
addSign("i",  true, { 165,  95,  35 }, 3, 1)     --[[  8 Brown Kimball ]]
addSign("j",  true, { 165,  95,  35 }, 2, 1)     --[[  9 Brown Belmont ]]
addSign("k",  true, { 255, 127,  63 }, 1, 2, 11) --[[ 10 Orange Loop ]]
addSign("l",  true, { 255, 127,  63 }, 1, 2)     --[[ 11 Orange Midway ]]
addSign("m",  true, { 155,   0, 215 }, 4, 4, 14) --[[ 12 Purple Loop ]]
addSign("n",  true, { 155,   0, 215 }, 2, 1)     --[[ 13 Purple Howard ]]
addSign("o",  true, { 155,   0, 215 }, 4, 4)     --[[ 14 Purple Linden ]]
addSign("p",  true, { 235,  90, 185 }, 4, 1, 16) --[[ 15 Pink Loop ]]
addSign("q",  true, { 235,  90, 185 }, 4, 1)     --[[ 16 Pink 54th/Cermak ]]
addSign("r",  true, {  31, 255,  31 }, 3, 3)     --[[ 17 Green Harlem ]]
addSign("s",  true, { 191, 255, 191 }, 4, 3)     --[[ 18 Green Cottage Grove ]]
addSign("t",  true, {  31, 255,  31 }, 3, 3)     --[[ 19 Green Ashland/63rd ]]
addSign("u",  true, {  31, 255,  31 }, 3, 3)     --[[ 20 Green Roosevelt ]]
addSign("D",  true, {  31, 255,  31 }, 2, 3)     --[[ 21 Green Loop ]]
addSign("v",  true, {   0,  95, 235 }, 2, 2)     --[[ 22 Blue O'Hare ]]
addSign("w",  true, {   0,  95, 235 }, 2, 2)     --[[ 23 Blue Forest Park ]]
addSign("x",  true, { 191, 191, 255 }, 2, 3)     --[[ 24 Blue UIC ]]
addSign("y",  true, {   0,  95, 235 }, 2, 3)     --[[ 25 Blue Rosemont ]]
addSign("z",  true, {   0,  95, 235 }, 2, 3)     --[[ 26 Blue Jefferson Park ]]
addSign("A",  true, { 191, 191, 255 }, 3, 3)     --[[ 27 Blue 54th/Cermak ]]
addSign("B",  true, { 255, 255,   0 }, 3, 3)     --[[ 28 Yellow Skokie ]]
addSign("C",  true, { 255, 255,   0 }, 3, 3)     --[[ 29 Yellow Howard ]]

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
	gDoorsOpenTime = 0.0
	gBodyTilt = 0.0
	gCamInside = false
	gLastDir = 1
	tLastDir = 1
	gIsBCar = 0 -- Is this an "A" car or a "B" car?
	gInit = false
	gOnThirdRail = true
	gBrakeCheckTime = 0.0
	gParkingBrake = false
	gExpressLightTimer = 0.0
	gExpressLightsOn = false
	gLeadCarReversed = 1
	
-- Moving average for acceleration
	gMovingAvgSize = 20
	gMovingAvgList = { }
	gMovingAvgIndex = 0 -- 0 - 9
	gMovingAvg = 0
	
-- Misc. signal stuff
	gLastSignalDist = 0
	
-- Control cache
	gControlCache = { }
	
	SetControlValue("OnThirdRail", 1)
	
	HeadlightOn   = false
	TaillightOn   = false
	ClassLightsOn = false

	Call( "BeginUpdate" )
end

function GetControlValue(name)
	return Call("*:GetControlValue", name, 0)
end

function SetControlValue(name, value)
	Call("*:SetControlValue", name, 0, value)
	gControlCache[name] = value
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

sigType = 0
sigState = 0
sigDist = 0
sigAspect = 0

function Update(time)
	local trainSpeed = Call("GetSpeed") * MPS_TO_MPH
	local accel = Call("GetAcceleration") * MPS_TO_MPH
	local reverser = GetControlValue("Reverser")
	local IsEndCar = GetControlValue( "IsEndCar" ) > 0
	local CarNum = GetControlValue( "CarNum" )
	local HandBrake = GetControlValue("HandBrakeCommand")
	local TrueHandBrake = GetControlValue("HandBrake")
	local BrakePressure = GetControlValue("TrainBrakeCylinderPressureBAR")
	local DestSign = GetControlValue( "DestinationSign" )
	
	if (not gInit) then
		-- Set "DestinationSign" control to value from car number (allows scenarios to set destsign)
		RVNumber = Call("*:GetRVNumber")
		if (string.len(RVNumber) == 5) then
			lastPart = string.lower(string.sub(RVNumber, 5, 5))
			SetControlValue("DestinationSign", getSignIndex(lastPart) - 1)
		else
			Call("*:SetRVNumber", "5001a")
		end
		
		gInit = true
	end

	--if ( Call( "GetIsPlayer" ) == 1 ) then
		gTimeSinceCarCount = gTimeSinceCarCount + time
		if (gTimeSinceCarCount >= CAR_COUNT_TIME) then
			gTimeSinceCarCount = 0
			CountCars()
		end
			
		local whine = GetControlValue("TractionWhine")
		local dynamic = GetControlValue("DynamicBrake")

		if ( GetControlValue( "Active" ) == 1 ) then
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
		end
	
		-- Headlights
		
		if math.abs(reverser) >= 0.15 then
			Headlights = 1
		else
			Headlights = 0
		end
		
		SetControlValue( "Headlights", Headlights )
		
		if (Headlights > 0.5 and IsEndCar) then
			if CarNum == 0 then -- Leading car ("active cab")
				Call( "HeadlightL:Activate", 1 )
				Call( "HeadlightR:Activate", 1 )
				Call( "TaillightL:Activate", 0 )
				Call( "TaillightR:Activate", 0 )
				
				HeadlightOn   = true
				TaillightOn   = false
				
				if DestSign > 0 then
					ClassLightsOn = true
				else
					ClassLightsOn = false
					setClassLights(0, 0)
				end
			else -- Trailing car (opposite "active cab" end)
				Call( "HeadlightL:Activate", 0 )
				Call( "HeadlightR:Activate", 0 )
				Call( "TaillightL:Activate", 1 )
				Call( "TaillightR:Activate", 1 )
				
				HeadlightOn   = false
				TaillightOn   = true
				ClassLightsOn = false
				
				setClassLights(1, 1) -- Red, Red
			end
		else -- Either middle car or headlights were switched off
			Call( "HeadlightL:Activate", 0 )
			Call( "HeadlightR:Activate", 0 )
			Call( "TaillightL:Activate", 0 )
			Call( "TaillightR:Activate", 0 )
			
			HeadlightOn   = false
			TaillightOn   = false
			ClassLightsOn = false
			
			setClassLights(0, 0) -- Off, Off
		end
	
		if HeadlightOn then
			Call("*:ActivateNode", "headlights", 1)
		else
			Call("*:ActivateNode", "headlights", 0)
		end
	
		if TaillightOn then
			Call("*:ActivateNode", "taillights", 1)
		else
			Call("*:ActivateNode", "taillights", 0)
		end
		
		-- Door light clusters
		
		if GetControlValue("DoorsOpenCloseRight") > 0.5 then
			Call("*:ActivateNode", "doorlights_right", 1)
		end
		
		if GetControlValue("DoorsOpenCloseLeft") > 0.5 then
			Call("*:ActivateNode", "doorlights_left", 1)
		end
		
		if GetControlValue("DoorsOpen") < 0.5 then
			Call("*:ActivateNode", "doorlights_right", 0)
			Call("*:ActivateNode", "doorlights_left", 0)
		end
		
		if BrakePressure >= 0.05 or TrueHandBrake > 0.5 then
			Call("*:ActivateNode", "brakelights", 1)
		else
			Call("*:ActivateNode", "brakelights", 0)
		end
		
		-- Cab speed
		
		local cabSpeed = clamp(math.floor(math.abs(trainSpeed)), 0, 72)
		SetControlValue("CabSpeedIndicator", cabSpeed)

		if gInitialised == FALSE then
			gInitialised = TRUE
		end

	-- Check if player is driving this engine.

		if ( Call( "GetIsEngineWithKey" ) == 1 ) then
			if gDriven ~= 1 then
				gDriven = 1
				SetControlValue( "Active", 1 )
			end
		else
			if gDriven ~= 0 then
				gDriven = 0
				SetControlValue( "Active", 0 )
				SetControlValue( "ATOActive", 0 )
			end
		end
	--end
	
	-- Third rail signal
	sigType, sigState, sigDist, sigAspect = Call("*:GetNextRestrictiveSignal", mod(GetControlValue("CarNum"), 2))
	SetControlValue("NextSignalAspect", sigAspect)
	SetControlValue("NextSignalDist", sigDist)
	if (sigDist < 1.0) then
		if (sigDist < gLastSignalDist - 0.01) then
			if (sigAspect == SIGNAL_THIRD_RAIL_OFF) then
				gOnThirdRail = false
			elseif (sigAspect == SIGNAL_THIRD_RAIL_ON) then
				gOnThirdRail = true
			end
		elseif (sigDist > gLastSignalDist + 0.01) then
			if (sigAspect == SIGNAL_THIRD_RAIL_OFF) then
				gOnThirdRail = true
			elseif (sigAspect == SIGNAL_THIRD_RAIL_ON) then
				gOnThirdRail = false
			end

		end
	end
	gLastSignalDist = sigDist
	
	if GetControlValue("ThirdRail") < 0.5 then
		SetControlValue("OnThirdRail", 0)
	else
		SetControlValue("OnThirdRail", gOnThirdRail and 1 or 0)
	end
	
	-- Inverter whine based on current
	
	local tWhine = 1.0
	local dWhine = 1.2 * time
	local current = GetControlValue("Ammeter")
	local tAccel = GetControlValue("TAccel")
	if ( GetControlValue("OnThirdRail") < 0.5) then
		tWhine = 0.0
	end
	
	if (gWhine < tWhine - dWhine) then
		gWhine = gWhine + dWhine
	elseif (gWhine > tWhine + dWhine) then
		gWhine = gWhine - dWhine
	else
		gWhine = tWhine
	end
	
	if (Call("GetIsPlayer") < 0.5) then
		SetControlValue( "TractionWhine", 1.0 )
	else
		SetControlValue( "TractionWhine", clamp(gWhine, 0.0, 1.0) )
	end
	
	-- Direction
	local realAccel = GetControlValue("Acceleration")
	local signSpeed = sign(trainSpeed / GetControlValue("SpeedometerMPH"))
	local signAccel = sign(accel / realAccel)
	local evenCar = mod(GetControlValue("CarNum"), 2) == 0
	if (math.abs(trainSpeed) > 0.01 and math.abs(realAccel) > 0.001 and math.abs(accel) > 0.001) then
		gLastDir = -sign(accel / realAccel)
		gLastDir = gLastDir * sign(signSpeed / signAccel)
		if (GetControlValue("Active") > 0) then
			SetControlValue("Direction", signSpeed)
		end
	end
	
	if (math.abs(trainSpeed) > 0.25 and math.abs(realAccel) > 0.1 and math.abs(accel) > 0.1) then
		gLeadCarReversed = sign(signSpeed / signAccel)
	end
	
	gLastDir = gLastDir * gLeadCarReversed
	
	SetControlValue("SignSpeed", signSpeed)
	SetControlValue("SignAccel", signAccel)
	
	SetControlValue("Speed2", round(trainSpeed, 2))
	
	-- Fix door animation
	local doorsLeft = GetControlValue("DoorsOpenCloseLeft") > 0
	local doorsRight = GetControlValue("DoorsOpenCloseRight") > 0
	if (doorsLeft or doorsRight) then
		local doorSide = doorsLeft and "doors_left" or "doors_right"
		gDoorsOpenTime = gDoorsOpenTime + time
		if (gDoorsOpenTime >= 2.5) then -- 2.5 seconds; doors fully open
			Call("*:SetTime", doorSide, 8.0) -- 8.0 is fully animated; animation won't glitch if doors close too soon
		end
	else
		gDoorsOpenTime = 0.0
	end
	
	-- Acceleration tilt
	
	UpdateMovingAverage(accel) -- MPH/s
	local accelAvg = GetMovingAverage() -- Smooth out acceleration
	SetControlValue("Accel2", accelAvg)
	accelAvg = accelAvg / 5.25 -- Max accel for animation is 5.25 MPH/s (full emergency braking)
	accelAvg = accelAvg * gLastDir
	accelAvg = accelAvg * GetControlValue("Direction")
	if not evenCar then -- but is it really even a car, bro?
		accelAvg = -accelAvg
	end
	tiltMult = 0.6
	if (gCamInside) then
		tiltMult = 0.4
	end
	tBodyTilt = 1.0 + clamp(accelAvg * tiltMult, -1, 1)
	dBodyTilt = 10 * clamp(math.abs(gBodyTilt - tBodyTilt) / 0.65, 0.1, 1.0)
	dBodyTilt = dBodyTilt * time
	if (gBodyTilt < tBodyTilt - dBodyTilt) then
		gBodyTilt = gBodyTilt + dBodyTilt
	elseif (gBodyTilt > tBodyTilt + dBodyTilt) then
		gBodyTilt = gBodyTilt - dBodyTilt
	else
		gBodyTilt = tBodyTilt
	end
		
	Call("*:SetTime", "body_tilt", gBodyTilt)
	SetControlValue("BodyTilt", gBodyTilt - 1.0)
	
	-- Relay train brake command to this car's brakes and apply local handbrake as a parking brake
	
	gBrakeCheckTime = gBrakeCheckTime + time
	lRandom = math.random() * 0.5 -- Add a bit of randomness, adds 'realism' and variety to simulation
	if (gBrakeCheckTime > 0.5 + lRandom) then
		gBrakeCheckTime = 0
		if (math.abs(trainSpeed) < 0.1 and BrakePressure >= 0.2) then
			gParkingBrake = true
		elseif (BrakePressure <= 0.01) then
			gParkingBrake = false
		end
	end
	
	if (gParkingBrake) then
		HandBrake = 1
	end
	
	SetControlValue("HandBrake", HandBrake)
	
	-- Destination sign
	
	RVNumber = Call("*:GetRVNumber")
	firstPart = "5001"
	if (string.len(RVNumber) == 5) then
		firstPart = string.sub(RVNumber, 1, 4)
		lastPart = string.sub(RVNumber, 5, 5)
		
		if (Call("GetIsPlayer") == 0) then
			DestSign = getSignIndex(string.lower(lastPart)) - 1
		end
	else
		Call("*:SetRVNumber", "5001a")
	end
	
	if (DestSign > 0 and DestSign < NUM_SIGNS and SIGNS[DestSign + 1]) then
		local sign = SIGNS[DestSign + 1]
		local secondPart = sign.id
		Call("*:SetRVNumber", firstPart .. secondPart)
		
		Call("*:ActivateNode", "side_displays", 1)
		
		if (IsEndCar) then
			Call("*:ActivateNode", "sign_off_front", 0)
			
			if (sign.hasLight) then
				Call( "SignLightFront:Activate", 1 )
				Call( "SignLightFront:SetColour", sign.color[1] / 255, sign.color[2] / 255, sign.color[3] / 255 )
			else
				Call( "SignLightFront:Activate", 0 )
			end
			
			if ClassLightsOn then -- Only on active cab; set earlier by "Headlights" code
				if (DestSign == 2) then -- Express
					gExpressLightTimer = gExpressLightTimer + time
					
					if gExpressLightTimer >= 1.0 then -- toggle lights every second
						gExpressLightTimer = 0.0
						gExpressLightsOn = not gExpressLightsOn
						
						if gExpressLightsOn then
							setClassLights(4, 4) -- White, White
						else
							setClassLights(0, 0) -- Off, Off
						end
					end
				else
					gExpressLightTimer = 1.0
					gExpressLightsOn = false
				
					setClassLights(sign.lMarker, sign.rMarker)
				end
			end
		else
			Call("*:ActivateNode", "sign_off_front", 1)
			
			Call( "SignLightFront:Activate", 0 )
		end
	else
		if (Call("GetIsPlayer") == 0) then
			Call("*:SetRVNumber", firstPart .. "a")
		end
		Call( "SignLightFront:Activate", 0 )
		Call("*:ActivateNode", "sign_off_front", 1)
		Call("*:ActivateNode", "side_displays", 0)
	end
	
	if (Call("GetIsPlayer") == 0) then
		SetControlValue("DestinationSign", DestSign)
	end
end

function CountCars()
	-- Determine if we're the front/back car or a middle car
	local rev = Call( "SendConsistMessage", 0, 0, 1 )
	local fwd = Call( "SendConsistMessage", 0, 0, 0 )
	local endCar = false
	
	if (fwd + rev == 1) then
		SetControlValue("IsEndCar", 1)
		endCar = true
	else
		SetControlValue("IsEndCar", 0)
	end
	
	if (GetControlValue("Active") > 0) then
		-- Determine the total number of cars in the consist

		SetControlValue( "NumCars", 1 )
		if (GetControlValue("OnThirdRail") > 0) then
			SetControlValue( "NumCarsOnPower", 1 )
		else
			SetControlValue( "NumCarsOnPower", 0 )
		end
		Call( "SendConsistMessage", CARCOUNT_ID, 0, 0 )
		Call( "SendConsistMessage", CARCOUNT_ID, 0, 1 )
		
		Call( "SendConsistMessage", CARPOWERCOUNT_ID, 0, 0 )
		Call( "SendConsistMessage", CARPOWERCOUNT_ID, 0, 1 )
		
		-- Set "car ID" of each car
		--debugPrint("Setting car IDs...this car is " .. (endCar and "an" or "not an") .. " end car")
		if (endCar) then -- Already at end, send backwards
			Call( "SendConsistMessage", CARNUM_RET_ID, 0, 1 )
			SetControlValue( "CarNum", 0 )
		else -- Not at end, send forwards so it bounces back from the end
			Call( "SendConsistMessage", CARNUM_ID, 0, 0 )
		end
	end
end

function OnConsistMessage ( msg, argument, direction )
	local cancel = false
	
	-- If this is not the driven vehicle then update the passed-down controls with values from the master engine
	if (GetControlValue("Active") == 0) then
		if (msg == WHINE_ID) then
			--SetControlValue("TractionWhine", argument)
		end
		
		if (msg == DYNAMIC_ID) then
			SetControlValue("DynamicBrake", argument)
		end
		
		if (msg == CARCOUNT_ID) then -- Going down train counting cars
			cancel = true
			argument = tonumber(argument) + 1
			local sent = Call( "SendConsistMessage", msg, argument, direction )
			if (sent == 0) then
				Call( "SendConsistMessage", CARCOUNT_RET_ID, argument, reverseMsgDir(direction) )
			end
		end
		
		if (msg == CARPOWERCOUNT_ID) then -- Going down train counting cars
			cancel = true
			argument = tonumber(argument)
			if (GetControlValue("OnThirdRail") > 0) then
				argument = argument + 1
			end
			local sent = Call( "SendConsistMessage", msg, argument, direction )
			if (sent == 0) then
				Call( "SendConsistMessage", CARPOWERCOUNT_RET_ID, argument, reverseMsgDir(direction) )
			end
		end
	else
		if (msg == CARCOUNT_RET_ID) then
			local curCarCount = GetControlValue("NumCars")
			SetControlValue("NumCars", curCarCount + argument)
		end
		
		if (msg == CARPOWERCOUNT_RET_ID) then
			local curCarCount = GetControlValue("NumCarsOnPower")
			SetControlValue("NumCarsOnPower", curCarCount + argument)
		end
	end
	
	if (msg == CARNUM_ID and GetControlValue("IsEndCar") > 0) then -- End car, return back down the line
		SetControlValue("CarNum", 0) -- First car, set to 0
		--debugPrint("CARNUM: Sending 0 to " .. reverseMsgDir(direction))
		Call("SendConsistMessage", CARNUM_RET_ID, 0, reverseMsgDir(direction)) -- Send return ID back down line
		cancel = true
	end
	
	if (msg == CARNUM_RET_ID) then
		local carNum = argument + 1
		--direction = reverseMsgDir(direction)
		SetControlValue("CarNum", carNum)
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
	if (type(argument) == "string") then
		for msg, arg in string.gfind(tostring(argument), "([^=\n]+)=([^=\n]+)") do
			if (tonumber(msg) == MSG_ATO_SPEED_LIMIT) then
				local speedLimit = tonumber(arg)
				if (speedLimit) then
					SetControlValue("ATOSpeedLimit", speedLimit)
				end
			elseif (tonumber(msg) == MSG_SIGN_CHANGE) then
				--debugPrint("Received sign change command")
				if (GetControlValue("Active") > 0.5) then
					local curSignIndex = GetControlValue("DestinationSign")
					--debugPrint("Current sign: " .. tostring(curSignIndex))
					if (curSignIndex < NUM_SIGNS and curSignIndex >= 0) then
						local curSign = SIGNS[curSignIndex + 1]
						--debugPrint("Changing to: " .. tostring(curSign.nextSign))
						SetControlValue("DestinationSign", curSign.nextSign)
						RVNumber = Call("*:GetRVNumber")
						firstPart = "5001"
						if (string.len(RVNumber) == 5) then
							firstPart = string.sub(RVNumber, 1, 4)
							Call("*:SetRVNumber", firstPart .. curSign.nextSign.id)
						else
							Call("*:SetRVNumber", "5001a")
						end
					end
				end
			--[[elseif (tonumber(msg) == MSG_THIRD_RAIL_OFF) then
				SetControlValue("OnThirdRail", 0)
				debugPrint("Car #" .. tostring(GetControlValue("CarNum")) .. ": Went off third rail")
			elseif (tonumber(msg) == MSG_THIRD_RAIL_ON) then
				SetControlValue("OnThirdRail", 1)
				debugPrint("Car #" .. tostring(GetControlValue("CarNum")) .. ": Went on third rail")]]
			end
		end
	end
end

function OnControlValueChange( name, index, value )
	if (index == 0) then
		gControlCache[name] = value
	end

	if Call( "*:ControlExists", name, index ) then
		Call( "*:SetControlValue", name, index, value )
		
		if (name == "DynamicBrake" and GetControlValue("Active") > 0) then
			Call("SendConsistMessage", DYNAMIC_ID, value, 1)
			Call("SendConsistMessage", DYNAMIC_ID, value, 0)
		end
	end

end