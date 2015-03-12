------------------------------------------------------------------------------
-- Signals\Pro Signals\CommonScripts                                        --
--     C o m m o n   C o l o r   L i g h t   S c r i p t . l u a    --
--                                                                          --
------------------------------------------------------------------------------

-- DEFAULT INITIALISE
--
function DefaultInitialise ( )

	-- If we're a signal head, we don't need to know our own name to switch our lights on and off
	if (SIGNAL_HEAD_NAME == nil) then
		SIGNAL_HEAD_NAME = ""
	end
	
	-- Initialises common signal features
	BaseInitialise()

	-- Initialise UK-specific global variables
	gInitialised			= false								-- has the route finished loading yet?
	gPreparedness			= SIGNAL_UNPREPARED					-- is a train approaching us?
	gSignalType				= Call("GetControlMode")			-- what type of signal are we - controlled or automatic?
	-- KJM 14-Dec-2009 Start auto 
	-- gControlState			= SIGNAL_STATE_INACTIVE				-- what control state are we in?
	gControlState			= SIGNAL_STATE_AUTO					-- what control state are we in?
	gSignalState			= CLEAR								-- overall state of signal, as used by AWS/TPWS
	gBlockState				= SIGNAL_CLEARED					-- underlying block state of this signal (clear, blocked, warning etc)
	gSwitchState			= SIGNAL_STRAIGHT					-- underlying switch state of this signal (straight, diverging etc)
	gAnimState				= -1								-- what's the current state of our lights?
	gRouteState				= { }								-- is there a diverging junction ahead?
	gCallOnState			= false								-- is the "Call-On" light on?
	
	-- new functionality for Rail Sim Professional
	gSwitchDirection		= "AHEAD"							-- whether the switch is set straight ahead, left, or right
	gIndicatorType			= Call("GetJunctionType")			-- what type of route indicator (if any) do we have?
	-- KJM 15-Dec-2009 Gone and replaced by 
	-- gAspectLimitSpeed		= Call("GetAspectLimitingSpeed")	-- if speed limit under connected link <= to this, limit aspect to warning
	INDICATOR_ROOT_NAME		= ""

	-- How long to stay off/on in each flash cycle
	LIGHT_FLASH_OFF_SECS	= 0.5
	LIGHT_FLASH_ON_SECS		= 0.5

	-- State of flashing light
	gTimeSinceLastFlash		= 0
	gLightFlashOn			= false
	gFirstLightFlash		= true

	
	-- Automatic signals should always be in automatic mode
	if gSignalType == SIGNAL_TYPE_AUTO then
		gControlState = SIGNAL_STATE_AUTO
		gPreparedness = SIGNAL_PREPARED
	end
	
	-- Initialise gRouteState
	for i = 0, gLinkCount - 1 do
		gRouteState[i] = SIGNAL_STRAIGHT
	end

	-- Select appropriate route indicator node name format, depending on route indicator type
	if gIndicatorType == ROUTE_INDICATOR_FEATHERS then
		INDICATOR_ROOT_NAME = FEATHER_ROOT_NAME
		
	elseif gIndicatorType == ROUTE_INDICATOR_THEATRE then
		INDICATOR_ROOT_NAME = THEATRE_ROOT_NAME
	end

	-- Tells the game to do an update tick once the route finishes loading
	-- This will initialise the lights on the signals, which can't be changed until the route is loaded
	Call( "BeginUpdate" )
end


--------------------------------------------------------------------------------------
-- SWITCH LIGHT
-- Turns the selected light node on (1) / off (0)
function SwitchLight( lightNode, state, head )

	-- If no head is specified, assume that signal only has one
	if head == nil then
		head = SIGNAL_HEAD_NAME
	end

	-- If this light node exists for this signal
	if lightNode ~= nil and head ~= nil then
		Call ( head .. "ActivateNode", lightNode, state )
	end
end


--------------------------------------------------------------------------------------
-- DEFAULT SET LIGHTS
-- Called by SetState to switch the appropriate lights for this signal type on/off according to its new state

