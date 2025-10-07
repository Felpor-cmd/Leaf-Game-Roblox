-- LeaderboardSystem.server.luau
-- Sistema de leaderboard para contagem de folhas coletadas

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

-- === CONFIGURACOES ===
local LEADERBOARD_NAME = "Leaves"
local DATA_STORE_NAME = "LeavesGameData"
local DATA_STORE_KEY = "PlayerLeaves_"

-- === DATASTORE ===
local dataStore = DataStoreService:GetDataStore(DATA_STORE_NAME)

-- === FUNCOES DE PERSISTENCIA ===
local function loadPlayerData(player)
    local success, data = pcall(function()
        local key = DATA_STORE_KEY .. player.UserId
        return dataStore:GetAsync(key)
    end)
    
    if success and data then
        print("📥", player.Name, "dados carregados:", data.leaves, "folhas")
        return data.leaves or 0
    else
        if not success then
            warn("❌ Erro ao carregar dados de", player.Name)
        else
            print("🆕", player.Name, "é um jogador novo!")
        end
        return 0
    end
end

local function savePlayerData(player, score)
    local success, errorMessage = pcall(function()
        local key = DATA_STORE_KEY .. player.UserId
        
        dataStore:SetAsync(key, {
            leaves = score,
            lastPlayed = os.time(),
            playerName = player.Name
        })
    end)
    
    if success then
        print("💾", player.Name, "dados salvos com sucesso!")
    else
        warn("❌ Erro ao salvar dados de", player.Name, ":", errorMessage)
    end
end

-- === FUNCOES PRINCIPAIS ===
local function createLeaderboard(player)
    -- Cria leaderstats se nao existir
    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then
        leaderstats = Instance.new("Folder")
        leaderstats.Name = "leaderstats"
        leaderstats.Parent = player
    end
    
    -- Cria contador de folhas
    local leavesCollected = leaderstats:FindFirstChild("LeavesCollected")
    if not leavesCollected then
        leavesCollected = Instance.new("IntValue")
        leavesCollected.Name = "LeavesCollected"
        
        -- Carrega dados salvos ou começa com 0
        local savedScore = loadPlayerData(player)
        leavesCollected.Value = savedScore
        
        leavesCollected.Parent = leaderstats
        
        -- Adiciona display name com cor verde claro
        local displayName = Instance.new("StringValue")
        displayName.Name = "DisplayName" 
        displayName.Value = "<font color='rgb(144, 238, 144')>" .. LEADERBOARD_NAME .. "</font>"
        displayName.Parent = leavesCollected
    end
    
    print("📊", player.Name, "adicionado ao leaderboard! Pontuação:", leavesCollected.Value)
    return leavesCollected
end

local function updateLeaderboard(player, amount)
    amount = amount or 1
    
    local leaderstats = player:FindFirstChild("leaderstats")
    if not leaderstats then
        createLeaderboard(player)
        leaderstats = player:FindFirstChild("leaderstats")
    end
    
    local leavesCollected = leaderstats:FindFirstChild("LeavesCollected")
    if leavesCollected then
        leavesCollected.Value = leavesCollected.Value + amount
        print("🍃", player.Name, "coletou folha! Total:", leavesCollected.Value)
        return leavesCollected.Value
    end
end

local function getPlayerScore(player)
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local leavesCollected = leaderstats:FindFirstChild("LeavesCollected")
        if leavesCollected then
            return leavesCollected.Value
        end
    end
    return 0
end

local function resetPlayerScore(player)
    local leaderstats = player:FindFirstChild("leaderstats")
    if leaderstats then
        local leavesCollected = leaderstats:FindFirstChild("LeavesCollected")
        if leavesCollected then
            leavesCollected.Value = 0
            print("🔄", player.Name, "score resetado!")
            return true
        end
    end
    return false
end

