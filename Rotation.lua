local DMW = DMW
local Druid = DMW.Rotations.DRUID
local Player, Buff, Debuff, Health, HP, Power, Spell, Target, Talent, Item, GCD, GCDRemain, CDs, HUD, Player40Y, Player40YC, Friends40Y, Friends40YC
local Rotation = DMW.Helpers.Rotation
local Setting = DMW.Helpers.Rotation.Setting
local LastForm
local LastFormBuff = false
local Shapeshifted
local ComboPoints
local Mana
local Energy
local Enemies40Y, Enemies40YC
local Attackable40Y, Attackable40YC
local Enemies5Y, Enemies5YC
local Unit5F
local LastHeal
local Opener
local TickTime = DMW.Player.TickTime or GetTime()
local TickTimeRemain = TickTime - GetTime()
local noShapeshiftPower
local NeedsHealing
local freeDPS
local freeHeal
local LowestHealthOption
local CurrentSpell
local GenderTable = {"It", "Him", "Her"}
local Gender = "None"

local function Locals()
    Player = DMW.Player
    Buff = Player.Buffs
    Debuff = Player.Debuffs
    Health = Player.Health
    HP = (Player.Health / Player.HealthMax) * 100
    Power = Player.Power
    Spell = Player.Spells
    Talent = Player.Talents
    Item = Player.Items
    Target = Player.Target or false
    GCD = Player:GCD()
    GCDRemain = Player:GCDRemain() --Spell.Shred:CD()
    HUD = DMW.Settings.profile.HUD
    CDs = Player:CDs() and Target and Target.TTD > 5 and Target.Distance < 5
    Friends40Y, Friends40YC = Player:GetFriends(40)
    Enemies40Y, Enemies40YC = Player:GetEnemies(40)
    Attackable40Y, Attackable40YC = Player:GetAttackable(40)
    Enemies5Y, Enemies5YC = Player:GetEnemies(5)
    Unit5F = Player:GetEnemy(5,true) or Target
    ComboPoints = GetComboPoints("player","target")
    Shapeshifted = Buff.DireBearForm:Exist(Player) or Buff.BearForm:Exist(Player) or Buff.CatForm:Exist(Player)
    or Buff.MoonkinForm:Exist(Player) or Buff.TravelForm:Exist(Player) or Buff.AquaticForm:Exist(Player)
    Mana = UnitPower("player",0)
    Energy = UnitPower("player",3)
    if Buff.DireBearForm:Exist(Player) then LastForm = Spell.DireBearForm end
    if Buff.BearForm:Exist(Player) then LastForm = Spell.BearForm end
    if Buff.CatForm:Exist(Player) then LastForm = Spell.CatForm end
    if Buff.MoonkinForm:Exist(Player) then LastForm = Spell.MoonkinForm end
    LastFormBuff = false
    if Buff.DireBearForm:Exist(Player) or Buff.BearForm:Exist(Player)
    or Buff.CatForm:Exist(Player) or Buff.MoonkinForm:Exist(Player)
    then
        LastFormBuff = true
    end
    if Player.Level >= 10 and Spell.BearForm:Known() then
        if not Spell.DireBearForm:Known() then LastForm = Spell.BearForm else LastForm = Spell.DireBearForm end
    end
    if Player.Level >= 20 and Spell.CatForm:Known() then LastForm = Spell.CatForm end
    if LastHeal == nil then LastHeal = GetTime() end
    Opener = Setting("Cat Opener")
    TickTime = DMW.Player.TickTime or GetTime() + 0.05
    TickTimeRemain = TickTime - GetTime()
    noShapeshiftPower = ((not Buff.CatForm:Exist(Player) or (Buff.CatForm:Exist(Player) and Power < 30))
    and (not Buff.BearForm:Exist(Player) or (Buff.BearForm:Exist(Player) and Power < 10))) or not Player.Combat
    NeedsHealing = (Setting("Regrowth") and HP <= Setting("Regrowth Percent"))
    or (Setting("Healing Touch") and HP <= Setting("Healing Touch Percent"))
    freeDPS = Setting("Omen of Clarity") ~= 4 and Setting("Omen of Clarity") ~= 2 and Buff.Clearcasting:Exist(Player)
    and (not NeedsHealing or Setting("Omen of Clarity") == 3)
    freeHeal = Setting("Omen of Clarity") ~= 4 and Setting("Omen of Clarity") ~= 3 and Buff.Clearcasting:Exist(Player)
    and (LastForm == nil or Mana >= LastForm:Cost())
    Item.HealthPotion = Player:GetPotion("health")
    Item.ManaPotion = Player:GetPotion("mana")
    Item.RejuvPotion = Player:GetPotion("rejuv")
    LowestHealthOption = (Setting("Healing Touch") and Setting("Healing Touch Percent"))
                            or (Setting("Regrowth") and Setting("Regrowth Percent"))
                            or (Setting("Rejuvenation") and Setting("Rejuvenation Percent"))
                            or 25
    CurrentSpell = Player:CurrentCast()
    if Target then Gender = GenderTable[UnitSex("target")] end
