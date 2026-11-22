local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local StarterGui = game:GetService("StarterGui")
local Stats = game:GetService("Stats")
local PhysicsService = game:GetService("PhysicsService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local old = playerGui:FindFirstChild("KawanMenu")
if old then old:Destroy() end

--------------------------------------------------------------------
-- Configurações do painel
--------------------------------------------------------------------
local Settings = {
    anim = true,          -- animações ligadas
    speed = 1,            -- velocidade das animações
    ripple = true,        -- efeito de clique
    rainbow = false,      -- cor de destaque arco-íris
    topline = true,       -- linha animada no topo
    glow = true,          -- brilho animado no título
    toggleKey = Enum.KeyCode.RightShift,
    xmas = {snow = true, hat = true, lights = true}, -- tema de Natal
    snowCount = 90, snowSize = 1, wind = 0, snowColor = Color3.new(1, 1, 1),
}

--------------------------------------------------------------------
-- Sistema de keys (validação ONLINE no seu painel)
--------------------------------------------------------------------
local MASTER_KEY = ""                 -- (não usado: as keys agora vêm do servidor)
local MASTER_YEARS = 9999
local keyRecords = {}                 -- (vazio: a aba local de keys fica desativada)
local unlocked, isKeyAdmin, activeKey = false, false, nil
local streamer = false

-- Tudo do servidor fica dentro deste bloco para não gastar variáveis locais (limite de 200 do Lua)
local getKeyRecord
do
    local SERVER_URL = "https://kawanmenu.onrender.com"   -- URL do seu painel (sem "/" no final)
    local HttpService_ = game:GetService("HttpService")
    local keyCache = {}

    local function getHwid()
        local ok, id = pcall(function() return game:GetService("RbxAnalyticsService"):GetClientId() end)
        return ok and id or "unknown"
    end

    local function httpGet(url)
        local ok, res = pcall(function() return game:HttpGet(url) end)
        if ok and type(res) == "string" then return res end
        local req = (syn and syn.request) or (http and http.request) or http_request or request
        if req then
            local ok2, r = pcall(req, {Url = url, Method = "GET"})
            if ok2 and type(r) == "table" and r.Body then return r.Body end
        end
        return nil
    end

    -- Consulta o servidor (cache de 10s). Se o servidor cair, mantém a última resposta válida.
    getKeyRecord = function(key)
        if not key or key == "" then return nil end
        local cached = keyCache[key]
        if cached and os.clock() - cached.t < 10 then return cached.record end

        local body = httpGet(SERVER_URL .. "/api/validate?key=" .. HttpService_:UrlEncode(key) .. "&hwid=" .. HttpService_:UrlEncode(getHwid()))
        if not body then
            return cached and cached.record or nil
        end
        local ok, data = pcall(function() return HttpService_:JSONDecode(body) end)
        local record = nil
        if ok and type(data) == "table" and data.valid then
            record = {expiresAt = data.expiresAt, revoked = false, admin = data.admin == true}
            if not record.expiresAt then record.tier = "MEMBRO" end
        end
        keyCache[key] = {t = os.clock(), record = record}
        return record
    end
end
local function formatExpiry(record)
    if record.admin then return "sem validade (ADMIN)" end
    if not record.expiresAt then return "vitalícia (MEMBRO)" end
    local remaining = math.max(0, record.expiresAt - os.time())
    if remaining > 100 * 365 * 86400 then return "vitalícia" end
    return string.format("%d dias, %d h", math.floor(remaining / 86400), math.floor((remaining % 86400) / 3600))
end

local EASE_OUT = Enum.EasingStyle.Quad
local function tween(inst, time, props, style, dir)
    if not Settings.anim then
        for k, v in pairs(props) do inst[k] = v end
        return
    end
    local t = TweenService:Create(inst,
        TweenInfo.new(time / Settings.speed, style or EASE_OUT, dir or Enum.EasingDirection.Out), props)
    t:Play()
    return t
end

--------------------------------------------------------------------
-- Cores, temas e fundos
--------------------------------------------------------------------
local rgb = Color3.fromRGB
local Themes = {
    {name = "Natal Vermelho", accent = rgb(235, 64, 82)},
    {name = "Natal Verde",    accent = rgb(70, 210, 120)},
    {name = "Roxo",     accent = rgb(150, 140, 255)},
    {name = "Ciano",    accent = rgb(35, 205, 255)},
    {name = "Azul",     accent = rgb(70, 140, 255)},
    {name = "Vermelho", accent = rgb(255, 90, 105)},
    {name = "Rosa",     accent = rgb(255, 120, 200)},
    {name = "Laranja",  accent = rgb(255, 150, 60)},
    {name = "Dourado",  accent = rgb(255, 195, 70)},
    {name = "Verde",    accent = rgb(80, 235, 155)},
    {name = "Gelo",     accent = rgb(225, 235, 255)},
}
local Backgrounds = {
    {name = "Natal",      window = rgb(18, 13, 16), side = rgb(24, 17, 21), card = rgb(31, 23, 28), inset = rgb(14, 10, 12)},
    {name = "Gelo",       window = rgb(14, 26, 40), side = rgb(18, 32, 50), card = rgb(24, 43, 64), inset = rgb(11, 21, 33)},
    {name = "Preto",      window = rgb(14, 14, 18), side = rgb(17, 17, 22), card = rgb(21, 21, 27), inset = rgb(12, 12, 16)},
    {name = "Grafite",    window = rgb(24, 25, 28), side = rgb(29, 30, 34), card = rgb(35, 36, 41), inset = rgb(20, 21, 24)},
    {name = "Azul-noite", window = rgb(9, 13, 24),  side = rgb(12, 17, 31), card = rgb(16, 23, 40), inset = rgb(8, 12, 21)},
    {name = "Roxo-noite", window = rgb(16, 11, 26), side = rgb(20, 14, 32), card = rgb(26, 19, 42), inset = rgb(13, 9, 22)},
    {name = "Vinho",      window = rgb(22, 10, 14), side = rgb(27, 12, 17), card = rgb(34, 16, 22), inset = rgb(17, 8, 11)},
}

local accent = Themes[1].accent
local C = {
    window = Backgrounds[1].window, side = Backgrounds[1].side,
    card = Backgrounds[1].card, inset = Backgrounds[1].inset,
    line = rgb(40, 40, 50), text = rgb(240, 240, 245),
    muted = rgb(135, 135, 150), off = rgb(46, 46, 56),
}

local accentRefs, accentHooks, bgRefs, cornerRefs = {}, {}, {}, {}

local function track(inst, prop)
    table.insert(accentRefs, {inst = inst, prop = prop})
    inst[prop] = accent
    return inst
end
local function bg(inst, prop, key)
    table.insert(bgRefs, {inst = inst, prop = prop, key = key})
    inst[prop] = C[key]
    return inst
end
local function setAccent(color)
    accent = color
    for i = #accentRefs, 1, -1 do
        local r = accentRefs[i]
        if not r.inst.Parent then
            table.remove(accentRefs, i)
        elseif not r.inst:GetAttribute("Off") then
            r.inst[r.prop] = color
        end
    end
    for _, hook in ipairs(accentHooks) do hook() end
end
local function setBackground(preset)
    for _, k in ipairs({"window", "side", "card", "inset"}) do C[k] = preset[k] end
    for i = #bgRefs, 1, -1 do
        local r = bgRefs[i]
        if not r.inst.Parent then table.remove(bgRefs, i) else r.inst[r.prop] = C[r.key] end
    end
end

Settings.accentTween = 0
Settings.smoothAccent = function(target)
    Settings.accentTween += 1
    local id = Settings.accentTween
    if not Settings.anim then setAccent(target) return end
    local from = accent
    task.spawn(function()
        local steps = 14
        for i = 1, steps do
            if id ~= Settings.accentTween then return end
            setAccent(from:Lerp(target, i / steps))
            task.wait(0.03 / Settings.speed)
        end
    end)
end

--------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------
local function new(class, props, parent)
    local inst = Instance.new(class)
    for k, v in pairs(props or {}) do inst[k] = v end
    if parent then inst.Parent = parent end
    return inst
end
local function corner(inst, r, registry)
    local c = new("UICorner", {CornerRadius = UDim.new(0, r or 8)}, inst)
    if registry then table.insert(cornerRefs, {inst = c, offset = registry}) end
    return c
end
local function stroke(inst, color, t, tr)
    return new("UIStroke", {Color = color or C.line, Thickness = t or 1, Transparency = tr or 0,
        ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, inst)
end
local function label(parent, props)
    props.BackgroundTransparency = 1
    props.Font = props.Font or Enum.Font.GothamMedium
    props.TextColor3 = props.TextColor3 or C.text
    props.TextSize = props.TextSize or 12
    return new("TextLabel", props, parent)
end

local clickEnabled, notifyEnabled = true, true
Settings.notifyLog = {}

local gui = new("ScreenGui", {
    Name = "KawanMenu", ResetOnSpawn = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 50,
}, playerGui)

-- Controles universais de toque para funções que originalmente exigiam teclado.
local MobilePad = {}
do
    local touchOnly = UIS.TouchEnabled
    local held = {forward = false, back = false, left = false, right = false, up = false, down = false}
    local activeInputs = {}
    local pad
    local function setHeld(key, value) held[key] = value and true or false end
    function MobilePad.Down(key) return held[key] == true end
    function MobilePad.Hide()
        for key in pairs(held) do
            held[key] = false
            activeInputs[key] = nil
        end
        if pad then pad.Visible = false end
    end
    function MobilePad.Show(mode)
        if not touchOnly then return end
        if not pad then
            pad = new("Frame", {Name = "KawanTouchFlightControls", AnchorPoint = Vector2.new(1, 1),
                Position = UDim2.new(1, -16, 1, -155), Size = UDim2.fromOffset(244, 100),
                BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 100, Visible = false}, gui)
            local buttons = {
                {key = "forward", text = "▲", x = 48, y = 0},
                {key = "left", text = "◀", x = 0, y = 48},
                {key = "back", text = "▼", x = 48, y = 48},
                {key = "right", text = "▶", x = 96, y = 48},
                {key = "up", text = "+", x = 192, y = 0},
                {key = "down", text = "−", x = 192, y = 48},
            }
            for _, item in ipairs(buttons) do
                local button = new("TextButton", {Name = "Touch_" .. item.key,
                    Position = UDim2.fromOffset(item.x, item.y), Size = UDim2.fromOffset(44, 44),
                    BackgroundColor3 = Color3.fromRGB(24, 27, 36), BackgroundTransparency = 0.12,
                    Text = item.text, TextColor3 = Color3.new(1, 1, 1), TextSize = 22,
                    Font = Enum.Font.GothamBold, AutoButtonColor = true, Active = true,
                    BorderSizePixel = 0, ZIndex = 101}, pad)
                corner(button, 10)
                stroke(button, accent, 1.2, 0.15)
                button.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
                        activeInputs[item.key] = input
                        setHeld(item.key, true)
                    end
                end)
                button.InputEnded:Connect(function(input)
                    if activeInputs[item.key] == input then
                        activeInputs[item.key] = nil
                        setHeld(item.key, false)
                    end
                end)
            end
            label(pad, {Name = "TouchControlHint", Position = UDim2.fromOffset(0, -18),
                Size = UDim2.fromOffset(244, 16), Text = "MOVIMENTO • TOQUE E SEGURE",
                TextSize = 9, TextColor3 = Color3.fromRGB(235, 235, 245),
                TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 101})
        end
        pad.Visible = true
        local hint = pad:FindFirstChild("TouchControlHint")
        if hint then hint.Text = string.upper(mode or "CONTROLES") .. " • TOQUE E SEGURE" end
    end
    UIS.InputEnded:Connect(function(input)
        for key, activeInput in pairs(activeInputs) do
            if activeInput == input then
                activeInputs[key] = nil
                setHeld(key, false)
            end
        end
    end)
end

local clickSound = new("Sound", {SoundId = "rbxassetid://6895079853", Volume = 0.22}, gui)
local function playClick()
    if clickEnabled then pcall(function() clickSound:Play() end) end
end

local uiScale = new("UIScale", {Scale = 1}, gui)
local userScale = 1
local WIN_W, WIN_H, SIDE_W, TOP_H = 700, 470, 172, 46
local function refreshScale()
    local cam = workspace.CurrentCamera
    local vs = cam and cam.ViewportSize or Vector2.new(1280, 720)
    local mobile = UIS.TouchEnabled and not UIS.KeyboardEnabled
    local padX, padY = mobile and 20 or 60, mobile and 24 or 60
    uiScale.Scale = math.min(1, vs.X / (WIN_W + padX), vs.Y / (WIN_H + padY)) * userScale
end
refreshScale()
if workspace.CurrentCamera then
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshScale)
end

-- Efeito de clique (ripple)
local function ripple(btn)
    btn.ClipsDescendants = true
    btn.MouseButton1Down:Connect(function(x, y)
        if not Settings.ripple or not Settings.anim then return end
        local s = uiScale.Scale
        local px = (x - btn.AbsolutePosition.X) / s
        local py = (y - btn.AbsolutePosition.Y) / s
        local size = math.max(btn.AbsoluteSize.X, btn.AbsoluteSize.Y) / s * 2.4
        local dot = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(px, py),
            Size = UDim2.fromOffset(0, 0), BackgroundColor3 = accent, BackgroundTransparency = 0.72,
            BorderSizePixel = 0, ZIndex = 20}, btn)
        corner(dot, 999)
        tween(dot, 0.45, {Size = UDim2.fromOffset(size, size), BackgroundTransparency = 1})
        task.delay(0.5 / Settings.speed, function() dot:Destroy() end)
    end)
end

--------------------------------------------------------------------
-- Notificações (com barra de tempo)
--------------------------------------------------------------------
local toastHolder = new("Frame", {Size = UDim2.fromOffset(250, 300), Position = UDim2.new(1, -266, 1, -316),
    BackgroundTransparency = 1}, gui)
new("UIListLayout", {Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Bottom,
    SortOrder = Enum.SortOrder.LayoutOrder}, toastHolder)

local function notify(text)
    table.insert(Settings.notifyLog, 1, os.date("%H:%M:%S") .. "  " .. tostring(text))
    if #Settings.notifyLog > 20 then table.remove(Settings.notifyLog) end
    if not notifyEnabled then return end
    local toast = new("Frame", {Size = UDim2.new(1, 0, 0, 38), BackgroundColor3 = C.side,
        BackgroundTransparency = 1, BorderSizePixel = 0, ClipsDescendants = true}, toastHolder)
    corner(toast, 8)
    local st = stroke(toast, accent, 1, 1)
    local lbl = label(toast, {Size = UDim2.new(1, -20, 1, -4), Position = UDim2.fromOffset(12, 0),
        Text = text, TextTransparency = 1, TextXAlignment = Enum.TextXAlignment.Left})
    local timer = new("Frame", {Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, -2),
        BackgroundColor3 = accent, BackgroundTransparency = 1, BorderSizePixel = 0}, toast)
    tween(toast, 0.2, {BackgroundTransparency = 0.05})
    tween(st, 0.2, {Transparency = 0.4})
    tween(lbl, 0.2, {TextTransparency = 0})
    tween(timer, 0.2, {BackgroundTransparency = 0})
    if Settings.anim then
        TweenService:Create(timer, TweenInfo.new(2.6, Enum.EasingStyle.Linear), {Size = UDim2.new(0, 0, 0, 2)}):Play()
    end
    task.delay(2.6, function()
        tween(toast, 0.25, {BackgroundTransparency = 1})
        tween(st, 0.25, {Transparency = 1})
        tween(lbl, 0.25, {TextTransparency = 1})
        tween(timer, 0.25, {BackgroundTransparency = 1})
        task.wait(0.3)
        toast:Destroy()
    end)
end

--------------------------------------------------------------------
-- Janela (CanvasGroup permite fade da janela inteira)
--------------------------------------------------------------------
local baseGT = 0 -- transparência base da janela (opacidade do painel)

local main = new("CanvasGroup", {
    Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
    Size = UDim2.fromOffset(WIN_W, WIN_H), BorderSizePixel = 0, GroupTransparency = 1,
})
bg(main, "BackgroundColor3", "window")
main.Visible = false -- só aparece depois de liberar a key
main.Parent = gui
corner(main, 10, 0)
stroke(main, C.line, 1, 0.2)
local winScale = new("UIScale", {Scale = 0.94}, main)

-- Linha animada no topo
local topLine = new("Frame", {Size = UDim2.new(1, 0, 0, 2), BorderSizePixel = 0, ZIndex = 10}, main)
local topGrad = new("UIGradient", {}, topLine)
topLine.BackgroundColor3 = Color3.new(1, 1, 1)

-- Barra lateral
local sidebar = new("Frame", {Size = UDim2.new(0, SIDE_W, 1, 0), BorderSizePixel = 0}, main)
bg(sidebar, "BackgroundColor3", "side")
new("Frame", {Size = UDim2.new(0, 1, 1, 0), Position = UDim2.new(1, -1, 0, 0),
    BackgroundColor3 = C.line, BackgroundTransparency = 0.3, BorderSizePixel = 0}, sidebar)

local brand = label(sidebar, {Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 14),
    Text = "KAWAN", TextSize = 24, Font = Enum.Font.GothamBlack})
local brandGrad = new("UIGradient", {}, brand)
local menuTag = label(sidebar, {Size = UDim2.new(1, 0, 0, 14), Position = UDim2.fromOffset(0, 42),
    Text = "M E N U", TextSize = 11, Font = Enum.Font.GothamBold})
track(menuTag, "TextColor3")

-- Gradientes acompanham a cor de destaque
local function updateGradients()
    local dim = accent:Lerp(Color3.new(0, 0, 0), 0.8)
    topGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, dim),
        ColorSequenceKeypoint.new(0.5, accent),
        ColorSequenceKeypoint.new(1, dim),
    })
    brandGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
        ColorSequenceKeypoint.new(0.5, accent),
        ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
    })
end
table.insert(accentHooks, updateGradients)
updateGradients()

--------------------------------------------------------------------
-- 🎄 Tema de Natal: neve caindo, gorro de Papai Noel e luzes piscando
--------------------------------------------------------------------
do
    local XM = Settings.xmas

    -- limpa restos de execuções anteriores
    for _, n in ipairs({"KawanSnow", "KawanSnowTop"}) do
        local o = playerGui:FindFirstChild(n)
        if o then o:Destroy() end
    end

    ----------------------------------------------------------------
    -- Luzes de Natal no topo da janela
    ----------------------------------------------------------------
    local lights = new("Frame", {Name = "XmasLights", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        BorderSizePixel = 0, ZIndex = 45, Visible = XM.lights}, main)
    local bulbColors = {rgb(255, 70, 80), rgb(80, 230, 130), rgb(255, 205, 80), rgb(100, 170, 255)}
    local bulbs, N = {}, 28
    for i = 1, N do
        local x = (i - 0.5) / N * WIN_W
        local y = 1 + 3 * math.sin(math.pi * (((i - 1) % 4) + 0.5) / 4)
        local b = new("Frame", {Size = UDim2.fromOffset(5, 8), AnchorPoint = Vector2.new(0.5, 0),
            Position = UDim2.fromOffset(x, y), BackgroundColor3 = bulbColors[(i - 1) % 4 + 1],
            BorderSizePixel = 0}, lights)
        new("UICorner", {CornerRadius = UDim.new(1, 0)}, b)
        bulbs[i] = b
    end

    ----------------------------------------------------------------
    -- Gorro de Papai Noel em cima do título
    ----------------------------------------------------------------
    local RED, WHITE = rgb(215, 40, 50), rgb(250, 250, 255)
    local hat = new("Frame", {Name = "SantaHat", Size = UDim2.fromOffset(46, 34), BackgroundTransparency = 1,
        Rotation = -12, ZIndex = 46, Visible = XM.hat}, main)
    local function part(size, pos, color, rot, radius)
        local f = new("Frame", {Size = size, Position = pos, BackgroundColor3 = color, BorderSizePixel = 0,
            Rotation = rot or 0}, hat)
        new("UICorner", {CornerRadius = UDim.new(0, radius)}, f)
        return f
    end
    part(UDim2.fromOffset(28, 22), UDim2.fromOffset(5, 6), RED, 0, 12)        -- cúpula
    part(UDim2.fromOffset(22, 10), UDim2.fromOffset(22, 4), RED, 30, 5)       -- ponta caída
    part(UDim2.fromOffset(10, 10), UDim2.fromOffset(36, 9), WHITE, 0, 5)      -- pompom
    part(UDim2.fromOffset(36, 9), UDim2.fromOffset(2, 23), WHITE, 0, 5)       -- faixa

    local function placeHat()
        local w = brand.TextBounds.X
        if w <= 0 then w = 85 end
        hat.Position = UDim2.fromOffset(math.floor((SIDE_W - w) / 2) - 14, -5)
    end
    placeHat()
    brand:GetPropertyChangedSignal("TextBounds"):Connect(placeHat)

    ----------------------------------------------------------------
    -- Neve na TELA TODA (fica atrás do menu, não cai em cima dele)
    ----------------------------------------------------------------
    local snowGui = new("ScreenGui", {Name = "KawanSnow", ResetOnSpawn = false, DisplayOrder = 49,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = false}, playerGui)
    local field = new("Frame", {Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0}, snowGui)

    -- Crosta de neve em CIMA do menu (acima da borda de cima da janela)
    local topGui = new("ScreenGui", {Name = "KawanSnowTop", ResetOnSpawn = false, DisplayOrder = 51,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = false}, playerGui)
    gui.Destroying:Connect(function()
        snowGui:Destroy()
        topGui:Destroy()
    end)

    local SNOW = rgb(244, 248, 255)
    local MAX_CRUST = 13
    local crustH = 0
    local crust = new("CanvasGroup", {Name = "SnowCrust", AnchorPoint = Vector2.new(0, 1),
        Size = UDim2.fromOffset(WIN_W, 40), BackgroundTransparency = 1, BorderSizePixel = 0}, topGui)
    local crustBase = new("Frame", {AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
        Size = UDim2.new(1, 0, 0, 0), BackgroundColor3 = SNOW, BorderSizePixel = 0}, crust)
    new("UICorner", {CornerRadius = UDim.new(0, 5)}, crustBase)
    local crustBumps, BN = {}, 44
    for i = 1, BN do
        local b = new("Frame", {BackgroundColor3 = SNOW, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.new((i - 0.5) / BN, 0, 1, 0), Size = UDim2.fromOffset(0, 0)}, crust)
        new("UICorner", {CornerRadius = UDim.new(1, 0)}, b)
        crustBumps[i] = {gui = b, x = (i - 0.5) / BN, f = 0.9 + math.random() * 0.8}
    end
    local function setCrust(h)
        crustH = math.clamp(h, 0, MAX_CRUST)
        local baseH = crustH * 0.45
        crustBase.Size = UDim2.new(1, 0, 0, baseH)
        for _, bb in ipairs(crustBumps) do
            local d = crustH * bb.f
            bb.gui.Size = UDim2.fromOffset(d, d)
            bb.gui.Position = UDim2.new(bb.x, 0, 1, -baseH)
        end
    end

    local function screenSize()
        local fs = field.AbsoluteSize
        if fs.X > 0 and fs.Y > 0 then return fs.X, fs.Y end
        local cam = workspace.CurrentCamera
        local v = cam and cam.ViewportSize or Vector2.new(1280, 720)
        return v.X, v.Y
    end

    -- Quando o painel é movido, a crosta desaba em blocos de neve que caem
    local clumps = {}
    local function dropSnow(mp, ms)
        local h = crustH
        setCrust(0)
        if not Settings.anim then return end
        local count = 18
        for i = 1, count do
            local size = math.max(5, h * (0.8 + math.random()))
            local g = new("Frame", {BackgroundColor3 = SNOW, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
                Size = UDim2.fromOffset(size, size * (0.7 + math.random() * 0.5))}, topGui)
            new("UICorner", {CornerRadius = UDim.new(0, math.floor(size / 2))}, g)
            local y = mp.Y + 3 - h * 0.6
            table.insert(clumps, {
                gui = g, x = mp.X + (i - 0.5) / count * ms.X + (math.random() - 0.5) * 10, y = y, y0 = y,
                vx = (math.random() - 0.5) * 60, vy = math.random() * 40,
                rot = (math.random() - 0.5) * 260, delay = math.random() * 0.2,
            })
        end
    end
    local function clearClumps()
        for _, c in ipairs(clumps) do c.gui:Destroy() end
        table.clear(clumps)
    end
    local lastPos = main.Position
    local movedAcc, lastMove = 0, -10

    local flakes = {}
    -- lander = floco que cai sobre o menu e pousa na crosta
    local function resetFlake(f, w, h, above, mx, mw)
        local size = math.max(1, math.floor(math.random(2, 6) * Settings.snowSize + 0.5))
        f.x = math.random() * w
        f.y = above and -math.random() * h or math.random() * h
        f.speed = 16 + size * 9 + math.random(0, 14)
        f.sway = math.random(5, 16)
        f.phase = math.random() * 6.28
        f.lander = mw ~= nil and mw > 0 and f.x >= mx and f.x <= mx + mw and math.random() < 0.6
        f.gui.Size = UDim2.fromOffset(size, size)
        f.gui.BackgroundTransparency = math.clamp(0.03 + (6 - size) * 0.08, 0, 0.9)
        f.gui.BackgroundColor3 = Settings.snowColor
    end
    local w0, h0 = screenSize()
    for i = 1, 90 do
        local g = new("Frame", {BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
            AnchorPoint = Vector2.new(0.5, 0.5)}, field)
        new("UICorner", {CornerRadius = UDim.new(1, 0)}, g)
        local f = {gui = g}
        resetFlake(f, w0, h0, false)
        flakes[i] = f
    end

    -- ao abrir o painel: crosta zera e a nevasca recomeça do topo da tela
    Settings.xmasRestart = function()
        setCrust(0)
        local w, h = screenSize()
        local mp, ms = main.AbsolutePosition, main.AbsoluteSize
        for _, f in ipairs(flakes) do resetFlake(f, w, h, true, mp.X, ms.X) end
    end

    Settings.snowRefresh = function()
        local w, h = screenSize()
        for _, f in ipairs(flakes) do resetFlake(f, w, h, false) end
    end
    Settings.setBulbs = function(cols)
        for i, b in ipairs(bulbs) do b.BackgroundColor3 = cols[(i - 1) % #cols + 1] end
    end

    function Settings.xmasApply()
        lights.Visible = XM.lights
        hat.Visible = XM.hat
    end

    RunService.Heartbeat:Connect(function(dt)
        local t = os.clock()
        dt = math.min(dt, 0.1)
        local vis = main.Visible
        if vis then
            if XM.lights then
                for i, b in ipairs(bulbs) do
                    b.BackgroundTransparency = 0.45 + 0.4 * math.sin(t * 3 + i * 1.3)
                end
            end
            if XM.hat then hat.Rotation = -12 + math.sin(t * 2) * 3 end
        end

        -- detecta o painel sendo arrastado
        local cp = main.Position
        local ddx, ddy = cp.X.Offset - lastPos.X.Offset, cp.Y.Offset - lastPos.Y.Offset
        local moved = math.sqrt(ddx * ddx + ddy * ddy)
        lastPos = cp
        if moved > 0.01 then
            if t - lastMove > 0.3 then movedAcc = 0 end
            movedAcc += moved
            lastMove = t
        end

        local snowOn = vis and XM.snow
        snowGui.Enabled = snowOn
        topGui.Enabled = snowOn
        if not snowOn then
            if #clumps > 0 then clearClumps() end
            return
        end

        local mp, ms = main.AbsolutePosition, main.AbsoluteSize
        if moved > 0.01 and crustH > 1.5 and movedAcc > 4 then dropSnow(mp, ms) end
        crust.Position = UDim2.fromOffset(mp.X, mp.Y + 3)
        crust.Size = UDim2.fromOffset(ms.X, 40)
        crust.GroupTransparency = main.GroupTransparency

        -- blocos de neve caindo
        for i = #clumps, 1, -1 do
            local c = clumps[i]
            if c.delay > 0 then
                c.delay -= dt
            else
                c.vy += 1100 * dt
                c.y += c.vy * dt
                c.x += c.vx * dt
                c.gui.Rotation += c.rot * dt
                c.gui.BackgroundTransparency = math.clamp((c.y - c.y0 - 120) / 250, 0, 1)
            end
            c.gui.Position = UDim2.fromOffset(c.x, c.y)
            if c.y - c.y0 > 400 then
                c.gui:Destroy()
                table.remove(clumps, i)
            end
        end
        if not Settings.anim then return end

        -- a crosta só volta a crescer depois que o painel para de se mexer
        local still = (t - lastMove) > 0.6
        local w, h = screenSize()
        local landY = mp.Y - crustH * 0.9
        local grow = still and dt * 0.5 * Settings.speed or 0
        for fi, f in ipairs(flakes) do
            local on = fi <= Settings.snowCount
            if f.gui.Visible ~= on then f.gui.Visible = on end
            if not on then continue end
            f.y += f.speed * dt * Settings.speed
            f.x += Settings.wind * dt
            if f.x > w + 12 then f.x = -10 elseif f.x < -12 then f.x = w + 10 end
            if f.lander and f.y >= landY and f.x >= mp.X and f.x <= mp.X + ms.X then
                if still then grow += 0.2 end
                resetFlake(f, w, h, true, mp.X, ms.X)
            elseif f.y > h + 6 then
                resetFlake(f, w, h, true, mp.X, ms.X)
                f.y = -4
            end
            f.gui.Position = UDim2.fromOffset(f.x + math.sin(t * 0.8 + f.phase) * f.sway, f.y)
        end
        if grow > 0 and crustH < MAX_CRUST then setCrust(crustH + grow) end
    end)
end

local sidebarList = new("ScrollingFrame", {Size = UDim2.new(1, 0, 1, -140), Position = UDim2.fromOffset(0, 68),
    BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 0, CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y}, sidebar)
new("UIListLayout", {Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder}, sidebarList)
new("UIPadding", {PaddingLeft = UDim.new(0, 8), PaddingRight = UDim.new(0, 8)}, sidebarList)

-- Perfil
local profile = new("Frame", {Size = UDim2.new(1, 0, 0, 58), Position = UDim2.new(0, 0, 1, -58),
    BackgroundTransparency = 1}, sidebar)
new("Frame", {Size = UDim2.new(1, -24, 0, 1), Position = UDim2.fromOffset(12, 0),
    BackgroundColor3 = C.line, BackgroundTransparency = 0.4, BorderSizePixel = 0}, profile)
local avatar = new("ImageLabel", {Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(14, 14),
    BorderSizePixel = 0}, profile)
bg(avatar, "BackgroundColor3", "card")
corner(avatar, 17)
local avatarRing = stroke(avatar, accent, 1.5, 0.3)
track(avatarRing, "Color")
task.spawn(function()
    local ok, img = pcall(function()
        return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
    end)
    if ok then avatar.Image = img end
end)
local profileName = label(profile, {Size = UDim2.new(1, -60, 0, 16), Position = UDim2.fromOffset(56, 15), Text = player.DisplayName,
    TextSize = 12, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left,
    TextTruncate = Enum.TextTruncate.AtEnd})
local crown = label(profile, {Size = UDim2.fromOffset(18, 18), Position = UDim2.fromOffset(34, 4),
    Text = "👑", TextSize = 14, Visible = false, ZIndex = 3})
local statusTag = label(profile, {Size = UDim2.new(1, -60, 0, 14), Position = UDim2.fromOffset(56, 31),
    Text = "Sessão ativa", TextSize = 11, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left})
track(statusTag, "TextColor3")
local function updateProfileLicense(record)
    if record.admin then
        statusTag.Text = "👑 Dono • Vitalício"
    elseif record.tier == "MEMBRO" and not record.expiresAt then
        statusTag.Text = "♾️ Membro • Vitalício"
    elseif record.expiresAt and (record.expiresAt - os.time()) > 100 * 365 * 86400 then
        statusTag.Text = "♾️ Vitalício"
    else
        local ok, d = pcall(os.date, "%d/%m/%Y", record.expiresAt)
        statusTag.Text = ok and ("📅 Vence: " .. d) or "✅ Key ativa"
    end
end

-- Barra superior e conteúdo
local topBar = new("Frame", {Size = UDim2.new(1, -SIDE_W, 0, TOP_H), Position = UDim2.fromOffset(SIDE_W, 0),
    BackgroundTransparency = 1}, main)
new("Frame", {Size = UDim2.new(1, 0, 0, 1), Position = UDim2.new(0, 0, 1, -1),
    BackgroundColor3 = C.line, BackgroundTransparency = 0.4, BorderSizePixel = 0}, topBar)

local closeBtn = new("TextButton", {Size = UDim2.fromOffset(26, 26), Position = UDim2.new(1, -36, 0.5, -13),
    Text = "×", TextColor3 = C.muted, TextSize = 16, Font = Enum.Font.GothamBold, AutoButtonColor = false,
    BorderSizePixel = 0, ZIndex = 5}, topBar)
bg(closeBtn, "BackgroundColor3", "card")
corner(closeBtn, 6)
closeBtn.MouseEnter:Connect(function()
    tween(closeBtn, 0.12, {TextColor3 = Color3.fromRGB(255, 110, 120), Rotation = 90})
end)
closeBtn.MouseLeave:Connect(function()
    tween(closeBtn, 0.12, {TextColor3 = C.muted, Rotation = 0})
end)

local content = new("Frame", {Size = UDim2.new(1, -SIDE_W, 1, -TOP_H), Position = UDim2.fromOffset(SIDE_W, TOP_H),
    BackgroundTransparency = 1}, main)

-- Arrastar
do
    local dragging, dragStart, startPos
    local function begin(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging, dragStart, startPos = true, input.Position, main.Position
        end
    end
    topBar.InputBegan:Connect(begin)
    sidebar.InputBegan:Connect(begin)
    UIS.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local d = (input.Position - dragStart) / uiScale.Scale
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
end

--------------------------------------------------------------------
-- KAWAN • MOBILE + MINIMIZAR  (cole logo ACIMA do bloco "Páginas, sub-abas, cards")
-- Tudo fica dentro de do ... end para não gastar variáveis locais (limite de 200 do Lua)
--------------------------------------------------------------------
do
    local isMobile = UIS.TouchEnabled and not UIS.KeyboardEnabled
    local minimized = false
    local BUBBLE_PX = 52                       -- tamanho da bolha em pixels (tamanho real na tela)

    ----------------------------------------------------------------
    -- 2) Botões de topo maiores no celular + botão de minimizar
    ----------------------------------------------------------------
    local bs = isMobile and 32 or 26
    closeBtn.Size = UDim2.fromOffset(bs, bs)
    closeBtn.Position = UDim2.new(1, -(bs + 10), 0.5, -bs / 2)

    local minBtn = new("TextButton", {
        Name = "MinBtn", Size = UDim2.fromOffset(bs, bs),
        Position = UDim2.new(1, -(bs * 2 + 16), 0.5, -bs / 2),
        Text = "−", TextColor3 = C.muted, TextSize = 18, Font = Enum.Font.GothamBold,
        AutoButtonColor = false, BorderSizePixel = 0, ZIndex = 5,
    }, topBar)
    bg(minBtn, "BackgroundColor3", "card")
    corner(minBtn, 6)
    minBtn.MouseEnter:Connect(function() tween(minBtn, 0.12, {TextColor3 = accent}) end)
    minBtn.MouseLeave:Connect(function() tween(minBtn, 0.12, {TextColor3 = C.muted}) end)

    -- as abas de topo (criadas depois) não podem ficar por baixo dos botões
    local reserve = bs * 2 + 26
    topBar.ChildAdded:Connect(function(c)
        if c:IsA("Frame") and c.Size.X.Offset == -50 then
            c.Size = UDim2.new(1, -reserve, 1, 0)
        end
    end)

    ----------------------------------------------------------------
    -- 3) Bolha flutuante (abre o menu; no celular substitui a tecla RightShift)
    ----------------------------------------------------------------
    local bubble = new("TextButton", {
        Name = "KawanBubble", Position = UDim2.fromOffset(14, 120),
        Text = "K", Font = Enum.Font.GothamBlack, AutoButtonColor = false,
        BorderSizePixel = 0, Visible = false, ZIndex = 60,
    }, gui)
    bg(bubble, "BackgroundColor3", "window")
    track(bubble, "TextColor3")
    track(stroke(bubble, accent, 2, 0.1), "Color")
    new("UICorner", {CornerRadius = UDim.new(1, 0)}, bubble)

    -- mantém a bolha com o mesmo tamanho real em qualquer tela
    local function fitBubble()
        local s = math.max(uiScale.Scale, 0.05)
        local px = BUBBLE_PX / s
        bubble.Size = UDim2.fromOffset(px, px)
        bubble.TextSize = math.clamp(22 / s, 14, 80)
    end
    uiScale:GetPropertyChangedSignal("Scale"):Connect(fitBubble)
    fitBubble()

    local function clampBubble()
        local s = math.max(uiScale.Scale, 0.05)
        local vs = gui.AbsoluteSize / s
        local sz = BUBBLE_PX / s
        local p = bubble.Position
        bubble.Position = UDim2.fromOffset(
            math.clamp(p.X.Offset, 4, math.max(4, vs.X - sz - 4)),
            math.clamp(p.Y.Offset, 4, math.max(4, vs.Y - sz - 4)))
    end

    local function updateBubble()
        bubble.Visible = unlocked and not main.Visible and (minimized or isMobile)
        if bubble.Visible then clampBubble() end
    end

    ----------------------------------------------------------------
    -- 4) Minimizar / restaurar
    ----------------------------------------------------------------
    local function minimize()
        if not main.Visible or minimized then return end
        minimized = true
        playClick()
        tween(main, 0.2, {GroupTransparency = 1})
        tween(winScale, 0.2, {Scale = 0.9})
        task.delay(Settings.anim and (0.22 / Settings.speed) or 0, function()
            if minimized then main.Visible = false end
            updateBubble()
        end)
    end

    local function restore()
        if main.Visible then return end
        playClick()
        minimized = false
        main.Position = UDim2.new(0.5, 0, 0.5, 0)
        winScale.Scale = 0.94
        main.GroupTransparency = 1
        main.Visible = true
        if Settings.xmasRestart then pcall(Settings.xmasRestart) end
        tween(main, 0.25, {GroupTransparency = baseGT})
        tween(winScale, 0.25, {Scale = 1}, Enum.EasingStyle.Back)
        updateBubble()
    end

    minBtn.Activated:Connect(minimize)

    main:GetPropertyChangedSignal("Visible"):Connect(function()
        if main.Visible then minimized = false end
        updateBubble()
    end)
    updateBubble()

    ----------------------------------------------------------------
    -- 5) Bolha arrastável (arrastar move; toque curto abre o menu)
    ----------------------------------------------------------------
    local dragging, moved, startIn, startPos = false, false, nil, nil
    bubble.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging, moved = true, false
            startIn, startPos = input.Position, bubble.Position
        end
    end)
    UIS.InputChanged:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseMovement
            or input.UserInputType == Enum.UserInputType.Touch then
            local d = (input.Position - startIn) / math.max(uiScale.Scale, 0.05)
            if d.Magnitude > 6 then moved = true end
            if moved then
                bubble.Position = UDim2.fromOffset(startPos.X.Offset + d.X, startPos.Y.Offset + d.Y)
            end
        end
    end)
    UIS.InputEnded:Connect(function(input)
        if not dragging then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1
            or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
            if moved then clampBubble() else restore() end
        end
    end)
