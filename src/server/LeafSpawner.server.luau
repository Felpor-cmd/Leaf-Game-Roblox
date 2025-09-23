-- LeafSpawner.server.luau
-- Script responsável por spawnar folhas periodicamente na plataforma LeavesSpawn

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

-- Configurações do spawner
local SPAWN_INTERVAL = 2 -- Intervalo entre spawns em segundos
local MAX_LEAVES = 50 -- Máximo de folhas simultâneas (para de spawnar quando atingir)

-- Variáveis
local lastSpawnTime = 0
local activeLeaves = {}
local spawningStopped = false -- Flag para controlar se o spawn parou

-- Função para aguardar e obter referências
local function waitForObjects()
    print("Aguardando objetos LeavesSpawn e Leaves...")
    
    local leavesSpawnPlatform = workspace:WaitForChild("LeavesSpawn", 10)
    if not leavesSpawnPlatform then
        error("LeavesSpawn não encontrado no workspace!")
    end
    
    local leavesModel = workspace:WaitForChild("Leaves", 10)
    if not leavesModel then
        error("Leaves não encontrado no workspace!")
    end
    
    print("Objetos encontrados com sucesso!")
    return leavesSpawnPlatform, leavesModel
end

-- Obter referências aos objetos no workspace
local leavesSpawnPlatform, leavesModel = waitForObjects()

