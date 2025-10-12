-- UiController.client.luau
-- Orquestra interações dos botões de UI (lado do cliente)
-- Requisito: Ao clicar no primeiro botão (Worlds) na lista "GUI Buttons Left",
-- mover a UI "GUI Worlds" para o centro da tela em Position {0.516, 0}, {0.5, 0}

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LOCAL_PLAYER = Players.LocalPlayer
local playerGui = LOCAL_PLAYER:WaitForChild("PlayerGui")

-- Configs
local TARGET_POSITION = UDim2.new(0.516, 0, 0.5, 0)
local CLOSE_POSITION = UDim2.new(1.5, 0, 0.5, 0) -- fecha para fora da tela (lado direito)
local TWEEN_TIME = 0.35
local TWEEN_STYLE = Enum.EasingStyle.Quad
local TWEEN_DIRECTION = Enum.EasingDirection.Out

-- Utils
local function findScreenGuiByNameContains(root: Instance, namePart: string): ScreenGui?
	namePart = namePart:lower()
	for _, inst in ipairs(root:GetDescendants()) do
		if inst:IsA("ScreenGui") and inst.Name:lower():find(namePart) then
			return inst
		end
	end
	return nil
end

local function findFirstGuiObject(container: Instance): GuiObject?
	for _, inst in ipairs(container:GetDescendants()) do
		if inst:IsA("GuiObject") then
			return inst
		end
	end
	return nil
end

local function findButtonByNameContains(root: Instance, namePart: string): GuiButton?
	namePart = namePart:lower()
	for _, inst in ipairs(root:GetDescendants()) do
		if inst:IsA("GuiButton") and inst.Name:lower():find(namePart) then
			return inst
		end
	end
	return nil
end

local function getGuiWorldsTarget(): GuiObject?
	-- Tenta encontrar uma ScreenGui chamada (ou contendo) "GUI Worlds"
	local guiWorlds = findScreenGuiByNameContains(playerGui, "gui worlds")
	if guiWorlds then
		-- ScreenGui não tem Position; tentamos achar o primeiro GuiObject filho como content root
		local mainObject = findFirstGuiObject(guiWorlds)
		if mainObject then return mainObject end
	end

	-- Caso "GUI Worlds" seja diretamente um Frame no PlayerGui (menos comum)
	for _, inst in ipairs(playerGui:GetDescendants()) do
		if inst:IsA("GuiObject") and inst.Name:lower() == "gui worlds" then
			return inst
		end
	end

	return nil
end

-- Estado atual do painel aberto
local currentOpenPanel: GuiObject? = nil

local function safelyCenterGui(guiObj: GuiObject)
	-- Garante âncora central (opcional; respeita layouts existentes se já configurados)
	if guiObj.AnchorPoint ~= Vector2.new(0.5, 0.5) then
		guiObj.AnchorPoint = Vector2.new(0.5, 0.5)
	end
	-- Faz o tween para a posição alvo
	local tween = TweenService:Create(guiObj, TweenInfo.new(TWEEN_TIME, TWEEN_STYLE, TWEEN_DIRECTION), {
		Position = TARGET_POSITION
	})
	tween:Play()
end

local function safelyCloseGui(guiObj: GuiObject)
	-- Fecha com tween para fora da tela, e depois opcionalmente desabilita o ScreenGui
	if not guiObj then return end
	if guiObj.AnchorPoint ~= Vector2.new(0.5, 0.5) then
		guiObj.AnchorPoint = Vector2.new(0.5, 0.5)
	end
	local tween = TweenService:Create(guiObj, TweenInfo.new(TWEEN_TIME, TWEEN_STYLE, TWEEN_DIRECTION), {
		Position = CLOSE_POSITION
	})
	tween:Play()
	tween.Completed:Connect(function()
		local sg = guiObj:FindFirstAncestorOfClass("ScreenGui")
		if sg then sg.Enabled = false end
	end)
end

local function openWorldsPanel()
	local guiTarget = getGuiWorldsTarget()
	if not guiTarget then
		warn("[UI] 'GUI Worlds' não encontrado (ScreenGui ou Frame). Verifique os nomes no PlayerGui.")
		return
	end
	local parentScreenGui = guiTarget:FindFirstAncestorOfClass("ScreenGui")
	if parentScreenGui then
		parentScreenGui.Enabled = true
	end
	-- Se outro painel estiver aberto e for diferente, fecha-o primeiro
	if currentOpenPanel and currentOpenPanel ~= guiTarget then
		safelyCloseGui(currentOpenPanel)
	end
	-- Abre e marca como atual
	safelyCenterGui(guiTarget)
	currentOpenPanel = guiTarget
end

local function closeCurrentPanel()
	if currentOpenPanel then
		safelyCloseGui(currentOpenPanel)
		currentOpenPanel = nil
	else
		-- nada aberto
	end
end

local function connectLeftButtons()
	-- Encontra o container da lista de botões da esquerda
	local leftButtonsGui = findScreenGuiByNameContains(playerGui, "gui buttons left")
	if not leftButtonsGui then
		warn("[UI] 'GUI Buttons Left' não encontrado no PlayerGui. Certifique-se que o ScreenGui existe.")
		return
	end

	-- Conecta todos os botões; marca com atributo para evitar conexões duplicadas
	for _, inst in ipairs(leftButtonsGui:GetDescendants()) do
		if inst:IsA("GuiButton") and not inst:GetAttribute("UiHooked") then
			inst:SetAttribute("UiHooked", true)
			local nameLower = inst.Name:lower()
			if nameLower:find("worlds") then
				inst.MouseButton1Click:Connect(function()
					print("[UI] Botão Worlds clicado -> abrir painel 'GUI Worlds'")
					openWorldsPanel()
				end)
			else
				inst.MouseButton1Click:Connect(function()
					print("[UI] Botão da esquerda (", inst.Name, ") clicado -> fechar painel atual, se houver")
					closeCurrentPanel()
				end)
			end
		end
	end

	print("[UI] Botões da esquerda conectados.")
