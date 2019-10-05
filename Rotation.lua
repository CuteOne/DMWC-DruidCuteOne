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
local LastCancel
local Opener
local TickTime = DMW.Player.TickTime or GetTime()
local TickTimeRemain = TickTime - GetTime()

-- local f = CreateFrame("Frame", "KeyboardListener", UIParent)
-- f:EnableKeyboard(true)
-- f:SetPropagateKeyboardInput(true)
-- f:SetScript("OnKeyDown", function(self, event, ...)
--     -- if event == "x" then
--         CancelShapeshiftForm()
--         CastShapeshiftForm(3)
--         print(event .. " Down, casted spells!")
--     -- end
-- end)

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
    MeleeAggro = false
    for _, Unit in ipairs(Enemies40Y) do
        if Unit.Distance < 5 and Player.Pointer == Unit.Target then
            MeleeAggro = true
        end
    end
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
    -- if Buff.TravelForm:Exist(Player) and IsOutdoors() then LastForm = Spell.TravelForm end
    -- if Buff.AquaticForm:Exist(Player) and not Player.Combat then LastForm = Spell.AquaticForm end
    if LastHeal == nil then LastHeal = GetTime() end
    Opener = Setting("Cat Opener")
    TickTime = DMW.Player.TickTime or GetTime()
    TickTimeRemain = TickTime - GetTime()
    -- print("GCD: "..GCDRemain..", Swing: "..DMW.Player.SwingMH..", Tick: "..TickTimeRemain)
end

local function CancelForm()
    if LastCancel == nil then LastCancel = GetTime() end
    if Shapeshifted and GetTime() > LastCancel + GCD then
        CancelShapeshiftForm()
        LastCancel = GetTime()
        return true
    elseif not Shapeshifted then
        return false
    end
end

local function ShapeshiftCost(castSpell)
    if Setting("Auto-Shapeshifting") then
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
        return shapeSpell:Cost() + castSpell:Cost()
    end
    return 0
end

local function Powershift()
    if GCDRemain == 0 and DMW.Player.SwingMH > 0.25
        and TickTimeRemain > 0 and TickTimeRemain < 0.25
    then
        for i=1, GetNumShapeshiftForms() do
            _, name, active = GetShapeshiftFormInfo(i);
            if( name and active ) then
                CancelShapeshiftForm()
                CastShapeshiftForm(i)
                return true
            end
        end
    end
    return false
end

local function FerociousBiteFinish(thisUnit)
    local desc = GetSpellDescription(Spell.FerociousBite.SpellID)
    local damage = 0
    local finishHim = false
    local unitHealth = tonumber(thisUnit.Health) or 0
    local unitHealthMax = tonumber(thisUnit.HealthMax) or 100
    if thisUnit and Spell.FerociousBite:Known() and ComboPoints > 0
        and unitHealthMax > 100
    then
        local comboStart = desc:find(" "..ComboPoints.." point",1,true)
        if comboStart ~= nil then
            comboStart = comboStart + 2
            local damageList = desc:sub(comboStart,desc:len())
            comboStart = damageList:find(": ",1,true)+2
            damageList = damageList:sub(comboStart,desc:len())
            local comboEnd = damageList:find("-",1,true)-1
            damageList = damageList:sub(1,comboEnd)
            damage = damageList:gsub(",","")
        end
        damage = tonumber(damage)
        -- print(damage.." | "..unitHealth)
        finishHim = damage >= unitHealth
    end
    return finishHim
end

local function Extra()
    if Setting("Auto-Shapeshifting") then
        -- Cancel Form To Speak to NPCs
        if Target and Target.Friend and not Target.ValidEnemy and not Target.Dead and not Target.Player
            and Target.Distance < 8 and Shapeshifted
        then
            if CancelForm() then print("Cancel Form [NPC]") return true end
        end
        -- Aquatic Form
        if not Player.Combat and (Spell.AquaticForm:IsReady() or Shapeshifted)
            and IsSwimming("player") and not Buff.AquaticForm:Exist(Player) and not Buff.Prowl:Exist(Player)
            and Player.Moving and Mana >= ShapeshiftCost(Spell.AquaticForm) and #Enemies5Y == 0
        then
            if CancelForm() then print("Cancel Form [Swimming]") end
            if Spell.AquaticForm:Cast(Player) then return true end
        end
        -- -- Swimming In Combat
        -- if Player.Combat and Buff.AquaticForm:Exist(Player) and Target and not Target.Dead and Target.Distance < 5 then
        --     if Spell.CatForm:Known() then LastForm = Spell.CatForm end
        --     if Spell.BearForm:Known() and not Spell.CatForm:Known() then LastForm = Spell.BearForm end
        --     if CancelForm() then print("Cancel Form [Combat (Swimming)]") return end
        -- end
    end
