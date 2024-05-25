---@class CInventory : Component
TTTBots.Components.Inventory = {}

local lib = TTTBots.Lib
---@class CInventory : Component
local BotInventory = TTTBots.Components.Inventory

function BotInventory:New(bot)
    local newInventory = {}
    setmetatable(newInventory, {
        __index = function(t, k) return BotInventory[k] end,
    })
    newInventory:Initialize(bot)

    local dbg = lib.GetConVarBool("debug_misc")
    if dbg then
        print("Initialized Inventory for bot " .. bot:Nick())
    end

    return newInventory
end

function BotInventory:Initialize(bot)
    -- print("Initializing")
    bot.components = bot.components or {}
    bot.components.Inventory = self

    self.componentID = string.format("inventory (%s)", lib.GenerateID()) -- Component ID, used for debugging

    self.tick = 0
    self.disabled = false

    self.bot = bot
end

---@class WeaponInfo Information about a weapon
---@field class string Classname of the weapon
---@field clip number CURRENT Ammo in the clip
---@field max_ammo number MAX Ammo in the clip
---@field ammo number Ammo in the inventory
---@field ammo_type number Ammo type of the weapon, https://wiki.facepunch.com/gmod/Default_Ammo_Types
---@field ammo_type_string string Ammo type of the string, after having been converted from the number. See ammo_type.
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
---@field is_shotgun boolean If the weapon is a shotgun
---@field is_melee boolean If the weapon is a shotgun
---@field timestamp number The CurTime() when this info was last updated

--- A hash table for the ammo_type field in an info table. See https://wiki.facepunch.com/gmod/Default_Ammo_Types
local ammoTypes = {
    [1] = { name = "ar2", description = "weapon_ar2 ammo" },
    [2] = { name = "ar2altfire", description = "weapon_ar2 altfire ammo" },
    [3] = { name = "pistol", description = "weapon_pistol ammo" },
    [4] = { name = "smg1", description = "weapon_smg1 ammo" },
    [5] = { name = "357", description = "weapon_357 ammo" },
    [6] = { name = "xbowbolt", description = "weapon_crossbow ammo" },
    [7] = { name = "buckshot", description = "weapon_shotgun ammo" },
    [8] = { name = "rpg_round", description = "weapon_rpg ammo" },
    [9] = { name = "smg1_grenade", description = "weapon_smg1 altfire ammo" },
    [10] = { name = "grenade", description = "weapon_frag ammo" },
    [11] = { name = "slam", description = "weapon_slam ammo" },
    [12] = { name = "alyxgun", description = "weapon_alyxgun ammo" },
    [13] = { name = "sniperround", description = "combine sniper ammo" },
    [14] = { name = "sniperpenetratedround", description = "combine sniper alternate ammo" },
    [15] = { name = "thumper", description = "" },
    [16] = { name = "gravity", description = "" },
    [17] = { name = "battery", description = "" },
    [18] = { name = "gaussenergy", description = "" },
    [19] = { name = "combinecannon", description = "" },
    [20] = { name = "airboatgun", description = "airboat mounted gun ammo" },
    [21] = { name = "striderminigun", description = "strider minigun ammo" },
    [22] = { name = "helicoptergun", description = "attack helicopter ammo" },
    [23] = { name = "9mmround", description = "hl:s pistol ammo" },
    [24] = { name = "357round", description = "hl:s .357 ammo" },
    [25] = { name = "buckshothl1", description = "hl:s shotgun ammo" },
    [26] = { name = "xbowbolthl1", description = "hl:s crossbow ammo" },
    [27] = { name = "mp5_grenade", description = "hl:s mp5 grenade ammo" },
    [28] = { name = "rpg_rocket", description = "hl:s rocket launcher ammo" },
    [29] = { name = "uranium", description = "hl:s gauss/gluon gun ammo" },
    [30] = { name = "grenadehl1", description = "hl:s grenade ammo" },
    [31] = { name = "hornet", description = "hl:s hornet ammo" },
    [32] = { name = "snark", description = "hl:s snark ammo" },
    [33] = { name = "tripmine", description = "hl:s tripmine ammo" },
    [34] = { name = "satchel", description = "hl:s satchel charge ammo" },
    [35] = { name = "12mmround", description = "hl:s related ammo (heavy turret entity?)" },
    [36] = { name = "striderminigundirect", description = "npc_strider \"enableaggressivebehavior\" ammo (less damage)" },
    [37] = { name = "combineheavycannon", description = "the \"combine autogun\" ammo from half-life 2: episode 2" }
}

