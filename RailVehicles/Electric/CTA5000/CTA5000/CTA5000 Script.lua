---------------------------------------
-- Class 377 Script --
---------------------------------------
--
-- (c) Railsimulator.com 2012
--


	TRUE = 1
	FALSE = 0

	WHINE_ID = 1715
	DYNAMIC_ID = 1716
	MSG_ATO_SPEED_LIMIT = 42

local gDebugFile = io.open("cmt100debug.log", "w")

function debugPrint(msg)
	print(msg)
	Print(msg .. "\n")
	gDebugFile:seek("end", 0)
	gDebugFile:write(msg .. "\n")
	gDebugFile:flush()
end

function Initialise()
-- For AWS self test.
	gAWSReady = TRUE
	gAWSTesting = FALSE

-- Stores for checking when values have changed.
	gDriven = -1
	gHeadlight = -1
	gTaillight = -1
	gInitialised = FALSE
	
-- Delta variables
	gPrevWhine = 0
	gPrevDynamic = 0.0

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
			end
		else
			if gDriven ~= 0 then
				gDriven = 0
				Call( "*:SetControlValue", "Active", 0, 0 )
				Call( "*:SetControlValue", "ATOActive", 0, 0 )
			end
		end
	end

end

function OnConsistMessage ( msg, argument, direction )
	-- If this is not the driven vehicle then update the passed-down controls with values from the master engine
	if (Call("*:GetControlValue", "Active", 0) == 0) then
		if (msg == WHINE_ID) then
			Call("*:SetControlValue", "TractionWhine", 0, argument)
		end
		
		if (msg == DYNAMIC_ID) then
			--Call("*:SetControlValue", "DynamicBrake", 0, argument)
		end
	end
	
	-- Pass message along in same direction.
	Call( "SendConsistMessage", msg, argument, direction )
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
	end

end