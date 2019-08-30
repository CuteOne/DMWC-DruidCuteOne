local DMW = DMW
local Druid = DMW.Rotations.DRUID
local Player, Buff, Debuff, Health, HP, Power, Spell, Target, Trait, Talent, Item, GCD, CDs, HUD, Player40Y, Player40YC, Friends40Y, Friends40YC
local Rotation = DMW.Helpers.Rotation
local Setting = DMW.Helpers.Rotation.Setting

local function Locals()
    Player = DMW.Player
    Buff = Player.Buffs
    Debuff = Player.Debuffs
    Health = Player.Health
    HP = Player.HP
    Power = Player.PowerPct
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
end

local function Defensive()
    -- Entangling Roots
    if Setting("Entangling Roots") and Target and not Target.Facing and Target.Moving
        and not Debuff.EntanglingRoots:Exist(Target)
    then
        if Spell.EntanglingRoots:Cast(Target) then return true end
    end
    -- Healing Touch
    if Setting("Healing Touch") and HP < Setting("Healing Touch Percent") then
        if Spell.HealingTouch:Cast(Player) then return true end
    end
    -- Mark of the Wild
    if Setting("Mark of the Wild") then
        if Target and Target.Friend and Target.Player and not Buff.MarkOfTheWild:Exist(Target) then
            if Spell.MarkOfTheWild:Cast(Target) then return true end
        elseif not Buff.MarkOfTheWild:Exist(Player) then
            if Spell.MarkOfTheWild:Cast(Player) then return true end
        end
    end
    -- Rejuvenation
    if Setting("Rejuvenation") and not Buff.Rejuvenation:Exist(Player) and HP <= Setting("Rejuvenation Percent") then
        if Spell.Rejuvenation:Cast(Player) then return true end
    end
    -- Thorns
    if Setting("Thorns") and not Buff.Thorns:Exist(Player) then
        if Spell.Thorns:Cast(Player) then return true end
    end
end

local function Caster()
    if Target and Target.ValidEnemy then
        -- No Combat
        if not Player.Combat then
            StartAttack()
            -- Wrath
            if not Player.Moving then
                if Spell.Wrath:Cast(Target) then return true end
            end
        end
        -- In Combat
        if Player.Combat then
            StartAttack()
            -- Moonfire
            if not Debuff.Moonfire:Exist(Target) then
                if Spell.Moonfire:Cast(Target) then return true end
            end
            -- Wrath
            if not Player.Moving and (Debuff.Moonfire:Exist(Target) or UnitLevel("player") < 4) then
                if Spell.Wrath:Cast(Target) then return true end
            end
        end
    end
end

function Druid.Rotation()
    Locals()
    if Rotation.Active() then
        if Defensive() then return true end
        if Caster() then return true end
    end
end