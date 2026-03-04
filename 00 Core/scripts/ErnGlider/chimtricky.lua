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
local MOD_NAME   = require("scripts.ErnGlider.ns")
local core       = require("openmw.core")
local pself      = require("openmw.self")
local camera     = require('openmw.camera')
local util       = require('openmw.util')
local async      = require("openmw.async")
local types      = require('openmw.types')
local input      = require('openmw.input')
local controls   = require('openmw.interfaces').Controls
local nearby     = require('openmw.nearby')
local animation  = require('openmw.animation')
local ui         = require('openmw.ui')
local aux_util   = require('openmw_aux.util')
local interfaces = require("openmw.interfaces")
local settings   = require("scripts.ErnGlider.settings")

-- TODO: also show fatigue and current shield condition and turn off other hud stuff

local kphText    = ui.create {
    type = ui.TYPE.Text,
    name = "speedText",
    props = {
        text = "0 kph",
        textColor = util.color.rgba(.9, 0.9, 0.8, 0.9),
        textShadow = true,
        textShadowColor = util.color.rgba(0, 0, 0, 0.9),
        textAlignV = ui.ALIGNMENT.Start,
        textAlignH = ui.ALIGNMENT.Start,
        textSize = 18,
    }
}

local function barLayout()
    return {
        type = ui.TYPE.Widget,
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
                    alpha = 0.625,
                    color = util.color.rgb(0.1, 0.1, 0.1),
                },
                events = {},
            },
            {
                type = ui.TYPE.Image,
                name = 'barFill',
                props = {
                    resource = ui.texture { path = 'white' },
                    relativePosition = util.vector2(0, 0),
                    relativeSize = util.vector2(1, 0),
                    alpha = 0.4,
                    color = util.color.rgb(0.8, 0.8, 0.5),
                },
            },
        }
    }
end

local fatigueBar         = ui.create(barLayout())
local conditionBar       = ui.create(barLayout())

local root               = ui.create {
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
                    -- ensures minimum size
                    props = { size = util.vector2(60, 0) }
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
                        fatigueBar, conditionBar
                    }
                },
            }
        }
    }
}

---@class DisplayData
---@field speed number
---@field conditionRatio number
---@field fatigueRatio number

---@type DisplayData?
local currentDisplayData = nil

---@param data DisplayData?
local function display(data)
    if not settings.main.chimTricky then
        data = nil
    end
    -- handle visibility
    if not data then
        -- newly hidden
        if currentDisplayData then
            settings.debugPrint("Hiding CHIM Tricky UI")
            currentDisplayData = nil
            root.layout.props.visible = false
            root:update()
        end
        --no-op
        return
    else
        root.layout.props.visible = true
    end

    if data.speed then
        kphText.layout.props.text = tostring(math.floor(data.speed)) .. " kph"
        kphText:update()
    end

    fatigueBar:update()
    conditionBar:update()

    settings.debugPrint(aux_util.deepToString(data, 3))
    root:update()
    currentDisplayData = data
end

return {
    display = display,
}
