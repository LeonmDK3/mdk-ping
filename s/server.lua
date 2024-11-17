-- server.lua
local activePings = {}

RegisterNetEvent('createPing')
AddEventHandler('createPing', function(pingData)
    local source = source
    local playerName = GetPlayerName(source)
    
    --print("[PingSystem] Received ping from", source, "with data:", json.encode(pingData))
    
    activePings[source] = {
        coords = pingData.coords,
        playerName = playerName,
        timeCreated = os.time(),
        networkId = pingData.networkId
    }
    
    --print("[PingSystem] Broadcasting ping to all players")
    
    TriggerClientEvent('broadcastPing', -1, {
        sourceServerId = source,
        coords = pingData.coords,
        playerName = playerName,
        networkId = pingData.networkId
    })
end)

AddEventHandler('playerDropped', function()
    local source = source
    activePings[source] = nil
end)