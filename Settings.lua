local DMW = DMW
DMW.Rotations.DRUID = {}
local Druid = DMW.Rotations.DRUID
local UI = DMW.UI

function Druid.Settings()
    UI.AddHeader("General")
        -- Rotaion Debug
        UI.AddToggle("Rotation Debug Messages", "Show Rotation Actions", 0, true)
        -- Powershifting
        UI.AddToggle("Powershifting", "Feral DPS In-Form Shifting for Energy", 0)
        -- Prowl
        UI.AddToggle("Prowl", "Uses Prowl when near aggro range", 1)
        -- Cat Opener
        UI.AddDropdown("Cat Opener", "Select Spell to Open with", {"Pounce", "Ravage", "Shred", "Rake"}, 1)
    UI.AddHeader("Form Management")
        -- Auto-Shapeshifting
        UI.AddToggle("Auto-Shapeshifting", "Main Option for all Shapeshifting", 1, true)
        -- Aquatic Form
        UI.AddToggle("Aquatic Form", "Enable/Disable Using Aquatic Form", 1)
        -- Travel Form
        UI.AddToggle("Travel Form", "Enable/Disable Using Travel Form", 1)
        -- Last Form
        UI.AddToggle("Last Form", "Enable/Disable Using Last Form", 1)
    UI.AddHeader("Bleeds")
        -- Rake
        UI.AddToggle("Rake", "Enable/Disable Using Rake", 1)
        -- Rip
        UI.AddToggle("Rip", "Enable/Disable Using Rip", 1)
    UI.AddHeader("Buffs")
        -- Innervate
        UI.AddToggle("Self-Innervate", "Enable/Disable Using Innervate", 1)
        -- Mark of the Wild
        UI.AddToggle("Mark of the Wild", "Enable/Disable Using Mark of the Wild", 1)
        -- Omen of Clarity
        UI.AddDropdown("Omen of Clarity", "Select how to use Omen of Clarity", {"Any", "Focus DPS", "Focus Healing", "None"}, 1)
        UI.AddBlank()
        -- Thorns
        UI.AddToggle("Thorns", "Enable/Disable Using Thorns", 1)
        -- Tiger's Fury
        UI.AddToggle("Tiger's Fury", "Enable/Disable Using Tiger's Fury", 1)
    UI.AddHeader("Defensives")
        UI.AddLabel("Cures")
        -- Abolish Poison
        UI.AddToggle("Abolish Poison", "Enable/Disable Using Abolish Poison", 1)
        -- Cure Poison
        UI.AddToggle("Cure Poison", "Enable/Disable Using Cure Poison", 1)
        -- Remove Curse
        UI.AddToggle("Remove Curse", "Enable/Disable Using Remove Curse", 1)
        UI.AddBlank()
        UI.AddLabel("Heals")
        -- Self-Heal In Group
        UI.AddToggle("Self Heal In Group", "Enable/Disable Healing Self while Grouped", 0)
        UI.AddBlank()
        -- Healing Touch
        UI.AddToggle("Healing Touch", "Enable/Disable Using Healing Touch", 1)
        UI.AddRange("Healing Touch Percent", "Select HP to use at, Default: 40%", 0, 100, 5, 40)
        -- Regrowth
        UI.AddToggle("Regrowth", "Enable/Disable Using Regrowth", 1)
        UI.AddRange("Regrowth Percent", "Select HP to use at, Default: 60%", 0, 100, 5, 60)
        -- Rejuvenation
        UI.AddToggle("Rejuvenation", "Enable/Disable Using Rejuvenation", 1)
        UI.AddRange("Rejuvenation Percent", "Select HP to use at, Default: 80%", 0, 100, 5, 80)
        UI.AddLabel("Other")
        -- Barkskin
        UI.AddToggle("Barkskin", "Enable/Disable Using Barkskin", 1)
        UI.AddRange("Barkskin Percent", "Select HP to use at, Default: 50%", 0, 100, 5, 50)
        -- Entangling Roots
        UI.AddToggle("Entangling Roots", "Enable/Disable Using Entagling Roots", 1)
        -- Faerie Fire
        UI.AddToggle("Faerie Fire", "Enable/Disable Using Faerie Fire/Faerie Fire Feral", 1)
        -- Nature's Grasp
        UI.AddToggle("Nature's Grasp", "Enable/Disable Using Nature's Grasp", 1)
        UI.AddBlank()
        -- Health Potion
        UI.AddToggle("Health Potion", "Enable/Disable Using Health Potion", 1)
        -- Mana Potion
        UI.AddToggle("Mana Potion", "Enable/Disable Using Mana Potion", 1)
end