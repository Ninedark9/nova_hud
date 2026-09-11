NovaMinimap = {}

function NovaMinimap.layout(screenW, screenH, config, originX, originY, scaleX, scaleY)
    local function clamp(value, low, high) return math.max(low, math.min(high, value)) end
    local diameter = clamp(screenW * (config.diameter or 0.12), 190, 420)
    diameter = math.min(diameter, screenH * 0.4)
    local right = clamp(tonumber(config.right) or 0.014, 0, 0.25) + math.max(0, originX)
    local top = clamp(tonumber(config.top) or 0.026, 0, 0.25) + math.max(0, originY)
    local width, height = diameter / screenW, diameter / screenH
    local left = 1.0 - right - width
    local x, y = (left - originX) / scaleX, (top - originY) / scaleY
    local w, h = width / scaleX, height / scaleY
    return {
        x = x, y = y, w = w, h = h,
        blurX = x, blurY = y, blurW = w, blurH = h,
        screenW = screenW, screenH = screenH,
        overlay = { left = left, top = top, width = width, height = height },
    }
end

function NovaMinimap.coverage(x, y, size, insetPixels)
    local inset = math.max(1.0, tonumber(insetPixels) or 4.0)
    local radius = size / 2 - inset
    local dx, dy = x + 0.5 - size / 2, y + 0.5 - size / 2
    return math.floor(math.max(0, math.min(1, radius + 0.5 - math.sqrt(dx * dx + dy * dy))) * 255 + 0.5)
end
