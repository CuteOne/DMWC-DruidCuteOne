local DMW = DMW
local Druid = DMW.Rotations.DRUID
local Player, Buff, Debuff, Health, HP, Power, Spell, Target, Talent, Item, GCD, CDs, HUD, Player40Y, Player40YC, Friends40Y, Friends40YC
local Rotation = DMW.Helpers.Rotation
local Setting = DMW.Helpers.Rotation.Setting
local LastForm
local Shapeshifted
local ComboPoints
local Mana
local Facing
local Enemies40Y, Enemies40YC
local Enemies5Y, Enemies5YC
local MeleeAggro

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
    HUD = DMW.Settings.profile.HUD
    CDs = Player:CDs() and Target and Target.TTD > 5 and Target.Distance < 5
    Friends40Y, Friends40YC = Player:GetFriends(40)
    Enemies40Y, Enemies40YC = Player:GetEnemies(40)
    Enemies5Y, Enemies5YC = Player:GetEnemies(5)
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
    if Buff.DireBearForm:Exist(Player) then LastForm = Spell.DireBearForm end
    if Buff.BearForm:Exist(Player) then LastForm = Spell.BearForm end
    if Buff.CatForm:Exist(Player) then LastForm = Spell.CatForm end
    if Buff.MoonkinForm:Exist(Player) then LastForm = Spell.MoonkinForm end
    if Buff.TravelForm:Exist(Player) then LastForm = Spell.TravelForm end
    if Buff.AquaticForm:Exist(Player) then LastForm = Spell.AquaticForm end
    Facing = true
    if Target then Facing = ObjectIsFacing("target", "player") end
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
        local shapeCost
        if shapeID > 0 then
            shapeSpell = select(4,GetShapeshiftFormInfo(shapeID))
            shapeCost = GetSpellPowerCost(GetSpellInfo(shapeSpell))[1].cost
        else
            shapeSpell = LastForm
            if shapeSpell == nil and not Shapeshifted then shapeSpell = Spell.CatForm end
            shapeCost = GetSpellPowerCost(GetSpellInfo(shapeSpell.SpellID))[1].cost
        end
        local spellCost = GetSpellPowerCost(GetSpellInfo(castSpell.SpellID))[1].cost
        return shapeCost + spellCost
    end
    return 0
end

local function Defensive()
    -- Abolish Poison
    if Setting("Abolish Poison") and (Spell.AbolishPoison:IsReady() or Shapeshifted)
        and Player:Dispel(Spell.AbolishPoison) and not Buff.AbolishPoison:Exist(Player)
        and Mana >= ShapeshiftCost(Spell.AbolishPoison)
    then
        CancelShapeshiftForm()
        if Spell.AbolishPoison:Cast(Player) then return true end
    end
    -- Cure Poison
    if Setting("Cure Poison") and (Spell.CurePoison:IsReady() and not Spell.AbolishPoison:Known())
        and Player:Dispel(Spell.CurePoison) and Mana >= ShapeshiftCost(Spell.CurePoison)
    then
        CancelShapeshiftForm()
        if Spell.CurePoison:Cast(Player) then return true end
    end
    -- Entangling Roots
    if Setting("Entangling Roots") and (Spell.EntanglingRoots:IsReady() or Shapeshifted) and Target and not Facing and Target.Moving
        and Target.ValidEnemy and not Debuff.EntanglingRoots:Exist(Target) and Target.Distance > 8
        and Player.Combat and not Spell.EntanglingRoots:LastCast() and Mana >= ShapeshiftCost(Spell.EntanglingRoots)
    then
        CancelShapeshiftForm()
        if Spell.EntanglingRoots:Cast(Target) then return true end
    end
    -- Healing Touch
    if Setting("Healing Touch") and (Spell.HealingTouch:IsReady() or Shapeshifted) and Mana >= ShapeshiftCost(Spell.HealingTouch)
        and HP <= Setting("Healing Touch Percent")
    then
        CancelShapeshiftForm()
        if Spell.HealingTouch:Cast(Player) then return true end
    end
    -- Mark of the Wild
    if Setting("Mark of the Wild") and (Spell.MarkOfTheWild:IsReady() or Shapeshifted) and Mana >= ShapeshiftCost(Spell.MarkOfTheWild) then
        -- Buff Friendly Player Target
        if Target and Target.Friend and Target.Player and not Buff.MarkOfTheWild:Exist(Target) then
            if not Player.Combat then CancelShapeshiftForm() end
            if Spell.MarkOfTheWild:Cast(Target) then return true end
        -- Buff Self
        elseif not Buff.MarkOfTheWild:Exist(Player) then
            if not Player.Combat then CancelShapeshiftForm() end
            if Spell.MarkOfTheWild:Cast(Player) then return true end
        end
    end
    -- Regrowth
    if Setting("Regrowth") and (Spell.Regrowth:IsReady() or Shapeshifted) and not Buff.Regrowth:Exist(Player)
        and --[[not Player.Combat and]] HP <= Setting("Regrowth Percent")
        and Mana >= ShapeshiftCost(Spell.Regrowth)
    then
        CancelShapeshiftForm()
        if Spell.Regrowth:Cast(Player) then return true end
    end
    -- Rejuvenation
    if Setting("Rejuvenation") and (Spell.Rejuvenation:IsReady() or Shapeshifted) and not Buff.Rejuvenation:Exist(Player)
        and --[[not Player.Combat and]] HP <= Setting("Rejuvenation Percent")
        and Mana >= ShapeshiftCost(Spell.Rejuvenation)
    then
        CancelShapeshiftForm()
        if Spell.Rejuvenation:Cast(Player) then return true end
    end
    -- Thorns
    if Setting("Thorns") and (Spell.Thorns:IsReady() or Shapeshifted) and not Player.Combat and not Buff.Thorns:Exist(Player)
        and Mana >= ShapeshiftCost(Spell.Thorns)
    then
        CancelShapeshiftForm()
        if Spell.Thorns:Cast(Player) then return true end
    end
    -- -- Return to Last Form
    -- if Setting("Auto-Shapeshifting") and LastForm ~= nil and Spell.LastForm:IsReady() and Player.Combat then
    --     if LastForm:Cast(Player) then return true end
    -- end
