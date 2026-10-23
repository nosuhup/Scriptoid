-- Luau | StarterPlayerScripts/HitboxDiagnostics.client.lua
-- Built by Olivia — https://discord.gg/ojailbreaks
-- Studio-only visual diagnostics. Preview parts never alter real hitboxes,
-- collide, query, touch, intercept clicks, or spoof engine properties.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer

local CONFIG = {
    Enabled = false,
    TargetPart = "HumanoidRootPart", -- "Head" or "HumanoidRootPart"
    HitboxSize = Vector3.new(6, 6, 6),
    Color = Color3.fromRGB(70, 220, 120),
    Transparency = 0.55,
    PredictionSeconds = 0.12,
    MaxPredictionDistance = 10,
    VisibleScale = 1.0,
    BlockedScale = 0.55,
    MaxDistance = 500,
    UpdateInterval = 0.08,
    ToggleKey = Enum.KeyCode.RightControl,
}

local PREVIEW_FOLDER_NAME = "_SeroidHitboxDiagnostics"
local running = true
local accumulator = 0
local previews = {}
local connections = {}
local activeCount = 0
local visibleCount = 0
local blockedCount = 0
local averagePrediction = Vector3.zero
local hudLabel

local oldFolder = Workspace:FindFirstChild(PREVIEW_FOLDER_NAME)
if oldFolder then
    oldFolder:Destroy()
end

local previewFolder = Instance.new("Folder")
previewFolder.Name = PREVIEW_FOLDER_NAME
previewFolder.Parent = Workspace

local gui = Instance.new("ScreenGui")
gui.Name = "SeroidHitboxDiagnosticsHUD"
gui.ResetOnSpawn = false
gui.DisplayOrder = 50

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -16, 0, 16)
panel.Size = UDim2.fromOffset(270, 116)
panel.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
panel.BackgroundTransparency = 0.12
panel.BorderSizePixel = 0
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 9)
corner.Parent = panel

hudLabel = Instance.new("TextLabel")
hudLabel.Name = "Readout"
hudLabel.Position = UDim2.fromOffset(12, 10)
hudLabel.Size = UDim2.new(1, -24, 1, -20)
hudLabel.BackgroundTransparency = 1
hudLabel.Font = Enum.Font.Code
hudLabel.TextSize = 13
hudLabel.TextColor3 = Color3.fromRGB(235, 238, 247)
hudLabel.TextXAlignment = Enum.TextXAlignment.Left
hudLabel.TextYAlignment = Enum.TextYAlignment.Top
hudLabel.Text = "SEROID // HITBOX DIAGNOSTICS"
hudLabel.Parent = panel

local function connect(signal, callback)
    local connection = signal:Connect(callback)
    table.insert(connections, connection)
    return connection
end

local function getTargetPart(character)
    if not character then
        return nil
    end

    if CONFIG.TargetPart == "Head" then
        return character:FindFirstChild("Head")
    end

    return character:FindFirstChild("HumanoidRootPart")
end

local function removePreview(player)
    local record = previews[player]
    if not record then
        return
    end

    if record.part then
        record.part:Destroy()
    end
    if record.highlight then
        record.highlight:Destroy()
    end
    previews[player] = nil
end

local function removeAllPreviews()
    for player in pairs(previews) do
        removePreview(player)
    end
end

local function makePreview(player)
    local part = Instance.new("Part")
    part.Name = "Preview_" .. tostring(player.UserId)
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false -- cannot intercept mouse targeting or raycasts
    part.CastShadow = false
    part.Massless = true
    part.Material = Enum.Material.ForceField
    part.Color = CONFIG.Color
    part.Transparency = math.clamp(CONFIG.Transparency, 0, 1)
    part.Size = CONFIG.HitboxSize
    part.Parent = previewFolder

    local highlight = Instance.new("Highlight")
    highlight.Name = "CharacterVisibilityDiagnostic"
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    highlight.FillTransparency = 0.9
    highlight.OutlineTransparency = 0.15

    local record = { part = part, highlight = highlight }
    previews[player] = record
    return record
end

local function inspectLineOfSight(targetPlayer, targetPart, localRoot)
    local origin = localRoot.Position
    local direction = targetPart.Position - origin
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {
        LocalPlayer.Character,
        targetPlayer.Character,
        previewFolder,
    }
    params.IgnoreWater = false

    local result = Workspace:Raycast(origin, direction, params)
    return result == nil, result
