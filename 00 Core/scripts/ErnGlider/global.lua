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
local MOD_NAME           = require("scripts.ErnGlider.ns")
local types              = require("openmw.types")
local world              = require("openmw.world")
local interfaces         = require("openmw.interfaces")
local updraftdata        = require("scripts.ErnGlider.updraft.load")
local kerneldensityfield = require("scripts.ErnGlider.kerneldensityfield")

local fieldsByCell       = {}

local function onGetUpdraftStrength(data)
    if not data then
        error("onGetUpdraftStrength.data is nil")
    end
    if not data.player then
        error("onGetUpdraftStrength.data.player is nil")
    end

    if not fieldsByCell[data.player.cell.id] then
        -- load up the map!
        local kdf = kerneldensityfield.new()
        for _, staticObj in ipairs(data.player.cell:getAll(types.Static)) do
            local updraftDataVal = updraftdata[staticObj.recordId]
            if updraftDataVal then
                kdf:addKernel(staticObj.id, staticObj.position, updraftDataVal.radius, updraftDataVal.strength)
            end
        end
        fieldsByCell[data.player.cell.id] = kdf
    end

    -- return val
    local updraftVal = fieldsByCell[data.player.cell.id]:calculate(data.player.position)
    if updraftVal > 0 then
        data.player:sendEvent(MOD_NAME .. "onUpdraft", { value = updraftVal })
    end
end


local function onHitByGlider(data)
    interfaces.Crimes.commitCrime(data.glider, {
        type = types.Player.OFFENSE_TYPE.Assault,
        victim = data.victim,
        victimAware = true,
    })
end

local function onDamageItem(data)
    types.Item.itemData(data.item).condition = types.Item.itemData(data.item).condition - data.amount
end

return {
    eventHandlers = {
        [MOD_NAME .. 'onHitByGlider'] = onHitByGlider,
        [MOD_NAME .. 'onDamageItem'] = onDamageItem,
        [MOD_NAME .. 'onGetUpdraftStrength'] = onGetUpdraftStrength,
    }
}
