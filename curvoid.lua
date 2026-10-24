--[[
    Curvoid v1.0.0
    Made by vel1ous

    Standalone camera-snap utility for Roblox client-side testing.
    Default controls:
      Q / F - Brief 180-degree backward camera snap, then restore.
      R     - Brief upward camera snap, then restore.
      Right Ctrl is not used; the menu has its own close button.

    Place this LocalScript in StarterPlayerScripts, or run it in a compatible
    client-side Luau environment. No external UI library or HTTP loader needed.
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

local CONFIG = {
    BackKey = Enum.KeyCode.Q,
    BackAliasKey = Enum.KeyCode.F,
    UpKey = Enum.KeyCode.R,
    HotkeysEnabled = true,
    SnapDuration = 0.10,
    UpAngle = 45,
}

local alive = true
local connections = {}
local activeSnap = nil
local snapToken = 0
local pendingBind = nil
local statusToken = 0
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

local function make(className, properties, parent)
    local object = Instance.new(className)
    for property, value in pairs(properties or {}) do
        pcall(function()
            object[property] = value
        end)
    end
    object.Parent = parent
    return object
end

local function round(object, radius)
    make("UICorner", {
        CornerRadius = UDim.new(0, radius or 8),
    }, object)
end

local function outline(object, color, thickness, transparency)
    make("UIStroke", {
        Color = color or Color3.fromRGB(0, 220, 240),
        Thickness = thickness or 1,
        Transparency = transparency or 0.15,
    }, object)
end

local COLORS = {
    Background = Color3.fromRGB(7, 11, 16),
    Panel = Color3.fromRGB(12, 18, 25),
    Card = Color3.fromRGB(15, 24, 32),
    CardHover = Color3.fromRGB(20, 34, 43),
    Cyan = Color3.fromRGB(0, 225, 245),
    CyanDim = Color3.fromRGB(0, 115, 135),
    Text = Color3.fromRGB(230, 241, 246),
    Muted = Color3.fromRGB(133, 157, 169),
    Red = Color3.fromRGB(255, 91, 107),
    Green = Color3.fromRGB(86, 235, 175),
}

local function getGuiParent()
    if type(gethui) == "function" then
        local ok, hiddenGui = pcall(gethui)
        if ok and hiddenGui then
            return hiddenGui
        end
    end
    return player:WaitForChild("PlayerGui")
end

local screenGui = make("ScreenGui", {
    Name = "CurvoidUI",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, getGuiParent())

local main = make("Frame", {
    Name = "Window",
    Size = UDim2.fromOffset(560, 405),
    Position = UDim2.new(0.5, -280, 0.5, -202),
    BackgroundColor3 = COLORS.Background,
    BorderSizePixel = 0,
}, screenGui)
round(main, 12)
outline(main, COLORS.CyanDim, 1.2, 0.1)

local topBar = make("Frame", {
    Name = "TopBar",
    Size = UDim2.new(1, 0, 0, 48),
    BackgroundColor3 = COLORS.Panel,
    BorderSizePixel = 0,
}, main)
round(topBar, 12)

make("Frame", {
    Name = "TopBarFill",
    Position = UDim2.new(0, 0, 1, -12),
    Size = UDim2.new(1, 0, 0, 12),
    BackgroundColor3 = COLORS.Panel,
    BorderSizePixel = 0,
}, topBar)

make("Frame", {
    Name = "AccentLine",
    Position = UDim2.new(0, 0, 1, -2),
    Size = UDim2.new(1, 0, 0, 2),
    BackgroundColor3 = COLORS.Cyan,
    BorderSizePixel = 0,
}, topBar)

make("TextLabel", {
    Name = "Brand",
    Position = UDim2.fromOffset(17, 7),
    Size = UDim2.fromOffset(190, 21),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamBold,
    Text = "CURVOID",
    TextSize = 18,
    TextColor3 = COLORS.Cyan,
    TextXAlignment = Enum.TextXAlignment.Left,
}, topBar)

make("TextLabel", {
    Name = "Version",
    Position = UDim2.fromOffset(18, 27),
    Size = UDim2.fromOffset(230, 14),
    BackgroundTransparency = 1,
    Font = Enum.Font.Gotham,
    Text = "CAMERA UTILITY  /  v1.0.0",
    TextSize = 9,
    TextColor3 = COLORS.Muted,
    TextXAlignment = Enum.TextXAlignment.Left,
}, topBar)

local statusLabel = make("TextLabel", {
    Name = "Status",
    Position = UDim2.new(1, -135, 0, 15),
    Size = UDim2.fromOffset(83, 18),
    BackgroundTransparency = 1,
    Font = Enum.Font.GothamMedium,
    Text = "● READY",
    TextSize = 10,
    TextColor3 = COLORS.Green,
    TextXAlignment = Enum.TextXAlignment.Right,
}, topBar)

local closeButton = make("TextButton", {
    Name = "Close",
    Position = UDim2.new(1, -39, 0, 10),
    Size = UDim2.fromOffset(27, 27),
    BackgroundColor3 = Color3.fromRGB(37, 21, 29),
    BorderSizePixel = 0,
    AutoButtonColor = true,
    Font = Enum.Font.GothamBold,
    Text = "×",
    TextSize = 20,
    TextColor3 = COLORS.Red,
}, topBar)
round(closeButton, 7)

local sidebar = make("Frame", {
    Name = "Sidebar",
    Position = UDim2.fromOffset(0, 48),
    Size = UDim2.new(0, 139, 1, -48),
    BackgroundColor3 = COLORS.Panel,
    BorderSizePixel = 0,
}, main)

make("Frame", {
    Name = "SidebarDivider",
    Position = UDim2.new(1, -1, 0, 0),
    Size = UDim2.new(0, 1, 1, 0),
    BackgroundColor3 = Color3.fromRGB(29, 50, 60),
    BorderSizePixel = 0,
}, sidebar)

local content = make("Frame", {
    Name = "Content",
    Position = UDim2.fromOffset(139, 49),
    Size = UDim2.new(1, -139, 1, -49),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
}, main)

local pages = {}
local navButtons = {}

local function makePage(name)
    local page = make("Frame", {
        Name = name,
        Position = UDim2.fromOffset(0, 0),
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = false,
    }, content)
    pages[name] = page
    return page
end

local controlsPage = makePage("Controls")
local settingsPage = makePage("Settings")
local aboutPage = makePage("About")

local function makeText(parent, text, position, size, fontSize, color, bold)
    return make("TextLabel", {
        Position = position,
        Size = size,
        BackgroundTransparency = 1,
        Font = bold and Enum.Font.GothamBold or Enum.Font.Gotham,
        Text = text,
        TextSize = fontSize,
        TextColor3 = color or COLORS.Text,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Center,
    }, parent)
end

local function makeButton(parent, text, position, size, primary)
    local button = make("TextButton", {
        Position = position,
        Size = size,
        BackgroundColor3 = primary and Color3.fromRGB(0, 83, 98) or COLORS.Card,
        BorderSizePixel = 0,
        AutoButtonColor = true,
        Font = Enum.Font.GothamSemibold,
        Text = text,
        TextSize = 11,
        TextColor3 = primary and COLORS.Cyan or COLORS.Text,
        TextTruncate = Enum.TextTruncate.AtEnd,
    }, parent)
    round(button, 7)
    outline(button, primary and COLORS.CyanDim or Color3.fromRGB(43, 64, 75), 1, 0.2)
    return button
end

local function makeCard(parent, y, height)
    local card = make("Frame", {
        Position = UDim2.fromOffset(12, y),
        Size = UDim2.new(1, -24, 0, height),
        BackgroundColor3 = COLORS.Card,
        BorderSizePixel = 0,
    }, parent)
    round(card, 9)
    outline(card, Color3.fromRGB(35, 57, 67), 1, 0.2)
    return card
end

local function setStatus(text, color)
    statusToken += 1
    local thisToken = statusToken
    statusLabel.Text = "● " .. string.upper(text)
    statusLabel.TextColor3 = color or COLORS.Cyan
    task.delay(1.7, function()
        if alive and thisToken == statusToken then
            statusLabel.Text = "● READY"
            statusLabel.TextColor3 = COLORS.Green
        end
    end)
end

local function showPage(name)
    for pageName, page in pairs(pages) do
        page.Visible = pageName == name
    end
    for pageName, button in pairs(navButtons) do
        local selected = pageName == name
        button.BackgroundColor3 = selected and Color3.fromRGB(0, 58, 70) or COLORS.Panel
        button.TextColor3 = selected and COLORS.Cyan or COLORS.Muted
    end
end

local function makeNav(name, label, y)
    local button = make("TextButton", {
        Position = UDim2.fromOffset(10, y),
        Size = UDim2.new(1, -20, 0, 37),
        BackgroundColor3 = COLORS.Panel,
        BorderSizePixel = 0,
        AutoButtonColor = true,
        Font = Enum.Font.GothamSemibold,
        Text = label,
        TextSize = 12,
        TextColor3 = COLORS.Muted,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, sidebar)
    make("UIPadding", {
        PaddingLeft = UDim.new(0, 12),
    }, button)
    round(button, 7)
    navButtons[name] = button
    track(button.Activated:Connect(function()
        showPage(name)
    end))
end

makeText(sidebar, "NAVIGATION", UDim2.fromOffset(15, 13), UDim2.fromOffset(108, 18), 9, COLORS.Muted, true)
makeNav("Controls", "▣   Controls", 43)
makeNav("Settings", "⚙   Settings", 88)
makeNav("About", "ⓘ   About", 133)

makeText(sidebar, "CURVOID", UDim2.fromOffset(15, 253), UDim2.fromOffset(108, 20), 10, COLORS.Cyan, true)
makeText(sidebar, "MADE BY\nvel1ous", UDim2.fromOffset(15, 275), UDim2.fromOffset(108, 35), 10, COLORS.Muted, false)

-- Controls page
makeText(controlsPage, "Camera actions", UDim2.fromOffset(13, 9), UDim2.new(1, -26, 0, 24), 16, COLORS.Text, true)
makeText(controlsPage, "One-tap camera snaps that automatically return.", UDim2.fromOffset(13, 33), UDim2.new(1, -26, 0, 20), 10, COLORS.Muted, false)

local backCard = makeCard(controlsPage, 62, 112)
makeText(backCard, "BACKWARD SNAP", UDim2.fromOffset(13, 10), UDim2.new(1, -145, 0, 19), 11, COLORS.Cyan, true)
makeText(backCard, "Rotate 180° behind you, then restore.", UDim2.fromOffset(13, 32), UDim2.new(1, -145, 0, 34), 10, COLORS.Muted, false)
local backBindButton = makeButton(backCard, "Q  ·  REBIND", UDim2.new(1, -128, 0, 11), UDim2.fromOffset(115, 31), false)
local backActionButton = makeButton(backCard, "SNAP NOW", UDim2.new(1, -128, 0, 60), UDim2.fromOffset(115, 34), true)

local upCard = makeCard(controlsPage, 184, 112)
makeText(upCard, "UPWARD SNAP", UDim2.fromOffset(13, 10), UDim2.new(1, -145, 0, 19), 11, COLORS.Cyan, true)
makeText(upCard, "Tilt up by the configured angle, then restore.", UDim2.fromOffset(13, 32), UDim2.new(1, -145, 0, 34), 10, COLORS.Muted, false)
local upBindButton = makeButton(upCard, "R  ·  REBIND", UDim2.new(1, -128, 0, 11), UDim2.fromOffset(115, 31), false)
local upActionButton = makeButton(upCard, "SNAP NOW", UDim2.new(1, -128, 0, 60), UDim2.fromOffset(115, 34), true)

makeText(controlsPage, "BACKWARD: Q / F     •     UPWARD: R", UDim2.fromOffset(14, 307), UDim2.new(1, -28, 0, 21), 10, COLORS.Muted, true)
makeText(controlsPage, "F is a built-in backward-snap alias. Rebinding Q does not remove F.", UDim2.fromOffset(14, 328), UDim2.new(1, -28, 0, 30), 9, COLORS.Muted, false)

-- Settings page
makeText(settingsPage, "Settings", UDim2.fromOffset(13, 9), UDim2.new(1, -26, 0, 24), 16, COLORS.Text, true)
makeText(settingsPage, "Configure the feel and keyboard controls.", UDim2.fromOffset(13, 33), UDim2.new(1, -26, 0, 20), 10, COLORS.Muted, false)

local hotkeyCard = makeCard(settingsPage, 62, 72)
makeText(hotkeyCard, "Keyboard shortcuts", UDim2.fromOffset(13, 11), UDim2.new(1, -135, 0, 20), 11, COLORS.Text, true)
makeText(hotkeyCard, "Enable or disable Q / F / R triggers.", UDim2.fromOffset(13, 34), UDim2.new(1, -135, 0, 20), 9, COLORS.Muted, false)
local hotkeyToggle = makeButton(hotkeyCard, "ENABLED", UDim2.new(1, -116, 0, 19), UDim2.fromOffset(103, 32), true)

local durationCard = makeCard(settingsPage, 145, 78)
makeText(durationCard, "Snap duration", UDim2.fromOffset(13, 10), UDim2.new(1, -128, 0, 20), 11, COLORS.Text, true)
makeText(durationCard, "How long the offset remains active (seconds).", UDim2.fromOffset(13, 33), UDim2.new(1, -128, 0, 26), 9, COLORS.Muted, false)
local durationBox = make("TextBox", {
    Position = UDim2.new(1, -112, 0, 22),
    Size = UDim2.fromOffset(99, 32),
    BackgroundColor3 = COLORS.Background,
    BorderSizePixel = 0,
    ClearTextOnFocus = false,
    Font = Enum.Font.GothamSemibold,
    Text = string.format("%.2f", CONFIG.SnapDuration),
    TextSize = 12,
    TextColor3 = COLORS.Cyan,
    PlaceholderText = "0.10",
}, durationCard)
round(durationBox, 7)
outline(durationBox, COLORS.CyanDim, 1, 0.25)

local angleCard = makeCard(settingsPage, 234, 78)
makeText(angleCard, "Upward angle", UDim2.fromOffset(13, 10), UDim2.new(1, -128, 0, 20), 11, COLORS.Text, true)
makeText(angleCard, "Vertical angle in degrees (5–85).", UDim2.fromOffset(13, 33), UDim2.new(1, -128, 0, 26), 9, COLORS.Muted, false)
local angleBox = make("TextBox", {
    Position = UDim2.new(1, -112, 0, 22),
    Size = UDim2.fromOffset(99, 32),
    BackgroundColor3 = COLORS.Background,
    BorderSizePixel = 0,
    ClearTextOnFocus = false,
    Font = Enum.Font.GothamSemibold,
    Text = tostring(CONFIG.UpAngle),
    TextSize = 12,
    TextColor3 = COLORS.Cyan,
    PlaceholderText = "45",
}, angleCard)
round(angleBox, 7)
outline(angleBox, COLORS.CyanDim, 1, 0.25)

local resetButton = makeButton(settingsPage, "RESET SETTINGS", UDim2.fromOffset(12, 324), UDim2.new(1, -24, 0, 34), false)

-- About page
makeText(aboutPage, "About Curvoid", UDim2.fromOffset(13, 10), UDim2.new(1, -26, 0, 25), 16, COLORS.Text, true)
local aboutCard = makeCard(aboutPage, 48, 147)
makeText(aboutCard, "CURVOID", UDim2.fromOffset(15, 13), UDim2.new(1, -30, 0, 25), 19, COLORS.Cyan, true)
makeText(aboutCard, "Version     v1.0.0\nCreator     vel1ous\nModule      Camera Snap Utility", UDim2.fromOffset(16, 46), UDim2.new(1, -30, 0, 70), 11, COLORS.Text, false)
makeText(aboutPage, "FEATURES", UDim2.fromOffset(14, 207), UDim2.new(1, -28, 0, 20), 10, COLORS.Cyan, true)
makeText(aboutPage, "• Brief 180° backward camera snap\n• Configurable upward camera tilt\n• Rebindable main hotkeys\n• Adjustable snap duration and angle\n• Standalone black / cyan interface\n• No external UI library or HTTP loader", UDim2.fromOffset(14, 229), UDim2.new(1, -28, 0, 110), 10, COLORS.Muted, false)
makeText(aboutPage, "Use in experiences and test environments where client-side camera scripts are permitted.", UDim2.fromOffset(14, 340), UDim2.new(1, -28, 0, 34), 9, COLORS.Muted, false)

local function updateBindLabels()
    backBindButton.Text = CONFIG.BackKey.Name .. "  ·  REBIND"
    upBindButton.Text = CONFIG.UpKey.Name .. "  ·  REBIND"
end

local function performSnap(kind, source)
    if not alive then
        return
    end
    if source == "key" and not CONFIG.HotkeysEnabled then
        return
    end
    if activeSnap then
        return
    end

    local camera = Workspace.CurrentCamera
    if not camera then
        setStatus("NO CAMERA", COLORS.Red)
        return
    end

    local offset
    if kind == "Back" then
        offset = CFrame.Angles(0, math.pi, 0)
    else
        offset = CFrame.Angles(math.rad(CONFIG.UpAngle), 0, 0)
    end

    snapToken += 1
    local thisToken = snapToken
    activeSnap = {
        camera = camera,
        base = camera.CFrame,
        offset = offset,
    }

    setStatus(kind == "Back" and "BACK SNAP" or "UP SNAP", COLORS.Cyan)

    task.delay(CONFIG.SnapDuration, function()
        if not alive or snapToken ~= thisToken then
            return
        end

        local snap = activeSnap
        if snap and snap.camera and snap.camera == Workspace.CurrentCamera then
            if snap.camera.CameraType == Enum.CameraType.Scriptable then
                pcall(function()
                    snap.camera.CFrame = snap.base
                end)
            end
        end
        activeSnap = nil
    end)
end

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
    end

    if camera.CameraType == Enum.CameraType.Scriptable then
        camera.CFrame = snap.base * snap.offset
    else
        -- RenderStepped runs after the default camera update; each frame starts
        -- from the fresh camera transform, so the offset never accumulates.
        camera.CFrame = camera.CFrame * snap.offset
    end
end)

track(backActionButton.Activated:Connect(function()
    performSnap("Back", "button")
end))

track(upActionButton.Activated:Connect(function()
    performSnap("Up", "button")
end))

track(backBindButton.Activated:Connect(function()
    pendingBind = "Back"
    backBindButton.Text = "PRESS A KEY..."
    setStatus("REBIND BACK", COLORS.Cyan)
end))

track(upBindButton.Activated:Connect(function()
    pendingBind = "Up"
    upBindButton.Text = "PRESS A KEY..."
    setStatus("REBIND UP", COLORS.Cyan)
end))

track(hotkeyToggle.Activated:Connect(function()
    CONFIG.HotkeysEnabled = not CONFIG.HotkeysEnabled
    hotkeyToggle.Text = CONFIG.HotkeysEnabled and "ENABLED" or "DISABLED"
    hotkeyToggle.BackgroundColor3 = CONFIG.HotkeysEnabled and Color3.fromRGB(0, 83, 98) or Color3.fromRGB(52, 32, 38)
    hotkeyToggle.TextColor3 = CONFIG.HotkeysEnabled and COLORS.Cyan or COLORS.Red
    setStatus(CONFIG.HotkeysEnabled and "HOTKEYS ON" or "HOTKEYS OFF", CONFIG.HotkeysEnabled and COLORS.Green or COLORS.Red)
end))

track(durationBox.FocusLost:Connect(function()
    local value = tonumber(durationBox.Text)
    if not value then
        durationBox.Text = string.format("%.2f", CONFIG.SnapDuration)
        setStatus("INVALID VALUE", COLORS.Red)
        return
    end
    CONFIG.SnapDuration = math.clamp(value, 0.03, 0.50)
    durationBox.Text = string.format("%.2f", CONFIG.SnapDuration)
    setStatus("DURATION SAVED", COLORS.Green)
end))

track(angleBox.FocusLost:Connect(function()
    local value = tonumber(angleBox.Text)
    if not value then
        angleBox.Text = tostring(CONFIG.UpAngle)
        setStatus("INVALID VALUE", COLORS.Red)
        return
    end
    CONFIG.UpAngle = math.floor(math.clamp(value, 5, 85) + 0.5)
    angleBox.Text = tostring(CONFIG.UpAngle)
    setStatus("ANGLE SAVED", COLORS.Green)
end))

track(resetButton.Activated:Connect(function()
    CONFIG.BackKey = Enum.KeyCode.Q
    CONFIG.BackAliasKey = Enum.KeyCode.F
    CONFIG.UpKey = Enum.KeyCode.R
    CONFIG.HotkeysEnabled = true
    CONFIG.SnapDuration = 0.10
    CONFIG.UpAngle = 45
    durationBox.Text = "0.10"
    angleBox.Text = "45"
    hotkeyToggle.Text = "ENABLED"
    hotkeyToggle.BackgroundColor3 = Color3.fromRGB(0, 83, 98)
    hotkeyToggle.TextColor3 = COLORS.Cyan
    pendingBind = nil
    updateBindLabels()
    setStatus("SETTINGS RESET", COLORS.Green)
end))

track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if not alive then
        return
    end

    if UserInputService:GetFocusedTextBox() then
        return
    end

    if pendingBind then
        if input.KeyCode == Enum.KeyCode.Escape then
            pendingBind = nil
            updateBindLabels()
            setStatus("REBIND CANCELLED", COLORS.Muted)
            return
        end
        if input.KeyCode ~= Enum.KeyCode.Unknown then
            if pendingBind == "Back" then
                CONFIG.BackKey = input.KeyCode
            else
                CONFIG.UpKey = input.KeyCode
            end
            pendingBind = nil
            updateBindLabels()
            setStatus("KEYBIND SAVED", COLORS.Green)
            return
        end
    end

    if gameProcessed or not CONFIG.HotkeysEnabled then
        return
    end

    if input.KeyCode == CONFIG.BackKey or input.KeyCode == CONFIG.BackAliasKey then
        performSnap("Back", "key")
    elseif input.KeyCode == CONFIG.UpKey then
        performSnap("Up", "key")
    end
end))

-- Drag the window from its title bar.
local dragging = false
local dragStart = nil
local startPosition = nil
local dragInput = nil

track(topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPosition = main.Position
        dragInput = input
    end
end))

track(topBar.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end))

track(UserInputService.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        main.Position = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
    end
end))

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
        screenGui:Destroy()
    end)
    if ENV.curvoidCleanup == cleanup then
        ENV.curvoidCleanup = nil
    end
end

track(closeButton.Activated:Connect(cleanup))
ENV.curvoidCleanup = cleanup
updateBindLabels()
showPage("Controls")
setStatus("READY", COLORS.Green)

warn("[Curvoid] v1.0.0 loaded. Backward: Q/F | Upward: R.")
