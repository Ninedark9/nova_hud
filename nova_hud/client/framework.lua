NovaHudFramework = NovaHudFramework or {}

local Config = NovaHudConfig or {}
local activeFramework = nil
local core = nil
local esxStatus = { hunger = 100, thirst = 100 }
local lastAnnounced = nil

local aliases = {
    ['auto'] = 'auto',
    ['nova'] = 'nova',
    ['nova_core'] = 'nova',
    ['qb'] = 'qbcore',
    ['qbcore'] = 'qbcore',
    ['qb-core'] = 'qbcore',
    ['esx'] = 'esx',
    ['es_extended'] = 'esx',
    ['standalone'] = 'standalone',
    ['none'] = 'standalone',
}

local frameworkResources = {
    nova = 'nova_core',
    qbcore = 'qb-core',
    esx = 'es_extended',
}

local function resourceStarted(name)
    return name and GetResourceState(name) == 'started'
end

local function configuredFramework()
    local value = tostring(Config.Framework or 'auto'):lower():gsub('%s+', '')
    return aliases[value] or 'auto'
end

local function fetchCore(framework)
    if framework == 'nova' then
        local ok, value = pcall(function() return exports['nova_core']:GetCoreObject() end)
        return ok and type(value) == 'table' and value or nil
    end
    if framework == 'qbcore' then
        local ok, value = pcall(function() return exports['qb-core']:GetCoreObject() end)
        return ok and type(value) == 'table' and value or nil
    end
    if framework == 'esx' then
        local ok, value = pcall(function() return exports['es_extended']:getSharedObject() end)
        return ok and type(value) == 'table' and value or nil
    end
    return nil
end

function NovaHudFramework.detect(force)
    local requested = configuredFramework()
    local detected = requested

    if requested == 'auto' then
        if resourceStarted('nova_core') then
            detected = 'nova'
        elseif resourceStarted('qb-core') then
            detected = 'qbcore'
        elseif resourceStarted('es_extended') then
            detected = 'esx'
        else
            detected = 'standalone'
        end
    end

    if force or detected ~= activeFramework then
        activeFramework = detected
        core = fetchCore(detected)
        if detected == 'esx' then
            esxStatus.hunger, esxStatus.thirst = 100, 100
        end
    elseif not core and detected ~= 'standalone' then
        core = fetchCore(detected)
    end

    if lastAnnounced ~= activeFramework then
        lastAnnounced = activeFramework
        print(('[NOVA HUD] Framework: %s'):format(activeFramework))
    end

    return activeFramework
end

function NovaHudFramework.getName()
    return NovaHudFramework.detect(false)
end

function NovaHudFramework.isFrameworkResource(name)
    for _, resource in pairs(frameworkResources) do
        if name == resource then return true end
    end
    return false
end

local function qbPlayerData()
    if not resourceStarted('qb-core') then return nil end
    local ok, data = pcall(function() return exports['qb-core']:GetPlayerData() end)
    if ok and type(data) == 'table' then return data end

    NovaHudFramework.detect(false)
    if core and core.Functions and type(core.Functions.GetPlayerData) == 'function' then
        local okCore, coreData = pcall(core.Functions.GetPlayerData)
        if okCore and type(coreData) == 'table' then return coreData end
    end
    return nil
end

local function esxPlayerData()
    NovaHudFramework.detect(false)
    if not core then return nil end
    if type(core.GetPlayerData) == 'function' then
        local ok, data = pcall(core.GetPlayerData)
        if ok and type(data) == 'table' then return data end
    end
    return type(core.PlayerData) == 'table' and core.PlayerData or nil
end

local function refreshEsxStatus(name)
    if not resourceStarted('esx_status') then return end
    TriggerEvent('esx_status:getStatus', name, function(status)
        if type(status) ~= 'table' then return end
        local percent = tonumber(status.percent)
        if percent == nil and tonumber(status.val) and tonumber(status.max) and tonumber(status.max) > 0 then
            percent = (tonumber(status.val) / tonumber(status.max)) * 100.0
        end
        if percent ~= nil then esxStatus[name] = math.max(0, math.min(100, percent)) end
    end)
end

function NovaHudFramework.refreshStatus()
    if NovaHudFramework.detect(false) ~= 'esx' then return end
    refreshEsxStatus('hunger')
    refreshEsxStatus('thirst')
