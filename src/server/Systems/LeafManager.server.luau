-- Gerencia o spawn de folhas, controlando o tempo e a quantidade.

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

-- Módulo que sabe como criar uma folha (novo caminho organizado)
local function listChildrenNames(inst)
    local names = {}
    for _, child in ipairs(inst:GetChildren()) do
        table.insert(names, child.Name .. "(" .. child.ClassName .. ")")
    end
    return table.concat(names, ", ")
end

local Leaf
do
    local serverFolder = ServerScriptService:WaitForChild("Server", 10)
    if not serverFolder then
        warn("[LeafManager] Pasta 'Server' não encontrada dentro de ServerScriptService. Filhos:", listChildrenNames(ServerScriptService))
    end
    local modulesFolder = serverFolder and serverFolder:WaitForChild("Modules", 10)
    if not modulesFolder then
        warn("[LeafManager] Pasta 'Modules' não encontrada. Filhos de Server:", serverFolder and listChildrenNames(serverFolder) or "<nil>")
    end
    local leafModuleInstance = modulesFolder and (modulesFolder:FindFirstChild("Leaf") or modulesFolder:FindFirstChild("Leaf.module"))
    if not leafModuleInstance then
        warn("[LeafManager] ModuleScript 'Leaf' não encontrado em Modules. Filhos de Modules:", modulesFolder and listChildrenNames(modulesFolder) or "<nil>")
    else
        Leaf = require(leafModuleInstance)
    end
end

if not Leaf then
    warn("[LeafManager] Falha ao carregar o módulo Leaf. O spawn não será iniciado até que o módulo exista.")
end

-- Configurações do spawner
local SPAWN_INTERVAL = 2
local MAX_LEAVES = 500

-- Variáveis
local lastSpawnTime = 0
local activeLeaves = {}
local spawningStopped = false

-- Referências
local leavesSpawnPlatform = workspace:WaitForChild("LeavesSpawn")
local leafTemplate = workspace:WaitForChild("Leaves"):WaitForChild("Leaf")

-- Função para verificar se deve parar o spawn
local function checkSpawnLimit()
    if #activeLeaves >= MAX_LEAVES then
        if not spawningStopped then
            spawningStopped = true
            -- print("Limite de folhas atingido! Spawn pausado.")
        end
        return true
    else
        if spawningStopped then
            spawningStopped = false
            -- print("Spawn reativado!")
        end
        return false
    end
end

-- Loop principal do spawner
RunService.Heartbeat:Connect(function()
    local currentTime = tick()
    if currentTime - lastSpawnTime >= SPAWN_INTERVAL then
        if Leaf and not checkSpawnLimit() then
            local created = Leaf.create(leavesSpawnPlatform, leafTemplate, activeLeaves)
            if created then
                -- Log leve para confirmar spawn (comentar depois se desejar)
                -- print("🍂 Leaf spawnada:", created.Name, "em", created.Position)
            end
            lastSpawnTime = currentTime
        end
    end
end)

print("🌳 LeafManager iniciado! Folhas caem da arvore a cada", SPAWN_INTERVAL, "segundos.")
print("🍃 Maximo de", MAX_LEAVES, "folhas.")
