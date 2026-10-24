-- =============================================================
-- curvoid v1.1.0 | by vel1ous | camera snap suite | scoot ui | ofx
-- library: scoot ui (by samet) — embedded above, demo pages stripped
-- =============================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- // state
local config = {
    enabled      = true,
    snapAngle    = 180,
    upAngle      = 45,
    holdTime     = 0.15,
    snapSpeed    = 8,
    jumpOnSnap   = true,
    smoothReturn = true,
    flashOn      = true,
    backOn       = true,
    upOn         = true,
}

local snaps = { flash = false, back = false, up = false }

local function getHum()
    local char = player.Character
    if not char then return nil end
    local hum = char:FindFirstChildOfClass("Humanoid")
    return (hum and hum.Health > 0) and hum or nil
end

local function jumpOnce()
    local hum = getHum()
    if hum then hum.Jump = true end
end

-- // snap core
local function doSnap(kind, yawAngle, pitchAngle, withJump)
    if snaps[kind] then return end
    if not config.enabled then return end
    snaps[kind] = true
    if withJump then jumpOnce() end

    local original = camera.CFrame
    camera.CFrame = original * CFrame.Angles(pitchAngle or 0, yawAngle or 0, 0)
    task.wait(config.holdTime)

    if config.smoothReturn then
        local steps = math.max(2, math.floor(config.snapSpeed))
        for i = 1, steps do
            local alpha = i / steps
            local snapped = CFrame.Angles(pitchAngle or 0, yawAngle or 0, 0).Rotation
            camera.CFrame = CFrame.new(original.Position) * snapped:Lerp(original.Rotation, alpha)
            RunService.RenderStepped:Wait()
        end
    end
    camera.CFrame = original
    snaps[kind] = false
end

local function flashSnap()
    if snaps.flash then return end
    snaps.flash = true
    local original = camera.CFrame
    camera.CFrame = original * CFrame.Angles(0, math.rad(config.snapAngle), 0)
    task.wait(config.holdTime)

    if config.smoothReturn then
        local steps = math.max(2, math.floor(config.snapSpeed))
        for i = 1, steps do
            local alpha = i / steps
            local rot = CFrame.Angles(0, math.rad(config.snapAngle), 0).Rotation
            camera.CFrame = CFrame.new(original.Position) * rot:Lerp(original.Rotation, alpha)
            RunService.RenderStepped:Wait()
        end
    end
    camera.CFrame = original
    snaps.flash = false
end

-- // window
local Window = Library:Window({
    Logo = "77218680285262",
    FadeTime = 0.3,
})

-- // black / cyan theme — curvoid palette over scoot preset
local ThemeMap = {
    ["Background"]       = Color3.fromRGB(8, 10, 12),
    ["Border"]           = Color3.fromRGB(10, 12, 14),
    ["Inline"]           = Color3.fromRGB(12, 16, 20),
    ["Page Background"]  = Color3.fromRGB(14, 18, 22),
    ["Element"]          = Color3.fromRGB(18, 24, 30),
    ["Hovered Element"]  = Color3.fromRGB(26, 36, 44),
    ["Outline"]          = Color3.fromRGB(30, 48, 56),
    ["Gradient"]         = Color3.fromRGB(180, 200, 210),
    ["Text"]             = Color3.fromRGB(235, 245, 248),
    ["Placeholder Text"] = Color3.fromRGB(90, 105, 115),
    ["Text Stroke"]      = Color3.fromRGB(0, 0, 0),
    ["Accent"]           = Color3.fromRGB(0, 220, 255),
}
for ThemeName, ThemeColor in ThemeMap do
    Library:ChangeTheme(ThemeName, ThemeColor)
end

local Watermark = Library:Watermark("curvoid v1.1.0 · by vel1ous · ofx")
local KeybindList = Library:KeybindList()

-- // pages
local SnapPage = Window:Page({Name = "Snaps", Columns = 2})
local TunePage = Window:Page({Name = "Tuning", Columns = 2})
local SettingsPage = Library:CreateSettingsPage(Window, Watermark, KeybindList)

