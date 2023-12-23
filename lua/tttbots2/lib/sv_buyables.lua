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
---@field OnBuy function - (OPTIONAL) Called when the bot successfully buys this item.
---@field CanBuy function - (OPTIONAL) Return false to prevent a bot from buying this item.
---@field Roles table<string> - A table of roles that can buy this item.
---@field RandomChance number - (OPTIONAL) An integer from 1 to math.huge. Functionally the item will be selected if random(1, RandomChoice) == 1.
---@field OnAnnounce function - (OPTIONAL) Called when the bot announces this item.
---@field ShouldAnnounce boolean - (OPTIONAL) Should this create a chatter event?
---@field AnnounceTeam boolean - (OPTIONAL) Is announcing team-only?
---@field BuyFunc function - (OPTIONAL) A function


--- Register a buyable item. This is useful for modders wanting to add custom buyable items.
---@param data Buyable - The data of the buyable item.
---@return boolean - Whther or not the override was successful.
function TTTBots.Buyables.RegisterBuyable(data)
    buyables[data.Name] = data

    for _, roleString in pairs(buyables_role) do
        buyables_role[roleString] = buyables_role[roleString] or {}
        buyables_role[roleString][data] = data.Priority
        table.sort(buyables_role[roleString], function(a, b) return a.Priority > b.Priority end)
    end

    return true
end

--- Return a buyable item by its name.
---@param name string - The name of the buyable item.
---@return Buyable|nil - The buyable item, or nil if it does not exist.
function TTTBots.Buyables.GetBuyable(name) return buyables[name] end

---Return a list of buyables for the given rolestring. Defaults to an empty table.
---@param roleString string
---@return table<Buyable>
function TTTBots.Buyables.GetBuyablesFor(roleString) return buyables_role[roleString] or {} end
