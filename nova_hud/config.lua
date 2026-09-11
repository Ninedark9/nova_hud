NovaHudConfig = {
  -- 'auto', 'nova', 'qbcore', 'esx', or 'standalone'.
    Framework = 'auto',
    Enabled = true,
    SpeedUnit = 'MPH', -- 'MPH' or 'KMH'
    UpdateInterval = 100,


    Status = {
        show = true,
        depletionEffect = true,
        lowThreshold = 25,
        criticalThreshold = 10,
        singleDepletedMoveRate = 0.88,
        doubleDepletedMoveRate = 0.78,
        shakeIntervalMs = 9000,
    },

    Minimap = {
        diameter = 0.12,
        top = 0.026,
        right = 0.014,
        zoom = 800,
        maskEdgeInsetPixels = 4.0,
    },

    Vehicle = {
        seatbeltKey = 'B',
        showFuel = true,
        showEngine = true,
        showSeatbelt = true,
    },

    HideNativeAreaNames = true,
    HideNativeCash = true,
    HideNativeWeaponWheelHelp = true,
}
