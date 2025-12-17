---@diagnostic disable: undefined-global

local utils = {}

-- Clamp value
function utils.clamp(value, min, max)
    return math.max(min, math.min(max, value))
end

-- Lerp
function utils.lerp(a, b, t)
    return a + (b - a) * t
end

-- Map value between ranges
function utils.map(value, inMin, inMax, outMin, outMax)
    local t = (value - inMin) / (inMax - inMin)
    return utils.lerp(outMin, outMax, t)
end

-- Rect collision
function utils.rectCollision(x1, y1, w1, h1, x2, y2, w2, h2)
    return x1 < x2 + w2 and
           x2 < x1 + w1 and
           y1 < y2 + h2 and
           y2 < y1 + h1
end

-- Circle collision
function utils.circleCollision(x1, y1, r1, x2, y2, r2)
    local dx = x2 - x1
    local dy = y2 - y1
    local distance = math.sqrt(dx * dx + dy * dy)
    return distance < r1 + r2
end

-- Distance
function utils.distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

-- Angle
function utils.angle(x1, y1, x2, y2)
    return math.atan(y2 - y1, x2 - x1)
end

-- Normalize
function utils.normalize(x, y)
    local len = math.sqrt(x * x + y * y)
    if len == 0 then return 0, 0 end
    return x / len, y / len
end

-- Sign
function utils.sign(value)
    if value > 0 then return 1
    elseif value < 0 then return -1
    else return 0
    end
end

-- Round
function utils.round(value)
    return math.floor(value + 0.5)
end

-- Point in rect
function utils.pointInRect(px, py, rx, ry, rw, rh)
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end

-- Shuffle (Fisher-Yates)
function utils.shuffle(t)
    for i = #t, 2, -1 do
        local j = math.random(i)
        t[i], t[j] = t[j], t[i]
    end
    return t
end

-- Deep copy
function utils.deepcopy(obj)
    if type(obj) ~= 'table' then return obj end
    local res = {}
    for k, v in pairs(obj) do
        res[utils.deepcopy(k)] = utils.deepcopy(v)
    end
    return res
end

return utils

