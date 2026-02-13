
local ENDPOINT = "https://715bbbf9.titanium-pages-proxy.pages.dev/api/payload"

local function httpGet(url)
    local host = tostring(url):match("^https?://([^/]+)") or ""
    local origin = host ~= "" and ("https://" .. host) or ""

    local defaultHeaders = {
        ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36",
        ["Accept"] = "text/plain,*/*;q=0.8",
        ["Accept-Language"] = "en-US,en;q=0.9",
        ["Cache-Control"] = "no-cache",
        ["Pragma"] = "no-cache",
    }

    if origin ~= "" then
        defaultHeaders["Origin"] = origin
        defaultHeaders["Referer"] = origin .. "/"
    end

    local function tryRequest(fn)
        if type(fn) ~= "function" then return nil end
        local ok, res = pcall(function()
            return fn({
                Url = url,
                Method = "GET",
                Headers = defaultHeaders,
                headers = defaultHeaders,
            })
        end)
        if not ok then
            ok, res = pcall(function()
                return fn(url)
            end)
        end
        if not ok then
            return nil, "request_error:" .. tostring(res)
        end
        if type(res) == "table" then
            local body = res.Body or res.body or res.ResponseBody or res.responseBody
            local code = res.StatusCode or res.Status or res.status
            if type(body) == "string" then
                return body, code
            end
            return nil, "no_body:" .. tostring(code)
        end
        if type(res) == "string" then
            return res, 200
        end
        return nil, "bad_response_type:" .. typeof(res)
    end

    if game and game.HttpGetAsync then
        local ok, res = pcall(function()
            return game:HttpGetAsync(url)
        end)
        if ok and type(res) == "string" then
            return res, "game:HttpGetAsync"
        end
        if not ok then
            return nil, "game_httpgetasync_error:" .. tostring(res)
        end
    end

    if game and game.HttpGet then
        local ok, res = pcall(function()
            return game:HttpGet(url)
        end)
        if ok and type(res) == "string" then
            return res, "game:HttpGet"
        end
        if not ok then
            return nil, "game_httpget_error:" .. tostring(res)
        end
    end

    local body, code = tryRequest(http_request)
    if type(body) == "string" then return body, "http_request:" .. tostring(code) end

    body, code = tryRequest((syn and syn.request) or nil)
    if type(body) == "string" then return body, "syn.request:" .. tostring(code) end

    body, code = tryRequest(request)
    if type(body) == "string" then return body, "request:" .. tostring(code) end

    return nil, (code or "unknown")
end

