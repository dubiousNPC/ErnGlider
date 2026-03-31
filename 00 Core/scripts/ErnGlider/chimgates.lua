--[[
ErnGlider for OpenMW.
Copyright (C) 2026 Erin Pentecost

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

local MOD_NAME     = require("scripts.ErnGlider.ns")
local pself        = require("openmw.self")
local core         = require('openmw.core')
local nearby       = require('openmw.nearby')
local util         = require('openmw.util')
local settings     = require("scripts.ErnGlider.settings")

local gateDistance = 1000

local function getFootPos()
    local box = pself:getBoundingBox()
    return box.center + util.vector3(0, 0, -box.halfSize.z)
end

local up = util.vector3(0.0, 0.0, 1.0)

local function deriveExactGatePosition(position)
    local validPos = nil
    local attempt = 1
    local footPos = getFootPos()
    local hit = nearby.castRay(position + up * 1000, position + up * -5000, {
        collisionType = nearby.COLLISION_TYPE.HeightMap,
        radius = 10,
    })
    if not hit.hitPos then
        settings.debugPrint("no ground at gate position")
        return
    end
    while true do
        local walkPos = nearby.findRandomPointAroundCircle(hit.hitPos, gateDistance / 3, {
            includeFlags = nearby.NAVIGATOR_FLAGS.Walk,
        })
        if walkPos then
            local height = walkPos.z
            settings.debugPrint("testing chim gate at height " .. tostring(height))
            if height and (height < footPos.z) then
                validPos = walkPos
                break
            end
        end
        attempt = attempt + 1
        if attempt > 16 then
            break
        end
    end
    if not validPos then
        return nil
    end
    return validPos
end

local forward = util.vector3(0.0, 1.0, 0.0)
local function nextGatePosition(lastPosition)
    local facing = pself.rotation:apply(forward):normalize()
    if not lastPosition then
        return deriveExactGatePosition(pself.position + facing * gateDistance)
    end

    local initialPos = lastPosition + facing *
        math.random(math.floor(0.75 * gateDistance), math.ceil(1.25 * gateDistance))
    return deriveExactGatePosition(initialPos)
end

return {
    nextGatePosition = nextGatePosition
}
