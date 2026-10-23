--[[
    seroid.lua — VibeUI movement + camera utility panel
    Defaults: speed 37, smooth movement on, FOV off, jump boost off.
    UI library: https://sirmemegithub.com/RealSlimShady2000/VibeUI

    Note: this is a client-side utility. Games can override or validate movement
    on the server. Use only where client-side modifications are permitted.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

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

    HitboxVisualsEnabled = false,
    HitboxScale = 2.0,
    HitboxTransparency = 0.55,
    HitboxColor = "Purple",
}

local state = {}
for key, value in pairs(DEFAULTS) do
    state[key] = value
end

local alive = true
local connections = {}
local originalJump = setmetatable({}, { __mode = "k" })
local originalFOV = nil
local VibeUI -- forward declaration used by notify()
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

-- Load the UI library with clear failure handling.
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

-- Appearance defaults must be set before creating the window.
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

local VisualsTab = Window:Tab({ Name = "Visuals", Columns = 2 })
local CameraSection = VisualsTab:Section({ Name = "Camera", Side = 1 })
local UtilitySection = VisualsTab:Section({ Name = "Utilities", Side = 2 })
local HitboxSection = VisualsTab:Section({ Name = "Hitbox Visualizer", Side = 2 })

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

-- Hitbox visualizer: draws client-side boxes only; never changes character parts,
-- collision, weapon reach, or server-side hit registration.
local hitboxAdornments = {}
local hitboxColors = {
    Purple = Color3.fromRGB(145, 105, 255),
    Red = Color3.fromRGB(255, 85, 95),
    Cyan = Color3.fromRGB(70, 220, 255),
    Green = Color3.fromRGB(90, 235, 145),
    White = Color3.fromRGB(245, 245, 255),
}

local function removeHitbox(playerToRemove)
    local adornment = hitboxAdornments[playerToRemove]
    if adornment then
        pcall(function() adornment:Destroy() end)
        hitboxAdornments[playerToRemove] = nil
    end
end

local function refreshHitboxes()
    if not alive then
        return
    end

    for _, otherPlayer in ipairs(Players:GetPlayers()) do
        if otherPlayer ~= player then
            local character = otherPlayer.Character
            local root = character and (
                character:FindFirstChild("HumanoidRootPart")
                or character:FindFirstChild("Torso")
                or character:FindFirstChild("UpperTorso")
            )
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")

            if state.HitboxVisualsEnabled and root and humanoid and humanoid.Health > 0 then
                local adornment = hitboxAdornments[otherPlayer]
                if not adornment or adornment.Parent == nil then
                    removeHitbox(otherPlayer)
                    adornment = Instance.new("BoxHandleAdornment")
                    adornment.Name = "seroid_HitboxVisual"
                    adornment.Adornee = root
                    adornment.AlwaysOnTop = true
                    adornment.ZIndex = 5
                    adornment.Parent = root
                    hitboxAdornments[otherPlayer] = adornment
                end

                adornment.Adornee = root
                adornment.Size = root.Size * state.HitboxScale
                adornment.Transparency = state.HitboxTransparency
                adornment.Color3 = hitboxColors[state.HitboxColor] or hitboxColors.Purple
                adornment.Visible = true
            else
                removeHitbox(otherPlayer)
            end
        end
    end

    for trackedPlayer in pairs(hitboxAdornments) do
        if trackedPlayer.Parent ~= Players then
            removeHitbox(trackedPlayer)
        end
    end
end

controls.HitboxVisualsEnabled = HitboxSection:Toggle({
    Name = "Enable hitbox visuals",
    Flag = "seroid_HitboxVisualsEnabled",
    Default = DEFAULTS.HitboxVisualsEnabled,
    Info = "Visual overlay only; does not change real hit detection.",
    Callback = function(value)
        state.HitboxVisualsEnabled = value
        if not value then
            for trackedPlayer in pairs(hitboxAdornments) do
                removeHitbox(trackedPlayer)
            end
        else
            refreshHitboxes()
        end
    end,
})

controls.HitboxScale = HitboxSection:Slider({
    Name = "Visual box scale",
    Flag = "seroid_HitboxScale",
    Min = 1,
    Max = 5,
    Default = DEFAULTS.HitboxScale,
    Decimals = 0.1,
    Callback = function(value)
        state.HitboxScale = math.clamp(value, 1, 5)
        refreshHitboxes()
    end,
})

controls.HitboxTransparency = HitboxSection:Slider({
    Name = "Box transparency",
    Flag = "seroid_HitboxTransparency",
    Min = 0.1,
    Max = 0.9,
    Default = DEFAULTS.HitboxTransparency,
    Decimals = 0.05,
    Callback = function(value)
        state.HitboxTransparency = math.clamp(value, 0.1, 0.9)
        refreshHitboxes()
    end,
})

controls.HitboxColor = HitboxSection:Dropdown({
    Name = "Box color",
    Flag = "seroid_HitboxColor",
    Items = { "Purple", "Red", "Cyan", "Green", "White" },
    Default = DEFAULTS.HitboxColor,
    Callback = function(value)
        if hitboxColors[value] then
            state.HitboxColor = value
            refreshHitboxes()
        end
    end,
})

track(Players.PlayerAdded:Connect(function(newPlayer)
    if newPlayer ~= player then
        track(newPlayer.CharacterAdded:Connect(function()
            task.defer(refreshHitboxes)
        end))
    end
end))

for _, existingPlayer in ipairs(Players:GetPlayers()) do
    if existingPlayer ~= player then
        track(existingPlayer.CharacterAdded:Connect(function()
            task.defer(refreshHitboxes)
        end))
    end
end

track(Players.PlayerRemoving:Connect(removeHitbox))
track(RunService.Heartbeat:Connect(function()
    if state.HitboxVisualsEnabled then
        refreshHitboxes()
    end
end))

-- Quick profiles use VibeUI's own config system.
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
    controls.HitboxVisualsEnabled:Set(DEFAULTS.HitboxVisualsEnabled)
    controls.HitboxScale:Set(DEFAULTS.HitboxScale)
    controls.HitboxTransparency:Set(DEFAULTS.HitboxTransparency)
    controls.HitboxColor:Set(DEFAULTS.HitboxColor)
    applyJump()
    applyFOV()
    notify("Reset complete", "seroid settings returned to their defaults.", "success")
end)

