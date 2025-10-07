-- Gerencia o teleporte de jogadores para outros mundos.

local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Pega o RemoteEvent que vem da GUI
local guiButtonClickEvent = ReplicatedStorage:WaitForChild("GuiButtonClickEvent")

-- Função que será executada quando o evento for recebido do cliente
-- Defina como true para simular teleporte no Studio
local SIMULATE_IN_STUDIO = true

local function onGuiButtonClicked(player)
    print("Evento de clique recebido do jogador:", player.Name, "- Preparando para teleporte!")
    
    -- 🆔 COLE A ID DO SEU NOVO MAPA AQUI
    local destinationPlaceId = 125206130988315 -- SUBSTITUA PELO ID DO SEU NOVO MAPA
    
    -- Pega a pontuação atual do jogador no leaderboard
    local currentScore = 0
    if _G.LeaderboardSystem and _G.LeaderboardSystem.getScore then
        currentScore = _G.LeaderboardSystem.getScore(player)
    end
    
    -- 🎒 Cria uma "mochila de dados" para enviar junto com o jogador
    local teleportData = {
        leaves = currentScore,
        lastWorld = "MundoDaFloresta"
    }
    
    -- Configura as opções de teleporte com os dados
    local teleportOptions = Instance.new("TeleportOptions")
    teleportOptions:SetTeleportData(teleportData)
    
    -- Studio fallback: simula teleporte local para testes
    if RunService:IsStudio() and SIMULATE_IN_STUDIO then
        print("[Studio] Simulando teleporte para o Place ID:", destinationPlaceId, "com dados:", teleportData and teleportData.leaves)

        -- Aplica os dados como se tivesse chegado no destino
        local leaderstats = player:FindFirstChild("leaderstats")
        if leaderstats then
            local leavesCollected = leaderstats:FindFirstChild("LeavesCollected")
            if leavesCollected and teleportData and teleportData.leaves then
                leavesCollected.Value = teleportData.leaves
            end
        end

        -- Move o jogador para um spawn local opcional (crie um Part chamado "StudioTeleportSpawn")
        local destinationSpawn = workspace:FindFirstChild("StudioTeleportSpawn")
        local character = player.Character
        if destinationSpawn and character and character.PrimaryPart then
            character:PivotTo(destinationSpawn.CFrame)
            print("[Studio] Player movido para StudioTeleportSpawn.")
        else
            print("[Studio] Nenhum 'StudioTeleportSpawn' encontrado. Apenas simulando dados.")
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
