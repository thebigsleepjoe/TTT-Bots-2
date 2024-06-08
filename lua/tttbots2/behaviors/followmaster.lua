TTTBots.Behaviors = TTTBots.Behaviors or {}
TTTBots.Behaviors.FollowMaster = {}

local lib = TTTBots.Lib

local FollowMaster = TTTBots.Behaviors.FollowMaster
FollowMaster.Name = "FollowMaster"
FollowMaster.Description = "(Typically of a sidekick) follow a master of the same team, that is not our role."
FollowMaster.Interruptible = true

local STATUS = TTTBots.STATUS

---Find a random master to follow.
---@param bot Bot
---@return Player?
function FollowMaster.FindMaster(bot)
    local myRole = bot:GetRoleStringRaw()
    local myTeam = bot:GetTeam()

    local options = TTTBots.Lib.FilterTable(TTTBots.Match.AlivePlayers, function(ply)
        local role = ply:GetRoleStringRaw()
        local team = ply:GetTeam()

        return role ~= myRole and team == myTeam
    end)

    if table.IsEmpty(options) then return end

    return table.Random(options)
end

function FollowMaster.ValidatePlayer(ply)
    if not ply then return false end
    if not IsValid(ply) then return false end
    if not TTTBots.Lib.IsPlayerAlive(ply) then return false end
    return true
end

--- Validate the behavior
function FollowMaster.Validate(bot)
    return FollowMaster.ValidatePlayer(bot.followMaster) or FollowMaster.FindMaster(bot)
end

--- Called when the behavior is started
function FollowMaster.OnStart(bot)
    local target = bot.followMaster or FollowMaster.FindMaster(bot)

    bot.followMaster = target

    return STATUS.RUNNING
end

function FollowMaster.GetFollowPoint(target)
    return target:GetPos()
end

--- Called when the behavior's last state is running
function FollowMaster.OnRunning(bot)
    local target = bot.followMaster

    if not FollowMaster.ValidatePlayer(target) then
        return STATUS.FAILURE
    end

    if target.attackTarget then bot:SetAttackTarget(target.attackTarget) end

    local loco = bot:BotLocomotor()
    bot.masterFollowPoint = FollowMaster.GetFollowPoint(target)

    if bot.masterFollowPoint == false then return STATUS.FAILURE end

    local distToPoint = bot:GetPos():Distance(bot.masterFollowPoint)
    local finalTarget = (distToPoint < 100 and bot:GetPos()) or bot.masterFollowPoint

    loco:SetGoal(finalTarget)
end

--- Called when the behavior returns a success state
function FollowMaster.OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function FollowMaster.OnFailure(bot)
end

--- Called when the behavior ends
function FollowMaster.OnEnd(bot)
    bot.followMaster = nil
    bot.masterFollowPoint = nil
    bot:BotLocomotor():StopMoving()
end
