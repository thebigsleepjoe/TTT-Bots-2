--- @meta
--- This file exists to provide custom typing/linting for the addon. It
--- has no inherent functionality and is NEVER(!) executed by the game.
--- This mod uses LuaLS annotations.
--- tbsj

ROLE_TRAITOR = 1
game = {}
player = {}
file = {}
TTT2 = {}
MASK_SHOT = 0 -- some number, not literally 0.

---@class Components : table
---@field locomotor CLocomotor
---@field memory CMemory
---@field morality CMorality
---@field chatter CChatter
---@field inventory CInventory
---@field obstacletracker CObstacleTracker
---@field personality CPersonality

---@class Vector
---@field Distance fun(self: Vector, vec: Vector): number The distance from us to them.
---@field LengthSqr fun(self: Vector): number The length of the vector prior to taking a sqrt.
---@field Dot fun(self: Vector, vec: Vector): number The dot product of the two vectors.

---@class Entity
---@field GetPos fun(self: Entity): Vector
---@field OBBCenter fun(self: Entity): Vector Object Bounding Box center of the Entity's model.
---@field IsPlayer fun(self: Entity): boolean Is the Entity a player?
---@field Visible fun(self: Entity, ent: Entity): boolean Can we see the Entity?
---@field VisibleVec fun(self: Entity, vec: Vector): boolean Can we see the Vector?
---@field EyePos fun(self: Entity): Vector The position of the Entity's eyes.
---@field GetClass fun(self: Entity): string The class of the Entity.
---@field GetAimVector fun(self: Entity): Vector The aim vector of the Entity.

---@class Weapon : Entity
---@field CanBuy table The roles that can buy this weapon, indexed by ROLE_ globals
---@field AutoSpawnable boolean Whether this weapon can be spawned by the game.

---@class Player : Entity
---@field GetRoleStringRaw fun(self: Entity): string
---@field GetVelocity fun(self: Entity): Vector
---@field Nick fun(self: Entity): string
---@field UserID fun(self: Entity): string
---@field GetActiveWeapon fun(self: Entity): Weapon the held wep of the player

---@class Bot : Player
---@field lastBarrelCheck number? The last time we checked for any nearby explosive barrels.
---@field lastBarrel Entity? The last explosive barrel we detected in our search.
---@field attackFocus number The focus of the bot's attack. Dictates accuracy, decreases with time.
---@field components Components The components of the bot.
---@field redHandedTime number The time the bot was last seen committing a crime.
---@field avatarN number The avatar number assigned to the bot. (SERVER)
---@field initialized boolean If TTT Bots has initialized this bot.

---@class CNavArea
---@field GetVisibleAreas fun(self: CNavArea): table<CNavArea> Get all areas visible from this area.
---@field GetAdjacentAreas fun(self: CNavArea): table<CNavArea> Get all areas adjacent to this area.
---@field GetCenter fun(self: CNavArea): Vector Get the center of the area.

---@class CNavLadder

------------------------------------
-- Reminder: this code is NEVER run, and never should be. It's just for typing.
------------------------------------

---Retrieve a random element from a table.
---@param tbl table
function table.Random(tbl)
    return tbl[math.random(#tbl)]
end

---Determines if tbl has the given value in the table.
---@param tbl table
---@param value any
---@return boolean
function table.HasValue(tbl, value)
    return false
end

---@param tbl table
---@return boolean
function table.IsEmpty(tbl) return false end

---@param tbl table
---@return number
function table.Count(tbl) return 0 end

---@param str string
---@param ending string
---@return boolean
function string.EndsWith(str, ending) return false end

---Get the current epoch time.
---@return number
function SysTime() return 0 end
