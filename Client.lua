local config = {
    ["Debug"] = false, --[[ Enable debug spheres (Ignores CheckDelay) ]]
    ["CheckDelay"] = 100, -- [[ Aim check delay (MS) ]]
    ["DisableFiring"] = false, -- [[ Disable firing instead of moving reticle (BETA) ]]
}





local function RotationToDirection(deg)
    local rad_x = deg['x'] * 0.0174532924
    local rad_z = deg['z'] * 0.0174532924

    local dir_x = -math.sin(rad_z) * math.cos(rad_x)
    local dir_y = math.cos(rad_z) * math.cos(rad_x)
    local dir_z = math.sin(rad_x)
    local dir = vector3(dir_x, dir_y, dir_z)
    return dir
end

local shapeTestFlags = 1 + 16

local function RaycastFromPlayer()
    -- Results of the raycast
    local hit = false
    local endCoords = nil
    local surfaceNormal = nil
    local entityHit = nil

    local playerPed = PlayerPedId()
    local camCoord = GetGameplayCamCoord()
    local camRot = GetGameplayCamRot(0)

    
    local rayHandle = StartExpensiveSynchronousShapeTestLosProbe(camCoord, camCoord + RotationToDirection(camRot) * 1000, shapeTestFlags, playerPed)
    local status, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)

    return hit, endCoords, surfaceNormal, entityHit
end

function convertToGfxPosition(screenX, screenY)
    -- Top left corner in gfxPosition
    local gfxTopLeftX = -0.5
    local gfxTopLeftY = -0.5

    -- Bottom right corner in gfxPosition
    local gfxBottomRightX = 0.5
    local gfxBottomRightY = 0.5

    local gfxX = gfxTopLeftX + (screenX * (gfxBottomRightX - gfxTopLeftX))
    local gfxY = gfxTopLeftY + (screenY * (gfxBottomRightY - gfxTopLeftY))
    return gfxX, gfxY
end

local overrideAimPosition = false


function fire(position)
    SetPedShootsAtCoord(PlayerPedId(), position, true)
end

--[[ Simulated Firing ]]
CreateThread(function()
    if config.DisableFiring then
        return
    end
    while true do
        Wait(0)
        
        if not overrideAimPosition then
            goto continue
        end

        if IsDisabledControlPressed(0, 24) or IsDisabledControlPressed(0, 257) then
            fire(overrideAimPosition)
        end
        ::continue::
    end
end)

--[[ Disable Firing ]]
CreateThread(function()
    while true do
        if overrideAimPosition then
            Wait(0)
            DisablePlayerFiring(PlayerId())
        else
            Wait(100)
        end
    end
end)

--[[ Aiming Check ]]
CreateThread(function()
    while true do
        Wait(config.Debug and 0 or config.CheckDelay)
        if not IsPlayerFreeAiming(PlayerId()) then
            goto continue
        end
        local ped = PlayerPedId()
        local pedCoord = GetEntityCoords(ped)
        local weapon = GetCurrentPedWeaponEntityIndex(ped)
        local boneIndex = GetEntityBoneIndexByName(weapon, "gun_muzzle")

        local muzzlePosition = GetEntityBonePosition_2(weapon, boneIndex)
        local _, reticulePosition = RaycastFromPlayer()

        local rayHandle = StartShapeTestRay(muzzlePosition, reticulePosition, shapeTestFlags, ped)
        local status, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(rayHandle)

        local distanceFromReticule = #(reticulePosition-pedCoord)
        local distanceFromHit = #(endCoords-pedCoord)
        
        if distanceFromReticule-distanceFromHit > 0.5 then
            if config.DisableFiring then
                overrideAimPosition = true
                goto continue
            end
            local retval, screenX, screenY = GetScreenCoordFromWorldCoord(endCoords.x, endCoords.y, endCoords.z)
            if retval then
                overrideAimPosition = endCoords
                local gfxX, gfxY = convertToGfxPosition(screenX, screenY)
                SetHudComponentPosition(14, gfxX, gfxY)
            end
        elseif overrideAimPosition then
            overrideAimPosition = false
            ResetHudComponentValues(14)
        end
        if config.Debug then
            DrawSphere(reticulePosition.x, reticulePosition.y, reticulePosition.z, 0.05, 0,255,0, 1.0)
            DrawSphere(endCoords.x, endCoords.y, endCoords.z, 0.08, 255,0,0, 1.0)
        end
        ::continue::
    end
end)
