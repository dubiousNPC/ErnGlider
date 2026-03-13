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
local MOD_NAME                        = require("scripts.ErnGlider.ns")
local types                           = require("openmw.types")
local world                           = require("openmw.world")
local interfaces                      = require("openmw.interfaces")
local updraftdata                     = require("scripts.ErnGlider.updraft.load")
local kerneldensityfield              = require("scripts.ErnGlider.kerneldensityfield")
local aux_util                        = require('openmw_aux.util')
local util                            = require('openmw.util')

local fieldsByCell                    = {}

local updraftVerticalStrengthFactor   = 5000
local updraftHorizontalStrengthFactor = 500

local forward                         = util.vector3(0, 1, 0)
local up                              = util.vector3(0, 0, 1)

local updraftingPlayers               = {}

local function onDoUpdraft(data)
    if not data then
        error("onGetUpdraftStrength.data is nil")
    end
    if not data.player then
        error("onGetUpdraftStrength.data.player is nil")
    end

    if not fieldsByCell[data.player.cell.id] then
        -- load up the map!
        local kdf = kerneldensityfield.new()
        local check = function(obj)
            --print("checking " .. obj.recordId)
            local updraftDataVal = updraftdata[obj.recordId]
            if updraftDataVal then
                print("found updraft source " .. obj.recordId .. ": " .. aux_util.deepToString(updraftDataVal))
                local box = obj:getBoundingBox()
                local bottom = box.center + util.vector3(0, 0, -box.halfSize.z)
                kdf:addKernel(obj.id, bottom, updraftDataVal.radius * obj.scale,
                    updraftDataVal.strength * obj.scale)
            end
        end

        for _, staticObj in ipairs(data.player.cell:getAll(types.Static)) do
            check(staticObj)
        end
        for _, activObj in ipairs(data.player.cell:getAll(types.Activator)) do
            check(activObj)
        end
        fieldsByCell[data.player.cell.id] = kdf
        --print(aux_util.deepToString(kdf, 3))
    end

    -- return val
    local updraftVal = util.clamp(fieldsByCell[data.player.cell.id]:max(data.player.position), 0, 1)
    --print("player updraft value: " .. tostring(updraftVal))
    if updraftVal > 0.1 then
        local started = false
        if not updraftingPlayers[data.player.id] then
            updraftingPlayers[data.player.id] = true
            started = true
        end
        data.player:sendEvent(MOD_NAME .. "onUpdraft", { value = updraftVal, started = started })
        -- teleport up
        -- this overrides player movement, so also move them forward so they escape
        local zBoost = up * updraftVal * data.dt * updraftVerticalStrengthFactor
        local facingBoost = data.player.rotation:apply(forward):normalize() * data.dt * updraftHorizontalStrengthFactor
        data.player:teleport(data.player.cell, data.player.position + zBoost + facingBoost)
        --data.player.position = data.player.position + zBoost
    else
        local ended = false
        if updraftingPlayers[data.player.id] then
            updraftingPlayers[data.player.id] = false
            ended = true
        end
        data.player:sendEvent(MOD_NAME .. "onUpdraft", { value = 0, ended = ended })
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
        [MOD_NAME .. 'onDoUpdraft'] = onDoUpdraft,
    }
}
