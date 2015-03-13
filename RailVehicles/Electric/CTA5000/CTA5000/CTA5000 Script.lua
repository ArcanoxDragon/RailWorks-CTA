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

MSG_ATO_SPEED_LIMIT = 42
MSG_SIGN_CHANGE = 43

CAR_COUNT_TIME = 1.0 -- seconds

local NUM_SIGNS = 0
local SIGNS = { }

local function addSign(texName, lightOn, lightColor, nextSign)
	local sign = { }
	local nSign = nextSign or 1 -- "Not In Service" by default
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
addSign("i",  true, { 165,  95,  35 }, 8)  --[[  8 Brown Kimball ]]
addSign("j",  true, { 165,  95,  35 }, 9)  --[[  9 Brown Belmont ]]
addSign("k",  true, { 255, 127,  63 }, 11) --[[ 10 Orange Loop ]]
addSign("l",  true, { 255, 127,  63 }, 11) --[[ 11 Orange Midway ]]
addSign("m",  true, { 155,   0, 215 }, 14) --[[ 12 Purple Loop ]]
addSign("n",  true, { 155,   0, 215 }, 13) --[[ 13 Purple Howard ]]
addSign("o",  true, { 155,   0, 215 }, 14) --[[ 14 Purple Linden ]]
addSign("p",  true, { 235,  90, 185 }, 16) --[[ 15 Pink Loop ]]
addSign("q",  true, { 235,  90, 185 }, 16) --[[ 16 Pink 54th/Cermak ]]
addSign("r",  true, {  31, 255,  31 }, 17) --[[ 17 Green Harlem ]]
addSign("s",  true, { 191, 255, 191 }, 18) --[[ 18 Green Cottage Grove ]]
addSign("r",  true, {  31, 255,  31 }, 19) --[[ 19 Green Ashland/63rd ]]
addSign("u",  true, {  31, 255,  31 }, 20) --[[ 20 Green Roosevelt ]]
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
	
-- Time variables
	gTimeSinceCarCount = 0.0

	Call( "BeginUpdate" )
end

function Update(time)

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
		Call("*:SetRVNumber", firstPart .. sign.id)
		
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
	local fwd = Call( "SendConsistMessage", 0, 0, 1 )
	local rev = Call( "SendConsistMessage", 0, 0, 0 )
	
	if (fwd + rev == 1) then
		Call("*:SetControlValue", "IsEndCar", 0, 1)
	else
		Call("*:SetControlValue", "IsEndCar", 0, 0)
	end
	
	if (Call("*:GetControlValue", "Active", 0) > 0) then
		-- Determine the total number of cars in the consist

		Call( "*:SetControlValue", "NumCars", 0, 1 )
		Call( "SendConsistMessage", CARCOUNT_ID, 0, 0 )
		Call( "SendConsistMessage", CARCOUNT_ID, 0, 1 )
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
			debugPrint("Received sign change command")
			if (Call("*:GetControlValue", "Active", 0) > 0.5) then
				local curSignIndex = Call("*:GetControlValue", "DestinationSign", 0)
				debugPrint("Current sign: " .. tostring(curSignIndex))
				if (curSignIndex < NUM_SIGNS and curSignIndex >= 0) then
					local curSign = SIGNS[curSignIndex + 1]
					debugPrint("Changing to: " .. tostring(curSign.nextSign))
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