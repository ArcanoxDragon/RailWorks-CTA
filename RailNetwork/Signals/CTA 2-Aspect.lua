--------------------------------------------------------------------------------------
-- UK 2 Aspect Signal Post
-- RSDL / Rail Simulator
--------------------------------------------------------------------------------------

--include=CommonScripts\Common Color Light Script.lua
--include=CommonScripts\Common Signal Script.lua

-- This is a two aspect signal
gAspect					= 3

--------------------------------------------------------------------------------------
-- INITIALISE
--
function Initialise ()
	-- Set our light node names
	LIGHT_NODE_GREEN		= "lens_green1"
	LIGHT_NODE_YELLOW		= "lens_yellow1"
	LIGHT_NODE_YELLOW2		= "lens_yellow2"
	LIGHT_NODE_RED			= "lens_red1"
	LIGHT_NODE_RED2			= "lens_red2"

	-- Standard 2 ASP Signals with feathers use feather node names starting with this -
	FEATHER_ROOT_NAME		= "feather_"

	DefaultInitialise( )
end

--------------------------------------------------------------------------------------
-- SET LIGHTS
-- Switches the lights on / off depending on state of signal
--
function SetLights( newState )
	DefaultSetLights( newState )
end

--------------------------------------------------------------------------------------
-- DETERMINE SIGNAL STATE
-- Figures out what lights to show and messages to send based on the state of the signal
--
function DetermineSignalState()
	DefaultDetermineSignalState()
end

--------------------------------------------------------------------------------------
-- UPDATE
-- Initialises the signal when the route finishes loading, and handles flashing lights
--
function Update ( time )
	DefaultUpdate( time )
end

--------------------------------------------------------------------------------------
-- ON CONSIST PASS
-- Called when a train passes one of the signal's links
--
function OnConsistPass ( prevFrontDist, prevBackDist, frontDist, backDist, linkIndex )

	-- Use DefaultOnConsistPass
	DefaultOnConsistPass ( prevFrontDist, prevBackDist, frontDist, backDist, linkIndex )
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
-- ON CONTROL MODE CHANGE
-- Called by code when the operator changes the control mode of a signal
--
function OnControlModeChange( control_state )

	-- Use DefaultOnControlModeChange
	DefaultOnControlModeChange( control_state )
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