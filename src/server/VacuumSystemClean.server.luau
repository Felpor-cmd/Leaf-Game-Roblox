-- VacuumSystem.server.luau
-- Sistema de transformacao e aspiracao de folhas com efeitos sutis

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- Configuracoes do sistema
local VACUUM_RANGE = 20 -- Distancia maxima para aspirar folhas
local VACUUM_FORCE = 25 -- Forca de atracao das folhas (reduzida para ser mais sutil)
local VACUUM_UPDATE_RATE = 0.1 -- Atualiza aspiracao a cada 0.1 segundos (10 FPS)

-- Variaveis de controle
local playersWithVacuum = {} -- Tabela para rastrear jogadores com poder
local vacuumConnections = {} -- Conexoes dos loops de aspiracao
local lastVacuumUpdate = {} -- Ultima atualizacao para cada jogador
local cachedLeaves = {} -- Cache de folhas para evitar busca constante

-- Referencias
local transformWall = workspace:WaitForChild("TransformWall")

-- Funcao para atualizar cache de folhas (executa menos frequentemente)
local function updateLeavesCache()
    cachedLeaves = {}
    
    for _, obj in pairs(workspace:GetChildren()) do
        -- Verifica se e uma folha spawnnada
        if obj.Name:find("SpawnedLeaf_") and (obj:IsA("Part") or obj:IsA("MeshPart") or obj:IsA("Model")) then
            table.insert(cachedLeaves, obj)
        end
    end
end

-- Atualiza cache a cada 0.5 segundos
spawn(function()
    while true do
        updateLeavesCache()
        wait(0.5) -- Cache atualizado 2 vezes por segundo
    end
end)

-- Funcao para verificar se a folha esta na frente do jogador (OTIMIZADA)
local function isLeafInFront(character, leaf)
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return false end
    
    local playerLookDirection = humanoidRootPart.CFrame.LookVector
    local toLeaf = (leaf.Position - humanoidRootPart.Position).Unit
    
    -- Calculo simplificado - apenas verifica se esta aproximadamente na frente
    local dotProduct = playerLookDirection:Dot(toLeaf)
    return dotProduct > 0.3 -- Aproximadamente 70 graus, mais permissivo e rapido
end

-- Funcao para aspirar folhas (OTIMIZADA)
local function vacuumLeaves(player)
    local character = player.Character
    if not character then return end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    -- Controle de taxa de atualizacao por jogador
    local currentTime = tick()
    if lastVacuumUpdate[player] and (currentTime - lastVacuumUpdate[player]) < VACUUM_UPDATE_RATE then
        return -- Pula esta atualizacao
    end
    lastVacuumUpdate[player] = currentTime
    
    local leavesProcessed = 0
    local maxLeavesPerFrame = 5 -- Processa no maximo 5 folhas por frame
    
    -- Usa cache ao inves de procurar todos os objetos
    for i = #cachedLeaves, 1, -1 do -- Itera de tras para frente para remocao segura
        local obj = cachedLeaves[i]
        if leavesProcessed >= maxLeavesPerFrame then break end
        
        -- Verifica se o objeto ainda existe
        if obj and obj.Parent then
            leavesProcessed = leavesProcessed + 1
            
            -- Para Models, pega a PrimaryPart ou primeira Part/MeshPart
            local leafPart = obj
            if obj:IsA("Model") then
                leafPart = obj.PrimaryPart or obj:FindFirstChildOfClass("Part") or obj:FindFirstChildOfClass("MeshPart")
            end
            
            if leafPart then
                local distance = (leafPart.Position - humanoidRootPart.Position).Magnitude
                
                -- So processa folhas proximas (otimizacao)
                if distance <= VACUUM_RANGE then
                    -- Verifica se esta na frente do jogador
                    if isLeafInFront(character, leafPart) then
                        -- Remove fisica existente apenas se nao tiver forca de vacuo
                        local existingBodyVelocity = leafPart:FindFirstChild("VacuumForce")
                        if not existingBodyVelocity then
                            -- Remove outras forcas
                            for _, child in pairs(leafPart:GetChildren()) do
                                if child:IsA("BodyVelocity") or child:IsA("BodyAngularVelocity") then
                                    child:Destroy()
                                end
                            end
                            
                            -- Configura folha
                            leafPart.Anchored = false
                            leafPart.CanCollide = false
                            
                            -- Cria forca de atracao
                            local bodyVelocity = Instance.new("BodyVelocity")
                            bodyVelocity.Name = "VacuumForce"
                            bodyVelocity.MaxForce = Vector3.new(10000, 10000, 10000)
                            
                            -- Cria rotacao durante aspiracao para efeito mais sutil
                            local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
                            bodyAngularVelocity.Name = "VacuumSpin"
                            bodyAngularVelocity.MaxTorque = Vector3.new(5000, 5000, 5000)
                            bodyAngularVelocity.AngularVelocity = Vector3.new(
                                math.random(-8, 8),
                                math.random(-8, 8),
                                math.random(-8, 8)
                            )
                            
                            local direction = (humanoidRootPart.Position - leafPart.Position).Unit
                            local force = VACUUM_FORCE * 2
                            
                            bodyVelocity.Velocity = direction * force
                            bodyVelocity.Parent = leafPart
                            bodyAngularVelocity.Parent = leafPart
                        end
                        
                        -- Coleta folha se muito proxima
                        if distance < 5 then
                            print("Jogador", player.Name, "aspirou uma folha!")
                            obj:Destroy()
                            -- Remove do cache
                            table.remove(cachedLeaves, i)
                        end
                    end
                end
            end
        else
            -- Remove objeto inexistente do cache
            table.remove(cachedLeaves, i)
        end
    end