end

--------------------------------------------------------------------
-- Páginas, sub-abas, cards
--------------------------------------------------------------------
local pages, activePage = {}, nil

local function selectSub(page, sub, force)
    for _, s in ipairs(page.subs) do
        local on = (s == sub)
        if on then
            if force or not s.body.Visible then
                s.body.GroupTransparency = 1
                s.body.Position = UDim2.fromOffset(0, 16)
                s.body.Visible = true
                tween(s.body, 0.26, {GroupTransparency = 0, Position = UDim2.fromOffset(0, 0)})
            end
        else
            s.body.Visible = false
        end
        s.indicator.Visible = on
        tween(s.button, 0.15, {TextColor3 = on and C.text or C.muted})
    end
    page.activeSub = sub
end

local function selectPage(page)
    if activePage == page then return end
    for _, p in ipairs(pages) do
        local on = (p == page)
        p.bar.Visible = on
        p.body.Visible = on
        tween(p.item, 0.18, {BackgroundTransparency = on and 0.88 or 1})
        tween(p.text, 0.18, {TextColor3 = on and C.text or C.muted})
        tween(p.icon, 0.18, {TextColor3 = on and accent or C.muted, TextTransparency = on and 0 or 0.4})
        tween(p.indicator, 0.22, {Size = UDim2.new(0, 2, 0, on and 16 or 0)}, Enum.EasingStyle.Back)
    end
    activePage = page
    selectSub(page, page.activeSub or page.subs[1], true)
end
table.insert(accentHooks, function()
    if activePage then activePage.icon.TextColor3 = accent end
end)

-- Keybinds individuais para todos os toggles do painel.
local keybindEntries = {}
local waitingForKeybind = nil

local function newCategory(name)
    local l = label(sidebarList, {Size = UDim2.new(1, 0, 0, 24), Text = "  " .. name, TextColor3 = C.muted,
        TextSize = 11, TextXAlignment = Enum.TextXAlignment.Left})
    return l
end

local function newPage(name, icon)
    local item = new("TextButton", {Size = UDim2.new(1, 0, 0, 32), BackgroundTransparency = 1, Text = "",
        AutoButtonColor = false, BorderSizePixel = 0}, sidebarList)
    track(item, "BackgroundColor3")
    corner(item, 6)
    ripple(item)
    local ind = new("Frame", {Size = UDim2.new(0, 2, 0, 0), Position = UDim2.new(0, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5), BorderSizePixel = 0}, item)
    track(ind, "BackgroundColor3")
    local ic = label(item, {Size = UDim2.fromOffset(20, 32), Position = UDim2.fromOffset(10, 0), Text = icon,
        TextColor3 = C.muted, TextSize = 14, Font = Enum.Font.GothamBold})
    local tx = label(item, {Size = UDim2.new(1, -40, 1, 0), Position = UDim2.fromOffset(36, 0), Text = name,
        TextColor3 = C.muted, TextSize = 13, TextXAlignment = Enum.TextXAlignment.Left})

    local bar = new("Frame", {Size = UDim2.new(1, -50, 1, 0), BackgroundTransparency = 1, Visible = false}, topBar)
    new("UIListLayout", {FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8),
        VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder}, bar)
    new("UIPadding", {PaddingLeft = UDim.new(0, 14)}, bar)
    local body = new("Frame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1, Visible = false,
        ClipsDescendants = true}, content)

    local page = {item = item, text = tx, icon = ic, indicator = ind, bar = bar, body = body, subs = {}}
    table.insert(pages, page)
    item.Activated:Connect(function() playClick() selectPage(page) end)
    item.MouseEnter:Connect(function()
        tween(ic, 0.15, {Position = UDim2.fromOffset(14, 0)})
        if activePage ~= page then
            tween(item, 0.12, {BackgroundTransparency = 0.94})
            tween(tx, 0.12, {TextColor3 = C.text})
        end
    end)
    item.MouseLeave:Connect(function()
        tween(ic, 0.15, {Position = UDim2.fromOffset(10, 0)})
        if activePage ~= page then
            tween(item, 0.12, {BackgroundTransparency = 1})
            tween(tx, 0.12, {TextColor3 = C.muted})
        end
    end)

    function page:SubTab(subName)
        local btn = new("TextButton", {Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X,
            BackgroundTransparency = 1, Text = subName, TextColor3 = C.muted, TextSize = 12,
            Font = Enum.Font.GothamMedium, AutoButtonColor = false, BorderSizePixel = 0}, bar)
        new("UIPadding", {PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 8)}, btn)
        local sind = new("Frame", {Size = UDim2.new(0, 2, 0, 14), Position = UDim2.new(0, 0, 0.5, -7),
            BorderSizePixel = 0, Visible = false}, btn)
        track(sind, "BackgroundColor3")
        btn.MouseEnter:Connect(function()
            if page.activeSub and page.activeSub.button ~= btn then tween(btn, 0.12, {TextColor3 = C.text}) end
        end)
        btn.MouseLeave:Connect(function()
            if page.activeSub and page.activeSub.button ~= btn then tween(btn, 0.12, {TextColor3 = C.muted}) end
        end)

        local wrap = new("CanvasGroup", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
            Visible = false}, body)
        local scroll = new("ScrollingFrame", {Size = UDim2.new(1, 0, 1, 0), BackgroundTransparency = 1,
            BorderSizePixel = 0, ScrollBarThickness = 3, CanvasSize = UDim2.new(),
            AutomaticCanvasSize = Enum.AutomaticSize.Y}, wrap)
        track(scroll, "ScrollBarImageColor3")
        new("UIPadding", {PaddingTop = UDim.new(0, 12), PaddingLeft = UDim.new(0, 14),
            PaddingRight = UDim.new(0, 14), PaddingBottom = UDim.new(0, 14)}, scroll)

        local cols = {}
        for i = 1, 2 do
            local col = new("Frame", {Size = UDim2.new(0.5, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                Position = UDim2.new(i == 1 and 0 or 0.5, i == 1 and 0 or 6, 0, 0), BackgroundTransparency = 1}, scroll)
            new("UIListLayout", {Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder}, col)
            cols[i] = col
        end

        local sub = {button = btn, body = wrap, indicator = sind}
        table.insert(self.subs, sub)
        btn.Activated:Connect(function()
            if page.activeSub == sub then return end
            playClick()
            selectSub(page, sub, true)
        end)

        local nextCol = 1
        function sub:Card(title, icon, colIndex)
            local col = cols[colIndex or nextCol]
            nextCol = nextCol % 2 + 1
            local card = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                BorderSizePixel = 0}, col)
            bg(card, "BackgroundColor3", "card")
            corner(card, 8, -2)
            local cardStroke = stroke(card, C.line, 1, 0.55)
            new("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder}, card)
            new("UIPadding", {PaddingBottom = UDim.new(0, 6)}, card)
            card.MouseEnter:Connect(function()
                tween(cardStroke, 0.18, {Color = accent, Transparency = 0.3})
            end)
            card.MouseLeave:Connect(function()
                tween(cardStroke, 0.18, {Color = C.line, Transparency = 0.55})
            end)

            local head = new("Frame", {Size = UDim2.new(1, 0, 0, 36), BackgroundTransparency = 1}, card)
            local hic = label(head, {Size = UDim2.fromOffset(20, 36), Position = UDim2.fromOffset(12, 0),
                Text = icon or "◆", TextSize = 13, Font = Enum.Font.GothamBold})
            track(hic, "TextColor3")
            label(head, {Size = UDim2.new(1, -44, 1, 0), Position = UDim2.fromOffset(34, 0), Text = title,
                TextSize = 13, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left})

            local function row(h)
                local r = new("Frame", {Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = Color3.new(1, 1, 1),
                    BackgroundTransparency = 1, BorderSizePixel = 0}, card)
                r.MouseEnter:Connect(function() tween(r, 0.1, {BackgroundTransparency = 0.96}) end)
                r.MouseLeave:Connect(function() tween(r, 0.1, {BackgroundTransparency = 1}) end)
                return r
            end

            local api = {}

            function api:Toggle(text, default, callback)
                local r = row(32)
                label(r, {Size = UDim2.new(1, -116, 1, 0), Position = UDim2.fromOffset(12, 0), Text = text,
                    TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd})
                local keyBtn = new("TextButton", {Size = UDim2.fromOffset(38, 20), Position = UDim2.new(1, -91, 0.5, -10),
                    BackgroundColor3 = C.inset, Text = "—", TextColor3 = C.text, TextSize = 10,
                    Font = Enum.Font.GothamBold, AutoButtonColor = false, BorderSizePixel = 0}, r)
                corner(keyBtn, 5)
                stroke(keyBtn, accent, 1, 0.25)
                local pill = new("TextButton", {Size = UDim2.fromOffset(34, 18), Position = UDim2.new(1, -46, 0.5, -9),
                    Text = "", AutoButtonColor = false, BorderSizePixel = 0}, r)
                corner(pill, 9)
                local knob = new("Frame", {Size = UDim2.fromOffset(12, 12), BackgroundColor3 = C.text,
                    BorderSizePixel = 0}, pill)
                corner(knob, 6)
                table.insert(accentRefs, {inst = pill, prop = "BackgroundColor3"})
                local state = default and true or false
                local function render(animate)
                    pill:SetAttribute("Off", not state)
                    local col = state and accent or C.off
                    local pos = state and UDim2.new(1, -15, 0.5, -6) or UDim2.new(0, 3, 0.5, -6)
                    if animate then
                        tween(pill, 0.18, {BackgroundColor3 = col})
                        tween(knob, 0.22, {Position = pos}, Enum.EasingStyle.Back)
                    else
                        pill.BackgroundColor3 = col
                        knob.Position = pos
                    end
                end
                render(false)
                local function set(v, silent)
                    state = v and true or false
                    render(true)
                    if not silent and callback then task.spawn(callback, state) end
                end
                local keyEntry = {key = nil, button = keyBtn, getState = function() return state end,
                    setState = function(v) set(v, false) end, label = text}
                table.insert(keybindEntries, keyEntry)
                keyBtn.Activated:Connect(function()
                    playClick()
                    if UIS.TouchEnabled and not UIS.KeyboardEnabled then
                        notify("Atalho de teclado disponível somente no PC; use o botão da função")
                        return
                    end
                    waitingForKeybind = keyEntry
                    keyBtn.Text = "..."
                    notify("Pressione a tecla desejada • Backspace remove • Esc cancela")
                end)
                pill.Activated:Connect(function() playClick() set(not state) end)
                pill.MouseButton1Down:Connect(function() tween(knob, 0.08, {Size = UDim2.fromOffset(16, 12)}) end)
                pill.MouseButton1Up:Connect(function() tween(knob, 0.12, {Size = UDim2.fromOffset(12, 12)}) end)
                if state then task.spawn(callback, state) end
                return {Set = function(_, v) set(v, true) end}
            end

            function api:Slider(text, min, max, default, callback)
                local r = row(54)
                local value = default
                local step = math.max(1, math.floor((max - min) / 50))

                local function stepBtn(txt, x)
                    local b = new("TextButton", {Size = UDim2.fromOffset(18, 18), Position = x,
                        BackgroundTransparency = 1, Text = txt, TextColor3 = C.muted, TextSize = 15,
                        Font = Enum.Font.GothamBold, AutoButtonColor = false}, r)
                    b.MouseEnter:Connect(function() tween(b, 0.1, {TextColor3 = accent}) end)
                    b.MouseLeave:Connect(function() tween(b, 0.1, {TextColor3 = C.muted}) end)
                    return b
                end
                local minus = stepBtn("−", UDim2.fromOffset(10, 8))
                label(r, {Size = UDim2.new(1, -110, 0, 18), Position = UDim2.fromOffset(30, 8), Text = text,
                    TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd})
                local plus = stepBtn("+", UDim2.new(1, -72, 0, 8))
                local box = new("TextLabel", {Size = UDim2.fromOffset(40, 18), Position = UDim2.new(1, -52, 0, 8),
                    TextColor3 = C.muted, TextSize = 11, Font = Enum.Font.GothamMedium, BorderSizePixel = 0}, r)
                bg(box, "BackgroundColor3", "inset")
                corner(box, 4)
                local bar = new("Frame", {Size = UDim2.new(1, -24, 0, 5), Position = UDim2.new(0, 12, 0, 36),
                    BackgroundColor3 = C.off, BorderSizePixel = 0}, r)
                corner(bar, 3)
                local fill = new("Frame", {Size = UDim2.new(0, 0, 1, 0), BorderSizePixel = 0}, bar)
                corner(fill, 3)
                track(fill, "BackgroundColor3")
                local handle = new("Frame", {Size = UDim2.fromOffset(10, 10), AnchorPoint = Vector2.new(0.5, 0.5),
                    Position = UDim2.new(1, 0, 0.5, 0), BackgroundColor3 = C.text, BorderSizePixel = 0}, fill)
                corner(handle, 5)

                local function render(animate)
                    local size = UDim2.new((value - min) / (max - min), 0, 1, 0)
                    if animate then tween(fill, 0.1, {Size = size}) else fill.Size = size end
                    box.Text = tostring(value)
                end
                local function setValue(v)
                    v = math.clamp(math.floor(v + 0.5), min, max)
                    if v ~= value then
                        value = v
                        render(true)
                        callback(value)
                    end
                end
                render(false)
                minus.Activated:Connect(function() playClick() setValue(value - step) end)
                plus.Activated:Connect(function() playClick() setValue(value + step) end)

                local dragging = false
                local function fromX(x)
                    setValue(min + math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1) * (max - min))
                end
                local hit = new("TextButton", {Size = UDim2.new(1, -16, 0, 20), Position = UDim2.new(0, 8, 0, 29),
                    BackgroundTransparency = 1, Text = ""}, r)
                hit.InputBegan:Connect(function(input)
                    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                        dragging = true
                        tween(handle, 0.12, {Size = UDim2.fromOffset(14, 14)}, Enum.EasingStyle.Back)
                        fromX(input.Position.X)
                    end
                end)
                hit.MouseEnter:Connect(function() tween(handle, 0.12, {Size = UDim2.fromOffset(13, 13)}) end)
                hit.MouseLeave:Connect(function()
                    if not dragging then tween(handle, 0.12, {Size = UDim2.fromOffset(10, 10)}) end
                end)
                UIS.InputChanged:Connect(function(input)
                    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                        fromX(input.Position.X)
                    end
                end)
                UIS.InputEnded:Connect(function(input)
                    if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
                        dragging = false
                        tween(handle, 0.14, {Size = UDim2.fromOffset(10, 10)})
                    end
                end)
                return {Set = function(_, v)
                    value = math.clamp(math.floor(v + 0.5), min, max)
                    render(true)
                end}
            end

            function api:Dropdown(text, options, startIndex, callback)
                local r = row(58)
                label(r, {Size = UDim2.new(1, -24, 0, 18), Position = UDim2.fromOffset(12, 6), Text = text,
                    TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Left})
                local index = startIndex or 1
                local box = new("TextButton", {Size = UDim2.new(1, -24, 0, 26), Position = UDim2.fromOffset(12, 26),
                    Text = "", AutoButtonColor = false, BorderSizePixel = 0}, r)
                bg(box, "BackgroundColor3", "inset")
                corner(box, 6)
                ripple(box)
                local bs = stroke(box, C.line, 1, 0.4)
                local val = label(box, {Size = UDim2.new(1, -30, 1, 0), Position = UDim2.fromOffset(10, 0),
                    Text = options[index], TextXAlignment = Enum.TextXAlignment.Left})
                local chev = label(box, {Size = UDim2.fromOffset(20, 26), Position = UDim2.new(1, -24, 0, 0),
                    Text = "⌄", TextColor3 = C.muted, TextSize = 14, Font = Enum.Font.GothamBold})
                box.MouseEnter:Connect(function() tween(bs, 0.12, {Color = accent, Transparency = 0.2}) end)
                box.MouseLeave:Connect(function() tween(bs, 0.12, {Color = C.line, Transparency = 0.4}) end)
                box.Activated:Connect(function()
                    playClick()
                    index = index % #options + 1
                    val.Text = options[index]
                    chev.Rotation = 0
                    tween(chev, 0.25, {Rotation = 360}, Enum.EasingStyle.Back)
                    callback(options[index], index)
                end)
                return {Set = function(_, i) index = i val.Text = options[i] end}
            end

            function api:Button(text, buttonText, callback)
                local r = row(34)
                label(r, {Size = UDim2.new(1, -100, 1, 0), Position = UDim2.fromOffset(12, 0), Text = text,
                    TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd})
                local b = new("TextButton", {Size = UDim2.fromOffset(70, 22), Position = UDim2.new(1, -82, 0.5, -11),
                    Text = buttonText or "OK", TextColor3 = C.text, TextSize = 10, Font = Enum.Font.GothamBold,
                    AutoButtonColor = false, BorderSizePixel = 0}, r)
                bg(b, "BackgroundColor3", "inset")
                corner(b, 5)
                ripple(b)
                track(stroke(b, accent, 1, 0.5), "Color")
                b.MouseEnter:Connect(function() tween(b, 0.1, {BackgroundColor3 = C.off}) end)
                b.MouseLeave:Connect(function() tween(b, 0.1, {BackgroundColor3 = C.inset}) end)
                b.Activated:Connect(function() playClick() callback() end)
            end

            function api:TextBox(text, placeholder, default, callback)
                local r = row(58)
                label(r, {Size = UDim2.new(1, -24, 0, 18), Position = UDim2.fromOffset(12, 6), Text = text,
                    TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Left})
                local box = new("TextBox", {Size = UDim2.new(1, -24, 0, 26), Position = UDim2.fromOffset(12, 26),
                    Text = default or "", PlaceholderText = placeholder or "", PlaceholderColor3 = C.muted,
                    TextColor3 = C.text, TextSize = 12, Font = Enum.Font.GothamMedium, ClearTextOnFocus = false,
                    TextXAlignment = Enum.TextXAlignment.Left, BorderSizePixel = 0}, r)
                bg(box, "BackgroundColor3", "inset")
                corner(box, 6)
                new("UIPadding", {PaddingLeft = UDim.new(0, 10)}, box)
                local bs = stroke(box, C.line, 1, 0.4)
                box.Focused:Connect(function() tween(bs, 0.12, {Color = accent, Transparency = 0}) end)
                box.FocusLost:Connect(function()
                    tween(bs, 0.12, {Color = C.line, Transparency = 0.4})
                    callback(box.Text)
                end)
                return box
            end

            function api:Swatch(text)
                local r = row(32)
                label(r, {Size = UDim2.new(1, -64, 1, 0), Position = UDim2.fromOffset(12, 0), Text = text,
                    TextXAlignment = Enum.TextXAlignment.Left})
                local sw = new("Frame", {Size = UDim2.fromOffset(34, 18), Position = UDim2.new(1, -46, 0.5, -9),
                    BorderSizePixel = 0}, r)
                corner(sw, 5)
                track(sw, "BackgroundColor3")
            end

            function api:List()
                local r = new("Frame", {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                    BackgroundTransparency = 1}, card)
                local lbl = label(r, {Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                    TextColor3 = C.muted, TextSize = 11, Font = Enum.Font.Code, TextWrapped = true,
                    TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top})
                new("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
                    PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 6)}, lbl)
                return lbl
            end

            function api:Info()
                local r = row(44)
                return label(r, {Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(12, 0),
                    TextColor3 = C.muted, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left})
            end

            function api:Note(text)
                local lbl = label(card, {Size = UDim2.new(1, -24, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
                    Text = text, TextColor3 = C.muted, TextSize = 11, Font = Enum.Font.Gotham,
                    TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left})
                new("UIPadding", {PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12),
                    PaddingTop = UDim.new(0, 2), PaddingBottom = UDim.new(0, 4)}, lbl)
            end

            return api
        end
        return sub
    end
    return page
