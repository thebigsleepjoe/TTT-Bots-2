TTTBots.Behavior = {}

function TTTBots.Behavior:New()
    local newBehavior = {}
    setmetatable(newBehavior, self)
    self.__index = self
    return newBehavior
end

function TTTBots.Behavior:Initialize(bot)
    self.bot = bot
end

function TTTBots.Behavior:Think()
    -- Override this function
end

function TTTBots.Behavior:OnPathComplete(path)
    -- Override this function
end

function TTTBots.Behavior:OnPathFailed(path)
    -- Override this function
end

function TTTBots.Behavior:OnPathChanged(path)
    -- Override this function
end

function TTTBots.Behavior:OnTargetChanged(target)
    -- Override this function
end