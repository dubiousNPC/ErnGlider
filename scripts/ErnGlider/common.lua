--[[
Animated Levitation
Copyright (C) 2025 fallchildren (modified)

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

local pself = require('openmw.self')
local types = require('openmw.types')
local anim = require('openmw.animation')
local camera = nil

if types.Player == pself.type then
    camera = require('openmw.camera')
end

local suffixes = { "1h", "2h", "2c", "hh", "1s", "1b", "2b", "2w", "bow", "crossbow", "1t" }

local function checkAnimation(a)
    if anim.isPlaying(pself, a) then
        return true
    end
    for _, suffix in ipairs(suffixes) do
        if anim.isPlaying(pself, a .. suffix) then
            return true
        end
    end

    return false
end

local function cancelAnimation(a)
    anim.cancel(pself, a)
    for _, suffix in ipairs(suffixes) do
        anim.cancel(pself, a .. suffix)
    end
end

local function playAnimation(animation, speed)
    local mask = anim.BLEND_MASK.All
    if camera and camera.MODE.FirstPerson == camera.getMode() then
        mask = anim.BLEND_MASK.LowerBody
    end
    anim.playBlended(
        pself,
        animation,
        {
            priority = anim.PRIORITY.Movement,
            speed = speed,
            blendMask = mask,
            loops = -1
        }
    )
end

local function overwriteAnimation(origanim, replaceanim, speed)
    cancelAnimation(origanim)
    playAnimation(replaceanim, speed)
end

return {
    playAnimation = playAnimation,
    cancelAnimation = cancelAnimation,
    overwriteAnimation = overwriteAnimation,
    checkAnimation = checkAnimation,
}
