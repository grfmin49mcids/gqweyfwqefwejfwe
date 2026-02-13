
local ENDPOINT = "https://titanium-licensing.test5555543.workers.dev/v1/payload"

local function httpGet(url)
    if http_request then
        local res = http_request({ Url = url, Method = "GET" })
        return res and (res.Body or res.body)
    end

    if syn and syn.request then
        local res = syn.request({ Url = url, Method = "GET" })
        return res and res.Body
    end

    if request then
        local res = request({ Url = url, Method = "GET" })
        return res and (res.Body or res.body)
    end

    if game and game.HttpGet then
        return game:HttpGet(url)
    end

    error("No supported HTTP request function found in this runtime")
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

    local parent = CoreGui
    pcall(function()
        local lp = Players.LocalPlayer
        if lp and lp:FindFirstChildOfClass("PlayerGui") then
            parent = lp:FindFirstChildOfClass("PlayerGui")
        end
    end)

    local gui = Instance.new("ScreenGui")
    gui.Name = "ProjectKeyPrompt"
    gui.ResetOnSpawn = false
    pcall(function() gui.Parent = parent end)
    if not gui.Parent then
        gui.Parent = CoreGui
    end

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 360, 0, 160)
    frame.Position = UDim2.new(0.5, -180, 0.5, -80)
    frame.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
    frame.BorderSizePixel = 0
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(40, 40, 45)
    stroke.Thickness = 1
    stroke.Parent = frame

    local title = Instance.new("TextLabel")
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, 0, 0, 44)
    title.Position = UDim2.new(0, 0, 0, 0)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Text = "Enter License Key"
    title.Parent = frame

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -32, 0, 40)
    box.Position = UDim2.new(0, 16, 0, 56)
    box.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    box.BorderSizePixel = 0
    box.Font = Enum.Font.Gotham
    box.TextSize = 14
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.PlaceholderText = "License key"
    box.ClearTextOnFocus = false
    box.Parent = frame

    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 6)
    boxCorner.Parent = box

    local boxStroke = Instance.new("UIStroke")
    boxStroke.Color = Color3.fromRGB(40, 40, 45)
    boxStroke.Thickness = 1
    boxStroke.Parent = box

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -32, 0, 36)
    btn.Position = UDim2.new(0, 16, 0, 108)
    btn.BackgroundColor3 = Color3.fromRGB(64, 160, 255)
    btn.BorderSizePixel = 0
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.TextColor3 = Color3.fromRGB(0, 0, 0)
    btn.Text = "Continue"
    btn.Parent = frame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn

    local done = Instance.new("BindableEvent")

    local function submit()
        local k = tostring(box.Text or "")
        k = k:gsub("^%s+", ""):gsub("%s+$", "")
        if #k >= 8 then
            env.PROJECT_LICENSE_KEY = k
            done:Fire(k)
            gui:Destroy()
        else
            title.Text = "Invalid key"
        end
    end

    btn.MouseButton1Click:Connect(submit)
    box.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            submit()
        end
    end)

    box:CaptureFocus()
    return done.Event:Wait()
end

local key = getKey()
if not key then
    key = promptForKey()
end

local url = ENDPOINT .. "?key=" .. urlEncode(key)
local payload = httpGet(url)

if type(payload) ~= "string" or #payload < 8 then
    error("Failed to download payload (empty response)")
end

local fn, err = loadstring(payload)
if not fn then
    error("Payload compile error: " .. tostring(err))
end

return fn()
