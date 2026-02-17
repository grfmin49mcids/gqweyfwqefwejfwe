local _L="DIAG-2026-02-15A"
local _E="https://titanium-licensing.test5555543.workers.dev"
local P=game:GetService("Players")
local LP=P.LocalPlayer
local CG=game:GetService("CoreGui")
local TS=game:GetService("TweenService")

local function _H()
    local o,h=pcall(function()
        local A=game:GetService("RbxAnalyticsService")
        return A and A:GetClientId()
    end)
    if o and h then return tostring(h) end
    return tostring(LP.UserId).."_"..tostring(game.PlaceId)
end

local function _U()
    local o,u=pcall(function() return LP.UserId end)
    return o and tostring(u) or "0"
end

local function _N(s)
    s=tostring(s):gsub("\n","\r\n")
    s=s:gsub("([^%w ])",function(c) return string.format("%%%02X",string.byte(c)) end)
    return s:gsub(" ","+")
end

local function _G(url,to)
    to=to or 5000
    local r,d=nil,false
    
    task.spawn(function()
        local h={
            ["User-Agent"]="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36",
            ["Accept"]="text/plain,*/*",
            ["Cache-Control"]="no-cache, no-store, max-age=0",
            ["Pragma"]="no-cache",
            ["Expires"]="0"
        }
        
        local function t(fn)
            if type(fn)~="function" then return nil end
            local o,res=pcall(function() return fn({Url=url,Method="GET",Headers=h}) end)
            if not o then o,res=pcall(function() return fn(url) end) end
            if o then
                if type(res)=="table" then return res.Body or res.body end
                if type(res)=="string" then return res end
            end
            return nil
        end
        
        local b=t(http_request)
        if b then r=b;d=true;return end
        
        b=t((syn and syn.request) or nil)
        if b then r=b;d=true;return end
        
        b=t(request)
        if b then r=b;d=true;return end

        if game and game.HttpGetAsync then
            local o,res=pcall(function() return game:HttpGetAsync(url) end)
            if o and type(res)=="string" then r=res;d=true;return end
        end
        
        if game and game.HttpGet then
            local o,res=pcall(function() return game:HttpGet(url) end)
            if o and type(res)=="string" then r=res;d=true;return end
        end
        
        d=true
    end)
    
    local s=tick()
    while not d do
        task.wait(0.05)
        if (tick()-s)*1000>to then
            return nil,"timeout"
        end
    end
    
    return r
end

local function _V(k)
    local u=_U()
    local url=_E.."/v1/payload".."?key=".._N(k).."&hwid=".._N(u).."&userId=".._N(u).."&cb="..tostring(math.random(1000000))
    
    local b,err=_G(url,5000)
    if not b then return nil,err end

    b=tostring(b)
    b=b:gsub("\r\n","\n"):gsub("\r","\n")

    if b:sub(1,9)=="-- ERROR:" then
        return nil,b:sub(11)
    end
    
    if b:sub(1,1)=="<" then return nil,"invalid_key" end
    if b:sub(1,1)=="{" or b:sub(1,1)=="[" then return nil,"invalid_response" end
    if #b<50 then return nil,"invalid_key" end
    local fn,le=loadstring(b)
    if not fn then
        le=tostring(le or "unknown")
        le=le:gsub("^%s+",""):gsub("%s+$","")
        return nil,"invalid_payload[".._L.."]: "..le
    end
    return fn
end

local function _Lg(k,s)
    local u=_U()
    local url=_E.."/v1/log".."?key=".._N(k).."&userId=".._N(u).."&status=".._N(s).."&cb="..tostring(math.random(1000000))
    task.spawn(function()
        _G(url,3000)
    end)
end

