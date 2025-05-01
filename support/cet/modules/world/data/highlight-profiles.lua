return {
    ['Dynamic'] = {
        primaryColor = 0xFF050EEE,
        shadingColor = 0x11050FFF,
        labelColor = 0xFFFFFFFF,
        focusOutlineIndex = 2,
        focusFillIndex = 0,
        focusOpacity = 1.0,
    },
    ['Object'] = {
        primaryColor = 0xFF32BB1D,
        shadingColor = 0x1132CC1D,
        labelColor = 0xFFFFFFFF,
        focusOutlineIndex = 1,
        focusFillIndex = 0,
        focusOpacity = 1.0,
    },
    ['Collision'] = {
        primaryColor = 0XFFE011E0,
        shadingColor = 0x11F011F0,
        labelColor = 0xFFFFFFFF,
    },
    ['Static'] = {
        primaryColor = 0XFF0060FF,
        shadingColor = 0x110060FF,
        labelColor = 0xFFFFFFFF,
        focusOutlineIndex = 1,
        focusFillIndex = 6,
        focusOpacity = 0.4,
        focusOpacityBoost = 0.2,
    },
    ['Proxy'] = {
        primaryColor = 0xFF6600FF,
        shadingColor = 0x156600FF,
        labelColor = 0xFFFFFFFF,
    },
    ['Occluder'] = {
        primaryColor = 0xFFFF9900,
        shadingColor = 0x11FFCC00,
        labelColor = 0xFFFFFFFF,
    },
    ['Lighting'] = {
        primaryColor = 0xFFFF9900,
        shadingColor = 0x11FFCC00,
        labelColor = 0xFFFFFFFF,
    },
    ['Area'] = {
        primaryColor = 0xFFFF0066,
        shadingColor = 0x22FF0066,
        labelColor = 0xFFFFFFFF,
    },
    ['Data'] = {
        primaryColor = 0xFF99FF00,
        shadingColor = 0x2299FF00,
        labelColor = 0xFF330000,
    },
}

--[[
Highlight Shader

fillIndex
1 = yellow (very intensive, no distance limits)
2 = light blue (disappears with distance)
3 = white (disappears with distance)
4 = green (disappears with distance and upclose)
5 = light blue (disappears with distance and upclose)
6 = orange (disappears with distance)
7 = red (disappears upclose)
8 = black

outlineIndex
1 = green
2 = red
3 = light blue
4 = light red
5 = yellow
6 = bright blue
7 = white
8 = black
--]]
