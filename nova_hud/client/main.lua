local loaded = false
local uiVisible = false
local seatbelt = false
local minimapScaleform = 0
local mapTextureReady = false
local lastResolutionX, lastResolutionY, lastSafeZone = 0, 0, 0
local mapReady, layoutApplying, refreshPending = false, false, false
local refreshGeneration = 0
local lastGeometry = nil
local textureLoading = false
local runtimeTxd, runtimeMask
local updateVisibility

local function customPauseOpen()
    return LocalPlayer and LocalPlayer.state and LocalPlayer.state.novaPauseMenu == true
end

local zoneLabels = {
    AIRP='Los Santos International Airport', ALAMO='Alamo Sea', ALTA='Alta', ARMYB='Fort Zancudo', BANHAMC='Banham Canyon', BANNING='Banning', BEACH='Vespucci Beach', BHAMCA='Banham Canyon', BRADP='Braddock Pass', BRADT='Braddock Tunnel', BURTON='Burton', CALAFB='Calafia Bridge', CANNY='Raton Canyon', CCREAK='Cassidy Creek', CHAMH='Chamberlain Hills', CHIL='Vinewood Hills', CHU='Chumash', CMSW='Chiliad Mountain State Wilderness', CYPRE='Cypress Flats', DAVIS='Davis', DELBE='Del Perro Beach', DELPE='Del Perro', DELSOL='La Puerta', DESRT='Grand Senora Desert', DOWNT='Downtown', DTVINE='Downtown Vinewood', EAST_V='East Vinewood', EBURO='El Burro Heights', ELGORL='El Gordo Lighthouse', ELYSIAN='Elysian Island', GALFISH='Galilee', GOLF='GWC and Golfing Society', GRAPES='Grapeseed', GREATC='Great Chaparral', HARMO='Harmony', HAWICK='Hawick', HORS='Vinewood Racetrack', HUMLAB='Humane Labs', JAIL='Bolingbroke Penitentiary', KOREAT='Little Seoul', LACT='Land Act Reservoir', LAGO='Lago Zancudo', LDAM='Land Act Dam', LEGSQU='Legion Square', LMESA='La Mesa', LOSPUER='La Puerta', MIRR='Mirror Park', MORN='Morningwood', MOVIE='Richards Majestic', MTCHIL='Mount Chiliad', MTGORDO='Mount Gordo', MTJOSE='Mount Josiah', MURRI='Murrieta Heights', NCHU='North Chumash', NOOSE='N.O.O.S.E.', OCEANA='Pacific Ocean', PALCOV='Paleto Cove', PALETO='Paleto Bay', PALFOR='Paleto Forest', PALHIGH='Palomino Highlands', PALMPOW='Palmer-Taylor Power Station', PBLUFF='Pacific Bluffs', PBOX='Pillbox Hill', PROCOB='Procopio Beach', RANCHO='Rancho', RGLEN='Richman Glen', RICHM='Richman', ROCKF='Rockford Hills', RTRAK='Redwood Lights Track', SANAND='San Andreas', SANCHIA='San Chianski Mountain Range', SANDY='Sandy Shores', SKID='Mission Row', SLAB='Stab City', STAD='Maze Bank Arena', STRAW='Strawberry', TATAMO='Tataviam Mountains', TERMINA='Terminal', TEXTI='Textile City', TONGVAH='Tongva Hills', TONGVAV='Tongva Valley', VCANA='Vespucci Canals', VESP='Vespucci', VINE='Vinewood', WINDF='Ron Alternates Wind Farm', WVINE='West Vinewood', ZANCUDO='Zancudo River', ZP_ORT='Port of South Los Santos', ZQ_UAR='Davis Quartz'
}

local function send(kind, data)
    SendNUIMessage({ type = kind, data = data })
end

local function clamp(v, mn, mx)
    v = tonumber(v) or mn
    if v < mn then return mn end
    if v > mx then return mx end
    return v
end

local function headingToCardinal(heading)
    local dirs = {'N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'}
    return dirs[(math.floor(((heading % 360) / 45) + 0.5) % 8) + 1]
