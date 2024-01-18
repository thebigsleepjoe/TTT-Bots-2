TTTBots.Buyables = {}
TTTBots.Buyables.m_buyables = {}
TTTBots.Buyables.m_buyables_role = {}
local buyables = TTTBots.Buyables.m_buyables
local buyables_role = TTTBots.Buyables.m_buyables_role

---@class Buyable
---@field Name string - The pretty name of this item.
---@field Class string - The class of this item.
---@field Price number - The price of this item, in credits. Bots are given an allowance of 2 credits.
---@field Priority number - The priority of this item. Higher numbers = higher priority. If two buyables have the same priority, the script will select one at random.
---@field OnBuy function? - Called when the bot successfully buys this item.
---@field CanBuy function? - Return false to prevent a bot from buying this item.
---@field Roles table<string> - A table of roles that can buy this item.
---@field RandomChance number? - An integer from 1 to math.huge. Functionally the item will be selected if random(1, RandomChoice) == 1.
---@field ShouldAnnounce boolean? - Should this create a chatter event?
---@field AnnounceTeam boolean? - Is announcing team-only?
---@field BuyFunc function? - A function called to "buy" the Class. By default, just calls function(ply) ply:Give(Class) end
---@field TTT2 boolean? - Is this TTT2 specific?


--- Return a buyable item by its name.
---@param name string - The name of the buyable item.
---@return Buyable|nil - The buyable item, or nil if it does not exist.
function TTTBots.Buyables.GetBuyable(name) return buyables[name] end

---Return a list of buyables for the given rolestring. Defaults to an empty table.
---The result is ALWAYS sorted by priority, descending.
---@param roleString string
---@return table<Buyable>
function TTTBots.Buyables.GetBuyablesFor(roleString) return buyables_role[roleString] or {} end

---Adds the given Buyable data to the roleString. This is called automatically when registering a Buyable, but exists for sanity.
---@param buyable Buyable
---@param roleString string
function TTTBots.Buyables.AddBuyableToRole(buyable, roleString)
    buyables_role[roleString] = buyables_role[roleString] or {}
    table.insert(buyables_role[roleString], buyable)
    table.sort(buyables_role[roleString], function(a, b) return a.Priority > b.Priority end)
end

---Purchases any registered buyables for the given bot's rolestring. Returns a table of Buyables that were successfully purchased.
---@param bot any
---@return table<Buyable>
function TTTBots.Buyables.PurchaseBuyablesFor(bot)
    local roleString = bot:GetRoleStringRaw()
    local options = TTTBots.Buyables.GetBuyablesFor(roleString)
    local creditAllowance = 2
    local purchased = {}

    for i, option in pairs(options) do
        if option.TTT2 and not TTTBots.Lib.IsTTT2() then continue end                      -- for mod compat.
        if option.Class and not TTTBots.Lib.WepClassExists(option.Class) then continue end -- for mod compat.
        if option.Price > creditAllowance then continue end
        if option.CanBuy and not option.CanBuy(bot) then continue end
        if option.RandomChance and math.random(1, option.RandomChance) ~= 1 then continue end

        creditAllowance = creditAllowance - option.Price
        table.insert(purchased, option)
        local buyfunc = option.BuyFunc or (function(ply) ply:Give(option.Class) end)
        buyfunc(bot)
        if option.OnBuy then option.OnBuy(bot) end
        if option.ShouldAnnounce then
            local chatter = TTTBots.Lib.GetComp(bot, "chatter") ---@type CChatter
            if not chatter then continue end
            chatter:On("Buy" .. option.Name, {}, option.AnnounceTeam or false)
        end
    end

    return purchased
end

--- Register a buyable item. This is useful for modders wanting to add custom buyable items.
---@param data Buyable - The data of the buyable item.
---@return boolean - Whther or not the override was successful.
function TTTBots.Buyables.RegisterBuyable(data)
    buyables[data.Name] = data

    for _, roleString in pairs(data.Roles) do
        TTTBots.Buyables.AddBuyableToRole(data, roleString)
    end

    return true
end

-- hook for TTTBeginRound
hook.Add("TTTBeginRound", "TTTBots_Buyables", function()
    -- The two second delay can avoid a bunch of confusing errors. Don't ask why, I don't fucking know.
    timer.Simple(2,
        function()
            if not TTTBots.Match.IsRoundActive() then return end
            for _, bot in pairs(TTTBots.Bots) do
                if not TTTBots.Lib.IsPlayerAlive(bot) then continue end
                if bot == NULL then continue end
                TTTBots.Buyables.PurchaseBuyablesFor(bot)
            end
        end)
end)

-- Import default data
include("tttbots2/data/sv_default_buyables.lua")
