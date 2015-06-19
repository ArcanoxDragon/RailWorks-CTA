--include=..\..\Common\Scripts\CTA Util.lua
--include=CommonScripts\Common Signal Script.lua
--include=CommonScripts\Common Color Light Script.lua

MSG_CUSTOM 					= 15
MSG_THIRD_RAIL_ON	 		= 51

SIGNAL_STATE_THIRD_RAIL_ON	= 31

function Initialise()
	-- This is a post signal, so need reference to the attached signal head to switch lights on and off
	SIGNAL_HEAD_NAME 		= "Third Rail On"

	-- Set our light node names
	LIGHT_NODE_GREEN		= "groundsignal_white"
	LIGHT_NODE_RED			= "groundsignal_red"
	
	-- This is a two aspect signal
	gAspect					= 2

	DefaultInitialise()
end

function Update(interval)

-- If this is the initialisation pass for the signal...
	if not gInitialised then
	
		DebugPrint("Initialising signal")
	
		-- Remember that we've been initialised
		gInitialised = true

		-- Update signal state and 2D map
		gSignalState = WARNING
		Call ("Set2DMapSignalState", WARNING)
		Call( "Set2DMapProSignalState", SIGNAL_STATE_THIRD_RAIL_ON )
	end
	
	-- Stop updating
	Call( "EndUpdate" )
end

function OnConsistPass(prevFrontDist, prevRearDist, frontDist, rearDist, linkIndex)
	-- Repeater; do nothing
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