end

--------------------------------------------------------------------
-- Páginas
--------------------------------------------------------------------
local P = {}
newCategory("Geral")
P.Home = newPage("Início", "🏠")
newCategory("EXCLUSIVOS")
P.Exclusivos = newPage("EXCLUSIVOS", "⭐")
newCategory("Jogo")
P.Players = newPage("Jogadores", "👥")
P.Pvp = newPage("PvP", "⚔️")
P.Rp = newPage("Roleplay", "🎭")
newCategory("Outros")
P.Tools = newPage("Ferramentas", "🧰")
P.Hud = newPage("HUD", "📊")
P.Style = newPage("Estilo", "🎨")
P.Settings = newPage("Ajustes", "⚙️")
newCategory("Natal")
P.Xmas = newPage("Natal & Ano Novo", "🎄")

-- Início
do
    local sub = P.Home:SubTab("📋 Resumo")
    local info = sub:Card("Sessão", "👤", 1):Info()
    local start = os.clock()
    task.spawn(function()
        while info.Parent do
            local t = math.floor(os.clock() - start)
            info.Text = string.format("%s\nTempo de sessão: %02d:%02d:%02d", streamer and "••••••" or player.DisplayName,
                t // 3600, (t % 3600) // 60, t % 60)
            task.wait(1)
        end
    end)

    -- Noclip exclusivo do carro: desativa colisão apenas nas peças do veículo dirigido
    -- e restaura os valores originais ao desligar ou sair do banco.
    local carNoclipEnabled = false
    local carNoclipToggle
    local carNoclipModel, carNoclipConn, carNoclipAddedConn = nil, nil, nil
    local carCollisionSaved = {}

    -- Helper local desta seção: não depende de funções declaradas em outras abas.
    local function getCurrentDrivenCar()
        local character = player.Character
        local hum = character and character:FindFirstChildOfClass("Humanoid")
        local seat = hum and hum.SeatPart
        if not seat or not seat:IsA("VehicleSeat") or seat.Occupant ~= hum then
            return nil, nil
        end
        local model = seat:FindFirstAncestorOfClass("Model")
        if not model then return nil, nil end
        local root = seat.AssemblyRootPart or model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")
        if not root or not root:IsA("BasePart") then return nil, nil end
        return root, model
    end

    local function restoreCarCollision()
        if carNoclipConn then carNoclipConn:Disconnect(); carNoclipConn = nil end
        if carNoclipAddedConn then carNoclipAddedConn:Disconnect(); carNoclipAddedConn = nil end
        for part, oldValue in pairs(carCollisionSaved) do
            if part and part.Parent then
                pcall(function() part.CanCollide = oldValue end)
            end
        end
        table.clear(carCollisionSaved)
        carNoclipModel = nil
        carNoclipEnabled = false
    end

    local function setCarNoclip(on)
        if on == carNoclipEnabled then return end
        if not on then
            restoreCarCollision()
            notify("Noclip do carro desligado • colisões restauradas")
            return
        end

        local root, model = getCurrentDrivenCar()
        if not root or not model then
            notify("Entre no carro pelo banco do motorista primeiro")
            if carNoclipToggle then carNoclipToggle:Set(false) end
            return
        end
        local lowerName = string.lower(model.Name)
        if string.find(lowerName, "heli", 1, true) or string.find(lowerName, "helicopter", 1, true) then
            notify("Noclip do carro não se aplica ao helicóptero")
            if carNoclipToggle then carNoclipToggle:Set(false) end
            return
        end

        carNoclipEnabled = true
        carNoclipModel = model
        table.clear(carCollisionSaved)

        local function isCriticalVehiclePart(part)
            if not part or not part:IsA("BasePart") then return true end
            if part == root or part:IsA("VehicleSeat") or part:IsA("Seat") then
                return true
            end
            local n = string.lower(part.Name)
            -- Preserve wheels and suspension-related pieces so vehicle physics
            -- does not lose its support/contact geometry.
            local keepTerms = {"wheel", "tire", "tyre", "roda", "pneu",
                "suspension", "suspensao", "axle", "eixo", "spring", "mola"}
            for _, term in ipairs(keepTerms) do
                if string.find(n, term, 1, true) then
                    return true
                end
            end
            return false
        end

        local function disablePartCollision(obj)
            if obj and obj:IsA("BasePart") and not isCriticalVehiclePart(obj) then
                if carCollisionSaved[obj] == nil then
                    carCollisionSaved[obj] = obj.CanCollide
                end
                obj.CanCollide = false
            end
        end

        -- Disable only body panels/secondary parts. Keep the seat, assembly root,
        -- wheels and suspension collidable to avoid destabilizing the vehicle.
        for _, obj in ipairs(model:GetDescendants()) do
            disablePartCollision(obj)
        end

        carNoclipAddedConn = model.DescendantAdded:Connect(disablePartCollision)

        local refreshClock = 0
        carNoclipConn = RunService.Heartbeat:Connect(function(dt)
            if not carNoclipEnabled then return end
            local currentRoot, currentModel = getCurrentDrivenCar()
            if not currentRoot or currentModel ~= carNoclipModel then
                restoreCarCollision()
                if carNoclipToggle then carNoclipToggle:Set(false) end
                notify("Noclip desligado • você saiu do carro")
                return
            end

            -- Reaplica apenas nas peças da carroceria; peças críticas ficam intactas.
            refreshClock = refreshClock + dt
            if refreshClock >= 0.15 then
                refreshClock = 0
                for part in pairs(carCollisionSaved) do
                    if part and part.Parent then
                        part.CanCollide = false
                    end
                end
            end
        end)
        notify("Noclip do carro ativado")
    end

    local carNoclipCard = sub:Card("Noclip do carro", "🚗", 1)
    carNoclipToggle = carNoclipCard:Toggle("Atravessar paredes com o carro", false, setCarNoclip)
    carNoclipCard:Note("Aplica noclip na carroceria e preserva banco, rodas e suspensão para manter a física estável. Ao desligar ou sair do banco, as colisões originais são restauradas. O servidor pode limitar o efeito.")
    gui.Destroying:Connect(restoreCarCollision)

    local tips = sub:Card("Atalhos", "⌨️", 2)
    tips:Note("Abra e feche o painel com RightShift (a tecla pode ser alterada em Ajustes).")
    tips:Note("Cada toggle tem um campo de tecla ao lado: clique nele e pressione a tecla desejada.")
    tips:Note("Backspace remove um atalho, Esc cancela a edição e cada tecla só pode ser usada uma vez.")
    tips:Note("Arraste pela barra superior ou pela lateral para mover a janela.")
end



-- HUD
do
    local hud = new("TextLabel", {Name = "KawanHUD", Size = UDim2.fromOffset(170, 26), Position = UDim2.new(0, 12, 0, 12),
        BackgroundTransparency = 0.2, BorderSizePixel = 0, Visible = false, TextColor3 = C.text, TextSize = 12,
        Font = Enum.Font.GothamBold}, gui)
    bg(hud, "BackgroundColor3", "window")
    corner(hud, 8)
    track(stroke(hud, accent, 1, 0.5), "Color")

    local showFps, showPing = true, true
    local frames, elapsed = 0, 0
    RunService.RenderStepped:Connect(function(dt)
        frames += 1
        elapsed += dt
        if elapsed >= 0.5 then
            local fps = math.floor(frames / elapsed + 0.5)
            frames, elapsed = 0, 0
            if hud.Visible then
                local parts = {}
                if showFps then table.insert(parts, fps .. " FPS") end
                if showPing then
                    local ok, ping = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
                    table.insert(parts, (ok and math.floor(ping) or 0) .. " ms")
                end
                hud.Text = table.concat(parts, "  •  ")
            end
        end
    end)

    local hudSub = P.Hud:SubTab("📊 Indicadores")
    Settings.hudSub = hudSub
    local card = hudSub:Card("Na tela", "📶", 1)
    card:Toggle("Mostrar HUD", false, function(on) hud.Visible = on end)
    card:Toggle("Exibir FPS", true, function(on) showFps = on end)
    card:Toggle("Exibir ping", true, function(on) showPing = on end)
end

-- Detector: lista quem está invisível ou voando perto de você (só observa, não altera nada)
do
    local det = {on = true, invisible = true, flying = true}

    local frame = new("Frame", {Name = "Detector", Size = UDim2.fromOffset(214, 30), Position = UDim2.new(0, 12, 0, 46),
        BackgroundTransparency = 0.2, BorderSizePixel = 0, Visible = false}, gui)
    bg(frame, "BackgroundColor3", "window")
    corner(frame, 8)
    track(stroke(frame, accent, 1, 0.5), "Color")
    local header = label(frame, {Size = UDim2.new(1, -16, 0, 26), Position = UDim2.fromOffset(10, 0),
        Text = "🛰️ Detector", TextSize = 11, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left})
    track(header, "TextColor3")

    local rows = {}
    for i = 1, 8 do
        local r = new("Frame", {Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 26 + (i - 1) * 22),
            BackgroundTransparency = 1, Visible = false}, frame)
        local nm = label(r, {Size = UDim2.fromOffset(104, 22), Position = UDim2.fromOffset(10, 0), Text = "",
            TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd})
        local tg = label(r, {Size = UDim2.fromOffset(50, 22), Position = UDim2.fromOffset(116, 0), Text = "", TextSize = 12})
        local ds = label(r, {Size = UDim2.fromOffset(40, 22), Position = UDim2.new(1, -48, 0, 0), Text = "",
            TextSize = 11, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Right})
        rows[i] = {frame = r, name = nm, tag = tg, dist = ds}
    end

    local airborne = {}
    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude

    -- invisível: nenhuma parte do corpo (fora o HumanoidRootPart) está visível
    local function isInvisible(char)
        local found = false
        for _, d in ipairs(char:GetChildren()) do
            if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
                found = true
                if d.Transparency < 0.6 then return false end
            end
        end
        return found
    end

    -- voando: no ar (sem chão por perto) por mais de ~1s, parado/flutuando ou subindo
    local function isFlying(plr, char, root, hum, step)
        if hum.Sit then airborne[plr] = 0 return false end
        local okS, state = pcall(function() return hum:GetState() end)
        if okS and (state == Enum.HumanoidStateType.Climbing or state == Enum.HumanoidStateType.Swimming) then
            airborne[plr] = 0
            return false
        end
        rayParams.FilterDescendantsInstances = {char}
        if workspace:Raycast(root.Position, Vector3.new(0, -8, 0), rayParams) then
            airborne[plr] = 0
            return false
        end
        airborne[plr] = (airborne[plr] or 0) + step
        local vy = root.AssemblyLinearVelocity.Y
        return airborne[plr] > 1.2 and (math.abs(vy) < 6 or vy > 15)
    end

    Players.PlayerRemoving:Connect(function(plr) airborne[plr] = nil end)

    task.spawn(function()
        local step = 0.25
        while gui.Parent do
            task.wait(step)
            pcall(function()
                local list = {}
                if det.on and unlocked then
                    local myChar = player.Character
                    local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
                    for _, plr in ipairs(Players:GetPlayers()) do
                        if plr ~= player then
                            local char = plr.Character
                            local root = char and char:FindFirstChild("HumanoidRootPart")
                            local hum = char and char:FindFirstChildOfClass("Humanoid")
                            if root and hum and hum.Health > 0 then
                                local tags = {}
                                if det.invisible and isInvisible(char) then table.insert(tags, "👻") end
                                if det.flying and isFlying(plr, char, root, hum, step) then table.insert(tags, "🕊️") end
                                if #tags > 0 then
                                    table.insert(list, {
                                        name = plr.Name, tags = table.concat(tags, " "),
                                        dist = myRoot and (root.Position - myRoot.Position).Magnitude or 0,
                                    })
                                end
                            else
                                airborne[plr] = 0
                            end
                        end
                    end
                    table.sort(list, function(a, b) return a.dist < b.dist end)
                end
                local n = math.min(#list, #rows)
                for i, r in ipairs(rows) do
                    local e = list[i]
                    if e then
                        r.frame.Visible = true
                        r.name.Text = e.name
                        r.tag.Text = e.tags
                        r.dist.Text = math.floor(e.dist) .. "m"
                    else
                        r.frame.Visible = false
                    end
                end
                header.Text = "🛰️ Detector • " .. #list
                frame.Size = UDim2.fromOffset(214, 30 + n * 22)
                frame.Visible = n > 0
            end)
        end
    end)

    local card = Settings.hudSub:Card("Detector", "🛰️", 2)
    card:Toggle("Mostrar quem está invisível/voando", true, function(on) det.on = on end)
    card:Toggle("👻 Detectar invisíveis", true, function(on) det.invisible = on end)
    card:Toggle("🕊️ Detectar voando", true, function(on) det.flying = on end)
    card:Note("Aparece no canto da tela só quando alguém for detectado. É uma estimativa: veículos e pulos altos podem enganar.")
end

-- Utilidades compartilhadas pelas abas novas (nada aqui altera o jogo dos outros)
local TeleportService = game:GetService("TeleportService")
local TextChatService = game:GetService("TextChatService")

local function copyText(txt)
    local ok = pcall(function() setclipboard(txt) end)
    notify(ok and "Copiado" or "Copiar não é suportado aqui")
end
local function sayInChat(msg)
    msg = string.sub(msg or "", 1, 200)
    if msg == "" then return end
    pcall(function()
        if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
            local ch = TextChatService.TextChannels:FindFirstChild("RBXGeneral")
            if ch then ch:SendAsync(msg) end
        else
            game:GetService("ReplicatedStorage").DefaultChatSystemChatEvents.SayMessageRequest:FireServer(msg, "All")
        end
    end)
end
local function fmtTime(t)
    t = math.floor(t)
    return string.format("%02d:%02d:%02d", t // 3600, (t % 3600) // 60, t % 60)
end
local function getHumanoid()
    local ch = player.Character
    return ch and ch:FindFirstChildOfClass("Humanoid")
end

-- Jogadores (lista informativa do servidor)
do
    local sub = P.Players:SubTab("👥 Servidor")
    local listCard = sub:Card("Jogadores online", "👥", 1)
    local listLabel = listCard:List()
    local pick = sub:Card("Perfil", "🪪", 2)
    local infoLabel = pick:Info()
    local selected = 1
    local ordered = {}
    local spectateTarget = nil

    local function refresh()
        ordered = Players:GetPlayers()
        table.sort(ordered, function(a, b) return a.DisplayName:lower() < b.DisplayName:lower() end)
        local rows = {}
        for _, p in ipairs(ordered) do
            local you = (p == player) and " (você)" or ""
            table.insert(rows, string.format("%s (@%s)%s", p.DisplayName, p.Name, you))
        end
        listLabel.Text = #ordered .. " jogador(es)\n" .. table.concat(rows, "\n")
        if selected > #ordered then selected = 1 end
        local p = ordered[selected]
        if p then
            infoLabel.Text = string.format("%s (@%s)\nID: %d\nConta: %d dias", p.DisplayName, p.Name, p.UserId, p.AccountAge)
            task.spawn(function()
                if p == player then return end
                local ok, friend = pcall(function() return player:IsFriendsWith(p.UserId) end)
                if ok and ordered[selected] == p then
                    infoLabel.Text = infoLabel.Text .. (friend and "  •  Amigo" or "")
                end
            end)
        end
    end
    pick:Button("Próximo jogador", "PRÓXIMO", function()
        selected = selected % math.max(#ordered, 1) + 1
        refresh()
    end)
    pick:Button("Atualizar lista", "ATUALIZAR", function() refresh() end)
    pick:Button("Observar jogador", "SPECTATE", function()
        local target = ordered[selected]
        local humanoid = target and target.Character and target.Character:FindFirstChildOfClass("Humanoid")
        local camera = workspace.CurrentCamera
        if target and target ~= player and humanoid and camera then
            camera.CameraSubject = humanoid
            spectateTarget = target
            notify("Observando " .. target.DisplayName)
        else
            notify("Selecione outro jogador com personagem ativo")
        end
    end)
    pick:Button("Voltar para meu personagem", "VOLTAR", function()
        local camera = workspace.CurrentCamera
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if camera and humanoid then camera.CameraSubject = humanoid end
        spectateTarget = nil
        notify("Câmera restaurada")
    end)
    pick:Button("Teleportar até jogador", "IR ATÉ", function()
        local target = ordered[selected]
        local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        local targetRoot = target and target.Character and target.Character:FindFirstChild("HumanoidRootPart")
        if target and target ~= player and myRoot and targetRoot then
            myRoot.CFrame = targetRoot.CFrame * CFrame.new(3, 0, 0)
            notify("Teleportado até " .. target.DisplayName)
        elseif target == player then
            notify("Você já está selecionado")
        else
            notify("Jogador ou personagem indisponível")
        end
    end)

    Players.PlayerAdded:Connect(function() refresh() end)
    Players.PlayerRemoving:Connect(function(p)
        if spectateTarget == p then
            local camera = workspace.CurrentCamera
            local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if camera and humanoid then camera.CameraSubject = humanoid end
            spectateTarget = nil
        end
        task.defer(refresh)
    end)
    gui.Destroying:Connect(function()
        local camera = workspace.CurrentCamera
        local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if spectateTarget and camera and humanoid then camera.CameraSubject = humanoid end
        spectateTarget = nil
    end)
    refresh()
end

-- PvP (mira na tela e estatísticas da sessão)
do
    local crossGui = playerGui:FindFirstChild("KawanMenuCross")
    if crossGui then crossGui:Destroy() end
    crossGui = new("ScreenGui", {Name = "KawanMenuCross", ResetOnSpawn = false, IgnoreGuiInset = true,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 49}, playerGui)
    gui.Destroying:Connect(function() crossGui:Destroy() end)

    local cross = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromOffset(0, 0), BackgroundTransparency = 1, Visible = false}, crossGui)
    local bars = {}
    for i = 1, 5 do
        bars[i] = new("Frame", {BorderSizePixel = 0, BackgroundColor3 = accent}, cross)
    end
    local cfg = {size = 8, gap = 4, thick = 2, dot = false, colorMode = 1}
    local fixed = {nil, Color3.new(1, 1, 1), rgb(80, 235, 155), rgb(255, 90, 105), rgb(255, 235, 90)}
    local colorNames = {"Cor do tema", "Branco", "Verde", "Vermelho", "Amarelo"}

    local function layout()
        local s, g, t = cfg.size, cfg.gap, cfg.thick
        bars[1].Size, bars[1].Position = UDim2.fromOffset(t, s), UDim2.fromOffset(-t / 2, -g - s)
        bars[2].Size, bars[2].Position = UDim2.fromOffset(t, s), UDim2.fromOffset(-t / 2, g)
        bars[3].Size, bars[3].Position = UDim2.fromOffset(s, t), UDim2.fromOffset(-g - s, -t / 2)
        bars[4].Size, bars[4].Position = UDim2.fromOffset(s, t), UDim2.fromOffset(g, -t / 2)
        bars[5].Size, bars[5].Position = UDim2.fromOffset(t, t), UDim2.fromOffset(-t / 2, -t / 2)
        bars[5].Visible = cfg.dot
    end
    local function recolor()
        local col = fixed[cfg.colorMode] or accent
        for _, b in ipairs(bars) do b.BackgroundColor3 = col end
    end
    table.insert(accentHooks, recolor)
    layout()

    local sub = P.Pvp:SubTab("🎯 Mira")
    local cc = sub:Card("Mira personalizada", "🎯", 1)
    cc:Toggle("Mostrar mira na tela", false, function(on) cross.Visible = on end)
    cc:Toggle("Ponto central", false, function(on) cfg.dot = on layout() end)
    cc:Dropdown("Cor da mira:", colorNames, 1, function(_, i) cfg.colorMode = i recolor() end)

    -- Opções de combate adaptadas do script de referência.
    -- Aimbot é assistência de câmera para a experiência própria; não altera tiros.
    local aimCfg = {
        Aimbot = false, SilentAim = false, SmoothAim = true,
        SmoothnessAimbot = 8, SmoothnessSilent = 8,
        Wallcheck = false, Teamcheck = false,
        ShowFOV = false, FOV = 170, AimBodyPart = "Head",
        HitboxDebug = false,
    }
    local aimCircle = new("Frame", {
        Name = "KawanAimFOV", AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(aimCfg.FOV, aimCfg.FOV),
        BackgroundTransparency = 1, Visible = false, BorderSizePixel = 0,
    }, crossGui)
    new("UICorner", {CornerRadius = UDim.new(1, 0)}, aimCircle)
    local aimCircleStroke = new("UIStroke", {Color = accent, Thickness = 1.5, Transparency = 0.12}, aimCircle)
    local function refreshAimCircle()
        local cam = workspace.CurrentCamera
        if cam then
            aimCircle.Position = UDim2.fromOffset(cam.ViewportSize.X / 2, cam.ViewportSize.Y / 2)
        end
        aimCircle.Size = UDim2.fromOffset(aimCfg.FOV, aimCfg.FOV)
        aimCircle.Visible = aimCfg.ShowFOV
    end
    table.insert(accentHooks, function() aimCircleStroke.Color = accent end)
    local aimHeld = false
    local mobileAim = UIS.TouchEnabled and not UIS.KeyboardEnabled
    UIS.InputBegan:Connect(function(input, processed)
        if not processed and input.UserInputType == Enum.UserInputType.MouseButton2 then aimHeld = true end
    end)
    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton2 then aimHeld = false end
    end)
    local function getAimPart(character)
        local names = {
            Head = {"Head"}, Chest = {"UpperTorso", "Torso", "HumanoidRootPart"},
            Abdomen = {"LowerTorso", "Torso", "HumanoidRootPart"},
            Neck = {"Head", "UpperTorso", "Torso"},
            LeftArm = {"LeftHand", "LeftLowerArm", "Left Arm"},
            RightArm = {"RightHand", "RightLowerArm", "Right Arm"},
            LeftLeg = {"LeftFoot", "LeftLowerLeg", "Left Leg"},
            RightLeg = {"RightFoot", "RightLowerLeg", "Right Leg"},
        }
        for _, name in ipairs(names[aimCfg.AimBodyPart] or names.Head) do
            local part = character and character:FindFirstChild(name)
            if part and part:IsA("BasePart") then return part end
        end
        return character and character:FindFirstChild("HumanoidRootPart")
    end
    local function validAimTarget(target, camera)
        if target == player then return false end
        if aimCfg.Teamcheck and player.Team and target.Team == player.Team then return false end
        local character = target.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        local part = getAimPart(character)
        if not humanoid or humanoid.Health <= 0 or not part then return false end
        local point, visible = camera:WorldToViewportPoint(part.Position)
        if not visible or point.Z <= 0 then return false end
        local center = Vector2.new(camera.ViewportSize.X / 2, camera.ViewportSize.Y / 2)
        local distance = (Vector2.new(point.X, point.Y) - center).Magnitude
        if distance > aimCfg.FOV / 2 then return false end
        if aimCfg.Wallcheck then
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = {player.Character}
            local result = workspace:Raycast(camera.CFrame.Position, part.Position - camera.CFrame.Position, params)
            if not result or not result.Instance:IsDescendantOf(character) then return false end
        end
        return true, part, distance
    end
    RunService:BindToRenderStep("KawanMenuAimAssist", Enum.RenderPriority.Camera.Value + 1, function(dt)
        refreshAimCircle()
        if not aimCfg.Aimbot or (not aimHeld and not mobileAim) then return end
        local camera = workspace.CurrentCamera
        if not camera then return end
        local bestPart, bestDistance
        for _, target in ipairs(Players:GetPlayers()) do
            local valid, part, distance = validAimTarget(target, camera)
            if valid and (not bestDistance or distance < bestDistance) then
                bestPart, bestDistance = part, distance
            end
        end
        if bestPart then
            local goal = CFrame.lookAt(camera.CFrame.Position, bestPart.Position)
            if aimCfg.SmoothAim then
                local smooth = math.max(aimCfg.SmoothnessAimbot, 1)
                camera.CFrame = camera.CFrame:Lerp(goal, 1 - math.exp(-dt * (60 / smooth)))
            else
                camera.CFrame = goal
            end
        end
    end)
    gui.Destroying:Connect(function()
        pcall(function() RunService:UnbindFromRenderStep("KawanMenuAimAssist") end)
    end)

    local aimSub = P.Pvp:SubTab("🎯 Combate")
    local aimCard = aimSub:Card("Combate / assistência de mira", "🎯", 1)
    aimCard:Toggle("Aimbot (mobile automático / PC botão direito)", false, function(on) aimCfg.Aimbot = on end)
    aimCard:Toggle("Silent Aim (configuração; requer integração com armas)", false, function(on) aimCfg.SilentAim = on end)
    aimCard:Toggle("Smooth Aim", true, function(on) aimCfg.SmoothAim = on end)
    aimCard:Slider("Suavidade do Aimbot", 1, 30, 8, function(v) aimCfg.SmoothnessAimbot = v end)
    aimCard:Slider("Suavidade do Silent Aim", 1, 30, 8, function(v) aimCfg.SmoothnessSilent = v end)
    aimCard:Toggle("Wall Check", false, function(on) aimCfg.Wallcheck = on end)
    aimCard:Toggle("Team Check", false, function(on) aimCfg.Teamcheck = on end)
    aimCard:Toggle("Exibir círculo de FOV", false, function(on) aimCfg.ShowFOV = on refreshAimCircle() end)
    aimCard:Slider("Tamanho do FOV", 50, 500, 170, function(v) aimCfg.FOV = v refreshAimCircle() end)
    aimCard:Dropdown("Parte do corpo:", {"Head", "Neck", "Chest", "Abdomen", "LeftArm", "RightArm", "LeftLeg", "RightLeg"}, 1,
        function(value) aimCfg.AimBodyPart = value end)
    aimCard:Note("A mira é assistência visual de câmera. Silent Aim e hitbox de dano exigem integração legítima com o sistema de armas e validação no servidor.")

    -- ESP e hitbox visual de jogadores, centralizados na aba Jogadores.
    local espSub = P.Players:SubTab("👁 ESP")
    local espCard = espSub:Card("ESP de jogadores", "👁", 1)
    local espCfg = {
        Enabled = false, Highlight = false, Names = true, Distance = false,
        Box = false, Tracers = false, TeamCheck = false, TeamColor = true, Hitbox = false,
        MaxDistance = 2000, Skeleton = false, Radar = false,
        SkeletonThickness = 2.2, RadarRange = 500,
    }
    local espObjects = {}
    local radarDots = {}
    local radarRoot = nil
    local radarStroke = nil
    local function ensureRadar()
        if radarRoot and radarRoot.Parent then return end
        radarRoot = new("Frame", {
            Name = "KawanCircularRadar", AnchorPoint = Vector2.new(1, 0),
            Position = UDim2.new(1, -24, 0, 110), Size = UDim2.fromOffset(184, 184),
            BackgroundColor3 = Color3.fromRGB(8, 16, 29), BackgroundTransparency = 0.18,
            BorderSizePixel = 0, Visible = false, ZIndex = 40,
        }, crossGui)
        new("UICorner", {CornerRadius = UDim.new(1, 0)}, radarRoot)
        radarStroke = new("UIStroke", {Color = accent, Thickness = 1.8, Transparency = 0.08}, radarRoot)
        local center = new("Frame", {Name="RadarCenter", AnchorPoint=Vector2.new(.5,.5), Position=UDim2.fromScale(.5,.5), Size=UDim2.fromOffset(5,5), BackgroundColor3=Color3.fromRGB(255,255,255), BorderSizePixel=0, ZIndex=42}, radarRoot)
        new("UICorner", {CornerRadius=UDim.new(1,0)}, center)
        local horizontal = new("Frame", {AnchorPoint=Vector2.new(.5,.5), Position=UDim2.fromScale(.5,.5), Size=UDim2.new(1,-18,0,1), BackgroundColor3=accent, BackgroundTransparency=.55, BorderSizePixel=0, ZIndex=41}, radarRoot)
        local vertical = new("Frame", {AnchorPoint=Vector2.new(.5,.5), Position=UDim2.fromScale(.5,.5), Size=UDim2.new(0,1,1,-18), BackgroundColor3=accent, BackgroundTransparency=.55, BorderSizePixel=0, ZIndex=41}, radarRoot)
        local title = new("TextLabel", {Name="RadarTitle", BackgroundTransparency=1, Position=UDim2.new(0,0,0,-22), Size=UDim2.new(1,0,0,18), Font=Enum.Font.GothamBold, Text="KAWAN RADAR", TextColor3=accent, TextSize=11, ZIndex=42}, radarRoot)
    end
    local function setSegment(frame, a, b, color)
        local delta = b - a
        local length = delta.Magnitude
        local mid = (a + b) / 2
        frame.Visible = length > 1
        if frame.Visible then
            frame.Position = UDim2.fromOffset(mid.X, mid.Y)
            frame.Size = UDim2.fromOffset(length, espCfg.SkeletonThickness)
            frame.Rotation = math.deg(math.atan2(delta.Y, delta.X))
            frame.BackgroundColor3 = color
            frame.BackgroundTransparency = 0.02
            local outline = frame:FindFirstChildOfClass("UIStroke")
            if outline then
                outline.Color = Color3.fromRGB(245, 250, 255)
                outline.Transparency = 0.58
                outline.Thickness = 0.7
            end
        end
    end
    local skeletonPairs = {
        {"Head","UpperTorso"}, {"UpperTorso","LowerTorso"},
        {"UpperTorso","LeftUpperArm"}, {"LeftUpperArm","LeftLowerArm"}, {"LeftLowerArm","LeftHand"},
        {"UpperTorso","RightUpperArm"}, {"RightUpperArm","RightLowerArm"}, {"RightLowerArm","RightHand"},
        {"LowerTorso","LeftUpperLeg"}, {"LeftUpperLeg","LeftLowerLeg"}, {"LeftLowerLeg","LeftFoot"},
        {"LowerTorso","RightUpperLeg"}, {"RightUpperLeg","RightLowerLeg"}, {"RightLowerLeg","RightFoot"},
    }
    local skeletonPairsR6 = {
        {"Head","Torso"}, {"Torso","Left Arm"}, {"Torso","Right Arm"},
        {"Torso","Left Leg"}, {"Torso","Right Leg"},
    }
    local function restoreNativeNameDistance(obj)
        if not obj or not obj.nativeHumanoid then return end
        local humanoid = obj.nativeHumanoid
        local original = obj.nativeNameOriginal
        if humanoid.Parent and original then
            pcall(function()
                humanoid.NameDisplayDistance = original.NameDisplayDistance
                humanoid.DisplayDistanceType = original.DisplayDistanceType
            end)
        end
        obj.nativeHumanoid = nil
        obj.nativeNameOriginal = nil
    end
    local function destroyEspObject(obj)
        if not obj then return end
        restoreNativeNameDistance(obj)
        for _, key in ipairs({"highlight", "billboard", "box", "line", "hitbox"}) do
            local item = obj[key]
            if item then pcall(function() item:Destroy() end) obj[key] = nil end
        end
        if obj.skeleton then
            for _, segment in ipairs(obj.skeleton) do pcall(function() segment:Destroy() end) end
            obj.skeleton = nil
        end
        if radarDots[obj] then pcall(function() radarDots[obj]:Destroy() end) radarDots[obj] = nil end
    end
    local function clearESP()
        for target, obj in pairs(espObjects) do
            destroyEspObject(obj)
            espObjects[target] = nil
        end
        if radarRoot then radarRoot.Visible = false end
    end
    local function makeOverlayFrame(name, parent)
        local frame = new("Frame", {
            Name = name, BorderSizePixel = 0, BackgroundTransparency = 1,
            Visible = false, ZIndex = 30,
        }, parent)
        local stroke = new("UIStroke", {Color = accent, Thickness = 1.6, Transparency = 0.05}, frame)
        return frame, stroke
    end
    -- Usa o letreiro nativo do Humanoid; não cria BillboardGui/labels extras.
    local function applyNativeNameDistance(obj, humanoid)
        if obj.nativeHumanoid ~= humanoid then
            restoreNativeNameDistance(obj)
            obj.nativeHumanoid = humanoid
            obj.nativeNameOriginal = {
                NameDisplayDistance = humanoid.NameDisplayDistance,
                DisplayDistanceType = humanoid.DisplayDistanceType,
            }
        end
        pcall(function()
            humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Subject
            humanoid.NameDisplayDistance = espCfg.MaxDistance
        end)
    end
    local function updateESP()
        if not espCfg.Enabled then clearESP() return end
        local now = os.clock()
        local camera = workspace.CurrentCamera
        local myChar = player.Character
        local myRoot = myChar and (myChar:FindFirstChild("HumanoidRootPart") or myChar:FindFirstChild("Head"))
        local viewport = camera and camera.ViewportSize
        for _, target in ipairs(Players:GetPlayers()) do
            if target == player then continue end
            local character = target.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            local head = character and character:FindFirstChild("Head")
            local root = character and (character:FindFirstChild("HumanoidRootPart") or head)
            local sameTeam = espCfg.TeamCheck and player.Team ~= nil and target.Team == player.Team
            local distance = (myRoot and root) and (myRoot.Position - root.Position).Magnitude or math.huge
            if not character or not humanoid or humanoid.Health <= 0 or not head or not root
                or sameTeam or distance > espCfg.MaxDistance then
                if espObjects[target] then destroyEspObject(espObjects[target]) espObjects[target] = nil end
                continue
            end
            local obj = espObjects[target] or {}
            espObjects[target] = obj
            local color = (espCfg.TeamColor and target.Team) and target.Team.TeamColor.Color or accent
            if espCfg.Highlight then
                if not obj.highlight or not obj.highlight.Parent then
                    obj.highlight = new("Highlight", {
                        Name = "KawanPlayerESP", Adornee = character, DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
                        FillColor = color, OutlineColor = Color3.fromRGB(235, 248, 255),
                        FillTransparency = 0.78, OutlineTransparency = 0.08,
                    }, character)
                else
                    obj.highlight.Adornee = character
                    obj.highlight.FillColor = color
                end
            elseif obj.highlight then obj.highlight:Destroy() obj.highlight = nil end
            if espCfg.Names then
                applyNativeNameDistance(obj, humanoid)
            else
                restoreNativeNameDistance(obj)
            end
            if espCfg.Hitbox then
                local part = getAimPart(character) or head
                if not obj.hitbox or not obj.hitbox.Parent then
                    obj.hitbox = new("BoxHandleAdornment", {
                        Name = "KawanHitboxVisual", Adornee = part, AlwaysOnTop = true,
                        ZIndex = 8, Size = part.Size + Vector3.new(0.12, 0.12, 0.12),
                        Color3 = Color3.fromRGB(70, 170, 255), Transparency = 0.48,
                    }, workspace)
                else
                    obj.hitbox.Adornee = part
                    obj.hitbox.Size = part.Size + Vector3.new(0.12, 0.12, 0.12)
                end
            elseif obj.hitbox then obj.hitbox:Destroy() obj.hitbox = nil end
            if camera and viewport and espCfg.Box then
                if not obj.box or not obj.box.Parent then
                    obj.box, obj.boxStroke = makeOverlayFrame("KawanBoxESP", crossGui)
                    obj.boxStroke.Thickness = 1.6
                end
                local cf, size = character:GetBoundingBox()
                local minX, minY, maxX, maxY = math.huge, math.huge, -math.huge, -math.huge
                local anyFront = false
                for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
                    local corner = (cf * CFrame.new(size.X*x/2, size.Y*y/2, size.Z*z/2)).Position
                    local point = camera:WorldToViewportPoint(corner)
                    if point.Z > 0 then
                        anyFront = true
                        minX, minY = math.min(minX, point.X), math.min(minY, point.Y)
                        maxX, maxY = math.max(maxX, point.X), math.max(maxY, point.Y)
                    end
                end end end
                local w, h = maxX - minX, maxY - minY
                local show = anyFront and w > 2 and h > 2 and maxX >= 0 and minX <= viewport.X and maxY >= 0 and minY <= viewport.Y
                obj.box.Visible = show
                if show then
                    obj.box.Position, obj.box.Size = UDim2.fromOffset(minX, minY), UDim2.fromOffset(w, h)
                    obj.boxStroke.Color = color
                end
            elseif obj.box then obj.box.Visible = false end
            if camera and viewport and espCfg.Tracers then
                if not obj.line or not obj.line.Parent then
                    obj.line = new("Frame", {Name = "KawanTracerESP", BorderSizePixel = 0,
                        AnchorPoint = Vector2.new(0.5, 0.5), BackgroundColor3 = color,
                        Visible = false, ZIndex = 29}, crossGui)
                end
                local point, visible = camera:WorldToViewportPoint(root.Position)
                local sx, sy = viewport.X / 2, viewport.Y
                local dx, dy = point.X - sx, point.Y - sy
                local length = math.sqrt(dx*dx + dy*dy)
                local show = visible and point.Z > 0 and length > 1
                obj.line.Visible = show
                if show then
                    obj.line.BackgroundColor3 = color
                    obj.line.Position = UDim2.fromOffset((sx + point.X)/2, (sy + point.Y)/2)
                    obj.line.Size = UDim2.fromOffset(length, 1.5)
                    obj.line.Rotation = math.deg(math.atan2(dy, dx))
                end
            elseif obj.line then obj.line.Visible = false end

            -- Skeleton ESP: linhas entre articulações visíveis na tela, sem atravessar paredes.
            if camera and viewport and espCfg.Skeleton then
                local isR6 = character:FindFirstChild("Torso") ~= nil
                local pairsList = isR6 and skeletonPairsR6 or skeletonPairs
                if not obj.skeleton or #obj.skeleton ~= #pairsList then
                    if obj.skeleton then for _, segment in ipairs(obj.skeleton) do segment:Destroy() end end
                    obj.skeleton = {}
                    for index = 1, #pairsList do
                        local segment = new("Frame", {
                            Name = "KawanSkeletonLine", AnchorPoint = Vector2.new(.5,.5),
                            BorderSizePixel = 0, BackgroundTransparency = 0.02,
                            Visible = false, ZIndex = 31,
                        }, crossGui)
                        new("UICorner", {CornerRadius = UDim.new(1, 0)}, segment)
                        new("UIStroke", {
                            Color = Color3.fromRGB(245,250,255),
                            Thickness = 0.7, Transparency = 0.58,
                        }, segment)
                        table.insert(obj.skeleton, segment)
                    end
                end
                for index, pair in ipairs(pairsList) do
                    local partA, partB = character:FindFirstChild(pair[1]), character:FindFirstChild(pair[2])
                    local segment = obj.skeleton[index]
                    if partA and partB then
                        local a, aFront = camera:WorldToViewportPoint(partA.Position)
                        local b, bFront = camera:WorldToViewportPoint(partB.Position)
                        if aFront and bFront and a.Z > 0 and b.Z > 0 then
                            setSegment(segment, Vector2.new(a.X,a.Y), Vector2.new(b.X,b.Y), color)
                        else segment.Visible = false end
                    else segment.Visible = false end
                end
            elseif obj.skeleton then
                for _, segment in ipairs(obj.skeleton) do segment.Visible = false end
            end

            -- Radar circular relativo à orientação do jogador.
            if espCfg.Radar and myRoot then
                ensureRadar()
                radarRoot.Visible = true
                local localPos = myRoot.CFrame:PointToObjectSpace(root.Position)
                local radarRadius = 76
                local range = math.max(1, espCfg.RadarRange)
                local radarVector = Vector2.new(localPos.X / range, -localPos.Z / range)
                if radarVector.Magnitude > 1 then radarVector = radarVector.Unit end
                local px = radarVector.X * radarRadius
                local py = radarVector.Y * radarRadius
                local dot = radarDots[obj]
                if not dot or not dot.Parent then
                    dot = new("Frame", {Name="KawanRadarPlayer", AnchorPoint=Vector2.new(.5,.5), Size=UDim2.fromOffset(7,7), BorderSizePixel=0, ZIndex=43}, radarRoot)
                    new("UICorner", {CornerRadius=UDim.new(1,0)}, dot)
                    radarDots[obj] = dot
                end
                dot.Position = UDim2.new(.5, px, .5, py)
                dot.BackgroundColor3 = color
                dot.Visible = true
            else
                if radarDots[obj] then radarDots[obj].Visible = false end
            end
        end
        if not espCfg.Radar and radarRoot then radarRoot.Visible = false end
        for target, obj in pairs(espObjects) do
            if target.Parent ~= Players then destroyEspObject(obj) espObjects[target] = nil end
        end
    end
    espCard:Toggle("Ativar ESP", false, function(on) espCfg.Enabled = on if not on then clearESP() end end)
    espCard:Toggle("Player ESP (destaque através de paredes)", false, function(on) espCfg.Highlight = on end)
    espCard:Toggle("Name ESP (nome nativo em maior distância)", true, function(on) espCfg.Names = on end)
    espCard:Toggle("Box ESP (caixa 2D)", false, function(on) espCfg.Box = on end)
    espCard:Toggle("Line ESP (linha até o jogador)", false, function(on) espCfg.Tracers = on end)
    espCard:Toggle("Skeleton ESP (linhas)", false, function(on) espCfg.Skeleton = on end)
    espCard:Slider("Espessura do Skeleton", 1, 6, 2.2, function(v) espCfg.SkeletonThickness = v end)
    espCard:Toggle("Radar circular", false, function(on) espCfg.Radar = on if on then ensureRadar() else if radarRoot then radarRoot.Visible = false end end end)
    espCard:Slider("Alcance do Radar", 100, 3000, 500, function(v) espCfg.RadarRange = v end)
    espCard:Toggle("Team Check (cor por equipe)", true, function(on) espCfg.TeamColor = on end)
    espCard:Toggle("Ocultar aliados", false, function(on) espCfg.TeamCheck = on end)
    espCard:Toggle("Hitbox ESP (parte selecionada)", false, function(on) espCfg.Hitbox = on end)
    espCard:Slider("Distância máxima do ESP", 100, 3000, 2000, function(v) espCfg.MaxDistance = v end)
    espCard:Note("Name ESP ajusta a distância do nome nativo do Humanoid, sem criar etiquetas extras. Se o servidor/anti-cheat bloquear alterações locais, será necessário permitir isso no jogo. Hitbox ESP é somente visual.")
    Players.PlayerAdded:Connect(function() if espCfg.Enabled then task.defer(updateESP) end end)
    Players.PlayerRemoving:Connect(function(target)
        if espObjects[target] then destroyEspObject(espObjects[target]) espObjects[target] = nil end
    end)
    local espRenderConnection = RunService.RenderStepped:Connect(updateESP)
    gui.Destroying:Connect(function()
        if espRenderConnection then espRenderConnection:Disconnect() end
        clearESP()
        if radarRoot then radarRoot:Destroy() radarRoot = nil end
    end)
    table.insert(accentHooks, function()
        for target, obj in pairs(espObjects) do
            local color = (espCfg.TeamColor and target.Team) and target.Team.TeamColor.Color or accent
            if obj.highlight then obj.highlight.FillColor = color end
            if obj.boxStroke then obj.boxStroke.Color = color end
            if obj.line then obj.line.BackgroundColor3 = color end
            if obj.skeleton then for _, segment in ipairs(obj.skeleton) do segment.BackgroundColor3 = color end end
            if radarDots[obj] then radarDots[obj].BackgroundColor3 = color end
        end
        if radarStroke then radarStroke.Color = accent end
    end)
    local cs = sub:Card("Formato", "📐", 2)
    cs:Slider("Comprimento", 2, 30, cfg.size, function(v) cfg.size = v layout() end)
    cs:Slider("Distância do centro", 0, 20, cfg.gap, function(v) cfg.gap = v layout() end)
    cs:Slider("Espessura", 1, 6, cfg.thick, function(v) cfg.thick = v layout() end)

    -- Estatísticas da sessão (só leitura dos seus próprios dados)
    local deaths, aliveSince = 0, os.clock()
    local function hook(char)
        aliveSince = os.clock()
        local h = char:WaitForChild("Humanoid", 5)
        if h then h.Died:Connect(function() deaths += 1 end) end
    end
    if player.Character then task.spawn(hook, player.Character) end
    player.CharacterAdded:Connect(hook)

    local st = P.Pvp:SubTab("📈 Sessão")
    local stats = st:Card("Estatísticas", "📈", 1):List()
    task.spawn(function()
        while gui.Parent do
            local lines = {"Mortes na sessão: " .. deaths, "Tempo vivo: " .. fmtTime(os.clock() - aliveSince)}
            local ls = player:FindFirstChild("leaderstats")
            if ls then
                for _, v in ipairs(ls:GetChildren()) do
                    if v:IsA("ValueBase") then table.insert(lines, v.Name .. ": " .. tostring(v.Value)) end
                end
            end
            stats.Text = table.concat(lines, "\n")
            task.wait(0.5)
        end
    end)
