local DMW = DMW
DMW.Rotations.DRUID = {}
local Druid = DMW.Rotations.DRUID
local UI = DMW.UI

function Druid.Settings()
    UI.AddHeader("General")
        -- Auto-Shapeshifting
        UI.AddToggle("Auto-Shapeshifting", nil, 1)
        -- Powershifting
        UI.AddToggle("Powershifting", nil, 0)
        -- Cat Opener
        UI.AddDropdown("Cat Opener", nil, {"Pounce", "Ravage", "Shred", "Rake"}, 1)
    UI.AddHeader("Bleeds")
        -- Rake
        UI.AddToggle("Rake", nil, 1)
        -- Rip
        UI.AddToggle("Rip", nil, 1)
    UI.AddHeader("Buffs")
        -- Mark of the Wild
        UI.AddToggle("Mark of the Wild", nil, 1)
        -- Prowl
        UI.AddToggle("Prowl", nil, 1)
        -- Thorns
        UI.AddToggle("Thorns", nil, 1)
        -- Tiger's Fury
        UI.AddToggle("Tiger's Fury", nil, 1)
    UI.AddHeader("Defensives")
        -- Abolish Poison
        UI.AddToggle("Abolish Poison", nil, 1)
        -- Cure Poison
        UI.AddToggle("Cure Poison", nil, 1)
        -- Entangling Roots
        UI.AddToggle("Entangling Roots", nil, 1)
        -- Faerie Fire
        UI.AddToggle("Faerie Fire", nil, 1)
        -- Healing Touch
        UI.AddToggle("Healing Touch", nil, 1)
        UI.AddRange("Healing Touch Percent", nil, 0, 100, 5, 40)
        -- Nature's Grasp
        UI.AddToggle("Nature's Grasp", nil, 1)
        UI.AddBlank()
        -- Regrowth
        UI.AddToggle("Regrowth", nil, 1)
        UI.AddRange("Regrowth Percent", nil, 0, 100, 5, 60)
        -- Rejuvenation
        UI.AddToggle("Rejuvenation", nil, 1)
        UI.AddRange("Rejuvenation Percent", nil, 0, 100, 5, 80)
end