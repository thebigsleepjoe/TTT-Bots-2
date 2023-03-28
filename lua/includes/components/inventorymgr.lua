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

    self.bot = bot
end

function BotInventoryMgr:GetWeaponInfo(wep)
    local info = {}
    info.class = wep:GetClass()                                 -- Class of the weapon
    info.clip = wep:Clip1()                                     -- Ammo in the clip
    info.max_ammo = wep:GetMaxClip1()                           -- Max ammo in the clip
    info.ammo = self.bot:GetAmmoCount(wep:GetPrimaryAmmoType()) -- Ammo in the inventory
    info.ammo_type = wep:GetPrimaryAmmoType()                   -- Ammo type of the weapon
    info.slot = wep:GetSlot()                                   -- Slot of the weapon
    info.hold_type = wep:GetHoldType()                          -- Hold type of the weapon
    info.is_gun = info.ammo_type == -1                          -- If the weapon is a gun
    info.needs_reload = info.clip == 0                          -- If the bot needs to reload this weapon (urgent)
    info.should_reload = info.clip < info.max_ammo              -- If the bot should reload this weapon (non-urgent)
    info.has_bullets = info.ammo > 0                            -- If the bot has bullets for this weapon
    info.print_name = wep:GetPrintName()                        -- Name of the weapon

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
    info.ammo_ent = wep.AmmoEnt                                                 -- Entity name for the ammo of the weapon
    info.is_traitor_weapon = table.HasValue(wep.CanBuy or {}, ROLE_TRAITOR)     -- If the weapon is a traitor weapon
    info.is_detective_weapon = table.HasValue(wep.CanBuy or {}, ROLE_DETECTIVE) -- If the weapon is a detective weapon
    info.silent = wep.IsSilent                                                  -- If the weapon is silent
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
    PrintTable(self:GetAllWeaponInfo())
    print("Thinking")
end