end

local function zoneNameFromCode(code)
    if not code or code == '' then return 'Los Santos' end
    return zoneLabels[code] or code
end

local function ensureMinimapScaleform()
    if minimapScaleform == 0 or not HasScaleformMovieLoaded(minimapScaleform) then
        minimapScaleform = RequestScaleformMovie('minimap')
    end
    return minimapScaleform ~= 0 and HasScaleformMovieLoaded(minimapScaleform)
end

local function hideNativeHealthArmour()
    if not ensureMinimapScaleform() then return end
    BeginScaleformMovieMethod(minimapScaleform, 'SETUP_HEALTH_ARMOUR')
    ScaleformMovieMethodAddParamInt(3)
    EndScaleformMovieMethod()
end

local function loadCircleMapTexture()
    if mapTextureReady then return true end
    while textureLoading do Wait(0) end
    if mapTextureReady then return true end
    textureLoading = true
    RemoveReplaceTexture('platform:/textures/graphics', 'radarmasksm')
    RemoveReplaceTexture('platform:/textures/graphics', 'radarmask1g')
    runtimeTxd = CreateRuntimeTxd('nova_hud_circle')
    if runtimeTxd and runtimeTxd ~= 0 then
        runtimeMask = CreateRuntimeTexture(runtimeTxd, 'radarmasksm', 256, 256)
    end
    if not runtimeTxd or runtimeTxd == 0 or not runtimeMask or runtimeMask == 0 then
        textureLoading = false
        print('[nova_hud] Failed to create the radar mask. Use nova_hud_refresh to retry.')
        return false
    end
    for y = 0, 255 do
        for x = 0, 255 do
            local coverage = NovaMinimap.coverage(x, y, 256, NovaHudConfig.Minimap.maskEdgeInsetPixels)
            SetRuntimeTexturePixel(runtimeMask, x, y, coverage, coverage, coverage, 255)
        end
        if y % 32 == 31 then Wait(0) end
    end
    CommitRuntimeTexture(runtimeMask)
    AddReplaceTexture('platform:/textures/graphics', 'radarmasksm', 'nova_hud_circle', 'radarmasksm')
    mapTextureReady, textureLoading = true, false
    return true
end

local function getMinimapLayout()
    local screenW, screenH = GetActiveScreenResolution()
    if screenW <= 0 or screenH <= 0 then screenW, screenH = 1920, 1080 end

    ResetScriptGfxAlign()
    SetScriptGfxAlign(string.byte('L'), string.byte('T'))
    SetScriptGfxAlignParams(0.0, 0.0, 0.0, 0.0)
    local originX, originY = GetScriptGfxPosition(0.0, 0.0)
    local endX, endY = GetScriptGfxPosition(1.0, 1.0)
    ResetScriptGfxAlign()
    local scaleX, scaleY = endX - originX, endY - originY
    if scaleX <= 0 or scaleY <= 0 then return nil end
    return NovaMinimap.layout(screenW, screenH, NovaHudConfig.Minimap, originX, originY, scaleX, scaleY)
end

local function applyMinimapLayout(generation)
    if not loaded or generation ~= refreshGeneration then return false end
    layoutApplying, mapReady = true, false
    updateVisibility(true)
    DisplayRadar(false)
    if not loadCircleMapTexture() then layoutApplying = false return false end
    if not loaded or generation ~= refreshGeneration then return false end
    local g = getMinimapLayout()
    if not g then layoutApplying = false return false end

    SetMinimapClipType(1)
    SetMinimapComponentPosition('minimap', 'L', 'T', g.x, g.y, g.w, g.h)
    SetMinimapComponentPosition('minimap_mask', 'L', 'T', g.x, g.y, g.w, g.h)
    SetMinimapComponentPosition('minimap_blur', 'L', 'T', g.x, g.y, g.w, g.h)
    local northBlip = GetNorthRadarBlip()
    if northBlip and northBlip ~= 0 then SetBlipAlpha(northBlip, 0) end

    SetRadarBigmapEnabled(true, false)
    Wait(0)
    SetRadarBigmapEnabled(false, false)
    if not loaded or generation ~= refreshGeneration then return false end
    SetMinimapClipType(1)
    SetRadarZoom(NovaHudConfig.Minimap.zoom or 800)
    hideNativeHealthArmour()
    lastResolutionX, lastResolutionY, lastSafeZone = g.screenW, g.screenH, GetSafeZoneSize()
    lastGeometry = g.overlay
    send('mapGeometry', lastGeometry)
    layoutApplying, mapReady = false, true
    updateVisibility(true)
    DisplayRadar(not IsPauseMenuActive() and not customPauseOpen())
    return true
