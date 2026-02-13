local ENDPOINT = "https://titanium-staff.test5555543.workers.dev"
local LICENSING_ENDPOINT = "https://titanium-licensing.test5555543.workers.dev"
local LOADER_VERSION = "1.2-UserAnchor"

-- Diagnostic logging for HWID vs UserId stability analysis
local function logDiagnostics()
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    
    local success, UserId = pcall(function() return LocalPlayer.UserId end)
    if not success then UserId = 0 end
    
    local hwid = getHWID()
    local joinCount = LocalPlayer:GetAttribute("TitaniumJoinCount") or 0
    joinCount = joinCount + 1
    LocalPlayer:SetAttribute("TitaniumJoinCount", joinCount)
    
    print("[TITANIUM DIAG] ===== Join #" .. tostring(joinCount) .. " =====")
    print("[TITANIUM DIAG] UserId (Persistent): " .. tostring(UserId))
    print("[TITANIUM DIAG] HWID (Session): " .. hwid:sub(1, 20) .. "...")
    print("[TITANIUM DIAG] Anchor Key: " .. tostring(UserId) .. "_" .. hwid:sub(1, 8))
    print("[TITANIUM DIAG] ====================")
    
    return UserId, hwid
end

-- Get UserId with fallback
local function getUserId()
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    
    local success, UserId = pcall(function() return LocalPlayer.UserId end)
    if success and UserId then
        return tostring(UserId)
    end
    
    -- Fallback: Try to parse from DisplayName
    success, UserId = pcall(function()
        local name = LocalPlayer.DisplayName or LocalPlayer.Name
        -- Extract numbers from name as fallback ID
        local nums = name:gsub("%D", "")
        if #nums > 0 then
            return nums
        end
        return "0"
    end)
    
    if success and UserId then
        return tostring(UserId)
    end
    
    return "0"
end

-- Get HWID (Hardware ID) - uses Roblox's analytics service for stable ID
local function getHWID()
    local success, hwid = pcall(function()
        local AnalyticsService = game:GetService("RbxAnalyticsService")
        if AnalyticsService then
            return AnalyticsService:GetClientId()
        end
        return nil
    end)
    
    if success and hwid then
        return tostring(hwid)
    end
    
    -- Fallback: Use UserId + PlaceId combo (more stable than random)
    local Players = game:GetService("Players")
    if Players and Players.LocalPlayer then
        return tostring(Players.LocalPlayer.UserId) .. "_" .. tostring(game.PlaceId)
    end
    
    return "unknown"
end

-- Get hybrid anchor key (UserId primary + HWID salt)
local function getAnchorKey()
    local userId = getUserId()
    local hwid = getHWID()
    -- Use UserId as primary, first 8 chars of HWID as salt for uniqueness
    return userId .. "_" .. hwid:sub(1, 8), userId, hwid
end

-- Setup persistent client-side cache
local function setupCache()
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    
    local cacheFolder = LocalPlayer:FindFirstChild("TitaniumCache")
    if not cacheFolder then
        cacheFolder = Instance.new("Folder")
        cacheFolder.Name = "TitaniumCache"
        cacheFolder.Parent = LocalPlayer
    end
    
    -- Activated status
    local activatedVal = cacheFolder:FindFirstChild("Activated")
    if not activatedVal then
        activatedVal = Instance.new("BoolValue")
        activatedVal.Name = "Activated"
        activatedVal.Value = false
        activatedVal.Parent = cacheFolder
    end
    
    -- Last validation timestamp
    local lastValidated = cacheFolder:FindFirstChild("LastValidated")
    if not lastValidated then
        lastValidated = Instance.new("NumberValue")
        lastValidated.Name = "LastValidated"
        lastValidated.Value = 0
        lastValidated.Parent = cacheFolder
    end
    
    -- Fail count for anti-abuse
    local failCount = cacheFolder:FindFirstChild("FailCount")
    if not failCount then
        failCount = Instance.new("IntValue")
        failCount.Name = "FailCount"
        failCount.Value = 0
        failCount.Parent = cacheFolder
    end
    
    -- Stored key for verification
    local storedKey = cacheFolder:FindFirstChild("StoredKey")
    if not storedKey then
        storedKey = Instance.new("StringValue")
        storedKey.Name = "StoredKey"
        storedKey.Value = ""
        storedKey.Parent = cacheFolder
    end
    
    return {
        activated = activatedVal,
        lastValidated = lastValidated,
        failCount = failCount,
        storedKey = storedKey,
        folder = cacheFolder
    }
