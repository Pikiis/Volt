-- =============================================
--          VOLT | Fish It Notifier
--        Webhook Notifier by Volt
--           [BUILD v3.0 - FIXED]
-- =============================================

-- =============================================
--   [1] SERVICES — cara paling aman di Delta
-- =============================================
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService  = game:GetService("HttpService")
local CoreGui      = game:GetService("CoreGui")
local LocalPlayer  = Players.LocalPlayer

-- =============================================
--   [2] ANTI-DUPLICATE
-- =============================================
if _G.__VoltRunning then
    warn("[Volt] Already running, skipping.")
    return
end
_G.__VoltRunning = true

-- =============================================
--   [3] EXECUTOR HTTP COMPATIBILITY
--   Delta pakai `request`, bukan syn.request
-- =============================================
local httpRequest = (syn and syn.request)
    or (http_request)
    or (request)
    or (http and http.request)
    or (fluxus and fluxus.request)
    or nil

-- =============================================
--   [4] CONFIG
-- =============================================
local Config = {
    FishCaughtEnabled    = false,
    FishCaughtWebhook    = "",
    DisconnectEnabled    = false,
    DisconnectWebhook    = "",
    ServerScanEnabled    = false,
    ServerScanWebhook    = "",
    RarityFilter = {
        Common    = true,
        Uncommon  = true,
        Epic      = true,
        Legendary = true,
        Mythic    = true,
        Secret    = true,
        Forgotten = true,
    },
}

