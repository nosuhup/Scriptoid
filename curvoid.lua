--[[
    Curvoid v1.1.0 — Smooth Camera Snap Utility
    Made by vel1ous
    Companion to seroid.lua. Uses the same VibeUI layout and library.
    Defaults: F = fast eased 180-degree backward turn and smooth return; R = upward snap.
    Turn, hold, return, angle, and cooldown settings are adjustable in the UI.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
if not player then
    warn("[Curvoid] LocalPlayer is unavailable.")
    return
end

local ENV = (type(getgenv) == "function" and getgenv()) or _G
if type(ENV.curvoidCleanup) == "function" then
    pcall(ENV.curvoidCleanup)
end

local DEFAULTS = {
    HotkeysEnabled = true,
    BackKey = Enum.KeyCode.F,
    BackAliasKey = Enum.KeyCode.Unknown,
    UpKey = Enum.KeyCode.R,
    TurnDuration = 0.09,
    HoldDuration = 0.05,
    ReturnDuration = 0.09,
    BackAngle = 180,
    BackCooldown = 2,
    UpAngle = 45,
}
local state = {}
for key, value in pairs(DEFAULTS) do
    state[key] = value
end

local alive = true
local connections = {}
local activeSnap = nil
local snapToken = 0
local lastBackKeyUse = -math.huge
local pendingBind = nil
local VibeUI

local function track(connection)
    table.insert(connections, connection)
    return connection
end

local function disconnectAll()
    for _, connection in ipairs(connections) do
        pcall(function()
            connection:Disconnect()
        end)
    end
    table.clear(connections)
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

local function cancelSnapMotion(snap)
    if not snap then
        return
    end

    if snap.holdThread then
        pcall(task.cancel, snap.holdThread)
        snap.holdThread = nil
    end

    if snap.completion then
        pcall(function()
            snap.completion:Disconnect()
        end)
        snap.completion = nil
    end

    if snap.tween then
        pcall(function()
            snap.tween:Cancel()
        end)
        snap.tween = nil
    end
end

local function restoreSnap(snap)
    if not snap or not snap.camera then
        return
    end

    local camera = snap.camera
    pcall(function()
        local canRestoreFrame = not snap.changedCameraType
            or camera.CameraType == Enum.CameraType.Scriptable

        if canRestoreFrame then
            camera.CFrame = snap.base
            if snap.focus then
                camera.Focus = snap.focus
            end
        end

        if snap.changedCameraType and camera.CameraType == Enum.CameraType.Scriptable then
            camera.CameraType = snap.cameraType
        end
    end)
end

local function finishSnap(token)
    if token ~= snapToken then
        return
    end

    local snap = activeSnap
    activeSnap = nil
    cancelSnapMotion(snap)
    restoreSnap(snap)
end

local function cleanup()
    if not alive then
        return
    end

    alive = false
    snapToken += 1

    local snap = activeSnap
    activeSnap = nil
    cancelSnapMotion(snap)
    restoreSnap(snap)
    disconnectAll()

    pcall(function()
        if VibeUI and type(VibeUI.Unload) == "function" then
            VibeUI:Unload()
        end
    end)

    if ENV.curvoidCleanup == cleanup then
        ENV.curvoidCleanup = nil
    end
end

-- Tween the camera instead of snapping CFrame repeatedly in a render loop.
local function animateSnap(snap, target, duration, easingDirection, onComplete)
    local tween = TweenService:Create(
        snap.camera,
        TweenInfo.new(
            math.clamp(duration, 0.03, 0.30),
            Enum.EasingStyle.Quart,
            easingDirection
        ),
        { CFrame = target }
    )

    snap.tween = tween
    local connection
    connection = tween.Completed:Connect(function(playbackState)
        if connection then
            connection:Disconnect()
        end
        if snap.completion == connection then
            snap.completion = nil
        end
        if snap.tween == tween then
            snap.tween = nil
        end

        if not alive or activeSnap ~= snap or playbackState ~= Enum.PlaybackState.Completed then
            return
        end

        onComplete()
    end)
    snap.completion = connection
    tween:Play()
end

local function performSnap(kind, source)
    if not alive or activeSnap then
        return
    end
    if source == "key" and not state.HotkeysEnabled then
        return
    end

    if kind == "Back" and source == "key" then
        local remaining = state.BackCooldown - (os.clock() - lastBackKeyUse)
        if remaining > 0 then
            return
        end
    end

    local camera = Workspace.CurrentCamera
    if not camera then
        notify("Camera unavailable", "No active CurrentCamera was found.", "warning")
        return
    end

    local angle = kind == "Back" and state.BackAngle or state.UpAngle
    local offset
    if kind == "Back" then
        offset = CFrame.Angles(0, math.rad(angle), 0)
    else
        offset = CFrame.Angles(math.rad(angle), 0, 0)
    end

    local originalType = camera.CameraType
    snapToken += 1
    local token = snapToken
    local snap = {
        camera = camera,
        base = camera.CFrame,
        focus = camera.Focus,
        cameraType = originalType,
        changedCameraType = originalType ~= Enum.CameraType.Scriptable,
        tween = nil,
        completion = nil,
        holdThread = nil,
    }
    activeSnap = snap

    if kind == "Back" and source == "key" then
        lastBackKeyUse = os.clock()
    end

    -- Take temporary camera control so Roblox's default camera script does
    -- not compete with the tween. The original camera mode is restored later.
    if snap.changedCameraType then
        camera.CameraType = Enum.CameraType.Scriptable
    end

    local function beginReturn()
        snap.holdThread = nil
        if not alive or activeSnap ~= snap then
            return
        end

        local ok, err = pcall(function()
            animateSnap(snap, snap.base, state.ReturnDuration, Enum.EasingDirection.In, function()
                finishSnap(token)
            end)
        end)
        if not ok then
            warn("[Curvoid] Return tween failed:", err)
            finishSnap(token)
        end
    end

    local ok, err = pcall(function()
        local target = snap.base * offset
        animateSnap(snap, target, state.TurnDuration, Enum.EasingDirection.Out, function()
            snap.holdThread = task.delay(state.HoldDuration, beginReturn)
        end)
    end)

    if not ok then
        warn("[Curvoid] Turn tween failed:", err)
        finishSnap(token)
    end
end

local libraryURL = "https://sirmemegithub.com/RealSlimShady2000/VibeUI/raw/branch/main/VibeUI.luau"
local loadOK, libraryOrError = pcall(function()
    assert(type(loadstring) == "function", "loadstring is unavailable in this environment")
    local response = game:HttpGet(libraryURL)
    local compile = loadstring(response)
    assert(type(compile) == "function", "VibeUI source did not compile")
    return compile()
end)

if not loadOK or type(libraryOrError) ~= "table" then
    warn("[Curvoid] Could not load VibeUI:", libraryOrError)
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
        Accent = Color3.fromRGB(0, 220, 240),
        Background = Color3.fromRGB(7, 11, 16),
    })
    VibeUI:SetOutlines(true)
    VibeUI:SetGlow(0.12)
    VibeUI:SetNotificationSide("BottomRight")
