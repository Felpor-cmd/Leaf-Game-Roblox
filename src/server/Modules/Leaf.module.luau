-- Este módulo contém toda a lógica para criar e configurar uma única folha.

local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local Leaf = {}

function Leaf.create(leavesSpawnPlatform, leafTemplate, activeLeaves)
    local newLeaf = leafTemplate:Clone()
    newLeaf.Name = "SpawnedLeaf_" .. tick()
    
    local platformSize = leavesSpawnPlatform.Size
    local platformPosition = leavesSpawnPlatform.Position
    
    local spawnRadius = platformSize.X/2 + 5
    local randomX = platformPosition.X + math.random(-spawnRadius, spawnRadius)
    local randomZ = platformPosition.Z + math.random(-spawnRadius, spawnRadius)
    local spawnY = platformPosition.Y + platformSize.Y/2 + 25
    
    local minY = platformPosition.Y + platformSize.Y/2 + newLeaf.Size.Y/2
    
    newLeaf.Anchored = false
    newLeaf.CanCollide = false
    newLeaf.Position = Vector3.new(randomX, spawnY, randomZ)
    
    local bodyVelocity = Instance.new("BodyVelocity")
    bodyVelocity.MaxForce = Vector3.new(3000, 3000, 3000)
    bodyVelocity.Velocity = Vector3.new(math.random(-8, 8), -6, math.random(-8, 8))
    bodyVelocity.Parent = newLeaf
    
    local bodyAngularVelocity = Instance.new("BodyAngularVelocity")
    bodyAngularVelocity.MaxTorque = Vector3.new(2000, 2000, 2000)
    bodyAngularVelocity.AngularVelocity = Vector3.new(math.random(-5, 5), math.random(-5, 5), math.random(-5, 5))
    bodyAngularVelocity.Parent = newLeaf
    
    local connection
    connection = RunService.Heartbeat:Connect(function()
        if newLeaf.Parent and newLeaf.Position.Y <= minY then
            local currentPos = newLeaf.Position
            local alignedY = minY + 0.1
            newLeaf.Position = Vector3.new(currentPos.X, alignedY, currentPos.Z)
            newLeaf.CanCollide = true
            
            if bodyVelocity.Parent then bodyVelocity:Destroy() end
            if bodyAngularVelocity.Parent then bodyAngularVelocity:Destroy() end
            
            local stabilizer = Instance.new("BodyPosition")
            stabilizer.MaxForce = Vector3.new(0, 2000, 0)
            stabilizer.Position = Vector3.new(currentPos.X, alignedY, currentPos.Z)
            stabilizer.Parent = newLeaf
            Debris:AddItem(stabilizer, 1)
            
            connection:Disconnect()
        end
    end)
    
    Debris:AddItem(bodyVelocity, 4)
    Debris:AddItem(bodyAngularVelocity, 4)
    
    newLeaf.Parent = workspace
    table.insert(activeLeaves, newLeaf)
    
    newLeaf.Touched:Connect(function(hit)
        if not hit or not hit.Parent then return end
        local player = game.Players:GetPlayerFromCharacter(hit.Parent)
        if player and _G.LeaderboardSystem then
            print("👋 [BACKUP-TOUCH] Coletando folha de", player.Name)
            _G.LeaderboardSystem.updateScore(player, 1)
            newLeaf:Destroy()
        end
    end)
    
    newLeaf.AncestryChanged:Connect(function()
        if not newLeaf.Parent then
            if connection then connection:Disconnect() end
            for i, leaf in ipairs(activeLeaves) do
                if leaf == newLeaf then
                    table.remove(activeLeaves, i)
                    break
                end
            end
        end
    end)
    
    return newLeaf
end

return Leaf