end

-- Roleplay (só emotes)
do
    local act = P.Rp:SubTab("💬 Ações")
    local em = act:Card("Emotes", "💃", 1)
    local emotes = {"dance", "dance2", "dance3", "wave", "point", "cheer", "laugh", "salute"}
    local emIdx = 1
    em:Dropdown("Emote:", emotes, 1, function(_, i) emIdx = i end)
    em:Button("Executar emote", "EXECUTAR", function() sayInChat("/e " .. emotes[emIdx]) end)
    em:Note("Usa o comando /e do chat padrão do Roblox.")
end

-- Recursos de movimento e veículo reunidos na nova aba EXCLUSIVOS.
do
    local sub = P.Exclusivos:SubTab("🚀 Movimentos")
    local airCard = sub:Card("Movimentos especiais", "🪽", 1)
    local jumpCard = sub:Card("Pulo reforçado", "⬆️", 2)
    local extraMoveCard = sub:Card("Mobilidade extra", "⚡", 1)
    local vehicleCard = sub:Card("Modo helicóptero", "🚁", 2)
    local supermanCard = sub:Card("Modo Superman", "🦸", 1)

    local getMoveCharacter
    local supermanEnabled, supermanConn = false, nil
    local supermanVelocity, supermanGyro = nil, nil
    local supermanSpeed = 75
    local function stopSuperman()
        supermanEnabled = false
        MobilePad.Hide()
        if supermanConn then supermanConn:Disconnect(); supermanConn = nil end
        if supermanVelocity then supermanVelocity:Destroy(); supermanVelocity = nil end
        if supermanGyro then supermanGyro:Destroy(); supermanGyro = nil end
    end
    local function startSuperman()
        local _, hum, root = getMoveCharacter()
        if not hum or not root or hum.Health <= 0 then notify("Personagem ainda não carregou") return end
        stopSuperman()
        supermanEnabled = true
        MobilePad.Show("SUPERMAN")
        supermanVelocity = Instance.new("BodyVelocity")
        supermanVelocity.Name = "KawanSupermanVelocity"
        supermanVelocity.MaxForce = Vector3.new(1e7, 1e7, 1e7)
        supermanVelocity.P = 16000
        supermanVelocity.Parent = root
        supermanGyro = Instance.new("BodyGyro")
        supermanGyro.Name = "KawanSupermanGyro"
        supermanGyro.MaxTorque = Vector3.new(1e7, 1e7, 1e7)
        supermanGyro.P = 12000
        supermanGyro.D = 700
        supermanGyro.Parent = root
        supermanConn = RunService.RenderStepped:Connect(function()
            local _, currentHum, currentRoot = getMoveCharacter()
            local cam = workspace.CurrentCamera
            if not supermanEnabled or not currentHum or not currentRoot or currentHum.Health <= 0 or not cam then
                stopSuperman()
                return
            end
            local forward = ((UIS:IsKeyDown(Enum.KeyCode.W) or MobilePad.Down("forward")) and 1 or 0) - ((UIS:IsKeyDown(Enum.KeyCode.S) or MobilePad.Down("back")) and 1 or 0)
            local side = ((UIS:IsKeyDown(Enum.KeyCode.D) or MobilePad.Down("right")) and 1 or 0) - ((UIS:IsKeyDown(Enum.KeyCode.A) or MobilePad.Down("left")) and 1 or 0)
            local vertical = ((UIS:IsKeyDown(Enum.KeyCode.Space) or MobilePad.Down("up")) and 1 or 0) - ((UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.C) or MobilePad.Down("down")) and 1 or 0)
            local direction = cam.CFrame.LookVector * forward + cam.CFrame.RightVector * side + Vector3.new(0, vertical, 0)
            if direction.Magnitude > 1 then direction = direction.Unit end
            supermanVelocity.Velocity = direction * supermanSpeed
            supermanGyro.CFrame = CFrame.lookAt(currentRoot.Position, currentRoot.Position + cam.CFrame.LookVector)
        end)
        notify(UIS.TouchEnabled and not UIS.KeyboardEnabled and "Superman ativado • use os botões na tela" or "Modo Superman ativado • W/A/S/D, Espaço sobe, Ctrl desce")
    end

    local airWalkEnabled, airWalkPlatform, airWalkConn = false, nil, nil
    local wallRunEnabled, wallRunConn = false, nil
    local wallRunOldAutoRotate = nil
    local jumpBoostEnabled = false
    local jumpBoostPower = 110
    local savedJumpPower = nil
    local infiniteJumpEnabled, slowFallEnabled, sprintEnabled = false, false, false
    local savedWalkSpeed = nil
    local slowFallConn = nil
    local vehicleFlyEnabled, vehicleFlyConn = false, nil
    local vehicleFlightSpeedKmh = 1000
    local vehicleFlightSpeed = (vehicleFlightSpeedKmh / 3.6) / 0.28
    local activeVehicleRoot, vehicleVelocity, vehicleGyro = nil, nil, nil
    local antiFlipEnabled, antiFlipGyro, antiFlipConn = false, nil, nil
    local markedPosition = nil

    getMoveCharacter = function()
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        return char, hum, root
    end

    local function stopAirWalk()
        airWalkEnabled = false
        if airWalkConn then airWalkConn:Disconnect(); airWalkConn = nil end
        if airWalkPlatform then airWalkPlatform:Destroy(); airWalkPlatform = nil end
    end

    local function startAirWalk()
        local char, hum, root = getMoveCharacter()
        if not char or not hum or not root then notify("Personagem ainda não carregou") return end
        stopAirWalk()
        local platform = Instance.new("Part")
        platform.Name = "KawanAirWalkPlatform"
        platform.Size = Vector3.new(7, 0.7, 7)
        platform.Transparency = 1
        platform.Anchored = true
        platform.CanCollide = true
        platform.CanTouch = false
        platform.CanQuery = false
        platform.Parent = workspace
        airWalkPlatform = platform
        airWalkEnabled = true
        airWalkConn = RunService.RenderStepped:Connect(function()
            local _, currentHum, currentRoot = getMoveCharacter()
            if not airWalkEnabled or not airWalkPlatform or not airWalkPlatform.Parent then
                stopAirWalk()
                return
            end
            if not currentHum or not currentRoot or currentHum.Health <= 0 then
                stopAirWalk()
                return
            end
            airWalkPlatform.CFrame = CFrame.new(currentRoot.Position - Vector3.new(0, 3.6, 0))
        end)
        notify("Air Walk ativado • plataforma invisível sob seus pés")
    end

    local function stopWallRun()
        wallRunEnabled = false
        if wallRunConn then wallRunConn:Disconnect(); wallRunConn = nil end
        local _, hum = getMoveCharacter()
        if hum and wallRunOldAutoRotate ~= nil then hum.AutoRotate = wallRunOldAutoRotate end
        wallRunOldAutoRotate = nil
    end

    local function startWallRun()
        local char, hum, root = getMoveCharacter()
        if not char or not hum or not root then notify("Personagem ainda não carregou") return end
        stopWallRun()
        wallRunEnabled = true
        wallRunOldAutoRotate = hum.AutoRotate
        hum.AutoRotate = false
        wallRunConn = RunService.Heartbeat:Connect(function()
            if not wallRunEnabled then return end
            local currentChar, currentHum, currentRoot = getMoveCharacter()
            if not currentChar or not currentHum or not currentRoot or currentHum.Health <= 0 then
                stopWallRun()
                return
            end
            local moveDir = currentHum.MoveDirection
            if moveDir.Magnitude < 0.15 then return end
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = {currentChar}
            local rightHit = workspace:Raycast(currentRoot.Position, currentRoot.CFrame.RightVector * 3.2, params)
            local leftHit = workspace:Raycast(currentRoot.Position, -currentRoot.CFrame.RightVector * 3.2, params)
            local hit
            if rightHit and rightHit.Instance and rightHit.Instance.CanCollide then hit = rightHit end
            if leftHit and leftHit.Instance and leftHit.Instance.CanCollide
                and (not hit or leftHit.Distance < hit.Distance) then hit = leftHit end
            if hit then
                local tangent = moveDir - hit.Normal * moveDir:Dot(hit.Normal)
                if tangent.Magnitude > 0.1 then
                    tangent = tangent.Unit
                    currentRoot.AssemblyLinearVelocity = tangent * 42 + Vector3.new(0, 7, 0)
                    currentRoot.CFrame = CFrame.lookAt(currentRoot.Position, currentRoot.Position + tangent, hit.Normal)
                    currentHum:ChangeState(Enum.HumanoidStateType.Freefall)
                end
            end
        end)
        notify("Wall Run ativado • corra próximo de uma parede")
    end

    local function applyJumpBoost()
        local _, hum = getMoveCharacter()
        if not hum then return end
        if jumpBoostEnabled then
            if savedJumpPower == nil then savedJumpPower = hum.JumpPower end
            hum.UseJumpPower = true
            hum.JumpPower = jumpBoostPower
        else
            if savedJumpPower ~= nil then hum.JumpPower = savedJumpPower end
            savedJumpPower = nil
        end
    end

    -- Pulo infinito: reaplica o estado de salto quando o jogador pede outro pulo no ar.
    local jumpRequestConn = UIS.JumpRequest:Connect(function()
        if not infiniteJumpEnabled then return end
        local _, hum = getMoveCharacter()
        if hum and hum.Health > 0 and hum.FloorMaterial == Enum.Material.Air then
            hum:ChangeState(Enum.HumanoidStateType.Jumping)
        end
    end)

    local function applySprint(on)
        local _, hum = getMoveCharacter()
        if not hum then return end
        if on then
            if savedWalkSpeed == nil then savedWalkSpeed = hum.WalkSpeed end
            hum.WalkSpeed = math.max(savedWalkSpeed, 16) * 1.65
        else
            if savedWalkSpeed ~= nil then hum.WalkSpeed = savedWalkSpeed end
            savedWalkSpeed = nil
        end
    end

    local function setSlowFall(on)
        slowFallEnabled = on
        if slowFallConn then slowFallConn:Disconnect(); slowFallConn = nil end
        if on then
            slowFallConn = RunService.Heartbeat:Connect(function()
                local _, hum, root = getMoveCharacter()
                if hum and root and hum.Health > 0 and hum.FloorMaterial == Enum.Material.Air then
                    local v = root.AssemblyLinearVelocity
                    if v.Y < -18 then root.AssemblyLinearVelocity = Vector3.new(v.X, -18, v.Z) end
                end
            end)
        end
    end

    local function dashForward()
        local _, hum, root = getMoveCharacter()
        if not hum or not root or hum.Health <= 0 then notify("Personagem ainda não carregou") return end
        local direction = hum.MoveDirection
        if direction.Magnitude < 0.1 then
            local cam = workspace.CurrentCamera
            direction = cam and Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z) or root.CFrame.LookVector
        end
        if direction.Magnitude > 0.1 then
            direction = direction.Unit
            local current = root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity = Vector3.new(direction.X * 72, math.max(current.Y, 8), direction.Z * 72)
        end
    end

    local function removeVehicleFlight()
        if vehicleFlyConn then vehicleFlyConn:Disconnect(); vehicleFlyConn = nil end
        if vehicleVelocity then vehicleVelocity:Destroy(); vehicleVelocity = nil end
        if vehicleGyro then vehicleGyro:Destroy(); vehicleGyro = nil end
        activeVehicleRoot = nil
    end

    local function findDrivenVehicle()
        local _, hum = getMoveCharacter()
        local seat = hum and hum.SeatPart
        if not seat or not seat:IsA("VehicleSeat") then return nil end
        local model = seat:FindFirstAncestorOfClass("Model")
        local root = seat.AssemblyRootPart or (model and (model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart")))
        if root and root:IsA("BasePart") then return root end
        return nil
    end

    -- No modo helicóptero, evita colisões ENTRE peças do próprio veículo,
    -- mas mantém colisões com o mapa/mundo. Não é noclip.
    local heliCollisionGroup = "KawanHeli_" .. tostring(player.UserId)
    local heliCollisionSaved = {}
    local heliCollisionModel, heliCollisionAddedConn = nil, nil
    local function restoreHeliSelfCollision()
        if heliCollisionAddedConn then
            heliCollisionAddedConn:Disconnect()
            heliCollisionAddedConn = nil
        end
        for part, oldGroup in pairs(heliCollisionSaved) do
            if part and part.Parent then
                pcall(function()
                    PhysicsService:SetPartCollisionGroup(part, oldGroup)
                end)
            end
        end
        table.clear(heliCollisionSaved)
        heliCollisionModel = nil
    end

    local function enableHeliSelfCollisionFilter(model)
        restoreHeliSelfCollision()
        if not model then return end
        local ok = pcall(function()
            PhysicsService:RegisterCollisionGroup(heliCollisionGroup)
        end)
        -- Configure only this private group to ignore itself; collisions with
        -- Default/other groups remain enabled.
        pcall(function()
            PhysicsService:CollisionGroupSetCollidable(heliCollisionGroup, heliCollisionGroup, false)
        end)
        local function assignPart(obj)
            if obj and obj:IsA("BasePart") and heliCollisionSaved[obj] == nil then
                local oldGroup = obj.CollisionGroup
                heliCollisionSaved[obj] = oldGroup
                pcall(function()
                    PhysicsService:SetPartCollisionGroup(obj, heliCollisionGroup)
                end)
            end
        end
        for _, obj in ipairs(model:GetDescendants()) do
            assignPart(obj)
        end
        heliCollisionModel = model
        heliCollisionAddedConn = model.DescendantAdded:Connect(assignPart)
    end

    local function stopVehicleFly()
        vehicleFlyEnabled = false
        MobilePad.Hide()
        removeVehicleFlight()
        restoreHeliSelfCollision()
    end

    local function startVehicleFly()
        local root = findDrivenVehicle()
        if not root then
            notify("Entre no banco do motorista (VehicleSeat) antes de ativar")
            return
        end
        removeVehicleFlight()
        local _, driverHum = getMoveCharacter()
        local driverSeat = driverHum and driverHum.SeatPart
        local vehicleModel = driverSeat and driverSeat:FindFirstAncestorOfClass("Model")
        if vehicleModel then
            enableHeliSelfCollisionFilter(vehicleModel)
        end
        activeVehicleRoot = root
        vehicleFlyEnabled = true
        MobilePad.Show("CARRO / HELICÓPTERO")
        vehicleVelocity = Instance.new("BodyVelocity")
        vehicleVelocity.Name = "KawanVehicleFlyVelocity"
        vehicleVelocity.MaxForce = Vector3.new(1e7, 1e7, 1e7)
        vehicleVelocity.P = 18000
        vehicleVelocity.Velocity = Vector3.zero
        vehicleVelocity.Parent = root
        vehicleGyro = Instance.new("BodyGyro")
        vehicleGyro.Name = "KawanVehicleFlyGyro"
        vehicleGyro.MaxTorque = Vector3.new(1e7, 1e7, 1e7)
        vehicleGyro.P = 14000
        vehicleGyro.D = 900
        vehicleGyro.CFrame = root.CFrame
        vehicleGyro.Parent = root
        vehicleFlyConn = RunService.RenderStepped:Connect(function()
            if not vehicleFlyEnabled then return end
            local currentRoot = findDrivenVehicle()
            if not currentRoot or currentRoot ~= activeVehicleRoot or not currentRoot.Parent then
                stopVehicleFly()
                notify("Voo do carro desligado • veículo não está mais sob seu controle")
                return
            end
            local cam = workspace.CurrentCamera
            if not cam then return end
            -- Controle original: movimento acompanha diretamente a direção e a inclinação da câmera.
            local forward = ((UIS:IsKeyDown(Enum.KeyCode.W) or MobilePad.Down("forward")) and 1 or 0) - ((UIS:IsKeyDown(Enum.KeyCode.S) or MobilePad.Down("back")) and 1 or 0)
            local side = ((UIS:IsKeyDown(Enum.KeyCode.D) or MobilePad.Down("right")) and 1 or 0) - ((UIS:IsKeyDown(Enum.KeyCode.A) or MobilePad.Down("left")) and 1 or 0)
            local vertical = ((UIS:IsKeyDown(Enum.KeyCode.Space) or MobilePad.Down("up")) and 1 or 0) - ((UIS:IsKeyDown(Enum.KeyCode.LeftControl) or UIS:IsKeyDown(Enum.KeyCode.C) or MobilePad.Down("down")) and 1 or 0)
            local direction = cam.CFrame.LookVector * forward + cam.CFrame.RightVector * side + Vector3.new(0, vertical, 0)
            if direction.Magnitude > 1 then direction = direction.Unit end
            vehicleVelocity.Velocity = direction * vehicleFlightSpeed
            local look = Vector3.new(cam.CFrame.LookVector.X, cam.CFrame.LookVector.Y, cam.CFrame.LookVector.Z)
            if look.Magnitude > 0.05 then
                -- Alinha a FRENTE do banco do motorista com a câmera.
                -- Alguns veículos têm o AssemblyRootPart girado 180 graus em relação ao banco;
                -- alinhar apenas o root fazia o veículo parecer voar de ré.
                local _, currentHum = getMoveCharacter()
                local seat = currentHum and currentHum.SeatPart
                if seat and seat:IsA("VehicleSeat") then
                    local seatRelativeRotation = currentRoot.CFrame:ToObjectSpace(seat.CFrame).Rotation
                    local desiredSeatFrame = CFrame.lookAt(
                        currentRoot.Position,
                        currentRoot.Position + look.Unit
                    )
                    vehicleGyro.CFrame = desiredSeatFrame * seatRelativeRotation:Inverse()
                else
                    vehicleGyro.CFrame = CFrame.lookAt(
                        currentRoot.Position,
                        currentRoot.Position + look.Unit
                    )
                end
            end
        end)
        notify(UIS.TouchEnabled and not UIS.KeyboardEnabled and "Voo do veículo ativado • use os botões na tela" or "Carro voador ativado • W/S/A/D, Espaço sobe, Ctrl desce")
    end

    airCard:Toggle("Air Walk • flutuar no ar", false, function(on)
        if on then startAirWalk() else stopAirWalk() notify("Air Walk desativado") end
    end)
    airCard:Toggle("Wall Run • correr nas paredes", false, function(on)
        if on then startWallRun() else stopWallRun() notify("Wall Run desativado") end
    end)
    -- Blink: teleporte curto e limitado na direção da câmera, com verificação de obstáculos.
    local blinkDistance = 16
    local blinkCooldown = false
    airCard:Slider("Distância do Blink", 5, 30, blinkDistance, function(value)
        blinkDistance = value
    end)
    airCard:Button("Blink • teleporte curto", "BLINK", function()
        local _, hum, root = getMoveCharacter()
        local cam = workspace.CurrentCamera
        if not hum or not root or hum.Health <= 0 or not cam then
            notify("Personagem ainda não carregou")
            return
        end
        if blinkCooldown then
            notify("Blink recarregando")
            return
        end
        local direction = cam.CFrame.LookVector
        if direction.Magnitude < 0.05 then return end
        direction = direction.Unit
        local origin = root.Position
        local params = RaycastParams.new()
        params.FilterType = Enum.RaycastFilterType.Exclude
        params.FilterDescendantsInstances = {player.Character}
        local hit = workspace:Raycast(origin, direction * blinkDistance, params)
        local travel = hit and math.max(0, hit.Distance - 3) or blinkDistance
        if travel < 3 then
            notify("Há um obstáculo muito perto")
            return
        end
        local destination = origin + direction * travel
        local oldVelocity = root.AssemblyLinearVelocity
        player.Character:PivotTo(CFrame.new(destination, destination + Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)))
        root.AssemblyLinearVelocity = Vector3.new(oldVelocity.X * 0.25, math.clamp(oldVelocity.Y, -20, 20), oldVelocity.Z * 0.25)
        blinkCooldown = true
        notify("Blink realizado")
        task.delay(2, function() blinkCooldown = false end)
    end)
    airCard:Note("Air Walk cria uma plataforma invisível sob o personagem. Wall Run funciona ao correr perto de uma parede. Blink faz um teleporte curto na direção da câmera e para antes de obstáculos.")

    jumpCard:Toggle("Pulo reforçado", false, function(on)
        jumpBoostEnabled = on
        applyJumpBoost()
        notify(on and "Pulo reforçado ativado" or "Pulo restaurado")
    end)
    jumpCard:Slider("Força do pulo", 60, 180, jumpBoostPower, function(value)
        jumpBoostPower = value
        if jumpBoostEnabled then applyJumpBoost() end
    end)

    extraMoveCard:Toggle("Pulo infinito", false, function(on)
        infiniteJumpEnabled = on
        notify(on and "Pulo infinito ativado" or "Pulo infinito desativado")
    end)
    extraMoveCard:Toggle("Queda lenta", false, function(on)
        setSlowFall(on)
        notify(on and "Queda lenta ativada" or "Queda lenta desativada")
    end)
    extraMoveCard:Toggle("Corrida rápida", false, function(on)
        sprintEnabled = on
        applySprint(on)
        notify(on and "Corrida rápida ativada" or "Velocidade restaurada")
    end)
    extraMoveCard:Button("Dash para frente", "DASH", dashForward)
    local chargedJumpReady = true
    extraMoveCard:Button("Salto carregado VIP", "SALTO", function()
        local _, hum, root = getMoveCharacter()
        if not hum or not root or hum.Health <= 0 then notify("Personagem ainda não carregou") return end
        if not chargedJumpReady then notify("Salto carregado recarregando") return end
        chargedJumpReady = false
        local velocity = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = Vector3.new(velocity.X, 92, velocity.Z)
        notify("Salto carregado! • recarga de 3 segundos")
        task.delay(3, function() chargedJumpReady = true end)
    end)
    extraMoveCard:Note("Dash também funciona no ar. Salto carregado dá um impulso vertical forte e tem recarga própria. Queda lenta reduz a velocidade de descida.")

    vehicleCard:Toggle("Ativar modo helicóptero", false, function(on)
        if on then startVehicleFly() else stopVehicleFly(); notify("Carro voador desativado") end
    end)
    vehicleCard:Slider("Velocidade do helicóptero (km/h)", 100, 1000, vehicleFlightSpeedKmh, function(value)
        vehicleFlightSpeedKmh = value
        vehicleFlightSpeed = (value / 3.6) / 0.28
    end)
    vehicleCard:Note("No modo helicóptero, peças do próprio veículo deixam de colidir entre si; colisões com o mapa continuam ativas. W/S/A/D controlam a direção, Espaço sobe e Ctrl desce. 1000 km/h é o alvo configurável; a velocidade real depende da física do veículo e do servidor.")

    supermanCard:Toggle("Voar como Superman", false, function(on)
        if on then startSuperman() else stopSuperman(); notify("Modo Superman desativado") end
    end)
    supermanCard:Slider("Velocidade do voo", 25, 140, supermanSpeed, function(value)
        supermanSpeed = value
    end)
    supermanCard:Note("Voo livre do personagem com direção da câmera. Use Espaço para subir e Ctrl para descer.")

    -- Extras solicitados: turbo configurável, nitro, estabilizador e ponto marcado.
    local vehicleExtraCard = sub:Card("Extras do veículo", "🏎️", 1)
    local pointCard = sub:Card("Ponto marcado", "📍", 2)

    -- Turbo contínuo: alvo configurável até 1000 km/h.
    -- Conversão aproximada usando 1 stud = 0,28 m. O turbo usa aceleração progressiva; o limite real depende do chassis/física e da validação do servidor.
    local turboEnabled, turboConn = false, nil
    local turboTargetKmh = 1000
    local function setTurbo(on)
        turboEnabled = on
        if turboConn then turboConn:Disconnect(); turboConn = nil end
        if not on then
            notify("Turbo desligado")
            return
        end
        if not findDrivenVehicle() then
            turboEnabled = false
            notify("Entre no veículo como motorista primeiro")
            return
        end
        turboConn = RunService.Heartbeat:Connect(function(dt)
            if not turboEnabled then return end
            local root = findDrivenVehicle()
            if not root then
                turboEnabled = false
                if turboConn then turboConn:Disconnect(); turboConn = nil end
                notify("Turbo desligado • você saiu do banco do motorista")
                return
            end
            local seat = (select(1, getMoveCharacter()))
            local hum = seat and seat:FindFirstChildOfClass("Humanoid")
            local vehicleSeat = hum and hum.SeatPart
            if not vehicleSeat or not vehicleSeat:IsA("VehicleSeat") then return end
            -- Só aplica turbo quando o acelerador está para frente.
            -- Não inverte o vetor quando ThrottleFloat é negativo: isso evita
            -- que controles/chassis com eixo de acelerador invertido empurrem o carro para trás.
            if vehicleFlyEnabled or vehicleSeat.ThrottleFloat <= 0.05 then return end
            -- A orientação do banco do motorista define a frente do veículo;
            -- não usamos AssemblyRootPart, que pode estar montado ao contrário.
            local forward = Vector3.new(vehicleSeat.CFrame.LookVector.X, 0, vehicleSeat.CFrame.LookVector.Z)
            if forward.Magnitude < 0.05 then return end
            forward = forward.Unit

            local targetStudsPerSecond = (turboTargetKmh / 3.6) / 0.28
            local current = root.AssemblyLinearVelocity
            local horizontal = Vector3.new(current.X, 0, current.Z)
            local forwardSpeed = horizontal:Dot(forward)

            if forwardSpeed < targetStudsPerSecond then
                local nextSpeed = math.min(targetStudsPerSecond, math.max(0, forwardSpeed) + 600 * dt)
                local lateral = horizontal - forward * forwardSpeed
                root.AssemblyLinearVelocity = forward * nextSpeed + lateral + Vector3.new(0, current.Y, 0)
            end
        end)
        notify("Turbo ativado • alvo de " .. turboTargetKmh .. " km/h")
    end

    airCard:Toggle("Turbo contínuo", false, setTurbo)
    airCard:Slider("Velocidade máxima do turbo (km/h)", 100, 1000, turboTargetKmh, function(value)
        turboTargetKmh = value
        if turboEnabled then notify("Turbo ajustado para " .. value .. " km/h") end
    end)
    airCard:Note("O turbo fica em Movimentos especiais. Entre no veículo e mantenha W/acelerador; 1000 km/h é um alvo teórico e depende da física e do servidor.")


    vehicleExtraCard:Button("Turbo / Nitro", "NITRO", function()
        local root = findDrivenVehicle()
        if not root then notify("Entre no veículo como motorista primeiro") return end
        local forward = root.CFrame.LookVector
        local current = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = Vector3.new(forward.X * 145, math.max(current.Y, 8), forward.Z * 145)
        notify("Nitro ativado!")
    end)
    vehicleExtraCard:Toggle("Anti-capotamento", false, function(on)
        antiFlipEnabled = on
        if antiFlipConn then antiFlipConn:Disconnect(); antiFlipConn = nil end
        if antiFlipGyro then antiFlipGyro:Destroy(); antiFlipGyro = nil end
        if on then
            antiFlipConn = RunService.Heartbeat:Connect(function()
                local root = findDrivenVehicle()
                if not root then
                    if antiFlipGyro then antiFlipGyro:Destroy(); antiFlipGyro = nil end
                    return
                end
                if not antiFlipGyro or antiFlipGyro.Parent ~= root then
                    if antiFlipGyro then antiFlipGyro:Destroy() end
                    antiFlipGyro = Instance.new("BodyGyro")
                    antiFlipGyro.Name = "KawanAntiFlipGyro"
                    antiFlipGyro.MaxTorque = Vector3.new(0, 0, 0)
                    antiFlipGyro.P = 4500
                    antiFlipGyro.D = 450
                    antiFlipGyro.Parent = root
                end
                antiFlipGyro.MaxTorque = Vector3.new(1e6, 0, 1e6)
                local _, yaw = root.CFrame:ToOrientation()
                antiFlipGyro.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, yaw, 0)
            end)
        end
        notify(on and "Anti-capotamento ativado" or "Anti-capotamento desativado")
    end)
    vehicleExtraCard:Button("Drift lateral", "DRIFT", function()
        local root = findDrivenVehicle()
        if not root then notify("Entre no veículo como motorista primeiro") return end
        local side = root.CFrame.RightVector
        local current = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = current + side * 65 + root.CFrame.LookVector * 18
        notify("Drift aplicado")
    end)
    -- Efeitos experimentais aplicados somente ao veículo que o jogador dirige.
    local earthquakeEnabled, earthquakeConn = false, nil
    vehicleExtraCard:Toggle("Modo terremoto", false, function(on)
        earthquakeEnabled = on
        if earthquakeConn then earthquakeConn:Disconnect(); earthquakeConn = nil end
        if on then
            if not findDrivenVehicle() then earthquakeEnabled = false; notify("Entre no veículo como motorista primeiro"); return end
            local started = os.clock()
            earthquakeConn = RunService.Heartbeat:Connect(function()
                local root = findDrivenVehicle()
                if not earthquakeEnabled or not root then
                    earthquakeEnabled = false
                    if earthquakeConn then earthquakeConn:Disconnect(); earthquakeConn = nil end
                    return
                end
                local t = os.clock() - started
                root.AssemblyAngularVelocity += Vector3.new(math.sin(t * 17) * 1.8, math.sin(t * 11) * 0.8, math.cos(t * 15) * 1.8)
            end)
        end
        notify(on and "Modo terremoto ativado" or "Modo terremoto desligado")
    end)
    vehicleExtraCard:Button("Capotar carro", "CAPOTAR", function()
        local root = findDrivenVehicle()
        if not root then notify("Entre no veículo como motorista primeiro"); return end
        root.AssemblyAngularVelocity = root.CFrame.RightVector * 7 + root.CFrame.LookVector * 2
        root:ApplyImpulse(Vector3.new(0, root.AssemblyMass * 38, 0))
        notify("Capotamento aplicado no seu veículo")
    end)
    local crazyEnabled, crazyConn = false, nil
    vehicleExtraCard:Toggle("Carro descontrolado", false, function(on)
        crazyEnabled = on
        if crazyConn then crazyConn:Disconnect(); crazyConn = nil end
        if on then
            if not findDrivenVehicle() then crazyEnabled = false; notify("Entre no veículo como motorista primeiro"); return end
            local started = os.clock()
            crazyConn = RunService.Heartbeat:Connect(function()
                local root = findDrivenVehicle()
                if not crazyEnabled or not root then
                    crazyEnabled = false
                    if crazyConn then crazyConn:Disconnect(); crazyConn = nil end
                    return
                end
                local t = os.clock() - started
                local side = math.sin(t * 8) * 24
                local forward = math.cos(t * 5) * 18
                local look, right = root.CFrame.LookVector, root.CFrame.RightVector
                local v = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = Vector3.new(v.X, v.Y, v.Z) + (look * forward + right * side) * 0.035
                root.AssemblyAngularVelocity += Vector3.new(math.sin(t * 9), math.cos(t * 6) * 0.7, math.cos(t * 8)) * 0.45
            end)
        end
        notify(on and "Carro descontrolado ativado" or "Carro descontrolado desligado")
    end)
    local lockedEnabled, lockedConn = false, nil
    vehicleExtraCard:Toggle("Carro travado", false, function(on)
        lockedEnabled = on
        if lockedConn then lockedConn:Disconnect(); lockedConn = nil end
        if on then
            if not findDrivenVehicle() then lockedEnabled = false; notify("Entre no veículo como motorista primeiro"); return end
            lockedConn = RunService.Heartbeat:Connect(function()
                local root = findDrivenVehicle()
                if not lockedEnabled or not root then
                    lockedEnabled = false
                    if lockedConn then lockedConn:Disconnect(); lockedConn = nil end
                    return
                end
                local v = root.AssemblyLinearVelocity
                root.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0)
                root.AssemblyAngularVelocity = Vector3.zero
            end)
        end
        notify(on and "Veículo travado" or "Veículo liberado")
    end)
    vehicleExtraCard:Button("Freio de mão", "FREAR", function()
        local root = findDrivenVehicle()
        if not root then notify("Entre no veículo como motorista primeiro") return end
        local v = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0)
        root.AssemblyAngularVelocity = Vector3.zero
        notify("Freio de mão aplicado")
    end)
    local cruiseEnabled, cruiseConn, cruiseSpeed = false, nil, 70
    local function setCruiseControl(on)
        cruiseEnabled = on
        if cruiseConn then cruiseConn:Disconnect(); cruiseConn = nil end
        if not on then return end
        local root = findDrivenVehicle()
        if not root then cruiseEnabled = false; notify("Entre no veículo como motorista primeiro"); return end
        local horizontal = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
        cruiseSpeed = math.clamp(horizontal.Magnitude, 35, 120)
        cruiseConn = RunService.Heartbeat:Connect(function()
            local current = findDrivenVehicle()
            if not cruiseEnabled or not current then
                cruiseEnabled = false
                if cruiseConn then cruiseConn:Disconnect(); cruiseConn = nil end
                return
            end
            local direction = Vector3.new(current.CFrame.LookVector.X, 0, current.CFrame.LookVector.Z)
            if direction.Magnitude > 0.05 then
                local v = current.AssemblyLinearVelocity
                current.AssemblyLinearVelocity = direction.Unit * cruiseSpeed + Vector3.new(0, v.Y, 0)
            end
        end)
        notify("Controle de cruzeiro ativado • velocidade mantida")
    end
    vehicleExtraCard:Toggle("Controle de cruzeiro", false, function(on)
        setCruiseControl(on)
    end)
    vehicleExtraCard:Slider("Velocidade de cruzeiro", 35, 120, 70, function(value)
        cruiseSpeed = value
    end)
    vehicleExtraCard:Button("Freio de emergência", "PARAR", function()
        local root = findDrivenVehicle()
        if not root then notify("Entre no veículo como motorista primeiro") return end
        setCruiseControl(false)
        root.AssemblyLinearVelocity = Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
        root.AssemblyAngularVelocity = Vector3.zero
        notify("Freio de emergência aplicado")
    end)
    vehicleExtraCard:Note("Nitro dá impulso, anti-capotamento estabiliza o carro, Drift aplica impulso lateral, Freio de mão reduz a velocidade e o controle de cruzeiro mantém a velocidade escolhida.")

    pointCard:Button("Marcar posição atual", "MARCAR", function()
        local _, hum, root = getMoveCharacter()
        if not root or not hum or hum.Health <= 0 then notify("Personagem não está pronto") return end
        markedPosition = root.CFrame
        notify("Posição marcada! Use Voltar ao ponto para retornar")
    end)
    pointCard:Button("Voltar ao ponto marcado", "VOLTAR", function()
        local _, hum, root = getMoveCharacter()
        if not markedPosition then notify("Marque uma posição primeiro") return end
        if not root or not hum or hum.Health <= 0 then notify("Personagem não está pronto") return end
        root.AssemblyLinearVelocity = Vector3.zero
        root.CFrame = markedPosition + Vector3.new(0, 3, 0)
        notify("Você voltou ao ponto marcado")
    end)

    -- VIP: aura, asas visuais, passos aquáticos e impacto de aterrissagem.
    local vipCard = sub:Card("Habilidades VIP", "👑", 1)
    local vipAuraOn, vipAuraObjects = false, {}
    local vipTrailOn, vipTrailObjects = false, {}
    local waterWalkOn, waterPlatform, waterConn = false, nil, nil
    local landingConn = nil
    local landingFxEnabled = false

    local function clearObjects(list)
        for _, obj in ipairs(list) do
            if obj and obj.Parent then obj:Destroy() end
        end
        table.clear(list)
    end
    local function setVipAura(on)
        vipAuraOn = on
        clearObjects(vipAuraObjects)
        local char, _, root = getMoveCharacter()
        if not on or not char or not root then return end
        local h = Instance.new("Highlight")
        h.Name = "KawanVIPAura"
        h.FillColor = Color3.fromRGB(0, 145, 255)
        h.OutlineColor = Color3.fromRGB(120, 210, 255)
        h.FillTransparency = 0.72
        h.OutlineTransparency = 0.08
        h.Parent = char
        table.insert(vipAuraObjects, h)
        local a = Instance.new("Attachment")
        a.Name = "KawanVIPAuraAttachment"
        a.Parent = root
        table.insert(vipAuraObjects, a)
        local pe = Instance.new("ParticleEmitter")
        pe.Name = "KawanVIPAuraParticles"
        pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        pe.Rate = 18
        pe.Lifetime = NumberRange.new(0.45, 0.9)
        pe.Speed = NumberRange.new(1, 3)
        pe.SpreadAngle = Vector2.new(180, 180)
        pe.LightEmission = 0.8
        pe.Color = ColorSequence.new(Color3.fromRGB(40, 155, 255), Color3.fromRGB(190, 235, 255))
        pe.Parent = a
        table.insert(vipAuraObjects, pe)
    end
    local function setVipWings(on)
        vipTrailOn = on
        clearObjects(vipTrailObjects)
        local char, _, root = getMoveCharacter()
        if not on or not char or not root then return end
        local a0 = Instance.new("Attachment")
        a0.Position = Vector3.new(-1.1, 0.7, 0.5)
        a0.Parent = root
        local a1 = Instance.new("Attachment")
        a1.Position = Vector3.new(1.1, 0.7, 0.5)
        a1.Parent = root
        for _, pair in ipairs({{a0,a1}}) do
            local trail = Instance.new("Trail")
            trail.Attachment0 = pair[1]
            trail.Attachment1 = pair[2]
            trail.Color = ColorSequence.new(Color3.fromRGB(255, 105, 25), Color3.fromRGB(255, 220, 80))
            trail.Lifetime = 0.35
            trail.LightEmission = 0.9
            trail.Parent = root
            table.insert(vipTrailObjects, trail)
        end
        table.insert(vipTrailObjects, a0)
        table.insert(vipTrailObjects, a1)
    end
    local function waterWalkStop()
        waterWalkOn = false
        if waterConn then waterConn:Disconnect(); waterConn = nil end
        if waterPlatform then waterPlatform:Destroy(); waterPlatform = nil end
    end
    local function waterWalkStart()
        local _, hum, root = getMoveCharacter()
        if not hum or not root then notify("Personagem ainda não carregou") return end
        waterWalkStop()
        local part = Instance.new("Part")
        part.Name = "KawanVIPWaterWalk"
        part.Size = Vector3.new(7, 0.5, 7)
        part.Transparency = 1
        part.Anchored = true
        part.CanCollide = true
        part.CanTouch = false
        part.CanQuery = false
        part.Parent = workspace
        waterPlatform = part
        waterWalkOn = true
        waterConn = RunService.Heartbeat:Connect(function()
            local _, h, r = getMoveCharacter()
            if not waterWalkOn or not h or not r or h.Health <= 0 then waterWalkStop(); return end
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = {player.Character, waterPlatform}
            local hit = workspace:Raycast(r.Position, Vector3.new(0, -18, 0), params)
            if hit and hit.Material == Enum.Material.Water then
                waterPlatform.CFrame = CFrame.new(r.Position.X, hit.Position.Y + 0.1, r.Position.Z)
                waterPlatform.CanCollide = true
            else
                waterPlatform.CanCollide = false
                waterPlatform.CFrame = CFrame.new(r.Position - Vector3.new(0, 4, 0))
            end
        end)
    end
    local function landingBurst()
        local _, _, root = getMoveCharacter()
        if not root then return end
        local orb = Instance.new("Part")
        orb.Name = "KawanVIPLandingFX"
        orb.Shape = Enum.PartType.Ball
        orb.Material = Enum.Material.Neon
        orb.Color = Color3.fromRGB(35, 155, 255)
        orb.Transparency = 0.25
        orb.Anchored = true
        orb.CanCollide = false
        orb.CanTouch = false
        orb.CanQuery = false
        orb.Size = Vector3.new(1, 1, 1)
        orb.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.5, 0))
        orb.Parent = workspace
        local tw = TweenService:Create(orb, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size=Vector3.new(12, 1, 12), Transparency=1})
        tw:Play()
        tw.Completed:Connect(function() if orb.Parent then orb:Destroy() end end)
    end
    vipCard:Toggle("Aura elétrica VIP", false, function(on)
        setVipAura(on); notify(on and "Aura VIP ativada" or "Aura VIP desativada")
    end)
    vipCard:Toggle("Asas de fogo / rastro", false, function(on)
        setVipWings(on); notify(on and "Rastro de fogo ativado" or "Rastro desativado")
    end)
    vipCard:Toggle("Passos aquáticos", false, function(on)
        if on then waterWalkStart() else waterWalkStop() end
        notify(on and "Passos aquáticos ativados" or "Passos aquáticos desativados")
    end)
    vipCard:Toggle("Pouso impactante", false, function(on)
        landingFxEnabled = on
        if landingConn then landingConn:Disconnect(); landingConn = nil end
        if on then
            local _, hum = getMoveCharacter()
            if hum then landingConn = hum.StateChanged:Connect(function(_, state)
                if state == Enum.HumanoidStateType.Landed then landingBurst() end
            end) end
        end
        notify(on and "Efeito de pouso ativado" or "Efeito de pouso desativado")
    end)
    vipCard:Note("Efeitos visuais locais para o seu personagem. O pouso cria uma onda azul ao tocar o chão.")

    -- Veículos VIP: garagem simples de sessão, retorno, hover, manobras e visual neon.
    local garageCard = sub:Card("Garagem VIP", "🅿️", 2)
    local vehicleStyleCard = sub:Card("Estilo e manobras", "✨", 1)
    local savedVehicleModel, savedVehiclePivot = nil, nil
    local hoverEnabled, hoverBody = false, nil
    local neonTrailEnabled, neonTrailObjects = false, {}
    local autoPilotEnabled, autoPilotConn = false, nil

    local function getDrivenModel()
        local root = findDrivenVehicle()
        if not root then return nil, nil end
        return root:FindFirstAncestorOfClass("Model"), root
    end
    local function saveVehicle()
        local model = getDrivenModel()
        if not model then notify("Entre no banco do motorista para salvar") return end
        savedVehicleModel = model
        savedVehiclePivot = model:GetPivot()
        notify("Veículo salvo na garagem desta sessão")
    end
    local function returnVehicle()
        if not savedVehicleModel or not savedVehicleModel.Parent then notify("Nenhum veículo salvo nesta sessão") return end
        local _, _, charRoot = getMoveCharacter()
        if not charRoot then notify("Personagem ainda não carregou") return end
        local seat = savedVehicleModel:FindFirstChildWhichIsA("VehicleSeat", true)
        if seat and seat.Occupant and seat.Occupant ~= (player.Character and player.Character:FindFirstChildOfClass("Humanoid")) then
            notify("Esse veículo está ocupado por outro jogador") return
        end
        local target = charRoot.CFrame * CFrame.new(0, 0, -14)
        pcall(function() savedVehicleModel:PivotTo(target) end)
        notify("Veículo reposicionado perto de você (se a rede permitir)")
    end
    local function setVehicleHover(on)
        hoverEnabled = on
        if hoverBody then hoverBody:Destroy(); hoverBody = nil end
        if not on then return end
        local root = findDrivenVehicle()
        if not root then hoverEnabled = false; notify("Entre no veículo como motorista primeiro"); return end
        hoverBody = Instance.new("BodyPosition")
        hoverBody.Name = "KawanVehicleHover"
        hoverBody.MaxForce = Vector3.new(0, 1e7, 0)
        hoverBody.P = 6500
        hoverBody.D = 900
        hoverBody.Position = root.Position
        hoverBody.Parent = root
        task.spawn(function()
            while hoverEnabled and hoverBody and hoverBody.Parent do
                local current = findDrivenVehicle()
                if not current then break end
                hoverBody.Position = Vector3.new(current.Position.X, current.Position.Y + 1.8, current.Position.Z)
                task.wait(0.08)
            end
            if hoverEnabled then hoverEnabled = false end
            if hoverBody then hoverBody:Destroy(); hoverBody = nil end
        end)
    end
    local function setNeonTrail(on)
        neonTrailEnabled = on
        clearObjects(neonTrailObjects)
        local root = findDrivenVehicle()
        if not on or not root then if on then notify("Entre no veículo como motorista primeiro") end return end
        local a0 = Instance.new("Attachment")
        a0.Position = Vector3.new(-1.2, 0, 1.8)
        a0.Parent = root
        local a1 = Instance.new("Attachment")
        a1.Position = Vector3.new(1.2, 0, 1.8)
        a1.Parent = root
        local tr = Instance.new("Trail")
        tr.Name = "KawanVehicleNeonTrail"
        tr.Attachment0 = a0
        tr.Attachment1 = a1
        tr.Color = ColorSequence.new(Color3.fromRGB(0, 145, 255), Color3.fromRGB(150, 225, 255))
        tr.Lifetime = 0.5
        tr.LightEmission = 1
        tr.Parent = root
        table.insert(neonTrailObjects, tr)
        table.insert(neonTrailObjects, a0)
        table.insert(neonTrailObjects, a1)
    end
    local function vehicleStunt(kind)
        local root = findDrivenVehicle()
        if not root then notify("Entre no veículo como motorista primeiro") return end
        if kind == "pulo" then
            root.AssemblyLinearVelocity = root.AssemblyLinearVelocity + Vector3.new(0, 55, 0)
        elseif kind == "giro" then
            root.AssemblyAngularVelocity = root.CFrame.RightVector * 5
        elseif kind == "hidraulica" then
            root.AssemblyAngularVelocity = root.CFrame.RightVector * -3.5
        end
        notify(kind == "pulo" and "Pulo hidráulico aplicado" or (kind == "giro" and "Giro aéreo aplicado" or "Hidráulica aplicada"))
    end
    local function startAutoPilot()
        local root = findDrivenVehicle()
        if not root then notify("Entre no veículo como motorista primeiro") return end
        if not markedPosition then notify("Marque primeiro um destino com Marcar posição atual") return end
        if autoPilotConn then autoPilotConn:Disconnect(); autoPilotConn = nil end
        autoPilotEnabled = true
        autoPilotConn = RunService.Heartbeat:Connect(function()
            local current = findDrivenVehicle()
            if not autoPilotEnabled or not current or not markedPosition then
                if autoPilotConn then autoPilotConn:Disconnect(); autoPilotConn = nil end
                autoPilotEnabled = false
                return
            end
            local delta = markedPosition.Position - current.Position
            local flat = Vector3.new(delta.X, 0, delta.Z)
            if flat.Magnitude < 12 then
                autoPilotEnabled = false
                autoPilotConn:Disconnect(); autoPilotConn = nil
                current.AssemblyLinearVelocity = Vector3.new(0, current.AssemblyLinearVelocity.Y, 0)
                notify("Destino alcançado")
                return
            end
            local dir = flat.Unit
            current.AssemblyLinearVelocity = Vector3.new(dir.X * 48, current.AssemblyLinearVelocity.Y, dir.Z * 48)
            current.CFrame = CFrame.lookAt(current.Position, current.Position + dir)
        end)
        notify("Piloto automático experimental ativado até o ponto marcado")
    end

    garageCard:Button("Salvar veículo atual", "SALVAR", saveVehicle)
    garageCard:Button("Chamar / retornar veículo salvo", "CHAMAR", returnVehicle)
    garageCard:Button("Piloto automático até o ponto marcado", "PILOTO", startAutoPilot)
    garageCard:Note("Garagem salva o veículo somente durante esta sessão. Reposicionar e dirigir automaticamente dependem da propriedade de rede e das regras do seu jogo.")
    vehicleStyleCard:Toggle("Modo Hover", false, function(on)
        setVehicleHover(on); notify(on and "Hover ativado" or "Hover desativado")
    end)
    vehicleStyleCard:Toggle("Rastro neon azul", false, function(on)
        setNeonTrail(on); notify(on and "Rastro neon ativado" or "Rastro neon desativado")
    end)
    vehicleStyleCard:Button("Pulo hidráulico", "PULAR", function() vehicleStunt("pulo") end)
    vehicleStyleCard:Button("Giro aéreo 360°", "GIRO", function() vehicleStunt("giro") end)
    vehicleStyleCard:Button("Hidráulica dianteira", "HIDRO", function() vehicleStunt("hidraulica") end)
    vehicleStyleCard:Note("O modo helicóptero usa o controle de voo do veículo. Manobras são impulsos físicos do veículo.")

    -- Invisibilidade local do veículo: guarda e restaura a transparência original.
    local vehicleInvisible = false
    local invisibleSaved = {}
    local function setVehicleInvisible(on)
        if on == vehicleInvisible then return end
        if on then
            local model = getDrivenModel()
            if not model then notify("Entre no veículo como motorista primeiro") return end
            table.clear(invisibleSaved)
            for _, obj in ipairs(model:GetDescendants()) do
                if obj:IsA("BasePart") or obj:IsA("Decal") or obj:IsA("Texture") then
                    invisibleSaved[obj] = obj.Transparency
                    obj.Transparency = 1
                end
            end
            vehicleInvisible = true
            notify("Carro invisível ativado (somente na sua tela)")
        else
            for obj, transparency in pairs(invisibleSaved) do
                if obj and obj.Parent then obj.Transparency = transparency end
            end
            table.clear(invisibleSaved)
            vehicleInvisible = false
            notify("A aparência original do veículo foi restaurada")
        end
    end
    local invisibleCard = sub:Card("Carro invisível", "👻", 2)
    invisibleCard:Toggle("Ocultar meu veículo", false, setVehicleInvisible)
    invisibleCard:Note("A transparência é aplicada localmente e pode não ficar invisível para os outros jogadores. Desative para restaurar as peças.")

    -- Três atalhos de garagem para veículos usados nesta sessão.
    local favoriteCard = sub:Card("Atalhos da garagem", "⭐", 1)
    local favoriteVehicles = {}
    local function saveFavorite(slot)
        local model = getDrivenModel()
        if not model then notify("Entre no veículo como motorista primeiro") return end
        favoriteVehicles[slot] = model
        notify("Veículo salvo no atalho " .. slot)
    end
    local function callFavorite(slot)
        local model = favoriteVehicles[slot]
        if not model or not model.Parent then notify("Atalho " .. slot .. " vazio ou veículo removido") return end
        local _, _, charRoot = getMoveCharacter()
        if not charRoot then notify("Personagem ainda não carregou") return end
        local seat = model:FindFirstChildWhichIsA("VehicleSeat", true)
        local ownHum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
        if seat and seat.Occupant and seat.Occupant ~= ownHum then
            notify("Esse veículo está ocupado por outro jogador")
            return
        end
        local ok = pcall(function() model:PivotTo(charRoot.CFrame * CFrame.new(0, 0, -12)) end)
        notify(ok and ("Atalho " .. slot .. " chamado") or "Não foi possível reposicionar o veículo")
    end
    for slot = 1, 3 do
        favoriteCard:Button("Salvar veículo no atalho " .. slot, "SALVAR", function() saveFavorite(slot) end)
        favoriteCard:Button("Chamar veículo do atalho " .. slot, "CHAMAR", function() callFavorite(slot) end)
    end
    favoriteCard:Note("Os atalhos guardam referências durante esta sessão. O reposicionamento depende das permissões de rede e das regras do seu jogo.")

    -- Bônus VIP separado do nitro comum já existente.
    local vipVehicleCard = sub:Card("Bônus VIP de veículos", "💎", 2)
    vipVehicleCard:Button("Nitro VIP", "VIP NITRO", function()
        local root = findDrivenVehicle()
        if not root then notify("Entre no veículo como motorista primeiro") return end
        local direction = root.CFrame.LookVector
        local velocity = root.AssemblyLinearVelocity
        root.AssemblyLinearVelocity = Vector3.new(direction.X * 190, math.max(velocity.Y, 12), direction.Z * 190)
        notify("Nitro VIP ativado")
    end)
    vipVehicleCard:Toggle("Rastro neon VIP", false, function(on)
        setNeonTrail(on)
        notify(on and "Rastro neon VIP ativado" or "Rastro neon VIP desativado")
    end)
    vipVehicleCard:Button("Pulo VIP do veículo", "PULO VIP", function() vehicleStunt("pulo") end)
    vipVehicleCard:Note("Bônus visuais e impulsos locais. Não concede acesso a veículos bloqueados pelo servidor do jogo.")

    player.CharacterAdded:Connect(function()
        task.wait(0.45)
        if airWalkEnabled then startAirWalk() end
        if wallRunEnabled then startWallRun() end
        if jumpBoostEnabled then savedJumpPower = nil; applyJumpBoost() end
        if sprintEnabled then savedWalkSpeed = nil; applySprint(true) end
        if vipAuraOn then setVipAura(true) end
        if vipTrailOn then setVipWings(true) end
        if landingConn then landingConn:Disconnect(); landingConn = nil end
        local _, newHum = getMoveCharacter()
        if newHum and landingFxEnabled then
            landingConn = newHum.StateChanged:Connect(function(_, state)
                if state == Enum.HumanoidStateType.Landed then landingBurst() end
            end)
        end
    end)
    player.CharacterRemoving:Connect(function()
        -- Desconecta os efeitos do personagem antigo, mas preserva os toggles
        -- para reativá-los automaticamente quando o novo personagem carregar.
        if airWalkConn then airWalkConn:Disconnect(); airWalkConn = nil end
        if airWalkPlatform then airWalkPlatform:Destroy(); airWalkPlatform = nil end
        if wallRunConn then wallRunConn:Disconnect(); wallRunConn = nil end
        local oldCharacter = player.Character
        local oldHumanoid = oldCharacter and oldCharacter:FindFirstChildOfClass("Humanoid")
        if oldHumanoid and wallRunOldAutoRotate ~= nil then
            oldHumanoid.AutoRotate = wallRunOldAutoRotate
        end
        wallRunOldAutoRotate = nil
        if savedWalkSpeed ~= nil then
            local oldHum = oldCharacter and oldCharacter:FindFirstChildOfClass("Humanoid")
            if oldHum then oldHum.WalkSpeed = savedWalkSpeed end
        end
        savedWalkSpeed = nil
    end)
    gui.Destroying:Connect(function()
        stopAirWalk()
        stopWallRun()
        jumpBoostEnabled = false
        applyJumpBoost()
        infiniteJumpEnabled = false
        setSlowFall(false)
        sprintEnabled = false
        applySprint(false)
        stopVehicleFly()
        if vehicleInvisible then setVehicleInvisible(false) end
        stopSuperman()
        waterWalkStop()
        setVipAura(false)
        setVipWings(false)
        if landingConn then landingConn:Disconnect(); landingConn = nil end
        if hoverBody then hoverBody:Destroy(); hoverBody = nil end
        hoverEnabled = false
        clearObjects(neonTrailObjects)
        if autoPilotConn then autoPilotConn:Disconnect(); autoPilotConn = nil end
        autoPilotEnabled = false
        antiFlipEnabled = false
        cruiseEnabled = false
        if cruiseConn then cruiseConn:Disconnect(); cruiseConn = nil end
        if antiFlipConn then antiFlipConn:Disconnect(); antiFlipConn = nil end
        if antiFlipGyro then antiFlipGyro:Destroy(); antiFlipGyro = nil end
        if jumpRequestConn then jumpRequestConn:Disconnect(); jumpRequestConn = nil end
    end)
