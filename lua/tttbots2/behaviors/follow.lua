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

--- Return if whether or not the bot is a follower per their personality. That is, if they are a traitor or have a following trait.
---@param bot Bot
---@return boolean
function Follow.IsFollowerPersonality(bot)
    local personality = lib.GetComp(bot, "personality") ---@type CPersonality
    if not personality then return false end

    local hasTrait = personality:GetTraitBool("follower") or personality:GetTraitBool("followerAlways")

    return hasTrait
end

--- Return if the bot is a follower role, like a traitor.
---@param bot any
function Follow.IsFollowerRole(bot)
    local role = TTTBots.Roles.GetRoleFor(bot) ---@type RoleData
    if not role then return false end

    return role:GetIsFollower()
end

--- Similar to IsFollower, but returns mathematical chance of deciding to follow a new person this tick.
function Follow.GetFollowChance(bot)
    local BASE_CHANCE = 0.1 -- X % chance per tick
    local debugging = false
    local chance = BASE_CHANCE * (Follow.IsFollowerPersonality(bot) and 2 or 1) * (Follow.IsFollowerRole(bot) and 2 or 1)

    local personality = lib.GetComp(bot, "personality") ---@type CPersonality
    if not personality then return chance end
    local alwaysFollows = personality:GetTraitBool("followerAlways")

    return (
        ((debugging or alwaysFollows) and 100) or -- if debugging return 100% always.
        chance                                    -- otherwise return the actual chance.
    )
end

function Follow.GetFollowTargets(bot)
    local targets = {}
    local isFollowerRole = Follow.IsFollowerRole(bot)
    local followTeammates = isFollowerRole -- and bot:HasTrait("teamplayer") -- Only applies for traitors

    ---@type CMemory
    local memory = bot.components.memory
    local recentPlayers = memory:GetRecentlySeenPlayers(8)

    -- For this function we are going to cheat and assume we know the updated positions of every player we've seen recently.
    for i, other in pairs(recentPlayers) do
        if not lib.IsPlayerAlive(other) then continue end
        if other == bot then continue end -- shouldn't be possible but neither should a lot of things.
        if other:IsBot() then
            local otherFollowTarget = other.followTarget
            if otherFollowTarget == bot then continue end              -- don't follow bots that are following us. This will create a death spiral.
        end
        if followTeammates and TTTBots.Roles.IsAllies(bot, other) then -- we are following teammates and this player is evil (like ourselves).
            table.insert(targets, other)
        elseif not followTeammates then                                -- we are not following teammates so just add everyone.
            table.insert(targets, other)
        end
    end

    return targets
end

---gets the visible navs to the ent's nearest nav
---@deprecated Still works, but don't use.
---@param target Entity
---@return table<CNavArea>
function Follow.GetVisibleNavs(target)
    local targetNav = navmesh.GetNearestNavArea(target:GetPos())
    if not targetNav then return {} end

    local visibleNavs = targetNav:GetVisibleAreas()

    return visibleNavs
end

--- This is a long f*cking function name that gets a random visible point on the navmesh to the target.
---@deprecated Still works, but don't use.
---@param target Player
---@return Vector|nil
function Follow.GetRandomVisiblePointOnNavmeshTo(target)
    local visibleNavs = Follow.GetVisibleNavs(target)
    if #visibleNavs <= 1 then return nil end -- no visible navs

    local rand = table.Random(visibleNavs)
    local point = rand:GetRandomPoint()
    return point
end

--- Get a random point in the list of CNavAreas
---@param navList table<CNavArea>
---@return Vector
function Follow.GetRandomPointInList(navList)
    local nav = table.Random(navList)
    local pos = nav:GetRandomPoint()
    return pos
end

--- Validate the behavior
function Follow.Validate(bot)
    if bot.followTarget and not IsValid(bot.followTarget) then
        bot.followTarget = nil
    end
    if not TTTBots.Match.IsRoundActive() then return false end
    if bot.followTarget then return true end -- already following someone
    local shouldFollow = lib.TestPercent(Follow.GetFollowChance(bot))
    return shouldFollow and #Follow.GetFollowTargets(bot) > 0
end

--- Called when the behavior is started
function Follow.OnStart(bot)
    bot.followTarget = table.Random(Follow.GetFollowTargets(bot))
    if not bot.followTarget then return STATUS.FAILURE end -- IDK how this happens but it just does.
    bot.followEndTime = CurTime() + math.random(12, 24)

    local chatter = lib.GetComp(bot, "chatter") ---@type CChatter
    chatter:On("FollowStarted", { player = bot.followTarget:Nick() })

    return STATUS.RUNNING
end

function Follow.GetFollowPoint(target)
    return target:GetPos()
end

--- Called when the behavior's last state is running
function Follow.OnRunning(bot)
    local target = bot.followTarget

    if not IsValid(target) or not lib.IsPlayerAlive(target) then
        return STATUS.FAILURE
    end

    if CurTime() > (bot.followEndTime or 0) then
        return STATUS.FAILURE
    end

    -- if bot.botFollowPoint ~= nil and bot:GetPos():Distance(bot.botFollowPoint) < 100 then
    --     return STATUS.SUCCESS
    -- end

    local loco = bot:BotLocomotor()
    bot.botFollowPoint = Follow.GetFollowPoint(target)

    if bot.botFollowPoint == false then return STATUS.FAILURE end

    local distToPoint = bot:GetPos():Distance(bot.botFollowPoint)
    local finalTarget = (distToPoint < 100 and bot:GetPos()) or bot.botFollowPoint

    loco:SetGoal(finalTarget)
end

--- Called when the behavior returns a success state
function Follow.OnSuccess(bot)
end

--- Called when the behavior returns a failure state
function Follow.OnFailure(bot)
end

--- Called when the behavior ends
function Follow.OnEnd(bot)
    timer.Remove("TTTBots.Follow." .. bot:Nick())
    bot.followTarget = nil
    bot.botFollowPoint = nil
    bot.followEndTime = nil
    bot:BotLocomotor():StopMoving()
end
