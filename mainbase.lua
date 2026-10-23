-- Luau | mainbase.lua | Roblox client runtime
-- Insert after `local controls = {}` and before `-- Speed controls`.
-- Client-only development visualizer: does not modify real character hitboxes,
-- intercept Mouse.Target, spoof metatables, or manipulate RemoteEvents.

local HitboxSection = VisualsTab:Section({
    Name = "Hitbox Simulation",
    Side = 2,
})

local HitboxConfig = {
    Enabled = false,
    TargetPart = "HumanoidRootPart",
    Shape = "Block",
    Multiplier = 2.5,
    PredictionTime = 0.10,
    Transparency = 0.65,
    ShowHighlight = true,
    ShowHUD = true,
    MaxDistance = 500,
    UpdateInterval = 0.08,
}

local hitboxProxies = {}
local hitboxHighlights = {}
local hitboxElapsed = 0
local hitboxGui
local hitboxStatus = {
    Targets = 0,
    Visible = 0,
    Blocked = 0,
    Prediction = Vector3.zero,
}

local function removeHitboxVisuals()
    for player, proxy in pairs(hitboxProxies) do
        if proxy and proxy.Parent then
            proxy:Destroy()
        end
        hitboxProxies[player] = nil
    end

    for player, highlight in pairs(hitboxHighlights) do
        if highlight and highlight.Parent then
            highlight:Destroy()
        end
        hitboxHighlights[player] = nil
    end
end

local function getTargetPart(character)
    if not character then
        return nil
    end

    if HitboxConfig.TargetPart == "Head" then
        return character:FindFirstChild("Head")
    end

    if HitboxConfig.TargetPart == "Torso" then
        return character:FindFirstChild("UpperTorso")
            or character:FindFirstChild("Torso")
    end

    return character:FindFirstChild("HumanoidRootPart")
end

local function getOrCreateProxy(targetPlayer)
    local proxy = hitboxProxies[targetPlayer]

    if proxy and proxy.Parent then
        return proxy
    end

    proxy = Instance.new("Part")
    proxy.Name = "seroid_HitboxPreview"
    proxy.Anchored = true
    proxy.CanCollide = false
    proxy.CanTouch = false
    proxy.CanQuery = false
    proxy.CastShadow = false
    proxy.Massless = true
    proxy.Material = Enum.Material.Neon
    proxy.Color = Color3.fromRGB(80, 220, 120)
    proxy.Transparency = HitboxConfig.Transparency
    proxy.Size = Vector3.new(4, 5, 4)
    proxy.Shape = Enum.PartType.Block
    proxy.Parent = workspace

    hitboxProxies[targetPlayer] = proxy
    return proxy
end

local function getOrCreateHighlight(targetPlayer, character)
    local existing = hitboxHighlights[targetPlayer]

    if existing and existing.Parent == character then
        return existing
    end

    if existing then
        existing:Destroy()
    end

    local highlight = Instance.new("Highlight")
    highlight.Name = "seroid_TargetDiagnostic"
    highlight.Adornee = character
    highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    highlight.FillTransparency = 0.82
    highlight.OutlineTransparency = 0.15
    highlight.Parent = character

    hitboxHighlights[targetPlayer] = highlight
    return highlight
end

local function inspectTarget(targetPlayer, targetPart, localRoot)
    local offset = targetPart.AssemblyLinearVelocity
        * HitboxConfig.PredictionTime

    -- Bound prediction so sudden physics impulses cannot move the preview
    -- arbitrarily far from the character.
    if offset.Magnitude > 12 then
        offset = offset.Unit * 12
    end

    local predictedPosition = targetPart.Position + offset
    local rayDirection = targetPart.Position - localRoot.Position

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = {
        player.Character,
        targetPlayer.Character,
    }
    params.IgnoreWater = false

    local obstruction = workspace:Raycast(
        localRoot.Position,
        rayDirection,
        params
    )

    local color
    local status

    if not obstruction then
        color = Color3.fromRGB(80, 220, 120)
        status = "VISIBLE"
    else
        local obstacle = obstruction.Instance
        local name = string.lower(obstacle.Name)

        -- This is a configurable diagnostic heuristic, not proof that
        -- the weapon or game permits penetration through the obstacle.
        local heuristicPenetrable =
            string.find(name, "glass", 1, true) ~= nil
            or string.find(name, "wood", 1, true) ~= nil
            or obstacle.Material == Enum.Material.Glass
            or obstacle.Material == Enum.Material.Wood
            or obstacle.Material == Enum.Material.WoodPlanks

        if heuristicPenetrable then
            color = Color3.fromRGB(255, 205, 65)
            status = "POSSIBLE OBSTRUCTION"
        else
            color = Color3.fromRGB(255, 85, 85)
            status = "BLOCKED"
        end
    end

    return predictedPosition, offset, color, status
