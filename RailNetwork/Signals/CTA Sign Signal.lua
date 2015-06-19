--include=..\..\Common\Scripts\CTA Util.lua

MSG_CUSTOM = 15
MSG_SIGN_CHANGE = 43

SIGNAL_STATE_SIGNCHANGE = 22

function Initialise()
	Call("BeginUpdate")
end

function Update(interval)
	Call("*:Set2DMapProSignalState", SIGNAL_STATE_SIGNCHANGE)
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
			debugPrint("Sending sign change.")
			Call("SendConsistMessage", MSG_CUSTOM, tostring(MSG_SIGN_CHANGE) .. "=0")
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