end

local function updatePreview(player, localRoot)
    local character = player.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local targetPart = getTargetPart(character)

    if not humanoid or humanoid.Health <= 0 or not targetPart then
        removePreview(player)
        return nil
    end

    local distance = (targetPart.Position - localRoot.Position).Magnitude
    if distance > CONFIG.MaxDistance then
        removePreview(player)
        return nil
    end

    local visible = inspectLineOfSight(player, targetPart, localRoot)
    local record = previews[player] or makePreview(player)
    local velocity = targetPart.AssemblyLinearVelocity
    local offset = velocity * math.max(0, CONFIG.PredictionSeconds)

    if offset.Magnitude > CONFIG.MaxPredictionDistance then
        offset = offset.Unit * CONFIG.MaxPredictionDistance
    end

    local scale = visible and CONFIG.VisibleScale or CONFIG.BlockedScale
    local color = visible and CONFIG.Color or Color3.fromRGB(255, 75, 75)

    record.part.Size = CONFIG.HitboxSize * scale
    record.part.CFrame = CFrame.new(targetPart.Position + offset)
    record.part.Color = color
    record.part.Transparency = math.clamp(CONFIG.Transparency, 0, 1)

    if record.highlight then
        record.highlight.Adornee = character
        record.highlight.OutlineColor = color
        record.highlight.FillColor = color
        if record.highlight.Parent ~= character then
            record.highlight.Parent = character
        end
    end

    return visible, offset
end

local function updateHUD()
    if hudLabel then
        hudLabel.Text = string.format(
            "SEROID // HITBOX DIAGNOSTICS\nTargets: %d | Visible: %d\nBlocked: %d\nPart: %s | Preview: %s\nToggle: RightControl",
            activeCount,
            visibleCount,
            blockedCount,
            CONFIG.TargetPart,
            CONFIG.Enabled and "ON" or "OFF"
        )
    end
end

local function registerPlayer(player)
    if player == LocalPlayer then
        return
    end

    connect(player.CharacterAdded, function()
        removePreview(player)
    end)

    connect(player.CharacterRemoving, function()
        removePreview(player)
    end)
end

for _, player in ipairs(Players:GetPlayers()) do
    registerPlayer(player)
end

connect(Players.PlayerAdded, registerPlayer)
connect(Players.PlayerRemoving, removePreview)

connect(UserInputService.InputBegan, function(input, processed)
    if processed or input.KeyCode ~= CONFIG.ToggleKey then
        return
    end

    CONFIG.Enabled = not CONFIG.Enabled
    if not CONFIG.Enabled then
        removeAllPreviews()
        activeCount = 0
        visibleCount = 0
        blockedCount = 0
        averagePrediction = Vector3.zero
    end
    updateHUD()
end)

local playerGui = LocalPlayer:WaitForChild("PlayerGui")
gui.Parent = playerGui

connect(RunService.Heartbeat, function(deltaTime)
    if not running or not CONFIG.Enabled then
        return
    end

    accumulator += deltaTime
    if accumulator < CONFIG.UpdateInterval then
        return
    end
    accumulator = 0

    local character = LocalPlayer.Character
    local localRoot = character and character:FindFirstChild("HumanoidRootPart")
    if not localRoot then
        removeAllPreviews()
        activeCount = 0
        visibleCount = 0
        blockedCount = 0
        averagePrediction = Vector3.zero
        updateHUD()
        return
    end

    activeCount = 0
    visibleCount = 0
    blockedCount = 0
    local predictionSum = Vector3.zero

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local visible, offset = updatePreview(player, localRoot)
            if visible ~= nil then
                predictionSum += offset or Vector3.zero
                activeCount += 1
                if visible then
                    visibleCount += 1
                else
                    blockedCount += 1
                end
            end
        end
    end

    averagePrediction = activeCount > 0 and predictionSum / activeCount or Vector3.zero
    updateHUD()
end)

connect(script.Destroying, function()
    running = false
    removeAllPreviews()

    for _, connection in ipairs(connections) do
        connection:Disconnect()
    end

    if gui then
        gui:Destroy()
    end
    if previewFolder then
        previewFolder:Destroy()
    end
end)
