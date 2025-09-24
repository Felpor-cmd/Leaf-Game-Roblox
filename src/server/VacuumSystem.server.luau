-- VacuumSystem.server.luau
-- Sistema de aspiracao de folhas ULTRA OTIMIZADO

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

-- === CONFIGURACOES OTIMIZADAS ===
local VACUUM_RANGE = 12 -- Reduzido de 20 para 12 (mais realista)
local VACUUM_FORCE = 120 -- Forca aumentada para aspiracao mais potente
local COLLECTION_AREA_SIZE = 60
local BOUNDARY_CHECK_RATE = 0.1 -- Reduzido para verificação mais frequente

-- === VARIAVEIS DE CONTROLE ===
local playersWithVacuum = {}
local vacuumConnections = {}
local wallTouchDebounce = {}
local cachedLeaves = {} -- Cache para evitar busca constante
local lastCacheUpdate = 0

-- === REFERENCIAS CACHADAS ===
local transformWall = workspace:WaitForChild("TransformWall")
local leavesSpawnPlatform = workspace:WaitForChild("LeavesSpawn")

-- === FUNCOES UTILITARIAS OTIMIZADAS ===
local function createNeonTrail(leafPart)
    -- Remove trilha existente se houver
    local existingTrail = leafPart:FindFirstChild("NeonTrail")
    if existingTrail then
        existingTrail:Destroy()
    end
    
    -- Cria anexo para a trilha
    local attachment0 = Instance.new("Attachment")
    attachment0.Name = "TrailAttachment0"
    attachment0.Position = Vector3.new(0, 0, 0)
    attachment0.Parent = leafPart
    
    local attachment1 = Instance.new("Attachment")  
    attachment1.Name = "TrailAttachment1"
    attachment1.Position = Vector3.new(0, 0, 0)
    attachment1.Parent = leafPart
    
    -- Cria a trilha neon
    local trail = Instance.new("Trail")
    trail.Name = "NeonTrail"
    trail.Attachment0 = attachment0
    trail.Attachment1 = attachment1
    
    -- Configurações visuais da trilha
    trail.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 127)),    -- Verde neon
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(127, 255, 212)), -- Verde claro
        ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255))    -- Branco
    }
    trail.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.2),   -- Início mais opaco
        NumberSequenceKeypoint.new(1, 1.0)    -- Final transparente
    }
    trail.Lifetime = 0.8        -- Duração da trilha
    trail.MinLength = 0.1       -- Comprimento mínimo
    trail.FaceCamera = true     -- Sempre virada para câmera
    trail.WidthScale = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.5),   -- Largura no início
        NumberSequenceKeypoint.new(1, 0.1)    -- Largura no final
    }
    
    trail.Parent = leafPart
    
    -- Remove trilha após um tempo para performance
    game:GetService("Debris"):AddItem(trail, 3)
    
    -- Adiciona efeito de brilho à folha
    local pointLight = Instance.new("PointLight")
    pointLight.Name = "VacuumGlow"
    pointLight.Color = Color3.fromRGB(0, 255, 127)
    pointLight.Brightness = 2
    pointLight.Range = 8
    pointLight.Parent = leafPart
    
    -- Remove luz após um tempo
    game:GetService("Debris"):AddItem(pointLight, 3)
    
    -- Adiciona efeito de partículas (estrelas/faíscas)
    local sparkleAttachment = Instance.new("Attachment")
    sparkleAttachment.Name = "SparkleAttachment"
    sparkleAttachment.Parent = leafPart
    
    local sparkleEffect = Instance.new("ParticleEmitter")
    sparkleEffect.Name = "VacuumSparkles"
    sparkleEffect.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    sparkleEffect.Lifetime = NumberRange.new(0.3, 0.8)
    sparkleEffect.Rate = 15
    sparkleEffect.SpreadAngle = Vector2.new(45, 45)
    sparkleEffect.Speed = NumberRange.new(2, 4)
    sparkleEffect.Color = ColorSequence.new(Color3.fromRGB(127, 255, 212))
    sparkleEffect.Size = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.1),
        NumberSequenceKeypoint.new(1, 0.01)
    }
    sparkleEffect.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0, 0.5),
        NumberSequenceKeypoint.new(1, 1.0)
    }
    sparkleEffect.Parent = sparkleAttachment
    
    -- Remove efeito de partículas após um tempo
    game:GetService("Debris"):AddItem(sparkleEffect, 3)
    
    return trail