end

local function destroyTargetVisual(targetPlayer)
    local proxy = hitboxProxies[targetPlayer]
    if proxy then
        proxy:Destroy()
        hitboxProxies[targetPlayer] = nil
    end

    local highlight = hitboxHighlights[targetPlayer]
    if highlight then
        highlight:Destroy()
        hitboxHighlights[targetPlayer] = nil
    end
end

local function createHitboxHUD()
    local playerGui = player:FindFirstChildOfClass("PlayerGui")
    if not playerGui then
        return
    end

    if hitboxGui then
        hitboxGui:Destroy()
    end

    hitboxGui = Instance.new("ScreenGui")
    hitboxGui.Name = "seroid_HitboxDiagnostics"
    hitboxGui.ResetOnSpawn = false
    hitboxGui.DisplayOrder = 20
    hitboxGui.Parent = playerGui

    local panel = Instance.new("Frame")
    panel.Name = "Metrics"
    panel.AnchorPoint = Vector2.new(1, 0)
    panel.Position = UDim2.new(1, -16, 0, 16)
    panel.Size = UDim2.fromOffset(245, 118)
    panel.BackgroundColor3 = Color3.fromRGB(18, 20, 29)
    panel.BackgroundTransparency = 0.12
    panel.BorderSizePixel = 0
    panel.Parent = hitboxGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = panel

    local label = Instance.new("TextLabel")
    label.Name = "Readout"
    label.Position = UDim2.fromOffset(10, 8)
    label.Size = UDim2.new(1, -20, 1, -16)
    label.BackgroundTransparency = 1
    label.Font = Enum.Font.Code
    label.TextSize = 13
    label.TextColor3 = Color3.fromRGB(230, 232, 245)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextYAlignment = Enum.TextYAlignment.Top
    label.Text = "SEROID // HITBOX DIAGNOSTICS"
    label.Parent = panel
end

local function updateHitboxHUD()
    if not HitboxConfig.ShowHUD then
        if hitboxGui then
            hitboxGui.Enabled = false
        end
        return
    end

    if not hitboxGui or not hitboxGui.Parent then
        createHitboxHUD()
    end

    if not hitboxGui then
        return
    end

    hitboxGui.Enabled = true

    local panel = hitboxGui:FindFirstChild("Metrics")
    local label = panel and panel:FindFirstChild("Readout")

    if label then
        local p = hitboxStatus.Prediction

        label.Text = string.format(
            "SEROID // HITBOX DIAGNOSTICS\nTargets: %d | Visible: %d\nBlocked: %d | FPS: %d\nPrediction: %.2f, %.2f, %.2f\nMode: LOCAL VISUAL PREVIEW",
            hitboxStatus.Targets,
            hitboxStatus.Visible,
            hitboxStatus.Blocked,
            math.floor(1 / math.max(RunService.RenderStepped:Wait(), 1 / 240)),
            p.X,
            p.Y,
            p.Z
        )
    end
end

controls.HitboxEnabled = HitboxSection:Toggle({
    Name = "Enable visual simulation",
    Flag = "seroid_HitboxEnabled",
    Default = false,
    Callback = function(value)
        HitboxConfig.Enabled = value

        if not value then
            removeHitboxVisuals()
            hitboxStatus.Targets = 0
            hitboxStatus.Visible = 0
            hitboxStatus.Blocked = 0
        end

        notify(
            "Hitbox simulation",
            value and "Local visual previews enabled."
                or "Local visual previews disabled.",
            "info"
        )
    end,
})

controls.HitboxTarget = HitboxSection:Dropdown({
    Name = "Target part",
    Flag = "seroid_HitboxTarget",
    Items = { "Head", "HumanoidRootPart", "Torso" },
    Default = HitboxConfig.TargetPart,
    Callback = function(value)
        HitboxConfig.TargetPart = value
    end,
})

controls.HitboxShape = HitboxSection:Dropdown({
    Name = "Preview shape",
    Flag = "seroid_HitboxShape",
    Items = { "Block", "Ball" },
    Default = HitboxConfig.Shape,
    Callback = function(value)
        HitboxConfig.Shape = value
    end,
})

controls.HitboxSize = HitboxSection:Slider({
    Name = "Preview size multiplier",
    Flag = "seroid_HitboxSize",
    Min = 1,
    Max = 8,
    Default = HitboxConfig.Multiplier,
    Decimals = 0.25,
    Callback = function(value)
        HitboxConfig.Multiplier = math.clamp(value, 1, 8)
    end,
})

controls.HitboxPrediction = HitboxSection:Slider({
    Name = "Prediction time",
    Flag = "seroid_HitboxPrediction",
    Min = 0,
    Max = 0.30,
    Default = HitboxConfig.PredictionTime,
    Decimals = 0.01,
    Callback = function(value)
        HitboxConfig.PredictionTime = math.clamp(value, 0, 0.30)
    end,
})

