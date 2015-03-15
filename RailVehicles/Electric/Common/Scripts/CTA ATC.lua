local ATC_TARGET_DECELERATION = 1.0 -- meters/second/second
local ATC_REACTION_TIME = 2.5 -- seconds
local MPS_TO_MPH = 2.23694 -- Meters/Second to Miles/Hour
local MPH_TO_MPS = 1.0 / MPS_TO_MPH
local MPH_TO_MiPS = 0.000277777778 -- Miles/Hour to Miles/Second
local MI_TO_M = 1609.34 -- Miles to Meters
local M_TO_MI = 1.0 / MI_TO_M -- Meters to Miles
local ATC_WARN_OFF = 0.0
local ATC_WARN_CONSTANT = 1.0
local ATC_WARN_INTERMITTENT = 2.0

local atcSigDirection = 0.0
local gLastSigDist = 0.0
local gLastSigDistTime = 0.0
local gBrakeApplication = false
local gBrakeTime = 0.0
local gAlertAcknowledged = true

function getBrakingDistance(vF, vI, a)
	return ((vF * vF) - (vI * vI)) / (2 * a)
end

function getStoppingSpeed(vI, a, d)
	return math.sqrt(math.max((vI * vI) + (2 * a * d), 0.0))
end

function SetATCWarnMode(mode)
	Call("*:SetControlValue", "ATCWarnMode", 0, mode)
end

function UpdateATC(interval)
	local targetSpeed, trainSpeed, enabled, throttle
	local spdType, spdLimit, spdDist, spdBuffer
	local sigType, sigState, sigDist, sigAspect

	targetSpeed = Call("*:GetCurrentSpeedLimit")
	trainSpeed = math.abs(TrainSpeed) * MPH_TO_MPS
	spdType, spdLimit, spdDist = Call("*:GetNextSpeedLimit", 0, 0)
	spdType2, spdLimit2, spdDist2 = Call("*:GetNextSpeedLimit", 0, spdDist + 0.1)
	enabled = Call("*:GetControlValue", "ATCEnabled", 0) > 0
	
	targetSpeed = Call("*:GetCurrentSpeedLimit")
	trackSpeed = targetSpeed
	if (spdType2 == 0 and spdType ~= 0) then
		spdType, spdLimit, spdDist = spdType2, spdLimit2, spdDist2
	end
	
	if (spdType == 0) then -- End of line...stop the train
		spdBuffer = (getBrakingDistance(0.0, targetSpeed, -ATC_TARGET_DECELERATION) + 6)
		Call("*:SetControlValue", "SpeedBuffer", 0, spdBuffer)
		if (spdDist <= spdBuffer) then
			targetSpeed = math.max(getStoppingSpeed(trackSpeed, -ATC_TARGET_DECELERATION, (spdBuffer + 3.0) - spdDist) - 0.25, 1.0 * MPH_TO_MPS)
			if (spdDist <= 50) then
				targetSpeed = math.min(targetSpeed, 6 * MPH_TO_MPS)
			end
			if (spdDist < 10) then
				targetSpeed = 0
			end
		end
	elseif (spdType > 0) then
		if (spdLimit < targetSpeed) then
			spdBuffer = (getBrakingDistance(spdLimit, targetSpeed, -ATC_TARGET_DECELERATION) + 6)
			if (spdDist <= spdBuffer) then
				targetSpeed = spdLimit
			end
		end
	end
	
	gLastSigDistTime = gLastSigDistTime + interval
	sigType, sigState, sigDist, sigAspect = Call("*:GetNextRestrictiveSignal", atcSigDirection)
	if (sigDist > gLastSigDist and gLastSigDistTime >= 1.0) then
		if (atcSigDirection < 0.5) then
			atcSigDirection = 1
		else
			atcSigDirection = 0
		end
	end
	
	if (gLastSigDistTime >= 1.0) then
		gLastSigDistTime = 0.0
		gLastSigDist = sigDist
	end
	
	if enabled then
		targetSpeed = math.floor((targetSpeed * MPS_TO_MPH * 10) + 0.5) / 10 -- Round to nearest 0.1
	else
		targetSpeed = 100
	end
	
	-- Restrict target speed to the valid CTA speed limits
	if (targetSpeed >= 70) then
		targetSpeed = 70
	elseif (targetSpeed >= 55) then
		targetSpeed = 55
	elseif (targetSpeed >= 45) then
		targetSpeed = 45
	elseif (targetSpeed >= 35) then
		targetSpeed = 35
	elseif (targetSpeed >= 25) then
		targetSpeed = 25
	elseif (targetSpeed >= 15) then
		targetSpeed = 15
	elseif (targetSpeed > 0) then
		targetSpeed = 6
	else
		targetSpeed = 0
	end
	
	Call("*:SetControlValue", "ATCRestrictedSpeed", 0, targetSpeed)
	
	ATOEnabled = (Call("*:GetControlValue", "ATOEnabled", 0) or -1) > 0.0
	
	-- Following section logic taken from CTA 7000-series RFP spec
	
	throttle = CombinedLever * 2.0 - 1.0
	
	if ((TrainSpeed >= (targetSpeed + 1) or gBrakeApplication) and not ATOEnabled) then
		gAlertAcknowledged = false
		if (gBrakeApplication) then
			Call("*:SetControlValue", "ATCBrakeApplication", 0, 1.0)
			SetATCWarnMode(ATC_WARN_CONSTANT)
			if (trainSpeed < 0.1 and throttle <= -0.99) then
				gBrakeApplication = false
			end
		else
			Call("*:SetControlValue", "ATCBrakeApplication", 0, 0.0)
			if (throttle <= -0.9) then -- 90% brake application
				SetATCWarnMode(ATC_WARN_INTERMITTENT)
			else
				gBrakeTime = gBrakeTime + interval
				if (gBrakeTime >= ATC_REACTION_TIME) then
					gBrakeApplication = true
				end
				SetATCWarnMode(ATC_WARN_CONSTANT)
			end
		end
	else
		Call("*:SetControlValue", "ATCBrakeApplication", 0, 0.0)
		gBrakeTime = 0.0
		SetATCWarnMode(ATC_WARN_OFF)
	end
	
	if (TrainSpeed < (targetSpeed + 1) and throttle <= -0.9) then
		gAlertAcknowledged = true
	end
end