function DefaultSetLights ( newState )

	-- Update light state
	gAnimState = newState
	
	-- Switch the appropriate lights on and off based on our new state
	
	if (newState == ANIMSTATE_GREEN) then
		SwitchLight( LIGHT_NODE_GREEN,		1 )
		SwitchLight( LIGHT_NODE_YELLOW,		0 )
		SwitchLight( LIGHT_NODE_YELLOW2,	0 )
		SwitchLight( LIGHT_NODE_RED,		0 )

	elseif (newState == ANIMSTATE_DOUBLE_YELLOW) then
		SwitchLight( LIGHT_NODE_GREEN,		0 )
		SwitchLight( LIGHT_NODE_YELLOW,		1 )
		SwitchLight( LIGHT_NODE_YELLOW2,	1 )
		SwitchLight( LIGHT_NODE_RED, 		0 )

	elseif (newState == ANIMSTATE_YELLOW) then
		SwitchLight( LIGHT_NODE_GREEN,		0 )
		SwitchLight( LIGHT_NODE_YELLOW,		1 )
		SwitchLight( LIGHT_NODE_YELLOW2,	0 )
		SwitchLight( LIGHT_NODE_RED, 		0 )

	elseif (newState == ANIMSTATE_RED) then
		SwitchLight( LIGHT_NODE_GREEN,		0 )
		SwitchLight( LIGHT_NODE_YELLOW,		0 )
		SwitchLight( LIGHT_NODE_YELLOW2,	0 )
		SwitchLight( LIGHT_NODE_RED, 		1 )
		
	elseif (newState >= ANIMSTATE_FLASHING_YELLOW) then
		-- Lights are flashing, turn them all off and then start update loop
		SwitchLight( LIGHT_NODE_GREEN,		0 )
		SwitchLight( LIGHT_NODE_YELLOW,		0 )
		SwitchLight( LIGHT_NODE_YELLOW2,	0 )
		SwitchLight( LIGHT_NODE_RED, 		0 )
		Call( "BeginUpdate" )
	else
		Print( ("ERROR: SetLights trying to switch to invalid state " .. newState ) )
	end
end


--------------------------------------------------------------------------------------
-- DEFAULT ACTIVATE ROUTE INDICATOR
-- Switches route indicators on and off depending on connected link
--
function DefaultActivateRouteIndicator ( connectedLink )
	
	local newIndicator = 0
	local newIndicatorStr = ""

	-- If we're connected to a valid link and the signal isn't red
	if connectedLink > 0 then

		-- Check what indicator (if any) is used by that route
		newIndicator = Call("GetLinkFeatherChar", connectedLink)

		-- If route has a valid indicator, turn its ID into a string
		if newIndicator ~= 0 then
			newIndicatorStr = string.char(newIndicator)
		else
			newIndicatorStr = ""
		end
	end
	
	-- If we were connected to a different link before
	if gCurrentIndicator ~= newIndicatorStr then
		-- If we're a feathered signal...
		if gIndicatorType == ROUTE_INDICATOR_FEATHERS then

			-- If a feather is currently switched on, switch it off
			if gCurrentIndicator ~= "" then
				Call( "Route Indicator:ActivateNode", INDICATOR_ROOT_NAME .. gCurrentIndicator, 0 )
			end
			
			-- If the newly connected route has a feather, switch it on
			if newIndicatorStr ~= "" then
				Call( "Route Indicator:ActivateNode", INDICATOR_ROOT_NAME .. newIndicatorStr, 1 )
			end
			
		-- If we use a theatre indicator
		elseif gIndicatorType == ROUTE_INDICATOR_THEATRE then
		
			-- Switch new texture on - this should get rid of the old texture too
			-- KJM 28-Aug-2008 Use new theatre function 
			-- Call( "ActivateNode", INDICATOR_ROOT_NAME .. newIndicator, 1 )
			Call( "Theatre Indicator:SetText", newIndicatorStr, PRIMARY_TEXT )

		end
		
		DebugPrint(("DEBUG: DefaultActivateRouteIndicator() - route indicator switching from " .. INDICATOR_ROOT_NAME .. gCurrentIndicator .. " to " .. INDICATOR_ROOT_NAME .. newIndicator))
	end
	
	-- Remember which indicator we just switched on
	gCurrentIndicator = newIndicatorStr
end