controls.HitboxTransparency = HitboxSection:Slider({
    Name = "Preview transparency",
    Flag = "seroid_HitboxTransparency",
    Min = 0.10,
    Max = 0.95,
    Default = HitboxConfig.Transparency,
    Decimals = 0.05,
    Callback = function(value)
        HitboxConfig.Transparency = math.clamp(value, 0.10, 0.95)
    end,
})

controls.HitboxHighlight = HitboxSection:Toggle({
    Name = "Character highlight",
    Flag = "seroid_HitboxHighlight",
    Default = HitboxConfig.ShowHighlight,
    Callback = function(value)
        HitboxConfig.ShowHighlight = value

        if not value then
            for _, highlight in pairs(hitboxHighlights) do
                highlight:Destroy()
            end
            table.clear(hitboxHighlights)
        end
    end,
})

controls.HitboxHUD = HitboxSection:Toggle({
    Name = "Diagnostic HUD",
    Flag = "seroid_HitboxHUD",
    Default = HitboxConfig.ShowHUD,
    Callback = function(value)
        HitboxConfig.ShowHUD = value

        if hitboxGui then
            hitboxGui.Enabled = value
        end
    end,
})

-- Event-driven player tracking; visual updates use a bounded cadence.
local function registerHitboxPlayer(targetPlayer)
    if targetPlayer == player then
        return
    end

    track(targetPlayer.CharacterAdded:Connect(function()
        destroyTargetVisual(targetPlayer)
    end))

    track(targetPlayer.CharacterRemoving:Connect(function()
        destroyTargetVisual(targetPlayer)
    end))
end

for _, targetPlayer in ipairs(Players:GetPlayers()) do
    registerHitboxPlayer(targetPlayer)
end

track(Players.PlayerAdded:Connect(registerHitboxPlayer))

track(Players.PlayerRemoving:Connect(function(targetPlayer)
    destroyTargetVisual(targetPlayer)
end))

track(RunService.Heartbeat:Connect(function(deltaTime)
    if not alive then
        return
    end

    hitboxElapsed += deltaTime
    if hitboxElapsed < HitboxConfig.UpdateInterval then
        return
    end
    hitboxElapsed = 0

    if not HitboxConfig.Enabled then
        return
    end

    local localCharacter = player.Character
    local localRoot = localCharacter
        and localCharacter:FindFirstChild("HumanoidRootPart")

    if not localRoot then
        return
    end

    local count = 0
    local visible = 0
    local blocked = 0
    local predictionSum = Vector3.zero

    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= player then
            local character = targetPlayer.Character
            local humanoid = character
                and character:FindFirstChildOfClass("Humanoid")
            local targetPart = getTargetPart(character)

            if humanoid and humanoid.Health > 0 and targetPart then
                local distance = (targetPart.Position - localRoot.Position).Magnitude

                if distance <= HitboxConfig.MaxDistance then
                    count += 1

                    local position, offset, color, status =
                        inspectTarget(targetPlayer, targetPart, localRoot)

                    local proxy = getOrCreateProxy(targetPlayer)
                    local multiplier = HitboxConfig.Multiplier

                    proxy.Size = targetPart.Size * multiplier
                    proxy.Shape = HitboxConfig.Shape == "Ball"
                        and Enum.PartType.Ball
                        or Enum.PartType.Block
                    proxy.CFrame = CFrame.new(position)
                    proxy.Color = color
                    proxy.Transparency = HitboxConfig.Transparency
                    proxy.Material = Enum.Material.Neon

                    predictionSum += offset

                    if status == "VISIBLE" then
                        visible += 1
                    elseif status == "BLOCKED" then
                        blocked += 1
                    end

                    if HitboxConfig.ShowHighlight then
                        local highlight = getOrCreateHighlight(
                            targetPlayer,
                            character
                        )
                        highlight.FillColor = color
                        highlight.OutlineColor = color
                    elseif hitboxHighlights[targetPlayer] then
                        hitboxHighlights[targetPlayer]:Destroy()
                        hitboxHighlights[targetPlayer] = nil
                    end
                else
                    destroyTargetVisual(targetPlayer)
                end
            else
                destroyTargetVisual(targetPlayer)
            end
        end
    end

    hitboxStatus.Targets = count
    hitboxStatus.Visible = visible
    hitboxStatus.Blocked = blocked
    hitboxStatus.Prediction = count > 0
        and predictionSum / count
        or Vector3.zero

    updateHitboxHUD()
end))

-- Add these cleanup lines inside the existing cleanup() function,
-- before VibeUI:Unload().
removeHitboxVisuals()

if hitboxGui then
    hitboxGui:Destroy()
    hitboxGui = nil
end
