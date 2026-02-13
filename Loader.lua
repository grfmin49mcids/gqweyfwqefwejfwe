
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

local key = getKey()
if not key then
    error("Missing license key. Set getgenv().PROJECT_LICENSE_KEY = 'YOUR_KEY' before running the loader.")
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