--------------------------------------------------------------------------------------
-- DEFAULT DETERMINE SIGNAL STATE
-- Figures out what lights to show and messages to send based on the state of the signal
--
function DefaultDetermineSignalState()

	-- KJM 16-Nov-2009 Doesn't seem right to process if uninitialised
	if not gInitialised then
		return
	end

	local newBlockState = gBlockState
	local newSwitchDirection = "AHEAD"
	local newSwitchState = gSwitchState
	
	-- Default call-on to false, unless we find otherwise
	gCallOnState = false


	-- If line is blocked
	if gConnectedLink == -1 or gOccupationTable[0] > 0 or gOccupationTable[gConnectedLink] > 0 then
	
		-- New block state is BLOCKED, don't need to know anything else - signal is red
		newBlockState = SIGNAL_BLOCKED
		
	-- Otherwise
	else
		-- Update block and switch state according to state of connected link
		newBlockState = gLinkState[gConnectedLink]
		newSwitchState = gRouteState[gConnectedLink]

		-- If we're covering a junction, check approach control type for connected link
		if gConnectedLink > 0 then
			
			local approachControlType = Call("GetLinkApproachControl", gConnectedLink)

			-- Approach Control with Flashing Yellows used by this link
			if approachControlType == 1 then
				newSwitchState = SIGNAL_DIVERGING_FLASHING

			-- Approach Control from Red used by this link
			elseif approachControlType == 2 then
				newSwitchState = SIGNAL_DIVERGING_RED
				
			-- If no Approach Control for this link, switch state depends on next signal up the line
			end
		end
	end

	-- Next figure out what aspect to show based on new state
	local newAnimState = gAnimState


	-- If signal is a control signal and it's currently inactive
	if gControlState == SIGNAL_STATE_INACTIVE then
	
		newBlockState = SIGNAL_BLOCKED	-- treat signal as blocked
		newAnimState = ANIMSTATE_RED
		gSignalState = BLOCKED

	-- If signal is a control signal and it's currently in "Call-On" mode
	elseif gControlState == SIGNAL_STATE_CALL_ON then
	
		newBlockState = SIGNAL_BLOCKED	-- treat signal as blocked
		newAnimState = ANIMSTATE_RED
		gSignalState = WARNING			-- TPWS inactive but AWS gives warning
		gCallOnState = true

	-- If line is blocked
	elseif newBlockState == SIGNAL_BLOCKED or gPreparedness == SIGNAL_UNPREPARED then

		newAnimState = ANIMSTATE_RED
		gSignalState = BLOCKED

	-- If we're connected to a link that uses Approach Control from Red
	-- and there isn't a train approaching within sight of us yet
	elseif newSwitchState == SIGNAL_DIVERGING_RED
		and gPreparedness ~= SIGNAL_PREPARED_VISIBLE then

		newAnimState = ANIMSTATE_RED
		gSignalState = BLOCKED

	-- In any other case, 2 Aspect signals show green
	elseif gAspect == 2 then

		newAnimState = ANIMSTATE_GREEN
		gSignalState = CLEAR

	-- If the connected link is aspect limited, show yellow
	-- KJM 15-Dec-2009 Use new call
	--elseif gAspectLimitSpeed > 0
	--	and Call ( "GetTrackSpeedLimit", gConnectedLink ) < gAspectLimitSpeed then
	elseif Call ( "GetLinkLimitedToYellow", gConnectedLink ) ~= 0 then
	
		newBlockState = SIGNAL_WARNING	-- treat signal as at warning
		newAnimState = ANIMSTATE_YELLOW
		gSignalState = WARNING

	-- If line ahead is at warning,
	-- or if next signal is set to a link that uses approach control from red,
	-- or if we're set to a link that uses approach control with flashing yellows...
	-- or if we're set to a link that is aspect limited
	elseif newBlockState == SIGNAL_WARNING
		or newSwitchState == SIGNAL_DIVERGING_YELLOW
		or newSwitchState == SIGNAL_DIVERGING_FLASHING then

		newAnimState = ANIMSTATE_YELLOW
		gSignalState = WARNING

	-- If next signal  is set to a link that uses approach control with flashing yellows...
	elseif newSwitchState == SIGNAL_DIVERGING_FLASHING_YELLOW then

		newAnimState = ANIMSTATE_FLASHING_YELLOW
		gSignalState = WARNING

	-- In any other case, 3 Aspect signals show green
	elseif gAspect == 3 then

		newAnimState = ANIMSTATE_GREEN
		gSignalState = CLEAR

	-- If line ahead is at warning2
	-- or if next but one signal is set to a link that uses approach control from red
	elseif newBlockState == SIGNAL_WARNING2
		or newSwitchState == SIGNAL_DIVERGING_DOUBLE_YELLOW then

		newAnimState = ANIMSTATE_DOUBLE_YELLOW
		gSignalState = WARNING

	-- If next but one signal is set to a link that uses approach control with flashing yellows
	elseif newSwitchState == SIGNAL_DIVERGING_FLASHING_DOUBLE_YELLOW then

		newAnimState = ANIMSTATE_FLASHING_DOUBLE_YELLOW
		gSignalState = WARNING

	-- If line ahead is clear
	elseif newBlockState == SIGNAL_CLEARED then
	
		newAnimState = ANIMSTATE_GREEN
		gSignalState = CLEAR
		
	else
		Print( ("ERROR - couldn't figure out what state " .. gAspect .. " aspect signal should be in with block state " .. newBlockState .. ", switch state " .. newSwitchState .. ", control state " .. gControlState .. ", call on state " .. gCallOnState .. " and preparedness " .. gPreparedness) )
	end

	
	-- If we've got route indicators...
	if gIndicatorType ~= ROUTE_INDICATOR_NONE then

		-- If lights are red, turn all route indicators off
		if newAnimState == ANIMSTATE_RED then
			ActivateRouteIndicator(0)

		-- Otherwise, activate the appropriate route indicator for the connected link
		else
			ActivateRouteIndicator(gConnectedLink)
		end

		-- If we've got feathers and one of them has just been activated, check if we're diverging left or right
		-- because there may be a repeater indicator signal behind us that needs to know which way we're going
		if gIndicatorType == ROUTE_INDICATOR_FEATHERS and gCurrentIndicator ~= "" then
			
			-- If no feather is active, treat as straight ahead
			-- KJM 03-Sep-2008 gCurrentIndicator could be alpha for mini theatres.  
			-- Mutihead repeaters wont be used with ground mini theatres so treast asd ahread
			if ( not tonumber(gCurrentIndicator) ) or tonumber(gCurrentIndicator) == 0 then
				-- Do nothing
				DebugPrint ("DEBUG: DefaultDetermineSignalState() - no feather active, treat as ahead")
				
			-- If feather 1, 2 or 3 is active, we're going left
			elseif tonumber(gCurrentIndicator) < 4 then
				DebugPrint ("DEBUG: DefaultDetermineSignalState() - feather 1-3 is active, diverging left")
				newSwitchDirection = "LEFT"
				
			-- Otherwise feather 4, 5 or 6 must be active, and we're going right
			else
				DebugPrint ("DEBUG: DefaultDetermineSignalState() - feather 4-6 is active, diverging right")
				newSwitchDirection = "RIGHT"
			end
		end
	end
	
	
	-- If we've got a "Call-On" light, switch it on or off as appropriate
	if gSignalType == SIGNAL_TYPE_CONTROL_CALL_ON then
		if gCallOnState then	SwitchLight(LIGHT_NODE_CALL_ON, 1, "Callon Indicator:")
		else					SwitchLight(LIGHT_NODE_CALL_ON, 0, "Callon Indicator:")
		end
	end
	
	
	-- If signal aspect has changed
	if newAnimState ~= gAnimState then
	
		-- Change lights, update 2D map and let any repeaters behind us know our new aspect
		DebugPrint( ("DEBUG: DefaultDetermineSignalState() - lights changing from " .. gAnimState .. " to " .. newAnimState) )
		SetLights(newAnimState)
		Call( "Set2DMapProSignalState", newAnimState )
		Call( "SendSignalMessage", SIGNAL_REPEATER_STATE, "" .. newAnimState, -1, 1, 0 )
	end

	-- If block state has changed
	if newBlockState ~= gBlockState then
		DebugPrint( ("DEBUG: DefaultDetermineSignalState() - block state changed from " .. gBlockState .. " to " .. newBlockState .. " - sending message" ) )
		gBlockState = newBlockState
		Call( "SendSignalMessage", newBlockState, "", -1, 1, 0 )
	end

	-- If switch state or direction has changed
	if newSwitchState ~= gSwitchState or newSwitchDirection ~= gSwitchDirection then
		DebugPrint( ("DEBUG: DefaultDetermineSignalState() - switch state changed from " .. gSwitchState .. ", direction " .. gSwitchDirection .. " to " .. newSwitchState .. ", direction " .. newSwitchDirection .. " - sending message" ) )
		gSwitchState = newSwitchState
		gSwitchDirection = newSwitchDirection
		Call( "SendSignalMessage", newSwitchState, newSwitchDirection, -1, 1, 0 )
	end