end

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
    end

    if game and game.HttpGet then
        local ok, res = pcall(function()
            return game:HttpGet(url)
        end)
        if ok and type(res) == "string" then
            return res, "game:HttpGet"
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

local function httpPost(url, bodyTable)
    local body = game:GetService("HttpService"):JSONEncode(bodyTable)
    
    local success, result = pcall(function()
        if syn and syn.request then
            return syn.request({
                Url = url,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["User-Agent"] = "Mozilla/5.0"
                },
                Body = body
            })
        elseif request then
            return request({
                Url = url,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                    ["User-Agent"] = "Mozilla/5.0"
                },
                Body = body
            })
        end
        return nil
    end)
    
    if success and result then
        return result.Body or result.body, result.StatusCode or 200
    end
    
    return nil, "post_failed"
end

local function urlEncode(s)
    s = tostring(s)
    s = s:gsub("\n", "\r\n")
    s = s:gsub("([^%w ])", function(c)
        return string.format("%%%02X", string.byte(c))
    end)
    return s:gsub(" ", "+")
end

print("[TITANIUM] Loader initialized")
print("[TITANIUM] HWID: " .. getHWID():sub(1, 20) .. "...")

-- Key Entry and Validation (with HWID/IP locking)
local function validateKey()
    local env = (getgenv and getgenv()) or _G
    
    local Players = game:GetService("Players")
    local CoreGui = game:GetService("CoreGui")
    local TweenService = game:GetService("TweenService")
    local RunService = game:GetService("RunService")

    local parent = CoreGui
    pcall(function()
        if gethui then parent = gethui()
        elseif get_hidden_ui then parent = get_hidden_ui() end
    end)

    local gui = Instance.new("ScreenGui")
    gui.Name = "TitaniumKeyPrompt"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.DisplayOrder = 1000000
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(gui)
        elseif protectgui then protectgui(gui) end
    end)

    gui.Parent = parent

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 440, 0, 320)
    frame.Position = UDim2.new(0.5, -220, 0.5, -160)
    frame.BackgroundColor3 = Color3.fromRGB(16, 17, 22)
    frame.BorderSizePixel = 0
    frame.ZIndex = 100
    frame.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 16)
    corner.Parent = frame

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(40, 40, 50)
    stroke.Thickness = 2
    stroke.Parent = frame

    -- Title
    local titleIcon = Instance.new("TextLabel")
    titleIcon.Text = "*"
    titleIcon.Size = UDim2.new(0, 40, 0, 40)
    titleIcon.Position = UDim2.new(0, 30, 0, 25)
    titleIcon.BackgroundTransparency = 1
    titleIcon.TextColor3 = Color3.fromRGB(139, 92, 246)
    titleIcon.Font = Enum.Font.GothamBold
    titleIcon.TextSize = 32
    titleIcon.Parent = frame

    local title = Instance.new("TextLabel")
    title.Text = "TITANIUM"
    title.Size = UDim2.new(1, -80, 0, 30)
    title.Position = UDim2.new(0, 70, 0, 25)
    title.BackgroundTransparency = 1
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBlack
    title.TextSize = 24
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = frame

    local subtitle = Instance.new("TextLabel")
    subtitle.Text = "Enter license key (HWID/IP locked to first device)"
    subtitle.Size = UDim2.new(1, -60, 0, 20)
    subtitle.Position = UDim2.new(0, 30, 0, 65)
    subtitle.BackgroundTransparency = 1
    subtitle.TextColor3 = Color3.fromRGB(140, 145, 160)
    subtitle.Font = Enum.Font.Gotham
    subtitle.TextSize = 12
    subtitle.TextXAlignment = Enum.TextXAlignment.Left
    subtitle.Parent = frame

    -- Key input
    local inputContainer = Instance.new("Frame")
    inputContainer.Size = UDim2.new(1, -60, 0, 56)
    inputContainer.Position = UDim2.new(0, 30, 0, 100)
    inputContainer.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
    inputContainer.BorderSizePixel = 0
    inputContainer.ZIndex = 101
    inputContainer.Parent = frame

    local inputCorner = Instance.new("UICorner")
    inputCorner.CornerRadius = UDim.new(0, 12)
    inputCorner.Parent = inputContainer

    local inputStroke = Instance.new("UIStroke")
    inputStroke.Color = Color3.fromRGB(55, 60, 75)
    inputStroke.Thickness = 1.5
    inputStroke.Parent = inputContainer

    local keyIcon = Instance.new("TextLabel")
    keyIcon.Text = "Key:"
    keyIcon.Size = UDim2.new(0, 50, 1, 0)
    keyIcon.Position = UDim2.new(0, 16, 0, 0)
    keyIcon.BackgroundTransparency = 1
    keyIcon.TextColor3 = Color3.fromRGB(139, 92, 246)
    keyIcon.Font = Enum.Font.GothamBold
    keyIcon.TextSize = 12
    keyIcon.ZIndex = 102
    keyIcon.Parent = inputContainer

    local keyBox = Instance.new("TextBox")
    keyBox.PlaceholderText = "TIT-XXX-XXXX-XXXX"
    keyBox.PlaceholderColor3 = Color3.fromRGB(80, 85, 100)
    keyBox.Text = ""
    keyBox.Size = UDim2.new(1, -70, 1, 0)
    keyBox.Position = UDim2.new(0, 60, 0, 0)
    keyBox.BackgroundTransparency = 1
    keyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    keyBox.Font = Enum.Font.GothamMedium
    keyBox.TextSize = 14
    keyBox.TextXAlignment = Enum.TextXAlignment.Left
    keyBox.ClearTextOnFocus = false
    keyBox.ZIndex = 102
    keyBox.Parent = inputContainer

    -- Status
    local statusLabel = Instance.new("TextLabel")
    statusLabel.Text = ""
    statusLabel.Size = UDim2.new(1, -60, 0, 40)
    statusLabel.Position = UDim2.new(0, 30, 0, 165)
    statusLabel.BackgroundTransparency = 1
    statusLabel.TextColor3 = Color3.fromRGB(255, 120, 120)
    statusLabel.Font = Enum.Font.Gotham
    statusLabel.TextSize = 11
    statusLabel.TextWrapped = true
    statusLabel.TextXAlignment = Enum.TextXAlignment.Left
    statusLabel.ZIndex = 101
    statusLabel.Parent = frame

    -- Submit button
    local submitBtn = Instance.new("TextButton")
    submitBtn.Text = "Continue"
    submitBtn.Size = UDim2.new(1, -60, 0, 50)
    submitBtn.Position = UDim2.new(0, 30, 0, 220)
    submitBtn.BackgroundColor3 = Color3.fromRGB(139, 92, 246)
    submitBtn.BorderSizePixel = 0
    submitBtn.Font = Enum.Font.GothamBold
    submitBtn.TextSize = 14
    submitBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    submitBtn.AutoButtonColor = false
    submitBtn.ZIndex = 101
    submitBtn.Parent = frame

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 12)
    btnCorner.Parent = submitBtn

    -- Footer
    local footer = Instance.new("TextLabel")
    footer.Text = "UserId: " .. getUserId() .. " | Anchor: " .. getAnchorKey():sub(1, 16) .. "..."
    footer.Size = UDim2.new(1, -60, 0, 14)
    footer.Position = UDim2.new(0, 30, 1, -30)
    footer.BackgroundTransparency = 1
    footer.TextColor3 = Color3.fromRGB(80, 85, 100)
    footer.Font = Enum.Font.Gotham
    footer.TextSize = 9
    footer.ZIndex = 101
    footer.Parent = frame

    -- Focus animations
    keyBox.Focused:Connect(function()
        TweenService:Create(inputStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(139, 92, 246)}):Play()
    end)
    keyBox.FocusLost:Connect(function()
        TweenService:Create(inputStroke, TweenInfo.new(0.2), {Color = Color3.fromRGB(55, 60, 75)}):Play()
    end)

    -- Done event
    local done = Instance.new("BindableEvent")

    local function submit()
        local k = tostring(keyBox.Text):gsub("^%s+", ""):gsub("%s+$", "")
        
        if #k < 8 then
            statusLabel.Text = "Please enter a valid key"
            return
        end

        submitBtn.Text = "Validating..."
        submitBtn.Active = false
        
        -- Get UserId-based anchor key
        local anchorKey, userId, hwid = getAnchorKey()
        local cache = setupCache()
        
        -- Log diagnostics
        logDiagnostics()
        
        -- Check cache first (1 hour TTL)
        local now = tick()
        local cacheAge = now - cache.lastValidated.Value
        
        if cache.activated.Value and cache.storedKey.Value == k and cacheAge < 3600 then
            -- Cache hit - skip external validation
            print("[TITANIUM] Cache valid - UserId " .. userId .. " proceeding")
            submitBtn.Text = "Key valid! (cached)"
            env.PROJECT_LICENSE_KEY = k
            env._TITANIUM_USERID = userId
            env._TITANIUM_HWID = hwid
            env._TITANIUM_ANCHOR = anchorKey
            done:Fire(k, false)
            gui.Enabled = false
            gui:ClearAllChildren()
            return
        end
        
        -- Throttle check (1 min between external validations)
        if cacheAge < 60 then
            warn("[TITANIUM] Validation throttled - using cache if available")
            if cache.activated.Value then
                submitBtn.Text = "Key valid! (throttled)"
                env.PROJECT_LICENSE_KEY = k
                env._TITANIUM_USERID = userId
                env._TITANIUM_HWID = hwid
                env._TITANIUM_ANCHOR = anchorKey
                done:Fire(k, false)
                gui.Enabled = false
                gui:ClearAllChildren()
                return
            end
        end
        
        -- Validate with server using UserId-based anchor
        local validateBody = {
            key = k,
            hwid = anchorKey,  -- Send hybrid anchor key (UserId_HWID-salt)
            userId = userId     -- Explicit UserId for server tracking
        }
        
        local validateRes = httpPost(ENDPOINT .. "/api/keys/validate", validateBody)
        
        if validateRes then
            local success, result = pcall(function()
                return game:GetService("HttpService"):JSONDecode(validateRes)
            end)
            
            if success and result then
                if result.valid then
                    if result.key and result.key.hwidSet then
                        -- Already activated - update cache
                        submitBtn.Text = "Key valid!"
                        cache.activated.Value = true
                        cache.lastValidated.Value = now
                        cache.storedKey.Value = k
                        cache.failCount.Value = 0
                        
                        env.PROJECT_LICENSE_KEY = k
                        env._TITANIUM_USERID = userId
                        env._TITANIUM_HWID = hwid
                        env._TITANIUM_ANCHOR = anchorKey
                        
                        print("[TITANIUM] UserId " .. userId .. " validated and cached")
                        done:Fire(k, false)
                        gui.Enabled = false
                        gui:ClearAllChildren()
                    else
                        -- First activation
                        submitBtn.Text = "Activating..."
                        
                        local activateBody = {
                            key = k,
                            hwid = anchorKey,
                            userId = userId,
                            username = nil
                        }
                        
                        local activateRes = httpPost(ENDPOINT .. "/api/keys/activate", activateBody)
                        
                        if activateRes then
                            local actSuccess, actResult = pcall(function()
                                return game:GetService("HttpService"):JSONDecode(activateRes)
                            end)
                            
                            if actSuccess and actResult and actResult.success then
                                submitBtn.Text = "Activated!"
                                cache.activated.Value = true
                                cache.lastValidated.Value = now
                                cache.storedKey.Value = k
                                cache.failCount.Value = 0
                                
                                env.PROJECT_LICENSE_KEY = k
                                env._TITANIUM_USERID = userId
                                env._TITANIUM_HWID = hwid
                                env._TITANIUM_ANCHOR = anchorKey
                                
                                print("[TITANIUM] UserId " .. userId .. " activated and cached")
                                done:Fire(k, true)
                                gui.Enabled = false
                                gui:ClearAllChildren()
                            else
                                -- Activation failed - increment fail count
                                cache.failCount.Value = cache.failCount.Value + 1
                                if cache.failCount.Value >= 3 then
                                    statusLabel.Text = "Too many failures - wait before retry"
                                else
                                    statusLabel.Text = "Activation failed: " .. (actResult and actResult.error or "Unknown")
                                end
                                submitBtn.Text = "Continue"
                                submitBtn.Active = true
                            end
                        else
                            submitBtn.Text = "Continue"
                            submitBtn.Active = true
                            statusLabel.Text = "Network error during activation"
                        end
                    end
                else
                    -- Validation failed - increment fail count
                    cache.failCount.Value = cache.failCount.Value + 1
                    if cache.failCount.Value >= 3 then
                        statusLabel.Text = "Too many failures - try another key"
                    else
                        statusLabel.Text = result.error or "Invalid key"
                    end
                    submitBtn.Text = "Continue"
                    submitBtn.Active = true
                    
                    if result.locked then
                        print("[TITANIUM] UserId/Anchor Lock Error:")
                        print("[TITANIUM] Your UserId: " .. tostring(userId))
                        print("[TITANIUM] Your Anchor: " .. tostring(anchorKey))
                        print("[TITANIUM] Error: " .. tostring(result.error))
                    end
                end
            else
                submitBtn.Text = "Continue"
                submitBtn.Active = true
                statusLabel.Text = "Validation error"
            end
        else
            submitBtn.Text = "Continue"
            submitBtn.Active = true
            statusLabel.Text = "Network error - check connection"
        end
    end

    submitBtn.MouseButton1Click:Connect(submit)
    keyBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then submit() end
    end)

    keyBox:CaptureFocus()

    return done.Event:Wait()
