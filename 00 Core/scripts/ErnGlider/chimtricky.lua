--[[
ErnGlider for OpenMW.
Copyright (C) 2025 Erin Pentecost

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>.
]]
local MOD_NAME           = require("scripts.ErnGlider.ns")
local core               = require("openmw.core")
local pself              = require("openmw.self")
local camera             = require('openmw.camera')
local util               = require('openmw.util')
local async              = require("openmw.async")
local types              = require('openmw.types')
local input              = require('openmw.input')
local controls           = require('openmw.interfaces').Controls
local nearby             = require('openmw.nearby')
local animation          = require('openmw.animation')
local ui                 = require('openmw.ui')
local aux_util           = require('openmw_aux.util')
local interfaces         = require("openmw.interfaces")
local settings           = require("scripts.ErnGlider.settings")
local localization       = core.l10n(MOD_NAME)
local uiInterface        = require("openmw.interfaces").UI

---@class DisplayData
---@field dt number
---@field speed number
---@field conditionRatio number
---@field fatigueRatio number
---@field points number

---@type DisplayData?
local currentDisplayData = nil

-- from PCP-OpenMW
-- Get a usable color value from a fallback in openmw.cfg
local function configColor(setting)
    local v = core.getGMST('FontColor_color_' .. setting)
    local values = {}
    for i in v:gmatch('([^,]+)') do table.insert(values, tonumber(i)) end
    local color = util.color.rgb(values[1] / 255, values[2] / 255, values[3] / 255)
    return color
end

local pointsText = ui.create {
    type = ui.TYPE.Text,
    name = "pointsText",
    props = {
        text = "0",
        textColor = configColor("normal"),
        textShadow = true,
        textShadowColor = util.color.rgba(0, 0, 0, 0.9),
        --textAlignV = ui.ALIGNMENT.Start,
        --textAlignH = ui.ALIGNMENT.Start,
        textSize = 18,
        relativePosition = util.vector2(0.5, 0.5),
        --anchor = util.vector2(0.5, 0.5),
    }
}

local kphText    = ui.create {
    type = ui.TYPE.Text,
    name = "speedText",
    props = {
        text = "0 kph",
        textColor = configColor("normal"),
        textShadow = true,
        textShadowColor = util.color.rgba(0, 0, 0, 0.9),
        textAlignV = ui.ALIGNMENT.Start,
        textAlignH = ui.ALIGNMENT.Start,
        textSize = 18,
        relativePosition = util.vector2(1, 0),
        anchor = util.vector2(1, 0),
    }
}

local function barLayout(ratio, color)
    return {
        type = ui.TYPE.Widget,
        name = 'bar',
        template = interfaces.MWUI.templates.borders,
        props = {
            size = util.vector2(20, 100),
        },
        content = ui.content {
            {
                type = ui.TYPE.Image,
                name = 'barContainer',
                props = {
                    resource = ui.texture { path = 'white' },
                    relativePosition = util.vector2(0, 0),
                    relativeSize = util.vector2(1, 1),
                    alpha = 0.7,
                    color = util.color.rgb(0.1, 0.1, 0.1),
                },
                events = {},
            },
            {
                type = ui.TYPE.Image,
                name = 'barFill',
                props = {
                    resource = ui.texture { path = 'white' },
                    anchor = util.vector2(0, 1),
                    relativePosition = util.vector2(0, 1),
                    relativeSize = util.vector2(1, ratio),
                    alpha = 0.7,
                    color = color,
                },
            },
        }
    }
end

local function setRatio(elem, ratio)
    if elem.layout.content.barFill.props.relativeSize.y ~= ratio then
        elem.layout.content.barFill.props.relativeSize = util.vector2(1, ratio)
    end
end

local fatigueBar    = ui.create(barLayout(0.3, configColor("fatigue")))
local conditionBar  = ui.create(barLayout(0.7, configColor("weapon_fill")))

local pointsElement = ui.create {
    name = "root",
    layer = 'HUD',
    type = ui.TYPE.Container,
    props = {
        position = util.vector2(10, 10),
        anchor = util.vector2(0, 0),
        visible = false,
        autoSize = true,
    },
    content = ui.content {
        pointsText
    }
}

local statusElement = ui.create {
    name = "root",
    layer = 'HUD',
    type = ui.TYPE.Container,
    --template = interfaces.MWUI.templates.boxTransparentThick,
    props = {
        relativePosition = util.vector2(1, 0.5),
        anchor = util.vector2(1, 0.5),
        visible = false,
        autoSize = true,
    },
    content = ui.content {
        {
            name = 'vFlex',
            type = ui.TYPE.Flex,
            props = {
                horizontal = false,
                arrange = ui.ALIGNMENT.Center,
            },
            content = ui.content {
                {
                    -- ensures minimum width
                    props = { size = util.vector2(60, 0) },
                },
                kphText,
                {
                    name = 'barFlex',
                    type = ui.TYPE.Flex,
                    props = {
                        horizontal = true,
                        autoSize = true,
                    },
                    content = ui.content {
                        { props = { size = util.vector2(4, 0) } },
                        fatigueBar,
                        { props = { size = util.vector2(4, 0) } },
                        conditionBar,
                        { props = { size = util.vector2(4, 0) } }
                    }
                },
            }
        }
    }
}

---@param data DisplayData?
local function display(data)
    if not settings.surf.chimTricky then
        data = nil
    end
    -- handle visibility
    if not data then
        -- newly hidden
        if currentDisplayData then
            settings.debugPrint("Hiding CHIM Tricky UI")
            uiInterface.setHudVisibility(true)
            currentDisplayData = nil
            statusElement.layout.props.visible = false
            statusElement:update()
            pointsElement.layout.props.visible = false
            pointsElement:update()
        end
        --no-op
        return
    else
        uiInterface.setHudVisibility(false)
        statusElement.layout.props.visible = true
        pointsElement.layout.props.visible = true
    end

    if data.speed then
        if currentDisplayData ~= nil and currentDisplayData.speed ~= data.speed then
            kphText.layout.props.text = localization('kph', { value = math.floor(data.speed) })
            kphText:update()
        end
    end

    if data.fatigueRatio then
        setRatio(fatigueBar, data.fatigueRatio)
    end
    fatigueBar:update()
    if data.conditionRatio then
        setRatio(conditionBar, data.conditionRatio)
    end
    conditionBar:update()

    if data.points then
        if currentDisplayData ~= nil and currentDisplayData.points ~= data.points then
            pointsText.layout.props.text = tostring(data.points)
            pointsText:update()
        end
    end

    --settings.debugPrint(aux_util.deepToString(data, 3))
    statusElement:update()
    pointsElement:update()
    local oldDT = currentDisplayData and currentDisplayData.dt or 0
    currentDisplayData = data
    currentDisplayData.dt = currentDisplayData.dt + oldDT
end

return {
    display = display,
}
