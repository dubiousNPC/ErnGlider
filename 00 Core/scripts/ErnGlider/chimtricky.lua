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

local speedHUD   = nil
local speedText  = nil
local speed      = nil

local function trackSpeed(newSpeed)
    if speedHUD == nil then
        return
    end
    if speed == newSpeed then
        return
    end
    if newSpeed == nil then
        speedHUD.layout.props.visible = false
    else
        speedHUD.layout.props.visible = true and settings.main.chimTricky
    end

    speedHUD.layout.content.compassFlex.content.speedText.props.text = tostring(math.floor(newSpeed)) .. " kph"
    speedHUD:update()
    speed = newSpeed
end

local function createSpeedHUD()
    if speedHUD then
        speedHUD:destroy()
        speedHUD = nil
        speedText = nil
    end

    local template = {
        content = ui.content {},
        props = {
            visible = settings.main.chimTricky
        }
    }

    local speedHUDBackground = {
        type = ui.TYPE.Image,
        name = "speedHUDBackground",
        props = {
            resource = ui.texture { path = 'black' },
            relativeSize = util.vector2(1, 1),
            alpha = 0.8
        }
    }

    template.content:add(speedHUDBackground)
    speedHUD = ui.create({
        type = ui.TYPE.Container,
        layer = 'HUD',
        name = "speedHUD",
        props = {
            relativePosition = util.vector2(0.5, 0.1),
            anchor = util.vector2(0.5, 0.5),
            autoSize = true,
            visible = false,
        },
        content = ui.content { speedHUDBackground },
    })

    local speedFlex = {
        type = ui.TYPE.Flex,
        name = "compassFlex",
        props = {
            horizontal = false,
            autoSize = true,
            size = util.vector2(1, 1),
            arrange = ui.ALIGNMENT.Start
        },
        content = ui.content {}
    }
    speedHUD.layout.content:add(speedFlex)

    speedText = {
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
        },
    }

    speedFlex.content:add(speedText)
end

createSpeedHUD()

return {
    trackSpeed = trackSpeed,
}
