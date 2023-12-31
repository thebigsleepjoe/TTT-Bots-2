---@diagnostic disable: missing-fields
local Registry = {}

---@type Buyable
Registry.C4 = {
    Name = "C4",
    Class = "weapon_ttt_c4",
    Price = 1,
    Priority = 1,
    RandomChance = 1, -- 1 since chance is calculated in CanBuy
    ShouldAnnounce = false,
    AnnounceTeam = false,
    CanBuy = function(ply)
        local personality = TTTBots.Lib.GetComp(ply, "personality") ---@type CPersonality
        if not personality then return false end
        return (personality:GetTraitBool("planter")) or math.random(1, 3) == 1 -- Less likely to buy C4 if not a planter.
    end,
    Roles = { "traitor" },
}

---@type Buyable
Registry.HealthStation = {
    Name = "Health Station",
    Class = "weapon_ttt_health_station",
    Price = 1,
    Priority = 1,
    RandomChance = 1, -- 1 since chance is calculated in CanBuy
    ShouldAnnounce = false,
    AnnounceTeam = false,
    CanBuy = function(ply)
        local personality = TTTBots.Lib.GetComp(ply, "personality") ---@type CPersonality
        if not personality then return false end
        return (personality:GetTraitBool("healer")) or
            math.random(1, 3) ==
            1 -- Less likely to buy health station if not a healer.
    end,
    Roles = { "detective" },
}

---@type Buyable
Registry.Defuser = {
    Name = "Defuser",
    Class = "weapon_ttt_defuser",
    Price = 1,
    Priority = 1,
    RandomChance = 1, -- 1 since chance is calculated in CanBuy
    ShouldAnnounce = false,
    AnnounceTeam = false,
    CanBuy = function(ply)
        local personality = TTTBots.Lib.GetComp(ply, "personality") ---@type CPersonality
        if not personality then return false end
        return (personality:GetTraitBool("defuser")) or
            math.random(1, 3) ==
            1 -- Less likely to buy defuser if not a defuser.
    end,
    Roles = { "detective" },
}

for key, data in pairs(Registry) do
    TTTBots.Buyables.RegisterBuyable(data)
end