end

-- Ferramentas
do
    local sw = P.Tools:SubTab("⏱️ Relógios")
    local swCard = sw:Card("Cronômetro", "⏱️", 1)
    local swLabel = swCard:Info()
    local running, startAt, accum = false, 0, 0
    local function elapsed() return accum + (running and (os.clock() - startAt) or 0) end
    swLabel.Text = "00:00:00"
    swCard:Button("Iniciar / pausar", "ALTERNAR", function()
        if running then accum = elapsed() running = false
        else startAt = os.clock() running = true end
    end)
    swCard:Button("Zerar", "ZERAR", function() running, accum = false, 0 end)
    task.spawn(function()
        while gui.Parent do
            swLabel.Text = fmtTime(elapsed())
            task.wait(0.2)
        end
    end)

    local notes = sw:Card("Bloco de notas", "🗒️", 2)
    local noteText = ""
    notes:TextBox("Anotação (vale só nesta sessão):", "Escreva aqui", "", function(t) noteText = t end)
    notes:Button("Copiar nota", "COPIAR", function() copyText(noteText) end)

    local move = P.Tools:SubTab("🏃 Movimento")
    local moveCard = move:Card("Movimentação de teste", "🏃", 1)
    local baseWalk, baseJump = 16, 50
    local flyOn, noclipOn = false, false
    local flyConn, noclipConn
    local flyBV, flyBG
    local function currentCharacter()
        local char = player.Character
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        local root = char and char:FindFirstChild("HumanoidRootPart")
        return char, hum, root
    end
    local function stopFly()
        flyOn = false
        MobilePad.Hide()
        if flyConn then flyConn:Disconnect() flyConn = nil end
        if flyBV then flyBV:Destroy() flyBV = nil end
        if flyBG then flyBG:Destroy() flyBG = nil end
        local _, hum = currentCharacter()
        if hum then hum.PlatformStand = false end
    end
    local function startFly()
        local char, hum, root = currentCharacter()
        if not char or not hum or not root then notify("Personagem indisponível") return end
        stopFly()
        flyOn = true
        MobilePad.Show("VOO")
        hum.PlatformStand = true
        flyBV = new("BodyVelocity", {Name = "KawanFlyVelocity", MaxForce = Vector3.new(1e5, 1e5, 1e5),
            Velocity = Vector3.zero}, root)
        flyBG = new("BodyGyro", {Name = "KawanFlyGyro", MaxTorque = Vector3.new(1e5, 1e5, 1e5),
            P = 1e4, CFrame = workspace.CurrentCamera.CFrame}, root)
        flyConn = RunService.RenderStepped:Connect(function()
            if not flyOn or not root.Parent then stopFly() return end
            local cam = workspace.CurrentCamera
            if not cam then return end
            local direction = Vector3.zero
            if UIS:IsKeyDown(Enum.KeyCode.W) or MobilePad.Down("forward") then direction += cam.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.S) or MobilePad.Down("back") then direction -= cam.CFrame.LookVector end
            if UIS:IsKeyDown(Enum.KeyCode.D) or MobilePad.Down("right") then direction += cam.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.A) or MobilePad.Down("left") then direction -= cam.CFrame.RightVector end
            if UIS:IsKeyDown(Enum.KeyCode.Space) or MobilePad.Down("up") then direction += Vector3.yAxis end
            if UIS:IsKeyDown(Enum.KeyCode.LeftControl) or MobilePad.Down("down") then direction -= Vector3.yAxis end
            flyBV.Velocity = direction.Magnitude > 0 and direction.Unit * 55 or Vector3.zero
            flyBG.CFrame = cam.CFrame
        end)
        notify(UIS.TouchEnabled and not UIS.KeyboardEnabled and "Voo ativado • use os botões na tela" or "Voo ativado • WASD, Espaço e Ctrl")
    end
    moveCard:Slider("Velocidade", 16, 100, 16, function(v)
        local _, hum = currentCharacter()
        if hum then hum.WalkSpeed = v end
    end)
    moveCard:Slider("Força do pulo", 50, 150, 50, function(v)
        local _, hum = currentCharacter()
        if hum then hum.UseJumpPower = true hum.JumpPower = v end
    end)
    moveCard:Toggle("Voo", false, function(on)
        if on then startFly() else stopFly() notify("Voo desativado") end
    end)
    moveCard:Toggle("Noclip", false, function(on)
        noclipOn = on
        if noclipConn then noclipConn:Disconnect() noclipConn = nil end
        if on then
            noclipConn = RunService.Stepped:Connect(function()
                local char = player.Character
                if char then
                    for _, part in ipairs(char:GetDescendants()) do
                        if part:IsA("BasePart") then part.CanCollide = false end
                    end
                end
            end)
            notify("Noclip ativado")
        else
            local char = player.Character
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then part.CanCollide = true end
                end
            end
            notify("Noclip desativado")
        end
    end)
    moveCard:Button("Restaurar movimento", "RESETAR", function()
        stopFly()
        noclipOn = false
        if noclipConn then noclipConn:Disconnect() noclipConn = nil end
        local char, hum = currentCharacter()
        if hum then hum.WalkSpeed = baseWalk hum.UseJumpPower = true hum.JumpPower = baseJump end
        if char then
            for _, part in ipairs(char:GetDescendants()) do
                if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then part.CanCollide = true end
            end
        end
        notify("Movimento restaurado")
    end)
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        if flyOn then startFly() end
    end)
    gui.Destroying:Connect(function()
        stopFly()
        if noclipConn then noclipConn:Disconnect() noclipConn = nil end
    end)

    local sv = P.Tools:SubTab("🖥️ Servidor")
    local svCard = sv:Card("Informações", "🖥️", 1)
    local svInfo = svCard:List()
    task.spawn(function()
        while gui.Parent do
            svInfo.Text = string.format("Jogadores: %d/%d\nTempo do servidor: %s\nPlace ID: %d\nJob ID: %s",
                #Players:GetPlayers(), Players.MaxPlayers, fmtTime(workspace.DistributedGameTime),
                game.PlaceId, string.sub(game.JobId, 1, 8) .. (game.JobId ~= "" and "…" or "(Studio)"))
            task.wait(1)
        end
    end)
    local act = sv:Card("Ações", "⚙️", 2)
    act:Button("Copiar Job ID", "COPIAR", function() copyText(game.JobId) end)
    act:Button("Copiar Place ID", "COPIAR", function() copyText(tostring(game.PlaceId)) end)
    act:Button("Copiar posição", "COPIAR", function()
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if root then
            local p = root.Position
            copyText(string.format("%d, %d, %d", math.floor(p.X), math.floor(p.Y), math.floor(p.Z)))
        end
    end)
    act:Button("Reentrar neste servidor", "REENTRAR", function()
        notify("Reentrando…")
        pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player) end)
    end)