BotInventory.wInfoCache = {} ---@type table<Weapon, WeaponInfo>
BotInventory.wInfoCacheTime = 1 --- Number of seconds before a cached weapon info is invalidated.

---Validate the cache for the weapon. Also returns the WeaponInfo if it's valid, otherwise nil.
---@param wep Weapon
---@return WeaponInfo?
local function cacheValidate(wep)
    local timeNow = CurTime()
    local cache = BotInventory.wInfoCache[wep]
    if not cache then return nil end

    if timeNow - cache.timestamp > BotInventory.wInfoCacheTime then
        BotInventory.wInfoCache[wep] = nil
        return nil
    end
end

---Returns the WeaponInfo table of the given entity
---@param wep Weapon
---@return WeaponInfo
function BotInventory:GetWeaponInfo(wep)
    if not (wep and IsValid(wep)) then
        ErrorNoHaltWithStack("Invalid weapon object passed to GetWeaponInfo")
        error("Invalid weapon object passed to GetWeaponInfo")
    end

    local cache = cacheValidate(wep)
    if cache then return cache end

    local info = {
        __tostring = function(obj) return BotInventory:GetWepInfoText(obj) end
    }
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
    -- The string version of the ammo type
    info.ammo_type_string = ammoTypes[info.ammo_type] and ammoTypes[info.ammo_type].name or "unknown"
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
    -- If it is a shotgun
    info.is_shotgun = string.find(info.ammo_type_string or "", "buckshot") ~= nil
    -- If it is melee
    info.is_melee = info.clip == -1

    info.damage = wep.Primary and wep.Primary.Damage or 1
    local rps = wep.Primary and (1 / (wep.Primary.Delay or 1)) or 1
    info.rpm = math.ceil(rps * 60) or 1
    info.numshots = wep.Primary and wep.Primary.NumShots or 1
    info.dps = math.ceil(info.damage * info.numshots * rps) or 1
    info.time_to_kill = (math.ceil((100 / info.dps) * 100) / 100) or 1

    info.is_automatic = (wep.Primary and wep.Primary.Automatic) or false
    -- we can infer if this is a sniper based off of the damage and if it's automatic
    info.is_sniper = (info.damage and info.damage > 40 and not info.is_automatic) or false

    info.timestamp = CurTime()

    -- Place this wep/info into the cache.
    BotInventory.wInfoCache[wep] = info

    return info
end

function BotInventory:GetAllWeaponInfo()
    local weapons = self.bot:GetWeapons()
    local weapon_info = {}
    for _, wep in pairs(weapons) do
        local info = self:GetWeaponInfo(wep)
        table.insert(weapon_info, info)
    end
    return weapon_info
end

--- get the first special (buyable) primary we have (aka, a buyable we should use as a primary)
---@return Weapon|nil wep The weapon object (not a wepinfo)
function BotInventory:GetSpecialPrimary()
    local specialClasses = TTTBots.Buyables.PrimaryWeapons

    for class, _ in pairs(specialClasses) do
        local wep = self.bot:GetWeapon(class)
        if IsValid(wep) then
            return wep
        end
    end
end

---Return true if the bot has a valid WeaponInfo wep and it has > 0 bullets in the clip. Tests for nil.
---@param wepInfo WeaponInfo?
---@return boolean
function BotInventory:WepInfoHasClip(wepInfo)
    return (wepInfo and wepInfo.has_bullets and wepInfo.clip > 0) or false
end

function BotInventory:WepHasClip(wep)
    return (wep and IsValid(wep) and wep:Clip1() > 0) or false
end

---Get if the bots has no other weapons besides melee (false) or not (true)
---@param attackMode boolean Set to true if you want to check the weapons have ammo in reserve, not just in the clip
---@return boolean
function BotInventory:HasNoWeaponAvailable(attackMode)
    local toCheck = {
        self:GetSpecialPrimary(),
        self:GetPrimary(),
        self:GetSecondary()
    }

    for i, v in pairs(toCheck) do
        if not IsValid(v) then continue end
        local wInfo = self:GetWeaponInfo(v)
        local hasReserve = wInfo.has_bullets
        local hasAmmo = wInfo.clip > 0

        if attackMode then
            if hasReserve and hasAmmo then return false end
        else
            if hasReserve then return false end
        end
    end

    return true
end

