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
    return lib.IsEvil(bot) or bot:HasTraitIn(FOLLOWING_TRAITS)
end

--- Similar to IsFollower, but returns mathematical chance of deciding to follow a new person this tick.
function Follow:GetFollowChance(bot)
    local BASE_CHANCE = 2 -- X % chance per tick
    local debugging = false
    local chance = BASE_CHANCE * (self:IsFollower(bot) and 1 or 0) * (lib.IsEvil(bot) and 2 or 1)

    return (
        (debugging and 100) or -- if debugging return 100% always.
        chance                 -- otherwise return the actual chance.
    )
end

function Follow:GetFollowTargets(bot)
    local targets = {}
    local isEvil = lib.IsEvil(bot)
    local followTeammates = isEvil and bot:HasTrait("teamplayer") -- Only applies for traitors

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

---gets the visible navs to the ent's nearest nav
---@deprecated Still works, but don't use.
---@param target Entity
---@return table<CNavArea>
function Follow:GetVisibleNavs(target)
    local targetNav = navmesh.GetNearestNavArea(target:GetPos())
    if not targetNav then return {} end

    local visibleNavs = targetNav:GetVisibleAreas()

    return visibleNavs
end

--- This is a long f*cking function name that gets a random visible point on the navmesh to the target.
---@deprecated Still works, but don't use.
---@param target Player
---@return Vector|nil
function Follow:GetRandomVisiblePointOnNavmeshTo(target)
    local visibleNavs = self:GetVisibleNavs(target)
    if #visibleNavs <= 1 then return nil end -- no visible navs

    local rand = table.Random(visibleNavs)
    local point = rand:GetRandomPoint()
    return point
end

--- Get a random point in the list of CNavAreas
---@param navList table<CNavArea>
---@return Vector
function Follow:GetRandomPointInList(navList)
    local nav = table.Random(navList)
    local pos = nav:GetRandomPoint()
    return pos
end

--- Validate the behavior
function Follow:Validate(bot)
    if bot.followTarget then return true end -- already following someone
    local shouldFollow = lib.CalculatePercentChance(self:GetFollowChance(bot))
    return shouldFollow and #self:GetFollowTargets(bot) > 0
end

function Follow:CreateTargetRemovalTimer(bot)
    timer.Create("TTTBots.Follow." .. bot:Nick(), math.random(20, 45), 1, function()
        if not IsValid(bot) then return end
        local target = bot.followTarget
        if not (TTTBots.Match.RoundActive and IsValid(target) and bot:Visible(target)) then
            self:CreateTargetRemovalTimer(bot)
            return
        end
        bot.followTarget = nil
    end)
end

--- Called when the behavior is started
function Follow:OnStart(bot)
    -- timer.Simple(math.random(15, 45), function()
    --     if not IsValid(bot) then return end
    --     bot.followTarget = nil
    -- end)
    -- let's use timer.Create instead to be fancy
    self:CreateTargetRemovalTimer(bot)
    bot.followTarget = table.Random(self:GetFollowTargets(bot))

    return STATUS.RUNNING
end

function Follow:GetFollowPoint(target)
    local nearestNav = navmesh.GetNearestNavArea(target:GetPos())
    local maxDist = 1000

    if not nearestNav then return end

    local isDiscreet = true

    local possibleAreas = TTTBots.Lib.GetAllVisibleWithinDist(nearestNav, maxDist)
    if possibleAreas == nil or #possibleAreas == 0 then isDiscreet = false end
    local randomPoint = (isDiscreet and self:GetRandomPointInList(possibleAreas)) or nearestNav:GetRandomPoint()

    return randomPoint
end

--- Called when the behavior's last state is running
function Follow:OnRunning(bot)
    local target = bot.followTarget

    if not IsValid(target) or not lib.IsPlayerAlive(target) then
        return STATUS.FAILURE
    end

    if bot.randFollowPoint ~= nil and bot:GetPos():Distance(bot.randFollowPoint) < 100 then
        return STATUS.SUCCESS
    end

    local loco = bot.components.locomotor
    bot.randFollowPoint = self:GetFollowPoint(target)

    if bot.randFollowPoint == false then return STATUS.FAILURE end

    loco:SetGoalPos(bot.randFollowPoint)
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
    bot.randFollowPoint = nil
    bot.components.locomotor:Stop()
end
