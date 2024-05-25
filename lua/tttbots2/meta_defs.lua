------------------------------------
--- @meta
--- This file exists to provide custom typing/linting for the addon. It
--- has no inherent functionality and is NEVER(!) executed by the game.
--- This mod uses LuaLS annotations.
--- -tbsj
------------------------------------


------------------------------------
-- Global fields and enums
-- Reminder: this code is NEVER run, and never should be. It's just for typing.
------------------------------------

ROLE_TRAITOR = 1
game = {}
player = {}
file = {}
TTT2 = {}
MASK_SHOT = 0 -- some number, not literally 0.

MOVETYPE_LADDER = 9 --- https://wiki.facepunch.com/gmod/Enums/MOVETYPE

IN_ATTACK = 1 --- https://wiki.facepunch.com/gmod/Enums/IN
IN_JUMP = 2 --- https://wiki.facepunch.com/gmod/Enums/IN
IN_DUCK = 4 --- https://wiki.facepunch.com/gmod/Enums/IN
IN_FORWARD = 8 --- https://wiki.facepunch.com/gmod/Enums/IN
IN_MOVELEFT = 512 --- https://wiki.facepunch.com/gmod/Enums/IN
IN_MOVERIGHT = 1024 --- https://wiki.facepunch.com/gmod/Enums/IN
IN_ATTACK2 = 2048 --- https://wiki.facepunch.com/gmod/Enums/IN
IN_RUN = 4096 --- https://wiki.facepunch.com/gmod/Enums/IN
IN_RELOAD = 8192 --- https://wiki.facepunch.com/gmod/Enums/IN
IN_USE = 32768 --- https://wiki.facepunch.com/gmod/Enums/IN

------------------------------------
-- Class definitions
------------------------------------

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
---@field GetNWBool fun(self: Entity, key: string, default: boolean): boolean Get a networked boolean.

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
---@field GetTop fun(self: CNavLadder): Vector Get the top of the ladder.
---@field GetBottom fun(self: CNavLadder): Vector Get the bottom of the ladder.

---@class StuckBot
---@field ply Bot The bot that is stuck.
---@field stuckTime number The timestamp the bot got stuck.
---@field stuckPos Vector The position the bot got stuck at.

---@class CommonStuckPosition
---@field center Vector The center of the stuck spot.
---@field timeLost number How many man-seconds have been lost here.
---@field cnavarea CNavArea The nav area the stuck spot is in.

------------------------------------
-- Global functions
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

--- Run a console command
---@param str string
---@param args string
function RunConsoleCommand(str, args) end

---Angle difference function.
---@param a number
---@param b number
---@return number angle
function math.AngleDifference(a, b) return 0 end

---Get the current frame time.
---@return number
function FrameTime() return 0 end

---Clamp a value between two numbers.
---@param val number
---@param min number
---@param max number
---@return number
function math.Clamp(val, min, max) return 0 end

---Lerp from one vec to another.
---@param frac number
---@param from Vector
---@param to Vector
---@return Vector
function LerpVector(frac, from, to) return Vector(0, 0, 0) end