-- // snaps page
do
    local MasterSection = SnapPage:Section({Name = "Master", Side = 1})
    MasterSection:Toggle({
        Name = "Master enabled",
        Flag = "CurvoidMaster",
        Default = true,
        Callback = function(Value)
            config.enabled = Value
        end
    })

    MasterSection:Toggle({
        Name = "Jump on g / r snap",
        Flag = "CurvoidJump",
        Default = true,
        Callback = function(Value)
            config.jumpOnSnap = Value
        end
    })

    MasterSection:Toggle({
        Name = "Smooth return",
        Flag = "CurvoidSmooth",
        Default = true,
        Callback = function(Value)
            config.smoothReturn = Value
        end
    })

    local BindSection = SnapPage:Section({Name = "Actions", Side = 1})

    local FlashToggle = BindSection:Toggle({
        Name = "Flash 180",
        Flag = "CurvoidFlash",
        Default = true,
        Callback = function(Value)
            config.flashOn = Value
        end
    })
    FlashToggle:Keybind({
        Flag = "CurvoidFlashKey",
        Default = Enum.KeyCode.F,
        Mode = "Toggle",
        Callback = function(Value)
            if Value and config.flashOn then
                task.spawn(flashSnap)
            end
        end
    })

    local BackToggle = BindSection:Toggle({
        Name = "Backwards snap",
        Flag = "CurvoidBack",
        Default = true,
        Callback = function(Value)
            config.backOn = Value
        end
    })
    BackToggle:Keybind({
        Flag = "CurvoidBackKey",
        Default = Enum.KeyCode.G,
        Mode = "Toggle",
        Callback = function(Value)
            if Value and config.backOn then
                task.spawn(doSnap, "back", math.rad(config.snapAngle), 0, config.jumpOnSnap)
            end
        end
    })

    local UpToggle = BindSection:Toggle({
        Name = "Up snap",
        Flag = "CurvoidUp",
        Default = true,
        Callback = function(Value)
            config.upOn = Value
        end
    })
    UpToggle:Keybind({
        Flag = "CurvoidUpKey",
        Default = Enum.KeyCode.R,
        Mode = "Toggle",
        Callback = function(Value)
            if Value and config.upOn then
                task.spawn(doSnap, "up", 0, math.rad(config.upAngle), config.jumpOnSnap)
            end
        end
    })

    local TestSection = SnapPage:Section({Name = "Test Fire", Side = 2})
    local TestButtons = TestSection:Button()
    TestButtons:Add("Flash 180", function()
        task.spawn(flashSnap)
    end)
    TestButtons:Add("Backwards snap", function()
        task.spawn(doSnap, "back", math.rad(config.snapAngle), 0, config.jumpOnSnap)
    end)
    TestButtons:Add("Up snap", function()
        task.spawn(doSnap, "up", 0, math.rad(config.upAngle), config.jumpOnSnap)
    end)

    local AboutSection = SnapPage:Section({Name = "About", Side = 2})
    AboutSection:Label("curvoid v1.1.0 — camera snap suite")
    AboutSection:Label("made by vel1ous · stamped ofx")
    AboutSection:Label("f — flash 180 · g — backwards · r — up")
    AboutSection:Label("rightcontrol — toggle menu")
end

-- // tuning page
do
    local AngleSection = TunePage:Section({Name = "Angles", Side = 1})
    AngleSection:Slider({
        Name = "Snap angle",
        Flag = "CurvoidSnapAngle",
        Min = 90,
        Max = 360,
        Default = 180,
        Suffix = "deg",
        Decimals = 5,
        Callback = function(Value)
            config.snapAngle = Value
        end
    })

    AngleSection:Slider({
        Name = "Up angle",
        Flag = "CurvoidUpAngle",
        Min = 15,
        Max = 90,
        Default = 45,
        Suffix = "deg",
        Decimals = 1,
        Callback = function(Value)
            config.upAngle = Value
        end
    })

    local TimingSection = TunePage:Section({Name = "Timing", Side = 1})
    TimingSection:Slider({
        Name = "Hold time",
        Flag = "CurvoidHoldTime",
        Min = 0.05,
        Max = 0.5,
        Default = 0.15,
        Suffix = "s",
        Decimals = 0.01,
        Callback = function(Value)
            config.holdTime = Value
        end
    })

    TimingSection:Slider({
        Name = "Return speed",
        Flag = "CurvoidSnapSpeed",
        Min = 2,
        Max = 20,
        Default = 8,
        Decimals = 1,
        Callback = function(Value)
            config.snapSpeed = Value
        end
    })
end

-- // open the menu on load
Window:SetOpen(true)

Library:Notification("curvoid v1.1.0", "loaded for " .. player.DisplayName .. " — f flash · g back · r up", 5)

getgenv().Library = Library
