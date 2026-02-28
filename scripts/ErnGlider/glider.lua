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
local interfaces = require("openmw.interfaces")
local settings = require("scripts.ErnGlider.settings")

-- how much yaw change contributes to side movement drift
local driftFactor = 3.0
-- side movement is multiplied by this each frame so it decays back to 0
local driftDecay = 0.9

local persist = {
    applied = false,
    appliedDuration = 0,
    sideMovement = 0,
}

pself.type.addTopic(pself, "glider")

local function getCurrentGlider()
    local gliderQuest = pself.type.quests(pself)["eg_glider"]
    local gliderStage = gliderQuest and gliderQuest.stage or 0
    if gliderStage >= 31 then
        return "eg_glide_3"
    elseif gliderStage >= 21 then
        return "eg_glide_2"
    elseif gliderStage >= 1 then
        return "eg_glide_1"
    else
        return nil
    end
end

local glideSpells = {
    eg_glide_1 = "eg_glide_1",
    eg_glide_2 = "eg_glide_2",
    eg_glide_3 = "eg_glide_3",
}
local glideVFX = {
    eg_glide_1 = "meshes\\a\\a_dreugh_helm.nif",
    eg_glide_2 = "meshes\\a\\a_bonemold_chuzei_helmet.nif",
    eg_glide_3 = "meshes\\a\\a_dustadept_helm.nif",
}

local function getSoundFilePath(file)
    return "sound\\" .. MOD_NAME .. "\\" .. file
end

local sounds = {
    wind = getSoundFilePath("wind.mp3"),
    breath_in = getSoundFilePath("breath_in.mp3"),
    hit_wall = "Sound\\Fx\\FOOT\\land_lt.wav"
}

local function applyGlideSpell(currentGlider)
    local spell = glideSpells[currentGlider]
    local vfx = glideVFX[currentGlider]
    pself.type.activeSpells(pself):add({
        id = spell,
        effects = { 0, 1 },
        ignoreResistances = true,
        ignoreSpellAbsorption = true,
        ignoreReflect = true
    })
    animation.addVfx(pself, vfx, { loop = true, boneName = "Head", vfxId = "glider" })
end

local forward = util.vector3(0.0, 1.0, 0.0)
local function touchingWall()
    local pselfCenter = pself:getBoundingBox().center
    local facing = pself.rotation:apply(forward):normalize() * 70

    local castResult = nearby.castRay(pselfCenter, pselfCenter + facing, {
        collisionType = nearby.COLLISION_TYPE.AnyPhysical,
        ignore = pself
    })

    return castResult
end

local enduranceStat = pself.type.stats.attributes.endurance(pself)
local fatigueStat = pself.type.stats.dynamic.fatigue(pself)

local function instantCost()
    return math.ceil(settings.main.fatigueCost)
end

local function naturalFatigueRegenRate()
    return 2.5 + (0.02 * enduranceStat.modified)
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
    print("Glide duration: " .. tostring(persist.appliedDuration))
    -- apply skill XP for glides longer than 3 seconds.
    if persist.appliedDuration > 3 then
        interfaces.SkillProgression.skillUsed(core.stats.Skill.records.acrobatics.id,
            {
                scale = persist.appliedDuration - 1,
                useType = interfaces.SkillProgression.SKILL_USE_TYPES
                    .Acrobatics_Jump
            })
    end
    persist.applied = false
    persist.appliedDuration = 0
    persist.sideMovement = 0
    print("Removing glider...")
    -- reset movement
    pself.controls.movement = 0
    -- remove spell effects
    for _, spell in pairs(pself.type.activeSpells(pself)) do
        if glideSpells[spell.id] then
            pself.type.activeSpells(pself):remove(spell.activeSpellId)
        end
    end
    -- remove vfx
    animation.removeVfx(pself, "glider")
    -- remove sound
    core.sound.stopSoundFile3d(sounds.wind, pself)
end

local function applyGlider()
    if not canApply() then
        return
    end

    local currentGlider = getCurrentGlider()
    if currentGlider == nil then
        settings.debugPrint("glider quest not started")
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
    applyGlideSpell(currentGlider)
    -- apply initial cost
    local cost = instantCost()
    fatigueStat.current = fatigueStat.current - cost
end

local function onHit(victimActor)
    -- victimActor is nil or a target actor that was run into.
    core.sound.playSoundFile3d(sounds.hit_wall, pself, {
        volume = settings.main.volume,
    })
    removeGlider()
    -- https://github.com/OpenMW/openmw/blob/87b266c1365696ce76fede471dd549f8184f090a/apps/openmw/mwrender/animation.cpp#L814-L828
    -- https://github.com/OpenMW/openmw/blob/87b266c1365696ce76fede471dd549f8184f090a/apps/openmw/mwmechanics/character.cpp#L219-L245

    local gliderAnim = victimActor and 'hit' .. tostring(math.random(1, 5)) or 'knockdown'

    interfaces.AnimationController.playBlendedAnimation(gliderAnim, {
        priority = animation.PRIORITY.Knockdown,
        autoDisable = true,
    })

    if victimActor then
        victimActor:sendEvent(MOD_NAME .. 'onHitByGlider', {
            glider = pself,
            victim = victimActor,
        })
        if types.NPC.objectIsInstance(victimActor) then
            core.sendGlobalEvent(MOD_NAME .. 'onHitByGlider', {
                glider = pself,
                victim = victimActor,
            })
        end
    end
end

local fatigueDebt = 0
local rayCastDelay = 0

local function onUpdate(dt)
    if dt == 0 then return end
    if not settings.main.enable then
        removeGlider()
        return
    end
    if persist.applied then
        if not canApply() then
            removeGlider()
            return
        end
        -- only remove whole units of fatigue
        fatigueDebt = fatigueDebt + (naturalFatigueRegenRate() + settings.main.fatigueCost) * dt
        if fatigueDebt > 1 then
            local whole = math.floor(fatigueDebt)
            fatigueDebt = fatigueDebt - whole
            fatigueStat.current = fatigueStat.current - whole
        end
        -- do this check less frequently
        rayCastDelay = rayCastDelay + dt
        if rayCastDelay > 0.3 then
            local touchResult = touchingWall()
            if touchResult.hit then
                local actor = nil
                if touchResult.hitObject and types.Actor.objectIsInstance(touchResult.hitObject) then
                    actor = touchResult.hitObject
                end
                onHit(actor)
                return
            end
        end
        -- track duration of glide
        persist.appliedDuration = persist.appliedDuration + dt
    else
        fatigueDebt = 0
    end
end

local function onFrame()
    if persist.applied then
        pself.controls.movement = 1
        local startingYaw = pself.controls.yawChange
        if math.abs(startingYaw) < 0.05 then
            startingYaw = 0
        end
        persist.sideMovement = util.clamp((persist.sideMovement + startingYaw * driftFactor) * driftDecay, -1, 1)
        pself.controls.sideMovement = (persist.sideMovement + persist.sideMovement) / 2
    end
end

return {
    interfaceName = MOD_NAME .. "Glider",
    interface = {
        version = 1,
        isApplied = function()
            return persist.applied
        end,
        remove = removeGlider,
        apply = applyGlider,
    },
    engineHandlers = {
        onInit = onInit,
        onLoad = onLoad,
        onSave = onSave,
        onUpdate = onUpdate,
        onFrame = onFrame
    }
}
