-- client.lua
local pingDuration = 10000
local playerRange = 30.0
local maxPingDistance = 1000.0
local is_frontend_sound_playing = false
local frontend_soundset_ref = "Study_Sounds"
local frontend_soundset_name = "show_info"

-- Store pings by player server ID
local activePings = {} -- Format: { [playerServerId] = { coords = vector3, playerName = string, expiresAt = number, ... } }

-- Debug print function
local function DebugPrint(...)
    print(string.format("[PingSystem] [%s]", GetGameTimer()), ...)
end

local function GetLookingCoords()
    local camCoords = GetGameplayCamCoord()
    local forward = GetGameplayCamRot(0)
    local forwardVector = vector3(
        -math.sin(math.rad(forward.z)) * math.abs(math.cos(math.rad(forward.x))),
        math.cos(math.rad(forward.z)) * math.abs(math.cos(math.rad(forward.x))),
        math.sin(math.rad(forward.x))
    )
    
    local endPoint = vector3(
        camCoords.x + (forwardVector.x * maxPingDistance),
        camCoords.y + (forwardVector.y * maxPingDistance),
        camCoords.z + (forwardVector.z * maxPingDistance)
    )
    
    local retval, hit, endCoords, surfaceNormal, entityHit = GetShapeTestResult(
        StartShapeTestRay(
            camCoords.x, camCoords.y, camCoords.z,
            endPoint.x, endPoint.y, endPoint.z,
            -1,
            PlayerPedId(),
            1
        )
    )
    
    if hit then
        local distance = #(camCoords - endCoords)
        if distance <= maxPingDistance then
            if entityHit > 0 then
				if GetEntityType(entityHit) == 1 or GetEntityType(entityHit) == 2 then
					local netId = nil
					if NetworkGetEntityIsNetworked(entityHit) then
						netId = NetworkGetNetworkIdFromEntity(entityHit)
						--DebugPrint("Entity hit with netId:", netId)
					else
						--DebugPrint("Entity hit but not networked")
					end
					return endCoords, netId
				end
				return endCoords, nil
			end
            --return endCoords, nil
        end
    end
    return nil, nil
end

local function RemovePing(serverId)
    if activePings[serverId] then
        SendNUIMessage({
            type = "removeIndicator",
            pingId = serverId
        })
        activePings[serverId] = nil
    end
end

RegisterNetEvent('broadcastPing')
AddEventHandler('broadcastPing', function(pingData)
    local sourceServerId = pingData.sourceServerId
    local sourcePlayer = GetPlayerFromServerId(sourceServerId)
    
    if sourcePlayer ~= -1 then
        local sourcePlayerCoords = GetEntityCoords(GetPlayerPed(sourcePlayer))
        local localPlayerCoords = GetEntityCoords(PlayerPedId())
        local distance = #(localPlayerCoords - sourcePlayerCoords)
        
        if distance <= playerRange then
            local exactExpirationTime = GetGameTimer() + pingDuration
            
            -- Track entity if network ID exists
            local trackedEntity = nil
            if pingData.networkId then
                if NetworkDoesNetworkIdExist(pingData.networkId) then
                    trackedEntity = NetworkGetEntityFromNetworkId(pingData.networkId)
                end
            end
            
            -- Update existing ping or create new one
            activePings[sourceServerId] = {
                coords = vector3(pingData.coords.x, pingData.coords.y, pingData.coords.z),
                playerName = pingData.playerName,
                expiresAt = exactExpirationTime,
                networkId = pingData.networkId,
                trackedEntity = trackedEntity
            }
            
            -- If there's already a timer for this player's ping, it will naturally exit
            -- when it checks activePings[sourceServerId].expiresAt ~= expirationTime
            Citizen.CreateThread(function()
                local pingId = sourceServerId
                local expirationTime = exactExpirationTime
                
                while GetGameTimer() < expirationTime do
                    Citizen.Wait(100)
                    -- Exit if ping was removed or updated with new expiration time
                    if not activePings[pingId] or activePings[pingId].expiresAt ~= expirationTime then
                        return
                    end
                end
                
                if activePings[pingId] and activePings[pingId].expiresAt == expirationTime then
                    RemovePing(pingId)
                end
            end)
        end
    end
end)

-- Handle ping creation
Citizen.CreateThread(function()
    while true do
        if IsControlPressed(0, 0xF84FA74F) and IsControlJustPressed(0, 0x8AAA0AD4) then
            local lookingCoords, networkId = GetLookingCoords()
            if lookingCoords then
			--DebugPrint("Creating ping at:", json.encode(lookingCoords), "NetworkId:", networkId)
				if frontend_soundset_ref ~= 0 then
					Citizen.InvokeNative(0x0F2A2175734926D8,frontend_soundset_name, frontend_soundset_ref);   -- load sound frontend
				end
				Citizen.InvokeNative(0x67C540AA08E4A6F5,frontend_soundset_name, frontend_soundset_ref, true, 0);  -- play sound frontend
				is_frontend_sound_playing = true
				
				TriggerServerEvent('createPing', {
					coords = {
						x = lookingCoords.x,
						y = lookingCoords.y,
						z = lookingCoords.z
					},
					networkId = networkId
				})
			else
				Citizen.InvokeNative(0x9D746964E0CF2C5F,frontend_soundset_name, frontend_soundset_ref)  -- stop audio
				is_frontend_sound_playing = false
			end
        end
        Citizen.Wait(0)
    end
end)

-- Display thread
Citizen.CreateThread(function()
    while true do
        local playerCoords = GetEntityCoords(PlayerPedId())
        local hasActivePings = false
        
        for serverId, pingData in pairs(activePings) do
            hasActivePings = true
            local sourcePlayer = GetPlayerFromServerId(serverId)
            
            if sourcePlayer ~= -1 then
                local sourcePlayerCoords = GetEntityCoords(GetPlayerPed(sourcePlayer))
                local distanceToPlayer = #(playerCoords - sourcePlayerCoords)
                
                if distanceToPlayer <= playerRange then
                    local displayCoords
                    
                    -- Try to get entity position if we have a network ID
                    if pingData.networkId and NetworkDoesNetworkIdExist(pingData.networkId) then
                        local entity = NetworkGetEntityFromNetworkId(pingData.networkId)
                        if DoesEntityExist(entity) then
                            displayCoords = GetEntityCoords(entity)
                            --DebugPrint("Updated coords from entity:", json.encode(displayCoords))
                        else
                            displayCoords = pingData.coords
                            --DebugPrint("Using original coords (entity not found)")
                        end
                    else
                        displayCoords = pingData.coords
                        --DebugPrint("Using original coords (no network ID)")
                    end
                    
                    local isVisible, screenX, screenY = GetScreenCoordFromWorldCoord(
                        displayCoords.x,
                        displayCoords.y,
                        displayCoords.z + 1.0
                    )
                    
                    if isVisible then
                        SendNUIMessage({
                            type = "update3DIndicator",
                            show = true,
                            x = screenX,
                            y = screenY,
                            playerName = pingData.playerName,
                            pingId = serverId
                        })
                    else
                        SendNUIMessage({
                            type = "removeIndicator",
                            pingId = serverId
                        })
                    end
                else
                    RemovePing(serverId)
                end
            else
                RemovePing(serverId)
            end
        end
        
        Citizen.Wait(hasActivePings and 0 or 250)
    end
end)