end

--------------------------------------------------------------------------------------
-- DEFAULT UPDATE
-- Initialises the signal when the route finishes loading, and handles flashing lights
--
function DefaultUpdate( time )

	-- If this is the initialisation pass for the signal...
	if not gInitialised then
	
		-- Remember that we've been initialised
		gInitialised = true
	
		-- If we're a feathered signal...
		if gIndicatorType == ROUTE_INDICATOR_FEATHERS then
		
			local indicator
			
			-- Cycle through all possible feathers and switch them off
			for i = 1, gLinkCount - 1 do

				indicator = Call("GetLinkFeatherChar", i)
				
				-- If there's a valid indicator for this link, turn its ID into a string
				if indicator ~= 0 then
					indicator = string.char(indicator)
					DebugPrint(("Link " .. i .. " uses feather " .. indicator .. " - switching off now"))
					Call( "Route Indicator:ActivateNode", INDICATOR_ROOT_NAME .. indicator, 0 )
				else
					DebugPrint(("Link " .. i .. " uses no feather"))
				end
			end
			
		-- If we've got a theatre indicator
		elseif gIndicatorType == ROUTE_INDICATOR_THEATRE then
		
			-- Turn off the textures - this should turn off everything and leave the indicator blank
			-- KJM 28-Aug-2008 Use new theatre function 
			-- Call( "ActivateNode", INDICATOR_ROOT_NAME .. "A", 0 )
			Call( "Theatre Indicator:SetText", "", PRIMARY_TEXT )
		end

		-- If we're a junction signal, check which link is connected now
		if gLinkCount > 1 then
			OnJunctionStateChange( 0, "", 1, 0 )
		
		-- Otherwise, check signal state now
		else
		
			DetermineSignalState()
			
			if gPreparedness ~= SIGNAL_UNPREPARED then
			
				-- If we're a pure Distant signal...
				if ( SIGNAL_HEAD_NAME == nil ) then

					-- Forward on our own preparedness
					Call( "SendSignalMessage", SIGNAL_PREPARED, "" .. gPreparedness, 1, 1, 0 )

				-- If we have a Main head and there are no trains ahead of us
				elseif gOccupationTable[0] == 0 then
					
					-- If we're a yard exit (always prepared)
					if gPreparedness == SIGNAL_PREPARED_ALWAYS then

						-- Act as if we had a train approaching us (because we might do!)
						Call( "SendSignalMessage", SIGNAL_PREPARED, "2", 1, 1, 0 )
					
					-- If we're a normal signal
					else

						-- Increment the preparedness by one and send it on
						Call( "SendSignalMessage", SIGNAL_PREPARED, "" .. (gPreparedness + 1), 1, 1, 0 )
					end
				end
			end
		end
	end

	-- Keep count of any flashing lights, in case they've all stopped flashing
	local newLightState = -1

	-- the first time that this is called, the time since the last update will be large - therefore we should ignore the first update
	if gFirstLightFlash then
	
		-- Reset flash state
		gTimeSinceLastFlash = 0
		gFirstLightFlash = false
		gLightFlashOn = false
		
	-- Otherwise increment the timer
	else	
		gTimeSinceLastFlash = gTimeSinceLastFlash + time
		
		-- If we're on and we've been on long enough, switch off
		if gLightFlashOn and gTimeSinceLastFlash >= LIGHT_FLASH_ON_SECS then
			newLightState = 0
			gLightFlashOn = false
			gTimeSinceLastFlash = 0
			
		elseif (not gLightFlashOn) and gTimeSinceLastFlash >= LIGHT_FLASH_OFF_SECS then
			newLightState = 1
			gLightFlashOn = true
			gTimeSinceLastFlash = 0
		end
	end	

	-- If the signal is flashing
	if gAnimState >= ANIMSTATE_FLASHING_YELLOW then

		-- Are we turning the lights on / off?
		if newLightState >= 0 then

			-- If so, switch on / off the appropriate light(s)
			if gAnimState == ANIMSTATE_FLASHING_YELLOW then
				SwitchLight( LIGHT_NODE_YELLOW, newLightState )
				
			elseif gAnimState == ANIMSTATE_FLASHING_DOUBLE_YELLOW then
				SwitchLight( LIGHT_NODE_YELLOW, newLightState )
				SwitchLight( LIGHT_NODE_YELLOW2, newLightState )
			end
		end
		
	-- If the signal isn't flashing anymore, stop updates and remember to reset everything if we start flashing again later
	else
		Call( "EndUpdate" )
		gFirstLightFlash = true
	end
