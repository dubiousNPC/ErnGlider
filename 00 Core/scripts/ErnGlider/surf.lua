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
local MOD_NAME               = require("scripts.ErnGlider.ns")
local core                   = require("openmw.core")
local pself                  = require("openmw.self")
local camera                 = require('openmw.camera')
local util                   = require('openmw.util')
local aux_util               = require('openmw_aux.util')
local async                  = require("openmw.async")
local types                  = require('openmw.types')
local input                  = require('openmw.input')
local controls               = require('openmw.interfaces').Controls
local nearby                 = require('openmw.nearby')
local animation              = require('openmw.animation')
local interfaces             = require("openmw.interfaces")
local ringbuffer             = require("scripts.ErnGlider.ringbuffer")
local chimtricky             = require("scripts.ErnGlider.chimtricky")
local settings               = require("scripts.ErnGlider.settings")
local blur                   = require("scripts.ErnGlider.blur")

-- initial momentum when starting surf
local startMomentum          = 0.2
-- downward slope bonus factor
local slopeDownMomentumRatio = 0.2
-- upward slope penalty factor
local slopeUpMomentumRatio   = 0.6
-- friction to decay momentum by
local friction               = 0.01
-- how much yaw change contributes to side movement drift
local driftFactor            = 3.0
-- side movement is multiplied by this each frame so it decays back to 0
local driftDecay             = 0.9
-- if momentum drops below this, we quit surfing
local kickoutMinimumMomentum = 0.15
-- prevent surfing when fatigue is at this level.
local minFatigue             = 1

local pointsPerSlideSecond   = 2
local pointsPerJump          = 1
local pointsPerAirTimeSecond = 8
local maxSpeedPointsModifier = 50

local persist                = {
    applied = false,
    appliedDuration = 0,
    momentum = startMomentum,
    activeShield = nil,
    activeShieldRecord = nil,
    landed = false,
    lastFootPos = nil,
    currentFootPos = nil,
    slope = 0,
    sideMovement = 0,
    startHeightOnCurrentJump = 0,
    maxHeightOnCurrentJump = 0,
    points = {
        slidePoints = 0,
        airPoints = 0,
        jumps = 0,
        maxSpeed = 0,
    },
}

local blurShader             = blur.NewBlurShader()

local fatigueStat            = pself.type.stats.dynamic.fatigue(pself)
local surfSpell              = "eg_surf_1"
local surfShieldWeightSpells = {
    light = {
        id = "eg_surf_light",
        effects = { 0, 1 },
        ignoreResistances = true,
        ignoreSpellAbsorption = true,
        ignoreReflect = true
    },
    medium = {
        id = "eg_surf_medium",
        effects = { 0 },
        ignoreResistances = true,
        ignoreSpellAbsorption = true,
        ignoreReflect = true
    },
    heavy = {
        id = "eg_surf_heavy",
        effects = { 0 },
        ignoreResistances = true,
        ignoreSpellAbsorption = true,
        ignoreReflect = true
    }
}

local function getSoundFilePath(file)
    return "sound\\" .. MOD_NAME .. "\\" .. file
end

local sounds         = {
    wind = getSoundFilePath("wind.mp3"),
    breath_in = getSoundFilePath("breath_in.mp3"),
    gravel_road = getSoundFilePath("gravel_road.mp3"),
    hit_wall = "Sound\\Fx\\body hit.wav",
    jump_start = "Sound\\ErnGlider\\light_smack.ogg",
    land_lt = "Sound\\Fx\\FOOT\\land_lt.wav",
    land_md = "Sound\\Fx\\FOOT\\land_md.wav",
    land_hv = "Sound\\Fx\\FOOT\\land_hv.wav"
}

local shieldBone     = "Right Foot"
local surfAnimations = {
    forward = "runforward", --"Shieldgo",
    left = "sneakleft",
    right = "sneakright"
}

local function cancelSurfAnimations()
    animation.cancel(pself, surfAnimations.forward)
    animation.cancel(pself, surfAnimations.right)
    animation.cancel(pself, surfAnimations.left)
end

