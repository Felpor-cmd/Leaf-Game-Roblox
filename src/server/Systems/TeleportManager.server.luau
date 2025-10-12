-- Gerencia o teleporte de jogadores para outros mundos.

local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Pega o RemoteEvent que vem da GUI
local guiButtonClickEvent = ReplicatedStorage:WaitForChild("GuiButtonClickEvent")

-- Mapeamento de mundos -> PlaceId (substitua pelos reais quando tiver)
local WORLD_PLACES: {[number]: number} = {
    [1] = 125206130988315, -- Mundo 1
    [2] = 125206130988315, -- Mundo 2 (placeholder)
    [3] = 125206130988315, -- Mundo 3 (placeholder)
    [4] = 125206130988315, -- Mundo 4 (placeholder)
}

-- Função que será executada quando o evento for recebido do cliente
-- Defina como true para simular teleporte no Studio
local SIMULATE_IN_STUDIO = true

local function onGuiButtonClicked(player, worldId)
    -- worldId pode vir como string do cliente: tenta converter
    if typeof(worldId) == "string" then worldId = tonumber(worldId) end
    if typeof(worldId) ~= "number" then worldId = 1 end

    -- Valida worldId no mapeamento
    local destinationPlaceId = WORLD_PLACES[worldId]
    if not destinationPlaceId then
        warn("[Teleport] worldId inválido recebido:", worldId, "-> usando 1 por padrão")
        worldId = 1
        destinationPlaceId = WORLD_PLACES[1]
    end

    print(string.format("Evento de clique recebido: %s -> worldId=%d, destino PlaceId=%d", player.Name, worldId, destinationPlaceId))
    
    -- Pega a pontuação atual do jogador no leaderboard
    local currentScore = 0
    if _G.LeaderboardSystem and _G.LeaderboardSystem.getScore then
        currentScore = _G.LeaderboardSystem.getScore(player)
    end
    
    -- 🎒 Cria uma "mochila de dados" para enviar junto com o jogador
    local teleportData = {
        leaves = currentScore,
        lastWorld = "MundoDaFloresta",
        worldId = worldId,
        spawnName = "WorldSpawn" .. tostring(worldId), -- usado no servidor de destino
    }
    
    -- Configura as opções de teleporte com os dados
    local teleportOptions = Instance.new("TeleportOptions")
    teleportOptions:SetTeleportData(teleportData)
    
    -- Studio fallback: simula teleporte local para testes
    if RunService:IsStudio() and SIMULATE_IN_STUDIO then
        print("[Studio] Simulando teleporte para o Place ID:", destinationPlaceId, "worldId:", worldId, "dados leaves:", teleportData and teleportData.leaves)

        -- Aplica os dados como se tivesse chegado no destino
        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats then
            local leavesCollected = leaderstats:FindFirstChild("LeavesCollected")
            if leavesCollected and teleportData and teleportData.leaves then
                leavesCollected.Value = teleportData.leaves
            end
        end

        -- Move o jogador para um spawn local opcional (crie um Part chamado "StudioTeleportSpawn")
        local destinationSpawn = workspace:FindFirstChild("StudioTeleportSpawn" .. tostring(worldId)) or workspace:FindFirstChild("StudioTeleportSpawn")
        local character = player.Character
        if destinationSpawn and character and character.PrimaryPart then
            -- Offset acima da parte para evitar ficar preso no chão/parte
            local height = destinationSpawn.Size and destinationSpawn.Size.Y or 4
            local offset = CFrame.new(0, height/2 + 3, 0)
            character:PivotTo(destinationSpawn.CFrame * offset)
            print("[Studio] Player movido para", destinationSpawn.Name, "com offset acima")
        else
            print("[Studio] Nenhum 'StudioTeleportSpawn" .. tostring(worldId) .. "' encontrado. Apenas simulando dados.")
        end
        return
    end

    -- 🚀 Teleporta o jogador para o novo servidor (modo real)
    print("Teleportando", player.Name, "para o Place ID:", destinationPlaceId, "com", currentScore, "folhas.")
    local ok, err = pcall(function()
        TeleportService:TeleportAsync(destinationPlaceId, {player}, teleportOptions)
    end)
    if not ok then
        warn("[Teleport] Falha ao iniciar teleporte:", err)
    end
end

-- Conecta a função ao evento do servidor
guiButtonClickEvent.OnServerEvent:Connect(onGuiButtonClicked)

print("📡 TeleportManager iniciado e ouvindo eventos da GUI.")
