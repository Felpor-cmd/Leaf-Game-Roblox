-- SpinSystem.server.luau
-- Gerencia 'spins' diários por jogador, contador de 24h e limite de 5.
-- Requisitos:
-- - Persistir por DataStore: spins e nextSpinAt (timestamp Unix do próximo crédito)
-- - Conceder spins com base no tempo passado (mesmo offline)
-- - Replicar valores para o cliente via Attributes no Player
-- - Integrar com Teleport: opcionalmente enviar via TeleportData (mantemos robusto em cross-place)

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local DAILY_SECONDS = 24 * 60 * 60
local MAX_SPINS = 5
local DATASTORE_NAME = "PlayerSpinData_v1"

local store = DataStoreService:GetDataStore(DATASTORE_NAME)

export type SpinData = {
    spins: number,
    nextSpinAt: number?, -- Unix epoch (os.time()) para o próximo crédito automático
}

local function clamp(n: number, min: number, max: number): number
    if n < min then return min end
    if n > max then return max end
    return n
end

local function now(): number
    return os.time()
end

local function defaultData(): SpinData
    return {
        spins = 1, -- novo jogador começa com 1
        nextSpinAt = now() + DAILY_SECONDS,
    }
end

local function safeUpdateAward(data: SpinData): SpinData
    -- Garante que spins sejam creditados conforme o tempo passado (offline ou online)
    local current = now()
    local nextAt = data.nextSpinAt or (current + DAILY_SECONDS)
    if data.spins == nil then data.spins = 0 end

    -- Crédito acumulado: para cada janela de 24h passada, +1 (até o limite)
    while current >= nextAt and data.spins < MAX_SPINS do
        data.spins += 1
        nextAt += DAILY_SECONDS
    end

    -- Se estourou limite, reprograma o próximo crédito a partir de agora (não empilha créditos infinitos)
    if data.spins >= MAX_SPINS then
        -- mantém nextAt correndo para o futuro
        if nextAt < current then
            nextAt = current + DAILY_SECONDS
        end
    end

    data.spins = clamp(data.spins, 0, MAX_SPINS)
    data.nextSpinAt = nextAt
    return data
end

local function loadDataAsync(userId: number): SpinData
    local ok, result = pcall(function()
        return store:GetAsync(tostring(userId))
    end)
    if ok and type(result) == "table" then
        local data: SpinData = {
            spins = tonumber(result.spins) or 0,
            nextSpinAt = tonumber(result.nextSpinAt) or (now() + DAILY_SECONDS),
        }
        return safeUpdateAward(data)
    end
    return defaultData()
end

local function saveDataAsync(userId: number, data: SpinData)
    pcall(function()
        store:SetAsync(tostring(userId), {
            spins = data.spins,
            nextSpinAt = data.nextSpinAt,
        })
    end)
end

-- Memória local por sessão
local sessionData: {[number]: SpinData} = {}

-- Replicação para o cliente via Attributes (acessível em LocalScripts)
local function replicateToClient(player: Player, data: SpinData)
    player:SetAttribute("Spins", data.spins)
    player:SetAttribute("NextSpinAt", data.nextSpinAt or 0)
end

-- API global simples (opcional)
_G.SpinSystem = {
    getData = function(player: Player): SpinData
        return sessionData[player.UserId] or defaultData()
    end,
    consumeSpin = function(player: Player): boolean
        local d = sessionData[player.UserId]
        if not d then return false end
        if d.spins <= 0 then return false end
        d.spins -= 1
        -- Se consumiu e não há agendamento, agenda próximo crédito
        if not d.nextSpinAt or d.nextSpinAt <= 0 then
            d.nextSpinAt = now() + DAILY_SECONDS
        end
        replicateToClient(player, d)
        return true
    end,
}

local function onPlayerAdded(player: Player)
    local data = loadDataAsync(player.UserId)
    sessionData[player.UserId] = data

    -- Caso tenha vindo TeleportData com valores mais recentes, aplica override conservador
    local joinData = player:GetJoinData()
    if joinData and joinData.TeleportData then
        local td = joinData.TeleportData
        local tdSpins = tonumber(td.spins)
        local tdNext = tonumber(td.nextSpinAt)
        if tdSpins and tdSpins > (data.spins or 0) then
            data.spins = clamp(tdSpins, 0, MAX_SPINS)
        end
        if tdNext and tdNext > (data.nextSpinAt or 0) then
            data.nextSpinAt = tdNext
        end
    end

    -- Garante crédito de acordo com tempo (se offline por muito tempo)
    data = safeUpdateAward(data)
    sessionData[player.UserId] = data
    replicateToClient(player, data)

    -- Auto-save periódico por jogador
    task.spawn(function()
        while player.Parent == Players do
            task.wait(60) -- salva a cada 60s
            saveDataAsync(player.UserId, sessionData[player.UserId])
        end
    end)
end

local function onPlayerRemoving(player: Player)
    local data = sessionData[player.UserId]
    if data then
        saveDataAsync(player.UserId, data)
    end
    sessionData[player.UserId] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Tick global (server) para verificar créditos de tempos em tempos (independente da presença do jogador)
-- Observação: DataStore não pode ser atualizado sem o contexto do jogador aqui, então só atualizamos in-memory
-- para conectados; os desconectados serão atualizados no próximo login pelo safeUpdateAward().
task.spawn(function()
    while true do
        task.wait(30)
        for _, player in ipairs(Players:GetPlayers()) do
            local d = sessionData[player.UserId]
            if d then
                local before = d.spins
                local updated = safeUpdateAward(d)
                sessionData[player.UserId] = updated
                if updated.spins ~= before then
                    replicateToClient(player, updated)
                    saveDataAsync(player.UserId, updated)
                end
            end
        end
    end
end)

print("🎰 SpinSystem iniciado: spins diários com limite de 5 e contador de 24h.")
