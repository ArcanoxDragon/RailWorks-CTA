------------------------------------------------------------------------------
-- Signals\Pro Signals\CommonScripts                                        --
--             C o m m o n   U K   R e p e a t e r . l u a                  --
--                                                                          --
------------------------------------------------------------------------------

--------------------------------------------------------------------------------------
-- SET LIGHTS
-- Switches the lights on / off depending on state of signal
--
function SetLights( newAnimState, newSwitchState )

	-- If lights haven't been set before, mark them as initialised now
	if not gInitialised then
		gInitialised = true
	end

	-- Then figure out which light we want to turn on
	local light = nil
	
	-- If signal ahead is blocked
	if newAnimState == ANIMSTATE_RED then
	
		-- Show RED, signal state is BLOCKED
		light = LIGHT_NODE_RED
		gSignalState = BLOCKED
		DebugPrint(("DEBUG: SetLights() - home signal ahead is showing aspect " .. newAnimState .. ", so we're turning " .. newSwitchState .. " head ON"))

	-- If signal ahead is clear
	elseif newAnimState == ANIMSTATE_GREEN then
	
		-- Show GREEN, signal state is CLEAR
		light = LIGHT_NODE_GREEN
		gSignalState = CLEAR
		DebugPrint(("DEBUG: SetLights() - home signal ahead is showing aspect " .. newAnimState .. ", so we're turning " .. newSwitchState .. " head OFF"))

	-- If signal ahead is showing any other aspect
	else
	
		-- Show GREEN, signal state is WARNING
		light = LIGHT_NODE_GREEN
		gSignalState = WARNING
		DebugPrint(("DEBUG: SetLights() - home signal ahead is showing aspect " .. newAnimState .. ", so we're turning " .. newSwitchState .. " head OFF"))
	end

	-- Update state of lights
	gAnimState = newAnimState
	gSwitchState = newSwitchState

	-- Turn all lights off to start with
	SwitchLight( LIGHT_NODE_GREEN,	0,	SIGNAL_HEAD_NAME["AHEAD"]	)
	SwitchLight( LIGHT_NODE_GREEN,	0,	SIGNAL_HEAD_NAME["LEFT"]	)
	SwitchLight( LIGHT_NODE_GREEN,	0,	SIGNAL_HEAD_NAME["RIGHT"]	)
	SwitchLight( LIGHT_NODE_RED,	1,	SIGNAL_HEAD_NAME["AHEAD"]	)
	SwitchLight( LIGHT_NODE_RED,	1,	SIGNAL_HEAD_NAME["LEFT"]	)
	SwitchLight( LIGHT_NODE_RED,	1,	SIGNAL_HEAD_NAME["RIGHT"]	)

	-- Then switch the light we want back on again
	SwitchLight( LIGHT_NODE_RED,	0, SIGNAL_HEAD_NAME[newSwitchState] )
	SwitchLight( light, 1, SIGNAL_HEAD_NAME[newSwitchState] )
end

--------------------------------------------------------------------------------------
-- UPDATE
-- Initialises the signal when the route finishes loading, and handles flashing lights
--
function Update ( time )

	-- If lights haven't been set yet, initialise them now
	if not gInitialised then
		SetLights( ANIMSTATE_GREEN, "AHEAD")
	end

	-- Stop updating
	Call( "EndUpdate" )
end

--------------------------------------------------------------------------------------
-- ON CONSIST PASS
-- Called when a train passes one of the signal's links
--
function OnConsistPass ( prevFrontDist, prevBackDist, frontDist, backDist, linkIndex )

	-- Repeater signal - do nothing!
end

--------------------------------------------------------------------------------------
-- JUNCTION STATE CHANGE
-- Called when a junction is changed. Should only be handled by home signals.
--
function OnJunctionStateChange( junction_state, parameter, direction, linkIndex )

	-- Repeater signal - do nothing!
end

-------------------------------------------------------------------------------------
-- ON SIGNAL MESSAGE
-- Handles messages from other signals. 
--
function OnSignalMessage( message, parameter, direction, linkIndex )

	-- Forward on message
	Call( "SendSignalMessage", message, parameter, -direction, 1, linkIndex )
	
	-- If next signal isn't blocked, show CLEAR
	if ( message == SIGNAL_REPEATER_STATE ) then
	
		DebugPrint( ( "DEBUG: OnSignalMessage() - Signal ahead on link " .. linkIndex .. " has switched from " .. gAnimState .. " to " .. tonumber(parameter)) )
		SetLights(tonumber(parameter), gSwitchState)

	-- If message includes a switch direction parameter, activate appropriate head
	elseif ( parameter == "AHEAD" or parameter == "LEFT" or parameter == "RIGHT" ) then
	
		DebugPrint( ( "DEBUG: OnSignalMessage() - Signal ahead on link " .. linkIndex .. " is now set to go " .. parameter ) )
		SetLights(gAnimState, parameter)
	end
end

