-- Spin.client.luau
-- Controla a UI do painel de Spin: animação pulsante da descrição e contador 24h.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local LOCAL_PLAYER = Players.LocalPlayer
local playerGui = LOCAL_PLAYER:WaitForChild("PlayerGui")

-- Util: encontra ScreenGui/Frame do Spin e seus elementos
local function findScreenGuiByNameContains(root: Instance, namePart: string): ScreenGui?
    namePart = string.lower(namePart)
    for _, inst in ipairs(root:GetDescendants()) do
        if inst:IsA("ScreenGui") and string.find(string.lower(inst.Name), namePart) then
            return inst
        end
    end
    return nil
end

local function findFirstGuiObject(container: Instance): GuiObject?
    for _, inst in ipairs(container:GetDescendants()) do
        if inst:IsA("GuiObject") then return inst end
    end
    return nil
end

local function findDescByNameContains(root: Instance, className: string, namePart: string): Instance?
    namePart = string.lower(namePart)
    for _, inst in ipairs(root:GetDescendants()) do
        if inst.ClassName == className and string.find(string.lower(inst.Name), namePart) then
            return inst
        end
    end
    return nil
end

-- Animação pulsante da descrição (ex.: TextLabel "Description")
local function startPulse(label: TextLabel)
    local baseSize = label.TextSize
    local tweenInfo = TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
    local tween = TweenService:Create(label, tweenInfo, { TextSize = baseSize * 1.1 })
    tween:Play()
end

local function formatTime(seconds: number): string
    if seconds < 0 then seconds = 0 end
    local h = math.floor(seconds / 3600)
    local m = math.floor((seconds % 3600) / 60)
    local s = math.floor(seconds % 60)
    return string.format("%02d:%02d:%02d", h, m, s)
end

local running = false
local function attachCountdown(rootGui: Instance)
    if running then return end
    running = true
    local countdownLabel = findDescByNameContains(rootGui, "TextLabel", "countdown") :: TextLabel?
    local descLabel = findDescByNameContains(rootGui, "TextLabel", "description") :: TextLabel?
    if descLabel then
        startPulse(descLabel)
    end

    local function update()
        local nextAt = LOCAL_PLAYER:GetAttribute("NextSpinAt")
        if typeof(nextAt) ~= "number" then return end
        local nowSec = os.time()
        local remain = nextAt - nowSec
        if countdownLabel then
            countdownLabel.Text = formatTime(remain)
        end
    end

    -- Atualiza a cada segundo
    task.spawn(function()
        while running do
            update()
            task.wait(1)
        end
    end)

    -- Reage a mudanças do atributo
    LOCAL_PLAYER:GetAttributeChangedSignal("NextSpinAt"):Connect(update)
    update()
end

-- Inicializa quando a GUI de Spin estiver disponível
local function tryHook()
    local sg = findScreenGuiByNameContains(playerGui, "gui spin")
    if not sg then return end
    local main = findFirstGuiObject(sg) or sg
    attachCountdown(main)
end

tryHook()
playerGui.DescendantAdded:Connect(function(desc)
    if desc:IsA("ScreenGui") and string.find(string.lower(desc.Name), "gui spin") then
        tryHook()
    end
end)

print("[UI] Spin UI controller ativo (pulse + countdown)")