local function getShield()
    if persist.activeShield then
        return persist.activeShield
    end
    local leftHand = pself.type.getEquipment(pself, types.Actor.EQUIPMENT_SLOT.CarriedLeft)
    if (not leftHand) or (not types.Armor.objectIsInstance(leftHand)) then
        persist.activeShield = nil
        persist.activeShieldRecord = nil
        return nil
    end

    if types.Armor.records[leftHand.recordId].type == types.Armor.TYPE.Shield then
        persist.activeShield = leftHand
        persist.activeShieldRecord = types.Armor.records[leftHand.recordId]
        return persist.activeShield
    end
    persist.activeShield = nil
    persist.activeShieldRecord = nil
    return nil
end

local function getSurfWeightSpell()
    local weight = persist.activeShieldRecord.weight
    -- light is 4-9, medium is 10-13, heavy is 14-45
    if weight < 10 then
        return surfShieldWeightSpells.light
    elseif weight < 14 then
        return surfShieldWeightSpells.medium
    else
        return surfShieldWeightSpells.heavy
    end
end

local function applySurfSpell()
    local shieldModel = persist.activeShieldRecord.model
    pself.type.activeSpells(pself):add({
        id = surfSpell,
        effects = { 0, 1, 2 },
        ignoreResistances = true,
        ignoreSpellAbsorption = true,
        ignoreReflect = true
    })
    pself.type.activeSpells(pself):add(getSurfWeightSpell())
    animation.addVfx(pself, shieldModel,
        { loop = true, boneName = shieldBone, vfxId = "surf", useAmbientLight = false })
end

local forward = util.vector3(0.0, 1.0, 0.0)

local function touchingWall()
    local pselfCenter = pself:getBoundingBox().center
    local facing = pself.rotation:apply(forward):normalize() * 70

    local castResult = nearby.castRay(pselfCenter, pselfCenter + util.vector3(facing.x, facing.y, 0), {
        collisionType = nearby.COLLISION_TYPE.AnyPhysical,
        ignore = pself
    })

    return castResult
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
    if data.sideMovement == nil then
        data.sideMovement = 0
    end
end
local function onSave()
    return persist
end

local function canApply()
    if types.Actor.getStance(pself) ~= types.Actor.STANCE.Nothing then
        settings.debugPrint("canApply surf: spell or weapon is readied")
        return false
    end
    local levitateEffect = types.Actor.activeEffects(pself):getEffect(core.magic.EFFECT_TYPE.Levitate)
    if (levitateEffect ~= nil) and (levitateEffect.magnitude > 0) then
        settings.debugPrint("canApply surf: levitating")
        return false
    end
    if not types.Player.getControlSwitch(pself, types.Player.CONTROL_SWITCH.Controls) then
        settings.debugPrint("canApply surf: no control")
        return false
    end
    local shield = getShield()
    if not shield then
        settings.debugPrint("canApply surf: no shield")
        return false
    end
    if types.Item.itemData(shield).condition <= 0 then
        settings.debugPrint("canApply surf: shield broken")
        return false
    end
    if fatigueStat.current <= minFatigue then
        settings.debugPrint("canApply surf: min fatigue")
        return false
    end
    return true
end

local function calcPoints(wipeout)
    local total = persist.points.slidePoints +
        persist.points.airPoints +
        persist.points.jumps * pointsPerJump +
        (persist.points.maxSpeed * persist.points.maxSpeed) * maxSpeedPointsModifier
    if wipeout then
        total = total / 2
    end
    total = (math.ceil(total) * 100)
    --print("Surf points: " .. total)
    return total
end

local currentSpeed = ringbuffer.new(20)