end

local function Bear()
    if Target and Target.ValidEnemy then
        -- No Combat
        if not Player.Combat then
            StartAttack()
            -- Enrage
            if Spell.Enrage:IsReady() and Player.Power < 10 and Target.Distance < 8 then
                if Spell.Enrage:Cast(Player) then return true end
            end
            -- Swipe
            if Spell.Swipe:IsReady() and #Enemies5Y >= 3 then
                if Spell.Swipe:Cast(Target) then return true end
            end
            -- Maul
            if Spell.Maul:IsReady() and (not Spell.Swipe:Known() or #Enemies5Y < 3) then
                if Spell.Maul:Cast(Target) then return true end
            end
        end
        -- In Combat
        if Player.Combat then
            StartAttack()
            -- Enrage
            if Spell.Enrage:IsReady() and Player.Power < 10 and Target.Distance < 8 then
                if Spell.Enrage:Cast(Player) then return true end
            end
            -- Demoralizing Roar
            if Spell.DemoralizingRoar:IsReady() and not Debuff.DemoralizingRoar:Exist(Target) and Target.Distance < 10 then
                if Spell.DemoralizingRoar:Cast(Target) then return true end
            end
            -- Swipe
            if Spell.Swipe:IsReady() and #Enemies5Y >= 3 then
                if Spell.Swipe:Cast(Target) then return true end
            end
            -- Maul
            if Spell.Maul:IsReady() and (not Spell.Swipe:Known() or #Enemies5Y < 3) then
                if Spell.Maul:Cast(Target) then return true end
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
                and (Debuff.Moonfire:Exist(Target) or UnitLevel("player") < 4)
                and (LastForm == nil or (LastForm:IsReady() and Target.Distance >= 8
                and Mana >= ShapeshiftCost(Spell.Wrath)))
            then
                if Spell.Wrath:Cast(Target) then return true end
            end
            -- Shapeshift
            if Setting("Auto-Shapeshifting") and LastForm ~= nil
                and ((LastForm:IsReady() and Mana < ShapeshiftCost(Spell.Wrath)
                and Mana < ShapeshiftCost(Spell.Moonfire)) or Target.Distance < 8)
            then
                if LastForm:Cast(Player) then return true end
            end
        end
    end
end

local function Cat()
    if Target and Target.ValidEnemy then
        if not Player.Combat then
            -- Rake
            if Spell.Rake:IsReady() and Debuff.Rake:Refresh(Target) then
                if Spell.Rake:Cast(Target) then return true end
            end
            -- Shred
            if Spell.Shred:IsReady() and not Facing then
                if Spell.Shred:Cast(Target) then return true end
            end
            -- Claw
            if Spell.Claw:IsReady() then
                if Spell.Claw:Cast(Target) then return true end
            end
            StartAttack()
        end
        if Player.Combat then
            StartAttack()
            -- Rip
            if Spell.Rip:IsReady() and ComboPoints == 5 then
                if Spell.Rip:Cast(Target) then return true end
            end
            if ComboPoints < 5 then
                -- Rake
                if Spell.Rake:IsReady() and Debuff.Rake:Refresh(Target) then
                    if Spell.Rake:Cast(Target) then return true end
                end
                -- Shred
                if Spell.Shred:IsReady() and not Facing then
                    if Spell.Shred:Cast(Target) then return true end
                end
                -- Claw
                if Spell.Claw:IsReady() and (Facing or not Spell.Shred:Known()) then
                    if Spell.Claw:Cast(Target) then return true end
                end
            end
        end
    end
end

function Druid.Rotation()
    Locals()
    if Rotation.Active() then
        -- Cancel Form To Speak to NPCs
        if Setting("Auto-Shapeshifting") and Target and Target.Friend and not Target.Dead and not Target.Player
            and Target.Distance < 8 and Shapeshifted
        then
            if CancelShapeshiftForm() then return end
        end
        if Defensive() then return true end
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