end

local function debug(message)
    if Setting("Rotation Debug Messages") then
        print(tostring(message))
    end
end

local function IsReadyShapeshifted(Spell)
    return (Spell:IsReady() or (Shapeshifted and Spell:Known() and GCDRemain == 0))
end

local function CancelForm()
    if Setting("Auto-Shapeshifting") and Shapeshifted and GetShapeshiftForm() ~= 0
        and GCDRemain == 0 and (DMW.Player.SwingMH > 0.25 or not Player.Combat)
    then
        CancelShapeshiftForm()
        return true
    elseif not Shapeshifted then
        return false
    end
end

local function ShapeshiftCost(castSpell,bufferSpell)
    if type(castSpell) == "number" then castSpell = DMW.Helpers.Rotation.GetSpellByID(castSpell) end
    if Setting("Auto-Shapeshifting") then
        -- Get Shapeshift Spell
        if Player.Level < 10 or not (Spell.DireBearForm:Known() or Spell.BearForm:Known()
            or Spell.CatForm:Known() or Spell.MoonkinForm:Known()
            or Spell.TravelForm:Known() or Spell.AquaticForm:Known())
        then
            return 0
        end
        local shapeID = GetShapeshiftForm() or 0
        local shapeSpell
        if shapeID > 0 then
            shapeSpell = DMW.Helpers.Rotation.GetSpellByID(select(4,GetShapeshiftFormInfo(shapeID)))
        else
            shapeSpell = LastForm
            if shapeSpell == nil then shapeSpell = Spell.CatForm end
        end
        -- Check for Buffer Spell and Get Cost
        local bufferCost = 0
        if bufferSpell ~= nil then bufferCost = bufferSpell:Cost() end
        -- Get Current Casting Spell Cost
        local currentSpellCost = not CurrentSpell and 0 or CurrentSpell:Cost()
        -- Add up shapeshift cost, desire spell cast cost, and current casting spell cost
        return shapeSpell:Cost() + castSpell:Cost() + currentSpellCost + bufferCost
    end
    return 0
end

local function Powershift()
    if GCDRemain == 0 and DMW.Player.SwingMH > 0.25
        and TickTimeRemain > 0.25
    then
        for i=1, GetNumShapeshiftForms() do
            _, name, active = GetShapeshiftFormInfo(i);
            if( name and active ) then
                CancelShapeshiftForm()
                debug("Cancel Form [Powershift]")
                CastShapeshiftForm(i)
                return true
            end
        end
    end
    return false
end

local function FerociousBiteFinish(thisUnit)
    if not Spell.FerociousBite:Known() then return false end
    local base, posBuff, negBuff = UnitAttackPower("player")
    local AP = base + posBuff + negBuff
    local hasFeralAgg = Talent.FeralAggression.Rank == 5 and 1.15 or 1
    local hasNaturalWeap = Talent.NaturalWeapons.Rank == 5 and 1.1 or 1
    local HighestRank = Spell.FerociousBite:HighestRank()
    local desc = GetSpellDescription(Spell.FerociousBite.Ranks[HighestRank])
    local damage = 0
    local finishHim = false
    local unitHealth = tonumber(thisUnit.Health) or 0
    local unitHealthMax = tonumber(thisUnit.HealthMax) or 100
    local calc = 0
    local comboStart, damageList, comboEnd = "", "", ""

    if thisUnit and Spell.FerociousBite:Known() and ComboPoints > 0
        and unitHealthMax > 100
    then
        -- Find damage line for current combo points
        comboStart = desc:find(" "..ComboPoints.." point",1,true)
        if comboStart ~= nil then
            -- Adjust to "point" in line
            comboStart = comboStart + 2
            -- Set to damageList from "ppint" to rest of tooltip
            damageList = desc:sub(comboStart,desc:len())
            -- Adjust to damage value in line
            comboStart = damageList:find(": ",1,true)+2
            -- Adjust damageList to contain damage value and rest of tooltip
            damageList = damageList:sub(comboStart,desc:len())
            -- Adjust to "-" in line
            comboEnd = damageList:find("-",1,true)-1
            -- Adjust damageList removing everything after the damageValue
            damageList = damageList:sub(1,comboEnd)
            -- Remove any commas
            damage = damageList:gsub(",","")
        end
        damage = tonumber(damage)
        -- Thanks to Rebecca from DR, Classic doesn't adjust tooltip like BfA, dmg calc from: https://nostalrius.org/viewtopic.php?f=41&t=27786
        calc = ((AP * 0.1526 + (Power - 35) * 2.5 + damage) * hasFeralAgg) * hasNaturalWeap
        -- print("FB Finish - Tooltip: "..damage..", Calc: "..calc.." | Health: "..unitHealth)
        damage = calc
        finishHim = damage >= unitHealth
    end
    return finishHim