local function removeSurf(wipeout)
    if not persist.applied then
        return
    end
    print("Surf duration: " .. tostring(persist.appliedDuration))
    persist.applied = false
    persist.appliedDuration = 0
    persist.landed = false
    print("Removing surf...")
    -- reset movement
    persist.sideMovement = 0
    pself.controls.movement = 0
    -- todo: this will probably be bad
    pself.controls.run = false
    -- remove spell effects
    local spellsToRemove = {
        [surfSpell] = true,
        [surfShieldWeightSpells.light.id] = true,
        [surfShieldWeightSpells.medium.id] = true,
        [surfShieldWeightSpells.heavy.id] = true
    }
    --settings.debugPrint(aux_util.deepToString(spellsToRemove, 3))
    for _, spell in pairs(pself.type.activeSpells(pself)) do
        if spellsToRemove[spell.id] then
            pself.type.activeSpells(pself):remove(spell.activeSpellId)
        end
    end
    -- remove vfx
    animation.removeVfx(pself, "surf")
    -- remove sound
    core.sound.stopSoundFile3d(sounds.wind, pself)
    core.sound.stopSoundFile3d(sounds.gravel_road, pself)
    -- play ending sound
    core.sound.playSoundFile3d(sounds.land_lt, pself, {
        volume = settings.main.volume,
        loop = false,
    })

    -- stop surf anims now
    cancelSurfAnimations()

    -- ending animation
    interfaces.AnimationController.playBlendedAnimation('jump', {
        priority = animation.PRIORITY.Jump,
        blendMask = animation.BLEND_MASK.LowerBody,
        autoDisable = true,
    })
    blurShader:setEnabled(false)

    calcPoints(wipeout)

    chimtricky.display(nil)
end

local function getFootPos()
    local box = pself:getBoundingBox()
    return box.center + util.vector3(0, 0, -box.halfSize.z)
end

local function applySurf()
    if not canApply() then
        return
    end

    persist.activeShield = nil
    persist.applied = true
    persist.momentum = startMomentum
    persist.landed = false

    persist.lastFootPos = getFootPos()
    persist.currentFootPos = getFootPos()
    persist.slope = 0
    persist.startHeightOnCurrentJump = persist.lastFootPos.z
    persist.maxHeightOnCurrentJump = persist.lastFootPos.z

    -- set up next run
    persist.points = {
        slidePoints = 0,
        airPoints = 0,
        jumps = 0,
        maxSpeed = 0,
    }

    print("Applying surf...")
    -- set movement on this frame
    pself.controls.movement = 1
    pself.controls.run = true
    pself.controls.sideMovement = 0
    -- apply sound
    core.sound.playSoundFile3d(sounds.wind, pself, {
        volume = settings.main.volume * 0.3,
        loop = true,
    })
    core.sound.playSoundFile3d(sounds.breath_in, pself, {
        volume = settings.main.volume,
    })
    -- apply spell
    applySurfSpell()

    blurShader:setEnabled(true)

    -- todo: unequip then re-equip shield?
    -- maybe just override the shield vfx for sheath mod somehow?
end

local function onHit(victimActor)
    -- victimActor is nil or a target actor that was run into.
    core.sound.playSoundFile3d(sounds.hit_wall, pself, {
        volume = settings.main.volume,
    })
    settings.debugPrint("hit something")
    removeSurf(true)
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

local function slideSound()
    if types.Actor.isOnGround(pself) then
        -- restart sound if not playing
        if not core.sound.isSoundFilePlaying(sounds.gravel_road, pself) then
            local vol = settings.main.volume * persist.momentum * .7
            --settings.debugPrint("gravel sound volume: " .. tostring(vol))
            core.sound.playSoundFile3d(sounds.gravel_road, pself, {
                volume = vol,
                loop = false,
            })
        end
    else
        -- ensure off if in air
        core.sound.stopSoundFile3d(sounds.gravel_road, pself)
    end
end

