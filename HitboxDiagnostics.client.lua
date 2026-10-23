-- Luau | HitboxDiagnostics.client.lua | Roblox LocalScript
-- Place in StarterPlayerScripts in your own Roblox experience.
-- Visual diagnostics only: never changes authoritative hitboxes, spoofs metatables,
-- intercepts input, or bypasses anti-cheat checks.
-- Built by Olivia — https://discord.gg/ojailbreaks

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local Config = {
    Enabled = false,
    TargetPart = "HumanoidRootPart", -- "Head" or "HumanoidRootPart"
    SizeMultiplier = 2.5,
    PredictionTime = 0.10,
    MaxPredictionStuds = 12,
    Transparency = 0.65,
    MaxDistance = 500,
    UpdateInterval = 0.08,
    ToggleKey = Enum.KeyCode.RightControl,
    VisibleColor = Color3.fromRGB(80, 220, 120),
    BlockedColor = Color3.fromRGB(255, 85, 85),
    ShowHighlight = true,
}

local proxies = {}
local highlights = {}
local playerConnections = {}
local elapsed = 0
local lastHeartbeatDt = 1 / 60

local gui = Instance.new("ScreenGui")
gui.Name = "SeroidHitboxDiagnostics"
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Metrics"
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -16, 0, 16)
panel.Size = UDim2.fromOffset(285, 126)
panel.BackgroundColor3 = Color3.fromRGB(18, 20, 29)
panel.BackgroundTransparency = 0.12
panel.BorderSizePixel = 0
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = panel

local readout = Instance.new("TextLabel")
readout.Name = "Readout"
readout.Position = UDim2.fromOffset(10, 8)
readout.Size = UDim2.new(1, -20, 1, -16)
readout.BackgroundTransparency = 1
readout.Font = Enum.Font.Code
readout.TextSize = 13
readout.TextColor3 = Color3.fromRGB(230, 232, 245)
readout.TextXAlignment = Enum.TextXAlignment.Left
readout.TextYAlignment = Enum.TextYAlignment.Top
readout.Text = "SEROID // HITBOX DIAGNOSTICS"
readout.Parent = panel

local function getTargetPart(character)
    if not character then
        return nil
    end

    local name = Config.TargetPart == "Head" and "Head" or "HumanoidRootPart"
    local part = character:FindFirstChild(name)
    return part and part:IsA("BasePart") and part or nil
end

local function destroyVisual(player)
    local proxy = proxies[player]
    if proxy then
        proxy:Destroy()
        proxies[player] = nil
    end

    local highlight = highlights[player]
    if highlight then
        highlight:Destroy()
        highlights[player] = nil
    end
end

local function clearVisuals()
    for player in pairs(proxies) do
        destroyVisual(player)
    end
    for player in pairs(highlights) do
        destroyVisual(player)
    end
end

local function getProxy(player)
    local proxy = proxies[player]
    if proxy and proxy.Parent then
        return proxy
    end

    proxy = Instance.new("Part")
    proxy.Name = "SeroidHitboxPreview"
    proxy.Anchored = true
    proxy.CanCollide = false
    proxy.CanTouch = false
    proxy.CanQuery = false
    proxy.CastShadow = false
    proxy.Material = Enum.Material.ForceField
    proxy.Color = Config.VisibleColor
    proxy.Transparency = Config.Transparency
    proxy.Size = Vector3.new(4, 5, 4)
    proxy.Parent = Workspace

    proxies[player] = proxy
    return proxy
end

local function getHighlight(player, character)
    local highlight = highlights[player]
    if highlight and highlight.Parent == character then
        return highlight
    end

    if highlight then
        highlight:Destroy()
    end

    highlight = Instance.new("Highlight")
    highlight.Name = "SeroidDiagnosticHighlight"
    highlight.Adornee = character
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    highlight.FillTransparency = 0.85
    highlight.OutlineTransparency = 0.15
    highlight.Parent = character

    highlights[player] = highlight
    return highlight
end

local function getLineOfSight(targetPlayer, targetPart, origin)
    local character = targetPlayer.Character
    if not character then
        return false
    end

    local direction = targetPart.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = { LocalPlayer.Character }
    params.IgnoreWater = false

    local result = Workspace:Raycast(origin, direction, params)
    return result == nil or result.Instance:IsDescendantOf(character)
end