end

local function Buffs()
    if (not Target or (Target and Target.Friend and not Target.Dead)) and (not Buff.Prowl:Exist(Player) or Enemies40YC == 0)
        and not Player.Combat and (not Player.Moving or not Shapeshifted)
    then
        -- Mark of the Wild
        if Setting("Mark of the Wild") and (Spell.MarkOfTheWild:IsReady() or Shapeshifted) and Mana >= ShapeshiftCost(Spell.MarkOfTheWild) then
            -- Buff Friendly Player Target
            if Target and Target.Friend and Target.Player and not Buff.MarkOfTheWild:Exist(Target) then
                if not Player.Combat and CancelForm() then print("Cancel Form [Mark of the Wild (Friend)]") end
                if Spell.MarkOfTheWild:Cast(Target) then --,HighestMOTW()) then
                    -- print("Casting Mark of the Wild (Friend - Level "..Target.Level..") [Rank "..HighestMOTW().."]")
                    return true
                end
            -- Buff Self
            elseif Buff.MarkOfTheWild:Refresh(Player) and not Buff.Prowl:Exist(Player) then
                if not Player.Combat and CancelForm() then print("Cancel Form [Mark of the Wild (Self)]") end
                if Spell.MarkOfTheWild:Cast(Player) then return true end
            end
        end
        -- Thorns
        if Setting("Thorns") and (Spell.Thorns:IsReady() or Shapeshifted) and Mana >= ShapeshiftCost(Spell.Thorns) then
            -- Buff Friendly Player Target
            if Target and Target.Friend and Target.Player and not Buff.Thorns:Exist(Target) then
                if not Player.Combat and CancelForm() then print("Cancel Form [Thorns (Friend)]") end
                if Spell.Thorns:Cast(Target) then return true end
            -- Buff Self
            elseif Buff.Thorns:Refresh(Player) and not Buff.Prowl:Exist(Player) then
                if not Player.Combat and CancelForm() then print("Cancel Form [Thorns (Self)]") end
                if Spell.Thorns:Cast(Player) then return true end
            end
        end
    end
end

