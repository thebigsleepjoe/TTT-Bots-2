---@class CInventory
TTTBots.Components.InventoryMgr = TTTBots.Components.InventoryMgr or {}

local lib = TTTBots.Lib
---@class CInventory
local BotInventoryMgr = TTTBots.Components.InventoryMgr

function BotInventoryMgr:New(bot)
    local newInventoryMgr = {}
    setmetatable(newInventoryMgr, {
        __index = function(t, k) return BotInventoryMgr[k] end,
    })
    newInventoryMgr:Initialize(bot)

    local dbg = lib.GetConVarBool("debug_misc")
    if dbg then
        print("Initialized InventoryMgr for bot " .. bot:Nick())
    end

    return newInventoryMgr
end

function BotInventoryMgr:Initialize(bot)
    -- print("Initializing")
    bot.components = bot.components or {}
    bot.components.InventoryMgr = self

    self.componentID = string.format("inventorymgr (%s)", lib.GenerateID()) -- Component ID, used for debugging

    self.tick = 0

    self.bot = bot
end

---@class WeaponInfo Information about a weapon
---@field class string Classname of the weapon
---@field clip number CURRENT Ammo in the clip
---@field max_ammo number MAX Ammo in the clip
---@field ammo number Ammo in the inventory
---@field ammo_type number Ammo type of the weapon, https://wiki.facepunch.com/gmod/Default_Ammo_Types
---@field slot string Slot of the weapon, functionally just a string version of the Kind
---@field hold_type string Hold type of the weapon, typically used for animations
---@field is_gun boolean If the weapon is a gun (that is, if it has a clip or not)
---@field needs_reload boolean If the bot needs to reload this weapon, because it has 0 shots left
---@field should_reload boolean If the weapon has less than 100% ammo remaining. Only reload during peace
---@field has_bullets boolean If the weapon has any bullets in the **INVENTORY** (not clip!)
---@field print_name string Name of the weapon, more human readable than class
---@field kind number Kind of the weapon, https://wiki.facepunch.com/gmod/Enums/WEAPON
---@field ammo_ent string Classname of the ammo entity
---@field is_traitor_weapon boolean If the weapon is a traitor weapon
---@field is_detective_weapon boolean If the weapon is a detective weapon
---@field silent boolean If the weapon is silent
---@field can_drop boolean If the weapon can be dropped
---@field damage number Damage of the weapon
---@field rpm number Rounds per minute of the weapon
---@field numshots number Number of shots per fire
---@field dps number Damage per second of the weapon
---@field time_to_kill number Time to kill of the weapon
---@field is_automatic boolean If the weapon is automatic
---@field is_sniper boolean If the weapon is a sniper