end

local function connectExitButton()
	-- Procura por um botão chamado "Exit" dentro de um Frame "Exit" (ou nomes contendo)
	local candidate: GuiButton? = nil
	for _, inst in ipairs(playerGui:GetDescendants()) do
		if inst:IsA("GuiButton") and inst.Name:lower():find("exit") then
			local ancestor = inst.Parent
			while ancestor and ancestor ~= playerGui do
				if ancestor:IsA("Frame") or ancestor:IsA("ScreenGui") then
					if ancestor.Name:lower():find("exit") then
						candidate = inst
						break
					end
				end
				ancestor = ancestor.Parent
			end
			if candidate then break end
		end
	end

	if candidate and not candidate:GetAttribute("UiHooked") then
		candidate:SetAttribute("UiHooked", true)
		candidate.MouseButton1Click:Connect(function()
			print("[UI] Botão Exit clicado -> fechar painel atual")
			closeCurrentPanel()
		end)
		print("[UI] Botão Exit conectado.")
	else
		if not candidate then
			warn("[UI] Botão Exit não encontrado (procure por Frame/ScreenGui com nome contendo 'Exit').")
		end
	end
end

-- Inicialização
connectLeftButtons()
connectExitButton()
-- Conector de contador de folhas será adicionado abaixo

-- Caso GUIs sejam inseridas depois, reconecta
playerGui.DescendantAdded:Connect(function(desc)
	if desc:IsA("ScreenGui") or desc:IsA("GuiButton") then
		connectLeftButtons()
		connectExitButton()
	end
end)

-- ====== LEAVES COUNTER (espelhar leaderstats) ======
local function findTextLabelIn(container: Instance): TextLabel?
	for _, inst in ipairs(container:GetDescendants()) do
		if inst:IsA("TextLabel") then return inst end
	end
	return nil
end

local function getLeavesCounterLabel(): TextLabel?
	-- Procura a ScreenGui "GUI Buttons Right"
	local rightGui = findScreenGuiByNameContains(playerGui, "gui buttons right")
	if not rightGui then return nil end

	-- Procura objeto "Leaves Counter" dentro
	local counterContainer: GuiObject? = nil
	for _, inst in ipairs(rightGui:GetDescendants()) do
		if inst:IsA("GuiObject") and inst.Name:lower():find("leaves counter") then
			counterContainer = inst
			break
		end
	end
	if not counterContainer then
		return nil
	end

	-- Se for um TextLabel direto, usa; senão, tenta achar um TextLabel filho
	if counterContainer:IsA("TextLabel") then
		return counterContainer
	end
	return findTextLabelIn(counterContainer)
end

local function formatLeavesText(value: number): string
	-- Abreviação: 1.2k, 3.4M, 10B, 500T (sem prefixo de texto)
	local sign = value < 0 and "-" or ""
	value = math.abs(value)

	if value < 1000 then
		return sign .. tostring(value)
	end

	local scales = {
		{1e12, "T"},
		{1e9,  "B"},
		{1e6,  "M"},
		{1e3,  "k"}, -- 'k' minúsculo conforme exemplo
	}

	for _, s in ipairs(scales) do
		local threshold, suffix = s[1], s[2]
		if value >= threshold then
			local v = value / threshold
			local formatted
			if v < 10 then
				formatted = string.format("%.1f", v)
			else
				formatted = string.format("%.0f", v)
			end
			formatted = string.gsub(formatted, "%.0$", "")
			return sign .. formatted .. suffix
		end
	end

	return sign .. tostring(value)
end

local leavesConnectionsSet = false
local function connectLeavesCounter()
	if leavesConnectionsSet then return end

	local leaderstats = LOCAL_PLAYER:FindFirstChild("leaderstats") or LOCAL_PLAYER:WaitForChild("leaderstats", 10)
	if not leaderstats then
		warn("[UI] leaderstats não encontrado para o jogador local.")
		return
	end
	local leavesValue = leaderstats:FindFirstChild("LeavesCollected") or leaderstats:WaitForChild("LeavesCollected", 10)
	if not leavesValue or not leavesValue:IsA("IntValue") then
		warn("[UI] LeavesCollected (IntValue) não encontrado em leaderstats.")
		return
	end

	local function applyToUi(newValue: number)
		local label = getLeavesCounterLabel()
		if not label then
			-- GUI pode não estar carregada ainda; silencioso
			return
		end
		label.Text = formatLeavesText(newValue)
	end

	-- Inicial
	applyToUi(leavesValue.Value)

	-- Atualizações
	leavesValue:GetPropertyChangedSignal("Value"):Connect(function()
		applyToUi(leavesValue.Value)
	end)
	-- Compatibilidade: alguns preferem .Changed
	leavesValue.Changed:Connect(function(v)
		if typeof(v) == "number" then
			applyToUi(v)
		else
			applyToUi(leavesValue.Value)
		end
	end)

	-- Quando GUIs aparecem depois, re-aplica o valor atual
	playerGui.DescendantAdded:Connect(function(desc)
		if desc:IsA("ScreenGui") or desc:IsA("GuiObject") then
			-- pequeno atraso para layout montar
			task.defer(function()
				applyToUi(leavesValue.Value)
			end)
		end
	end)

	leavesConnectionsSet = true
	print("[UI] Leaves Counter conectado ao leaderstats.")
end

-- Conectar contador de folhas
connectLeavesCounter()