end

-- Funcao para dar poderes de aspirador ao jogador
local function giveVacuumPower(player)
    if playersWithVacuum[player] then return end -- Ja tem o poder
    
    playersWithVacuum[player] = true
    lastVacuumUpdate[player] = 0 -- Inicializa contador
    print("Jogador", player.Name, "ganhou poderes de aspirador!")
    
    -- Efeito visual no jogador (opcional)
    local character = player.Character
    if character then
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if humanoidRootPart then
            -- Adiciona um efeito visual
            local attachment = Instance.new("Attachment")
            attachment.Name = "VacuumEffect"
            attachment.Parent = humanoidRootPart
        end
    end
    
    -- Inicia o loop de aspiracao para este jogador (OTIMIZADO)
    vacuumConnections[player] = RunService.Heartbeat:Connect(function()
        if playersWithVacuum[player] then -- Verifica se ainda tem o poder
            vacuumLeaves(player)
        end
    end)
end

-- Funcao para remover poderes de aspirador do jogador
local function removeVacuumPower(player)
    if not playersWithVacuum[player] then return end -- Nao tem o poder
    
    playersWithVacuum[player] = nil
    lastVacuumUpdate[player] = nil
    print("Jogador", player.Name, "perdeu poderes de aspirador!")
    
    -- Remove efeito visual
    local character = player.Character
    if character then
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if humanoidRootPart then
            local effect = humanoidRootPart:FindFirstChild("VacuumEffect")
            if effect then
                effect:Destroy()
            end
        end
    end
    
    -- Para o loop de aspiracao
    if vacuumConnections[player] then
        vacuumConnections[player]:Disconnect()
        vacuumConnections[player] = nil
    end
end

-- Funcao para detectar passagem pela parede
local function onWallTouch(hit, player)
    local character = hit.Parent
    local humanoid = character:FindFirstChild("Humanoid")
    
    if humanoid and player then
        local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
        if not humanoidRootPart then return end
        
        -- Determina de que lado da parede o jogador esta
        local wallPosition = transformWall.Position
        local playerPosition = humanoidRootPart.Position
        
        -- Assume que a parede esta orientada no eixo X
        -- Lado esquerdo (X menor) = sem poder, Lado direito (X maior) = com poder
        local isOnPowerSide = playerPosition.X > wallPosition.X
        
        if isOnPowerSide and not playersWithVacuum[player] then
            -- Jogador entrou no lado do poder
            giveVacuumPower(player)
        elseif not isOnPowerSide and playersWithVacuum[player] then
            -- Jogador saiu do lado do poder
            removeVacuumPower(player)
        end
    end
end

-- Conecta eventos de toque na parede
transformWall.Touched:Connect(function(hit)
    local player = Players:GetPlayerFromCharacter(hit.Parent)
    if player then
        onWallTouch(hit, player)
    end
end)

-- Limpeza quando jogador sai do jogo
Players.PlayerRemoving:Connect(function(player)
    if vacuumConnections[player] then
        vacuumConnections[player]:Disconnect()
        vacuumConnections[player] = nil
    end
    playersWithVacuum[player] = nil
    lastVacuumUpdate[player] = nil
end)

print("VacuumSystem iniciado com efeitos sutis!")
print("Performance: Atualizacao a cada", VACUUM_UPDATE_RATE, "segundos | Max 5 folhas/frame")
print("Alcance:", VACUUM_RANGE, "studs | Forca:", VACUUM_FORCE, "| Com rotacao suave")