local function Defensive()
    if not Buff.Prowl:Exist(Player) and (not Player.Moving or not Shapeshifted) then
        local noShapeshiftPower = ((not Buff.CatForm:Exist(Player) or (Buff.CatForm:Exist(Player) and Power < 30))
            and (not Buff.BearForm:Exist(Player) or (Buff.BearForm:Exist(Player) and Power < 10))) or not Player.Combat
        -- Abolish Poison
        if Setting("Abolish Poison") and Spell.AbolishPoison:IsReady()
            and Player:Dispel(Spell.AbolishPoison) and not Buff.AbolishPoison:Exist(Player)
            and Mana >= ShapeshiftCost(Spell.AbolishPoison) and not Player.Combat
        then
            if CancelForm() then print("Cancel Form [Abolish Poison]") return end
            if Spell.AbolishPoison:Cast(Player) then return true end
        end
        -- Cure Poison
        if Setting("Cure Poison") and (Spell.CurePoison:IsReady() and not Spell.AbolishPoison:Known())
            and Player:Dispel(Spell.CurePoison) and Mana >= ShapeshiftCost(Spell.CurePoison)
            and not Player.Combat
        then
            if CancelForm() then print("Cancel Form [Cure Poison]") return end
            if Spell.CurePoison:Cast(Player) then return true end
        end
        -- Entangling Roots
        if Setting("Entangling Roots") and (Spell.EntanglingRoots:IsReady() or Shapeshifted) and Target and not Facing and Target.Moving
            and Target.ValidEnemy and not Debuff.EntanglingRoots:Exist(Target) and Target.Distance > 8
            and Player.Combat and not Spell.EntanglingRoots:LastCast() and Mana >= ShapeshiftCost(Spell.EntanglingRoots)
        then
            if CancelForm() then print("Cancel Form [Entangling Roots]") return end
            if Spell.EntanglingRoots:Cast(Target) then return true end
        end
        -- Faerie Fire
        if Setting("Fearie Fire") and (Spell.FaerieFire:IsReady() or Shapeshifted)
            and Target.CreatureType ~= "Elemental" and not Debuff.FaerieFire:Exist(Target)
            and not Shapeshifted and Mana >= ShapeshiftCost(Spell.FaerieFire) and Target.Distance > 8
            and noShapeshiftPower
        then
            if Spell.FaerieFire:Cast(Target) then return true end
        end
        -- Healing Touch
        if Setting("Healing Touch") and (Spell.HealingTouch:IsReady() or Shapeshifted)
            and Mana >= ShapeshiftCost(Spell.HealingTouch) and HP <= Setting("Healing Touch Percent")
            and noShapeshiftPower and GetTime() > LastHeal + (GCD * 2)
        then
            if CancelForm() then print("Cancel Form [Healing Touch]") return end
            if Spell.Innervate:IsReady() and Mana < ShapeshiftCost(Spell.HealingTouch) then Spell.Innervate:Cast(Player) end
            if Spell.HealingTouch:Cast(Player) then LastHeal = GetTime() + Spell.HealingTouch:CastTime() return true end
        end
        -- Regrowth
        if Setting("Regrowth") and (Spell.Regrowth:IsReady() or Shapeshifted) and not Buff.Regrowth:Exist(Player)
            and HP <= Setting("Regrowth Percent") and not Spell.Regrowth:LastCast()
            and Mana >= ShapeshiftCost(Spell.Regrowth) and noShapeshiftPower
            and GetTime() > LastHeal + GCD
        then
            if CancelForm() then print("Cancel Form [Regrowth]") return end
            if Spell.Regrowth:Cast(Player) then LastHeal = GetTime() + Spell.Regrowth:CastTime() return true end
        end
        -- Rejuvenation
        if Setting("Rejuvenation") and (Spell.Rejuvenation:IsReady() or Shapeshifted)
            and not Buff.Rejuvenation:Exist(Player) and HP <= Setting("Rejuvenation Percent")
            and Mana >= ShapeshiftCost(Spell.Rejuvenation) and not Player.Combat
            -- and GetTime() > LastHeal + GCD
        then
            if CancelForm() then print("Cancel Form [Rejuvenation]") return end
            if Spell.Rejuvenation:Cast(Player) then --[[LastHeal = GetTime()]] return true end
        end
    end
end