end

local function IsAutoAttacking()
    for i = 1,72 do
        if IsAttackAction(i) then return IsCurrentAction(i) end
    end
    return false
end

local function GetNewTarget(Range,Facing)
    local TargetUnit = _G["TargetUnit"]
    local _, EnemiesC = Player:GetEnemies(Range)
    Facing = Facing or false
    if Player.Combat and EnemiesC > 0 and (not Player.Target or Target.Dead or Target.Distance > Range) then
        for _, Unit in ipairs(DMW.Enemies) do
            if Unit.Distance <= Range and (not Facing or Unit.Facing) then
                debug("Targeting New Enemy")
                TargetUnit(Unit.Pointer)
                DMW.Player.Target = Unit
                return true
            end
        end
    end
    return false
end

local function InAggroRange(offset)
    local offset = offset or 0
    for _, Unit in ipairs(Attackable40Y) do
        local threatRange = max((20 + (Unit.Level - Player.Level)),5) + offset
        if Unit.Distance < threatRange
            and (UnitReaction("player",Unit.Pointer) < 4 or (Target and Target.ValidEnemy))
        then
            return true
        end
    end
    return false
end

local function Extra()
    if Setting("Auto-Shapeshifting") then
        -- Cancel Form To Speak to NPCs
        if Target and Target.Friend and not Target.ValidEnemy and not Target.Dead and not Target.Player
            and Target.Distance < 8 and Shapeshifted
        then
            if CancelForm() then
                debug("Cancel Form [NPC]")
                InteractUnit("target")
                debug("Interacting [NPC]")
                return true
            end 
        end
        -- Aquatic Form
        if Setting("Aquatic Form") and not Player.Combat and IsReadyShapeshifted(Spell.AquaticForm)
            and IsSwimming() and not Buff.AquaticForm:Exist(Player) and not Buff.Prowl:Exist(Player)
            and Player.Moving and Player.MovingTime > 2 and Mana >= ShapeshiftCost(Spell.AquaticForm,LastForm)
            and not InAggroRange() and Player.SwimmingTime > 2
        then
            if CancelForm() then debug("Cancel Form [Swimming]") end
            if Spell.AquaticForm:Cast(Player) then debug("Cast Aquatic Form") return true end
        end
        -- Travel Form
        if Setting("Travel Form") and not Player.Combat and not IsMounted() and not IsSwimming() and not IsFalling()
            and IsReadyShapeshifted(Spell.TravelForm) and not Player:IsInside() and not Buff.TravelForm:Exist(Player)
            and not Buff.Prowl:Exist(Player) and Player.Moving and Player.MovingTime > 2
            and Mana >= ShapeshiftCost(Spell.TravelForm,LastForm) and not InAggroRange()
        then
            if CancelForm() then debug("Cancel Form [Travel]") end
            if Spell.TravelForm:Cast(Player) then debug("Cast Travel Form") return true end
        end
    end
    -- Powershifting
    if Setting("Powershifting") and Player.Combat and Talent.Furor.Rank == 5 and Buff.CatForm:Exist(Player)
        and Energy < 30 and ComboPoints < 5 and not Buff.Clearcasting:Exist(Player)
        and ((not Player.InInstance and Mana >= ShapeshiftCost(Spell.HealingTouch) + Spell.CatForm:Cost())
            or (Player.InInstance and Mana >= Spell.CatForm:Cost() * 2))
    then
        if Powershift() then debug("Powershifted") return true end
    end
end

