return function(...)
    local map = { values = {} }
    for index, value in ipairs({...}) do
        map[value] = value
        map.values[index] = value
        map.values[value] = index
    end
    return map
end
