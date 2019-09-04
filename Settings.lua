local DMW = DMW
DMW.Rotations.DRUID = {}
local Druid = DMW.Rotations.DRUID
local UI = DMW.UI

function Druid.Settings()
    UI.AddHeader("General")
    -- Auto-Shapeshifting
    UI.AddToggle("Auto-Shapeshifting", nil, 1)
    UI.AddHeader("DPS")
    UI.AddHeader("Defensives")
    -- Entangling Roots
    UI.AddToggle("Entangling Roots", nil, 1)
    -- Healing Touch
    UI.AddToggle("Healing Touch", nil, 1)
    UI.AddRange("Healing Touch Percent", nil, 0, 100, 5, 50)
    -- Mark of the Wild
    UI.AddToggle("Mark of the Wild", nil, 1)
    -- Nature's Grasp
    UI.AddToggle("Nature's Grasp", nil, 1)
    -- Regrowth
    UI.AddToggle("Regrowth", nil, 1)
    UI.AddRange("Regrowth Percent", nil, 0, 100, 5, 30)
    -- Rejuvenation
    UI.AddToggle("Rejuvenation", nil, 1)
    UI.AddRange("Rejuvenation Percent", nil, 0, 100, 5, 80)
    -- Thorns
    UI.AddToggle("Thorns", nil, 1)
end