local function getTopPlayers(limit)
    limit = limit or 5
    local playerScores = {}
    
    for _, player in pairs(Players:GetPlayers()) do
        local score = getPlayerScore(player)
        if score > 0 then
            table.insert(playerScores, {
                name = player.Name,
                score = score
            })
        end
    end
    
    -- Ordena por score (maior para menor)
    table.sort(playerScores, function(a, b)
        return a.score > b.score
    end)
    
    -- Retorna apenas o limite especificado
    local topPlayers = {}
    for i = 1, math.min(limit, #playerScores) do
        table.insert(topPlayers, playerScores[i])
    end
    
    return topPlayers
end

-- === EVENTOS ===
-- Quando player entra
Players.PlayerAdded:Connect(function(player)
    createLeaderboard(player)
end)

-- Quando player sai (salva automaticamente)
Players.PlayerRemoving:Connect(function(player)
    local score = getPlayerScore(player)
    savePlayerData(player, score)
    print("👋", player.Name, "saiu do jogo. Pontuação salva:", score)
end)

-- Para players que ja estao no jogo
for _, player in pairs(Players:GetPlayers()) do
    createLeaderboard(player)
end

-- === AUTO-SAVE PERIODICO ===
-- Salva dados de todos os players a cada 5 minutos
spawn(function()
    while true do
        wait(300) -- 5 minutos
        
        for _, player in pairs(Players:GetPlayers()) do
            local score = getPlayerScore(player)
            savePlayerData(player, score)
        end
        
        print("💾 Auto-save realizado para todos os jogadores!")
    end
end)

-- === SISTEMA DE BACKUP DE EMERGENCIA ===
-- Salva dados quando o servidor está fechando
game:BindToClose(function()
    print("🚨 Servidor fechando - salvando todos os dados!")
    
    for _, player in pairs(Players:GetPlayers()) do
        local score = getPlayerScore(player)
        savePlayerData(player, score)
        print("💾 [EMERGÊNCIA]", player.Name, "dados salvos:", score)
    end
    
    -- Aguarda um pouco para garantir que os dados sejam salvos
    wait(2)
    print("✅ Backup de emergência concluído!")
end)

-- === COMANDOS DE CHAT ===
local function setupChatCommands(player)
    player.Chatted:Connect(function(message)
        message = message:lower()
        
        if message == "/top" or message == "/ranking" then
            local topPlayers = getTopPlayers(5)
            
            if #topPlayers == 0 then
                print("📊 Nenhuma folha coletada ainda!")
                return
            end
            
            print("🏆 TOP 5 COLETORES DE FOLHAS:")
            for i, playerData in ipairs(topPlayers) do
                local medal = ""
                if i == 1 then medal = "🥇"
                elseif i == 2 then medal = "🥈" 
                elseif i == 3 then medal = "🥉"
                else medal = "🏅" end
                
                print(medal, i .. "°", playerData.name .. ":", playerData.score, "folhas")
            end
            
        elseif message == "/myscore" or message == "/score" then
            local score = getPlayerScore(player)
            print("🍃", player.Name, "- Suas folhas coletadas:", score)
            
        elseif message == "/reset" then
            resetPlayerScore(player)
            
        elseif message == "/save" then
            local score = getPlayerScore(player)
            savePlayerData(player, score)
            print("💾", player.Name, "dados salvos manualmente!")
            
        elseif message == "/load" then
            local savedScore = loadPlayerData(player)
            local leaderstats = player:FindFirstChild("leaderstats")
            if leaderstats then
                local leavesCollected = leaderstats:FindFirstChild("LeavesCollected")
                if leavesCollected then
                    leavesCollected.Value = savedScore
                    print("📥", player.Name, "dados carregados:", savedScore, "folhas")
                end
            end
        end
    end)
end

-- Conecta comandos para players existentes
for _, player in pairs(Players:GetPlayers()) do
    setupChatCommands(player)
end

-- Conecta comandos para novos players  
Players.PlayerAdded:Connect(function(player)
    setupChatCommands(player)
end)

-- === FUNCOES PUBLICAS (para outros sistemas) ===
_G.LeaderboardSystem = {
    updateScore = updateLeaderboard,
    getScore = getPlayerScore,
    createLeaderboard = createLeaderboard,
    resetScore = resetPlayerScore,
    getTopPlayers = getTopPlayers,
    savePlayerData = savePlayerData,
    loadPlayerData = loadPlayerData
}

-- === INICIALIZACAO ===
print("📊 LeaderboardSystem carregado!")
print("🏆 Nome do leaderboard:", LEADERBOARD_NAME)
print("🔄 Atualização automática ao coletar folhas")
print("� DataStore ativo: Dados persistem entre sessões")
print("⏰ Auto-save a cada 5 minutos")
print("�💬 Comandos: /top, /myscore, /reset, /save, /load")