end)

local Window = VibeUI:Window({
    Title = "Curvoid v1.1",
    Size = UDim2.fromOffset(760, 570),
    Keybind = Enum.KeyCode.RightControl,
    Layout = "Side",
    Resizable = true,
})

local ControlsTab = Window:Tab({ Name = "Controls", Columns = 2 })
local BackSection = ControlsTab:Section({ Name = "Backward Snap", Side = 1 })
local UpSection = ControlsTab:Section({ Name = "Upward Snap", Side = 2 })
local QuickSection = ControlsTab:Section({ Name = "Quick Actions", Side = 1 })

local SettingsTab = Window:Tab({ Name = "Settings", Columns = 2 })
local KeySection = SettingsTab:Section({ Name = "Keyboard", Side = 1 })
local TimingSection = SettingsTab:Section({ Name = "Motion", Side = 2 })
local AngleSection = SettingsTab:Section({ Name = "Angles", Side = 1 })

local AboutTab = Window:Tab({ Name = "About", Columns = 2 })
local AboutSection = AboutTab:Section({ Name = "Curvoid", Side = 1 })
local InfoSection = AboutTab:Section({ Name = "Runtime & Controls", Side = 2 })

local controls = {}

controls.Backward = BackSection:Toggle({
    Name = "Enable backward hotkey (F)",
    Flag = "curvoid_BackwardEnabled",
    Default = true,
    Callback = function(value)
        state.BackwardEnabled = value
    end,
})
local backButtons = BackSection:Button()
backButtons:Add("Snap backward now", function()
    performSnap("Back", "button")
end)

