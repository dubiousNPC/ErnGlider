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

local MOD_NAME = require("scripts.ErnGlider.ns")
local pself = require("openmw.self")
local core = require('openmw.core')
local nearby = require('openmw.nearby')
local util = require('openmw.util')

local gateDistance = 2000

local function getFootPos()
    local box = pself:getBoundingBox()
    return box.center + util.vector3(0, 0, -box.halfSize.z)
end

local function deriveExactGatePosition(position)
    local validPos = nil
    local attempt = 1
    local footPos = getFootPos()
    while true do
        local walkPos = nearby.findRandomPointAroundCircle(position, 500 + attempt * 100, {
            includeFlags = nearby.NAVIGATOR_FLAGS.Walk,
        })
        if walkPos then
            local height = core.land.getHeightAt(walkPos, pself)
            if height < footPos then
                validPos = footPos
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
local function gatePositions()
    local facing = pself.rotation:apply(forward):normalize()
    local firstGate = deriveExactGatePosition(pself.position + facing * gateDistance)
    local positions = {}
    table.insert(positions, firstGate)
    while #positions < 4 do
        local nextGate = deriveExactGatePosition(positions[#positions] + facing *
            math.random(math.floor(0.75 * gateDistance), math.ceil(1.25 * gateDistance)))
        if not nextGate then
            break
        end
        table.insert(positions, nextGate)
    end
    return positions
end

return {
    gatePositions = gatePositions
}
