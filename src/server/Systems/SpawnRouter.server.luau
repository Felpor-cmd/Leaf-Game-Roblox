-- SpawnRouter.server.luau
-- Em cada Place de destino, posiciona o jogador no spawn correto com base no TeleportData

local Players = game:GetService("Players")

local function moveToSpawn(player: Player, spawnName: string?)
    if not spawnName or spawnName == "" then return end

    -- Tenta achar a Part de destino no Workspace
    local target = workspace:FindFirstChild(spawnName)
    if not target or not target:IsA("BasePart") then
        warn("[SpawnRouter] Spawn não encontrado:", spawnName)
        return
    end

    -- Aguarda o Character carregar e o PrimaryPart ficar disponível
    local character = player.Character or player.CharacterAdded:Wait()
    local okPrimary = character:WaitForChild("HumanoidRootPart", 10)
    if not okPrimary then
        warn("[SpawnRouter] HumanoidRootPart não disponível para:", player.Name)
        return
    end

    -- Move o jogador para o spawn, com offset acima da parte
    local height = target.Size and target.Size.Y or 4
    local offset = CFrame.new(0, height/2 + 3, 0)
    character:PivotTo(target.CFrame * offset)
    print(string.format("[SpawnRouter] %s posicionado em %s", player.Name, spawnName))
end

local function onPlayerAdded(player: Player)
    -- Lê dados de teleporte
    local joinData = player:GetJoinData()
    local spawnName: string? = nil
    local worldId: number? = nil
    if joinData and joinData.TeleportData then
        spawnName = joinData.TeleportData.spawnName
        worldId = joinData.TeleportData.worldId
    end

    -- Fallback: se vier apenas worldId, gera nome padrão
    if (not spawnName or spawnName == "") and typeof(worldId) == "number" then
        spawnName = "WorldSpawn" .. tostring(worldId)
    end

    if not spawnName then
        print("[SpawnRouter] Sem TeleportData.spawnName; mantendo spawn padrão do jogo.")
        return
    end

    -- Espera o Character para fazer o pivot
    if player.Character then
        moveToSpawn(player, spawnName)
    end
    player.CharacterAdded:Connect(function()
        moveToSpawn(player, spawnName)
    end)
end

Players.PlayerAdded:Connect(onPlayerAdded)

print("📍 SpawnRouter iniciado: aguardando TeleportData.spawnName para posicionar jogadores.")
