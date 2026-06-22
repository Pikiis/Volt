-- =============================================
--          VOLT | Fish It Notifier
--        Webhook Notifier by Volt
--        [SECURED BUILD - v2.0]
-- =============================================

-- =============================================
--   [1] EXECUTOR COMPATIBILITY LAYER
--   Support: Synapse X, Delta, Arceus X,
--            Fluxus, Codex, Krnl, Solara,
--            Evon, Hydrogen (Mobile), Wave
-- =============================================
local _http = (syn and syn.request)
    or (http and http.request)
    or (fluxus and fluxus.request)
    or (request)
    or (fetchget)
    or nil

local _gethui = (gethui and gethui())
    or (game:GetService("CoreGui"))

-- Executor-safe pcall wrapper
local _pcall = pcall
local _xpcall = xpcall

-- Safe service getter
local function _service(name)
    local ok, svc = _pcall(function()
        return game:GetService(name)
    end)
    return ok and svc or nil
end

local HttpService  = _service("HttpService")
local Players      = _service("Players")
local RunService   = _service("RunService")
local TweenService = _service("TweenService")
local LocalPlayer  = Players and Players.LocalPlayer

-- Guard: pastikan environment valid
if not LocalPlayer then
    warn("[Volt] Gagal load: LocalPlayer tidak ditemukan.")
    return
end

-- =============================================
--   [2] ANTI-DUPLICATE GUARD
--   Cegah script jalan 2x di session sama
-- =============================================
if _G.__VoltLoaded then
    warn("[Volt] Script sudah berjalan, skip reload.")
    return
end
_G.__VoltLoaded = true

-- Cleanup ketika script berhenti
game:BindToClose(function()
    _G.__VoltLoaded = nil
end)

-- =============================================
--   [3] STRING OBFUSCATION HELPER
--   Encode string sensitif biar tidak mudah
--   di-scan oleh string dumper
-- =============================================
local function _s(t)
    local r = {}
    for i = 1, #t do
        r[i] = string.char(t[i])
    end
    return table.concat(r)
end

-- Encoded strings (tidak plain-text di memory)
local STR_APP_NAME    = _s({86,111,108,116,32,124,32,70,105,115,104,32,73,116})        -- "Volt | Fish It"
local STR_NOTIFIER    = _s({86,111,108,116,32,124,32,70,105,115,104,32,73,116,32,78,111,116,105,102,105,101,114}) -- "Volt | Fish It Notifier"
local STR_SERVER_SCAN = _s({86,111,108,116,32,124,32,83,101,114,118,101,114,32,83,99,97,110})  -- "Volt | Server Scan"
local STR_DISCONNECT  = _s({86,111,108,116,32,124,32,68,105,115,99,111,110,110,101,99,116})    -- "Volt | Disconnect"
local STR_GUI_NAME    = _s({86,111,108,116,78,111,116,105,102,105,101,114})                    -- "VoltNotifier"

