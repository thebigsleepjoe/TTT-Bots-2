TTTBots.Behaviors = TTTBots.Behaviors or {}
TTTBots.Behaviors.Follow = {}

local lib = TTTBots.Lib

local Follow = TTTBots.Behaviors.Follow
Follow.Name = "Follow"
Follow.Description = "Follow a player discretely."
Follow.Interruptible = true

local STATUS = {
    RUNNING = 1,
    SUCCESS = 2,
    FAILURE = 3,
}

--- A list of string traits that this behavior uses.
--- Traitors will be much more likely to follow people around regardless of traits.
local FOLLOWING_TRAITS = {
    aggressive = true,
    suspicious = true,
    veryoblivious = true,
    doesntcare = true,
    lovescrowds = true,
    teamplayer = true,
    follower = true,
    rdmer = true,
    bodyguard = true,
}

--- Return if whether or not the bot is a follower. That is, if they are a traitor or have a following trait.
---@param bot Player
---@return boolean
function Follow:IsFollower(bot)
    return lib.IsEvil(bot) or bot:HasPTraitIn(FOLLOWING_TRAITS)
end

--- Similar to IsFollower, but returns mathematical chance of deciding to follow a new person this tick.
function Follow:GetFollowChance(bot)
    local BASE_CHANCE = 1 -- 1 % chance per tick
    local debugging = true
    local chance = BASE_CHANCE * (self:IsFollower(bot) and 1 or 0) * (lib.IsEvil(bot) and 2 or 1)

    return (
        (debugging and 100) or -- if debugging return 100% always.
        chance                 -- otherwise return the actual chance.
    )
end

function Follow:GetFollowTargets(bot)
    local targets = {}
    local isEvil = lib.IsEvil(bot)
    local followTeammates = isEvil and bot:HasPTrait("teamplayer") -- Only applies for traitors

    ---@type CMemory
    local memory = bot.components.memory
    local recentPlayers = memory:GetRecentlySeenPlayers(8)

    -- For this function we are going to cheat and assume we know the updated positions of every player we've seen recently.
    for i, ply in pairs(recentPlayers) do
        if ply == bot then continue end             -- shouldn't be possible but neither should a lot of things.
        if followTeammates and lib.IsEvil(ply) then -- we are following teammates and this player is evil (like ourselves).
            table.insert(targets, ply)
        elseif not followTeammates then             -- we are not following teammates so just add everyone.
            table.insert(targets, ply)
        end
    end

    return targets
end

--- Validate the behavior
function Follow:Validate(bot)
    if bot.followTarget then return true end -- already following someone
    local shouldFollow = lib.CalculatePercentChance(self:GetFollowChance(bot))
    return shouldFollow and #self:GetFollowTargets(bot) > 0
end

--- Called when the behavior is started
function Follow:OnStart(bot)
    -- timer.Simple(math.random(15, 45), function()
    --     if not IsValid(bot) then return end
    --     bot.followTarget = nil
    -- end)
    -- let's use timer.Create instead to be fancy
    timer.Create("TTTBots.Follow." .. bot:Nick(), math.random(20, 45), 1, function()
        if not IsValid(bot) then return end
        bot.followTarget = nil
    end)

    bot.followTarget = table.Random(self:GetFollowTargets(bot))

    return STATUS.RUNNING
end

--- Called when the behavior's last state is running
function Follow:OnRunning(bot)
    local target = bot.followTarget

    if not IsValid(target) or not lib.IsPlayerAlive(target) then
        return STATUS.FAILURE
    end

    local loco = bot.components.locomotor

    loco:SetGoalPos(target:GetPos())
end

--- Called when the behavior returns a success state
function Follow:OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function Follow:OnFailure(bot)
end

--- Called when the behavior ends
function Follow:OnEnd(bot)
    timer.Remove("TTTBots.Follow." .. bot:Nick())
    bot.followTarget = nil
end