local function clampPrediction(velocity)
    local offset = velocity * Config.PredictionTime
    local magnitude = offset.Magnitude

    if magnitude > Config.MaxPredictionStuds and magnitude > 0 then
        offset = offset.Unit * Config.MaxPredictionStuds
    end

    return offset
end

local function registerPlayer(player)
    if player == LocalPlayer or playerConnections[player] then
        return
    end

    local connections = {}
    playerConnections[player] = connections

    table.insert(connections, player.CharacterRemoving:Connect(function()
        destroyVisual(player)
    end))

    table.insert(connections, player.CharacterAdded:Connect(function()
        destroyVisual(player)
    end))
end

local function unregisterPlayer(player)
    destroyVisual(player)

    local connections = playerConnections[player]
    if connections then
        for _, connection in ipairs(connections) do
            connection:Disconnect()
        end
    end

    playerConnections[player] = nil
end

for _, player in ipairs(Players:GetPlayers()) do
    registerPlayer(player)
end

Players.PlayerAdded:Connect(registerPlayer)
Players.PlayerRemoving:Connect(unregisterPlayer)

local function setEnabled(enabled)
    Config.Enabled = enabled
    if not enabled then
        clearVisuals()
    end
end

UserInputService.InputBegan:Connect(function(input, processed)
    if processed then
        return
    end

    if input.KeyCode == Config.ToggleKey then
        setEnabled(not Config.Enabled)
    end
end)

RunService.Heartbeat:Connect(function(dt)
    lastHeartbeatDt = dt
    elapsed += dt

    if elapsed < Config.UpdateInterval then
        return
    end
    elapsed = 0

    if not Config.Enabled then
        readout.Text = string.format(
            "SEROID // HITBOX DIAGNOSTICS\nState: OFF\nToggle: RightControl\nPreview only — no hitbox changes"
        )
        return
    end

    local localCharacter = LocalPlayer.Character
    local localRoot = localCharacter and localCharacter:FindFirstChild("HumanoidRootPart")
    if not localRoot then
        readout.Text = "SEROID // HITBOX DIAGNOSTICS\nWaiting for local character..."
        return
    end

    local targets, visible, blocked = 0, 0, 0
    local predictionTotal = 0

    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= LocalPlayer then
            local character = targetPlayer.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local targetPart = getTargetPart(character)

            if humanoid and humanoid.Health > 0 and targetPart then
                local distance = (targetPart.Position - localRoot.Position).Magnitude

                if distance <= Config.MaxDistance then
                    targets += 1

                    local offset = clampPrediction(targetPart.AssemblyLinearVelocity)
                    local visibleNow = getLineOfSight(targetPlayer, targetPart, localRoot.Position)
                    local color = visibleNow and Config.VisibleColor or Config.BlockedColor
                    local proxy = getProxy(targetPlayer)

                    proxy.Size = targetPart.Size * math.clamp(Config.SizeMultiplier, 1, 8)
                    proxy.CFrame = targetPart.CFrame + offset
                    proxy.Color = color
                    proxy.Transparency = math.clamp(Config.Transparency, 0.1, 0.95)

                    if visibleNow then
                        visible += 1
                    else
                        blocked += 1
                    end

                    if Config.ShowHighlight then
                        local highlight = getHighlight(targetPlayer, character)
                        highlight.FillColor = color
                        highlight.OutlineColor = color
                    elseif highlights[targetPlayer] then
                        highlights[targetPlayer]:Destroy()
                        highlights[targetPlayer] = nil
                    end

                    predictionTotal += offset.Magnitude
                else
                    destroyVisual(targetPlayer)
                end
            else
                destroyVisual(targetPlayer)
            end
        end
    end

    local averagePrediction = targets > 0 and predictionTotal / targets or 0
    local fps = math.floor(1 / math.max(lastHeartbeatDt, 1 / 240))

    readout.Text = string.format(
        "SEROID // HITBOX DIAGNOSTICS\nTargets: %d | Visible: %d\nBlocked: %d | FPS: %d\nAvg prediction: %.2f studs\nToggle: RightControl | ON\nPreview only — no hitbox changes",
        targets,
        visible,
        blocked,
        fps,
        averagePrediction
    )
end)

script.Destroying:Connect(function()
    clearVisuals()
    for player in pairs(playerConnections) do
        unregisterPlayer(player)
    end
    if gui then
        gui:Destroy()
    end
end)
