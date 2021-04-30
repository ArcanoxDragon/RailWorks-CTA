PID = {}
PID.__index = PID

function PID.create( options )
	options = options or {}
	
	local pid 			= {}
	
	-- options
	pid.kP = options.kP
	pid.kI = options.kI
	pid.kD = options.kD
	pid.minOutput = options.minOutput or -1.0
	pid.maxOutput = options.maxOutput or 1.0
	pid.minIntegral = options.minIntegral or pid.minOutput or -1.0
	pid.maxIntegral = options.maxIntegral or pid.maxOutput or 1.0
	pid.dynamicIntegralLargeThreshold = options.dynamicIntegralLargeThreshold or math.huge
	pid.dynamicIntegralSmallThreshold = options.dynamicIntegralSmallThreshold or pid.dynamicIntegralLargeThreshold
	pid.dynamicIntegral = options.dynamicIntegral or false
	pid.errorAvgAlpha = options.errorAvgAlpha or 0
	pid.deltaAvgAlpha = options.deltaAvgAlpha or 0
	
	-- state
	pid.lastInput = 0.0
	pid.error = 0.0
	pid.delta = 0.0
	pid.integral = 0.0
	pid.iLocked = false
	pid.iAutoLocked = false
	pid.value = 0.0
	pid.p = 0.0
	pid.i = 0.0
	pid.d = 0.0
	
	if pid.errorAvgAlpha > 0 then
		pid.errorAvg = ExponentialMovingAverage.create(pid.errorAvgAlpha)
	end
	if pid.deltaAvgAlpha > 0 then
		pid.deltaAvg = ExponentialMovingAverage.create(pid.deltaAvgAlpha)
	end
	
	setmetatable( pid, PID )
	return pid
end

function PID:update( target, actual, dt )
	self.error = target - actual
	self.delta = (actual - self.lastInput) / dt
	
	if self.errorAvg then
		self.error = self.errorAvg:get(self.error)
	end
	if self.deltaAvg then
		self.delta = self.deltaAvg:get(self.delta)
	end
	
	self.integralDynamicLocked = self.dynamicIntegral and math.abs(self.delta) > self.dynamicIntegralSmallThreshold
	
	if self.integralDynamicLocked and math.abs(self.delta) > self.dynamicIntegralLargeThreshold then
		self.integral = 0
	end
	
	local integralEffectivelyLocked = self.integralLocked or self.integralDynamicLocked
	
	if not integralEffectivelyLocked then
		self.integral = math.max( math.min( self.integral + self.error * self.kI * dt, self.maxIntegral ), self.minIntegral )
	end
	
	self.p = self.kP * self.error
	self.i = self.integral
	self.d = self.kD * self.delta

	self.lastInput = actual
	self.value = math.max( math.min( self.p + self.i - self.d, self.maxOutput ), self.minOutput )
	
	return self.value
end

function PID:resetIntegral()
	self.integral = 0.0
end

function PID:reset()
	self.integral = 0.0
	self.lastInput = 0.0
	self.integralLocked = false
	self.integralDynamicLocked = false
	
	if self.errorAvg then
		self.errorAvg:reset()
	end
	
	if self.deltaAvg then
		self.deltaAvg:reset()
	end
end