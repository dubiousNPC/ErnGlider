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
local MOD_NAME = require("scripts.ErnGlider.ns")
local core = require("openmw.core")
local pself = require("openmw.self")
local camera = require('openmw.camera')
local util = require('openmw.util')
local async = require("openmw.async")
local types = require('openmw.types')
local input = require('openmw.input')
local controls = require('openmw.interfaces').Controls
local nearby = require('openmw.nearby')
local animation = require('openmw.animation')
local cameraInterface = require("openmw.interfaces").Camera
local uiInterface = require("openmw.interfaces").UI
local settings = require("scripts.ErnGlider.settings")

local persist = {
    canApply=false,
    applied=false
}

local glideSpells = {
    eg_glide_1 = "eg_glide_1",
    eg_glide_2 = "eg_glide_2",
    eg_glide_3 = "eg_glide_3",
}

local function getSoundFilePath(file)
    return "sound\\" .. MOD_NAME .. "\\" .. file
end

local sounds = {
    wind = getSoundFilePath("wind.mp3"),
    breath_in = getSoundFilePath("breath_in.mp3"),
    hit_wall = "Sound\\Fx\\FOOT\\land_lt.wav"
}

local function applyGlideSpell()
    local acrobatics = pself.type.stats.skills.acrobatics(pself).modified
    local record = glideSpells.eg_glide_3
    if acrobatics <= 20 then
        record = glideSpells.eg_glide_1
    elseif acrobatics <= 60 then
        record = glideSpells.eg_glide_2
    end
    pself.type.activeSpells(pself):add({
        id = record,
        effects = { 0,1 },
        ignoreResistances = true,
        ignoreSpellAbsorption = true,
        ignoreReflect = true
    })
end

local function touchingWall()
    local pselfCenter = pself:getBoundingBox().center
    local facing = pself.rotation:apply(util.vector3(0.0, 1.0, 0.0)):normalize()*70

    local castResult = nearby.castRay(pselfCenter, pselfCenter+facing, {
        collisionType = nearby.COLLISION_TYPE.AnyPhysical,
        ignore = pself
    })

    return castResult.hit
end

local fatigueStat = pself.type.stats.dynamic.fatigue(pself)

local function instantCost()
    return math.ceil(settings.main.fatigueCost * 1.5)
end

local function onInit(initData)
    if initData ~= nil then
        persist = initData
    end
end
local function onLoad(data)
    if data ~= nil then
        persist = data
    end
end
local function onSave()
    return persist
end

local function canApply()
    if types.Actor.isOnGround(pself) then
        settings.debugPrint("canApply gilder: on ground")
        return false
    end
    if types.Actor.getStance(pself) ~= types.Actor.STANCE.Nothing then
        settings.debugPrint("canApply gilder: spell or weapon is readied")
        return false
    end
    if not animation.isPlaying(pself, "jump") then
        settings.debugPrint("canApply gilder: not jumping")
        return false
    end
    local levitateEffect = types.Actor.activeEffects(pself):getEffect(core.magic.EFFECT_TYPE.Levitate)
    if (levitateEffect ~= nil) and (levitateEffect.magnitude > 0) then
        settings.debugPrint("canApply gilder: levitating")
        return false
    end
    if fatigueStat.current < instantCost() then
        settings.debugPrint("canApply gilder: can't pay instant fatigue cost")
        return false
    end
    if (not pself.cell.isExterior) and (not pself.cell:hasTag("QuasiExterior")) then
        settings.debugPrint("canApply gilder: interior cell")
        return false
    end
    if not types.Player.getControlSwitch(pself, types.Player.CONTROL_SWITCH.Controls) then
        settings.debugPrint("canApply gilder: no control")
        return false
    end
    return true
end

local function removeGlider()
    if not persist.applied then
        return
    end
    persist.applied = false
    print("Removing glider...")
    -- reset movement
    pself.controls.movement = 0
    -- remove spell effects
    for _, spell in pairs(pself.type.activeSpells(pself)) do
        if glideSpells[spell.id] then
            pself.type.activeSpells(pself):remove(spell.activeSpellId)
        end
    end
    -- remove sound
    core.sound.stopSoundFile3d(sounds.wind, pself)
end

local function applyGlider()
    if not canApply() then
        return
    end
    persist.applied = true
    print("Applying glider...")
    -- set movement on this frame
    pself.controls.movement = 1
    -- apply sound
    core.sound.playSoundFile3d(sounds.wind, pself, {
        volume = settings.main.volume * 0.3,
        loop = true,
    })
    core.sound.playSoundFile3d(sounds.breath_in, pself, {
        volume = settings.main.volume,
    })
    -- apply spell
    applyGlideSpell()
    -- apply initial cost
    local cost = instantCost()
    fatigueStat.current = fatigueStat.current - cost
end

input.registerTriggerHandler("Jump", async:callback(
    function()
        if not settings.main.enable then
            return
        end
        print("jump detected")
        if persist.applied then
            removeGlider()
        else
            applyGlider()
        end
    end
))

local fatigueDebt = 0
local function onUpdate(dt)
    if dt == 0 then return end
    if not settings.main.enable then
        removeGlider()
        return
    end
    if persist.applied then
        if not canApply() then
            print("no longer valid")
            removeGlider()
            return
        end
        fatigueDebt = fatigueDebt + settings.main.fatigueCost * dt
        if fatigueDebt > 1 then
            local whole = math.floor(fatigueDebt)
            fatigueDebt = fatigueDebt - whole
            fatigueStat.current = fatigueStat.current - whole

            -- do this check less frequently
            if touchingWall() then
                core.sound.playSoundFile3d(sounds.hit_wall, pself, {
                    volume = settings.main.volume,
                })
                removeGlider()
                return
            end
        end
    else
        fatigueDebt = 0
    end
end

local function onFrame()
    if persist.applied then
        pself.controls.movement = 1
    end
end

return {
    engineHandlers = {
        onInit = onInit,
        onLoad = onLoad,
        onSave = onSave,
        onUpdate = onUpdate,
        onFrame = onFrame
    }
}