local function _C()
    local pr=CG
    pcall(function()
        if gethui then pr=gethui()
        elseif get_hidden_ui then pr=get_hidden_ui() end
    end)
    
    local g=Instance.new("ScreenGui")
    g.Name="KeyPrompt"
    g.ResetOnSpawn=false
    g.IgnoreGuiInset=true
    g.DisplayOrder=1000000
    g.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
    
    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(g)
        elseif protectgui then protectgui(g) end
    end)
    
    g.Parent=pr
    
    local f=Instance.new("Frame")
    f.Size=UDim2.new(0,440,0,320)
    f.Position=UDim2.new(0.5,-220,0.5,-160)
    f.BackgroundColor3=Color3.fromRGB(16,17,22)
    f.BorderSizePixel=0
    f.ZIndex=100
    f.Parent=g
    
    local c=Instance.new("UICorner")
    c.CornerRadius=UDim.new(0,16)
    c.Parent=f
    
    local s=Instance.new("UIStroke")
    s.Color=Color3.fromRGB(40,40,50)
    s.Thickness=2
    s.Parent=f
    
    local ti=Instance.new("TextLabel")
    ti.Text="*"
    ti.Size=UDim2.new(0,40,0,40)
    ti.Position=UDim2.new(0,30,0,25)
    ti.BackgroundTransparency=1
    ti.TextColor3=Color3.fromRGB(139,92,246)
    ti.Font=Enum.Font.GothamBold
    ti.TextSize=32
    ti.Parent=f
    
    local t=Instance.new("TextLabel")
    t.Text="Loader (".._L..")"
    t.Size=UDim2.new(1,-80,0,30)
    t.Position=UDim2.new(0,70,0,25)
    t.BackgroundTransparency=1
    t.TextColor3=Color3.fromRGB(255,255,255)
    t.Font=Enum.Font.GothamBlack
    t.TextSize=24
    t.TextXAlignment=Enum.TextXAlignment.Left
    t.Parent=f
    
    local su=Instance.new("TextLabel")
    su.Text="Enter license key [".._L.."]"
    su.Size=UDim2.new(1,-60,0,20)
    su.Position=UDim2.new(0,30,0,65)
    su.BackgroundTransparency=1
    su.TextColor3=Color3.fromRGB(140,145,160)
    su.Font=Enum.Font.Gotham
    su.TextSize=12
    su.TextXAlignment=Enum.TextXAlignment.Left
    su.Parent=f
    
    local ic=Instance.new("Frame")
    ic.Size=UDim2.new(1,-60,0,56)
    ic.Position=UDim2.new(0,30,0,100)
    ic.BackgroundColor3=Color3.fromRGB(22,24,30)
    ic.BorderSizePixel=0
    ic.ZIndex=101
    ic.Parent=f
    
    local icc=Instance.new("UICorner")
    icc.CornerRadius=UDim.new(0,12)
    icc.Parent=ic
    
    local ics=Instance.new("UIStroke")
    ics.Color=Color3.fromRGB(55,60,75)
    ics.Thickness=1.5
    ics.Parent=ic
    
    local ki=Instance.new("TextLabel")
    ki.Text="Key:"
    ki.Size=UDim2.new(0,50,1,0)
    ki.Position=UDim2.new(0,16,0,0)
    ki.BackgroundTransparency=1
    ki.TextColor3=Color3.fromRGB(139,92,246)
    ki.Font=Enum.Font.GothamBold
    ki.TextSize=12
    ki.ZIndex=102
    ki.Parent=ic
    
    local kb=Instance.new("TextBox")
    kb.PlaceholderText="XXX-XXXX-XXXX"
    kb.PlaceholderColor3=Color3.fromRGB(80,85,100)
    kb.Text=""
    kb.Size=UDim2.new(1,-70,1,0)
    kb.Position=UDim2.new(0,60,0,0)
    kb.BackgroundTransparency=1
    kb.TextColor3=Color3.fromRGB(255,255,255)
    kb.Font=Enum.Font.GothamMedium
    kb.TextSize=14
    kb.TextXAlignment=Enum.TextXAlignment.Left
    kb.ClearTextOnFocus=false
    kb.ZIndex=102
    kb.Parent=ic
    
    local sl=Instance.new("TextLabel")
    sl.Text=""
    sl.Size=UDim2.new(1,-60,0,40)
    sl.Position=UDim2.new(0,30,0,165)
    sl.BackgroundTransparency=1
    sl.TextColor3=Color3.fromRGB(255,120,120)
    sl.Font=Enum.Font.Gotham
    sl.TextSize=11
    sl.TextWrapped=true
    sl.TextXAlignment=Enum.TextXAlignment.Left
    sl.ZIndex=101
    sl.Parent=f
    
    local sb=Instance.new("TextButton")
    sb.Text="Continue"
    sb.Size=UDim2.new(1,-60,0,50)
    sb.Position=UDim2.new(0,30,0,220)
    sb.BackgroundColor3=Color3.fromRGB(139,92,246)
    sb.BorderSizePixel=0
    sb.Font=Enum.Font.GothamBold
    sb.TextSize=14
    sb.TextColor3=Color3.fromRGB(255,255,255)
    sb.AutoButtonColor=false
    sb.ZIndex=101
    sb.Parent=f
    
    local sbc=Instance.new("UICorner")
    sbc.CornerRadius=UDim.new(0,12)
    sbc.Parent=sb
    
    local ft=Instance.new("TextLabel")
    ft.Text="UserId: ".._U()
    ft.Size=UDim2.new(1,-60,0,14)
    ft.Position=UDim2.new(0,30,1,-30)
    ft.BackgroundTransparency=1
    ft.TextColor3=Color3.fromRGB(80,85,100)
    ft.Font=Enum.Font.Gotham
    ft.TextSize=9
    ft.ZIndex=101
    ft.Parent=f
    
    kb.Focused:Connect(function()
        TS:Create(ics,TweenInfo.new(0.2),{Color=Color3.fromRGB(139,92,246)}):Play()
    end)
    kb.FocusLost:Connect(function()
        TS:Create(ics,TweenInfo.new(0.2),{Color=Color3.fromRGB(55,60,75)}):Play()
    end)
    
    return{
        Gui=g,
        KeyBox=kb,
        Status=sl,
        Button=sb,
        Destroy=function() g:Destroy() end
    }