end

function NovaHudFramework.isPlayerLoaded()
    local framework = NovaHudFramework.detect(false)
    if framework == 'nova' then
        return LocalPlayer and LocalPlayer.state and LocalPlayer.state['nova:loaded'] == true
    end
    if framework == 'qbcore' then
        if LocalPlayer and LocalPlayer.state and LocalPlayer.state.isLoggedIn ~= nil then
            return LocalPlayer.state.isLoggedIn == true
        end
        local data = qbPlayerData()
        return type(data) == 'table' and data.citizenid ~= nil
    end
    if framework == 'esx' then
        if core and type(core.IsPlayerLoaded) == 'function' then
            local ok, value = pcall(core.IsPlayerLoaded)
            if ok then return value == true end
        end
        return core and core.PlayerLoaded == true or false
    end
    return NetworkIsPlayerActive(PlayerId())
end

function NovaHudFramework.getStatus()
    local framework = NovaHudFramework.detect(false)

    if framework == 'nova' then
        local state = LocalPlayer and LocalPlayer.state
        local meta = state and state['nova:metadata'] or nil
        meta = type(meta) == 'table' and meta or {}
        return {
            hunger = tonumber(meta.hunger) or 100,
            thirst = tonumber(meta.thirst) or 100,
            isDead = meta.isDead == true or (state and state['nova:isDead'] == true) or IsEntityDead(PlayerPedId()),
        }
    end

    if framework == 'qbcore' then
        local data = qbPlayerData() or {}
        local meta = type(data.metadata) == 'table' and data.metadata or {}
        return {
            hunger = tonumber(meta.hunger) or 100,
            thirst = tonumber(meta.thirst) or 100,
            isDead = meta.isdead == true or meta.isDead == true or meta.inlaststand == true or IsEntityDead(PlayerPedId()),
        }
    end

    if framework == 'esx' then
        local data = esxPlayerData() or {}
        local metadata = type(data.metadata) == 'table' and data.metadata or {}
        return {
            hunger = tonumber(esxStatus.hunger) or 100,
            thirst = tonumber(esxStatus.thirst) or 100,
            isDead = data.dead == true or metadata.dead == true or metadata.isDead == true or IsEntityDead(PlayerPedId()),
        }
    end

    return { hunger = 100, thirst = 100, isDead = IsEntityDead(PlayerPedId()) }
end

local function emitLoaded(framework)
    if NovaHudFramework.detect(false) ~= framework then return end
    if framework == 'esx' then NovaHudFramework.refreshStatus() end
    TriggerEvent('nova_hud:framework:loaded', framework)
end

local function emitUnloaded(framework)
    if NovaHudFramework.detect(false) ~= framework then return end
    TriggerEvent('nova_hud:framework:unloaded', framework)
end

RegisterNetEvent('nova:client:OnPlayerLoaded', function() emitLoaded('nova') end)
RegisterNetEvent('nova:client:OnPlayerUnload', function() emitUnloaded('nova') end)
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function() emitLoaded('qbcore') end)
RegisterNetEvent('QBCore:Client:OnPlayerUnload', function() emitUnloaded('qbcore') end)
RegisterNetEvent('esx:playerLoaded', function()
    Wait(0)
    emitLoaded('esx')
end)
RegisterNetEvent('esx:onPlayerLogout', function() emitUnloaded('esx') end)

AddEventHandler('esx_status:onTick', function(data)
    if NovaHudFramework.detect(false) ~= 'esx' or type(data) ~= 'table' then return end
    for i = 1, #data do
        local status = data[i]
        if type(status) == 'table' and (status.name == 'hunger' or status.name == 'thirst') then
            local percent = tonumber(status.percent)
            if percent ~= nil then esxStatus[status.name] = math.max(0, math.min(100, percent)) end
        end
    end
end)

AddEventHandler('onClientResourceStart', function(name)
    if not NovaHudFramework.isFrameworkResource(name) and name ~= 'esx_status' then return end
    CreateThread(function()
        Wait(250)
        NovaHudFramework.detect(true)
        if NovaHudFramework.isPlayerLoaded() then
            if NovaHudFramework.getName() == 'esx' then NovaHudFramework.refreshStatus() end
            TriggerEvent('nova_hud:framework:loaded', NovaHudFramework.getName())
        end
    end)
end)
