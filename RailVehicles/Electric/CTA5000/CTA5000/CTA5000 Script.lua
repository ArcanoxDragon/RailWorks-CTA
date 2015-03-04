---------------------------------------
-- Class 377 Script --
---------------------------------------
--
-- (c) Railsimulator.com 2012
--

--include=..\..\Common\Scripts\CTA Util.lua

WHINE_ID = 1715
DYNAMIC_ID = 1716
CARCOUNT_ID = 1717
CARCOUNT_RET_ID = 1718

MSG_ATO_SPEED_LIMIT = 42

CAR_COUNT_TIME = 1.0 -- seconds

local NUM_SIGNS = 7
local FRONT_SIGNS = { 	"sign_off",
						"sign_nis",
						"sign_express",
						"sign_red_howard",
						"sign_red_95th",
						"sign_brown_loop",
						"sign_brown_kimball",
						nil } -- The last "nil" is mainly just for formatting and ease of entry...

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
				CountCars()
			end
			
			gTimeSinceCarCount = gTimeSinceCarCount + time
			if (gTimeSinceCarCount >= CAR_COUNT_TIME) then
				gTimeSinceCarCount = 0
				CountCars()
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
	
	for i = 1, NUM_SIGNS do
		if ((i - 1 == math.floor(DestSign) and IsEndCar) or (not IsEndCar and i == 1)) then
			Call("*:ActivateNode", FRONT_SIGNS[i], 1)
		else
			Call("*:ActivateNode", FRONT_SIGNS[i], 0)
		end
	end
	
	if (DestSign > 0 and IsEndCar) then
		Call( "SignLightFront:Activate", 1 )
	else
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
	
	-- Determine the total number of cars in the consist

	Call( "*:SetControlValue", "NumCars", 0, 1 )
	Call( "SendConsistMessage", CARCOUNT_ID, 0, 0 )
	Call( "SendConsistMessage", CARCOUNT_ID, 0, 1 )
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
		end
	end
	
end

function OnControlValueChange ( name, index, value )

	if Call( "*:ControlExists", name, index ) then
		Call( "*:SetControlValue", name, index, value )
		
		if (name == "DynamicBrake" and Call("*:GetControlValue", "Active", 0) > 0) then
			Call("SendConsistMessage", DYNAMIC_ID, value, 1)
			Call("SendConsistMessage", DYNAMIC_ID, value, 0)
		end
	end

end