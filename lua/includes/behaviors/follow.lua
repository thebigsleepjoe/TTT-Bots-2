TTTBots.Behaviors = TTTBots.Behaviors or {}
TTTBots.Behaviors.Follow = {}

local lib = TTTBots.Lib

local Follow = TTTBots.Behaviors.Follow
Follow.Name = "Follow"
Follow.Description = "Follow a player non-descreetly."
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
    local personality = lib.GetComp(bot, "personality") ---@type CPersonality
    if not personality then return false end

    local hasTrait = personality:GetTraitBool("follower") or personality:GetTraitBool("followerAlways")
    local isEvil = lib.IsEvil(bot)

    return isEvil or hasTrait
end

--- Similar to IsFollower, but returns mathematical chance of deciding to follow a new person this tick.
function Follow:GetFollowChance(bot)
    local BASE_CHANCE = 5 -- X % chance per tick
    local debugging = false
    local chance = BASE_CHANCE * (self:IsFollower(bot) and 1 or 0) * (lib.IsEvil(bot) and 2 or 1)

    local personality = lib.GetComp(bot, "personality") ---@type CPersonality
    if not personality then return chance end
    local alwaysFollows = personality:GetTraitBool("followerAlways")

    return (
        ((debugging or alwaysFollows) and 100) or -- if debugging return 100% always.
        chance                                    -- otherwise return the actual chance.
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

    local chatter = lib.GetComp(bot, "chatter") ---@type CChatter
    chatter:On("FollowStarted", { player = bot.followTarget:Nick() })

    return STATUS.RUNNING
end

function Follow:GetFollowPoint(target)
    return target:GetPos()
end

--- Called when the behavior's last state is running
function Follow:OnRunning(bot)
    local target = bot.followTarget

    if not IsValid(target) or not lib.IsPlayerAlive(target) then
        return STATUS.FAILURE
    end

    if bot.botFollowPoint ~= nil and bot:GetPos():Distance(bot.botFollowPoint) < 100 then
        return STATUS.SUCCESS
    end

    local loco = bot.components.locomotor
    bot.botFollowPoint = self:GetFollowPoint(target)

    if bot.botFollowPoint == false then return STATUS.FAILURE end

    loco:SetGoalPos(bot.botFollowPoint)
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
    bot.botFollowPoint = nil
    bot.components.locomotor:Stop()
end