end

local function scheduleMinimapRefresh()
    if refreshPending or not loaded then return end
    refreshPending = true
    refreshGeneration = refreshGeneration + 1
    local generation = refreshGeneration
    CreateThread(function()
        Wait(350)
        if generation == refreshGeneration then
            applyMinimapLayout(generation)
            if generation == refreshGeneration then
                refreshPending, layoutApplying = false, false
            end
        end
    end)
end

updateVisibility = function(force)
    local visible = loaded and mapReady and not layoutApplying and not IsPauseMenuActive() and not customPauseOpen()
    if force or visible ~= uiVisible then
        uiVisible = visible
        send('visibility', { visible = visible })
    end
end

local function getVehicleGear(vehicle)
    if vehicle == 0 then return 'N' end
    local current = GetVehicleCurrentGear(vehicle)
    local vec = GetEntitySpeedVector(vehicle, true)
    if current <= 0 then
        if vec.y < -0.2 then return 'R' end
        return 'N'
    end
    return tostring(current)
end

local function unitMultiplier()
    return (NovaHudConfig.SpeedUnit or 'MPH') == 'KMH' and 3.6 or 2.236936
end

local function updateMapData(ped)
    local coords = GetEntityCoords(ped)
    local heading = GetGameplayCamRot(0).z
    if heading < 0 then heading = heading + 360 end
    local zoneCode = GetNameOfZone(coords.x, coords.y, coords.z)
    local zone = zoneNameFromCode(zoneCode)
    local streetHash, crossingHash = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    local street = streetHash ~= 0 and GetStreetNameFromHashKey(streetHash) or ''
    local crossing = crossingHash ~= 0 and GetStreetNameFromHashKey(crossingHash) or ''

    send('map', {
        heading = math.floor(heading + 0.5),
        cardinal = headingToCardinal(heading),
        zone = zone,
        street = street ~= '' and street or zone,
        crossing = crossing
    })
end

local function getStatusMetadata()
    if NovaHudFramework and type(NovaHudFramework.getStatus) == 'function' then
        return NovaHudFramework.getStatus()
    end
    return { hunger = 100, thirst = 100, isDead = IsEntityDead(PlayerPedId()) }
end

local function updateStatusData(ped)
    if not (NovaHudConfig.Status or {}).show then
        send('status', { show = false })
        return
    end

    local meta = getStatusMetadata()
    local nativeHealth = math.max(0, GetEntityHealth(ped) or 0)
    local maxHealth = math.max(101, GetEntityMaxHealth(ped) or 200)
    local health = 0
    if nativeHealth > 100 then
        health = ((nativeHealth - 100) / math.max(1, maxHealth - 100)) * 100
    end

    send('status', {
        show = true,
        health = math.floor(clamp(health, 0, 100) + 0.5),
        armor = math.floor(clamp(GetPedArmour(ped) or 0, 0, 100) + 0.5),
        hunger = math.floor(clamp(tonumber(meta.hunger) or 100, 0, 100) + 0.5),
        thirst = math.floor(clamp(tonumber(meta.thirst) or 100, 0, 100) + 0.5)
    })
end

