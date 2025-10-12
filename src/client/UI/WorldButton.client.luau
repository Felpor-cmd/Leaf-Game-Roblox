-- WorldButton Binder (Client)
-- Em vez de um script por botão, este binder procura por todos os botões
-- de mundo no PlayerGui e conecta automaticamente os cliques.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LOCAL_PLAYER = Players.LocalPlayer
local playerGui = LOCAL_PLAYER:WaitForChild("PlayerGui")

local remoteEvent = ReplicatedStorage:WaitForChild("GuiButtonClickEvent")

local function resolveWorldIdFromButton(btn: GuiButton)
	local attr = btn:GetAttribute("WorldId")
	if typeof(attr) == "number" then return attr end
	local name = btn.Name:lower()
	local idText = string.match(name, "(%d+)")
	if idText then
		local idNum = tonumber(idText)
		if typeof(idNum) == "number" then return idNum end
	end
	-- Tenta extrair do texto visível do botão
	local anyText: string? = (btn :: any).Text
	if typeof(anyText) == "string" then
		local txtId = string.match(string.lower(anyText), "(%d+)")
		if txtId then
			local idNum2 = tonumber(txtId)
			if typeof(idNum2) == "number" then return idNum2 end
		end
	end
	return nil
end

local function isUnderWorldsPanel(inst: Instance): boolean
	local current = inst.Parent
	while current and current ~= playerGui do
		if (current:IsA("Frame") or current:IsA("ScreenGui")) and string.find(string.lower(current.Name), "gui worlds") then
			return true
		end
		current = current.Parent
	end
	return false
end

local function hookButton(btn: GuiButton)
	if btn:GetAttribute("WorldButtonHooked") then return end
	btn:SetAttribute("WorldButtonHooked", true)
	btn.MouseButton1Click:Connect(function()
		local worldId = resolveWorldIdFromButton(btn)
		if typeof(worldId) ~= "number" then
			-- Não identificado como botão de mundo válido; ignora.
			return
		end
		print(string.format("[UI] Mundo botão '%s' clicado -> worldId=%d", btn.Name, worldId))
		remoteEvent:FireServer(worldId)
	end)
end

local function scanAndHook()
	for _, inst in ipairs(playerGui:GetDescendants()) do
		if inst:IsA("GuiButton") then
			if isUnderWorldsPanel(inst) then
				hookButton(inst)
			end
		end
	end
end

-- Inicializa e mantém atualizado quando GUIs aparecem depois
scanAndHook()
playerGui.DescendantAdded:Connect(function(desc)
	if desc:IsA("GuiButton") and isUnderWorldsPanel(desc) then
		hookButton(desc)
	end
end)

print("[UI] WorldButton binder ativo: procurando e conectando botões de mundo.")