end

--------------------------------------------------------------------------------------
-- DEFAULT ON CONSIST PASS
-- Called when a train passes one of the signal's links
--
function DefaultOnConsistPass ( prevFrontDist, prevBackDist, frontDist, backDist, linkIndex )

	-- Use BaseOnConsistPass
	BaseOnConsistPass ( prevFrontDist, prevBackDist, frontDist, backDist, linkIndex )
end

--------------------------------------------------------------------------------------
-- JUNCTION STATE CHANGE
-- Called when a signal receives a message saying that a junction ahead of it has switched
--
function DefaultOnJunctionStateChange( junction_state, parameter, direction, linkIndex )

	-- Use BaseOnJunctionStateChange
	BaseOnJunctionStateChange( junction_state, parameter, direction, linkIndex )
end

-------------------------------------------------------------------------------------
-- DEFAULT ON CONTROL MODE CHANGE
-- Called by code when the operator changes the control mode of a signal
--
function DefaultOnControlModeChange( control_state )

	-- Use BaseOnControlModeChange
	BaseOnControlModeChange( control_state )
end

-------------------------------------------------------------------------------------
-- DEFAULT REACT TO SIGNAL MESSAGE
-- Subfunction to save duplicate code when handling pass back messages - just takes all the old scripting out of the OnSignalMessage function
--
function DefaultReactToSignalMessage( message, parameter, direction, linkIndex )

	-- CHECK FOR YARD ENTRY - any messages arriving on a yard entry link should be ignored
	if gYardEntry[linkIndex] then
		-- Do nothing

		
	
	-- SIGNAL STATES

	elseif ( message == SIGNAL_CLEARED or message == SIGNAL_WARNING2 ) then
		-- Next signal's state is Clear or Warning2, so this link is Clear
		DebugPrint( ( "DEBUG: Link " .. linkIndex .. " is now Cleared" ) )
		gLinkState[linkIndex] = SIGNAL_CLEARED

		-- If the message arrived on the connected link...
		if linkIndex == gConnectedLink then
			DetermineSignalState()
		end

	elseif ( message == SIGNAL_WARNING ) then
		-- Next signal's state is Warning, so this link is at Warning2
		DebugPrint( ( "DEBUG: Link " .. linkIndex .. " is now Warning2" ) )
		gLinkState[linkIndex] = SIGNAL_WARNING2

		-- If the message arrived on the connected link...
		if linkIndex == gConnectedLink then
			DetermineSignalState()
		end

	elseif ( message == SIGNAL_BLOCKED ) then
		-- Next signal's state is Blocked, so this link is at Warning
		DebugPrint( ( "DEBUG: Link " .. linkIndex .. " is now Warning" ) )
		gLinkState[linkIndex] = SIGNAL_WARNING

		-- If the message arrived on the connected link...
		if linkIndex == gConnectedLink then
			DetermineSignalState()
		end



	-- ROUTE STATES

	-- No diverging approach control signal for at least two blocks ahead of us
	elseif message == SIGNAL_STRAIGHT
		or message == SIGNAL_DIVERGING_DOUBLE_YELLOW
		or message == SIGNAL_DIVERGING_FLASHING_DOUBLE_YELLOW then
		
		-- If route state has changed for this link...
		if gRouteState[linkIndex] ~= SIGNAL_STRAIGHT then
			gRouteState[linkIndex] = SIGNAL_STRAIGHT

			-- If the message arrived on the connected link...
			if linkIndex == gConnectedLink then
				DetermineSignalState()
			end
		end

	-- Next but one signal is diverging and using Approach Control from red
	elseif message == SIGNAL_DIVERGING_YELLOW and gAspect == 4 then
		
		-- If route state has changed for this link...
		if gRouteState[linkIndex] ~= SIGNAL_DIVERGING_DOUBLE_YELLOW then
			gRouteState[linkIndex] = SIGNAL_DIVERGING_DOUBLE_YELLOW

			-- If the message arrived on the connected link...
			if linkIndex == gConnectedLink then
				DetermineSignalState()
			end
		end

	-- Next but one signal is diverging and using Approach Control with flashing yellows
	elseif message == SIGNAL_DIVERGING_FLASHING_YELLOW and gAspect == 4 then

		-- If route state has changed for this link...
		if gRouteState[linkIndex] ~= SIGNAL_DIVERGING_FLASHING_DOUBLE_YELLOW then
			gRouteState[linkIndex] = SIGNAL_DIVERGING_FLASHING_DOUBLE_YELLOW

			-- If the message arrived on the connected link...
			if linkIndex == gConnectedLink then
				DetermineSignalState()
			end
		end

	-- Next signal is diverging and using Approach Control from red
	elseif message == SIGNAL_DIVERGING_RED then

		-- If route state has changed for this link...
		if gRouteState[linkIndex] ~= SIGNAL_DIVERGING_YELLOW then
			gRouteState[linkIndex] = SIGNAL_DIVERGING_YELLOW

			-- If the message arrived on the connected link...
			if linkIndex == gConnectedLink then
				DetermineSignalState()
			end
		end

	-- Next signal is diverging and using Approach Control with flashing yellows
	elseif message == SIGNAL_DIVERGING_FLASHING then

		-- If route state has changed for this link...
		if gRouteState[linkIndex] ~= SIGNAL_DIVERGING_FLASHING_YELLOW then
			gRouteState[linkIndex] = SIGNAL_DIVERGING_FLASHING_YELLOW

			-- If the message arrived on the connected link...
			if linkIndex == gConnectedLink then
				DetermineSignalState()
			end
		end



	-- OCCUPANCY

	elseif (message == OCCUPATION_DECREMENT) then
		-- update the occupation table for this signal given the information that a train has just left this block and entered the next block
		if gOccupationTable[linkIndex] > 0 then
			gOccupationTable[linkIndex] = gOccupationTable[linkIndex] - 1
			DebugPrint( ("DEBUG: DefaultReactToSignalMessage: OCCUPATION_DECREMENT received... gOccupationTable[" .. linkIndex .. "]: " .. gOccupationTable[linkIndex]) )
		else
			Print( ("ERROR: DefaultReactToSignalMessage: OCCUPATION_DECREMENT received... gOccupationTable[" .. linkIndex .. "] was already 0!") )
		end

		-- If this isn't the connected link...
		if linkIndex ~= gConnectedLink then
		
			-- Do nothing
			
		-- If that part of the block is still occupied
		elseif gOccupationTable[linkIndex] > 0 then
		
			-- Signal ahead of us still has a train approaching it nearby
			-- KJM Not _VISIBLE
			--Call( "SendSignalMessage", SIGNAL_PREPARED_VISIBLE, "", 1, 1, gConnectedLink )
			Call( "SendSignalMessage", SIGNAL_PREPARED, "1", 1, 1, gConnectedLink )
			
		-- If our block is still occupied before the junction
		elseif gOccupationTable[0] > 0 then
		
			-- Signal ahead of us still has a train approaching it
			Call( "SendSignalMessage", SIGNAL_PREPARED, "1", 1, 1, gConnectedLink )
		
		-- If we're a yard exit
		elseif gSignalType == SIGNAL_TYPE_AUTO then
		
			-- Let the signal ahead of us on that link know it might still have a train approaching it
			Call( "SendSignalMessage", SIGNAL_PREPARED, "2", 1, 1, 0 )

			-- KJM 12-Jan-2010
			-- Signal state WILL change - this was missing
			DetermineSignalState()

			
		-- If there's another train approaching us, and it's less than 3 signals behind us
		elseif gPreparedness < 3 then
		
			-- Let the signal ahead of us on that link know it still has a train approaching it
			Call( "SendSignalMessage", SIGNAL_PREPARED, "" .. (gPreparedness + 1), 1, 1, 0 )
		
			-- KJM 17-Nov-2009
			-- Signal state *could* change now because I'm now unblocked and prepared.
			DetermineSignalState()
		-- Otherwise...
		else
			-- Signal state should change now
			DetermineSignalState()
		
			-- Pass a SIGNAL_UNPREPARED message up the track to clear any Vr signals between us and the next Hp signal
			Call( "SendSignalMessage", SIGNAL_UNPREPARED, "", 1, 1, 0 )
		end
		
	elseif (message == OCCUPATION_INCREMENT) then
		-- update the occupation table for this signal given the information that a train has just entered this block
		gOccupationTable[linkIndex] = gOccupationTable[linkIndex] + 1
		DebugPrint( ("DEBUG: DefaultReactToSignalMessage: OCCUPATION_INCREMENT received... gOccupationTable[" .. linkIndex .. "]: " .. gOccupationTable[linkIndex]) )

		-- If this is the connected link, check the signal state
		if linkIndex == gConnectedLink then
			DetermineSignalState()
			-- KJM From germany
			-- Pass a SIGNAL_PREPARED message up the track to activate any Vr signals between us and the next Hp signal
			Call( "SendSignalMessage", SIGNAL_PREPARED, "1", 1, 1, 0 )
		end

	-- ++++ KJM 
		
	elseif message == SIGNAL_PREPARED then

		-- These messages are sent forwards, so only pay attention to them if they're reaching link 0
			-- (If they hit any other links on the way up first, they'll be forwarded as PASS messages)
		-- Ignore the message if we're a yard exit, as they should always be prepared
		if linkIndex == 0 then
		
			DebugPrint ( ("DEBUG: DefaultReactToSignalMessage: SIGNAL_PREPARED " .. parameter .. " received" ) )
			local newPreparedness = gPreparedness

			-- Train is directly behind us
			if parameter == "1" then
			
				newPreparedness = 1

			-- Train is approaching the signal behind us
			elseif parameter == "2" then
			
				newPreparedness = 2

			-- Train is approaching the signal two behind us
			elseif parameter == "3" then
			
				newPreparedness = 3
			end
			
			-- If preparedness has changed or we're going to blindlky forward it cos we're auto
			if newPreparedness ~= gPreparedness or gSignalType == SIGNAL_TYPE_AUTO then

				-- only save prep if not auto
				if  gSignalType ~= SIGNAL_TYPE_AUTO then
					gPreparedness = newPreparedness
					-- Check our state
					DetermineSignalState()
				end

				-- If  there's no train in our block (so the next signal isn't already "more" prepared)...
				if ( gOccupationTable[0] == 0 and (gConnectedLink < 1 or gOccupationTable[gConnectedLink] == 0) ) then
				
					-- We only want to prepare the first 3 signals ahead of the train, so...
					-- If the parameter is less than 3, increment the parameter and pass the message on
					if newPreparedness < 3 then

						-- Increment the parameter and pass the message on
						Call( "SendSignalMessage", SIGNAL_PREPARED, "" .. (newPreparedness + 1), -direction, 1, 0 )
						
					else
				
						-- Send SIGNAL_UNPREPARED - train is too far away for next signal to prepare for it
						Call( "SendSignalMessage", SIGNAL_UNPREPARED, "", -direction, 1, 0 )
					end
				end
			end
		end
		
	elseif message == SIGNAL_UNPREPARED then

		if linkIndex == 0 and gSignalType ~= SIGNAL_TYPE_AUTO and gPreparedness ~= message then

			DebugPrint ( ("DEBUG: DefaultReactToSignalMessage: SIGNAL_UNPREPARED received" ) )

			-- We no longer have a train approaching us
			gPreparedness = message
	
			-- Check our state
			DetermineSignalState()

			-- If there's no train in our block...
			if ( gOccupationTable[0] == 0 and (gConnectedLink < 1 or gOccupationTable[gConnectedLink] == 0) ) then

				-- Pass the message on unchanged
				Call( "SendSignalMessage", SIGNAL_UNPREPARED, parameter, -direction, 1, 0 )
			end
		
		end

	elseif message == INITIALISE_TO_PREPARED then

		-- Received if there's a train on the line behind us when the route first loads
		-- This message is sent forwards, so only pay attention if they're reaching link 0 from behind
		-- Ignore the message if we're a yard exit, as they should always be prepared
		if linkIndex == 0 then
			DebugPrint ( ("DEBUG: DefaultReactToSignalMessage: INITIALISE_TO_PREPARED received" ) )
			if gSignalType ~= SIGNAL_TYPE_AUTO then
				-- Update preparedness
				gPreparedness = 1
			end
			-- Increment the parameter and pass the message on
			Call( "SendSignalMessage", SIGNAL_PREPARED, "2", -direction, 1, 0 )
			

		end	

	-- ---- KJM 
		


