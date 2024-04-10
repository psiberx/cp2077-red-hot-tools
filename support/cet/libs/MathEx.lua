local function clamp(value, rangeMin, rangeMax)
    return math.max(rangeMin, math.min(rangeMax, value))
end

return {
    Clamp = clamp,
}
