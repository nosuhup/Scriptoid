--[[
    seroid.lua — VibeUI movement + camera utility panel (Ultimate Backstab & Keybind Edition)
    Defaults: speed 37, smooth movement on, FOV off, jump boost off.
    UI library: https://sirmemegithub.com/RealSlimShady2000/VibeUI
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
if not player then
    warn("[seroid] LocalPlayer is unavailable.")
    return
end

local ENV = (type(getgenv) == "function" and getgenv()) or _G

-- Clean up an earlier copy before creating another one.
if type(ENV.seroidCleanup) == "function" then
    pcall(ENV.seroidCleanup)
end

local DEFAULTS = {
    SpeedEnabled = true,
    Speed = 37,
    SmoothMovement = true,
    Smoothing = 0.35,
    GroundOnly = false,
    PreserveVerticalVelocity = true,

    JumpEnabled = false,
    JumpMode = "Power",
    JumpValue = 70,

    FOVEnabled = false,
    FOV = 85,

    -- Dash & Backstab settings
    DashEnabled = true,
    DashCooldown = 3.9,
    DashDuration = 0.1,        -- 0.1s smooth dash speed (anti-rubberband)
    DashMagnetRange = 85,      -- Max detection range for targets
    BackstabOffset = 6.0,      -- Distance behind target in studs
    
    -- Keybinds
    KeyToggle = Enum.KeyCode.H,
    KeyStraight = Enum.KeyCode.Q,
    KeyBackstab = Enum.KeyCode.R,
}

local state = {}
for key, value in pairs(DEFAULTS) do
    state[key] = value
end

local alive = true
local connections = {}
local originalJump = setmetatable({}, { __mode = "k" })
local originalFOV = nil
local lastDashTick = 0
local isDashing = false
local VibeUI
local currentCamera = Workspace.CurrentCamera
if currentCamera then
    originalFOV = currentCamera.FieldOfView
end

local function track(connection)
    table.insert(connections, connection)
    return connection
end

local function notify(title, description, kind)
    pcall(function()
        VibeUI:Notification({
            Title = title,
            Description = description,
            Type = kind or "info",
            Duration = 3,
        })
    end)
end

local function getCharacter()
    return player.Character
end

local function getHumanoid()
    local character = getCharacter()
    return character and character:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
    local character = getCharacter()
    if not character then
        return nil
    end

    return character:FindFirstChild("HumanoidRootPart")
        or character.PrimaryPart
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("UpperTorso")
end

local function captureJump(humanoid)
    if humanoid and not originalJump[humanoid] then
        originalJump[humanoid] = {
            UseJumpPower = humanoid.UseJumpPower,
            JumpPower = humanoid.JumpPower,
            JumpHeight = humanoid.JumpHeight,
        }
    end
end

local function applyJump()
    local humanoid = getHumanoid()
    if not humanoid then
        return
    end

    captureJump(humanoid)

    if not state.JumpEnabled then
        local saved = originalJump[humanoid]
        if saved then
            pcall(function()
                humanoid.UseJumpPower = saved.UseJumpPower
                humanoid.JumpPower = saved.JumpPower
                humanoid.JumpHeight = saved.JumpHeight
            end)
        end
        return
    end

    pcall(function()
        if state.JumpMode == "Height" then
            humanoid.UseJumpPower = false
            humanoid.JumpHeight = state.JumpValue
        else
            humanoid.UseJumpPower = true
            humanoid.JumpPower = state.JumpValue
        end
    end)
end

local function applyFOV()
    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end

    if state.FOVEnabled then
        camera.FieldOfView = math.clamp(state.FOV, 50, 120)
    elseif originalFOV then
        camera.FieldOfView = originalFOV
    end
end

-- Play custom dash animation
local function playDashAnimation(humanoid)
    if not humanoid then return end
    pcall(function()
        local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator", 0.5)
        if not animator then return end
        
        local anim = Instance.new("Animation")
        anim.AnimationId = "rbxassetid://10490011756"
        local trackAnim = animator:LoadAnimation(anim)
        trackAnim.Priority = Enum.AnimationPriority.Action4
        trackAnim:Play()
    end)
end

-- Find closest target near camera crosshair view
local function getClosestTargetToAim()
    local camera = Workspace.CurrentCamera
    local localRoot = getRoot()
    if not camera or not localRoot then return nil end

    local closestTargetRoot = nil
    local bestScore = math.huge
    local camPos = camera.CFrame.Position
    local camLook = camera.CFrame.LookVector

    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= player and p.Character then
            local targetRoot = p.Character:FindFirstChild("HumanoidRootPart")
                or p.Character.PrimaryPart
            local humanoid = p.Character:FindFirstChildOfClass("Humanoid")
            if targetRoot and humanoid and humanoid.Health > 0 then
                local toTarget = targetRoot.Position - camPos
                local dist = toTarget.Magnitude
                if dist <= state.DashMagnetRange then
                    local unitDir = toTarget.Unit
                    local dot = camLook:Dot(unitDir)
                    if dot > 0.05 then
                        local score = dist / (dot * 2)
                        if score < bestScore then
                            bestScore = score
                            closestTargetRoot = targetRoot
                        end
                    end
                end
            end
        end
    end

    return closestTargetRoot
end

-- Perform dash mode: "Straight" (Q) or "Backstab" (R)
local function performDash(mode)
    if not state.DashEnabled or isDashing then return end
    local now = tick()
    if now - lastDashTick < state.DashCooldown then
        local remaining = math.ceil((state.DashCooldown - (now - lastDashTick)) * 10) / 10
        notify("Dash Cooldown", "Wait " .. remaining .. "s before dashing again.", "warning")
        return
    end

    local root = getRoot()
    local humanoid = getHumanoid()
    if not root or not humanoid or humanoid.Health <= 0 then return end

    lastDashTick = now
    isDashing = true

    playDashAnimation(humanoid)

    local targetCFrame
    local targetRoot = getClosestTargetToAim()

    if mode == "Backstab" and targetRoot then
        -- Calculate position directly behind the target's look vector
        local targetPos = targetRoot.Position
        local targetLook = targetRoot.CFrame.LookVector
        -- Offset backwards from the target's facing direction
        local backPos = targetPos - (Vector3.new(targetLook.X, 0, targetLook.Z).Unit * state.BackstabOffset)
        backPos = Vector3.new(backPos.X, targetPos.Y, backPos.Z) -- Match height
        
        -- Look directly back at the target so player is facing them ready to strike
        targetCFrame = CFrame.new(backPos, targetPos)
        notify("Backstab Dash", "Flanked behind target successfully!", "success")
    elseif mode == "Straight" and targetRoot then
        -- Straight magnet right onto the target player's center
        local targetPos = targetRoot.Position
        local lookDir = (targetPos - root.Position)
        lookDir = Vector3.new(lookDir.X, 0, lookDir.Z).Unit
        if lookDir.Magnitude ~= lookDir.Magnitude then lookDir = root.CFrame.LookVector end
        targetCFrame = CFrame.new(targetPos, targetPos + lookDir)
        notify("Straight Dash", "Magnetized to target straight-on.", "success")
    else
        -- Fallback: forward vector based on camera/root
        local camera = Workspace.CurrentCamera
        local lookVec = camera and camera.CFrame.LookVector or root.CFrame.LookVector
        local flatDir = Vector3.new(lookVec.X, 0, lookVec.Z).Unit
        if flatDir.Magnitude ~= flatDir.Magnitude then flatDir = Vector3.new(0, 0, -1) end
        
        local fallbackPos = root.Position + (flatDir * 35)
        targetCFrame = CFrame.new(fallbackPos, fallbackPos + flatDir)
        notify("Dash", "Performed standard forward dash.", "info")
    end

    -- Smooth tween over 0.1 seconds to completely bypass server anti-cheat rubberbanding
    local tweenInfo = TweenInfo.new(state.DashDuration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween = TweenService:Create(root, tweenInfo, { CFrame = targetCFrame })
    
    tween:Play()
    tween.Completed:Connect(function()
        isDashing = false
    end)
end

-- Load UI Library
local libraryURL =
    "https://sirmemegithub.com/RealSlimShady2000/VibeUI/raw/branch/main/VibeUI.luau"

local loadOK, libraryOrError = pcall(function()
    assert(type(loadstring) == "function", "loadstring is unavailable in this environment")
    local response = game:HttpGet(libraryURL)
    local compile = loadstring(response)
    assert(type(compile) == "function", "VibeUI source did not compile")
    return compile()
end)

if not loadOK or type(libraryOrError) ~= "table" then
    warn("[seroid] Could not load VibeUI:", libraryOrError)
    return
end

VibeUI = libraryOrError

pcall(function()
    VibeUI.Config.Rounded = true
    VibeUI.Config.MobileToggle = true
    VibeUI.Config.CustomCursor = true
    VibeUI.Config.FadeSpeed = 0.20
    VibeUI.Config.NotificationDuration = 4
    VibeUI.Config.Tween.Time = 0.20
    VibeUI:SetTheme({
        Accent = Color3.fromRGB(145, 105, 255),
        Background = Color3.fromRGB(16, 17, 25),
    })
    VibeUI:SetOutlines(true)
    VibeUI:SetGlow(0.15)
    VibeUI:SetNotificationSide("BottomRight")
end)

local Window = VibeUI:Window({
    Title = "seroid",
    Size = UDim2.fromOffset(700, 510),
    Keybind = Enum.KeyCode.RightControl,
    Layout = "Side",
    Resizable = true,
})

local MovementTab = Window:Tab({ Name = "Movement", Columns = 2 })
local SpeedSection = MovementTab:Section({ Name = "Speed Control", Side = 1 })
local MotionSection = MovementTab:Section({ Name = "Movement Options", Side = 2 })
local JumpSection = MovementTab:Section({ Name = "Jump Control", Side = 2 })
local DashSection = MovementTab:Section({ Name = "Dash & Backstab Control", Side = 1 })

local VisualsTab = Window:Tab({ Name = "Visuals", Columns = 2 })
local CameraSection = VisualsTab:Section({ Name = "Camera", Side = 1 })
local UtilitySection = VisualsTab:Section({ Name = "Utilities", Side = 2 })

local ConfigTab = Window:Tab({ Name = "Profiles", Columns = 2 })
local ProfileSection = ConfigTab:Section({ Name = "Quick Profiles", Side = 1 })
local StatusSection = ConfigTab:Section({ Name = "Status & Safety", Side = 2 })

local controls = {}

-- Speed controls
controls.SpeedEnabled = SpeedSection:Toggle({
    Name = "Enable speed",
    Flag = "seroid_SpeedEnabled",
    Default = DEFAULTS.SpeedEnabled,
    Callback = function(value)
        state.SpeedEnabled = value
        ENV.SpeedEnabled = value
        notify("Speed", value and "Movement boost enabled." or "Movement boost disabled.", "info")
    end,
})
controls.SpeedEnabled:AddKeybind({
    Flag = "seroid_SpeedKey",
    Default = Enum.KeyCode.LeftControl,
    Mode = "Toggle",
})

controls.Speed = SpeedSection:Slider({
    Name = "Speed",
    Flag = "seroid_Speed",
    Min = 8,
    Max = 80,
    Default = DEFAULTS.Speed,
    Decimals = 1,
    Suffix = " studs/s",
    Callback = function(value)
        state.Speed = math.clamp(value, 8, 80)
        ENV.Speed = state.Speed
    end,
})

controls.SpeedPreset = SpeedSection:Dropdown({
    Name = "Speed preset",
    Flag = "seroid_SpeedPreset",
    Items = {
        "Walk (16)",
        "Run (28)",
        "seroid (37)",
        "Turbo (50)",
        "Extreme (65)",
    },
    Default = "seroid (37)",
    Callback = function(value)
        local number = tonumber(string.match(value or "", "%((%d+)%)"))
        if number then
            controls.Speed:Set(number)
        end
    end,
})

local speedButtons = SpeedSection:Button()
speedButtons:Add("Default speed", function()
    controls.Speed:Set(DEFAULTS.Speed)
    controls.SpeedPreset:Set("seroid (37)")
    notify("Speed reset", "Speed set to 37.", "success")
end)
speedButtons:Add("Disable speed", function()
    controls.SpeedEnabled:Set(false)
end)

-- Dash & Backstab controls setup with explicit Keybind toggles & sliders
controls.DashEnabled = DashSection:Toggle({
    Name = "Enable Dash / Backstab (H)",
    Flag = "seroid_DashEnabled",
    Default = DEFAULTS.DashEnabled,
    Callback = function(value)
        state.DashEnabled = value
    end,
})
controls.DashEnabled:AddKeybind({
    Flag = "seroid_DashToggleKey",
    Default = DEFAULTS.KeyToggle,
    Mode = "Toggle",
})

controls.BackstabOffset = DashSection:Slider({
    Name = "Backstab Distance Behind",
    Flag = "seroid_BackstabOffset",
    Min = 2,
    Max = 15,
    Default = DEFAULTS.BackstabOffset,
    Decimals = 0.5,
    Suffix = " studs",
    Callback = function(value)
        state.BackstabOffset = value
    end,
})

controls.DashMagnetRange = DashSection:Slider({
    Name = "Magnet Range",
    Flag = "seroid_DashMagnetRange",
    Min = 20,
    Max = 150,
    Default = DEFAULTS.DashMagnetRange,
    Decimals = 1,
    Suffix = " studs",
    Callback = function(value)
        state.DashMagnetRange = value
    end,
})

controls.DashCooldown = DashSection:Slider({
    Name = "Dash Cooldown",
    Flag = "seroid_DashCooldown",
    Min = 0.5,
    Max = 10.0,
    Default = DEFAULTS.DashCooldown,
    Decimals = 1,
    Suffix = " s",
    Callback = function(value)
        state.DashCooldown = value
    end,
})

local dashButtons = DashSection:Button()
dashButtons:Add("Test Straight (Q)", function()
    performDash("Straight")
end)
dashButtons:Add("Test Backstab (R)", function()
    performDash("Backstab")
end)

-- Movement quality options
controls.SmoothMovement = MotionSection:Toggle({
    Name = "Smooth acceleration",
    Flag = "seroid_SmoothMovement",
    Default = DEFAULTS.SmoothMovement,
    Callback = function(value)
        state.SmoothMovement = value
    end,
})

controls.Smoothing = MotionSection:Slider({
    Name = "Smoothing strength",
    Flag = "seroid_Smoothing",
    Min = 0.05,
    Max = 0.90,
    Default = DEFAULTS.Smoothing,
    Decimals = 0.05,
    Callback = function(value)
        state.Smoothing = math.clamp(value, 0.05, 0.90)
    end,
})

controls.GroundOnly = MotionSection:Toggle({
    Name = "Ground only",
    Flag = "seroid_GroundOnly",
    Default = DEFAULTS.GroundOnly,
    Info = "Only apply the speed boost while grounded.",
    Callback = function(value)
        state.GroundOnly = value
    end,
})

controls.PreserveVerticalVelocity = MotionSection:Toggle({
    Name = "Preserve vertical velocity",
    Flag = "seroid_PreserveVertical",
    Default = DEFAULTS.PreserveVerticalVelocity,
    Info = "Avoid replacing the Y velocity used for falling or jumping.",
    Callback = function(value)
        state.PreserveVerticalVelocity = value
    end,
})

-- Jump controls
controls.JumpEnabled = JumpSection:Toggle({
    Name = "Enable jump boost",
    Flag = "seroid_JumpEnabled",
    Default = DEFAULTS.JumpEnabled,
    Callback = function(value)
        state.JumpEnabled = value
        applyJump()
    end,
})

controls.JumpMode = JumpSection:Dropdown({
    Name = "Jump mode",
    Flag = "seroid_JumpMode",
    Items = { "Power", "Height" },
    Default = DEFAULTS.JumpMode,
    Callback = function(value)
        state.JumpMode = value
        applyJump()
    end,
})

controls.JumpValue = JumpSection:Slider({
    Name = "Jump value",
    Flag = "seroid_JumpValue",
    Min = 20,
    Max = 150,
    Default = DEFAULTS.JumpValue,
    Decimals = 1,
    Callback = function(value)
        state.JumpValue = math.clamp(value, 20, 150)
        applyJump()
    end,
})

local jumpButtons = JumpSection:Button()
jumpButtons:Add("Reset jump", function()
    controls.JumpEnabled:Set(false)
    controls.JumpMode:Set(DEFAULTS.JumpMode)
    controls.JumpValue:Set(DEFAULTS.JumpValue)
    applyJump()
    notify("Jump reset", "Original jump settings restored.", "success")
end)

-- Camera controls
controls.FOVEnabled = CameraSection:Toggle({
    Name = "Custom field of view",
    Flag = "seroid_FOVEnabled",
    Default = DEFAULTS.FOVEnabled,
    Callback = function(value)
        state.FOVEnabled = value
        applyFOV()
    end,
})

controls.FOV = CameraSection:Slider({
    Name = "Field of view",
    Flag = "seroid_FOV",
    Min = 50,
    Max = 120,
    Default = DEFAULTS.FOV,
    Decimals = 1,
    Suffix = "°",
    Callback = function(value)
        state.FOV = math.clamp(value, 50, 120)
        if state.FOVEnabled then
            applyFOV()
        end
    end,
})

controls.FOVPreset = CameraSection:Dropdown({
    Name = "FOV preset",
    Flag = "seroid_FOVPreset",
    Items = { "Default (70)", "Wide (85)", "Very wide (100)", "Max (120)" },
    Default = "Wide (85)",
    Callback = function(value)
        local number = tonumber(string.match(value or "", "%((%d+)%)"))
        if number then
            controls.FOV:Set(number)
        end
    end,
})

local cameraButtons = CameraSection:Button()
cameraButtons:Add("Reset FOV", function()
    controls.FOVEnabled:Set(false)
    controls.FOV:Set(70)
    controls.FOVPreset:Set("Default (70)")
    applyFOV()
    notify("Camera reset", "Original camera FOV restored.", "success")
end)

-- Quick profiles
local profileName = "seroid_default"

local profileButtons = ProfileSection:Button()
profileButtons:Add("Save profile", function()
    local ok, err = pcall(function()
        VibeUI:SaveConfig(profileName)
    end)
    if ok then
        notify("Profile saved", "Saved as '" .. profileName .. "'.", "success")
    else
        notify("Save failed", tostring(err), "error")
    end
end)
profileButtons:Add("Load profile", function()
    local ok, err = pcall(function()
        local config = VibeUI:ReadConfig(profileName)
        if not config then
            error("No saved profile named '" .. profileName .. "' was found.")
        end
        VibeUI:LoadConfig(config)
    end)
    if ok then
        notify("Profile loaded", "Loaded '" .. profileName .. "'.", "success")
    else
        notify("Load failed", tostring(err), "error")
    end
end)

local resetButtons = ProfileSection:Button()
resetButtons:Add("Reset all", function()
    controls.SpeedEnabled:Set(DEFAULTS.SpeedEnabled)
    controls.Speed:Set(DEFAULTS.Speed)
    controls.SpeedPreset:Set("seroid (37)")
    controls.SmoothMovement:Set(DEFAULTS.SmoothMovement)
    controls.Smoothing:Set(DEFAULTS.Smoothing)
    controls.GroundOnly:Set(DEFAULTS.GroundOnly)
    controls.PreserveVerticalVelocity:Set(DEFAULTS.PreserveVerticalVelocity)
    controls.JumpEnabled:Set(DEFAULTS.JumpEnabled)
    controls.JumpMode:Set(DEFAULTS.JumpMode)
    controls.JumpValue:Set(DEFAULTS.JumpValue)
    controls.FOVEnabled:Set(DEFAULTS.FOVEnabled)
    controls.FOV:Set(DEFAULTS.FOV)
    controls.FOVPreset:Set("Wide (85)")
    controls.DashEnabled:Set(DEFAULTS.DashEnabled)
    controls.BackstabOffset:Set(DEFAULTS.BackstabOffset)
    controls.DashMagnetRange:Set(DEFAULTS.DashMagnetRange)
    controls.DashCooldown:Set(DEFAULTS.DashCooldown)
    applyJump()
    applyFOV()
    notify("Reset complete", "seroid settings returned to defaults.", "success")
end)

local infoOK = pcall(function()
    StatusSection:Paragraph({
        Name = "Runtime status",
        Content = "Speed loop: client-side | Toggle: H | Straight: Q | Backstab Flank: R",
    })
    StatusSection:Paragraph({
        Name = "Compatibility",
        Content = "R6/R15/custom rigs supported. Anti-rubberband tweening active.",
    })
    StatusSection:Paragraph({
        Name = "Safety",
        Content = "Unload restores captured jump and camera settings and disconnects event connections.",
    })
end)

pcall(function()
    VibeUI:CreateSettingsPage(Window)
end)

ENV.Speed = state.Speed
ENV.SpeedEnabled = state.SpeedEnabled
ENV.Loop = true

-- Input listener for Keybinds (H = Toggle, Q = Straight Magnet, R = Backstab Flank)
track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    
    if input.KeyCode == state.KeyToggle then
        state.DashEnabled = not state.DashEnabled
        controls.DashEnabled:Set(state.DashEnabled)
        notify("Dash System", state.DashEnabled and "Enabled" or "Disabled", state.DashEnabled and "success" or "warning")
    elseif input.KeyCode == state.KeyStraight then
        performDash("Straight")
    elseif input.KeyCode == state.KeyBackstab then
        performDash("Backstab")
    end
end))

-- Movement loop
track(RunService.Heartbeat:Connect(function(deltaTime)
    if not alive or not state.SpeedEnabled then
        return
    end

    local humanoid = getHumanoid()
    local root = getRoot()
    if not humanoid or not root or humanoid.Health <= 0 then
        return
    end

    if state.GroundOnly and humanoid.FloorMaterial == Enum.Material.Air then
        return
    end

    local direction = humanoid.MoveDirection
    local flat = Vector3.new(direction.X, 0, direction.Z)
    local magnitude = flat.Magnitude

    if magnitude < 0.001 then
        return
    end

    flat = flat / magnitude

    local velocity = root.AssemblyLinearVelocity
    local target = Vector3.new(flat.X * state.Speed, velocity.Y, flat.Z * state.Speed)

    if not state.PreserveVerticalVelocity then
        target = Vector3.new(target.X, 0, target.Z)
    end

    if state.SmoothMovement then
        local alpha = 1 - math.pow(1 - state.Smoothing, math.clamp(deltaTime * 60, 0.1, 3))
        local horizontal = Vector3.new(velocity.X, 0, velocity.Z):Lerp(
            Vector3.new(target.X, 0, target.Z),
            alpha
        )
        root.AssemblyLinearVelocity = Vector3.new(
            horizontal.X,
            target.Y,
            horizontal.Z
        )
    else
        root.AssemblyLinearVelocity = target
    end
end))

track(player.CharacterAdded:Connect(function()
    task.defer(function()
        if alive then
            task.wait(0.15)
            applyJump()
        end
    end)
end))

track(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    local val = Workspace.CurrentCamera
    if not val then return end
    currentCamera = val
    if state.FOVEnabled then
        originalFOV = val.FieldOfView
        applyFOV()
    else
        originalFOV = val.FieldOfView
    end
end))

task.defer(function()
    if not alive then
        return
    end
    applyJump()
    applyFOV()
    notify("seroid loaded", "Ready. [H] Toggle | [Q] Straight Magnet | [R] Backstab Flank.", "success")
end)

local function cleanup()
    if not alive then
        return
    end
    alive = false

    for _, connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(connections)

    local humanoid = getHumanoid()
    if humanoid then
        local saved = originalJump[humanoid]
        if saved then
            pcall(function()
                humanoid.UseJumpPower = saved.UseJumpPower
                humanoid.JumpPower = saved.JumpPower
                humanoid.JumpHeight = saved.JumpHeight
            end)
        end
    end

    local camera = Workspace.CurrentCamera
    if camera and originalFOV then
        pcall(function()
            camera.FieldOfView = originalFOV
        end)
    end

    ENV.SpeedConnection = nil
    ENV.SpeedEnabled = false
    ENV.Loop = false
    ENV.seroidCleanup = nil

    pcall(function()
        VibeUI:Unload()
    end)
end

ENV.seroidCleanup = cleanup
ENV.SpeedConnection = connections[1]

ENV.seroid = {
    Version = "2.4",
    State = state,
    Cleanup = cleanup,
    UI = VibeUI,
}
