local debugFile = io.open("lua_debug.log", "w+")

MPS_TO_MPH = 2.23694 -- Meters/Second to Miles/Hour
MPH_TO_MPS = 1.0 / MPS_TO_MPH
MPH_TO_MiPS = 0.000277777778 -- Miles/Hour to Miles/Second

-- Why RailWorks defined these, I have no clue, but I'm keeping them defined anyways...
TRUE = 1
FALSE = 0

-- Digits constants

PRIMARY_DIGITS = 0
SECONDARY_DIGITS = 1

intervals = {}

function debugPrintInner(message)
	local formattedMessage = string.format("[%s] %s", os.date("%X"), message)
	
	Print(formattedMessage)
	debugFile:seek("end", 0)
	debugFile:write(formattedMessage .. "\n")
	debugFile:flush()
end

function debugPrint(message)
	local success, err = pcall(function() debugPrintInner(message) end)
	
	if not success then
		debugFile:seek("end", 0)
		debugFile:write("Error calling debugPrint: " .. err .. "\n")
		debugFile:flush()
	end
end

function carPrint( msg )
	debugPrint( "[" .. Call( "*:GetRVNumber" ) .. "] " .. msg )
end

-- inclusive min, exclusive max
function inRange( val, min, max )
	return val >= min and val < max
end

function checkInterval( name, interval, timeDelta )
	if ( intervals[ name ] == nil ) then
		local newInterval = {}
		newInterval.time = 0.0
		intervals[ name ] = newInterval
	end
	
	local i = intervals[ name ]
	
	i.time = i.time + timeDelta
	if ( i.time >= interval ) then
		i.time = 0
		return true
	else
		return false
	end
end

function clamp(x, xMin, xMax)
	return math.min(math.max(x, xMin), xMax)
end

function round(num, precision)
	local mult = 10 ^ (precision or 0)
	return math.floor(num * mult + 0.5) / mult
end

function sign(num)
	if (num > 0) then return 1 end
	if (num < 0) then return -1 end
	return 0
end

function mod(a, b)
	return a - math.floor(a / b) * b
end

function reverseMsgDir(direction)
	if (direction == 0) then return 1 end
	return 0
end

function getBrakingDistance(vF, vI, a)
	return ((vF * vF) - (vI * vI)) / (2 * a)
end

function getStoppingSpeed(vI, a, d)
	return math.sqrt(math.max((vI * vI) + (2 * a * d), 0.0))
end

function mapRange( value, sourceMin, sourceMax, destMin, destMax, doClamp )
	local c = doClamp and true or false -- Convert optional into boolean
	local normalized = ( value - sourceMin ) / ( sourceMax - sourceMin )
	
	if c then
		local clampMin = math.min( destMin, destMax )
		local clampMax = math.max( destMin, destMax )
	
		return clamp( normalized * ( destMax - destMin ) + destMin, clampMin, clampMax )
	else
		return normalized * ( destMax - destMin ) + destMin
	end
end