local function Buffs()
    if (not Target or (Target and Target.Friend and not Target.Dead)) and (not Buff.Prowl:Exist(Player) or Enemies40YC == 0)
        and not Player.Combat and (not Player.Moving or not Shapeshifted)
    then
        -- Mark of the Wild
        if Setting("Mark of the Wild") and IsReadyShapeshifted(Spell.MarkOfTheWild)
            and Mana >= ShapeshiftCost(Spell.MarkOfTheWild) and Spell.MarkOfTheWild:TimeSinceLastCast() > GCD
        then
            -- Buff Friendly Player Target
            if Target and Target.Friend and Target.Player and not Buff.MarkOfTheWild:Exist(Target)
                and not Buff.GiftOfTheWild:Exist(Target)
            then
                if not Player.Combat and CancelForm() then debug("Cancel Form [Mark of the Wild (Friend)]") end
                if Spell.MarkOfTheWild:Cast(Target) then
                    debug("Cast Mark of the Wild ["..Target.Name.."]")
                    return true
                end
            -- Buff Self
            elseif not Buff.GiftOfTheWild:Exist(Player) and Buff.MarkOfTheWild:Remain(Player) < 60
                and not Buff.Prowl:Exist(Player)
            then
                if not Player.Combat and CancelForm() then debug("Cancel Form [Mark of the Wild (Self)]") end
                if Spell.MarkOfTheWild:Cast(Player) then debug("Cast Mark of the Wild") return true end
            end
        end
        -- Thorns
        if Setting("Thorns") and IsReadyShapeshifted(Spell.Thorns) and Mana >= ShapeshiftCost(Spell.Thorns)
            and Spell.Thorns:TimeSinceLastCast() > GCD
        then
            -- Buff Friendly Player Target
            if Target and Target.Friend and Target.Player and not Buff.Thorns:Exist(Target) then
                if not Player.Combat and CancelForm() then debug("Cancel Form [Thorns (Friend)]") end
                if Spell.Thorns:Cast(Target) then debug("Cast Thorns ["..Target.Name.."]") return true end
            -- Buff Self
            elseif Buff.Thorns:Remain(Player) < 60 and not Buff.Prowl:Exist(Player) then
                if not Player.Combat and CancelForm() then debug("Cancel Form [Thorns (Self)]") end
                if Spell.Thorns:Cast(Player) then debug("Cast Thorns") return true end
            end
        end
        -- Omen of Clarity
        if Setting("Omen of Clarity") ~= 4 and IsReadyShapeshifted(Spell.OmenOfClarity)
            and Mana >= ShapeshiftCost(Spell.OmenOfClarity) and Spell.OmenOfClarity:TimeSinceLastCast() > GCD
        then
            if Buff.OmenOfClarity:Remain(Player) < 60 and not Buff.Prowl:Exist(Player) then
                if CancelForm() then debug("Cancel Form [Omen of Clarity]") end
                if Spell.OmenOfClarity:Cast(Player) then debug("Cast Omen of Clarity") return true end
            end
        end
    end
end

