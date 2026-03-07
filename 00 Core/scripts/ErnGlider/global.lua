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
local types = require("openmw.types")
local world = require("openmw.world")
local interfaces = require("openmw.interfaces")


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
    }
}