local function updateVehicleData(ped)
    if not IsPedInAnyVehicle(ped, false) then
        if seatbelt then seatbelt = false end
        send('vehicle', { show = false })
        return
    end

    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or GetPedInVehicleSeat(vehicle, -1) ~= ped then
        send('vehicle', { show = false })
        return
    end

    local speed = GetEntitySpeed(vehicle) * unitMultiplier()
    local rpm = clamp(GetVehicleCurrentRpm(vehicle) or 0.0, 0.0, 1.0)
    local fuel = clamp(GetVehicleFuelLevel(vehicle) or 0.0, 0.0, 100.0)
    local engine = clamp((GetVehicleEngineHealth(vehicle) or 0.0) / 10.0, 0.0, 100.0)
    local lightsOn, highbeamsOn = GetVehicleLightsState(vehicle)
    local handbrake = GetVehicleHandbrake(vehicle)

    send('vehicle', {
        show = true,
        speed = math.floor(speed + 0.5),
        unit = NovaHudConfig.SpeedUnit or 'MPH',
        rpm = rpm,
        gear = getVehicleGear(vehicle),
        fuel = math.floor(fuel + 0.5),
        engine = math.floor(engine + 0.5),
        seatbelt = seatbelt,
        lights = lightsOn == 1 or highbeamsOn == 1,
        handbrake = handbrake and true or false
    })
end