-- =============================================
--   [4] CONFIG
-- =============================================
local Config = {
    FishCaughtEnabled   = false,
    FishCaughtWebhook   = "",
    DisconnectEnabled   = false,
    DisconnectWebhook   = "",
    WebhookServerEnabled = false,
    WebhookServerURL    = "",
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
--   [5] SAFE WEBHOOK SENDER
--   - Pcall wrapped
--   - Rate limiter sederhana (anti-spam)
--   - Validasi URL format
-- =============================================
local _lastSent = {}
local RATE_LIMIT_MS = 1.5 -- detik minimal antar webhook per kategori

local function _isValidWebhook(url)
    if type(url) ~= "string" or url == "" then return false end
    -- Hanya izinkan discord webhook URL
    return url:match("^https://discord%.com/api/webhooks/%d+/.+") ~= nil
        or url:match("^https://discordapp%.com/api/webhooks/%d+/.+") ~= nil
        or url:match("^https://ptb%.discord%.com/api/webhooks/%d+/.+") ~= nil
        or url:match("^https://canary%.discord%.com/api/webhooks/%d+/.+") ~= nil
end

local function sendWebhook(category, webhookUrl, content, embeds)
    if not _isValidWebhook(webhookUrl) then return end

    -- Rate limit check
    local now = tick()
    if _lastSent[category] and (now - _lastSent[category]) < RATE_LIMIT_MS then
        return
    end
    _lastSent[category] = now

    _pcall(function()
        if not _http then return end

        local body = HttpService:JSONEncode({
            content  = content or nil,
            embeds   = embeds or nil,
            username = STR_APP_NAME,
        })

        _http({
            Url     = webhookUrl,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = body,
        })
    end)
end

-- =============================================
--   [6] RARITY SYSTEM
-- =============================================
local RarityColors = {
    Common    = 0x9E9E9E,
    Uncommon  = 0x4CAF50,
    Epic      = 0x9C27B0,
    Legendary = 0xFFD700,
    Mythic    = 0xFF5722,
    Secret    = 0xFF0000,
    Forgotten = 0x111111,
}

local function getRarity(fishName)
    if type(fishName) ~= "string" then return "Common" end
    local n = fishName:lower()
    if n:find("forgotten") then return "Forgotten"
    elseif n:find("secret")    then return "Secret"
    elseif n:find("mythic")    then return "Mythic"
    elseif n:find("legendary") then return "Legendary"
    elseif n:find("epic")      then return "Epic"
    elseif n:find("uncommon")  then return "Uncommon"
    else return "Common" end
end

-- =============================================
--   [7] NOTIFIER FUNCTIONS (semua pcall-safe)
-- =============================================
local function notifyFishCaught(player, fishName, rarity)
    if not Config.FishCaughtEnabled then return end
    local url = Config.FishCaughtWebhook
    if not _isValidWebhook(url) then return end

    local color = RarityColors[rarity] or RarityColors["Common"]
    _pcall(sendWebhook, "fish_caught", url, nil, {{
        title       = "🎣 Fish Caught!",
        description = ("**Player:** %s\n**Ikan:** %s\n**Rarity:** %s"):format(
                        tostring(player.Name), tostring(fishName), tostring(rarity)),
        color       = color,
        footer      = { text = STR_NOTIFIER },
        timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }})
end

local function notifyServerFish(player, fishName, rarity)
    if not Config.WebhookServerEnabled then return end
    if not Config.RarityFilter[rarity] then return end
    local url = Config.WebhookServerURL
    if not _isValidWebhook(url) then return end

    local color = RarityColors[rarity] or RarityColors["Common"]
    _pcall(sendWebhook, "server_" .. tostring(player.UserId), url, nil, {{
        title       = "🌐 Server Fish Scan",
        description = ("**Player:** %s\n**Ikan:** %s\n**Rarity:** %s"):format(
                        tostring(player.Name), tostring(fishName), tostring(rarity)),
        color       = color,
        footer      = { text = STR_SERVER_SCAN },
        timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }})
end

local function notifyDisconnect(reason)
    if not Config.DisconnectEnabled then return end
    local url = Config.DisconnectWebhook
    if not _isValidWebhook(url) then return end

    _pcall(sendWebhook, "disconnect", url, nil, {{
        title       = "⚠️ Account Disconnected!",
        description = ("**Player:** %s\n**Reason:** %s\n**Game:** Fish It"):format(
                        tostring(LocalPlayer.Name), tostring(reason)),
        color       = 0xFF0000,
        footer      = { text = STR_DISCONNECT },
        timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ"),
    }})
end

-- =============================================
--   [8] EVENT HOOKS
-- =============================================
local _connections = {}

local function addConn(conn)
    table.insert(_connections, conn)
end

local function setupDisconnectDetector()
    -- Method 1: CoreGui text detection
    _pcall(function()
        addConn(_gethui.DescendantAdded:Connect(function(obj)
            _pcall(function()
                if not obj:IsA("TextLabel") then return end
                local t = obj.Text:lower()
                if t:find("disconnect") or t:find("you have been") or t:find("kicked") or t:find("lost connection") then
                    notifyDisconnect(obj.Text)
                end
            end)
        end))
    end)

    -- Method 2: OnTeleport fallback
    _pcall(function()
        addConn(LocalPlayer.OnTeleport:Connect(function(state)
            if state == Enum.TeleportState.Failed then
                notifyDisconnect("Teleport / Connection Failed")
            end
        end))
    end)

    -- Method 3: Kick detection via CharacterRemoving + timeout
    _pcall(function()
        addConn(LocalPlayer.CharacterRemoving:Connect(function()
            task.delay(8, function()
                if not LocalPlayer.Character and Config.DisconnectEnabled then
                    notifyDisconnect("Character removed (possible kick)")
                end
            end)
        end))
    end)
end

local function setupFishHooks()
    -- Scan ReplicatedStorage untuk RemoteEvent fish/catch
    _pcall(function()
        local RS = game:GetService("ReplicatedStorage")
        for _, remote in ipairs(RS:GetDescendants()) do
            _pcall(function()
                if not (remote:IsA("RemoteEvent") or remote:IsA("RemoteFunction")) then return end
                local n = remote.Name:lower()
                if n:find("fish") or n:find("catch") or n:find("caught") or n:find("reel") then
                    addConn(remote.OnClientEvent:Connect(function(...)
                        _pcall(function()
                            local args = {...}
                            local fishName = tostring(args[1] or args[2] or "Unknown Fish")
                            local rarity   = getRarity(fishName)
                            notifyFishCaught(LocalPlayer, fishName, rarity)
                        end)
                    end))
                end
            end)
        end
    end)

    -- Monitor semua player untuk server scan
    local function watchPlayer(player)
        _pcall(function()
            addConn(player.CharacterAdded:Connect(function(char)
                _pcall(function()
                    addConn(char.DescendantAdded:Connect(function(obj)
                        _pcall(function()
                            if obj:IsA("BillboardGui") or (obj:IsA("TextLabel") and obj.Text ~= "") then
                                local txt = obj:IsA("TextLabel") and obj.Text or ""
                                if txt ~= "" then
                                    local rarity = getRarity(txt)
                                    notifyServerFish(player, txt, rarity)
                                end
                            end
                        end)
                    end))
                end)
            end))
        end)
    end

    for _, p in ipairs(Players:GetPlayers()) do
        _pcall(function() watchPlayer(p) end)
    end
    addConn(Players.PlayerAdded:Connect(function(p)
        _pcall(function() watchPlayer(p) end)
    end))
end

-- =============================================
--   [9] UI BUILDER
-- =============================================
local function buildUI()
    -- Cleanup UI lama
    _pcall(function()
        local old = LocalPlayer.PlayerGui:FindFirstChild(STR_GUI_NAME)
        if old then old:Destroy() end
    end)

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name             = STR_GUI_NAME
    ScreenGui.ResetOnSpawn     = false
    ScreenGui.ZIndexBehavior   = Enum.ZIndexBehavior.Sibling
    ScreenGui.DisplayOrder     = 999
    -- Protect dari deteksi sederhana
    _pcall(function() ScreenGui.Parent = _gethui end)
    if not ScreenGui.Parent then
        ScreenGui.Parent = LocalPlayer.PlayerGui
    end

    -- Tween helper
    local function tween(obj, props, t)
        _pcall(function()
            TweenService:Create(obj, TweenInfo.new(t or 0.15, Enum.EasingStyle.Quad), props):Play()
        end)
    end

    -- ===== MAIN FRAME =====
    local MainFrame = Instance.new("Frame")
    MainFrame.Name            = "MainFrame"
    MainFrame.Size            = UDim2.new(0, 340, 0, 490)
    MainFrame.Position        = UDim2.new(0.5, -170, 0.5, -245)
    MainFrame.BackgroundColor3 = Color3.fromRGB(13, 13, 18)
    MainFrame.BorderSizePixel = 0
    MainFrame.Active          = true
    MainFrame.Draggable       = true
    MainFrame.Parent          = ScreenGui

    Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)

    local Stroke = Instance.new("UIStroke", MainFrame)
    Stroke.Color     = Color3.fromRGB(80, 140, 255)
    Stroke.Thickness = 1.5

    -- ===== HEADER =====
    local Header = Instance.new("Frame", MainFrame)
    Header.Size             = UDim2.new(1, 0, 0, 46)
    Header.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
    Header.BorderSizePixel  = 0
    Instance.new("UICorner", Header).CornerRadius = UDim.new(0, 12)

    -- Header fix bottom corners
    local HFix = Instance.new("Frame", Header)
    HFix.Size             = UDim2.new(1, 0, 0.5, 0)
    HFix.Position         = UDim2.new(0, 0, 0.5, 0)
    HFix.BackgroundColor3 = Color3.fromRGB(18, 18, 26)
    HFix.BorderSizePixel  = 0

    local Logo = Instance.new("TextLabel", Header)
    Logo.Size              = UDim2.new(0, 80, 1, 0)
    Logo.Position          = UDim2.new(0, 12, 0, 0)
    Logo.BackgroundTransparency = 1
    Logo.Text              = "⚡ Volt"
    Logo.TextColor3        = Color3.fromRGB(80, 160, 255)
    Logo.Font              = Enum.Font.GothamBold
    Logo.TextSize          = 15
    Logo.TextXAlignment    = Enum.TextXAlignment.Left

    local Title = Instance.new("TextLabel", Header)
    Title.Size              = UDim2.new(1, -130, 1, 0)
    Title.Position          = UDim2.new(0, 90, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text              = "Fish It — Notifier"
    Title.TextColor3        = Color3.fromRGB(160, 160, 175)
    Title.Font              = Enum.Font.Gotham
    Title.TextSize          = 12
    Title.TextXAlignment    = Enum.TextXAlignment.Left

    local CloseBtn = Instance.new("TextButton", Header)
    CloseBtn.Size             = UDim2.new(0, 28, 0, 28)
    CloseBtn.Position         = UDim2.new(1, -36, 0.5, -14)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(55, 18, 18)
    CloseBtn.Text             = "✕"
    CloseBtn.TextColor3       = Color3.fromRGB(255, 80, 80)
    CloseBtn.Font             = Enum.Font.GothamBold
    CloseBtn.TextSize         = 12
    CloseBtn.BorderSizePixel  = 0
    Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

    CloseBtn.MouseEnter:Connect(function()
        tween(CloseBtn, { BackgroundColor3 = Color3.fromRGB(100, 30, 30) })
    end)
    CloseBtn.MouseLeave:Connect(function()
        tween(CloseBtn, { BackgroundColor3 = Color3.fromRGB(55, 18, 18) })
    end)
    CloseBtn.MouseButton1Click:Connect(function()
        ScreenGui:Destroy()
        _G.__VoltLoaded = nil
    end)

    -- ===== SCROLL FRAME =====
    local Scroll = Instance.new("ScrollingFrame", MainFrame)
    Scroll.Size                  = UDim2.new(1, -16, 1, -54)
    Scroll.Position              = UDim2.new(0, 8, 0, 52)
    Scroll.BackgroundTransparency = 1
    Scroll.ScrollBarThickness    = 3
    Scroll.ScrollBarImageColor3  = Color3.fromRGB(80, 140, 255)
    Scroll.CanvasSize            = UDim2.new(0, 0, 0, 0)
    Scroll.BorderSizePixel       = 0

    local List = Instance.new("UIListLayout", Scroll)
    List.SortOrder = Enum.SortOrder.LayoutOrder
    List.Padding   = UDim.new(0, 6)

    local Pad = Instance.new("UIPadding", Scroll)
    Pad.PaddingTop = UDim.new(0, 6)

    List:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        Scroll.CanvasSize = UDim2.new(0, 0, 0, List.AbsoluteContentSize.Y + 16)
    end)

    -- ===== UI HELPERS =====
    local BLUE   = Color3.fromRGB(80,  140, 255)
    local DARK   = Color3.fromRGB(22,  22,  30)
    local DARKER = Color3.fromRGB(15,  15,  20)

    local function makeSep(ord)
        local f = Instance.new("Frame", Scroll)
        f.LayoutOrder        = ord
        f.Size               = UDim2.new(1, 0, 0, 1)
        f.BackgroundColor3   = Color3.fromRGB(35, 35, 48)
        f.BorderSizePixel    = 0
    end

    local function makeLabel(text, ord)
        local lbl = Instance.new("TextLabel", Scroll)
        lbl.LayoutOrder           = ord
        lbl.Size                  = UDim2.new(1, 0, 0, 22)
        lbl.BackgroundTransparency = 1
        lbl.Text                  = text
        lbl.TextColor3            = BLUE
        lbl.Font                  = Enum.Font.GothamBold
        lbl.TextSize              = 11
        lbl.TextXAlignment        = Enum.TextXAlignment.Left
    end

    local function makeToggle(labelText, cfgKey, ord)
        local Row = Instance.new("Frame", Scroll)
        Row.LayoutOrder        = ord
        Row.Size               = UDim2.new(1, 0, 0, 40)
        Row.BackgroundColor3   = DARK
        Row.BorderSizePixel    = 0
        Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 8)

        local Lbl = Instance.new("TextLabel", Row)
        Lbl.Size              = UDim2.new(1, -60, 1, 0)
        Lbl.Position          = UDim2.new(0, 12, 0, 0)
        Lbl.BackgroundTransparency = 1
        Lbl.Text              = labelText
        Lbl.TextColor3        = Color3.fromRGB(210, 210, 220)
        Lbl.Font              = Enum.Font.Gotham
        Lbl.TextSize          = 13
        Lbl.TextXAlignment    = Enum.TextXAlignment.Left

        local Track = Instance.new("TextButton", Row)
        Track.Size            = UDim2.new(0, 44, 0, 24)
        Track.Position        = UDim2.new(1, -54, 0.5, -12)
        Track.BackgroundColor3 = Config[cfgKey] and BLUE or Color3.fromRGB(45, 45, 55)
        Track.Text            = ""
        Track.BorderSizePixel = 0
        Instance.new("UICorner", Track).CornerRadius = UDim.new(1, 0)

        local Knob = Instance.new("Frame", Track)
        Knob.Size             = UDim2.new(0, 18, 0, 18)
        Knob.Position         = Config[cfgKey] and UDim2.new(1, -21, 0.5, -9) or UDim2.new(0, 3, 0.5, -9)
        Knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        Knob.BorderSizePixel  = 0
        Instance.new("UICorner", Knob).CornerRadius = UDim.new(1, 0)

        Track.MouseButton1Click:Connect(function()
            Config[cfgKey] = not Config[cfgKey]
            local on = Config[cfgKey]
            tween(Track, { BackgroundColor3 = on and BLUE or Color3.fromRGB(45, 45, 55) })
            tween(Knob,  { Position = on and UDim2.new(1,-21,0.5,-9) or UDim2.new(0,3,0.5,-9) })
        end)
    end

    local function makeInput(ph, cfgKey, ord)
        local Row = Instance.new("Frame", Scroll)
        Row.LayoutOrder        = ord
        Row.Size               = UDim2.new(1, 0, 0, 40)
        Row.BackgroundColor3   = DARK
        Row.BorderSizePixel    = 0
        Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 8)

        -- Validation indicator dot
        local Dot = Instance.new("Frame", Row)
        Dot.Size               = UDim2.new(0, 8, 0, 8)
        Dot.Position           = UDim2.new(1, -16, 0.5, -4)
        Dot.BackgroundColor3   = Color3.fromRGB(60, 60, 70)
        Dot.BorderSizePixel    = 0
        Instance.new("UICorner", Dot).CornerRadius = UDim.new(1, 0)

        local Box = Instance.new("TextBox", Row)
        Box.Size               = UDim2.new(1, -30, 1, -10)
        Box.Position           = UDim2.new(0, 10, 0, 5)
        Box.BackgroundTransparency = 1
        Box.PlaceholderText    = ph
        Box.PlaceholderColor3  = Color3.fromRGB(80, 80, 90)
        Box.Text               = Config[cfgKey] or ""
        Box.TextColor3         = Color3.fromRGB(220, 220, 230)
        Box.Font               = Enum.Font.Gotham
        Box.TextSize           = 11
        Box.TextXAlignment     = Enum.TextXAlignment.Left
        Box.ClearTextOnFocus   = false

        Box.FocusLost:Connect(function()
            Config[cfgKey] = Box.Text
            -- Visual feedback: valid = hijau, invalid = merah
            local valid = _isValidWebhook(Box.Text) or Box.Text == ""
            tween(Dot, { BackgroundColor3 = Box.Text == "" and Color3.fromRGB(60,60,70)
                            or valid and Color3.fromRGB(50,200,80)
                            or Color3.fromRGB(220,60,60) })
        end)
    end

    local function makeRarityRow(name, dotColor, ord)
        local Row = Instance.new("Frame", Scroll)
        Row.LayoutOrder        = ord
        Row.Size               = UDim2.new(1, 0, 0, 34)
        Row.BackgroundColor3   = DARK
        Row.BorderSizePixel    = 0
        Instance.new("UICorner", Row).CornerRadius = UDim.new(0, 8)

        local Dot2 = Instance.new("Frame", Row)
        Dot2.Size              = UDim2.new(0, 10, 0, 10)
        Dot2.Position          = UDim2.new(0, 12, 0.5, -5)
        Dot2.BackgroundColor3  = dotColor
        Dot2.BorderSizePixel   = 0
        Instance.new("UICorner", Dot2).CornerRadius = UDim.new(1, 0)

        local Lbl2 = Instance.new("TextLabel", Row)
        Lbl2.Size              = UDim2.new(1, -70, 1, 0)
        Lbl2.Position          = UDim2.new(0, 30, 0, 0)
        Lbl2.BackgroundTransparency = 1
        Lbl2.Text              = name
        Lbl2.TextColor3        = Color3.fromRGB(210, 210, 220)
        Lbl2.Font              = Enum.Font.Gotham
        Lbl2.TextSize          = 12
        Lbl2.TextXAlignment    = Enum.TextXAlignment.Left

        local Chk = Instance.new("TextButton", Row)
        Chk.Size               = UDim2.new(0, 24, 0, 24)
        Chk.Position           = UDim2.new(1, -34, 0.5, -12)
        Chk.BackgroundColor3   = Config.RarityFilter[name] and BLUE or Color3.fromRGB(38, 38, 48)
        Chk.Text               = Config.RarityFilter[name] and "✓" or ""
        Chk.TextColor3         = Color3.fromRGB(255, 255, 255)
        Chk.Font               = Enum.Font.GothamBold
        Chk.TextSize           = 13
        Chk.BorderSizePixel    = 0
        Instance.new("UICorner", Chk).CornerRadius = UDim.new(0, 6)

        Chk.MouseButton1Click:Connect(function()
            Config.RarityFilter[name] = not Config.RarityFilter[name]
            local on = Config.RarityFilter[name]
            tween(Chk, { BackgroundColor3 = on and BLUE or Color3.fromRGB(38,38,48) })
            Chk.Text = on and "✓" or ""
        end)
    end

    -- ===== BUILD LAYOUT =====
    local o = 0

    makeLabel("  🎣  FISH CAUGHT WEBHOOK", o) o+=1
    makeToggle("Fish Caught Notifier", "FishCaughtEnabled", o) o+=1
    makeInput("Paste Discord webhook URL...", "FishCaughtWebhook", o) o+=1
    makeSep(o) o+=1

    makeLabel("  ⚠️  DISCONNECT NOTIFIER", o) o+=1
    makeToggle("Disconnect Alert", "DisconnectEnabled", o) o+=1
    makeInput("Paste Discord webhook URL...", "DisconnectWebhook", o) o+=1
    makeSep(o) o+=1

    makeLabel("  🌐  WEBHOOK SERVER SCAN", o) o+=1
    makeToggle("Server Fish Scanner", "WebhookServerEnabled", o) o+=1
    makeInput("Paste Discord webhook URL...", "WebhookServerURL", o) o+=1

    makeLabel("  ▸  Filter Rarity", o) o+=1
    makeRarityRow("Common",    Color3.fromRGB(158,158,158), o) o+=1
    makeRarityRow("Uncommon",  Color3.fromRGB(76, 175, 80), o) o+=1
    makeRarityRow("Epic",      Color3.fromRGB(156, 39,176), o) o+=1
    makeRarityRow("Legendary", Color3.fromRGB(255,215,  0), o) o+=1
    makeRarityRow("Mythic",    Color3.fromRGB(255, 87, 34), o) o+=1
    makeRarityRow("Secret",    Color3.fromRGB(229, 57, 53), o) o+=1
    makeRarityRow("Forgotten", Color3.fromRGB( 70, 70, 80), o) o+=1

    -- ===== TOGGLE ICON BUTTON =====
    local Icon = Instance.new("ImageButton", ScreenGui)
    Icon.Size             = UDim2.new(0, 44, 0, 44)
    Icon.Position         = UDim2.new(0, 14, 0.5, -22)
    Icon.BackgroundColor3 = BLUE
    Icon.Image            = ""
    Icon.BorderSizePixel  = 0
    Instance.new("UICorner", Icon).CornerRadius = UDim.new(0, 12)

    local UIStroke2 = Instance.new("UIStroke", Icon)
    UIStroke2.Color     = Color3.fromRGB(130, 180, 255)
    UIStroke2.Thickness = 1

    local IconLbl = Instance.new("TextLabel", Icon)
    IconLbl.Size              = UDim2.new(1, 0, 1, 0)
    IconLbl.BackgroundTransparency = 1
    IconLbl.Text              = "⚡"
    IconLbl.TextSize          = 22
    IconLbl.Font              = Enum.Font.GothamBold

    local visible = true
    Icon.MouseButton1Click:Connect(function()
        visible = not visible
        tween(MainFrame, { Size = visible
            and UDim2.new(0,340,0,490)
            or  UDim2.new(0,340,0,0) }, 0.2)
        task.delay(0.21, function()
            MainFrame.Visible = visible
        end)
        if visible then MainFrame.Visible = true end
    end)

    Icon.MouseEnter:Connect(function()
        tween(Icon, { BackgroundColor3 = Color3.fromRGB(100,160,255) })
    end)
    Icon.MouseLeave:Connect(function()
        tween(Icon, { BackgroundColor3 = BLUE })
    end)
end

-- =============================================
--   [10] INIT — semua dalam pcall
-- =============================================
local function init()
    _pcall(buildUI)
    _pcall(setupDisconnectDetector)
    _pcall(setupFishHooks)
    print("[Volt] v2.0 Secured loaded successfully.")
end

init()
