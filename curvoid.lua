--[[
    Curvoid v1.0.0 — Camera Snap Utility
    Made by vel1ous
    Companion to seroid.lua. Uses the same VibeUI layout and library.
    Defaults: Q/F = instant 180-degree backward snap for 0.20 seconds, R = upward snap.
    Snaps temporarily take camera control so the default controller is not overwritten each frame.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
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
    BackKey = Enum.KeyCode.Q,
    BackAliasKey = Enum.KeyCode.F,
    UpKey = Enum.KeyCode.R,
    SnapDuration = 0.20,
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
local BACK_KEY_COOLDOWN = 2
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

local function restoreSnap(snap)
    if not snap or not snap.camera then
        return
    end

    local camera = snap.camera
    pcall(function()
        local canRestoreFrame = camera == Workspace.CurrentCamera
            and (not snap.changedCameraType or camera.CameraType == Enum.CameraType.Scriptable)

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

local function performSnap(kind, source)
    if not alive or activeSnap then
        return
    end
    if source == "key" and not state.HotkeysEnabled then
        return
    end

    if kind == "Back" and source == "key" then
        local remaining = BACK_KEY_COOLDOWN - (os.clock() - lastBackKeyUse)
        if remaining > 0 then
            return
        end
    end

    local camera = Workspace.CurrentCamera
    if not camera then
        notify("Camera unavailable", "No active CurrentCamera was found.", "warning")
        return
    end

    local offset
    if kind == "Back" then
        offset = CFrame.Angles(0, math.pi, 0)
    else
        offset = CFrame.Angles(math.rad(state.UpAngle), 0, 0)
    end

    local originalType = camera.CameraType
    local duration = math.clamp(state.SnapDuration, 0.03, 0.50)

    snapToken += 1
    local token = snapToken
    activeSnap = {
        camera = camera,
        base = camera.CFrame,
        focus = camera.Focus,
        cameraType = originalType,
        changedCameraType = originalType ~= Enum.CameraType.Scriptable,
    }

    if kind == "Back" and source == "key" then
        lastBackKeyUse = os.clock()
    end

    -- Pause the default camera controller briefly instead of fighting it
    -- with repeated CFrame writes every rendered frame.
    if originalType ~= Enum.CameraType.Scriptable then
        camera.CameraType = Enum.CameraType.Scriptable
    end

    local ok, err = pcall(function()
        camera.CFrame = activeSnap.base * offset
    end)
    if not ok then
        finishSnap(token)
        warn("[Curvoid] Could not apply camera snap:", err)
        return
    end

    task.delay(duration, function()
        if not alive then
            return
        end
        finishSnap(token)
    end)
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
    Title = "Curvoid",
    Size = UDim2.fromOffset(700, 510),
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
local TimingSection = SettingsTab:Section({ Name = "Snap Settings", Side = 2 })

local AboutTab = Window:Tab({ Name = "About", Columns = 2 })
local AboutSection = AboutTab:Section({ Name = "Curvoid", Side = 1 })
local InfoSection = AboutTab:Section({ Name = "Runtime & Controls", Side = 2 })

local controls = {}

controls.Backward = BackSection:Toggle({
    Name = "Enable backward hotkeys (Q / F)",
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
controls.SnapDuration = TimingSection:Slider({
    Name = "Snap duration",
    Flag = "curvoid_SnapDuration",
    Min = 0.03,
    Max = 0.50,
    Default = DEFAULTS.SnapDuration,
    Decimals = 0.01,
    Suffix = " s",
    Callback = function(value)
        state.SnapDuration = math.clamp(value, 0.03, 0.50)
    end,
})
controls.UpAngle = TimingSection:Slider({
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
    state.BackKey = DEFAULTS.BackKey
    state.BackAliasKey = DEFAULTS.BackAliasKey
    state.UpKey = DEFAULTS.UpKey
    state.SnapDuration = DEFAULTS.SnapDuration
    state.UpAngle = DEFAULTS.UpAngle
    controls.HotkeysEnabled:Set(DEFAULTS.HotkeysEnabled)
    controls.SnapDuration:Set(DEFAULTS.SnapDuration)
    controls.UpAngle:Set(DEFAULTS.UpAngle)
    pendingBind = nil
    notify("Curvoid reset", "Settings returned to defaults.", "success")
end)
quickButtons:Add("Rebind backward key", function()
    pendingBind = "Back"
    notify("Rebind backward", "Press a key. F remains as a backup shortcut.", "info")
end)
quickButtons:Add("Rebind upward key", function()
    pendingBind = "Up"
    notify("Rebind upward", "Press a key to use for the upward snap.", "info")
end)

pcall(function()
    AboutSection:Paragraph({
        Name = "Curvoid v1.0.0",
        Content = "Made by vel1ous. Standalone camera snap utility and companion to seroid.lua.",
    })
    InfoSection:Paragraph({
        Name = "Default controls",
        Content = "Q / F: instant 180° backward camera snap for 0.20 seconds, then return to normal view. Keyboard backward snaps have a shared 2-second cooldown. R: upward camera snap (45°).",
    })
    InfoSection:Paragraph({
        Name = "Interface",
        Content = "Uses the same VibeUI window, tabs, sections, settings page, notifications, and layout conventions as seroid.lua.",
    })
    InfoSection:Paragraph({
        Name = "Cleanup",
        Content = "Unload restores temporary camera state and disconnects tracked input connections.",
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

    if input.KeyCode == state.BackKey or input.KeyCode == state.BackAliasKey then
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
notify("Curvoid loaded", "Ready. [Q/F] Backward | [R] Upward | Right Ctrl opens the menu.", "success")
warn("[Curvoid] v1.0.0 loaded. Backward: Q/F | Upward: R.")
