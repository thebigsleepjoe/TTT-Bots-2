if engine.ActiveGamemode() ~= "terrortown" then return end

--- This file forces clients to download all bot avatar images.

local f = string.format

for i = 0, 5 do
    resource.AddFile(f("materials/avatars/%d.png", i))
end

for i = 0, 87 do
    resource.AddFile(f("materials/avatars/humanlike/%d.jpg", i))
end