-- =============================================
--   [5] UTILITIES
-- =============================================
local function safeCall(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then
        -- silent fail, tidak crash script
    end
end

local function tween(obj, props, t)
    safeCall(function()
        TweenService:Create(obj, TweenInfo.new(t or 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
    end)
end

local function isValidWebhook(url)
    if type(url) ~= "string" or #url < 10 then return false end
    return url:match("^https://discord%.com/api/webhooks/") ~= nil
        or url:match("^https://discordapp%.com/api/webhooks/") ~= nil
        or url:match("^https://ptb%.discord%.com/api/webhooks/") ~= nil
end

-- Rate limiter per kategori
local _lastSent = {}
local function canSend(cat)
    local now = tick()
    if _lastSent[cat] and (now - _lastSent[cat]) < 2 then return false end
    _lastSent[cat] = now
    return true
end

-- =============================================
--   [6] WEBHOOK SENDER
-- =============================================
local function sendWebhook(cat, url, embeds)
    if not isValidWebhook(url) then return end
    if not canSend(cat) then return end
    if not httpRequest then return end

    safeCall(function()
        httpRequest({
            Url     = url,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = HttpService:JSONEncode({
                username = "Volt | Fish It",
                embeds   = embeds,
            }),
        })
    end)
end

-- =============================================
--   [7] RARITY
-- =============================================
local RarityColor = {
    Common    = 0x9E9E9E,
    Uncommon  = 0x4CAF50,
    Epic      = 0x9C27B0,
    Legendary = 0xFFD700,
    Mythic    = 0xFF5722,
    Secret    = 0xFF0000,
    Forgotten = 0x333333,
}

local function getRarity(name)
    name = tostring(name):lower()
    if name:find("forgotten") then return "Forgotten"
    elseif name:find("secret")    then return "Secret"
    elseif name:find("mythic")    then return "Mythic"
    elseif name:find("legendary") then return "Legendary"
    elseif name:find("epic")      then return "Epic"
    elseif name:find("uncommon")  then return "Uncommon"
    else return "Common" end
end

-- =============================================
--   [8] NOTIFIERS
-- =============================================
local function notifyFishCaught(player, fishName, rarity)
    if not Config.FishCaughtEnabled then return end
    sendWebhook("caught_" .. player.UserId, Config.FishCaughtWebhook, {{
        title       = "🎣 Fish Caught!",
        description = ("**Player:** %s\n**Fish:** %s\n**Rarity:** %s"):format(player.Name, fishName, rarity),
        color       = RarityColor[rarity] or RarityColor.Common,
        footer      = { text = "Volt | Fish It Notifier" },
        timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }})
end

local function notifyServerFish(player, fishName, rarity)
    if not Config.ServerScanEnabled then return end
    if not Config.RarityFilter[rarity] then return end
    sendWebhook("server_" .. player.UserId, Config.ServerScanWebhook, {{
        title       = "🌐 Server Fish Scan",
        description = ("**Player:** %s\n**Fish:** %s\n**Rarity:** %s"):format(player.Name, fishName, rarity),
        color       = RarityColor[rarity] or RarityColor.Common,
        footer      = { text = "Volt | Server Scan" },
        timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }})
end

local function notifyDisconnect(reason)
    if not Config.DisconnectEnabled then return end
    sendWebhook("disconnect", Config.DisconnectWebhook, {{
        title       = "⚠️ Disconnected!",
        description = ("**Player:** %s\n**Reason:** %s"):format(LocalPlayer.Name, tostring(reason)),
        color       = 0xFF0000,
        footer      = { text = "Volt | Disconnect Notifier" },
        timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }})
end

-- =============================================
--   [9] GAME HOOKS
-- =============================================
local _conns = {}
local function addConn(c) if c then table.insert(_conns, c) end end

local function hookGame()
    -- Hook RemoteEvents di ReplicatedStorage
    safeCall(function()
        local RS = game:GetService("ReplicatedStorage")
        local function scanRemotes(parent)
            for _, obj in ipairs(parent:GetDescendants()) do
                safeCall(function()
                    if obj:IsA("RemoteEvent") then
                        local n = obj.Name:lower()
                        if n:find("fish") or n:find("catch") or n:find("reel") or n:find("caught") then
                            addConn(obj.OnClientEvent:Connect(function(...)
                                safeCall(function()
                                    local args = {...}
                                    local fishName = tostring(args[1] or args[2] or "Unknown")
                                    local rarity   = getRarity(fishName)
                                    notifyFishCaught(LocalPlayer, fishName, rarity)
                                end)
                            end))
                        end
                    end
                end)
            end
        end
        scanRemotes(RS)
        -- Juga scan kalau remote muncul belakangan
        addConn(RS.DescendantAdded:Connect(function(obj)
            safeCall(function()
                if obj:IsA("RemoteEvent") then
                    local n = obj.Name:lower()
                    if n:find("fish") or n:find("catch") or n:find("reel") then
                        addConn(obj.OnClientEvent:Connect(function(...)
                            safeCall(function()
                                local args = {...}
                                local fishName = tostring(args[1] or args[2] or "Unknown")
                                notifyFishCaught(LocalPlayer, fishName, getRarity(fishName))
                            end)
                        end))
                    end
                end
            end)
        end))
    end)

    -- Server scan: pantau semua player
    local function watchPlayer(player)
        safeCall(function()
            addConn(player.CharacterAdded:Connect(function(char)
                addConn(char.DescendantAdded:Connect(function(obj)
                    safeCall(function()
                        if obj:IsA("BillboardGui") then
                            for _, lbl in ipairs(obj:GetDescendants()) do
                                if lbl:IsA("TextLabel") and lbl.Text ~= "" then
                                    local rarity = getRarity(lbl.Text)
                                    notifyServerFish(player, lbl.Text, rarity)
                                end
                            end
                        end
                    end)
                end))
            end))
        end)
    end

    for _, p in ipairs(Players:GetPlayers()) do safeCall(function() watchPlayer(p) end) end
    addConn(Players.PlayerAdded:Connect(function(p) safeCall(function() watchPlayer(p) end) end))

    -- Disconnect detection
    safeCall(function()
        addConn(CoreGui.DescendantAdded:Connect(function(obj)
            safeCall(function()
                if obj:IsA("TextLabel") then
                    local t = obj.Text:lower()
                    if t:find("disconnect") or t:find("kicked") or t:find("lost connection") or t:find("you have been") then
                        notifyDisconnect(obj.Text)
                    end
                end
            end)
        end))
    end)

    safeCall(function()
        addConn(LocalPlayer.OnTeleport:Connect(function(state)
            if state == Enum.TeleportState.Failed then
                notifyDisconnect("Teleport Failed")
            end
        end))
    end)
end

-- =============================================
--   [10] UI
-- =============================================
local BLUE   = Color3.fromRGB(80,  145, 255)
local BLUE2  = Color3.fromRGB(50,  100, 200)
local DARK   = Color3.fromRGB(13,  13,  18)
local DARK2  = Color3.fromRGB(20,  20,  28)
local DARK3  = Color3.fromRGB(25,  25,  35)
local WHITE  = Color3.fromRGB(220, 220, 230)
local DIMMED = Color3.fromRGB(130, 130, 145)

local function buildUI()
    -- Cleanup
    safeCall(function()
        local old = CoreGui:FindFirstChild("VoltUI")
        if old then old:Destroy() end
    end)

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name           = "VoltUI"
    ScreenGui.ResetOnSpawn   = false
    ScreenGui.DisplayOrder   = 999
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    -- Delta-safe parent
    local ok = pcall(function() ScreenGui.Parent = CoreGui end)
    if not ok then ScreenGui.Parent = LocalPlayer.PlayerGui end

    -- ==========================================
    --   LOADER SCREEN
    -- ==========================================
    local Loader = Instance.new("Frame", ScreenGui)
    Loader.Name              = "Loader"
    Loader.Size              = UDim2.new(1, 0, 1, 0)
    Loader.BackgroundColor3  = Color3.fromRGB(8, 8, 12)
    Loader.ZIndex            = 100

    -- Logo text
    local LoaderLogo = Instance.new("TextLabel", Loader)
    LoaderLogo.Size              = UDim2.new(0, 300, 0, 50)
    LoaderLogo.Position          = UDim2.new(0.5, -150, 0.5, -110)
    LoaderLogo.BackgroundTransparency = 1
    LoaderLogo.Text              = "⚡ VOLT"
    LoaderLogo.TextColor3        = BLUE
    LoaderLogo.Font              = Enum.Font.GothamBold
    LoaderLogo.TextSize          = 38
    LoaderLogo.TextTransparency  = 1
    LoaderLogo.ZIndex            = 101

    local LoaderSub = Instance.new("TextLabel", Loader)
    LoaderSub.Size               = UDim2.new(0, 300, 0, 24)
    LoaderSub.Position           = UDim2.new(0.5, -150, 0.5, -55)
    LoaderSub.BackgroundTransparency = 1
    LoaderSub.Text               = "Fish It Notifier"
    LoaderSub.TextColor3         = DIMMED
    LoaderSub.Font               = Enum.Font.Gotham
    LoaderSub.TextSize           = 14
    LoaderSub.TextTransparency   = 1
    LoaderSub.ZIndex             = 101

    -- Status label
    local StatusLbl = Instance.new("TextLabel", Loader)
    StatusLbl.Size               = UDim2.new(0, 300, 0, 20)
    StatusLbl.Position           = UDim2.new(0.5, -150, 0.5, 10)
    StatusLbl.BackgroundTransparency = 1
    StatusLbl.Text               = ""
    StatusLbl.TextColor3         = Color3.fromRGB(100, 180, 100)
    StatusLbl.Font               = Enum.Font.Gotham
    StatusLbl.TextSize           = 12
    StatusLbl.TextTransparency   = 1
    StatusLbl.ZIndex             = 101

    -- Progress bar background
    local BarBG = Instance.new("Frame", Loader)
    BarBG.Size               = UDim2.new(0, 260, 0, 4)
    BarBG.Position           = UDim2.new(0.5, -130, 0.5, 40)
    BarBG.BackgroundColor3   = Color3.fromRGB(30, 30, 40)
    BarBG.BorderSizePixel    = 0
    BarBG.ZIndex             = 101
    Instance.new("UICorner", BarBG).CornerRadius = UDim.new(1, 0)

    local Bar = Instance.new("Frame", BarBG)
    Bar.Size             = UDim2.new(0, 0, 1, 0)
    Bar.BackgroundColor3 = BLUE
    Bar.BorderSizePixel  = 0
    Bar.ZIndex           = 102
    Instance.new("UICorner", Bar).CornerRadius = UDim.new(1, 0)

    -- Version
    local VerLbl = Instance.new("TextLabel", Loader)
    VerLbl.Size              = UDim2.new(0, 300, 0, 16)
    VerLbl.Position          = UDim2.new(0.5, -150, 0.5, 60)
    VerLbl.BackgroundTransparency = 1
    VerLbl.Text              = "v3.0 — Secured Build"
    VerLbl.TextColor3        = Color3.fromRGB(60, 60, 80)
    VerLbl.Font              = Enum.Font.Gotham
    VerLbl.TextSize          = 11
    VerLbl.TextTransparency  = 1
    VerLbl.ZIndex            = 101

    -- ==========================================
    --   MAIN PANEL (hidden saat loader)
    -- ==========================================
    local Panel = Instance.new("Frame", ScreenGui)
    Panel.Name              = "Panel"
    Panel.Size              = UDim2.new(0, 340, 0, 500)
    Panel.Position          = UDim2.new(0.5, -170, 0.5, -250)
    Panel.BackgroundColor3  = DARK
    Panel.BorderSizePixel   = 0
    Panel.Visible           = false
    Panel.Active            = true
    Panel.Draggable         = true
    Instance.new("UICorner", Panel).CornerRadius = UDim.new(0, 12)

    local PanelStroke = Instance.new("UIStroke", Panel)
    PanelStroke.Color     = BLUE
    PanelStroke.Thickness = 1.5

    -- Header
    local Header = Instance.new("Frame", Panel)
    Header.Size            = UDim2.new(1, 0, 0, 48)
    Header.BackgroundColor3 = DARK2
    Header.BorderSizePixel = 0
    Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 12)

    local HFix = Instance.new("Frame", Header)
    HFix.Size            = UDim2.new(1, 0, 0.5, 0)
    HFix.Position        = UDim2.new(0, 0, 0.5, 0)
    HFix.BackgroundColor3 = DARK2
    HFix.BorderSizePixel = 0

    local HLogo = Instance.new("TextLabel", Header)
    HLogo.Size              = UDim2.new(0, 90, 1, 0)
    HLogo.Position          = UDim2.new(0, 14, 0, 0)
    HLogo.BackgroundTransparency = 1
    HLogo.Text              = "⚡ Volt"
    HLogo.TextColor3        = BLUE
    HLogo.Font              = Enum.Font.GothamBold
    HLogo.TextSize          = 15
    HLogo.TextXAlignment    = Enum.TextXAlignment.Left

    local HTitle = Instance.new("TextLabel", Header)
    HTitle.Size              = UDim2.new(1, -160, 1, 0)
    HTitle.Position          = UDim2.new(0, 105, 0, 0)
    HTitle.BackgroundTransparency = 1
    HTitle.Text              = "Fish It — Notifier"
    HTitle.TextColor3        = DIMMED
    HTitle.Font              = Enum.Font.Gotham
    HTitle.TextSize          = 12
    HTitle.TextXAlignment    = Enum.TextXAlignment.Left

    local CloseBtn = Instance.new("TextButton", Header)
    CloseBtn.Size            = UDim2.new(0, 28, 0, 28)
    CloseBtn.Position        = UDim2.new(1, -38, 0.5, -14)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(55, 18, 18)
    CloseBtn.Text            = "✕"
    CloseBtn.TextColor3      = Color3.fromRGB(255, 80, 80)
    CloseBtn.Font            = Enum.Font.GothamBold
    CloseBtn.TextSize        = 12
    CloseBtn.BorderSizePixel = 0
    Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

    CloseBtn.MouseButton1Click:Connect(function()
        Panel.Visible = false
        _G.__VoltRunning = nil
        for _, c in ipairs(_conns) do safeCall(function() c:Disconnect() end) end
        ScreenGui:Destroy()
    end)

    -- Scroll area
    local Scroll = Instance.new("ScrollingFrame", Panel)
    Scroll.Size                 = UDim2.new(1, -16, 1, -56)
    Scroll.Position             = UDim2.new(0, 8, 0, 54)
    Scroll.BackgroundTransparency = 1
    Scroll.ScrollBarThickness   = 3
    Scroll.ScrollBarImageColor3 = BLUE
    Scroll.BorderSizePixel      = 0
    Scroll.CanvasSize           = UDim2.new(0, 0, 0, 0)

    local List = Instance.new("UIListLayout", Scroll)
    List.SortOrder = Enum.SortOrder.LayoutOrder
    List.Padding   = UDim.new(0, 6)

    local Pad = Instance.new("UIPadding", Scroll)
    Pad.PaddingTop = UDim.new(0, 4)

    List:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        Scroll.CanvasSize = UDim2.new(0, 0, 0, List.AbsoluteContentSize.Y + 14)
    end)

    -- ===== UI Component helpers =====

    local o = 0
    local function nextOrder() o += 1 return o end

    local function makeSection(text)
        local lbl = Instance.new("TextLabel", Scroll)
        lbl.LayoutOrder          = nextOrder()
        lbl.Size                 = UDim2.new(1, 0, 0, 24)
        lbl.BackgroundTransparency = 1
        lbl.Text                 = text
        lbl.TextColor3           = BLUE
        lbl.Font                 = Enum.Font.GothamBold
        lbl.TextSize             = 11
        lbl.TextXAlignment       = Enum.TextXAlignment.Left
    end

    local function makeSep()
        local f = Instance.new("Frame", Scroll)
        f.LayoutOrder      = nextOrder()
        f.Size             = UDim2.new(1, 0, 0, 1)
        f.BackgroundColor3 = Color3.fromRGB(32, 32, 44)
        f.BorderSizePixel  = 0
    end

    local function makeToggle(labelText, cfgKey)
        local Row = Instance.new("Frame", Scroll)
        Row.LayoutOrder      = nextOrder()
        Row.Size             = UDim2.new(1, 0, 0, 40)
        Row.BackgroundColor3 = DARK3
        Row.BorderSizePixel  = 0
        Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 8)

        local Lbl = Instance.new("TextLabel", Row)
        Lbl.Size             = UDim2.new(1, -60, 1, 0)
        Lbl.Position         = UDim2.new(0, 12, 0, 0)
        Lbl.BackgroundTransparency = 1
        Lbl.Text             = labelText
        Lbl.TextColor3       = WHITE
        Lbl.Font             = Enum.Font.Gotham
        Lbl.TextSize         = 13
        Lbl.TextXAlignment   = Enum.TextXAlignment.Left

        local Track = Instance.new("TextButton", Row)
        Track.Size           = UDim2.new(0, 44, 0, 24)
        Track.Position       = UDim2.new(1, -54, 0.5, -12)
        Track.BackgroundColor3 = Config[cfgKey] and BLUE or Color3.fromRGB(40, 40, 52)
        Track.Text           = ""
        Track.BorderSizePixel = 0
        Instance.new("UICorner", Track).CornerRadius = UDim.new(1, 0)

        local Knob = Instance.new("Frame", Track)
        Knob.Size            = UDim2.new(0, 18, 0, 18)
        Knob.Position        = Config[cfgKey] and UDim2.new(1,-21,0.5,-9) or UDim2.new(0,3,0.5,-9)
        Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Knob.BorderSizePixel = 0
        Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)

        Track.MouseButton1Click:Connect(function()
            Config[cfgKey] = not Config[cfgKey]
            local on = Config[cfgKey]
            tween(Track, { BackgroundColor3 = on and BLUE or Color3.fromRGB(40,40,52) })
            tween(Knob,  { Position = on and UDim2.new(1,-21,0.5,-9) or UDim2.new(0,3,0.5,-9) })
        end)
    end

    local function makeInput(placeholder, cfgKey)
        local Row = Instance.new("Frame", Scroll)
        Row.LayoutOrder      = nextOrder()
        Row.Size             = UDim2.new(1, 0, 0, 40)
        Row.BackgroundColor3 = DARK3
        Row.BorderSizePixel  = 0
        Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 8)

        local Indicator = Instance.new("Frame", Row)
        Indicator.Size           = UDim2.new(0, 6, 0, 6)
        Indicator.Position       = UDim2.new(1, -14, 0.5, -3)
        Indicator.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
        Indicator.BorderSizePixel = 0
        Instance.new("UICorner", Indicator).CornerRadius = UDim.new(1, 0)

        local Box = Instance.new("TextBox", Row)
        Box.Size             = UDim2.new(1, -26, 1, -12)
        Box.Position         = UDim2.new(0, 10, 0, 6)
        Box.BackgroundTransparency = 1
        Box.PlaceholderText  = placeholder
        Box.PlaceholderColor3 = Color3.fromRGB(70, 70, 85)
        Box.Text             = Config[cfgKey] or ""
        Box.TextColor3       = WHITE
        Box.Font             = Enum.Font.Gotham
        Box.TextSize         = 11
        Box.TextXAlignment   = Enum.TextXAlignment.Left
        Box.ClearTextOnFocus = false

        Box.FocusLost:Connect(function()
            Config[cfgKey] = Box.Text
            local valid = isValidWebhook(Box.Text)
            local empty = Box.Text == ""
            tween(Indicator, {
                BackgroundColor3 = empty and Color3.fromRGB(50,50,65)
                    or valid and Color3.fromRGB(60,210,90)
                    or Color3.fromRGB(220,60,60)
            })
        end)
    end

    local function makeRarity(name, dotCol)
        local Row = Instance.new("Frame", Scroll)
        Row.LayoutOrder      = nextOrder()
        Row.Size             = UDim2.new(1, 0, 0, 34)
        Row.BackgroundColor3 = DARK3
        Row.BorderSizePixel  = 0
        Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 8)

        local Dot = Instance.new("Frame", Row)
        Dot.Size             = UDim2.new(0, 10, 0, 10)
        Dot.Position         = UDim2.new(0, 12, 0.5, -5)
        Dot.BackgroundColor3 = dotCol
        Dot.BorderSizePixel  = 0
        Instance.new("UICorner", Dot).CornerRadius = UDim.new(1, 0)

        local Lbl = Instance.new("TextLabel", Row)
        Lbl.Size             = UDim2.new(1, -60, 1, 0)
        Lbl.Position         = UDim2.new(0, 30, 0, 0)
        Lbl.BackgroundTransparency = 1
        Lbl.Text             = name
        Lbl.TextColor3       = WHITE
        Lbl.Font             = Enum.Font.Gotham
        Lbl.TextSize         = 12
        Lbl.TextXAlignment   = Enum.TextXAlignment.Left

        local Chk = Instance.new("TextButton", Row)
        Chk.Size             = UDim2.new(0, 24, 0, 24)
        Chk.Position         = UDim2.new(1, -34, 0.5, -12)
        Chk.BackgroundColor3 = Config.RarityFilter[name] and BLUE or Color3.fromRGB(36,36,48)
        Chk.Text             = Config.RarityFilter[name] and "✓" or ""
        Chk.TextColor3       = Color3.fromRGB(255,255,255)
        Chk.Font             = Enum.Font.GothamBold
        Chk.TextSize         = 13
        Chk.BorderSizePixel  = 0
        Instance.new("UICorner", Chk).CornerRadius = UDim.new(0, 6)

        Chk.MouseButton1Click:Connect(function()
            Config.RarityFilter[name] = not Config.RarityFilter[name]
            local on = Config.RarityFilter[name]
            tween(Chk, { BackgroundColor3 = on and BLUE or Color3.fromRGB(36,36,48) })
            Chk.Text = on and "✓" or ""
        end)
    end

    -- Build layout
    makeSection("  🎣  FISH CAUGHT WEBHOOK")
    makeToggle("Fish Caught Notifier", "FishCaughtEnabled")
    makeInput("Paste Discord webhook URL...", "FishCaughtWebhook")
    makeSep()

    makeSection("  ⚠️  DISCONNECT NOTIFIER")
    makeToggle("Disconnect Alert", "DisconnectEnabled")
    makeInput("Paste Discord webhook URL...", "DisconnectWebhook")
    makeSep()

    makeSection("  🌐  SERVER FISH SCAN")
    makeToggle("Server Fish Scanner", "ServerScanEnabled")
    makeInput("Paste Discord webhook URL...", "ServerScanWebhook")
    makeSection("  ▸  Filter Rarity")
    makeRarity("Common",    Color3.fromRGB(158,158,158))
    makeRarity("Uncommon",  Color3.fromRGB(76,175,80))
    makeRarity("Epic",      Color3.fromRGB(156,39,176))
    makeRarity("Legendary", Color3.fromRGB(255,215,0))
    makeRarity("Mythic",    Color3.fromRGB(255,87,34))
    makeRarity("Secret",    Color3.fromRGB(229,57,53))
    makeRarity("Forgotten", Color3.fromRGB(80,80,95))

    -- Toggle Icon
    local Icon = Instance.new("ImageButton", ScreenGui)
    Icon.Name            = "VoltIcon"
    Icon.Size            = UDim2.new(0, 44, 0, 44)
    Icon.Position        = UDim2.new(0, 14, 0.5, -22)
    Icon.BackgroundColor3 = BLUE
    Icon.BorderSizePixel = 0
    Icon.Visible         = false
    Instance.new("UICorner", Icon).CornerRadius = UDim.new(0, 12)

    local IconStroke = Instance.new("UIStroke", Icon)
    IconStroke.Color     = Color3.fromRGB(130, 180, 255)
    IconStroke.Thickness = 1

    local IconLbl = Instance.new("TextLabel", Icon)
    IconLbl.Size              = UDim2.new(1, 0, 1, 0)
    IconLbl.BackgroundTransparency = 1
    IconLbl.Text              = "⚡"
    IconLbl.TextSize          = 22
    IconLbl.Font              = Enum.Font.GothamBold

    local panelOpen = true
    Icon.MouseButton1Click:Connect(function()
        panelOpen = not panelOpen
        Panel.Visible = panelOpen
    end)

    -- ==========================================
    --   LOADER SEQUENCE
    -- ==========================================
    local function runLoader()
        -- Fade in logo
        tween(LoaderLogo, { TextTransparency = 0 }, 0.5)
        task.wait(0.4)
        tween(LoaderSub, { TextTransparency = 0 }, 0.4)
        task.wait(0.3)
        tween(StatusLbl, { TextTransparency = 0 }, 0.3)
        tween(VerLbl,    { TextTransparency = 0 }, 0.3)

        -- Step 1
        task.wait(0.2)
        StatusLbl.Text = "✦ Script executed..."
        StatusLbl.TextColor3 = Color3.fromRGB(100, 180, 255)
        tween(Bar, { Size = UDim2.new(0.25, 0, 1, 0) }, 0.4)
        task.wait(0.6)

        -- Step 2
        StatusLbl.Text = "✦ Scanning game: Fish It..."
        StatusLbl.TextColor3 = Color3.fromRGB(100, 200, 130)
        tween(Bar, { Size = UDim2.new(0.55, 0, 1, 0) }, 0.5)
        task.wait(0.7)

        -- Step 3: hook game
        safeCall(hookGame)
        StatusLbl.Text = "✦ Hooking events..."
        tween(Bar, { Size = UDim2.new(0.8, 0, 1, 0) }, 0.4)
        task.wait(0.5)

        -- Step 4: done
        StatusLbl.Text = "✦ Volt loaded successfully!"
        StatusLbl.TextColor3 = Color3.fromRGB(80, 220, 120)
        tween(Bar, { Size = UDim2.new(1, 0, 1, 0) }, 0.3)
        task.wait(0.8)

        -- Fade out loader, show panel
        tween(Loader, { BackgroundTransparency = 1 }, 0.5)
        tween(LoaderLogo, { TextTransparency = 1 }, 0.4)
        tween(LoaderSub,  { TextTransparency = 1 }, 0.4)
        tween(StatusLbl,  { TextTransparency = 1 }, 0.4)
        tween(VerLbl,     { TextTransparency = 1 }, 0.4)
        tween(BarBG,      { BackgroundTransparency = 1 }, 0.4)
        tween(Bar,        { BackgroundTransparency = 1 }, 0.4)
        task.wait(0.5)

        Loader.Visible = false
        Panel.Visible  = true
        Icon.Visible   = true
    end

    task.spawn(runLoader)
end

-- =============================================
--   [11] MAIN
-- =============================================
safeCall(buildUI)
