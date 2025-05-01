local function clamp(value, rangeMin, rangeMax)
    return math.max(rangeMin, math.min(rangeMax, value))
end

local function intersectPlane(plane, line)
	local direction = Game['OperatorSubtract;Vector4Vector4;Vector4'](line[2], line[1])
	local denom = Vector4.Dot(plane.normal, direction)

	if math.abs(denom) < 0.0001 then
		return nil
	end

	local diff = Game['OperatorSubtract;Vector4Vector4;Vector4'](plane.origin, line[1])
	local distance = Vector4.Dot(diff, plane.normal) / denom

	if math.abs(distance) < 0.0001 then
		return nil
	end

    local destination = Game['OperatorMultiply;Vector4Float;Vector4'](direction, distance)
    local intersection = Game['OperatorAdd;Vector4Vector4;Vector4'](line[1], destination)

	return intersection, distance
end

return {
    Clamp = clamp,
    IntersectPlane = intersectPlane,
}