RegisterCommand('+nova_hud_seatbelt', function()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return end
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or IsThisModelABike(GetEntityModel(vehicle)) or IsThisModelAQuadbike(GetEntityModel(vehicle)) or IsThisModelABicycle(GetEntityModel(vehicle)) then return end
    if GetPedInVehicleSeat(vehicle, -1) ~= ped then return end
    seatbelt = not seatbelt
    PlaySoundFrontend(-1, seatbelt and 'NAV_UP_DOWN' or 'NAV_LEFT_RIGHT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
end, false)
RegisterCommand('-nova_hud_seatbelt', function() end, false)
RegisterKeyMapping('+nova_hud_seatbelt', 'Toggle seatbelt', 'keyboard', NovaHudConfig.Vehicle.seatbeltKey or 'B')

CreateThread(function()
    while true do
        if loaded then
            if not IsPauseMenuActive() and not customPauseOpen() then DisplayRadar(mapReady and not layoutApplying) end
            updateVisibility(false)
            if uiVisible then
                if NovaHudConfig.HideNativeAreaNames then
                    HideHudComponentThisFrame(6)
                    HideHudComponentThisFrame(7)
                    HideHudComponentThisFrame(8)
                    HideHudComponentThisFrame(9)
                end
                if NovaHudConfig.HideNativeCash then
                    HideHudComponentThisFrame(3)
                    HideHudComponentThisFrame(4)
                    HideHudComponentThisFrame(13)
                end
                if NovaHudConfig.HideNativeWeaponWheelHelp then
                    HideHudComponentThisFrame(19)
                    HideHudComponentThisFrame(20)
                    HideHudComponentThisFrame(22)
                end
                DisplayAmmoThisFrame(false)
                DisplayRadar(mapReady and not layoutApplying)
                SetRadarZoom(NovaHudConfig.Minimap.zoom or 800)
                hideNativeHealthArmour()
            end

            if seatbelt then
                DisableControlAction(0, 75, true)
                DisableControlAction(27, 75, true)
            end
            Wait(0)
        else
            Wait(300)
        end
    end
end)

CreateThread(function()
    while true do
        local sleep = 600
        if loaded and uiVisible then
            local ped = PlayerPedId()
            if ped ~= 0 then
                sleep = NovaHudConfig.UpdateInterval or 100
                updateMapData(ped)
                updateStatusData(ped)
                updateVehicleData(ped)

                local w, h = GetActiveScreenResolution()
                if w ~= lastResolutionX or h ~= lastResolutionY or math.abs(GetSafeZoneSize() - lastSafeZone) > 0.0001 then
                    scheduleMinimapRefresh()
                end
            end
        end
        Wait(sleep)
    end
end)


CreateThread(function()
    local effectActive = false
    local nextShake = 0

    while true do
        local statusConfig = NovaHudConfig.Status or {}
        if loaded and statusConfig.depletionEffect ~= false then
            local meta = getStatusMetadata()
            local hunger = clamp(tonumber(meta.hunger) or 100, 0, 100)
            local thirst = clamp(tonumber(meta.thirst) or 100, 0, 100)
            local isDead = meta.isDead == true or IsEntityDead(PlayerPedId())
            local hungerZero = hunger <= 0.001
            local thirstZero = thirst <= 0.001

            if not isDead and (hungerZero or thirstZero) then
                local ped = PlayerPedId()
                local both = hungerZero and thirstZero
                local moveRate = both and (tonumber(statusConfig.doubleDepletedMoveRate) or 0.78)
                    or (tonumber(statusConfig.singleDepletedMoveRate) or 0.88)

                SetPedMoveRateOverride(ped, moveRate)
                SetRunSprintMultiplierForPlayer(PlayerId(), moveRate)
                SetPedMotionBlur(ped, true)
                if both then DisableControlAction(0, 21, true) end

                local now = GetGameTimer()
                if now >= nextShake then
                    ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', both and 0.11 or 0.06)
                    nextShake = now + math.max(3000, tonumber(statusConfig.shakeIntervalMs) or 9000)
                end
                effectActive = true
                Wait(0)
            else
                if effectActive then
                    SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
                    local ped = PlayerPedId()
                    if ped ~= 0 then SetPedMotionBlur(ped, false) end
                    effectActive = false
                end
                Wait(250)
            end
        else
            if effectActive then
                SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
                local ped = PlayerPedId()
                if ped ~= 0 then SetPedMotionBlur(ped, false) end
                effectActive = false
            end
            Wait(500)
        end
    end
end)

local function setFrameworkLoaded(value)
    if value then
        if loaded then return end
        loaded = true
        updateVisibility(true)
        scheduleMinimapRefresh()
        return
    end

    loaded = false
    seatbelt = false
    send('status', { show = false })
    refreshGeneration = refreshGeneration + 1
    refreshPending, layoutApplying, mapReady = false, false, false
    DisplayRadar(false)
    updateVisibility(true)
end

AddEventHandler('nova_hud:framework:loaded', function()
    setFrameworkLoaded(true)
end)

AddEventHandler('nova_hud:framework:unloaded', function()
    setFrameworkLoaded(false)
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    Wait(350)
    if NovaHudFramework then
        NovaHudFramework.detect(true)
        if NovaHudFramework.isPlayerLoaded() then
            if NovaHudFramework.getName() == 'esx' then NovaHudFramework.refreshStatus() end
            setFrameworkLoaded(true)
        end
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end

    SetRunSprintMultiplierForPlayer(PlayerId(), 1.0)
    local ped = PlayerPedId()
    if ped ~= 0 then SetPedMotionBlur(ped, false) end

    refreshGeneration = refreshGeneration + 1
    loaded, mapReady = false, false
    RemoveReplaceTexture('platform:/textures/graphics', 'radarmasksm')
    local northBlip = GetNorthRadarBlip()
    if northBlip and northBlip ~= 0 then SetBlipAlpha(northBlip, 255) end

    SetMinimapClipType(0)
    SetMinimapComponentPosition('minimap', 'L', 'B', -0.0045, 0.002, 0.150, 0.188888)
    SetMinimapComponentPosition('minimap_mask', 'L', 'B', 0.020, 0.032, 0.111, 0.159)
    SetMinimapComponentPosition('minimap_blur', 'L', 'B', -0.030, 0.022, 0.266, 0.237)
    if minimapScaleform ~= 0 then
        SetScaleformMovieAsNoLongerNeeded(minimapScaleform)
    end
end)

RegisterCommand('nova_hud_refresh', function()
    if not loaded then return end
    scheduleMinimapRefresh()
end, false)

RegisterNUICallback('ready', function(_, callback)
    callback({ ok = true })
    if lastGeometry then send('mapGeometry', lastGeometry) end
    updateVisibility(true)
end)