local function Bear()
    if Target and Target.ValidEnemy then
        -- No Combat
        if not Player.Combat then
            StartAttack()
            -- Enrage
            if Spell.Enrage:IsReady() and Player.Power < 10 and Unit5F.Distance < 8 then
                if Spell.Enrage:Cast(Player) then return true end
            end
            -- Swipe
            if Spell.Swipe:IsReady() and #Enemies5Y >= 3 then
                if Spell.Swipe:Cast(Unit5F) then return true end
            end
            -- Maul
            if Spell.Maul:IsReady() and (not Spell.Swipe:Known() or #Enemies5Y < 3) then
                if Spell.Maul:Cast(Unit5F) then return true end
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
            --     -- if Spell.BearForm:Cast(Player) then return true end
            -- end
            -- Enrage
            if Spell.Enrage:IsReady() and Player.Power < 10 and Unit5F.Distance < 8 then
                if Spell.Enrage:Cast(Player) then return true end
            end
            -- Demoralizing Roar
            if Spell.DemoralizingRoar:IsReady() and not Debuff.DemoralizingRoar:Exist(Unit5F)
                and Unit5F.Distance < 10
            then
                if Spell.DemoralizingRoar:Cast(Player) then return true end
            end
            -- Swipe
            if Spell.Swipe:IsReady() and #Enemies5Y >= 3 then
                if Spell.Swipe:Cast(Unit5F) then return true end
            end
            -- Maul
            if Spell.Maul:IsReady() and (not Spell.Swipe:Known() or #Enemies5Y < 3) then
                if Spell.Maul:Cast(Unit5F) then return true end
            end
        end
    end
end

local function Caster()
    if Target and Target.ValidEnemy then
        -- No Combat
        if not Player.Combat then
            StartAttack()
            -- Wrath
            if Spell.Wrath:IsReady() and not Player.Moving and not Spell.Wrath:LastCast() and Mana >= ShapeshiftCost(Spell.Wrath) then
                if Spell.Wrath:Cast(Target) then return true end
            end
            -- Moonfire
            if Spell.Moonfire:IsReady() and (Player.Moving or Spell.Wrath:LastCast()) and Mana >= ShapeshiftCost(Spell.Moonfire) then
                if Spell.Moonfire:Cast(Target) then return true end
            end
        end
        -- In Combat
        if Player.Combat then
            StartAttack()
            -- Moonfire
            if Spell.Moonfire:IsReady() and not Debuff.Moonfire:Exist(Target) and (LastForm == nil
                or (LastForm:IsReady() and Target.Distance >= 8 and Mana >= ShapeshiftCost(Spell.Moonfire)))
            then
                if Spell.Moonfire:Cast(Target) then return true end
            end
            -- Wrath
            if Spell.Wrath:IsReady() and not Player.Moving
                and (Debuff.Moonfire:Exist(Target) or not Spell.Moonfire:Known())
                and (LastForm == nil or (LastForm:IsReady() and Target.Distance >= 8
                and Mana >= ShapeshiftCost(Spell.Wrath)))
            then
                if Spell.Wrath:Cast(Target) then return true end
            end
        end
    end
    -- -- Shapeshift
    -- if Setting("Auto-Shapeshifting") and LastForm ~= nil
    --     and Target and Target.ValidEnemy and Player.Combat and LastForm:IsReady()
    --     and Mana < ShapeshiftCost(Spell.Wrath) and Mana < ShapeshiftCost(Spell.Moonfire)
    --     and (not IsSwimming() or not Buff.TravelForm:Exist(Player) or Target.Distance < 8)
    -- then
    --     if LastForm:Cast(Player) then return true end
    -- end
end

local function Cat()
    -- Prowl
    if Setting("Prowl") and not IsResting() and not Player.Combat and Spell.Prowl:IsReady()
        and Buff.CatForm:Exist(Player) and not Buff.Prowl:Exist(Player) and DMW.Player.CombatLeft > 1
    then
        for _, Unit in ipairs(Attackable40Y) do
            local threatRange = max((20 + (Unit.Level - Player.Level)),5)
            if Unit.Distance < threatRange
                and (UnitReaction("player",Unit.Pointer) < 4 or (Target and Target.ValidEnemy))
            then
                if Spell.Prowl:Cast(Player) then return true end
            end
        end
    end
    if Target and Target.ValidEnemy and Target.Distance < 5 then
        -- Stealth Opener
        if Buff.Prowl:Exist(Player) and Target:IsBehind() then
            -- Tiger's Fury
            if Setting("Tiger's Fury") and Spell.TigersFury:IsReady() and TickTimeRemain > 0
                and TickTimeRemain < 0.1 and not Buff.TigersFury:Exist(Player)
            then
                if Spell.TigersFury:Cast(Player) then return end
            end
            -- Pounce
            if Opener == 1 and Spell.Pounce:IsReady() then
                if Spell.Pounce:Cast(Target) then return true end
            end
            -- Ravage
            if (Opener == 2 or (Opener <= 1 and not Spell.Pounce:Known())) and Spell.Ravage:IsReady() then
                if Spell.Ravage:Cast(Target) then return true end
            end
            -- Shred
            if (Opener == 3 or (Opener <= 2 and not Spell.Ravage:Known())) and Spell.Shred:IsReady() then
                if Spell.Shred:Cast(Target) then return true end
            end
            -- Rake
            if Setting("Rake") and (Opener == 4 or (Opener <= 3 and not Spell.Shred:Known())) and Spell.Rake:IsReady() then
                if Spell.Rake:Cast(Target) then return true end
            end
            -- Claw
            if ((Opener == 4 and not Setting("Rake")) or (Opener < 4 and not Spell.Rake:Known()))
                and Spell.Claw:IsReady()
            then
                if Spell.Claw:Cast(Target) then return true end
            end
        end
        -- No Stealth Opener
        if not Player.Combat then
            -- Tiger's Fury
            if Setting("Tiger's Fury") and Spell.TigersFury:IsReady() and TickTimeRemain > 0
                and TickTimeRemain < 0.1 and not Buff.TigersFury:Exist(Player)
            then
                if Spell.TigersFury:Cast(Player) then return end
            end
            -- -- Rake
            -- if Setting("Rake") and Spell.Rake:IsReady() and Debuff.Rake:Refresh(Target) then
            --     if Spell.Rake:Cast(Target) then return true end
            -- end
            -- Shred
            if Spell.Shred:IsReady() and Target:IsBehind() then
                if Spell.Shred:Cast(Target) then return true end
            end
            -- Claw
            if Spell.Claw:IsReady() and not Spell.Shred:Known() then
                if Spell.Claw:Cast(Target) then return true end
            end
            -- StartAttack()
        end
        if Player.Combat then
            StartAttack()
            -- Powershifting
            if Setting("Powershifting") and Talent.Furor.Rank == 5 and Energy < 30
                and Mana >= ShapeshiftCost(Spell.HealingTouch) and not Spell.CatForm:LastCast()
                and Player:GCDRemain() == 0
            then
                if Powershift() then return true end
            end
            -- Ferocious Bite - Finish Him!
            if Spell.FerociousBite:IsReady() and Power >= 35 and FerociousBiteFinish(Unit5F) then
                if Spell.FerociousBite:Cast(Unit5F) then return true end
            end
            -- Tiger's Fury
            if Setting("Tiger's Fury") and Spell.TigersFury:IsReady()
                and (Power == 100) --or (ComboPoints == 5 and Spell.FerociousBite:IsReady()))
                and not Buff.TigersFury:Exist(Player)
            then
                if Spell.TigersFury:Cast(Player) then return true end
            end
            -- Faerie Fire Feral
            if Spell.FaerieFireFeral:IsReady() and Target.CreatureType ~= "Elemental"
                and not Debuff.FaerieFireFeral:Exist(Unit5F)
            then
                if Spell.FaerieFireFeral:Cast(Unit5F) then return true end
            end
            if ComboPoints == 5 and not FerociousBiteFinish(Unit5F) then
                -- Ferocious Bite
                if Spell.FerociousBite:IsReady() and Power >= 35 then
                    if Spell.FerociousBite:Cast(Unit5F) then return true end
                end
                -- Rip
                if Setting("Rip") and Spell.Rip:IsReady() and Unit5F.TTD > 6 and not Spell.FerociousBite:Known() then
                    if Spell.Rip:Cast(Unit5F) then return true end
                end
            end
            if (ComboPoints < 5 or Power > 70) and not FerociousBiteFinish(Unit5F) then
                -- Ravage
                if Spell.Ravage:IsReady() and Buff.Prowl:Exist(Player) and Target:IsBehind() then
                    if Spell.Ravage:Cast(Unit5F) then return true end
                end
                -- Rake
                if Setting("Rake") and Spell.Rake:IsReady() and Debuff.Rake:Refresh(Unit5F) and Unit5F.TTD <= 3 then
                    if Spell.Rake:Cast(Unit5F) then return true end
                end
                -- Shred
                if Spell.Shred:IsReady() and Unit5F:IsBehind() then
                    if Spell.Shred:Cast(Unit5F) then return true end
                end
                -- Claw
                if Spell.Claw:IsReady() and (not Unit5F:IsBehind() or not Spell.Shred:Known()) then
                    if Spell.Claw:Cast(Unit5F) then return true end
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
        -- Last Form
        if Setting("Auto-Shapeshifting") and LastForm ~= nil and (Player.Moving or Player.Combat)
            and not LastFormBuff and (not (Buff.AquaticForm:Exist(Player) or Buff.TravelForm:Exist(Player))
                or #Enemies5Y > 0 or (Target and Target.Distance < 8))
        then
            if CancelForm() then print("Cancel Form [Last Form]") return end
            if Spell.Innervate:IsReady() and Mana < LastForm:Cost() then Spell.Innervate:Cast(Player) end
            if LastForm:Cast(Player) then return true end
        end
        if not Shapeshifted then
            if Caster() then return true end
        end
        if Buff.BearForm:Exist(Player) then
            if Bear() then return true end
        end
        if Buff.CatForm:Exist(Player) then
            if Cat() then return true end
        end
    end
end