local function Defensive()
    if not Buff.Prowl:Exist(Player) and (not Player.Moving or not Shapeshifted) then
        -- Abolish Poison
        if Setting("Abolish Poison") and Spell.AbolishPoison:IsReady()
            and Player:Dispel(Spell.AbolishPoison) and not Buff.AbolishPoison:Exist(Player)
            and Mana >= ShapeshiftCost(Spell.AbolishPoison) and Player.Combat
        then
            if CancelForm() then debug("Cancel Form [Abolish Poison]") return end
            if Spell.AbolishPoison:Cast(Player) then debug("Cast Abolish Poison") return true end
        end
        -- Barkskin
        if Setting("Barkskin") and IsReadyShapeshifted(Spell.Barkskin)
            and Player.Combat and Mana >= ShapeshiftCost(Spell.Barkskin) and HP <= Setting("Barkskin Percent")
            and noShapeshiftPower
        then
            if CancelForm() then debug("Cancel Form [Barkskin]") return end
            if Spell.Barkskin:Cast(Player) then debug("Cast Barkskin") return true end
        end
        -- Cure Poison
        if Setting("Cure Poison") and (Spell.CurePoison:IsReady() and not Spell.AbolishPoison:Known())
            and Player:Dispel(Spell.CurePoison) and Mana >= ShapeshiftCost(Spell.CurePoison)
            and not Player.Combat
        then
            if CancelForm() then debug("Cancel Form [Cure Poison]") return end
            if Spell.CurePoison:Cast(Player) then debug("Cast Cure Poison") return true end
        end
        -- Entangling Roots
        if Setting("Entangling Roots") and IsReadyShapeshifted(Spell.EntanglingRoots)
            and Target and not Target.Facing and Target.Moving and Target.ValidEnemy and Target.Health < Target.HealthMax
            and not Debuff.EntanglingRoots:Exist(Target) and Target.Distance > 8
            and Player.Combat and not Spell.EntanglingRoots:LastCast() and Mana >= ShapeshiftCost(Spell.EntanglingRoots)
        then
            if CancelForm() then debug("Cancel Form [Entangling Roots]") return end
            if Spell.EntanglingRoots:Cast(Target) then debug("Cast Entangling Roots") return true end
        end
        -- Faerie Fire
        if Setting("Fearie Fire") and IsReadyShapeshifted(Spell.FaerieFire)
            and Target.CreatureType ~= "Elemental" and not Debuff.FaerieFire:Exist(Target)
            and not Shapeshifted and Mana >= ShapeshiftCost(Spell.FaerieFire) and Target.Distance > 8
            and noShapeshiftPower
        then
            if Spell.FaerieFire:Cast(Target) then debug("Cast Faerie Fire") return true end
        end
        -- Healing Touch
        if Setting("Healing Touch") and IsReadyShapeshifted(Spell.HealingTouch)
            and (Mana >= ShapeshiftCost(Spell.HealingTouch) or freeHeal) and HP <= Setting("Healing Touch Percent")
            and noShapeshiftPower and not Spell.HealingTouch:LastCast() and not Player.InInstance
            -- and (not CurrentSpell or CurrentSpell ~= Spell.Regrowth) and Spell.Regrowth:TimeSinceLastCast() > GCD * 2
            and not Player.HealPending and Player.LastHeal < GetTime() - 0.5
        then
            if CancelForm() then debug("Cancel Form [Healing Touch]") return end
            if Spell.HealingTouch:Cast(Player) then debug("Cast Healing Touch") Player.HealPending = true return true end
        end
        -- Regrowth
        if Setting("Regrowth") and IsReadyShapeshifted(Spell.Regrowth)
            and not Buff.Regrowth:Exist(Player) and HP <= Setting("Regrowth Percent")
            and not Spell.Regrowth:LastCast() and (Mana >= ShapeshiftCost(Spell.Regrowth) or freeHeal)
            and noShapeshiftPower and not Spell.Regrowth:LastCast() and not Player.InInstance
            -- and (not CurrentSpell or CurrentSpell ~= Spell.HealingTouch) and Spell.HealingTouch:TimeSinceLastCast() > GCD * 2
            and not Player.HealPending and Player.LastHeal < GetTime() - 0.5
        then
            if CancelForm() then debug("Cancel Form [Regrowth]") return end
            if Spell.Regrowth:Cast(Player) then debug("Cast Regrowth") Player.HealPending = true return true end
        end
        -- Rejuvenation
        if Setting("Rejuvenation") and IsReadyShapeshifted(Spell.Rejuvenation)
            and not Buff.Rejuvenation:Exist(Player) and HP <= Setting("Rejuvenation Percent")
            and Mana >= ShapeshiftCost(Spell.Rejuvenation) and not Player.Combat
            and not Buff.Clearcasting:Exist(Player) and not Player.InInstance
            and not Player.HealPending and Player.LastHeal < GetTime() - 0.5
        then
            if CancelForm() then debug("Cancel Form [Rejuvenation]") return end
            if Spell.Rejuvenation:Cast(Player) then debug("Cast Rejuvenation") Player.HealPending = true return true end
        end
        -- Remove Curse
        if Setting("Remove Curse") and IsReadyShapeshifted(Spell.RemoveCurse)
            and Player:Dispel(Spell.RemoveCurse) and Mana >= ShapeshiftCost(Spell.RemoveCurse)
            and not Player.Combat
        then
            if CancelForm() then debug("Cancel Form [Remove Curse]") return end
            if Spell.RemoveCurse:Cast(Player) then debug("Cast Remove Curse") return true end
        end
        -- Health Potion
        if Setting("Health Potion") and Item.HealthPotion and Item.HealthPotion:IsReady()
            and HP < LowestHealthOption
            and (Mana >= Spell.CatForm:Cost() or not Shapeshifted)
            and Mana < ShapeshiftCost(Spell.HealingTouch)
            and not Player.InInstance
        then
            if CancelForm() then debug("Cancel Form [Health Potion]") return end
            if Item.HealthPotion:Use() then debug("Use Health Potion") return true end
        end
        -- Mana Potion
        if Setting("Mana Potion") and Item.ManaPotion
            and Item.ManaPotion:IsReady() and (Mana < Spell.CatForm:Cost() * 2)
        then
            if CancelForm() then debug("Cancel Form [Mana Potion]") return end
            if Item.ManaPotion:Use() then debug("Use Mana Potion") return true end
        end
        -- Rejuvenation Potion
        if ((Setting("Health Potion") and Item.HealthPotion and Item.HealthPotion:IsReady()
                and HP < LowestHealthOption and (Mana >= Spell.CatForm:Cost() or not Shapeshifted)
                and Mana < ShapeshiftCost(Spell.HealingTouch)
                and not Player.InInstance)
            or Setting("Mana Potion") and Item.ManaPotion
                and Item.ManaPotion:IsReady() and (Mana < Spell.CatForm:Cost() * 2))
        then
            if CancelForm() then debug("Cancel Form [Rejuvenation Potion]") return end
            if Item.RejuvenationPotion:Use() then debug("Use Rejuvenation Potion") return true end
        end
    end