--	-- PREPARE FOR APPROACHING TRAIN
--		-- These messages are sent forwards, so only pay attention to them if they're reaching link 0 from behind
--		-- If they hit any other links on the way up first, they'll be forwarded as PASS messages
--		-- Only control signals need to pay attention to them - auto signals should ignore them
--	elseif (message == SIGNAL_UNPREPARED
--		or	message == SIGNAL_PREPARED
--		or	message == SIGNAL_PREPARED_VISIBLE)
--		and gSignalType ~= SIGNAL_TYPE_AUTO
--		and linkIndex == 0 then
--
--		if gPreparedness ~= message then
--			gPreparedness = message
--			DetermineSignalState()
--		end
		
--		-- If the message had the "PrepCheck" parameter, the signal that was behind us is no longer connected
--		-- It's assumed we no longer have a train approaching us, but we should check to be safe
--		if parameter == "PrepCheck" then
--
--			-- Send back a query message to check if there's another signal connected behind us now
--			-- NOTE: Need to do this last, or the reply to this message arrives before we finish processing the previous one
--			Call( "SendSignalMessage", SIGNAL_QUERY_PREPAREDNESS, "", -1, 1, 0 )
--		end

--	-- QUERY PREPAREDNESS
--	-- The signal ahead of us thinks it no longer has a train approaching it - is it right?
--	elseif (message == SIGNAL_QUERY_PREPAREDNESS
--		and linkIndex == gConnectedLink) then
--		
--		DebugPrint( ("DEBUG: DefaultReactToSignalMessage: SIGNAL_QUERY_PREPAREDNESS received") )
--
--		-- If there's a train beyond our connected link...
--		if gOccupationTable[linkIndex] > 0 then
--
--			-- Send a PREPARED_VISIBLE message forwards
--			Call( "SendSignalMessage", SIGNAL_PREPARED_VISIBLE, "0", 1, 1, gConnectedLink )
--			
--		-- If there's a train before the connected link
--		elseif gOccupationTable[0] then
--
--			-- Send a PREPARED message forwards
--			Call( "SendSignalMessage", SIGNAL_PREPARED, "0", 1, 1, gConnectedLink )
--		end	


	-- INITIALISATION MESSAGES

	-- There's a train on the line ahead of us when the route first loads
	elseif (message == INITIALISE_SIGNAL_TO_BLOCKED) then
	
		gOccupationTable[linkIndex] = gOccupationTable[linkIndex] + 1
		DebugPrint( ("DEBUG: DefaultReactToSignalMessage: INITIALISE_SIGNAL_TO_BLOCKED received... gOccupationTable[" .. linkIndex .. "]: " .. gOccupationTable[linkIndex]) )

		-- Only need to do this for single link signals - anything spanning a junction will initialise later when junctions are set
		if (gLinkCount == 1 and gOccupationTable[linkIndex] == 1) then
			DetermineSignalState()
		end

	-- There's a train on the line behind us when the route first loads
		-- This message is sent forwards, so only pay attention if they're reaching link 0 from behind
		-- Only control signals need to pay attention to this message - auto signals should ignore them
		-- NOTE: This message is required to handle signals that don't have another signal behind them