local armsAnimationOptions = {
    priority = animation.PRIORITY.Storm,
    --blendMask = util.bitOr(animation.BLEND_MASK.LeftArm, animation.BLEND_MASK.RightArm),
    blendMask = animation.BLEND_MASK.UpperBody,
    loops = -1,
    speed = 1,
}
local fullAnimationOptions = {
    priority = animation.PRIORITY.Storm,
    --blendMask = util.bitOr(animation.BLEND_MASK.LeftArm, animation.BLEND_MASK.RightArm),
    --blendMask = animation.BLEND_MASK.UpperBody,
    loops = -1,
    speed = 1,
}
local function animate()
    if not types.Actor.isOnGround(pself) then
        -- cancel these anims, which should let Jump animation take precedence
        cancelSurfAnimations()
        return
    end

    if (pself.controls.sideMovement <= -1 * settings.main.deadzone) and not animation.isPlaying(pself, surfAnimations.left) then
        animation.cancel(pself, surfAnimations.right)
        if not animation.isPlaying(pself, surfAnimations.left) then
            settings.debugPrint("anim start left - " .. surfAnimations.left)
            animation.playBlended(pself, surfAnimations.left, armsAnimationOptions)
        end
    elseif (pself.controls.sideMovement >= settings.main.deadzone) and not animation.isPlaying(pself, surfAnimations.right) then
        animation.cancel(pself, surfAnimations.left)
        if not animation.isPlaying(pself, surfAnimations.right) then
            settings.debugPrint("anim start right - " .. surfAnimations.right)
            animation.playBlended(pself, surfAnimations.right, armsAnimationOptions)
        end
    elseif (math.abs(pself.controls.sideMovement) < settings.main.deadzone) then
        animation.cancel(pself, surfAnimations.left)
        animation.cancel(pself, surfAnimations.right)
        if not animation.isPlaying(pself, surfAnimations.forward) then
            settings.debugPrint("anim start forward - " .. surfAnimations.forward)
            animation.playBlended(pself, surfAnimations.forward, fullAnimationOptions)
        end
    end
end

local function onJump()
    -- we're doing an intentional jump
    settings.debugPrint("intentional jump")
    if not types.Actor.isOnGround(pself) then
        removeSurf()
        return
    end
    persist.points.jumps = persist.points.jumps + 1
end

local conditionDebt = 0
local rayCastDelay = 0

local function onUpdate(dt)
    if dt == 0 then return end
    if persist.applied then
        if not settings.surf.enable then
            removeSurf()
            return
        end
        if not canApply() then
            removeSurf()
            return
        end
        -- did we hit the ground too hard?
        if animation.isPlaying(pself, "knockdown") then
            settings.debugPrint("fell from too high!")
            removeSurf()
        end

        local justLanded = false
        local justJumped = false
        if types.Actor.isOnGround(pself) then
            if not persist.landed then
                justLanded = true
            end
            persist.landed = true
        else
            if persist.landed then
                justJumped = true
            end
            persist.landed = false
        end

        if justJumped then
            persist.startHeightOnCurrentJump = getFootPos().z
            persist.maxHeightOnCurrentJump = persist.startHeightOnCurrentJump
            core.sound.playSoundFile3d(sounds.jump_start, pself, {
                volume = settings.main.volume,
                loop = false,
            })
        end

        -- track landing
        if justLanded then
            persist.landed = true
            settings.debugPrint("Landed!")
            local dropHeight = (persist.maxHeightOnCurrentJump - persist.currentFootPos.z)
            local acrobatics = pself.type.stats.skills.acrobatics(pself).modified
            local weight = persist.activeShieldRecord.weight
            -- heavy shields take more damage on drops because they generally have
            -- more total Condition, and also Slowfall.
            local safeHeight = pself:getBoundingBox().halfSize.z * util.remap(acrobatics, 0, 100, 0.25, 4) *
                math.max(0.1, 1 - (weight / 50))
            if dropHeight > 0 and dropHeight > safeHeight then
                local damage = math.ceil(math.sqrt((dropHeight - safeHeight)) * settings.surf.fallCost)
                conditionDebt = conditionDebt + damage
                settings.debugPrint("Big drop! Height: " .. tostring(dropHeight) .. ", damage: " .. tostring(damage))
                -- play hard landing sound
                core.sound.playSoundFile3d(sounds.land_hv, pself, {
                    volume = settings.main.volume,
                    loop = false,
                })
            else
                settings.debugPrint("Small drop of height " .. tostring(dropHeight))
                -- play softer landing sound
                core.sound.playSoundFile3d(sounds.land_md, pself, {
                    volume = settings.main.volume,
                    loop = false,
                })
            end
            animation.addVfx(pself, "meshes/ernglider/poof.nif",
                { loop = false, boneName = shieldBone, vfxId = "poof", useAmbientLight = false })
        elseif not persist.landed then
            -- in air
            persist.maxHeightOnCurrentJump = math.max(persist.maxHeightOnCurrentJump, persist.currentFootPos.z)
        end

        -- update gravel sound
        slideSound()
        -- handle animations
        animate()

        -- roll over foot positions
        persist.lastFootPos = persist.currentFootPos
        persist.currentFootPos = getFootPos()

        local xyDist = util.vector2(persist.lastFootPos.x - persist.currentFootPos.x,
            persist.lastFootPos.y - persist.currentFootPos.y):length()
        persist.slope = (persist.currentFootPos.z - persist.lastFootPos.z) / xyDist

        -- game unit / second to km / hour factor is 0.05112
        currentSpeed:push(xyDist / dt * 0.05112)

        -- only remove whole units of condition
        conditionDebt = conditionDebt + (settings.surf.conditionCost * dt)
        if conditionDebt > 1 then
            local whole = math.floor(conditionDebt)
            conditionDebt = math.max(0, conditionDebt - whole)
            core.sendGlobalEvent(MOD_NAME .. 'onDamageItem', {
                item = getShield(),
                amount = whole,
            })
        end
        -- do this check less frequently
        rayCastDelay = rayCastDelay + dt
        if rayCastDelay > 0.3 then
            --[[settings.debugPrint("momentum: " ..
                string.format("%.2f", persist.momentum) ..
                ", slope: " ..
                string.format("%.2f", persist.slope) .. ", side:" .. string.format("%.2f", persist.sideMovement))]]
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
        -- track duration of surf
        persist.appliedDuration = persist.appliedDuration + dt
        local avgSpeed = currentSpeed:getAverage()
        blurShader:update(util.clamp(util.remap(avgSpeed, 15, 200, 0, 1), 0, 0.005))

        chimtricky.display({
            dt = dt,
            speed = avgSpeed,
            conditionRatio = types.Item.itemData(getShield()).condition / persist.activeShieldRecord.health,
            fatigueRatio = fatigueStat.current / fatigueStat.base,
            points = calcPoints(false),
        })
    else
        -- not currently surfing
        conditionDebt = 0
    end