controls.Upward = UpSection:Toggle({
    Name = "Enable upward hotkey (R)",
    Flag = "curvoid_UpwardEnabled",
    Default = true,
    Callback = function(value)
        state.UpwardEnabled = value
    end,
})
local upButtons = UpSection:Button()
upButtons:Add("Snap upward now", function()
    performSnap("Up", "button")
end)

controls.HotkeysEnabled = KeySection:Toggle({
    Name = "Enable keyboard shortcuts",
    Flag = "curvoid_HotkeysEnabled",
    Default = DEFAULTS.HotkeysEnabled,
    Callback = function(value)
        state.HotkeysEnabled = value
    end,
})
controls.TurnDuration = TimingSection:Slider({
    Name = "Turn duration",
    Flag = "curvoid_TurnDuration",
    Min = 0.03,
    Max = 0.30,
    Default = DEFAULTS.TurnDuration,
    Decimals = 0.01,
    Suffix = " s",
    Callback = function(value)
        state.TurnDuration = math.clamp(value, 0.03, 0.30)
    end,
})
controls.HoldDuration = TimingSection:Slider({
    Name = "Hold at turned view",
    Flag = "curvoid_HoldDuration",
    Min = 0,
    Max = 0.20,
    Default = DEFAULTS.HoldDuration,
    Decimals = 0.01,
    Suffix = " s",
    Callback = function(value)
        state.HoldDuration = math.clamp(value, 0, 0.20)
    end,
})
controls.ReturnDuration = TimingSection:Slider({
    Name = "Return duration",
    Flag = "curvoid_ReturnDuration",
    Min = 0.03,
    Max = 0.30,
    Default = DEFAULTS.ReturnDuration,
    Decimals = 0.01,
    Suffix = " s",
    Callback = function(value)
        state.ReturnDuration = math.clamp(value, 0.03, 0.30)
    end,
})
controls.BackCooldown = KeySection:Slider({
    Name = "F cooldown",
    Flag = "curvoid_BackCooldown",
    Min = 0.5,
    Max = 5,
    Default = DEFAULTS.BackCooldown,
    Decimals = 0.1,
    Suffix = " s",
    Callback = function(value)
        state.BackCooldown = math.clamp(value, 0.5, 5)
    end,
})
controls.BackAngle = AngleSection:Slider({
    Name = "Backward turn angle",
    Flag = "curvoid_BackAngle",
    Min = 90,
    Max = 180,
    Default = DEFAULTS.BackAngle,
    Decimals = 1,
    Suffix = "°",
    Callback = function(value)
        state.BackAngle = math.clamp(value, 90, 180)
    end,
})
controls.UpAngle = AngleSection:Slider({
    Name = "Upward angle",
    Flag = "curvoid_UpAngle",
    Min = 5,
    Max = 85,
    Default = DEFAULTS.UpAngle,
    Decimals = 1,
    Suffix = "°",
    Callback = function(value)
        state.UpAngle = math.clamp(value, 5, 85)
    end,
})