end

local function removeVisualEffects(leafPart)
    -- Remove todos os efeitos visuais da folha
    local effectsToRemove = {
        "NeonTrail",
        "TrailAttachment0", 
        "TrailAttachment1",
        "VacuumGlow",
        "SparkleAttachment"
    }
    
    for _, effectName in pairs(effectsToRemove) do
        local effect = leafPart:FindFirstChild(effectName)
        if effect then
            effect:Destroy()
        end
    end
end

local function updateLeavesCache()
    -- Atualiza cache apenas se necessario
    local currentTime = tick()
    if currentTime - lastCacheUpdate < 0.5 then return end -- Cache valido por 0.5s
    lastCacheUpdate = currentTime
    
    -- Limpa cache anterior
    table.clear(cachedLeaves)
    
    -- Popula cache com busca otimizada
    for _, obj in pairs(workspace:GetChildren()) do
        if obj.Name:find("SpawnedLeaf_") then
            local leafPart = obj
            if obj:IsA("Model") then
                leafPart = obj.PrimaryPart or obj:FindFirstChildOfClass("Part") or obj:FindFirstChildOfClass("MeshPart")
            end
            if leafPart and obj:IsA("Part") or obj:IsA("MeshPart") or (obj:IsA("Model") and leafPart) then
                cachedLeaves[#cachedLeaves + 1] = {obj = obj, part = leafPart}
            end
        end
    end
end

local function isLeafInCollectionArea(leafPosition)
    local distance = (leafPosition - leavesSpawnPlatform.Position).Magnitude
    return distance <= COLLECTION_AREA_SIZE
end

-- === SISTEMA DE COLETA UNIVERSAL ===
local function checkGlobalLeafCollection()
    -- Verifica coleta para TODOS os players (mesmo sem poder de vacuo)
    for _, player in pairs(Players:GetPlayers()) do
        local character = player.Character
        if character then
            local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
            if humanoidRootPart then
                local playerPosition = humanoidRootPart.Position
                
                -- Verifica folhas próximas para coleta
                for i = #cachedLeaves, 1, -1 do
                    local leafData = cachedLeaves[i]
                    local obj, leafPart = leafData.obj, leafData.part
                    
                    if obj and obj.Parent and leafPart then
                        local distance = (leafPart.Position - playerPosition).Magnitude
                        local heightDifference = math.abs(leafPart.Position.Y - playerPosition.Y)
                        
                        -- Coleta folha se muito próxima E não muito alta (sistema universal - mais sensível)
                        if distance < 3.5 and heightDifference < 6 then
                            print("🍃 [UNIVERSAL] Coletando folha de", player.Name, "- Distancia:", math.floor(distance * 100) / 100)
                            
                            -- Remove efeitos visuais antes de destruir
                            removeVisualEffects(leafPart)
                            
                            -- Atualiza leaderboard
                            if _G.LeaderboardSystem then
                                _G.LeaderboardSystem.updateScore(player, 1)
                                print("📊 Leaderboard atualizado para", player.Name)
                            end
                            
                            obj:Destroy()
                            table.remove(cachedLeaves, i)
                            break
                        end
                    else
                        table.remove(cachedLeaves, i)
                    end
                end
            end
        end
    end
end

-- === SISTEMA DE LIMPEZA DE AREA (ULTRA RAPIDO) ===
spawn(function()
    while true do
        wait(0.1) -- Reduzido de 0.5 para 0.1 segundos (10x mais rápido)
        
        -- Usa cache para verificacao de limites (mais eficiente)
        updateLeavesCache()
        
        for i = #cachedLeaves, 1, -1 do
            local leafData = cachedLeaves[i]
            local obj, leafPart = leafData.obj, leafData.part
            
            if obj and obj.Parent and leafPart then
                if not isLeafInCollectionArea(leafPart.Position) then
                    obj:Destroy()
                    table.remove(cachedLeaves, i)
                end
            else
                table.remove(cachedLeaves, i)
            end
        end
        
        -- Sistema de coleta universal (sempre ativo - ULTRA RAPIDO)
        checkGlobalLeafCollection()
    end
end)

-- === SISTEMA DE COLETA INSTANTANEO (60 FPS) ===
-- Adiciona um sistema de coleta em tempo real para folhas muito próximas
RunService.Heartbeat:Connect(function()
    -- Coleta instantânea para folhas muito próximas (distância crítica)
    for _, player in pairs(Players:GetPlayers()) do
        local character = player.Character
        if character then
            local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
            if humanoidRootPart then
                local playerPosition = humanoidRootPart.Position
                
                -- Verifica apenas folhas muito próximas para coleta instantânea
                for i = #cachedLeaves, 1, -1 do
                    local leafData = cachedLeaves[i]
                    local obj, leafPart = leafData.obj, leafData.part
                    
                    if obj and obj.Parent and leafPart then
                        local distance = (leafPart.Position - playerPosition).Magnitude
                        local heightDifference = math.abs(leafPart.Position.Y - playerPosition.Y)
                        
                        -- Coleta INSTANTÂNEA se extremamente próxima E na altura certa
                        if distance < 1.5 and heightDifference < 4 then
                            print("⚡ [INSTANTÂNEO] Coletando folha de", player.Name, "- Distancia:", math.floor(distance * 100) / 100)
                            
                            -- Remove efeitos visuais antes de destruir
                            removeVisualEffects(leafPart)
                            
                            -- Atualiza leaderboard
                            if _G.LeaderboardSystem then
                                _G.LeaderboardSystem.updateScore(player, 1)
                            end
                            
                            obj:Destroy()
                            table.remove(cachedLeaves, i)
                            break
                        end
                    else
                        table.remove(cachedLeaves, i)
                    end
                end
            end
        end
    end
end)

-- === SISTEMA DE ASPIRACAO ULTRA OTIMIZADO ===
local function vacuumLeaves(player)
    local character = player.Character
    if not character then return end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    -- Atualiza cache se necessario
    updateLeavesCache()
    
    local playerPosition = humanoidRootPart.Position
    -- Processamento em tempo real - sem limite de folhas por frame
    
    -- Processa folhas do cache (tempo real)
    for i = 1, #cachedLeaves do        
        local leafData = cachedLeaves[i]
        local obj, leafPart = leafData.obj, leafData.part
        
        if obj and obj.Parent and leafPart then
            -- Calcula distância 3D normal
            local distance = (leafPart.Position - playerPosition).Magnitude
            
            -- Calcula distância horizontal (X e Z apenas) para controle do vácuo
            local horizontalDistance = math.sqrt(
                (leafPart.Position.X - playerPosition.X)^2 + 
                (leafPart.Position.Z - playerPosition.Z)^2
            )
            
            -- Verifica altura para não puxar folhas muito altas
            local heightDifference = math.abs(leafPart.Position.Y - playerPosition.Y)
            local maxHeight = 8 -- Máximo 8 studs de altura
            
            -- Só aplica vácuo se estiver na distância horizontal E altura razoável
            if horizontalDistance <= VACUUM_RANGE and heightDifference <= maxHeight then
                
                -- Verifica se ja tem forca aplicada
                local hasVacuumForce = leafPart:FindFirstChild("VacuumForce")
                
                if not hasVacuumForce then
                    -- Remove outras forcas (otimizado)
                    for _, child in pairs(leafPart:GetChildren()) do
                        if child:IsA("BodyVelocity") or child:IsA("BodyAngularVelocity") then
                            child:Destroy()
                        end
                    end
                    
                    -- Configura folha para aspiracao
                    leafPart.Anchored = false
                    leafPart.CanCollide = false
                    
                    -- Cria trilha neon para efeito visual
                    createNeonTrail(leafPart)
                    
                    -- Cria forca de atracao
                    local bodyVelocity = Instance.new("BodyVelocity")
                    bodyVelocity.Name = "VacuumForce"
                    bodyVelocity.MaxForce = Vector3.new(20000, 20000, 20000) -- Aumentado para aplicacao de forca mais forte
                    
                    local direction = (playerPosition - leafPart.Position).Unit
                    -- Multiplicador baseado na distância horizontal - mais forte quando perto
                    local distanceMultiplier = math.max(0.5, 1 - (horizontalDistance / VACUUM_RANGE) * 0.5)
                    local finalForce = VACUUM_FORCE * distanceMultiplier
                    
                    bodyVelocity.Velocity = direction * finalForce
                    bodyVelocity.Parent = leafPart
                    
                    -- Rotacao suave (otimizada)
                    local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
                    bodyAngularVelocity.Name = "VacuumSpin"
                    bodyAngularVelocity.MaxTorque = Vector3.new(4000, 4000, 4000)
                    bodyAngularVelocity.AngularVelocity = Vector3.new(
                        math.random(-6, 6),
                        math.random(-6, 6), 
                        math.random(-6, 6)
                    )
                    bodyAngularVelocity.Parent = leafPart
                end
                
                -- Coleta folha se proxima o suficiente (aumentado para detecção mais agressiva)
                if distance < 5 then
                    -- Debug: confirma coleta
                    print("🍃 Coletando folha de", player.Name, "- Distancia:", math.floor(distance * 100) / 100)
                    
                    -- Remove efeitos visuais antes de destruir
                    removeVisualEffects(leafPart)
                    
                    -- Atualiza leaderboard do player
                    if _G.LeaderboardSystem then
                        _G.LeaderboardSystem.updateScore(player, 1)
                        print("📊 Leaderboard atualizado para", player.Name)
                    else
                        print("⚠️  LeaderboardSystem não encontrado!")
                    end
                    
                    obj:Destroy()
                    -- Remove do cache
                    table.remove(cachedLeaves, i)
                    break -- Sai do loop para evitar indices invalidos
                end
            end
        end
    end
end

-- === SISTEMA DE PODERES (OTIMIZADO) ===
local function giveVacuumPower(player)
    if playersWithVacuum[player] then return end
    
    playersWithVacuum[player] = true
    print("🌪️", player.Name, "ganhou poderes de aspirador!")
    
    -- Loop otimizado com menos overhead
    vacuumConnections[player] = RunService.Heartbeat:Connect(function()
        vacuumLeaves(player)
    end)
end

local function removeVacuumPower(player)
    if not playersWithVacuum[player] then return end
    
    playersWithVacuum[player] = nil
    print("🚫", player.Name, "perdeu poderes de aspirador!")
    
    local connection = vacuumConnections[player]
    if connection then
        connection:Disconnect()
        vacuumConnections[player] = nil
    end
end

-- === DETECCAO DE PAREDE (OTIMIZADA) ===
local function onWallTouch(hit, player)
    local character = hit.Parent
    if not character:FindFirstChild("Humanoid") then return end
    
    -- Debounce otimizado (reduzido para mais responsividade)
    local currentTime = tick()
    local lastTouch = wallTouchDebounce[player]
    if lastTouch and (currentTime - lastTouch) < 0.3 then return end -- Reduzido de 0.8 para 0.3
    wallTouchDebounce[player] = currentTime
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    if not humanoidRootPart then return end
    
    -- Calculo simplificado de lado
    local isOnPowerSide = humanoidRootPart.Position.X > transformWall.Position.X
    
    if isOnPowerSide and not playersWithVacuum[player] then
        giveVacuumPower(player)
    elseif not isOnPowerSide and playersWithVacuum[player] then
        removeVacuumPower(player)
    end
    
    -- Debug: mostra posição atual
    print("🔍 [WALL TOUCH]", player.Name, 
          "- Pos X:", math.floor(humanoidRootPart.Position.X),
          "- Wall X:", math.floor(transformWall.Position.X),
          "- Lado correto:", isOnPowerSide,
          "- Tem poder:", playersWithVacuum[player] ~= nil)
end

-- === CONEXOES DE EVENTOS ===
-- Sistema de detecção por toque (backup)
transformWall.Touched:Connect(function(hit)
    local player = Players:GetPlayerFromCharacter(hit.Parent)
    if player then
        onWallTouch(hit, player)
    end
end)

-- === SISTEMA DE DETECCAO CONTINUA ===
-- Verifica posição de todos os players a cada segundo
spawn(function()
    while true do
        wait(1) -- Verifica a cada 1 segundo
        
        for _, player in pairs(Players:GetPlayers()) do
            local character = player.Character
            if character then
                local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
                if humanoidRootPart then
                    -- Calcula se está do lado certo da parede
                    local isOnPowerSide = humanoidRootPart.Position.X > transformWall.Position.X
                    
                    -- Gerencia poderes baseado na posição
                    if isOnPowerSide and not playersWithVacuum[player] then
                        giveVacuumPower(player)
                        print("🔄 [CONTÍNUO] Poder de vácuo ativado para", player.Name)
                    elseif not isOnPowerSide and playersWithVacuum[player] then
                        removeVacuumPower(player)
                        print("🔄 [CONTÍNUO] Poder de vácuo removido de", player.Name)
                    end
                end
            end
        end
    end
end)

-- Limpeza automatica
Players.PlayerRemoving:Connect(function(player)
    local connection = vacuumConnections[player]
    if connection then
        connection:Disconnect()
    end
    
    playersWithVacuum[player] = nil
    wallTouchDebounce[player] = nil
    vacuumConnections[player] = nil
end)

-- === DETECCAO PARA NOVOS PLAYERS ===
-- Verifica novos players que entram no jogo
Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function(character)
        wait(2) -- Aguarda character carregar completamente
        
        local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
        if humanoidRootPart then
            local isOnPowerSide = humanoidRootPart.Position.X > transformWall.Position.X
            
            if isOnPowerSide then
                giveVacuumPower(player)
                print("🆕 [NOVO PLAYER]", player.Name, "spawnou na zona de poder!")
            end
        end
    end)