end

local function _M()
    pcall(function()
        local g1=CG:FindFirstChild("KeyPrompt")
        if g1 then g1:Destroy() end
        local g2=CG:FindFirstChild("Fallback")
        if g2 then g2:Destroy() end
    end)
    
    local gui=_C()
    local done=Instance.new("BindableEvent")
    
    local function submit()
        local k=tostring(gui.KeyBox.Text):gsub("^%s+",""):gsub("%s+$",""):upper()
        
        if #k<8 then
            gui.Status.Text="Please enter a valid key"
            return
        end
        
        gui.Button.Text="Loading..."
        gui.Button.Active=false
        gui.Status.Text=""
        
        task.spawn(function()
            gui.Status.Text="Validating..."
            
            local fn,err=_V(k)
            if not fn then
                _Lg(k,"denied")
                gui.Button.Text="Continue"
                gui.Button.Active=true
                err=tostring(err or "invalid_key")
                err=err:gsub("^%s+",""):gsub("%s+$","")
                if err=="" then err="invalid_key" end
                if err:sub(1,13)=="invalid_payload" then
                    gui.Status.Text="Activation failed: payload update error."
                elseif err=="invalid_key" then
                    gui.Status.Text="Activation failed: invalid or disabled key."
                elseif err=="timeout" then
                    gui.Status.Text="Activation failed: network timeout."
                else
                    gui.Status.Text="Activation failed: "..err
                end
                return
            end
            
            gui.Status.Text="Success!"
            _Lg(k,"success")
            
            done:Fire(fn)
            gui.Destroy()
        end)
    end
    
    gui.Button.MouseButton1Click:Connect(submit)
    gui.KeyBox.FocusLost:Connect(function(ep)
        if ep then submit() end
    end)
    
    gui.KeyBox:CaptureFocus()
    
    local res=done.Event:Wait()
    
    if type(res)=="function" then
        local ok,err=pcall(res)
        if not ok then
            err=tostring(err or "unknown error")
        end
    end
    
    return true
end

pcall(_M)
