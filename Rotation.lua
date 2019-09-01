local DMW = DMW
local Druid = DMW.Rotations.DRUID
local Player, Buff, Debuff, Health, HP, Power, Spell, Target, Trait, Talent, Item, GCD, CDs, HUD, Player40Y, Player40YC, Friends40Y, Friends40YC
local Rotation = DMW.Helpers.Rotation
local Setting = DMW.Helpers.Rotation.Setting
local LastForm = "Caster Form"
local Shapeshifted

local function Locals()
    Player = DMW.Player
    Buff = Player.Buffs
    Debuff = Player.Debuffs
    Health = Player.Health
    HP = (Player.Health / Player.HealthMax) * 100
    Power = Player.Power
    Spell = Player.Spells
    Talent = Player.Talents
    Trait = Player.Traits
    Item = Player.Items
    Target = Player.Target or false
    GCD = Player:GCD()
    HUD = DMW.Settings.profile.HUD
    CDs = Player:CDs() and Target and Target.TTD > 5 and Target.Distance < 5
    Friends40Y, Friends40YC = Player:GetFriends(40)
    Player40Y, Player40YC = Player:GetEnemies(40)
    MeleeAggro = false
    for _, Unit in ipairs(Player40Y) do
        if Unit.Distance < 5 and Player.Pointer == Unit.Target then
            MeleeAggro = true
        end
    end
    Shapeshifted = Buff.DireBearForm:Exist(Player) or Buff.BearForm:Exist(Player) or Buff.CatForm:Exist(Player) 
        or Buff.MoonkinForm:Exist(Player) or Buff.TravelForm:Exist(Player) or Buff.AquaticForm:Exist(Player)
end

local function CancelForm()
    if Buff.CatForm:Exist(Player) then
        LastForm = "Cat Form"
        CancelShapeshiftForm()
    end
    if Buff.BearForm:Exist(Player) then
        LastForm = "Bear Form"
        CancelShapeshiftForm()
    end
end

local function Defensive()
    -- Return to Last Form
    if LastForm ~= "Caster Form" then
        if LastForm == "Bear Form" then
            if Spell.BearForm:Cast(Player) then LastForm = "Caster Form" return end
        end
        if LastForm == "Cat Form" then
            if Spell.CatForm:Cast(Player) then LastForm = "Caster Form" return end
        end
    end
    -- Entangling Roots
    if Setting("Entangling Roots") and Target and not ObjectIsFacing("target","player") and Target.Moving
        and Target.ValidEnemy and not Debuff.EntanglingRoots:Exist(Target) and Target.Distance > 8
        and Player.Combat and not Spell.EntanglingRoots:LastCast()
    then
        CancelForm()
        if Spell.EntanglingRoots:Cast(Target) then return true end
    end
    -- Healing Touch
    if Setting("Healing Touch")
        and ((not Player.Combat and HP <= Setting("Healing Touch Percent"))
            or (Player.Combat and HP <= Setting("Healing Touch Percent") / 2))
    then
        CancelForm()
        if Spell.HealingTouch:Cast(Player) then return true end
    end
    -- Mark of the Wild
    if Setting("Mark of the Wild") then
        if Target and Target.Friend and Target.Player and not Buff.MarkOfTheWild:Exist(Target) then
            if not Player.Combat then CancelForm() end
            if Spell.MarkOfTheWild:Cast(Target) then return true end
        elseif not Buff.MarkOfTheWild:Exist(Player) then
            if not Player.Combat then CancelForm() end
            if Spell.MarkOfTheWild:Cast(Player) then return true end
        end
    end
    -- Regrowth
    if Setting("Regrowth") and not Buff.Regrowth:Exist(Player)
        and not Player.Combat and HP <= Setting("Regrowth Percent")
    then
        CancelForm()
        if Spell.Regrowth:Cast(Player) then return true end
    end
    -- Rejuvenation
    if Setting("Rejuvenation") and not Buff.Rejuvenation:Exist(Player)
        and not Player.Combat and HP <= Setting("Rejuvenation Percent")
    then
        CancelForm()
        if Spell.Rejuvenation:Cast(Player) then return true end
    end
    -- Thorns
    if Setting("Thorns") and not Player.Combat and not Buff.Thorns:Exist(Player) then
        CancelForm()
        if Spell.Thorns:Cast(Player) then return true end
    end
end

local function Bear()
    if Target and Target.ValidEnemy then
        -- No Combat
        if not Player.Combat then
            StartAttack()
            -- Enrage 
            if Player.Power < 10 and Target.Distance < 8 then
                if Spell.Enrage:Cast(Player) then return true end
            end
            -- Maul
            if Spell.Maul:Cast(Target) then return true end
        end
        -- In Combat
        if Player.Combat then
            StartAttack()
            -- Demoralizing Roar
            if not Debuff.DemoralizingRoar:Exist(Target) and Target.Distance < 10 then
                if Spell.DemoralizingRoar:Cast(Target) then return true end
            end
            -- Maul
            if Spell.Maul:Cast(Target) then return true end
        end
    end
end

local function Caster()
    local knowsBear = IsSpellKnown(Spell.BearForm.SpellID)
    local bearCost = GetSpellPowerCost(Spell.BearForm.SpellID)[1].cost
    local wrathCost = GetSpellPowerCost(Spell.Wrath.SpellID)[1].cost
    local mfCost = GetSpellPowerCost(Spell.Moonfire.SpellID)[1].cost
    local knowsCat = IsSpellKnown(Spell.CatForm.SpellID)
    local function canCast(checkCost)
        return UnitPower("player",0) > checkCost
    end
    if Target and Target.ValidEnemy then
        -- No Combat
        if not Player.Combat then
            StartAttack()
            -- Wrath
            if not Player.Moving and not Spell.Wrath:LastCast() then
                if Spell.Wrath:Cast(Target) then return true end
            end
            -- Moonfire
            if Player.Moving or Spell.Wrath:LastCast() then
                if Spell.Moonfire:Cast(Target) then return true end
            end
        end
        -- In Combat
        if Player.Combat then
            StartAttack()
            -- Moonfire
            if not Debuff.Moonfire:Exist(Target) and (not knowsBear
                or (Spell.BearForm:IsReady() and canCast(mfCost + bearCost)
                and Target.Distance >= 8))
            then
                if Spell.Moonfire:Cast(Target) then return true end
            end
            -- Wrath
            if not Player.Moving and (Debuff.Moonfire:Exist(Target) or UnitLevel("player") < 4)
                and (not knowsBear or (Spell.BearForm:IsReady() and canCast(wrathCost + bearCost)
                and Target.Distance >= 8))
            then
                if Spell.Wrath:Cast(Target) then return true end
            end
            -- Shapeshift
            if not (canCast(wrathCost + bearCost) and canCast(mfCost + bearCost)) or Target.Distance < 8 then
                if knowsCat then
                    if Spell.CatForm:Cast(Player) then return true end
                end
                if knowsBear then
                    if Spell.BearForm:Cast(Player) then return true end
                end
            end
        end
    end
end

function Druid.Rotation()
    Locals()
    if Rotation.Active() then
        -- Cancel Form To Speak to NPCs
        if Target and Target.Friend and not Target.Dead and not Target.Player
            and Target.Distance < 8 and Shapeshifted
        then
            if CancelShapeshiftForm() then return end
        end
        if Defensive() then return true end
        if not Buff.CatForm:Exist(Player) and not Buff.BearForm:Exist(Player) then
            if Caster() then return true end
        end
        if Buff.BearForm:Exist(Player) then
            if Bear() then return true end
        end
    end
end