end)

-- === INICIALIZACAO ===
print("🚀 VacuumSystem ULTRA OTIMIZADO iniciado!")
print("⚡ Performance: Processamento em TEMPO REAL")
print("🎯 Alcance:", VACUUM_RANGE, "studs (horizontal) | Forca:", VACUUM_FORCE, "| Area:", COLLECTION_AREA_SIZE)
print("📏 Limites de altura: Vacuo (8 studs) | Universal (6 studs) | Instantaneo (4 studs)")
print("🔥 TRIPLE SYSTEM: Vacuo (5 studs) + Universal (3.5 studs) + Instantaneo (1.5 studs)")
print("⚡ Coleta: 60 FPS instantânea + 10 FPS universal + Touch backup")
print("🌍 Sistema Universal: Coleta folhas mesmo sem poder de vacuo!")
print("🔄 Detecção contínua: Verifica posição dos players a cada segundo")
print("✨ EFEITOS VISUAIS: Trilhas neon + Brilho + Partículas nas folhas sugadas!")

-- Verifica integracao com leaderboard
if _G.LeaderboardSystem then
    print("📊 Integrado com LeaderboardSystem - pontuacao automatica!")
else
    print("⚠️  LeaderboardSystem nao encontrado - sem pontuacao")
end

-- === VERIFICACAO INICIAL DE POSICOES ===
-- Verifica players que já estão na posição correta quando o servidor inicia
spawn(function()
    wait(3) -- Aguarda um pouco para garantir que tudo carregou
    
    for _, player in pairs(Players:GetPlayers()) do
        local character = player.Character
        if character then
            local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
            if humanoidRootPart then
                local isOnPowerSide = humanoidRootPart.Position.X > transformWall.Position.X
                
                if isOnPowerSide and not playersWithVacuum[player] then
                    giveVacuumPower(player)
                    print("✅ [INICIAL]", player.Name, "já estava na zona de poder!")
                end
            end
        end
    end
end)