local quickButtons = QuickSection:Button()
quickButtons:Add("Reset settings", function()
    state.HotkeysEnabled = DEFAULTS.HotkeysEnabled
    state.BackwardEnabled = true
    state.UpwardEnabled = true
    state.BackKey = DEFAULTS.BackKey
    state.BackAliasKey = DEFAULTS.BackAliasKey
    state.UpKey = DEFAULTS.UpKey
    state.TurnDuration = DEFAULTS.TurnDuration
    state.HoldDuration = DEFAULTS.HoldDuration
    state.ReturnDuration = DEFAULTS.ReturnDuration
    state.BackCooldown = DEFAULTS.BackCooldown
    state.BackAngle = DEFAULTS.BackAngle
    state.UpAngle = DEFAULTS.UpAngle
    lastBackKeyUse = -math.huge
    controls.Backward:Set(true)
    controls.Upward:Set(true)
    controls.HotkeysEnabled:Set(DEFAULTS.HotkeysEnabled)
    controls.TurnDuration:Set(DEFAULTS.TurnDuration)
    controls.HoldDuration:Set(DEFAULTS.HoldDuration)
    controls.ReturnDuration:Set(DEFAULTS.ReturnDuration)
    controls.BackCooldown:Set(DEFAULTS.BackCooldown)
    controls.BackAngle:Set(DEFAULTS.BackAngle)
    controls.UpAngle:Set(DEFAULTS.UpAngle)
    pendingBind = nil
    notify("Curvoid reset", "Settings returned to defaults.", "success")
end)
quickButtons:Add("Rebind backward key", function()
    pendingBind = "Back"
    notify("Rebind backward", "Press a key to replace F. Q is not an active alias by default.", "info")
end)
quickButtons:Add("Rebind upward key", function()
    pendingBind = "Up"
    notify("Rebind upward", "Press a key to use for the upward snap.", "info")
end)
quickButtons:Add("Cancel current snap", function()
    if activeSnap then
        finishSnap(snapToken)
        notify("Camera restored", "The current snap was cancelled.", "success")
    else
        notify("Camera idle", "No snap is currently running.", "info")
    end
end)

pcall(function()
    AboutSection:Paragraph({
        Name = "Curvoid v1.1.0",
        Content = "Made by vel1ous. Standalone camera snap utility and companion to seroid.lua.",
    })
    InfoSection:Paragraph({
        Name = "Default controls",
        Content = "F: fast, eased backward camera turn and smooth return. Tune turn time, hold time, return time, angle, and cooldown in Settings. R: upward camera snap; its angle is adjustable.",
    })
    InfoSection:Paragraph({
        Name = "Interface",
        Content = "Uses the same VibeUI window, tabs, sections, settings page, notifications, and layout conventions as seroid.lua.",
    })
    InfoSection:Paragraph({
        Name = "Cleanup",
        Content = "Motion uses TweenService rather than a permanent render loop. Unload cancels active tweens, restores the camera mode, and disconnects tracked input connections.",
    })
    VibeUI:CreateSettingsPage(Window)
end)

track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not alive or UserInputService:GetFocusedTextBox() then
        return
    end

    if pendingBind and not gameProcessed then
        if input.KeyCode == Enum.KeyCode.Escape then
            pendingBind = nil
            notify("Rebind cancelled", "The previous key remains active.", "info")
            return
        end
        if input.KeyCode ~= Enum.KeyCode.Unknown then
            if pendingBind == "Back" then
                state.BackKey = input.KeyCode
            else
                state.UpKey = input.KeyCode
            end
            pendingBind = nil
            notify("Keybind saved", "New shortcut: " .. input.KeyCode.Name, "success")
            return
        end
    end

    if gameProcessed or not state.HotkeysEnabled then
        return
    end

    if input.KeyCode == state.BackKey
        or (state.BackAliasKey ~= Enum.KeyCode.Unknown and input.KeyCode == state.BackAliasKey) then
        if state.BackwardEnabled ~= false then
            performSnap("Back", "key")
        end
    elseif input.KeyCode == state.UpKey then
        if state.UpwardEnabled ~= false then
            performSnap("Up", "key")
        end
    end
end))

ENV.curvoidCleanup = cleanup
notify("Curvoid loaded", "Ready. [F] Smooth backward turn | [R] Upward | Right Ctrl opens the menu.", "success")
warn("[Curvoid] v1.1.0 loaded. Backward: F | Upward: R.")