end

-- Estilo (cores e aparência)
local rainbowToggle
do
    local themeNames, bgNames = {}, {}
    for _, t in ipairs(Themes) do table.insert(themeNames, t.name) end
    for _, b in ipairs(Backgrounds) do table.insert(bgNames, b.name) end

    local sub = P.Style:SubTab("🎨 Cores")
    local theme = sub:Card("Tema", "🎨", 1)
    theme:Dropdown("Cor de destaque:", themeNames, 1, function(_, i)
        if rainbowToggle then rainbowToggle:Set(false) end
        Settings.rainbow = false
        Settings.themeIdx = i
        Settings.smoothAccent(Themes[i].accent)
        notify("Tema: " .. Themes[i].name)
    end)
    rainbowToggle = theme:Toggle("🌈 Modo arco-íris", false, function(on)
        Settings.rainbow = on
        if on then Settings.ownerPalette = nil end
    end)
    theme:Dropdown("Cor de fundo:", bgNames, 1, function(_, i)
        Settings.bgIdx = i
        setBackground(Backgrounds[i])
        notify("Fundo: " .. Backgrounds[i].name)
    end)

    local custom = sub:Card("Cor personalizada", "🖌️", 2)
    local rgbv = {r = math.floor(accent.R * 255), g = math.floor(accent.G * 255), b = math.floor(accent.B * 255)}
    local function applyRGB()
        Settings.rainbow = false
        rainbowToggle:Set(false)
        setAccent(Color3.fromRGB(rgbv.r, rgbv.g, rgbv.b))
    end
    custom:Slider("Vermelho (R)", 0, 255, rgbv.r, function(v) rgbv.r = v applyRGB() end)
    custom:Slider("Verde (G)", 0, 255, rgbv.g, function(v) rgbv.g = v applyRGB() end)
    custom:Slider("Azul (B)", 0, 255, rgbv.b, function(v) rgbv.b = v applyRGB() end)
    custom:Swatch("Prévia")

    local look = P.Style:SubTab("🪟 Janela")
    local shape = look:Card("Formato", "📐", 1)
    shape:Slider("Arredondamento", 0, 20, 10, function(v)
        for i = #cornerRefs, 1, -1 do
            local r = cornerRefs[i]
            if r.inst.Parent then r.inst.CornerRadius = UDim.new(0, math.max(v + r.offset, 0))
            else table.remove(cornerRefs, i) end
        end
    end)
    shape:Slider("Opacidade do painel (%)", 50, 100, 100, function(v)
        baseGT = 1 - v / 100
        if main.Visible then main.GroupTransparency = baseGT end
    end)
    shape:Slider("Tamanho do painel (%)", 70, 130, 100, function(v)
        userScale = v / 100
        refreshScale()
    end)

    local name = look:Card("Nome do painel", "✏️", 2)
    name:TextBox("Título (máx. 10 letras):", "KAWAN", "KAWAN", function(txt)
        txt = txt:sub(1, 10)
        brand.Text = (txt ~= "" and txt or "KAWAN")
        Settings.title = brand.Text
    end)
    name:Note("Troque pelo nome do seu servidor ou da sua facção.")
end

-- Ajustes
local setOpen
do
    local sub = P.Settings:SubTab("✨ Animações")
    local fx = sub:Card("Efeitos", "✨", 1)
    fx:Toggle("Animações", true, function(on) Settings.anim = on end)
    fx:Toggle("Efeito de clique", true, function(on) Settings.ripple = on end)
    fx:Toggle("Linha animada no topo", true, function(on)
        Settings.topline = on
        topLine.Visible = on
    end)
    fx:Toggle("Brilho animado no título", true, function(on)
        Settings.glow = on
        if not on then brandGrad.Offset = Vector2.new(0, 0) end
    end)
    local speed = sub:Card("Velocidade", "⚡", 2)
    speed:Slider("Velocidade das animações (%)", 50, 200, 100, function(v) Settings.speed = v / 100 end)
    local xm = sub:Card("Natal", "🎄", 3)
    Settings.xmasToggles = {}
    Settings.xmasToggles.snow = xm:Toggle("❄️ Neve na tela + crosta", true, function(on) Settings.xmas.snow = on Settings.xmasApply() end)
    Settings.xmasToggles.hat = xm:Toggle("🎅 Gorro de Papai Noel", true, function(on) Settings.xmas.hat = on Settings.xmasApply() end)
    Settings.xmasToggles.lights = xm:Toggle("💡 Luzes de Natal", true, function(on) Settings.xmas.lights = on Settings.xmasApply() end)

    local gen = P.Settings:SubTab("🎛️ Geral")
    local prefs = gen:Card("Preferências", "🎛️", 1)
    prefs:Toggle("Som de clique", true, function(on) clickEnabled = on end)
    prefs:Toggle("Notificações", true, function(on) notifyEnabled = on end)
    prefs:Button("Posição da janela", "CENTRALIZAR", function()
        tween(main, 0.35, {Position = UDim2.new(0.5, 0, 0.5, 0)}, Enum.EasingStyle.Back)
    end)

    local keys = {"RightShift", "Insert", "RightControl", "Home", "F4"}
    local keyCard = gen:Card("Atalho", "⌨️", 2)
    keyCard:Dropdown("Tecla para abrir/fechar:", keys, 1, function(k)
        Settings.toggleKey = Enum.KeyCode[k]
        notify("Tecla: " .. k)
    end)
end

-- Página interna mantida oculta para compatibilidade; geração/gerenciamento local de keys removidos.
P.Keys = newPage("Chaves", "🔑")
P.Keys.item.Visible = false

-- Exclusivo do Dono (só aparece com key admin) • tudo local e visual
local ownerCat = newCategory("Exclusivo")
P.Owner = newPage("Dono", "👑")
ownerCat.Visible = false
P.Owner.item.Visible = false

