TTTBots.Buyables = {}
TTTBots.Buyables.m_buyables = {}

---@class Buyable
---@field Name string - The pretty name of this item.
---@field Class string - The class of this item.
---@field Price number - The price of this item, in credits.
---@field CanBuy function - Return false to prevent a bot from buying this item.
---@field OnBuy function - Called when the bot successfully buys this item.
---@field ShouldAnnounce boolean - Should this create a chatter event?
---@field AnnounceTeam boolean - Is announcing team-only?
---@field Priority number - The priority of this item. Higher numbers = higher priority. If two buyables have the same priority, the script will select one at random.
---@field RandomChance number - An integer from 1 to math.huge. Functionally the item will be selected if random(1, RandomChoice) == 1.

function TTTBots.Buyables.RegisterBuyable(data)
    TTTBots.Buyables.m_buyables[weapon_name] = data
end