--	elseif (message == INITIALISE_TO_PREPARED
--		and gSignalType ~= SIGNAL_TYPE_AUTO
--		and linkIndex == 0) then
--		
--		DebugPrint( ("DEBUG: DefaultReactToSignalMessage: INITIALISE_TO_PREPARED received on linkIndex 0") )
--
--		-- If we don't already know we have a train approaching, set our state to PREPARED_VISIBLE
--			-- on the assumption there's nothing else behind us to let us know when the train is close
--		if gPreparedness == SIGNAL_UNPREPARED then
--			gPreparedness = SIGNAL_PREPARED_VISIBLE
--		end
		
	-- JB 04/05/07 - New junction state change message added
	elseif (message == JUNCTION_STATE_CHANGE) then
		-- Only act on message if it arrived at link 0, junction_state parameter is "0", and this signal spans a junction (ie, has more than one link)
		if gInitialised and linkIndex == 0 and parameter == "0" and gLinkCount > 1 then
			OnJunctionStateChange( 0, "", 1, 0 )
			
			-- Pass on message in case junction is protected by more than one signal
				-- NB: this message is passed on when received on link 0 instead of link 1+
				-- When it reaches a link > 0 or a signal with only one link, it will be consumed
			Call( "SendSignalMessage", message, parameter, -direction, 1, linkIndex )
		end
		
	-- This message is to reset the signals after a scenario / route is reset
	elseif (message == RESET_SIGNAL_STATE) then
		ResetSignalState()	

	-- KJM 22-Mar-2010 Add Call on functionality on TAB key
	elseif (message == REQUEST_TO_SPAD) then

		DebugPrint( ("DEBUG: " .. gId .. " DefaultReactToSignalMessage: REQUEST_TO_SPAD" ) )
		gControlState = SIGNAL_STATE_CALL_ON
		DetermineSignalState()

	end
end

-------------------------------------------------------------------------------------
-- DEFAULT ON SIGNAL MESSAGE
-- Handles messages from other signals. 
--
function DefaultOnSignalMessage( message, parameter, direction, linkIndex )
	
	-- Use the base function for this
	BaseOnSignalMessage( message, parameter, direction, linkIndex )
end


--------------------------------------------------------------------------------------
--  GET SIGNAL STATE
-- Gets the current state of the signal - blocked, warning or clear. 
-- The state info is used for AWS/TPWS scripting.
--
function GetSignalState( )
	return gSignalState
end

