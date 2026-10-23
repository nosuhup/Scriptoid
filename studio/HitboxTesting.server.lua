--!strict
-- Studio-only hitbox testing for your own Roblox experience.
-- Place this Script in ServerScriptService as HitboxTesting.server.lua.
-- It changes character part sizes on the server only while running in Studio.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- For group-owned experiences, add your Roblox UserIds here.
-- User-owned experiences automatically authorize the experience creator.
local GROUP_GAME_ADMIN_IDS: {[number]: boolean} = {
    -- [123456789] = true,
}

local PREFIX = "!hitbox"
local MIN_MULTIPLIER = 1
local MAX_MULTIPLIER = 4

if not RunService:IsStudio() then
    warn("[HitboxTesting] Disabled outside Roblox Studio.")
    return
end

-- Original sizes are stored per character so slider/command changes never
-- multiply an already-expanded part.
local originalSizes: {[Model]: {[BasePart]: Vector3}} = {}

local TEST_PART_NAMES = {
    "Head",
    "HumanoidRootPart",
    "UpperTorso",
    "LowerTorso",
    "Torso",
}

local function isAuthorized(player: Player): boolean
    if game.CreatorType == Enum.CreatorType.User
        and player.UserId == game.CreatorId then
        return true
    end

    return GROUP_GAME_ADMIN_IDS[player.UserId] == true
end

local function getCharacterParts(character: Model): {BasePart}
    local parts = {}

    for _, name in ipairs(TEST_PART_NAMES) do
        local part = character:FindFirstChild(name)

        if part and part:IsA("BasePart") then
            table.insert(parts, part)
        end
    end

    return parts
end

local function applyMultiplier(target: Player, multiplier: number)
    local character = target.Character
    if not character then
        warn("[HitboxTesting] Target has no character:", target.Name)
        return
    end

    local parts = getCharacterParts(character)
    if #parts == 0 then
        warn("[HitboxTesting] No supported body parts:", target.Name)
        return
    end

    local saved = originalSizes[character]
    if not saved then
        saved = {}
        originalSizes[character] = saved
    end

    for _, part in ipairs(parts) do
        if saved[part] == nil then
            saved[part] = part.Size
        end

        part.Size = saved[part] * multiplier
    end

    print(string.format(
        "[HitboxTesting] %s: %.2fx applied by server-side Studio test.",
        target.Name,
        multiplier
    ))
end

local function resetTarget(target: Player)
    local character = target.Character
    if not character then
        return
    end

    local saved = originalSizes[character]
    if not saved then
        return
    end

    for part, originalSize in pairs(saved) do
        if part.Parent then
            part.Size = originalSize
        end
    end

    originalSizes[character] = nil
    print("[HitboxTesting] Original part sizes restored for", target.Name)
end

local function resolveTargets(requester: Player, query: string): {Player}
    local lowered = string.lower(query)

    if lowered == "me" then
        return { requester }
    elseif lowered == "all" then
        return Players:GetPlayers()
    end

    -- Prefer exact username matches.
    for _, candidate in ipairs(Players:GetPlayers()) do
        if string.lower(candidate.Name) == lowered then
            return { candidate }
        end
    end

    -- Accept an unambiguous username/display-name prefix.
    local matches = {}
    for _, candidate in ipairs(Players:GetPlayers()) do
        local username = string.lower(candidate.Name)
        local displayName = string.lower(candidate.DisplayName)

        if string.sub(username, 1, #lowered) == lowered
            or string.sub(displayName, 1, #lowered) == lowered then
            table.insert(matches, candidate)
        end
    end

    if #matches ~= 1 then
        warn(string.format(
            "[HitboxTesting] Target '%s' matched %d players; use an exact username.",
            query,
            #matches
        ))
        return {}
    end

    return matches
end

local function handleCommand(player: Player, message: string)
    if not isAuthorized(player) then
        return
    end

    local args = string.split(message, " ")
    if string.lower(args[1] or "") ~= PREFIX then
        return
    end

    if #args == 3 and string.lower(args[2]) == "reset" then
        local targets = resolveTargets(player, args[3])

        for _, target in ipairs(targets) do
            resetTarget(target)
        end

        return
    end

    if #args ~= 3 then
        warn("[HitboxTesting] Use: !hitbox <username|me|all> <1-4>")
        warn("[HitboxTesting] Reset: !hitbox reset <username|me|all>")
        return
    end

    local multiplier = tonumber(args[3])
    if not multiplier or multiplier < MIN_MULTIPLIER
        or multiplier > MAX_MULTIPLIER then
        warn("[HitboxTesting] Multiplier must be between 1 and 4.")
        return
    end

    for _, target in ipairs(resolveTargets(player, args[2])) do
        applyMultiplier(target, multiplier)
    end
end

local function connectPlayer(player: Player)
    player.Chatted:Connect(function(message)
        handleCommand(player, message)
    end)

    player.CharacterRemoving:Connect(function(character)
        -- The departing character will be destroyed; discard cached references.
        originalSizes[character] = nil
    end)
end

for _, player in ipairs(Players:GetPlayers()) do
    connectPlayer(player)
end

Players.PlayerAdded:Connect(connectPlayer)

print("[HitboxTesting] Ready in Studio. Commands: !hitbox <username|me|all> <1-4>")