---Returns the WeaponInfo table of the given entity
---@param wep Weapon
---@return WeaponInfo
function BotInventoryMgr:GetWeaponInfo(wep)
    if wep == nil then return end

    local info = {}
    -- Class of the weapon
    info.class = wep:GetClass()
    -- Ammo in the clip
    info.clip = wep:Clip1()
    -- Max ammo in the clip
    info.max_ammo = wep:GetMaxClip1()
    -- Ammo in the inventory
    info.ammo = self.bot:GetAmmoCount(wep:GetPrimaryAmmoType())
    -- Ammo type of the weapon
    info.ammo_type = wep:GetPrimaryAmmoType()
    -- Slot of the weapon, functionally just a string version of the Kind
    info.slot = (
        wep.Kind == 1 and "melee"
        or wep.Kind == 2 and "secondary"
        or wep.Kind == 3 and "primary"
        or wep.Kind == 4 and "grenade"
        or wep.Kind == 5 and "carry"
        or wep.Kind == 6 and "unarmed"
        or wep.Kind == 7 and "special"
        or wep.Kind == 8 and "extra"
        or wep.Kind == 9 and "class"
    )
    -- Hold type of the weapon
    info.hold_type = wep:GetHoldType()
    -- If the weapon is a gun
    info.is_gun = info.max_ammo > 0
    -- If the bot needs to reload this weapon (urgent)
    info.needs_reload = info.clip == 0
    -- If the bot should reload this weapon (non-urgent)
    info.should_reload = info.clip < info.max_ammo
    -- If the bot has bullets for this weapon
    info.has_bullets = info.ammo > 0
    -- Name of the weapon
    info.print_name = wep:GetPrintName()

    --[[
        info.kind:
        | WEAPON_PISTOL: small arms like the pistol and the deagle.
        | WEAPON_HEAVY: rifles, shotguns, machineguns.
        | WEAPON_NADE: grenades.
        | WEAPON_EQUIP1: special equipment, typically bought with credits and Traitor/Detective-only.
        | WEAPON_EQUIP2: same as above, secondary equipment slot. Players can carry one of each.
        | WEAPON_ROLE: special equipment that is default equipment for a role, like the DNA Scanner.
        | WEAPON_MELEE: only for the crowbar players get by default.
        | WEAPON_CARRY: only for the Magneto-stick, default equipment.
    ]]
    info.kind = wep.Kind -- Kind of the weapon
    --[[
        info.ammo_ent:
        | item_ammo_pistol_ttt: Pistol and M16 ammo.
        | item_ammo_smg1_ttt: SMG ammo, used by MAC10 and UMP.
        | item_ammo_revolver_ttt: Desert eagle ammo.
        | item_ammo_357_ttt: Sniper rifle ammo.
        | item_box_buckshot_ttt: Shotgun ammo.
    ]]
    info.ammo_ent = wep.AmmoEnt
    -- If the weapon is a traitor weapon
    info.is_traitor_weapon = table.HasValue(wep.CanBuy or {}, ROLE_TRAITOR)
    -- If the weapon is a detective weapon
    info.is_detective_weapon = table.HasValue(wep.CanBuy or {}, ROLE_DETECTIVE)
    -- If the weapon is silent
    info.silent = wep.IsSilent
    -- If we can drop it
    info.can_drop = wep.AllowDrop

    info.damage = wep.Primary and wep.Primary.Damage
    info.rpm = math.ceil(wep.Primary and (1 / wep.Primary.Delay) * 60)
    info.numshots = wep.Primary and wep.Primary.NumShots
    info.dps = math.ceil(info.damage * info.numshots * info.rpm * (1 / 60))
    info.time_to_kill = math.ceil((100 / info.dps) * 100) / 100

    info.is_automatic = wep.Primary and wep.Primary.Automatic
    -- we can infer if this is a sniper based off of the damage and if it's automatic
    info.is_sniper = info.damage and info.damage > 40 and not info.is_automatic
    return info
end

function BotInventoryMgr:GetAllWeaponInfo()
    local weapons = self.bot:GetWeapons()
    local weapon_info = {}
    for _, wep in pairs(weapons) do
        local info = self:GetWeaponInfo(wep)
        table.insert(weapon_info, info)
    end
    return weapon_info
end

function BotInventoryMgr:Think()
    local SLOWDOWN = 4
    self.tick = self.tick + 1

    if self.tick % SLOWDOWN ~= 0 or self.disabled then return end

    local primary = self:GetWeaponInfo(self:GetPrimary())
    local secondary = self:GetWeaponInfo(self:GetSecondary())
    if not (primary and primary.is_gun) then primary = nil end
    if not (secondary and secondary.is_gun) then secondary = nil end

    local isAttacking = self.bot.attackTarget ~= nil
    -- local personality = self.bot.components.personality
    local locomotor = self.bot.components.locomotor

    if not primary and not secondary then
        self:EquipMelee()
        return
    end

    if primary and primary.has_bullets then
        self:EquipPrimary()
    elseif secondary and secondary.has_bullets then
        self:EquipSecondary()
    else
        self:EquipMelee()
        return
    end

    local current = self:GetHeldWeaponInfo()
    if not (current and current.is_gun) then return end

    if current.needs_reload then
        locomotor:StopAttack()
        locomotor:Reload()
    end