end

local function Bear()
    Player:AutoTarget(5, true)
    if Target and Target.ValidEnemy then
        -- No Combat
        if not Player.Combat and not Target.Player then
            StartAttack()
            -- Enrage
            if Spell.Enrage:IsReady() and Player.Power < 10 and Unit5F.Distance < 8 then
                if Spell.Enrage:Cast(Player) then debug("Cast Enrage [Pre-Combat]") return true end
            end
            -- Swipe
            if Spell.Swipe:IsReady() and #Enemies5Y >= 3 then
                if Spell.Swipe:Cast(Unit5F) then debug("Cast Swipe [Pre-Combat]") return true end
            end
            -- Maul
            if Spell.Maul:IsReady() and (not Spell.Swipe:Known() or #Enemies5Y < 3) then
                if Spell.Maul:Cast(Unit5F) then debug("Cast Maul [Pre-Combat]") return true end
            end
        end
        -- In Combat
        if Player.Combat then
            StartAttack()
            -- -- Powershifting
            -- if Talent.Furor.Rank == 5 and Power < 10
            --     and Mana >= Spell.BearForm:Cost() and not Spell.BearForm:LastCast()
            -- then
            --     -- CancelShapeshiftForm()
            --     RunMacroText("/cancelform\n/cast Bear Form")
            --     -- if Spell.BearForm:Cast(Player) then debug("Cast Bear Form") return true end
            -- end
            -- Enrage
            if Spell.Enrage:IsReady() and Player.Power < 10 and Unit5F.Distance < 8 and HP > 80 then
                if Spell.Enrage:Cast(Player) then debug("Cast Enrage") return true end
            end
            -- Demoralizing Roar
            if Spell.DemoralizingRoar:IsReady() and not Debuff.DemoralizingRoar:Exist(Unit5F)
                and Unit5F.Distance < 10
            then
                if Spell.DemoralizingRoar:Cast(Player) then debug("Cast Demoralizing Roar") return true end
            end
            -- Swipe
            if Spell.Swipe:IsReady() and #Enemies5Y >= 3 then
                if Spell.Swipe:Cast(Unit5F) then debug("Cast Swipe") return true end
            end
            -- Maul
            if Spell.Maul:IsReady() and (not Spell.Swipe:Known() or #Enemies5Y < 3) then
                if Spell.Maul:Cast(Unit5F) then debug("Cast Maul") return true end
            end
        end
    end
end

local function Caster()
    Player:AutoTarget(40, true)
    if Target and Target.ValidEnemy then
        -- No Combat
        if not Player.Combat and not Target.Player then
            -- Start Attack
            if not IsAutoAttacking() then
                StartAttack()
                debug("Starting Attack")
            end
            -- Faerie Fire
            if Spell.FaerieFire:IsReady() and not Debuff.FaerieFire:Exist(Target) and Mana >= ShapeshiftCost(Spell.FaerieFire)
                and LastForm:IsReady() and Target.Distance >= 8
            then
                if Spell.FaerieFire:Cast(Target) then debug("Cast Faerie Fire [Pre-Combat]") return true end
            end
            -- Moonfire (Shapeshift)
            if Spell.Moonfire:IsReady() and not Spell.FaerieFire:Known() and not Debuff.Moonfire:Exist(Target)
                and Mana >= ShapeshiftCost(Spell.Moonfire.Ranks[Spell.Moonfire:HighestRank()])
                and LastForm:IsReady() and Target.Distance >= 8
            then
                if Spell.Moonfire:Cast(Target,1) then debug("Cast Moonfire [Pre-Combat - Shapeshift]") return true end
            end
            -- Wrath
            if Spell.Wrath:IsReady() and Target.Facing and not Player.Moving and (not Spell.Wrath:LastCast(true) or not Spell.Moonfire:Known())
                and Mana >= ShapeshiftCost(Spell.Wrath) and (LastForm == nil or (LastForm:IsReady() and Target.Distance >= 8))
            then
                if Spell.Wrath:Cast(Target) then debug("Cast Wrath [Pre-Combat]") return true end
            end
            -- Moonfire
            if Spell.Moonfire:IsReady() and (Player.Moving or Spell.Wrath:LastCast())
                and Mana >= ShapeshiftCost(Spell.Moonfire) and (LastForm == nil or (LastForm:IsReady() and Target.Distance >= 8))
            then
                if Spell.Moonfire:Cast(Target) then debug("Cast Moonfire [Pre-Combat]") return true end
            end
        end
        -- In Combat
        if Player.Combat then
            -- Start Attack
            if not IsAutoAttacking() then
                StartAttack()
                debug("Starting Attack")
            end
            -- Moonfire
            if Spell.Moonfire:IsReady() and not Debuff.Moonfire:Exist(Target) and (LastForm == nil
                or (LastForm:IsReady() and Target.Distance >= 8 and Mana >= ShapeshiftCost(Spell.Moonfire)))
            then
                if Spell.Moonfire:Cast(Target) then debug("Cast Moonfire") return true end
            end
            -- Wrath
            if Spell.Wrath:IsReady() and Target.Facing and not Player.Moving
                and (Debuff.Moonfire:Exist(Target) or not Spell.Moonfire:Known())
                and (LastForm == nil or (LastForm:IsReady() and Target.Distance >= 8
                and Mana >= ShapeshiftCost(Spell.Wrath)))
            then
                if Spell.Wrath:Cast(Target) then debug("Cast Wrath") return true end
            end
        end
    end
end

local function Cat()
    -- Prowl
    if Setting("Prowl") and not IsResting() and not Player.Combat and Spell.Prowl:IsReady()
        and Buff.CatForm:Exist(Player) and not Buff.Prowl:Exist(Player) and Player.CombatLeftTime > 1
        and Spell.Prowl:TimeSinceLastCast() > GCD
    then
        if InAggroRange() then
            if Spell.Prowl:Cast(Player) then debug("Cast Prowl") return true end
        end
    end
    Player:AutoTarget(5, true)
    if Target and Target.ValidEnemy and Spell.Claw:InRange(Target) then
        -- Tiger's Fury
        if Setting("Tiger's Fury") and Spell.TigersFury:IsReady()
            -- and TickTimeRemain > 0 and TickTimeRemain < 0.1 
            and not Buff.TigersFury:Exist(Player) and Power == 100
            and not Target.Player
            --and Spell.TigersFury:TimeSinceLastCast() > GCD
        then
            if Spell.TigersFury:Cast(Player) then debug("Cast Tiger's Fury [Pre-Combat]") return end
        end
        -- Stealth Opener
        if Buff.Prowl:Exist(Player) and not Target.Player
            and (not (Setting("Tiger's Fury") or not Spell.TigersFury:Known() or Power < 100) or Buff.TigersFury:Exist(Player))
        then
            -- Pounce
            if Opener == 1 and Spell.Pounce:IsReady() then
                if Spell.Pounce:Cast(Target) then debug("Cast Pounce [Stealth Pre-Combat]") return true end
            end
            -- Ravage
            if (Opener == 2 or (Opener <= 1 and not Spell.Pounce:Known())) and Spell.Ravage:IsReady() and Target:IsBehind() then
                if Spell.Ravage:Cast(Target) then debug("Cast Ravage [Stealth Pre-Combat]") return true end
            end
            -- Shred
            if (Opener == 3 or (Opener <= 2 and not Spell.Ravage:Known())) and Spell.Shred:IsReady() and Target:IsBehind() then
                if Spell.Shred:Cast(Target) then debug("Cast Shred [Stealth Pre-Combat]") return true end
            end
            -- Rake
            if Setting("Rake") and (Opener == 4 or (Opener <= 3 and not Spell.Shred:Known()))
                and Spell.Rake:IsReady() and not Unit5F:IsImmune("Bleed")
            then
                if Spell.Rake:Cast(Target) then debug("Cast Rake [Stealth Pre-Combat]") return true end
            end
            -- Claw
            if ((Opener == 4 and not Setting("Rake")) or (Opener < 4 and not Spell.Rake:Known()))
                and Spell.Claw:IsReady()
            then
                if Spell.Claw:Cast(Target) then debug("Cast Claw [Stealth Pre-Combat]") return true end
            end
        end
        -- No Stealth Opener
        if not Buff.Prowl:Exist(Player) and (Target:IsBehind() or not Spell.Shred:Known()) and not Target.Player
            and (not (Setting("Tiger's Fury") or not Spell.TigersFury:Known() or Power < 100) or Buff.TigersFury:Exist(Player))
        then
            -- Shred
            if Spell.Shred:IsReady() and Target:IsBehind() then
                if Spell.Shred:Cast(Target) then debug("Cast Shred [Pre-Combat]") return true end
            end
            -- Claw
            if Spell.Claw:IsReady() and not (Spell.Shred:Known() or Target:IsBehind()) then
                if Spell.Claw:Cast(Target) then debug("Cast Claw [Pre-Combat]") return true end
            end
            -- StartAttack()
        end
        if Player.Combat then
            StartAttack()
            -- Ferocious Bite - Finish Him!
            if Spell.FerociousBite:IsReady() and Power >= 35 and FerociousBiteFinish(Unit5F) then
                if Spell.FerociousBite:Cast(Unit5F) then debug("Cast Ferocious Bite [Finish "..Gender.."!]") return true end
            end
            -- Tiger's Fury
            if Setting("Tiger's Fury") and Spell.TigersFury:IsReady()
                and Power == 100 and not Buff.TigersFury:Exist(Player)
                --and Spell.TigersFury:TimeSinceLastCast() > GCD
            then
                if Spell.TigersFury:Cast(Player) then debug("Cast Tiger's Fury") return true end
            end
            -- Faerie Fire Feral
            if Spell.FaerieFireFeral:IsReady() and Target.CreatureType ~= "Elemental"
                and not Debuff.FaerieFireFeral:Exist(Unit5F) and Unit5F.TTD > GCD
            then
                if Spell.FaerieFireFeral:Cast(Unit5F) then debug("Cast Faerie Fire Feral") return true end
            end
            if ComboPoints == 5 and not FerociousBiteFinish(Unit5F) then
                -- Ferocious Bite
                if Spell.FerociousBite:IsReady() and Power >= 35 and Power < 60 then
                    if Spell.FerociousBite:Cast(Unit5F) then debug("Cast Ferocious Bite") return true end
                end
                -- Rip
                if Setting("Rip") and Spell.Rip:IsReady() and Unit5F.TTD > 6
                    and not Spell.FerociousBite:Known() and not Unit5F:IsImmune("Bleed")
                then
                    if Spell.Rip:Cast(Unit5F) then debug("Cast Rip") return true end
                end
            end
            if (ComboPoints < 5 or Power >= 60 or freeDPS) and not FerociousBiteFinish(Unit5F) then
                -- Ravage
                if Spell.Ravage:IsReady() and Buff.Prowl:Exist(Player) and Target:IsBehind() then
                    if Spell.Ravage:Cast(Unit5F) then debug("Cast Ravage") return true end
                end
                -- Rake
                if Setting("Rake") and Spell.Rake:IsReady() and Debuff.Rake:Refresh(Unit5F)
                    and (Unit5F.TTD <= 3 or not Spell.FerociousBite:Known()) and not freeDPS
                    and not Unit5F:IsImmune("Bleed")
                then
                    if Spell.Rake:Cast(Unit5F) then debug("Cast Rake") return true end
                end
                -- Shred
                if Spell.Shred:IsReady() and Unit5F:IsBehind() then
                    if Spell.Shred:Cast(Unit5F) then debug("Cast Shred") return true end
                end
                -- Claw
                if Spell.Claw:IsReady() and (not Unit5F:IsBehind() or not Spell.Shred:Known()) then
                    if Spell.Claw:Cast(Unit5F) then debug("Cast Claw") return true end
                end
            end
        end
    end
end

function Druid.Rotation()
    Locals()
    if Rotation.Active() then
        if Extra() then return true end
        if Buffs() then return true end
        if Defensive() then return true end
        -- Innervate
        if Setting("Self-Innervate") and Spell.Innervate:IsReady()
            and ((not Player.InInstance and Mana < ShapeshiftCost(Spell.HealingTouch))
                or (Player.InInstance and Mana < Spell.CatForm:Cost() * 2))
        then
            Spell.Innervate:Cast(Player)
            debug("Cast Innervate")
        end
        -- Last Form
        if Setting("Auto-Shapeshifting") and Setting("Last Form") and LastForm ~= nil
            and ((Player.Moving and Player.MovingTime > 2 and (not Spell.TravelForm:Known() or Player:IsInside() or not Setting("Travel Form")))
            or ((Player.Combat or InAggroRange(5)) and ((Target and not Target.Friend) or not Target)))
            and not LastFormBuff and (not (Buff.AquaticForm:Exist(Player) or Buff.TravelForm:Exist(Player)) or InAggroRange(5))
                -- or #Enemies5Y > 0 or (Target and Target.Distance < 8))
        then
            if CancelForm() then debug("Cancel Form [Last Form]") return end
            if LastForm:Cast(Player) then debug("Cast Last Form") return true end
        end
        if not Shapeshifted then
            if Caster() then return true end
        end
        if Buff.BearForm:Exist(Player) or Buff.DireBearForm:Exist(Player) then
            if Bear() then return true end
        end
        if Buff.CatForm:Exist(Player) then
            if Cat() then return true end
        end
    end
end