local infoOK = pcall(function()
    StatusSection:Paragraph({
        Name = "Runtime status",
        Content = "Speed loop: client-side | Default speed: 37 | Menu: Right Ctrl | Speed toggle: Left Ctrl",
    })
    StatusSection:Paragraph({
        Name = "Compatibility",
        Content = "R6/R15/custom rigs are supported when a Humanoid and root part are available. Some games may override client movement.",
    })
    StatusSection:Paragraph({
        Name = "Safety",
        Content = "Unload restores captured jump and camera settings and disconnects this script's event connections.",
    })
end)

-- Add VibeUI's built-in theme, interface, and config settings page.
pcall(function()
    VibeUI:CreateSettingsPage(Window)
end)

-- Publish common compatibility values for existing scripts that read them.
ENV.Speed = state.Speed
ENV.SpeedEnabled = state.SpeedEnabled
ENV.Loop = true

-- Movement loop: one Heartbeat connection, with safe direction checks.
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
    local newCamera = Workspace.CurrentCamera
    if not newCamera then
        return
    end

    currentCamera = newCamera
    if state.FOVEnabled then
        originalFOV = newCamera.FieldOfView
        applyFOV()
    else
        originalFOV = newCamera.FieldOfView
    end
end))

-- Apply initial settings after controls are constructed.
task.defer(function()
    if not alive then
        return
    end
    applyJump()
    applyFOV()
    notify("seroid loaded", "Ready. Right Ctrl opens the menu.", "success")
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

    -- Restore current character's original jump settings.
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

    -- Remove all visual hitbox adornments.
    for trackedPlayer in pairs(hitboxAdornments) do
        removeHitbox(trackedPlayer)
    end

    -- Restore the camera's captured FOV.
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

-- Expose a compact state table for debugging/custom extension.
ENV.seroid = {
    Version = "2.0",
    State = state,
    Cleanup = cleanup,
    UI = VibeUI,
}