--- Manage our own inventory by selecting the best weapon, queueing a reload if necessary, etc.
function BotInventory:AutoManageInventory()
    local SLOWDOWN = math.floor(TTTBots.Tickrate / 2) -- about twice per second
    if self.tick % SLOWDOWN ~= 0 or self.disabled then return end

    local forcedClass = lib.GetConVarString('debug_forceweapon')
    if forcedClass ~= "" then
        if not self.bot:HasWeapon(forcedClass) then
            self.bot:Give(forcedClass)
        end
        self.bot:SelectWeapon(forcedClass)

        local held = self:GetHeldWeaponInfo()
        if not held then return end
        if not held.needs_reload then return end

        local loco = self.bot:BotLocomotor()

        if not loco then return end
        loco:Reload()

        return
    end

    local w_special = self:GetSpecialPrimary()
    local special = w_special and self:GetWeaponInfo(w_special) or nil
    local primary = self:GetPrimary()
    local secondary = self:GetSecondary()

    -- local isAttacking = self.bot.attackTarget ~= nil

    local hash = {
        [self.EquipSpecial] = special,
        [self.EquipPrimary] = primary,
        [self.EquipSecondary] = secondary,
        [self.EquipMelee] = self:HasNoWeaponAvailable(false),
    }

    for func, wepInfo in pairs(hash) do
        if wepInfo == true or (type(wepInfo) == "table" and wepInfo.ammo or 0) > 0 then
            func(self)
            break
        end
    end

    local current = self:GetHeldWeaponInfo()
    if not (current and current.is_gun) then return end

    local locomotor = self.bot:BotLocomotor()
    if current.needs_reload then
        locomotor:StopAttack()
        locomotor:Reload()
    end
end

--- Reload the currently held weapon if it has less ammo in the 1st clip than its maximum, if it also has ammo in reserve.
---@return boolean reloading If we are reloading
function BotInventory:ReloadIfNecessary()
    local heldWep = self:GetHeldWeaponInfo(self.bot)
    if not (heldWep and heldWep.is_gun) then return false end

    local reload = heldWep.should_reload

    if reload then
        local loco = self.bot:BotLocomotor() ---@type CLocomotor
        loco:StopAttack()
        loco:StopAttack2()
        loco:Reload()
    end

    return reload
end

--- Gives the bot weapon_ttt_c4 if he doesn't have it already.
function BotInventory:GiveC4()
    local hasC4 = false
    local weapons = self.bot:GetWeapons()
    for _, wep in pairs(weapons) do
        if wep:GetClass() == "weapon_ttt_c4" then
            hasC4 = true
            break
        end
    end

    if not hasC4 then
        self.bot:Give("weapon_ttt_c4")
    end
end

function BotInventory:PauseAutoSwitch()
    self.pauseAutoSwitch = true
end

function BotInventory:ResumeAutoSwitch()
    self.pauseAutoSwitch = false
end

function BotInventory:Think()
    if not lib.IsPlayerAlive(self.bot) then return end
    if lib.GetDebugFor("inventory") then
        self:PrintInventory()
    end
    self.tick = self.tick + 1

    if not IsValid(self.bot.attackTarget) then
        self:ReloadIfNecessary()
    end

    -- Manage our own inventory, but only if we have not been paused
    if self.pauseAutoSwitch then return end
    self:AutoManageInventory()
end

--- Return the jackal gun (weapon_ttt2_sidekickdeagle) if it has >0 shots. If not, then return nil.
---@return WeaponInfo?
function BotInventory:GetJackalGun()
    local hasWeapon = self.bot:HasWeapon("weapon_ttt2_sidekickdeagle")
    if not hasWeapon then return end
    local wep = self.bot:GetWeapon("weapon_ttt2_sidekickdeagle")
    if not IsValid(wep) then return end

    return wep:Clip1() > 0 and wep or nil
end

--- Equip the Jackal's Sidekick Deagle if we have it. Returns true if we equipped it, false if we didn't.
--- Doesn't error if we don't have it.
---@return boolean
function BotInventory:EquipJackalGun()
    local gun = self:GetJackalGun()
    if not gun then return false end
    self.bot:SetActiveWeapon(gun)
    return true
end

---Returns the weapon info table for the weapon we are holding, or what the target is holding if any.
---@param target Player|nil
---@return WeaponInfo?
function BotInventory:GetHeldWeaponInfo(target)
    if not target then
        local wep = self.bot:GetActiveWeapon()

        if not (wep and IsValid(wep)) then return nil end

        return self:GetWeaponInfo(wep)
    end

    local wep = target:GetActiveWeapon()
    if not IsValid(wep) then return nil end
    return self:GetWeaponInfo(wep)
end