end

-- Fetch payload with validation
local function fetchPayload(key)
    local cb = tostring(os.time()) .. tostring(math.random(1000, 9999))
    local url = LICENSING_ENDPOINT .. "/v1/payload?key=" .. urlEncode(key) .. "&cb=" .. cb
    local body, info = httpGet(url)
    
    -- Debug logging
    if type(body) == "string" then
        print("[TITANIUM DEBUG] Payload URL: " .. tostring(url))
        print("[TITANIUM DEBUG] Payload first 100 chars: " .. body:sub(1, 100))
        print("[TITANIUM DEBUG] Payload length: " .. tostring(#body))
        print("[TITANIUM DEBUG] HTTP info: " .. tostring(info))
        
        -- Check if it's HTML
        if body:match("^%s*<") then
            print("[TITANIUM DEBUG] WARNING: Payload appears to be HTML, not Lua!")
            print("[TITANIUM DEBUG] Full payload: " .. body:sub(1, 500))
            return nil, "html_response", url
        end
        
        -- Check if it looks like Lua
        if not body:match("^[%s%a%d_]") and not body:match("^%-%-") then
            print("[TITANIUM DEBUG] WARNING: Payload doesn't look like valid Lua code")
            return nil, "invalid_lua", url
        end
    end
    
    return body, info, url
end

-- Validate payload is valid Lua without executing
local function validatePayload(payload)
    if type(payload) ~= "string" then
        print("[TITANIUM DEBUG] Payload is not a string, type: " .. type(payload))
        return false, "payload is not a string"
    end
    
    -- Detailed debug logging
    print("[TITANIUM DEBUG PAYLOAD] Length: " .. tostring(#payload))
    print("[TITANIUM DEBUG PAYLOAD] First 100 chars: " .. payload:sub(1, 100))
    print("[TITANIUM DEBUG PAYLOAD] Last 50 chars: " .. payload:sub(-50))
    
    -- Trim whitespace
    payload = payload:gsub("^%s+", ""):gsub("%s+$", "")
    
    if #payload < 8 then
        print("[TITANIUM DEBUG] Payload too short: " .. tostring(#payload) .. " bytes")
        return false, "payload too short (" .. tostring(#payload) .. " bytes)"
    end
    
    -- Check for HTML/XML
    if payload:sub(1, 1) == "<" then
        print("[TITANIUM DEBUG] Payload starts with '<' - likely HTML")
        return false, "payload is HTML/XML, not Lua"
    end
    
    -- Try to compile
    local fn, err = loadstring(payload)
    if not fn then
        print("[TITANIUM DEBUG] loadstring compile error: " .. tostring(err))
        return false, "compile error: " .. tostring(err)
    end
    
    print("[TITANIUM DEBUG] Payload compiled successfully")
    return true, fn
end

-- Main flow
local function main()
    local env = (getgenv and getgenv()) or _G

    -- Step 1: Get and validate key
    print("[TITANIUM v" .. LOADER_VERSION .. "] Starting...")
    
    -- Log initial diagnostics
    logDiagnostics()
    
    local key, isFirstActivation = validateKey()
    
    if not key then
        error("Key entry cancelled")
    end
    
    print("[TITANIUM] Key validated for UserId " .. getUserId() .. ". First activation: " .. tostring(isFirstActivation))
    
    -- Step 2: Fetch payload with validation
    print("[TITANIUM] Loading payload...")
    
    local payload, info, lastUrl
    for i = 1, 3 do
        payload, info, lastUrl = fetchPayload(key)
        if type(payload) == "string" then
            -- Validate it's actual Lua code
            local isValid, result = validatePayload(payload)
            if isValid then
                print("[TITANIUM] Payload validated successfully")
                break
            else
                print("[TITANIUM DEBUG] Attempt " .. tostring(i) .. " failed: " .. tostring(result))
                payload = nil
            end
        else
            print("[TITANIUM DEBUG] Attempt " .. tostring(i) .. " returned nil: " .. tostring(info))
        end
        task.wait(0.5)
    end

    if type(payload) ~= "string" then
        error("Failed to download valid Lua payload. Last URL: " .. tostring(lastUrl) .. " | Info: " .. tostring(info))
    end

    print("[TITANIUM] Payload loaded: " .. tostring(#payload) .. " bytes")
    print("[TITANIUM DEBUG] About to validate payload...")
    
    -- Final validation before execution
    local isValid, fnOrErr = validatePayload(payload)
    if not isValid then
        print("[TITANIUM DEBUG] Final validation failed: " .. tostring(fnOrErr))
        print("[TITANIUM DEBUG] Payload preview (first 500 chars): " .. payload:sub(1, 500))
        
        -- Try to provide more detailed error info
        local testFn, testErr = loadstring(payload)
        print("[TITANIUM DEBUG] loadstring direct test - fn: " .. tostring(testFn) .. " | err: " .. tostring(testErr))
        
        error("Payload validation failed: " .. tostring(fnOrErr))
    end
    
    local fn = fnOrErr
    if type(fn) ~= "function" then
        print("[TITANIUM DEBUG] fn is not a function! Type: " .. type(fn))
        print("[TITANIUM DEBUG] fn value: " .. tostring(fn))
        error("Payload did not compile to a function, got: " .. type(fn))
    end
    
    print("[TITANIUM] Executing payload for UserId " .. getUserId() .. "...")
    print("[TITANIUM DEBUG] fn type: " .. type(fn))
    
    local execSuccess, execResult = pcall(fn)
    if not execSuccess then
        print("[TITANIUM DEBUG] Payload execution failed: " .. tostring(execResult))
        error("Payload execution failed: " .. tostring(execResult))
    end
    
    return execResult
end

-- Run
local success, result = pcall(main)

if not success then
    warn("[TITANIUM CRITICAL] Main execution failed: " .. tostring(result))
    warn("[TITANIUM] Full error details:")
    warn("  Type: " .. type(result))
    warn("  Value: " .. tostring(result))
    -- Don't re-error to prevent stack trace spam
    -- error(result)
end

return result
