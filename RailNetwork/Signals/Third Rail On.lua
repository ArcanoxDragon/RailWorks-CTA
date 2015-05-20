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
			--Call("SendConsistMessage", MSG_CUSTOM, tostring(MSG_THIRD_RAIL_ON) .. "=0")
		end
	end
end

function DetermineSignalState()

end

--------------------------------------------------------------------------------------
-- JUNCTION STATE CHANGE
-- Called when a junction is changed. Should only be handled by home signals.
--
function OnJunctionStateChange( junction_state, parameter, direction, linkIndex )

	-- Use DefaultOnJunctionStateChange
	DefaultOnJunctionStateChange( junction_state, parameter, direction, linkIndex )
end

-------------------------------------------------------------------------------------
-- REACT TO SIGNAL MESSAGE
-- Subfunction to save duplicate code when handling pass back messages - just takes all the old scripting out of the OnSignalMessage function
--
function ReactToSignalMessage( message, parameter, direction, linkIndex )

	-- Use DefaultReactToSignalMessage
	DefaultReactToSignalMessage( message, parameter, direction, linkIndex )
end

-------------------------------------------------------------------------------------
-- ON SIGNAL MESSAGE
-- Handles messages from other signals. 
--
function OnSignalMessage( message, parameter, direction, linkIndex )

	-- Use DefaultOnSignalMessage
	DefaultOnSignalMessage( message, parameter, direction, linkIndex )
end

function GetSignalState()
	return 1 -- Warning
end