---@return WeaponInfo?
function BotInventory:GetPrimary()
    -- info.slot == "primary"
    local weapons = self.bot:GetWeapons()
    for _, wep in pairs(weapons) do
        local info = self:GetWeaponInfo(wep)
        if info.slot == "primary" then
            return wep
        end
    end

    return nil
end

---@return WeaponInfo?
function BotInventory:GetSecondary()
    -- info.slot == "secondary"
    local weapons = self.bot:GetWeapons()
    for _, wep in pairs(weapons) do
        local info = self:GetWeaponInfo(wep)
        if info.slot == "secondary" then
            return wep
        end
    end

    return nil
end

---@return WeaponInfo?
function BotInventory:GetCrowbar()
    -- info.slot == "melee"
    local weapons = self.bot:GetWeapons()
    for _, wep in pairs(weapons) do
        local info = self:GetWeaponInfo(wep)
        if info.slot == "melee" then
            return wep
        end
    end

    return nil
end

---@return WeaponInfo?
function BotInventory:GetGrenade()
    -- info.slot == "grenade"
    local weapons = self.bot:GetWeapons()
    for _, wep in pairs(weapons) do
        local info = self:GetWeaponInfo(wep)
        if info.slot == "grenade" then
            return wep
        end
    end

    return nil
end

---@return WeaponInfo?
function BotInventory:GetWeaponByName(name)
    local weapons = self.bot:GetWeapons()
    for _, wep in pairs(weapons) do
        local info = self:GetWeaponInfo(wep)
        if info.print_name == name then
            return wep
        end
    end

    return nil
end

--- Gets the debug/stylized text for the given weapon info. Used to check the ammo and weapon type.
---@param wepInfo any
---@return string str Formatted info string
function BotInventory:GetWepInfoText(wepInfo)
    if not wepInfo then return "nil" end
    local ammoLeft = wepInfo.clip or 0
    local ammoMax = wepInfo.max_ammo or 0
    local heldAmmo = wepInfo.ammo or 0
    local wepText = string.format("%s (%d/%d) [%d left]", wepInfo.print_name, ammoLeft, ammoMax, heldAmmo)

    return wepText
end

--- Equips the wep in the bot's hands. wep can be a string or a weapon object. If it is a string then it has the following opts:
--- 1. "primary": equips the bot's primary weapon
--- 2. "secondary": equips the bot's secondary weapon
--- 3. "melee": equips the bot's melee weapon
--- 4. "grenade": equips the bot's grenade
--- 5. "weapon_name": equips the bot's weapon with the given name
---<p>Otherwise, wep is a weapon object and it is equipped.</p>
function BotInventory:Equip(wep)
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

function BotInventory:EquipSpecial()
    local firstSpecial = self:GetSpecialPrimary()
    if not (firstSpecial and IsValid(firstSpecial)) then return false end
    self.bot:SelectWeapon(firstSpecial)
    return true
end

function BotInventory:EquipPrimary()
    return self:Equip("primary")
end

function BotInventory:EquipSecondary()
    return self:Equip("secondary")
end

function BotInventory:EquipMelee()
    -- return self:Equip("melee")
    return self.bot:SelectWeapon("weapon_zm_improvised")
end

function BotInventory:EquipGrenade()
    return self:Equip("grenade")
end

function BotInventory:GetInventoryString()
    local weapons = self.bot:GetWeapons()
    local str = ""
    for _, wep in pairs(weapons) do
        local info = self:GetWeaponInfo(wep)
        local slot = info.slot
        local name = info.print_name
        local dps = info.dps
        local ttk = info.time_to_kill
        local clip = info.clip or 0
        local max = info.max_ammo or 0
        local total = info.ammo --- how much ammo in inv
        local needsReload = info.needs_reload

        local shotstring = info.is_shotgun and "(shotgun)" or ""

        -- example "\nPrimary weapon_name (DPS: 100; TTK: 2.5s) [8/10 shots, of %d]"
        str = str ..
            string.format("\n%s %s %s (DPS: %s; TTK: %ss) [%d/%d shots, of %d]. {NeedsReload=%s, ammo_type_string=%s}",
                slot, shotstring, name, dps, ttk, clip, max, total, needsReload, info.ammo_type_string)
    end
    return str
end

local function printf(str, ...)
    print(string.format(str, ...))
end

function BotInventory:PrintInventory()
    printf("===III=== Inventory for bot %s ===III===", self.bot:Nick())
    printf(self:GetInventoryString())
    printf("===III=== End inventory ===III===")
end

---@class Player
local plyMeta = FindMetaTable("Player")

---@return CInventory
function plyMeta:BotInventory()
    ---@cast self Bot
    return self.components.inventory
end