end

---Returns the weapon info table for the weapon we are holding, or what the target is holding if any.
---@param target Player|nil
---@return table
function BotInventoryMgr:GetHeldWeaponInfo(target)
    if not target then
        return self:GetWeaponInfo(self.bot:GetActiveWeapon())
    end

    local wep = target:GetActiveWeapon()
    if not IsValid(wep) then return end
    return self:GetWeaponInfo(wep)
end

function BotInventoryMgr:GetPrimary()
    -- info.slot == "primary"
    local weapons = self.bot:GetWeapons()
    for _, wep in pairs(weapons) do
        local info = self:GetWeaponInfo(wep)
        if info.slot == "primary" then
            return wep
        end
    end
end

function BotInventoryMgr:GetSecondary()
    -- info.slot == "secondary"
    local weapons = self.bot:GetWeapons()
    for _, wep in pairs(weapons) do
        local info = self:GetWeaponInfo(wep)
        if info.slot == "secondary" then
            return wep
        end
    end
end

function BotInventoryMgr:GetCrowbar()
    -- info.slot == "melee"
    local weapons = self.bot:GetWeapons()
    for _, wep in pairs(weapons) do
        local info = self:GetWeaponInfo(wep)
        if info.slot == "melee" then
            return wep
        end
    end
end

function BotInventoryMgr:GetGrenade()
    -- info.slot == "grenade"
    local weapons = self.bot:GetWeapons()
    for _, wep in pairs(weapons) do
        local info = self:GetWeaponInfo(wep)
        if info.slot == "grenade" then
            return wep
        end
    end
end

function BotInventoryMgr:GetWeaponByName(name)
    local weapons = self.bot:GetWeapons()
    for _, wep in pairs(weapons) do
        local info = self:GetWeaponInfo(wep)
        if info.print_name == name then
            return wep
        end
    end
end

--- Equips the wep in the bot's hands. wep can be a string or a weapon object. If it is a string then it has the following opts:
--- 1. "primary": equips the bot's primary weapon
--- 2. "secondary": equips the bot's secondary weapon
--- 3. "melee": equips the bot's melee weapon
--- 4. "grenade": equips the bot's grenade
--- 5. "weapon_name": equips the bot's weapon with the given name
---<p>Otherwise, wep is a weapon object and it is equipped.</p>
function BotInventoryMgr:Equip(wep)
    local found
    if type(wep) == "string" then
        local funcTbl = {
            primary = self.GetPrimary,
            secondary = self.GetSecondary,
            melee = self.GetCrowbar,
            grenade = self.GetGrenade,
        }
        if funcTbl[wep] then
            found = funcTbl[wep](self)
        else
            found = self:GetWeaponByName(wep)
        end
    else
        found = wep
    end

    if found then
        -- self.bot:SelectWeapon(found) apparently this only works with classnames and not weapon objects...
        self.bot:SelectWeapon(found:GetClass())
    end

    return (found ~= nil)
end

function BotInventoryMgr:EquipPrimary()
    return self:Equip("primary")
end

function BotInventoryMgr:EquipSecondary()
    return self:Equip("secondary")
end

function BotInventoryMgr:EquipMelee()
    -- return self:Equip("melee")
    return self.bot:SelectWeapon("weapon_zm_improvised")
end

function BotInventoryMgr:EquipGrenade()
    return self:Equip("grenade")
end

function BotInventoryMgr:GetInventoryString()
    local weapons = self.bot:GetWeapons()
    local str = ""
    for _, wep in pairs(weapons) do
        -- example "\nPrimary weapon_name (DPS: 100; TTK: 2.5s)"
        local info = self:GetWeaponInfo(wep)
        local slot = info.slot
        local name = info.print_name
        local dps = info.dps
        local ttk = info.time_to_kill

        str = str .. string.format("\n%s %s (DPS: %s; TTK: %ss)", slot, name, dps, ttk)
    end
    return str
end
