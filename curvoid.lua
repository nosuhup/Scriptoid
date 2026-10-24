--[[
    Curvoid v1.0.0 — Camera Snap Utility
    Made by vel1ous
    Companion to seroid.lua. Uses the same VibeUI layout and library.
    Defaults: Q/F = backward snap, R = upward snap.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
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
    SnapDuration = 0.10,
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
local VibeUI
local BIND_NAME = "CurvoidCameraSnap_" .. tostring(player.UserId)

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

local function cleanup()
    if not alive then
        return
    end
    alive = false
    activeSnap = nil
    snapToken += 1
    pcall(function()
        RunService:UnbindFromRenderStep(BIND_NAME)
    end)
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

    snapToken += 1
    local token = snapToken
    activeSnap = {
        camera = camera,
        base = camera.CFrame,
        offset = offset,
        scriptable = camera.CameraType == Enum.CameraType.Scriptable,
    }

    task.delay(state.SnapDuration, function()
        if not alive or snapToken ~= token then
            return
        end
        local snap = activeSnap
        if snap and snap.scriptable and snap.camera == Workspace.CurrentCamera then
            pcall(function()
                snap.camera.CFrame = snap.base
            end)
        end
        activeSnap = nil
    end)
end

-- Apply the temporary rotation after Roblox's normal camera update.
RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
    local snap = activeSnap
    if not alive or not snap then
        return
    end

    local camera = Workspace.CurrentCamera
    if not camera then
        return
    end

    if snap.camera ~= camera then
        snap.camera = camera
        snap.base = camera.CFrame
        snap.scriptable = camera.CameraType == Enum.CameraType.Scriptable
    end

    if snap.scriptable then
        camera.CFrame = snap.base * snap.offset
    else
        -- The default camera controller refreshes its base CFrame each frame;
        -- applying the offset after it avoids accumulating rotation.
        camera.CFrame = camera.CFrame * snap.offset
    end
end)

local libraryURL = "https://sirmemegithub.com/RealSlimShady2000/VibeUI/raw/branch/main/VibeUI.luau"
local loadOK, libraryOrError = pcall(function()
    assert(type(loadstring) == "function", "loadstring is unavailable in this environment")
    local response = game:HttpGet(libraryURL)
    local compile = loadstring(response)
    assert(type(compile) == "function", "VibeUI source did not compile")
    return compile()
end)

if not loadOK or type(libraryOrError) ~= "table" then
    pcall(function()
        RunService:UnbindFromRenderStep(BIND_NAME)
    end)
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
    state.SnapDuration = DEFAULTS.SnapDuration
    state.UpAngle = DEFAULTS.UpAngle
    controls.HotkeysEnabled:Set(DEFAULTS.HotkeysEnabled)
    controls.SnapDuration:Set(DEFAULTS.SnapDuration)
    controls.UpAngle:Set(DEFAULTS.UpAngle)
    notify("Curvoid reset", "Settings returned to defaults.", "success")
end)

pcall(function()
    AboutSection:Paragraph({
        Name = "Curvoid v1.0.0",
        Content = "Made by vel1ous. Standalone camera snap utility and companion to seroid.lua.",
    })
    InfoSection:Paragraph({
        Name = "Default controls",
        Content = "Q / F: backward camera snap (180°). R: upward camera snap (45°).",
    })
    InfoSection:Paragraph({
        Name = "Interface",
        Content = "Uses the same VibeUI window, tabs, sections, settings page, notifications, and layout conventions as seroid.lua.",
    })
    InfoSection:Paragraph({
        Name = "Cleanup",
        Content = "Unload removes the render binding and tracked input connections.",
    })
    VibeUI:CreateSettingsPage(Window)
end)

track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not alive or gameProcessed or UserInputService:GetFocusedTextBox() then
        return
    end
    if not state.HotkeysEnabled then
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
