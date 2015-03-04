local debugFile = io.open("lua_debug.log", "w+")
local pi = 3.14159265

-- Why RailWorks defined these, I have no clue, but I'm keeping them defined anyways...
TRUE = 1
FALSE = 0

-- Digits constants

PRIMARY_DIGITS = 0
SECONDARY_DIGITS = 1

function debugPrint(msg)
	Print(msg)
	debugFile:seek("end", 0)
	debugFile:write(msg .. "\n")
	debugFile:flush()
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

function reverseMsgDir(direction)
	if (direction == 0) then return 1 end
	return 0
end