local resetOwner
do
    local ownerState = {crown = true, tag = false, tagText = "👑 DONO", aura = false}
    local tagGui, auraEmitter
    local handles = {}

    local function applyCrown() crown.Visible = isKeyAdmin and ownerState.crown end
    local function applyTag()
        if tagGui then tagGui:Destroy() tagGui = nil end
        if not ownerState.tag then return end
        local head = player.Character and player.Character:FindFirstChild("Head")
        if not head then return end
        tagGui = new("BillboardGui", {Name = "KawanTag", Adornee = head, Size = UDim2.fromOffset(200, 30),
            StudsOffset = Vector3.new(0, 2.5, 0)}, head)
        local l = label(tagGui, {Size = UDim2.fromScale(1, 1), Text = ownerState.tagText, TextSize = 18,
            Font = Enum.Font.GothamBlack, TextStrokeTransparency = 0.4})
        track(l, "TextColor3")
    end
    local function applyAura(on)
        if auraEmitter then auraEmitter:Destroy() auraEmitter = nil end
        if not on then return end
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        auraEmitter = new("ParticleEmitter", {Rate = 18, Lifetime = NumberRange.new(1, 1.6),
            Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(180, 180), LightEmission = 1,
            Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0)}),
            Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1)}),
            Color = ColorSequence.new(accent)}, root)
    end
    table.insert(accentHooks, function()
        if auraEmitter then auraEmitter.Color = ColorSequence.new(accent) end
    end)
    player.CharacterAdded:Connect(function()
        task.wait(1)
        if ownerState.tag then applyTag() end
        if ownerState.aura then applyAura(true) end
    end)

    -- Filtros de tela
    local filters = {
        {"Normal"},
        {"Vibrante", sat = 0.45, con = 0.1, tint = rgb(255, 255, 255)},
        {"Noir", sat = -1, con = 0.2, tint = rgb(255, 255, 255)},
        {"Quente", sat = 0.1, con = 0.05, tint = rgb(255, 225, 190)},
        {"Frio", sat = 0.05, con = 0.05, tint = rgb(190, 215, 255)},
        {"Sonhador", sat = 0.2, con = -0.05, tint = rgb(255, 215, 245)},
    }
    local function applyFilter(i)
        local f = Lighting:FindFirstChild("KawanFilter")
        if i == 1 then
            if f then f:Destroy() end
            return
        end
        local d = filters[i]
        f = f or new("ColorCorrectionEffect", {Name = "KawanFilter"}, Lighting)
        f.Saturation, f.Contrast, f.TintColor = d.sat, d.con, d.tint
    end

    -- Paletas animadas
    local palettes = {
        {"Nenhum"},
        {"Real", rgb(255, 195, 70), rgb(255, 245, 210)},
        {"Aurora", rgb(35, 205, 255), rgb(185, 105, 255), rgb(255, 120, 200)},
        {"Fogo", rgb(255, 90, 105), rgb(255, 150, 60), rgb(255, 195, 70)},
        {"Oceano", rgb(70, 140, 255), rgb(35, 205, 255), rgb(80, 235, 155)},
    }

    -- Streamer / posição / anúncio
    local function applyStreamer()
        profileName.Text = streamer and "••••••" or player.DisplayName
        avatar.ImageTransparency = streamer and 1 or 0
    end
    local posLabel = new("TextLabel", {Name = "KawanPos", Position = UDim2.fromOffset(12, 46), Size = UDim2.fromOffset(230, 24),
        BackgroundTransparency = 0.2, BorderSizePixel = 0, Visible = false, TextColor3 = C.text, TextSize = 12,
        Font = Enum.Font.GothamBold}, gui)
    bg(posLabel, "BackgroundColor3", "window")
    corner(posLabel, 8)
    track(stroke(posLabel, accent, 1, 0.5), "Color")
    task.spawn(function()
        while gui.Parent do
            if posLabel.Visible then
                local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
                local pp = root and root.Position or Vector3.zero
                posLabel.Text = string.format("📍 %d, %d, %d  •  🕒 %s", math.floor(pp.X), math.floor(pp.Y), math.floor(pp.Z), os.date("%H:%M"))
            end
            task.wait(0.25)
        end
    end)
    local function announce(text)
        text = string.sub(text or "", 1, 80)
        if text == "" then return end
        local b = new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -60),
            Size = UDim2.fromOffset(420, 44), BorderSizePixel = 0, ZIndex = 90}, gui)
        bg(b, "BackgroundColor3", "window")
        corner(b, 10)
        track(stroke(b, accent, 1.5, 0.2), "Color")
        label(b, {Size = UDim2.new(1, -24, 1, 0), Position = UDim2.fromOffset(12, 0), Text = "📢  " .. text,
            TextSize = 14, Font = Enum.Font.GothamBold, TextWrapped = true})
        tween(b, 0.4, {Position = UDim2.new(0.5, 0, 0, 18)}, Enum.EasingStyle.Back)
        task.delay(4, function()
            tween(b, 0.3, {Position = UDim2.new(0.5, 0, 0, -60)})
            task.wait(0.35)
            b:Destroy()
        end)
    end
    local announceText = ""

    -- Conteúdo
    local sub = P.Owner:SubTab("✨ Exclusivos")
    local id = sub:Card("Identidade", "👑", 1)
    handles.crown = id:Toggle("Coroa animada no perfil", true, function(on) ownerState.crown = on applyCrown() end)
    handles.tag = id:Toggle("Tag sobre a cabeça", false, function(on) ownerState.tag = on applyTag() end)
    id:TextBox("Texto da tag:", "👑 DONO", "👑 DONO", function(txt)
        ownerState.tagText = (txt ~= "" and string.sub(txt, 1, 20) or "👑 DONO")
        if ownerState.tag then applyTag() end
    end)
    id:Note("A tag aparece só para você (visual local).")

    local th = sub:Card("Temas do Dono", "💎", 2)
    local palNames = {}
    for _, pl in ipairs(palettes) do table.insert(palNames, pl[1]) end
    handles.pal = th:Dropdown("Paleta animada:", palNames, 1, function(_, i)
        if i == 1 then
            Settings.ownerPalette = nil
        else
            Settings.rainbow = false
            if rainbowToggle then rainbowToggle:Set(false) end
            local colors = {}
            for k = 2, #palettes[i] do table.insert(colors, palettes[i][k]) end
            Settings.ownerPalette = colors
        end
        notify("💎 Paleta: " .. palNames[i])
    end)
    th:Note("As cores do painel ficam mudando suavemente entre as da paleta.")

    local fx = P.Owner:SubTab("🎆 Efeitos")
    local fl = fx:Card("Filtros de tela", "🎞️", 1)
    local filterNames = {}
    for _, f in ipairs(filters) do table.insert(filterNames, f[1]) end
    handles.filter = fl:Dropdown("Filtro:", filterNames, 1, function(_, i) applyFilter(i) end)
    local au = fx:Card("Aura", "🌟", 2)
    handles.aura = au:Toggle("Partículas ao redor do personagem", false, function(on)
        ownerState.aura = on
        applyAura(on)
    end)
    au:Note("Efeito visual só no seu cliente, na cor do tema.")

    local pn = P.Owner:SubTab("🛠️ Painel")
    local pv = pn:Card("Privacidade", "🕶️", 1)
    handles.streamer = pv:Toggle("Modo streamer (esconde nome e foto)", false, function(on)
        streamer = on
        applyStreamer()
    end)
    local ex = pn:Card("Extras", "📍", 2)
    handles.pos = ex:Toggle("Mostrar posição e hora", false, function(on) posLabel.Visible = on end)
    local an = pn:Card("Anúncio na tela", "📢", 1)
    an:TextBox("Mensagem (máx. 80 letras):", "Bem-vindos ao servidor!", "", function(txt) announceText = txt end)
    an:Button("Mostrar banner", "ENVIAR", function() announce(announceText) end)
    an:Note("O banner aparece só na sua tela.")

    resetOwner = function()
        handles.crown:Set(true)
        handles.tag:Set(false)
        handles.aura:Set(false)
        handles.streamer:Set(false)
        handles.pos:Set(false)
        handles.pal:Set(1)
        handles.filter:Set(1)
        ownerState.tag, ownerState.aura, ownerState.crown = false, false, true
        applyTag()
        applyAura(false)
        applyFilter(1)
        Settings.ownerPalette = nil
        streamer = false
        applyStreamer()
        posLabel.Visible = false
        crown.Visible = false
    end
end

--------------------------------------------------------------------
-- 🎄 v7: Natal+, personalização, utilidades e roleplay
--------------------------------------------------------------------
Settings.safe = function(name, fn)
    local ok, err = pcall(fn)
    if not ok then
        warn("[Kawan] erro em " .. name .. ": " .. tostring(err))
        pcall(notify, "⚠️ Erro em: " .. name)
    end
end

Settings.applyLook = function(color, bgIdx, instant)
    if Settings.rainbow then
        Settings.rainbow = false
        if rainbowToggle then rainbowToggle:Set(false) end
    end
    Settings.ownerPalette = nil
    if color then
        if instant then setAccent(color) else Settings.smoothAccent(color) end
    end
    if bgIdx and Backgrounds[bgIdx] then
        Settings.bgIdx = bgIdx
        setBackground(Backgrounds[bgIdx])
    end
end

