TTTBots.Components = TTTBots.Components or {}
TTTBots.Components.InventoryMgr = TTTBots.Components.InventoryMgr or {}

local lib = TTTBots.Lib
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
    print("Initializing")
    bot.components = bot.components or {}
    bot.components.InventoryMgr = self

    self.componentID = string.format("inventorymgr (%s)", lib.GenerateID()) -- Component ID, used for debugging

    self.tick = 0

    self.bot = bot
end

function BotInventoryMgr:GetWeaponInfo(wep)
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

    info.is_automatic = wep.Primary and wep.Primary.Automatic

    info.damage = wep.Primary and wep.Primary.Damage
    info.rpm = math.ceil(wep.Primary and (1 / wep.Primary.Delay) * 60)
    info.numshots = wep.Primary and wep.Primary.NumShots
    info.dpm = math.ceil(info.damage * info.numshots * info.rpm * (1 / 60))
    info.time_to_kill = math.ceil((100 / info.dps) * 100) / 100

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
    self.tick = (self.tick % 10000000) + 1

    if self.tick % 50 == 0 then
        PrintTable(self:GetAllWeaponInfo())
    end
    print("Thinking")
end
