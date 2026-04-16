return {
    ['Object'] = {
        primaryColor = 0xFF32BB1D,
        fillingColor = 0x1132CC1D,
        shadingColor = 0x22000000,
        labelColor = 0xFFFFFFFF,
        focusOutlineIndex = 1,
        focusFillIndex = 0,
        focusOpacity = 1.0,
    },
    ['Dynamic'] = {
        primaryColor = 0xFF050EEE,
        fillingColor = 0x11050FFF,
        shadingColor = 0x22000000,
        labelColor = 0xFFFFFFFF,
        focusOutlineIndex = 2,
        focusFillIndex = 0,
        focusOpacity = 1.0,
    },
    ['Static'] = {
        primaryColor = 0XFF1155FF,
        fillingColor = 0x116699FF,
        shadingColor = 0x22000000,
        labelColor = 0xFFFFFFFF,
        focusOutlineIndex = 1,
        focusFillIndex = 6,
        focusOpacity = 0.35,
        focusOpacityBoost = 0.25,
    },
    ['Proxy'] = {
        primaryColor = 0xFFFF6600,
        fillingColor = 0x11FFCC00,
        shadingColor = 0x22000000,
        labelColor = 0xFFFFFFFF,
        focusOutlineIndex = 6,
        focusFillIndex = 0,
        focusOpacity = 1.0,
    },
    ['Collision'] = {
        primaryColor = 0XFFE000E0,
        fillingColor = 0x11E000E0,
        shadingColor = 0x22000000,
        labelColor = 0xFFFFFFFF,
    },
    ['Occluder'] = {
        primaryColor = 0xFFCCFFFF,
        fillingColor = 0x11CCFFFF,
        shadingColor = 0x22006666,
        labelColor = 0xFF004444,
    },
    ['Lighting'] = {
        primaryColor = 0xFFFFFF99,
        fillingColor = 0x18FFFF99,
        shadingColor = 0x22996600,
        labelColor = 0xFF885500,
    },
    ['Effect'] = {
        primaryColor = 0xFF6600FF,
        fillingColor = 0x156600FF,
        shadingColor = 0x22000000,
        labelColor = 0xFFFFFFFF,
    },
    ['Area'] = {
        primaryColor = 0xFF99FF00,
        fillingColor = 0x2299FF00,
        shadingColor = 0x22000000,
        labelColor = 0xFF330000,
    },
    ['Data'] = {
        primaryColor = 0xFF99FF00,
        fillingColor = 0x2299FF00,
        shadingColor = 0x22000000,
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