end

local function quadraticEaseOut(x)
    return 1 - (1 - x) * (1 - x)
end

local function slopeMomentumFactor(slope)
    slope = util.clamp(slope, -1, 1)
    if slope > 0 then
        -- quadratic ease-in when going uphill
        return slopeUpMomentumRatio * slope * slope
    else
        -- quadratic ease-out when going downhill
        return slopeDownMomentumRatio * quadraticEaseOut(slope)
    end
end

local function onFrame(dt)
    if persist.applied then
        -- only adjust momenum while on ground
        if persist.landed then
            persist.momentum = util.clamp(persist.momentum - (friction + slopeMomentumFactor(persist.slope)) * dt,
                0,
                1)
            if persist.landed and (persist.momentum <= kickoutMinimumMomentum) then
                settings.debugPrint("out of momentum")
                removeSurf()
                return
            end
            if persist.momentum > 0.3 then
                persist.points.slidePoints = persist.points.slidePoints + pointsPerSlideSecond * dt * persist.momentum
            end
        else
            if persist.momentum > 0.2 then
                persist.points.airPoints = persist.points.airPoints + pointsPerAirTimeSecond * dt * persist.momentum
            end
        end

        -- Don't give direct control over strafing.
        -- If the camera swings too much, automatically mix in strafing.
        local startingYaw = pself.controls.yawChange
        if math.abs(startingYaw) < 0.05 then
            startingYaw = 0
        end
        persist.sideMovement = util.clamp((persist.sideMovement + startingYaw * driftFactor) * driftDecay, -1, 1)
        --settings.debugPrint("sidemovement: " .. tostring(persist.sideMovement))
        pself.controls.sideMovement = persist.sideMovement
        pself.controls.movement = util.clamp(persist.momentum - math.abs(persist.sideMovement), 0, 1)
        pself.controls.run = true
    end
end

return {
    interfaceName = MOD_NAME .. "Surf",
    interface = {
        version = 1,
        isApplied = function()
            return persist.applied
        end,
        remove = removeSurf,
        jump = onJump,
        apply = applySurf,
    },
    engineHandlers = {
        onInit = onInit,
        onLoad = onLoad,
        onSave = onSave,
        onUpdate = onUpdate,
        onFrame = onFrame
    }
}
