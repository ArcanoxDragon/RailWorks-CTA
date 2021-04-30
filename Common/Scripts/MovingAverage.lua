-- #region ExponentialMovingAverage

ExponentialMovingAverage = {}
ExponentialMovingAverage.__index = ExponentialMovingAverage

function ExponentialMovingAverage.create(alpha)
    local obj = {}
    
    obj.alpha = math.max(math.min(alpha, 1.0), 0.0)
    obj.value = 0.0
    obj.lastValue = 0.0
    
    setmetatable(obj, ExponentialMovingAverage)
    return obj
end

function ExponentialMovingAverage:get(sample)
    local thisValue = self.value
    
    self.value = self.alpha * sample + (1 - self.alpha) * self.lastValue
    self.lastValue = thisValue
    
    return self.value
end

function ExponentialMovingAverage:peek()
    return self.value
end

function ExponentialMovingAverage:reset(value)
    self.value = value or 0.0
    self.lastValue = value or 0.0
end

-- #endregion ExponentialMovingAverage

-- #region MovingAverage

MovingAverage = {}
MovingAverage.__index = MovingAverage

function MovingAverage.create(windowSize)
    local obj = {}
    
    obj.windowSize = windowSize
    obj.samples = {}
    obj.state = 0.0
    obj.nextBucket = 0
    obj.debug = false
    
    setmetatable(obj, MovingAverage)
    
    obj:reset()
    
    return obj
end

function MovingAverage:get(sample)
    local currentBucket = self.nextBucket
    local currentSample = self.samples[currentBucket] or 0.0
    
    self.nextBucket = mod(self.nextBucket + 1, self.windowSize)
    self.state = self.state + (sample - currentSample) / self.windowSize
    self.samples[currentBucket] = sample
    
    return self.state
end

function MovingAverage:peek()
    return self.state
end

function MovingAverage:reset(value)
    for bucket = 0, self.windowSize do
        self.samples[bucket] = value or 0.0
    end
    
    self.state = value or 0.0
    self.nextBucket = 0
end

-- #endregion MovingAverage