local function urlEncode(s)
    s = tostring(s)
    s = s:gsub("\n", "\r\n")
    s = s:gsub("([^%w ])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    return s:gsub(" ", "+")
end

local function getKey()
    local env = (getgenv and getgenv()) or _G

    if env and type(env.PROJECT_LICENSE_KEY) == "string" and #env.PROJECT_LICENSE_KEY >= 8 then
        return env.PROJECT_LICENSE_KEY
    end

    if env and type(env.getLicenseKey) == "function" then
        local ok, k = pcall(env.getLicenseKey)
        if ok and type(k) == "string" and #k >= 8 then
            return k
        end
    end

    return nil
end

local function promptForKey()
    local env = (getgenv and getgenv()) or _G

    local Players = game:GetService("Players")
    local CoreGui = game:GetService("CoreGui")
    local TweenService = game:GetService("TweenService")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")

    local parent = CoreGui
    pcall(function()
        if gethui then
            parent = gethui()
        elseif get_hidden_ui then
            parent = get_hidden_ui()
        end
    end)

    local gui = Instance.new("ScreenGui")
    gui.Name = "ProjectKeyPrompt"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 1000000
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Enabled = true

    pcall(function()
        if syn and syn.protect_gui then
            syn.protect_gui(gui)
        elseif protectgui then
            protectgui(gui)
        end
    end)

    gui.Parent = parent
    if not gui.Parent then
        gui.Parent = CoreGui
    end

    gui.AncestryChanged:Connect(function()
        if not gui.Parent then
            pcall(function() gui.Parent = parent end)
            if not gui.Parent then
                gui.Parent = CoreGui
            end
        end
    end)

    local watchdogAlive = true
    local function enforceOnTop()
        if not watchdogAlive then return end
        if gui and gui.Parent == nil then
            pcall(function() gui.Parent = parent end)
            if not gui.Parent then
                gui.Parent = CoreGui
            end
        end
        if gui then
            gui.Enabled = true
            gui.DisplayOrder = 1000000
        end
    end

    local watchdogConn
    watchdogConn = RunService.RenderStepped:Connect(function()
        if not watchdogAlive then
            if watchdogConn then watchdogConn:Disconnect() end
            return
        end
        enforceOnTop()
    end)

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 420, 0, 220)
    frame.Position = UDim2.new(0.5, -210, 0.5, -110)
    frame.BackgroundColor3 = Color3.fromRGB(16, 17, 22)
    frame.BorderSizePixel = 0
    frame.ZIndex = 100
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(40, 40, 45)
    stroke.Thickness = 2
    stroke.Parent = frame

    local bgGrad = Instance.new("UIGradient")
    bgGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 20, 28)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(12, 13, 18))
    })
    bgGrad.Rotation = 90
    bgGrad.Parent = frame

    local pad = Instance.new("UIPadding")
    pad.PaddingTop = UDim.new(0, 16)
    pad.PaddingBottom = UDim.new(0, 16)
    pad.PaddingLeft = UDim.new(0, 16)
    pad.PaddingRight = UDim.new(0, 16)
    pad.Parent = frame

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, 0, 0, 26)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Text = "Titanium Login"
    title.Parent = frame

    local sub = Instance.new("TextLabel")
    sub.BackgroundTransparency = 1
    sub.Size = UDim2.new(1, 0, 0, 20)
    sub.Position = UDim2.new(0, 0, 0, 28)
    sub.Font = Enum.Font.Gotham
    sub.TextSize = 13
    sub.TextColor3 = Color3.fromRGB(170, 175, 190)
    sub.TextXAlignment = Enum.TextXAlignment.Left
    sub.Text = "Enter your license key to continue"
    sub.Parent = frame

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, 0, 0, 44)
    box.Position = UDim2.new(0, 0, 0, 72)
    box.BackgroundColor3 = Color3.fromRGB(22, 24, 33)
    box.BorderSizePixel = 0
    box.Font = Enum.Font.Gotham
    box.TextSize = 14
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.PlaceholderColor3 = Color3.fromRGB(120, 125, 140)
    box.PlaceholderText = "Paste license key here"
    box.ClearTextOnFocus = false
    box.ZIndex = 101
    box.Parent = frame

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 6)
    boxCorner.Parent = box

    local boxStroke = Instance.new("UIStroke")
    boxStroke.Color = Color3.fromRGB(55, 60, 75)
    boxStroke.Thickness = 1
    boxStroke.Parent = box

    local hint = Instance.new("TextLabel")
    hint.BackgroundTransparency = 1
    hint.Size = UDim2.new(1, 0, 0, 18)
    hint.Position = UDim2.new(0, 0, 0, 120)
    hint.Font = Enum.Font.Gotham
    hint.TextSize = 12
    hint.TextColor3 = Color3.fromRGB(170, 175, 190)
    hint.TextXAlignment = Enum.TextXAlignment.Left
    hint.Text = "Have fun"
    hint.ZIndex = 101
    hint.Parent = frame

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, 0, 0, 40)
    btn.Position = UDim2.new(0, 0, 0, 146)
    btn.BackgroundColor3 = Color3.fromRGB(85, 160, 255)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.TextColor3 = Color3.fromRGB(0, 0, 0)
    btn.Text = "Continue"
    btn.AutoButtonColor = true
    btn.ZIndex = 101
    btn.Parent = frame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn

    local btnGrad = Instance.new("UIGradient")
    btnGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 190, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 130, 255))
    })
    btnGrad.Rotation = 0
    btnGrad.Parent = btn

    local status = Instance.new("TextLabel")
    status.BackgroundTransparency = 1
    status.Size = UDim2.new(1, 0, 0, 18)
    status.Position = UDim2.new(0, 0, 0, 192)
    status.Font = Enum.Font.Gotham
    status.TextSize = 12
    status.TextColor3 = Color3.fromRGB(255, 120, 120)
    status.TextXAlignment = Enum.TextXAlignment.Left
    status.Text = ""
    status.ZIndex = 101
    status.Parent = frame

    local done = Instance.new("BindableEvent")

    local function submit()
        local k = tostring(box.Text or "")
        k = k:gsub("^%s+", ""):gsub("%s+$", "")
        if #k >= 8 then
            btn.Text = "Loading..."
            status.Text = ""
            env.PROJECT_LICENSE_KEY = k
            done:Fire(k)
            watchdogAlive = false
            if watchdogConn then
                watchdogConn:Disconnect()
                watchdogConn = nil
            end
            gui:Destroy()
        else
            status.Text = "Invalid key"
        end
    end

    btn.MouseButton1Click:Connect(submit)
    box.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            submit()
        end
    end)

    UserInputService.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.Escape then
            enforceOnTop()
            pcall(function() box:CaptureFocus() end)
        end
    end)

    box:CaptureFocus()

    do
        local startPos = frame.Position
        frame.Position = startPos + UDim2.new(0, 0, 0, 10)
        frame.BackgroundTransparency = 1
        stroke.Transparency = 1
        TweenService:Create(frame, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = startPos,
            BackgroundTransparency = 0
        }):Play()
        TweenService:Create(stroke, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Transparency = 0
        }):Play()
    end

    return done.Event:Wait()
end

local key = getKey()
if not key then
    key = promptForKey()
end

local function fetchPayload(k)
    local cb = tostring(os.time()) .. tostring(math.random(1000, 9999))
    local url = ENDPOINT .. "?key=" .. urlEncode(k) .. "&cb=" .. cb
    local body, info = httpGet(url)
    return body, info, url
end

local payload, info
local lastUrl
for i = 1, 3 do
    payload, info, lastUrl = fetchPayload(key)
    if type(payload) == "string" and #payload >= 8 then
        break
    end
    task.wait(0.15)
end

if type(payload) ~= "string" or #payload < 8 then
    local msg = "Failed to download payload"
    msg = msg .. " (info=" .. tostring(info) .. ")"
    msg = msg .. " endpoint=" .. tostring(ENDPOINT)
    msg = msg .. " url=" .. tostring(lastUrl)
    if type(payload) == "string" then
        msg = msg .. " body_len=" .. tostring(#payload)
        msg = msg .. " body_prefix=" .. payload:sub(1, 80)
    else
        msg = msg .. " body_type=" .. tostring(typeof(payload))
    end
    error(msg)
end

local fn, err = loadstring(payload)
if not fn then
    error("Payload compile error: " .. tostring(err))
end

return fn()