-- Função para criar uma folha usando o modelo personalizado Leaves/Leaf
local function createLeafFromModel()
    -- Obtém a Part "Leaf" dentro do modelo "Leaves"
    local leafTemplate = leavesModel:FindFirstChild("Leaf")
    if not leafTemplate then
        warn("Part 'Leaf' não encontrada dentro do modelo 'Leaves'!")
        return
    end
    
    -- Clona apenas a Part da folha (não o modelo inteiro)
    local newLeaf = leafTemplate:Clone()
    newLeaf.Name = "SpawnedLeaf_" .. tick()
    
    -- print("DEBUG: Folha criada com nome:", newLeaf.Name, "| Tipo:", newLeaf.ClassName)
    
    -- Define posição aleatória na plataforma
    local platformSize = leavesSpawnPlatform.Size
    local platformPosition = leavesSpawnPlatform.Position
    
    local randomX = platformPosition.X + math.random(-platformSize.X/2, platformSize.X/2)
    local randomZ = platformPosition.Z + math.random(-platformSize.Z/2, platformSize.Z/2)
    local spawnY = platformPosition.Y + platformSize.Y/2 + 10 -- Spawna acima da plataforma
    
    -- Altura mínima onde a folha deve parar (superfície da plataforma)
    local minY = platformPosition.Y + platformSize.Y/2 + newLeaf.Size.Y/2
    
    -- Configura a folha
    newLeaf.Anchored = false
    newLeaf.CanCollide = false
    newLeaf.Position = Vector3.new(randomX, spawnY, randomZ)
    
    -- Adiciona uma tag para identificar folhas spawnnadas
    local stringValue = Instance.new("StringValue")
    stringValue.Name = "LeafTag"
    stringValue.Value = "SpawnedLeaf"
    stringValue.Parent = newLeaf
    
    -- Adiciona física para a folha cair
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(4000, 4000, 4000)
    bodyVelocity.Velocity = Vector3.new(
        math.random(-5, 5), -- Movimento horizontal aleatório
        -10, -- Queda
        math.random(-5, 5)
    )
    bodyVelocity.Parent = newLeaf
    
    -- Adiciona rotação para a folha girar no ar
    local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
    bodyAngularVelocity.MaxTorque = Vector3.new(4000, 4000, 4000)
    bodyAngularVelocity.AngularVelocity = Vector3.new(
        math.random(-10, 10), -- Rotação em X (pitch)
        math.random(-10, 10), -- Rotação em Y (yaw)
        math.random(-10, 10)  -- Rotação em Z (roll)
    )
    bodyAngularVelocity.Parent = newLeaf
    
    -- Sistema para parar a folha quando atingir a plataforma
    local connection
    connection = RunService.Heartbeat:Connect(function()
        if newLeaf.Parent and newLeaf.Position.Y <= minY then
            -- Para a folha na altura da plataforma (alinhada perfeitamente)
            local currentPos = newLeaf.Position
            local alignedY = minY + 0.1 -- Pequeno offset para ficar ligeiramente acima da superficie
            newLeaf.Position = Vector3.new(currentPos.X, alignedY, currentPos.Z)
            
            -- Liga colisao para a folha ficar apoiada na plataforma
            newLeaf.Anchored = false
            newLeaf.CanCollide = true -- Liga colisao para apoiar na plataforma
            
            -- Remove a física (movimento e rotação)
            if bodyVelocity and bodyVelocity.Parent then
                bodyVelocity:Destroy()
            end
            if bodyAngularVelocity and bodyAngularVelocity.Parent then
                bodyAngularVelocity:Destroy()
            end
            
            -- Adiciona BodyVelocity para manter posicao estavel
            local stabilizer = Instance.new("BodyVelocity")
            stabilizer.MaxForce = Vector3.new(0, 1000, 0)
            stabilizer.Velocity = Vector3.new(0, 0, 0) -- Sem movimento, apenas estabiliza
            stabilizer.Parent = newLeaf
            
            -- Remove estabilizador após a folha se acomodar
            Debris:AddItem(stabilizer, 2)
            
            -- Desconecta o loop
            connection:Disconnect()
            
            -- print("Folha personalizada pousou na plataforma:", newLeaf.Position)
        end
    end)
    
    -- Remove a velocidade e rotação após um tempo para deixar a folha cair naturalmente
    Debris:AddItem(bodyVelocity, 2)
    Debris:AddItem(bodyAngularVelocity, 2)
    
    -- Adiciona a folha ao workspace
    newLeaf.Parent = workspace
    -- print("DEBUG: Folha adicionada ao workspace:", newLeaf.Name, "| Parent:", newLeaf.Parent.Name)
    
    -- Adiciona à lista de folhas ativas
    table.insert(activeLeaves, newLeaf)
    
    -- Sistema de detecção de toque do jogador
    local function onTouch(hit)
        local humanoid = hit.Parent:FindFirstChild("Humanoid")
        if humanoid then
            -- Verifica se é realmente um jogador
            local player = game.Players:GetPlayerFromCharacter(hit.Parent)
            if player then
                -- print("Jogador", player.Name, "coletou uma folha!")
                
                -- Remove folha imediatamente
                newLeaf:Destroy()
            end
        end
    end
    
    -- Conecta o evento de toque
    newLeaf.Touched:Connect(onTouch)
    
    -- Remove da lista quando for destruída
    newLeaf.AncestryChanged:Connect(function()
        if not newLeaf.Parent then
            for i, leaf in ipairs(activeLeaves) do
                if leaf == newLeaf then
                    table.remove(activeLeaves, i)
                    break
                end
            end
            -- Garante que a conexão seja limpa
            if connection then
                connection:Disconnect()
            end
            
            -- Reativa o spawn se estava parado
            if spawningStopped and #activeLeaves < MAX_LEAVES then
                spawningStopped = false
                -- print("Spawn reativado! Folhas ativas:", #activeLeaves)
            end
        end
    end)
    
    -- print("Folha personalizada spawnada em:", newLeaf.Position)
end

-- Função para verificar se deve parar o spawn
local function checkSpawnLimit()
    if #activeLeaves >= MAX_LEAVES then
        if not spawningStopped then
            spawningStopped = true
            -- print("Limite de folhas atingido! Spawn pausado. Folhas ativas:", #activeLeaves)
        end
        return true
    end
    return false
end

-- Loop principal do spawner
local function onHeartbeat()
    local currentTime = tick()
    
    if currentTime - lastSpawnTime >= SPAWN_INTERVAL then
        -- Verifica se as referências ainda existem
        if leavesSpawnPlatform and leavesSpawnPlatform.Parent and 
           leavesModel and leavesModel.Parent then
            
            -- Verifica se deve parar o spawn
            if not checkSpawnLimit() then
                createLeafFromModel()
                lastSpawnTime = currentTime
            end
        else
            warn("LeavesSpawn ou Leaves não encontrados no workspace!")
        end
    end
end

-- Conecta o loop principal
RunService.Heartbeat:Connect(onHeartbeat)

print("LeafSpawner iniciado! Folhas serão spawnadas a cada", SPAWN_INTERVAL, "segundos.")
print("Máximo de", MAX_LEAVES, "folhas. Toque nas folhas para coletá-las!")
