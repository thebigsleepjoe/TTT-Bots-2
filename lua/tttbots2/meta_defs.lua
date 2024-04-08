--- @meta
--- This file exists to provide custom typing/linting for the addon. It
--- has no inherent functionality and is never executed by the game.
--- tbsj

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

---@class Entity
---@field GetPos fun(): Vector
---@field OBBCenter fun(): Vector Object Bounding Box center of the Entity's model.
---@field IsPlayer fun(): boolean Is the Entity a player?

---@class Player : Entity
---@field GetRoleStringRaw fun(): string
---@field GetVelocity fun(): Vector
---@field Nick fun(): string

---@class Bot : Player
---@field lastBarrelCheck number? The last time we checked for any nearby explosive barrels.
---@field lastBarrel Entity? The last explosive barrel we detected in our search.
---@field attackFocus number The focus of the bot's attack. Dictates accuracy, decreases with time.
---@field components Components The components of the bot.
---@field redHandedTime number The time the bot was last seen committing a crime.

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