-- ===== Natal: enfeites, contagem, neve, luzes =====
Settings.safe("Natal: enfeites, contagem, neve, luzes", function()
    local XM = Settings.xmas
    local sub = P.Xmas:SubTab("🎄 Enfeites")

    -- Contagem regressiva para o Natal
    local function christmasLeft()
        local now = os.time()
        local y = tonumber(os.date("%Y", now))
        local target = os.time({year = y, month = 12, day = 25, hour = 0, min = 0, sec = 0})
        if now >= target and now < target + 86400 then return 0, true end
        if now >= target + 86400 then
            target = os.time({year = y + 1, month = 12, day = 25, hour = 0, min = 0, sec = 0})
        end
        return target - now, false
    end
    local function fmtLeft(s)
        s = math.max(0, math.floor(s))
        return string.format("%dd %02dh %02dm %02ds", s // 86400, (s % 86400) // 3600, (s % 3600) // 60, s % 60)
    end

    local cd = sub:Card("Contagem para o Natal", "⏳", 1)
    local cdInfo = cd:Info()
    local hud = new("TextLabel", {Name = "KawanXmasHUD", AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(250, 26),
        Position = UDim2.new(0.5, 0, 0, 12), BackgroundTransparency = 0.2, BorderSizePixel = 0, Visible = false,
        TextColor3 = C.text, TextSize = 12, Font = Enum.Font.GothamBold}, gui)
    bg(hud, "BackgroundColor3", "window")
    corner(hud, 8)
    track(stroke(hud, accent, 1, 0.5), "Color")
    cd:Toggle("Mostrar contagem na tela", false, function(on) hud.Visible = on end)
    task.spawn(function()
        while gui.Parent do
            local left, isDay = christmasLeft()
            local txt = isDay and "🎄 Feliz Natal! 🎅" or ("🎄 Natal em " .. fmtLeft(left))
            cdInfo.Text = txt
            hud.Text = txt
            task.wait(1)
        end
    end)

    -- Bolinhas penduradas, estrela e laço
    local orn = new("Frame", {Name = "XmasOrnaments", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
        BorderSizePixel = 0, ZIndex = 44, Visible = false}, main)
    local ornColors = {rgb(235, 64, 82), rgb(80, 230, 130), rgb(255, 205, 80), rgb(100, 170, 255), rgb(255, 120, 200), rgb(225, 235, 255)}
    local xs = {236, 330, 452, 566, 650}
    local baubles = {}
    for i, x in ipairs(xs) do
        local holder = new("Frame", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(x, 2),
            Size = UDim2.fromOffset(12, 60), BackgroundTransparency = 1, BorderSizePixel = 0}, orn)
        new("Frame", {Position = UDim2.fromOffset(5, 30), Size = UDim2.fromOffset(1, 8),
            BackgroundColor3 = rgb(220, 220, 230), BorderSizePixel = 0}, holder)
        local ball = new("Frame", {Position = UDim2.fromOffset(1, 38), Size = UDim2.fromOffset(10, 10),
            BackgroundColor3 = ornColors[(i - 1) % #ornColors + 1], BorderSizePixel = 0}, holder)
        new("UICorner", {CornerRadius = UDim.new(1, 0)}, ball)
        baubles[i] = holder
    end
    local star = label(sidebar, {Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, -28, 0, 8), Text = "⭐",
        TextSize = 14, ZIndex = 46, Visible = false})
    local bow = label(topBar, {Size = UDim2.fromOffset(18, 18), Position = UDim2.new(1, -42, 0.5, -20), Text = "🎀",
        TextSize = 13, ZIndex = 8, Visible = false})
    local ornOn = false
    local ornConn = RunService.Heartbeat:Connect(function()
        if not ornOn or not main.Visible then return end
        local t = os.clock()
        for i, h in ipairs(baubles) do h.Rotation = math.sin(t * 1.6 + i) * 9 end
        star.Rotation = math.sin(t * 2) * 12
    end)
    gui.Destroying:Connect(function() ornConn:Disconnect() end)
    local ornCard = sub:Card("Enfeites do painel", "🎀", 2)
    ornCard:Toggle("Bolas, estrela e laço", false, function(on)
        ornOn = on
        orn.Visible, star.Visible, bow.Visible = on, on, on
    end)
    ornCard:Note("Bolinhas balançando no topo, estrela na lateral e laço no botão fechar.")

    -- Neve
    local snow = sub:Card("Neve", "❄️", 1)
    Settings.snowSliders = {}
    Settings.snowSliders.count = snow:Slider("Quantidade de flocos", 0, 90, Settings.snowCount, function(v) Settings.snowCount = v end)
    Settings.snowSliders.size = snow:Slider("Tamanho dos flocos (%)", 50, 200, math.floor(Settings.snowSize * 100), function(v)
        Settings.snowSize = v / 100
        if Settings.snowRefresh then Settings.snowRefresh() end
    end)
    Settings.snowSliders.wind = snow:Slider("Vento (esq. ← → dir.)", -60, 60, Settings.wind, function(v) Settings.wind = v end)
    local snowColors = {
        {"Branca", Color3.new(1, 1, 1)}, {"Azulada", rgb(190, 220, 255)},
        {"Dourada", rgb(255, 225, 140)}, {"Rosa", rgb(255, 200, 225)},
    }
    local snowNames = {}
    for _, s in ipairs(snowColors) do table.insert(snowNames, s[1]) end
    Settings.snowColorIdx = 1
    Settings.snowColorDrop = snow:Dropdown("Cor da neve:", snowNames, 1, function(_, i)
        Settings.snowColorIdx = i
        Settings.snowColor = snowColors[i][2]
        if Settings.snowRefresh then Settings.snowRefresh() end
    end)

    -- Luzes
    local lt = sub:Card("Luzes de Natal", "💡", 2)
    local palettes = {
        {"Clássico", {rgb(255, 70, 80), rgb(80, 230, 130), rgb(255, 205, 80), rgb(100, 170, 255)}},
        {"Azul gelo", {rgb(100, 170, 255), rgb(190, 225, 255), rgb(60, 130, 255), rgb(225, 240, 255)}},
        {"Quente", {rgb(255, 150, 60), rgb(255, 195, 70), rgb(255, 110, 70), rgb(255, 225, 150)}},
        {"Branco", {rgb(255, 255, 255), rgb(235, 240, 255)}},
        {"Rosa e roxo", {rgb(255, 120, 200), rgb(185, 105, 255), rgb(255, 170, 225), rgb(150, 140, 255)}},
    }
    local palNames = {}
    for _, p in ipairs(palettes) do table.insert(palNames, p[1]) end
    lt:Dropdown("Cores das luzes:", palNames, 1, function(_, i)
        if Settings.setBulbs then Settings.setBulbs(palettes[i][2]) end
    end)
    lt:Note("Troca as cores das lâmpadas piscando no topo da janela.")
end)

-- ===== Natal: extras (tema completo, presente, aura, cartão, música) =====
Settings.safe("Natal: extras (tema completo, presente, aura, cartão, música)", function()
    local XM = Settings.xmas
    local sub = P.Xmas:SubTab("🎁 Extras")

    local full = sub:Card("Tema Natal completo", "🎄", 1)
    full:Button("Aplica fundo, cor, neve, gorro e luzes", "APLICAR", function()
        Settings.applyLook(Themes[1].accent, 1)
        Settings.themeIdx = 1
        XM.snow, XM.hat, XM.lights = true, true, true
        local tg = Settings.xmasToggles
        if tg then
            for k in pairs({snow = 1, hat = 1, lights = 1}) do if tg[k] then tg[k]:Set(true) end end
        end
        if Settings.xmasApply then Settings.xmasApply() end
        notify("🎄 Tema de Natal aplicado")
    end)

    local gift = sub:Card("Presente surpresa", "🎁", 2)
    local phrases = {
        "Feliz Natal! Que seu ano novo seja incrível 🎄",
        "Ho ho ho! Boas festas! 🎅",
        "Que a paz e a alegria estejam com você ✨",
        "Boas festas e muitas vitórias! 🏆",
        "Neve, luzes e boas companhias ❄️",
    }
    gift:Button("Abrir presente", "🎁 ABRIR", function()
        local r = math.random(1, 3)
        if r == 1 then
            local i = math.random(1, #Themes)
            Settings.themeIdx = i
            Settings.applyLook(Themes[i].accent)
            notify("🎁 Você ganhou o tema " .. Themes[i].name .. "!")
        elseif r == 2 then
            local i = math.random(1, #Backgrounds)
            Settings.applyLook(nil, i)
            notify("🎁 Você ganhou o fundo " .. Backgrounds[i].name .. "!")
        else
            notify("🎁 " .. phrases[math.random(1, #phrases)])
        end
    end)

    -- Aura de neve no personagem (visual local)
    local aura
    local function setAura(on)
        if aura then aura:Destroy() aura = nil end
        if not on then return end
        local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if not root then return end
        aura = new("ParticleEmitter", {
            Texture = "rbxasset://textures/particles/sparkles_main.dds", Rate = 20,
            Lifetime = NumberRange.new(1.2, 2), Speed = NumberRange.new(0.5, 2),
            SpreadAngle = Vector2.new(180, 180), LightEmission = 0.8, Acceleration = Vector3.new(0, -3, 0),
            Size = NumberSequence.new(0.4, 0),
            Color = ColorSequence.new(Color3.new(1, 1, 1), rgb(190, 220, 255)),
        }, root)
    end
    local auraOn = false
    local santa = sub:Card("Modo Papai Noel", "🎅", 1)
    santa:Toggle("Flocos ao redor do personagem", false, function(on)
        auraOn = on
        setAura(on)
    end)
    santa:Note("Efeito visual só no seu cliente.")
    player.CharacterAdded:Connect(function()
        task.wait(1)
        if auraOn then setAura(true) end
    end)
    gui.Destroying:Connect(function() setAura(false) end)

    -- Cartão de Natal
    local function xmasCard(text)
        text = string.sub(text or "", 1, 80)
        if text == "" then text = "Feliz Natal!" end
        local b = new("Frame", {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -70),
            Size = UDim2.fromOffset(460, 52), BackgroundColor3 = rgb(150, 25, 40), BorderSizePixel = 0, ZIndex = 90}, gui)
        corner(b, 12)
        stroke(b, rgb(250, 250, 255), 2, 0)
        label(b, {Size = UDim2.new(1, -90, 1, 0), Position = UDim2.fromOffset(45, 0), Text = text,
            TextColor3 = rgb(255, 255, 255), TextSize = 14, Font = Enum.Font.GothamBold, TextWrapped = true})
        label(b, {Size = UDim2.fromOffset(40, 52), Position = UDim2.fromOffset(2, 0), Text = "🎄", TextSize = 22})
        label(b, {Size = UDim2.fromOffset(40, 52), Position = UDim2.new(1, -42, 0, 0), Text = "🎅", TextSize = 22})
        tween(b, 0.4, {Position = UDim2.new(0.5, 0, 0, 18)}, Enum.EasingStyle.Back)
        task.delay(5, function()
            tween(b, 0.3, {Position = UDim2.new(0.5, 0, 0, -70)})
            task.wait(0.35)
            b:Destroy()
        end)
    end
    local cardText = ""
    local cc = sub:Card("Cartão de Natal", "💌", 2)
    cc:TextBox("Mensagem (máx. 80):", "Feliz Natal, pessoal!", "", function(t) cardText = t end)
    cc:Button("Mostrar cartão", "MOSTRAR", function() xmasCard(cardText) end)
    cc:Note("O cartão aparece só na sua tela.")

    -- Música (você escolhe o ID)
    local music = new("Sound", {Name = "KawanXmasMusic", Looped = true, Volume = 0.4}, gui)
    local musicId = ""
    local mc = sub:Card("Música de Natal", "🎶", 1)
    mc:TextBox("ID do áudio (números):", "Ex: 1234567890", "", function(t)
        local digits = string.gsub(t or "", "%D", "")
        musicId = digits
        music.SoundId = digits ~= "" and ("rbxassetid://" .. digits) or ""
    end)
    mc:Toggle("Tocar música", false, function(on)
        if on then
            if musicId == "" then notify("Digite um ID de áudio primeiro") return end
            music:Play()
        else
            music:Stop()
        end
    end)
    mc:Slider("Volume", 0, 100, 40, function(v) music.Volume = v / 100 end)
    mc:Note("Use um áudio público ou seu. Alguns áudios do Roblox são bloqueados em certos jogos.")
    gui.Destroying:Connect(function() music:Stop() end)
end)

-- ===== Ano Novo: fogos e contagem =====
Settings.safe("Ano Novo: fogos e contagem", function()
    local sub = P.Xmas:SubTab("🎆 Ano Novo")
    local fwGui = new("ScreenGui", {Name = "KawanFireworks", ResetOnSpawn = false, IgnoreGuiInset = true,
        DisplayOrder = 52, ZIndexBehavior = Enum.ZIndexBehavior.Sibling}, playerGui)
    local sparks = {}
    local fwColors = {rgb(255, 90, 105), rgb(255, 195, 70), rgb(80, 235, 155), rgb(35, 205, 255),
        rgb(185, 105, 255), rgb(255, 255, 255)}
    local function burst(x, y)
        if #sparks > 500 then return end
        local c1 = fwColors[math.random(#fwColors)]
        local c2 = fwColors[math.random(#fwColors)]
        for i = 1, 36 do
            local a = (i / 36) * math.pi * 2 + math.random() * 0.2
            local sp = 90 + math.random() * 130
            local f = new("Frame", {Size = UDim2.fromOffset(4, 4), AnchorPoint = Vector2.new(0.5, 0.5),
                BackgroundColor3 = (i % 2 == 0) and c1 or c2, BorderSizePixel = 0,
                Position = UDim2.fromOffset(x, y)}, fwGui)
            new("UICorner", {CornerRadius = UDim.new(1, 0)}, f)
            table.insert(sparks, {gui = f, x = x, y = y, vx = math.cos(a) * sp, vy = math.sin(a) * sp,
                life = 0, max = 1.1 + math.random() * 0.5})
        end
    end
    local function randomBurst()
        local cam = workspace.CurrentCamera
        local vs = cam and cam.ViewportSize or Vector2.new(1280, 720)
        burst(vs.X * (0.15 + math.random() * 0.7), vs.Y * (0.1 + math.random() * 0.35))
    end
    local fwConn = RunService.Heartbeat:Connect(function(dt)
        dt = math.min(dt, 0.1)
        for i = #sparks, 1, -1 do
            local s = sparks[i]
            s.life += dt
            if s.life >= s.max then
                s.gui:Destroy()
                table.remove(sparks, i)
            else
                s.vy += 160 * dt
                s.vx *= (1 - 0.8 * dt)
                s.x += s.vx * dt
                s.y += s.vy * dt
                s.gui.Position = UDim2.fromOffset(s.x, s.y)
                s.gui.BackgroundTransparency = (s.life / s.max) ^ 2
            end
        end
    end)
    gui.Destroying:Connect(function()
        fwConn:Disconnect()
        fwGui:Destroy()
    end)

    local fw = sub:Card("Fogos de artifício", "🎆", 1)
    fw:Button("Soltar fogos", "🎆 SOLTAR", function()
        for i = 1, 3 do
            task.delay((i - 1) * 0.25, randomBurst)
        end
    end)
    local auto = false
    fw:Toggle("Fogos automáticos", false, function(on)
        auto = on
        if on then
            task.spawn(function()
                while auto and gui.Parent do
                    randomBurst()
                    task.wait(1 + math.random() * 0.8)
                end
            end)
        end
    end)
    local newYearAuto = true
    fw:Toggle("Fogos na virada (00:00)", true, function(on) newYearAuto = on end)
    fw:Note("Os fogos aparecem na tela toda, mesmo com o painel fechado.")

    local cd = sub:Card("Contagem Ano Novo", "🥂", 2)
    local info = cd:Info()
    local fired = false
    task.spawn(function()
        while gui.Parent do
            local now = os.time()
            local d = os.date("*t", now)
            local target = os.time({year = d.year + 1, month = 1, day = 1, hour = 0, min = 0, sec = 0})
            if d.month == 1 and d.day == 1 then
                info.Text = "🥂 Feliz Ano Novo! 🎆"
            else
                local s = target - now
                info.Text = string.format("🥂 Ano Novo em\n%dd %02dh %02dm %02ds", s // 86400, (s % 86400) // 3600,
                    (s % 3600) // 60, s % 60)
            end
            local midnight = (d.month == 12 and d.day == 31 and d.hour == 23 and d.min == 59 and d.sec >= 55)
                or (d.month == 1 and d.day == 1 and d.hour == 0 and d.min == 0 and d.sec <= 12)
            if midnight and newYearAuto and not fired then
                fired = true
                task.spawn(function()
                    for _ = 1, 12 do
                        randomBurst()
                        task.wait(0.6)
                    end
                end)
            elseif not midnight then
                fired = false
            end
            task.wait(1)
        end
    end)
end)

-- ===== Personalização: salvar, perfis, fontes, atalhos =====
Settings.safe("Personalização: salvar, perfis, fontes, atalhos", function()
    local HttpService = game:GetService("HttpService")
    local XM = Settings.xmas
    Settings.slots = Settings.slots or {}

    local function colorToTable(c)
        return {math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5)}
    end
    local function tableToColor(t)
        if type(t) ~= "table" then return nil end
        local r, g, b = tonumber(t[1]), tonumber(t[2]), tonumber(t[3])
        if not (r and g and b) then return nil end
        return Color3.fromRGB(math.clamp(r, 0, 255), math.clamp(g, 0, 255), math.clamp(b, 0, 255))
    end
    local function collect()
        return {
            accent = colorToTable(accent), bg = Settings.bgIdx or 1, theme = Settings.themeIdx,
            snowCount = Settings.snowCount, snowSize = Settings.snowSize, wind = Settings.wind,
            snowColorIdx = Settings.snowColorIdx or 1,
            xmas = {snow = XM.snow, hat = XM.hat, lights = XM.lights},
            scale = userScale, title = Settings.title, slots = Settings.slots,
        }
    end
    local function applyConfig(d)
        if type(d) ~= "table" then return false end
        local color = tableToColor(d.accent)
        Settings.applyLook(color, tonumber(d.bg), true)
        if tonumber(d.theme) then Settings.themeIdx = tonumber(d.theme) end
        local ss = Settings.snowSliders or {}
        if tonumber(d.snowCount) then
            Settings.snowCount = math.clamp(d.snowCount, 0, 90)
            if ss.count then ss.count:Set(Settings.snowCount) end
        end
        if tonumber(d.snowSize) then
            Settings.snowSize = math.clamp(d.snowSize, 0.5, 2)
            if ss.size then ss.size:Set(Settings.snowSize * 100) end
        end
        if tonumber(d.wind) then
            Settings.wind = math.clamp(d.wind, -60, 60)
            if ss.wind then ss.wind:Set(Settings.wind) end
        end
        local sci = tonumber(d.snowColorIdx)
        if sci and sci >= 1 and sci <= 4 and Settings.snowColorDrop then
            Settings.snowColorDrop:Set(sci)
            local opts = {Color3.new(1, 1, 1), rgb(190, 220, 255), rgb(255, 225, 140), rgb(255, 200, 225)}
            Settings.snowColorIdx = sci
            Settings.snowColor = opts[sci]
        end
        if Settings.snowRefresh then Settings.snowRefresh() end
        if type(d.xmas) == "table" then
            for _, k in ipairs({"snow", "hat", "lights"}) do
                if type(d.xmas[k]) == "boolean" then
                    XM[k] = d.xmas[k]
                    local tg = Settings.xmasToggles
                    if tg and tg[k] then tg[k]:Set(d.xmas[k]) end
                end
            end
            if Settings.xmasApply then Settings.xmasApply() end
        end
        if tonumber(d.scale) then
            userScale = math.clamp(d.scale, 0.7, 1.3)
            refreshScale()
        end
        if type(d.title) == "string" and d.title ~= "" then
            Settings.title = string.sub(d.title, 1, 10)
            brand.Text = Settings.title
        end
        if type(d.slots) == "table" then Settings.slots = d.slots end
        return true
    end

    local FILE = "KawanMenu_config.json"
    local function saveFile()
        local ok, err = pcall(function() writefile(FILE, HttpService:JSONEncode(collect())) end)
        notify(ok and "💾 Configurações salvas" or "Salvar em arquivo não é suportado aqui • use Copiar config")
    end
    local function loadFile()
        local ok, txt = pcall(function()
            if isfile and isfile(FILE) then return readfile(FILE) end
            return nil
        end)
        if not ok or not txt then return false end
        local ok2, d = pcall(function() return HttpService:JSONDecode(txt) end)
        return ok2 and applyConfig(d)
    end

    local sub = P.Style:SubTab("💾 Perfis")
    local sv = sub:Card("Salvar configurações", "💾", 1)
    sv:Button("Salvar em arquivo", "SALVAR", saveFile)
    sv:Button("Carregar do arquivo", "CARREGAR", function()
        notify(loadFile() and "📂 Configurações carregadas" or "Nenhum arquivo salvo encontrado")
    end)
    sv:Button("Copiar config (JSON)", "COPIAR", function()
        copyText(HttpService:JSONEncode(collect()))
    end)
    sv:TextBox("Colar config (JSON):", "Cole aqui e saia do campo", "", function(t)
        if t == "" then return end
        local ok, d = pcall(function() return HttpService:JSONDecode(t) end)
        notify((ok and applyConfig(d)) and "📂 Config aplicada" or "JSON inválido")
    end)
    sv:Note("Salva cor, fundo, neve, enfeites, tamanho, nome e slots. O arquivo é carregado sozinho ao abrir, se o executor suportar.")
    task.spawn(function()
        task.wait(0.8)
        loadFile()
    end)

    local presets = {
        {"Natal", Themes[1].accent, 1},
        {"Noturno", Themes[4].accent, 5},
        {"Streamer", Themes[3].accent, 3},
    }
    local presetNames = {}
    for _, p in ipairs(presets) do table.insert(presetNames, p[1]) end
    local pr = sub:Card("Perfis de tema", "🎭", 2)
    local presetIdx = 1
    pr:Dropdown("Perfil pronto:", presetNames, 1, function(_, i) presetIdx = i end)
    pr:Button("Aplicar perfil", "APLICAR", function()
        local p = presets[presetIdx]
        Settings.applyLook(p[2], p[3])
        notify("Perfil: " .. p[1])
    end)
    for n = 1, 3 do
        pr:Button("Salvar visual atual no slot " .. n, "SALVAR", function()
            Settings.slots[tostring(n)] = {accent = colorToTable(accent), bg = Settings.bgIdx or 1}
            notify("Slot " .. n .. " salvo")
        end)
        pr:Button("Carregar slot " .. n, "CARREGAR", function()
            local s = Settings.slots[tostring(n)]
            if not s then notify("Slot " .. n .. " está vazio") return end
            Settings.applyLook(tableToColor(s.accent), tonumber(s.bg))
            notify("Slot " .. n .. " carregado")
        end)
    end

    -- Fontes
    local fsub = P.Style:SubTab("🔤 Fontes")
    local families = {
        {"Gotham (padrão)", Enum.Font.GothamBlack, Enum.Font.GothamBold, Enum.Font.GothamMedium},
        {"Ubuntu", Enum.Font.Ubuntu, Enum.Font.Ubuntu, Enum.Font.Ubuntu},
        {"Source Sans", Enum.Font.SourceSansBold, Enum.Font.SourceSansBold, Enum.Font.SourceSans},
        {"Arial", Enum.Font.ArialBold, Enum.Font.ArialBold, Enum.Font.Arial},
        {"Fredoka", Enum.Font.FredokaOne, Enum.Font.FredokaOne, Enum.Font.FredokaOne},
        {"Arcade", Enum.Font.Arcade, Enum.Font.Arcade, Enum.Font.Arcade},
    }
    local famNames = {}
    for _, f in ipairs(families) do table.insert(famNames, f[1]) end
    local function applyFont(idx)
        local fam = families[idx]
        for _, o in ipairs(gui:GetDescendants()) do
            if (o:IsA("TextLabel") or o:IsA("TextButton") or o:IsA("TextBox")) and o.Font ~= Enum.Font.Code then
                local w = o:GetAttribute("KW")
                if not w then
                    w = (o.Font == Enum.Font.GothamBlack) and 1 or ((o.Font == Enum.Font.GothamBold) and 2 or 3)
                    o:SetAttribute("KW", w)
                end
                o.Font = fam[w + 1]
            end
        end
    end
    local fc = fsub:Card("Fonte do painel", "🔤", 1)
    fc:Dropdown("Fonte:", famNames, 1, function(_, i)
        applyFont(i)
        notify("Fonte: " .. famNames[i])
    end)
    fc:Note("Muda os textos que já existem no painel. Notificações novas continuam na fonte padrão.")

    local nm = fsub:Card("Nome do painel", "✏️", 2)
    nm:Note("Para trocar o título, use Estilo > Janela > Nome do painel. O nome também é salvo na config.")
end)

-- ===== Início: pesquisa, mover HUDs, dica do dia =====
Settings.safe("Início: pesquisa, mover HUDs, dica do dia", function()
    local sub = P.Home:SubTab("🔎 Pesquisa")
    local srch = sub:Card("Pesquisar função", "🔎", 1)
    local resLbl = srch:List()
    resLbl.Text = "Digite um nome para buscar."
    local found = {}
    srch:TextBox("Nome da função:", "Ex: neve, voo, nitro", "", function(t)
        found = {}
        local q = string.lower(t or "")
        if q ~= "" then
            for _, e in ipairs(keybindEntries) do
                if string.find(string.lower(e.label), q, 1, true) then
                    table.insert(found, e)
                end
            end
        end
        local rows = {}
        for i = 1, math.min(#found, 8) do
            table.insert(rows, i .. ". " .. found[i].label .. (found[i].getState() and "  [ON]" or "  [OFF]"))
        end
        resLbl.Text = #found == 0 and "Nada encontrado." or table.concat(rows, "\n")
    end)
    srch:Button("Alternar 1º resultado", "ALTERNAR", function()
        local e = found[1]
        if not e then notify("Pesquise antes") return end
        e.setState(not e.getState())
    end)

    -- Mover HUDs
    local move = sub:Card("Mover HUDs", "🖐️", 1)
    local dragOn = false
    local names = {"KawanHUD", "Detector", "KawanPos", "KawanXmasHUD"}
    local defaults = {}
    for _, n in ipairs(names) do
        local obj = gui:FindFirstChild(n)
        if obj then
            defaults[n] = obj.Position
            obj.Active = true
            local dragging, ds, sp = false, nil, nil
            obj.InputBegan:Connect(function(input)
                if not dragOn then return end
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging, ds, sp = true, input.Position, obj.Position
                end
            end)
            UIS.InputChanged:Connect(function(input)
                if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                    local d = (input.Position - ds) / uiScale.Scale
                    obj.Position = UDim2.new(sp.X.Scale, sp.X.Offset + d.X, sp.Y.Scale, sp.Y.Offset + d.Y)
                end
            end)
            UIS.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    dragging = false
                end
            end)
        end
    end
    move:Toggle("Arrastar HUDs (FPS, relógio, detector...)", false, function(on)
        dragOn = on
        notify(on and "Arraste os HUDs visíveis para onde quiser" or "Posições travadas")
    end)
    move:Button("Restaurar posições", "RESTAURAR", function()
        for n, pos in pairs(defaults) do
            local obj = gui:FindFirstChild(n)
            if obj then obj.Position = pos end
        end
        notify("Posições restauradas")
    end)
    move:Note("Ligue os HUDs primeiro (aba HUD, Natal) para poder arrastá-los.")

    -- Dica do dia
    local tips = {
        "Clique no campo ao lado de cada toggle para definir uma tecla de atalho.",
        "Arraste o painel pela barra superior ou pela lateral.",
        "Use o Modo Foto antes de tirar print para esconder a interface.",
        "O botão K flutuante abre o painel no celular.",
        "Salve seu visual em Estilo > Perfis para voltar a ele depois.",
        "Em Natal você ajusta neve, vento, luzes e enfeites.",
        "Use a pesquisa de função para achar qualquer toggle rápido.",
        "Use o botão − no topo para minimizar o painel numa bolinha K arrastável.",
        "Experimente o modo arco-íris em Estilo > Cores.",
        "Dá para mudar a fonte do painel em Estilo > Fontes.",
        "Os fogos de Ano Novo disparam sozinhos na virada.",
        "Backspace remove um atalho; Esc cancela a edição.",
    }
    local tipCard = sub:Card("Dica do dia", "💡", 2)
    local tipLbl = tipCard:Info()
    local tipIdx = tonumber(os.date("%j")) % #tips + 1
    tipLbl.Text = tips[tipIdx]
    tipCard:Button("Outra dica", "PRÓXIMA", function()
        tipIdx = tipIdx % #tips + 1
        tipLbl.Text = tips[tipIdx]
    end)
end)

-- ===== Utilidades: histórico, atalhos, anti-AFK, calculadora, conversor, foto =====
Settings.safe("Utilidades: histórico, atalhos, anti-AFK, calculadora, conversor, foto", function()
    local sub = P.Tools:SubTab("🧩 Utilidades")

    local hist = sub:Card("Histórico de notificações", "📜", 1)
    local histLbl = hist:List()
    histLbl.Text = "Sem notificações ainda."
    hist:Button("Limpar histórico", "LIMPAR", function()
        table.clear(Settings.notifyLog)
        histLbl.Text = "Sem notificações ainda."
    end)
    task.spawn(function()
        while gui.Parent do
            if main.Visible then
                local log = Settings.notifyLog
                histLbl.Text = #log == 0 and "Sem notificações ainda." or table.concat(log, "\n")
            end
            task.wait(1)
        end
    end)

    local keysCard = sub:Card("Painel de atalhos", "⌨️", 2)
    local keysLbl = keysCard:List()
    local function refreshKeys()
        local rows = {"Abrir/fechar: " .. Settings.toggleKey.Name}
        for _, e in ipairs(keybindEntries) do
            if e.key then table.insert(rows, e.key.Name .. "  →  " .. e.label) end
        end
        if #rows == 1 then table.insert(rows, "Nenhum atalho definido.") end
        keysLbl.Text = table.concat(rows, "\n")
    end
    refreshKeys()
    keysCard:Button("Atualizar lista", "ATUALIZAR", refreshKeys)

    local afk = sub:Card("Anti-AFK", "💤", 1)
    local afkConn
    afk:Toggle("Evitar desconexão por inatividade", false, function(on)
        if afkConn then afkConn:Disconnect() afkConn = nil end
        if on then
            afkConn = player.Idled:Connect(function()
                pcall(function()
                    local vu = game:GetService("VirtualUser")
                    vu:CaptureController()
                    vu:ClickButton2(Vector2.new())
                end)
            end)
        end
        notify(on and "Anti-AFK ativado" or "Anti-AFK desativado")
    end)
    gui.Destroying:Connect(function() if afkConn then afkConn:Disconnect() end end)

    local photo = sub:Card("Foto rápida", "📸", 2)
    photo:Button("Esconder tudo por 5 s", "FOTO", function()
        local wasOpen = main.Visible
        notify("📸 Interface some em 3 s")
        task.delay(3, function()
            if wasOpen then setOpen(false) end
            task.wait(0.25)
            gui.Enabled = false
            task.wait(5)
            gui.Enabled = true
            if wasOpen then setOpen(true) end
        end)
    end)
    photo:Note("Tire o print nesses 5 segundos (tecla de captura do seu aparelho).")

    -- Calculadora
    local function evalExpr(src)
        local s = string.gsub(src, "%s+", "")
        s = string.gsub(s, ",", ".")
        local pos = 1
        local parseExpr
        local function peek() return string.sub(s, pos, pos) end
        local function parseNumber()
            local num = string.match(s, "^%d*%.?%d+", pos) or string.match(s, "^%d+%.?", pos)
            if not num then error("número esperado") end
            pos += #num
            return tonumber(num)
        end
        local function parseAtom()
            local c = peek()
            if c == "(" then
                pos += 1
                local v = parseExpr()
                if peek() ~= ")" then error("falta )") end
                pos += 1
                return v
            elseif c == "-" then
                pos += 1
                return -parseAtom()
            elseif c == "+" then
                pos += 1
                return parseAtom()
            end
            return parseNumber()
        end
        local function parsePow()
            local base = parseAtom()
            if peek() == "^" then
                pos += 1
                return base ^ parsePow()
            end
            return base
        end
        local function parseTerm()
            local v = parsePow()
            while true do
                local c = peek()
                if c == "*" then pos += 1 v *= parsePow()
                elseif c == "/" then pos += 1 v /= parsePow()
                elseif c == "%" then pos += 1 v %= parsePow()
                else break end
            end
            return v
        end
        parseExpr = function()
            local v = parseTerm()
            while true do
                local c = peek()
                if c == "+" then pos += 1 v += parseTerm()
                elseif c == "-" then pos += 1 v -= parseTerm()
                else break end
            end
            return v
        end
        local v = parseExpr()
        if pos <= #s then error("símbolo inválido") end
        return v
    end
    local calc = sub:Card("Calculadora", "🧮", 1)
    local calcOut = calc:Info()
    calcOut.Text = "Resultado: -"
    calc:TextBox("Conta (+ - * / ^ % e parênteses):", "Ex: (12+8)*3", "", function(t)
        if t == "" then calcOut.Text = "Resultado: -" return end
        local ok, v = pcall(evalExpr, t)
        if ok then
            calcOut.Text = "Resultado: " .. tostring(math.floor(v * 1e6 + 0.5) / 1e6)
        else
            calcOut.Text = "Conta inválida"
        end
    end)

    -- Conversor
    local conv = sub:Card("Conversor", "🔁", 2)
    local convOut = conv:Info()
    local convNames = {"studs → metros", "metros → studs", "°C → °F", "°F → °C", "km → milhas", "milhas → km"}
    local convFns = {
        function(x) return x * 0.28 end, function(x) return x / 0.28 end,
        function(x) return x * 9 / 5 + 32 end, function(x) return (x - 32) * 5 / 9 end,
        function(x) return x * 0.621371 end, function(x) return x / 0.621371 end,
    }
    local convIdx, convVal = 1, 0
    local function runConv()
        local r = convFns[convIdx](convVal)
        convOut.Text = string.format("%g → %.2f", convVal, r)
    end
    runConv()
    conv:Dropdown("Conversão:", convNames, 1, function(_, i) convIdx = i runConv() end)
    conv:TextBox("Valor:", "Ex: 100", "", function(t)
        convVal = tonumber(t) or 0
        runConv()
    end)
end)

-- ===== Jogadores: amigos online =====
Settings.safe("Jogadores: amigos online", function()
    local sub = P.Players:SubTab("🤝 Amigos")
    local card = sub:Card("Amigos no servidor", "🤝", 1)
    local lbl = card:List()
    lbl.Text = "Clique em atualizar."
    local function refreshFriends()
        lbl.Text = "Verificando..."
        task.spawn(function()
            local rows = {}
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= player then
                    local ok, fr = pcall(function() return player:IsFriendsWith(p.UserId) end)
                    if ok and fr then table.insert(rows, p.DisplayName .. " (@" .. p.Name .. ")") end
                end
            end
            lbl.Text = #rows .. " amigo(s) aqui\n" .. table.concat(rows, "\n")
        end)
    end
    card:Button("Atualizar lista", "ATUALIZAR", refreshFriends)
    local alert = sub:Card("Avisos", "🔔", 2)
    local friendAlert = false
    alert:Toggle("Avisar quando um amigo entrar", false, function(on) friendAlert = on end)
    Players.PlayerAdded:Connect(function(p)
        if not friendAlert then return end
        local ok, fr = pcall(function() return player:IsFriendsWith(p.UserId) end)
        if ok and fr then notify("🤝 Seu amigo " .. p.DisplayName .. " entrou") end
    end)
end)

-- ===== Jogadores: observar =====
Settings.safe("Observar jogador", function()
    local sub = P.Players:SubTab("👁 Observar")
    local card = sub:Card("Observar jogador", "👁", 1)
    local info = card:Info()
    local list, idx, target = {}, 1, nil
    local toggle

    local function cam() return workspace.CurrentCamera end
    local function myHumanoid()
        return player.Character and player.Character:FindFirstChildOfClass("Humanoid")
    end
    local function rebuild()
        list = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= player then table.insert(list, p) end
        end
        table.sort(list, function(a, b) return a.DisplayName:lower() < b.DisplayName:lower() end)
        if idx > #list then idx = 1 end
    end
    local function refreshInfo()
        local p = list[idx]
        if not p then
            info.Text = "Nenhum outro jogador no servidor"
            return
        end
        local text = string.format("%d/%d  %s (@%s)", idx, #list, p.DisplayName, p.Name)
        local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
        local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
        local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
        if hum then text = text .. string.format("\nVida: %d", math.floor(hum.Health)) end
        if root and myRoot then text = text .. string.format("  •  %dm", math.floor((root.Position - myRoot.Position).Magnitude)) end
        if target then text = text .. "\n👁 Observando " .. target.DisplayName end
        info.Text = text
    end
    local function stop(silent)
        target = nil
        local c, h = cam(), myHumanoid()
        if c and h then c.CameraSubject = h end
        if toggle then toggle:Set(false) end
        if not silent then notify("Câmera restaurada") end
        refreshInfo()
    end
    local function watch(p)
        local hum = p and p.Character and p.Character:FindFirstChildOfClass("Humanoid")
        local c = cam()
        if not hum or not c then
            notify("Jogador sem personagem ativo")
            if toggle then toggle:Set(false) end
            return
        end
        target = p
        c.CameraSubject = hum
        if toggle then toggle:Set(true) end
        notify("Observando " .. p.DisplayName)
        refreshInfo()
    end
    local function move(step)
        rebuild()
        if #list == 0 then refreshInfo() return end
        idx = (idx - 1 + step) % #list + 1
        if target then watch(list[idx]) else refreshInfo() end
    end

    card:Button("Jogador anterior", "◀", function() move(-1) end)
    card:Button("Próximo jogador", "▶", function() move(1) end)
    toggle = card:Toggle("Observar jogador selecionado", false, function(on)
        if on then
            rebuild()
            watch(list[idx])
        else
            stop(false)
        end
    end)
    card:Button("Voltar para meu personagem", "VOLTAR", function() stop(false) end)
    card:Note("Com a opção ligada, a câmera segue o jogador mesmo quando ele renasce. Use ◀ ▶ para trocar de jogador.")

    Players.PlayerAdded:Connect(function() rebuild() refreshInfo() end)
    Players.PlayerRemoving:Connect(function(p)
        if target == p then stop(true) notify("O jogador observado saiu") end
        task.defer(function() rebuild() refreshInfo() end)
    end)
    player.CharacterAdded:Connect(function()
        task.wait(0.6)
        if not target then
            local c, h = cam(), myHumanoid()
            if c and h and c.CameraSubject ~= h and not list[idx] then c.CameraSubject = h end
        end
    end)
    task.spawn(function()
        while gui.Parent do
            task.wait(0.5)
            if target then
                local hum = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
                local c = cam()
                if hum and c and c.CameraSubject ~= hum then c.CameraSubject = hum end
            end
            if main.Visible then refreshInfo() end
        end
    end)
    gui.Destroying:Connect(function() stop(true) end)
    rebuild()
    refreshInfo()
end)

--------------------------------------------------------------------
-- Abrir / fechar com animação
--------------------------------------------------------------------
local open = false
setOpen = function(v)
    open = v
    if v then
        main.Visible = true
        if Settings.xmasRestart then Settings.xmasRestart() end
        winScale.Scale = 0.93
        main.GroupTransparency = 1
        tween(winScale, 0.3, {Scale = 1}, Enum.EasingStyle.Back)
        tween(main, 0.22, {GroupTransparency = baseGT})
    else
        tween(winScale, 0.18, {Scale = 0.95})
        tween(main, 0.18, {GroupTransparency = 1})
        task.delay(0.2 / Settings.speed, function()
            if not open then main.Visible = false end
        end)
    end
end

main:GetPropertyChangedSignal("Visible"):Connect(function() open = main.Visible end)

closeBtn.Activated:Connect(function()
    playClick()
    setOpen(false)
    notify(UIS.TouchEnabled and not UIS.KeyboardEnabled and "Painel oculto • toque na bolha para abrir" or "Painel oculto • " .. Settings.toggleKey.Name .. " para abrir")
end)
UIS.InputBegan:Connect(function(input, processed)
    if input.UserInputType ~= Enum.UserInputType.Keyboard then return end
    if waitingForKeybind and unlocked then
        local entry = waitingForKeybind
        if input.KeyCode == Enum.KeyCode.Escape then
            waitingForKeybind = nil
            entry.button.Text = entry.key and entry.key.Name or "—"
            notify("Configuração de tecla cancelada")
            return
        elseif input.KeyCode == Enum.KeyCode.Backspace then
            entry.key = nil
            entry.button.Text = "—"
            waitingForKeybind = nil
            notify("Keybind removido")
            return
        elseif input.KeyCode ~= Enum.KeyCode.Unknown then
            if input.KeyCode == Settings.toggleKey then
                notify("Essa tecla já está reservada para abrir o painel")
                return
            end
            for _, other in ipairs(keybindEntries) do
                if other ~= entry and other.key == input.KeyCode then
                    notify("Tecla já usada em outra opção; escolha outra")
                    return
                end
            end
            entry.key = input.KeyCode
            entry.button.Text = input.KeyCode.Name
            waitingForKeybind = nil
            notify("Tecla definida: " .. input.KeyCode.Name)
            return
        end
    end
    if processed then return end
    if unlocked and input.KeyCode == Settings.toggleKey then
        setOpen(not open)
        return
    end
    if unlocked then
        for _, entry in ipairs(keybindEntries) do
            if entry.key and input.KeyCode == entry.key then
                entry.setState(not entry.getState())
                return
            end
        end
    end
end)

--------------------------------------------------------------------
-- Animação contínua (brilho, linha e arco-íris)
--------------------------------------------------------------------
RunService.Heartbeat:Connect(function()
    local t = os.clock()
    if Settings.glow then brandGrad.Offset = Vector2.new(math.sin(t * 1.2) * 0.6, 0) end
    if Settings.topline then topGrad.Offset = Vector2.new(math.sin(t * 0.9) * 0.8, 0) end
    if Settings.rainbow then setAccent(Color3.fromHSV((t * 0.08) % 1, 0.55, 1)) end
    local pal = Settings.ownerPalette
    if pal and not Settings.rainbow then
        local pos = (t * 0.25) % #pal
        local i = math.floor(pos)
        setAccent(pal[i + 1]:Lerp(pal[(i + 1) % #pal + 1], pos - i))
    end
    if crown.Visible then
        crown.Rotation = math.sin(t * 2.2) * 14
        crown.Position = UDim2.fromOffset(34, 4 + math.sin(t * 3) * 1.5)
    end
end)

--------------------------------------------------------------------
-- Tela de acesso (key)
--------------------------------------------------------------------
local access = new("Frame", {Name = "Access", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
    Size = UDim2.fromOffset(340, 232), BorderSizePixel = 0, ZIndex = 100}, gui)
bg(access, "BackgroundColor3", "window")
corner(access, 14)
track(stroke(access, accent, 1.5, 0.35), "Color")
local accScale = new("UIScale", {Scale = 0.9}, access)
local accLine = new("Frame", {Size = UDim2.new(1, 0, 0, 2), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1)}, access)
local accLineGrad = new("UIGradient", {}, accLine)
table.insert(accentHooks, function()
    local dim = accent:Lerp(Color3.new(0, 0, 0), 0.8)
    accLineGrad.Color = ColorSequence.new({ColorSequenceKeypoint.new(0, dim),
        ColorSequenceKeypoint.new(0.5, accent), ColorSequenceKeypoint.new(1, dim)})
end)
setAccent(accent)

label(access, {Size = UDim2.new(1, -30, 0, 30), Position = UDim2.fromOffset(15, 16), Text = "KAWAN MENU",
    TextSize = 20, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Left})
local accTag = label(access, {Size = UDim2.new(1, -30, 0, 16), Position = UDim2.fromOffset(15, 44),
    Text = "ACESSO PREMIUM", TextSize = 11, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Left})
track(accTag, "TextColor3")
label(access, {Size = UDim2.new(1, -30, 0, 18), Position = UDim2.fromOffset(15, 64),
    Text = "Digite sua key para liberar o painel", TextColor3 = C.muted, TextSize = 11, Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left})

local keyInput = new("TextBox", {Size = UDim2.new(1, -40, 0, 40), Position = UDim2.fromOffset(20, 94), Text = "",
    PlaceholderText = "KEY PREMIUM", PlaceholderColor3 = C.muted, TextColor3 = C.text, TextSize = 15,
    Font = Enum.Font.GothamBold, ClearTextOnFocus = false, BorderSizePixel = 0}, access)
bg(keyInput, "BackgroundColor3", "inset")
corner(keyInput, 8)
local keyStroke = stroke(keyInput, C.line, 1, 0.4)
keyInput.Focused:Connect(function() tween(keyStroke, 0.12, {Color = accent, Transparency = 0}) end)
keyInput.FocusLost:Connect(function() tween(keyStroke, 0.12, {Color = C.line, Transparency = 0.4}) end)

local unlockBtn = new("TextButton", {Size = UDim2.new(1, -40, 0, 38), Position = UDim2.fromOffset(20, 146),
    Text = "DESBLOQUEAR", TextColor3 = C.window, TextSize = 12, Font = Enum.Font.GothamBold,
    AutoButtonColor = false, BorderSizePixel = 0}, access)
track(unlockBtn, "BackgroundColor3")
corner(unlockBtn, 8)
ripple(unlockBtn)

local accStatus = label(access, {Size = UDim2.new(1, -30, 0, 22), Position = UDim2.fromOffset(15, 194),
    Text = "ACESSO RESTRITO", TextColor3 = C.muted, TextSize = 10, Font = Enum.Font.GothamBold})

local attempts, lockedUntil = 0, 0
local function showAccess()
    unlocked, isKeyAdmin, activeKey = false, false, nil
    P.Keys.item.Visible = false
    P.Owner.item.Visible = false
    ownerCat.Visible = false
    if resetOwner then resetOwner() end
    if activePage == P.Owner or activePage == P.Keys then selectPage(P.Home) end
    keyInput.Text = ""
    accStatus.Text = "ACESSO RESTRITO"
    accStatus.TextColor3 = C.muted
    unlockBtn.Text = "DESBLOQUEAR"
    access.Visible = true
    accScale.Scale = 0.9
    tween(accScale, 0.3, {Scale = 1}, Enum.EasingStyle.Back)
end

local function tryUnlock()
    if os.clock() < lockedUntil then
        accStatus.Text = "AGUARDE " .. math.ceil(lockedUntil - os.clock()) .. "s PARA TENTAR DE NOVO"
        accStatus.TextColor3 = Color3.fromRGB(255, 190, 90)
        return
    end
    local entered = string.gsub(keyInput.Text or "", "%s+", "")
    local record = getKeyRecord(entered)
    if record then
        attempts = 0
        unlocked, isKeyAdmin, activeKey = true, record.admin == true, entered
        updateProfileLicense(record)
        P.Keys.item.Visible = false
        P.Owner.item.Visible = isKeyAdmin
        ownerCat.Visible = isKeyAdmin
        crown.Visible = isKeyAdmin
        accStatus.Text = "ACESSO PREMIUM LIBERADO"
        accStatus.TextColor3 = Color3.fromRGB(90, 240, 150)
        unlockBtn.Text = "ACESSO LIBERADO"
        tween(accScale, 0.28, {Scale = 0.82}, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        task.delay(0.3 / Settings.speed, function()
            access.Visible = false
            setOpen(true)
            notify((isKeyAdmin and "👑 Bem-vindo, Dono" or "✅ Acesso liberado") .. " • 🎄 Natal v7")
        end)
    else
        attempts += 1
        accStatus.Text = "KEY INVÁLIDA, REVOGADA OU EXPIRADA"
        accStatus.TextColor3 = Color3.fromRGB(255, 90, 110)
        keyInput.Text = ""
        if attempts >= 5 then
            attempts = 0
            lockedUntil = os.clock() + 10
            accStatus.Text = "MUITAS TENTATIVAS • AGUARDE 10s"
        end
        local origin = UDim2.fromScale(0.5, 0.5)
        task.spawn(function()
            for _, dx in ipairs({-8, 8, -5, 5, 0}) do
                tween(access, 0.045, {Position = origin + UDim2.fromOffset(dx, 0)})
                task.wait(0.045)
            end
        end)
    end
end
unlockBtn.Activated:Connect(function() playClick() tryUnlock() end)
keyInput.FocusLost:Connect(function(enter) if enter then tryUnlock() end end)

-- Se a key for revogada ou expirar durante o uso, o painel volta a bloquear
task.spawn(function()
    while gui.Parent do
        task.wait(15)
        if unlocked and not getKeyRecord(activeKey) then
            setOpen(false)
            showAccess()
            notify("Sua key foi revogada ou expirou")
        end
    end
end)

selectPage(P.Home)
showAccess()
