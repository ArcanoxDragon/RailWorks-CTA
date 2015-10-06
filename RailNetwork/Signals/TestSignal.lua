--include=CommonScripts\Common Signal Script.lua
--include=CommonScripts\Common Color Light Script.lua

MSG_CUSTOM 				= 15
MSG_ATO_SPEED_LIMIT 	= 42

MPS_TO_MPH 				= 2.23694 -- Meters/Second to Miles/Hour

SIGNAL_STATE			= 28

f = io.open("debug.txt", "w")
f:write("opened\n")
f:flush()

debug = function(message)
	print(message)
	f:write(message .. "\n")
	f:flush()
	DebugPrint(message)
end

function Initialize()
	debug("Initialize Called")
	
	-- This is a post signal, so need reference to the attached signal head to switch lights on and off
	SIGNAL_HEAD_NAME 		= "Test Signal"

	-- This is a two aspect signal
	gAspect					= 2

	DefaultInitialise()
end

function Initialise() Initialize() end -- Stupid British spelling

function Update(interval)

-- If this is the initialisation pass for the signal...
	if not gInitialised then
	
		debug("Initialising signal")
	
		-- Remember that we've been initialised
		gInitialised = true

		-- Update signal state and 2D map
		gSignalState = WARNING
		Call ("Set2DMapSignalState", WARNING)
		Call( "Set2DMapProSignalState", SIGNAL_STATE )
	end
	
	-- Stop updating
	Call( "EndUpdate" )
end

function OnConsistPass(prevFrontDist, prevRearDist, frontDist, rearDist, linkIndex)
	if (linkIndex == 0) then
		local crossingStart = 0
		local crossingEnd = 0

		if ( frontDist > 0 and rearDist < 0 ) or ( frontDist < 0 and rearDist > 0 ) then
			if ( prevFrontDist < 0 and prevRearDist < 0 ) or ( prevFrontDist > 0 and prevRearDist > 0 ) then
				crossingStart = 1
			end
		else
			if ( prevFrontDist < 0 and prevRearDist > 0 ) or ( prevFrontDist > 0 and prevRearDist < 0 ) then
				crossingEnd = 1
			end
		end
		
		if (crossingStart > 0) then
			debug("Sending text-based consist message")
			local test = SysCall("PlayerEngine:GetControlValue", "SpeedometerMPH", 0)
			debug("Test: " .. tostring(test))
			Call("SendConsistMessage", MSG_CUSTOM, tostring(test))
		end
	end
end

--------------------------------------------------------------------------------------
-- JUNCTION STATE CHANGE
-- Called when a junction is changed. Should only be handled by home signals.
--
function OnJunctionStateChange( junction_state, parameter, direction, linkIndex )
	-- Repeater; nothing
end

-------------------------------------------------------------------------------------
-- ON SIGNAL MESSAGE
-- Handles messages from other signals. 
--
function OnSignalMessage( message, parameter, direction, linkIndex )
	-- Just pass the message along...we're a repeater
	Call("SendSignalMessage", message, parameter, -direction, 1, linkIndex)
end

function GetSignalState()
	return 1 -- Warning
end