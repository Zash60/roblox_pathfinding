--[[
    Script de Pathfinding A* com UI Mobile para Roblox Executors (Delta)
    Criado por: Seu Assistente de IA
    Funcionalidades:
    - UI Amigável para Mobile
    - Set Start / Set End (Definir Início / Fim)
    - Autowalk (Caminhada Automática) com botão de ligar/desligar
    - Teleporte para o início ao começar
    - Visualização opcional do caminho
]]

-- CONFIGURAÇÕES
local VISUALIZE_PATH = true -- Mude para 'false' se não quiser ver as esferas do caminho

-- SERVIÇOS E VARIÁVEIS GLOBAIS
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

local startPos, endPos = nil, nil
local currentPath = nil
local isAutowalking = true
local isWalking = false

-- FUNÇÃO PARA NOTIFICAÇÕES (Simples)
local function notify(message)
    local notificationGui = Instance.new("ScreenGui", player.PlayerGui)
    notificationGui.Name = "NotificationGui"
    notificationGui.ResetOnSpawn = false

    local label = Instance.new("TextLabel", notificationGui)
    label.Size = UDim2.new(0.8, 0, 0.1, 0)
    label.Position = UDim2.new(0.1, 0, -0.15, 0)
    label.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    label.BackgroundTransparency = 0.2
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.SourceSansBold
    label.TextSize = 18
    label.TextWrapped = true
    label.Text = message
    label.ZIndex = 10

    local corner = Instance.new("UICorner", label)
    corner.CornerRadius = UDim.new(0, 8)

    label:TweenPosition(UDim2.new(0.1, 0, 0.05, 0), "Out", "Quad", 0.5, true)
    wait(3)
    label:TweenPosition(UDim2.new(0.1, 0, -0.15, 0), "In", "Quad", 0.5, true, function()
        notificationGui:Destroy()
    end)
end

-- CRIAÇÃO DA INTERFACE (UI)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PathfindingUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 200, 0, 250)
mainFrame.Position = UDim2.new(0, 10, 0.5, -125)
mainFrame.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
mainFrame.BackgroundTransparency = 0.1
mainFrame.BorderColor3 = Color3.fromRGB(200, 200, 200)
mainFrame.BorderSizePixel = 1
mainFrame.Draggable = true -- Permite arrastar a UI
mainFrame.Active = true
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner", mainFrame)
corner.CornerRadius = UDim.new(0, 12)

local titleLabel = Instance.new("TextLabel", mainFrame)
titleLabel.Size = UDim2.new(1, 0, 0, 30)
titleLabel.Position = UDim2.new(0, 0, 0, 0)
titleLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.Text = "Pathfinder A*"
local titleCorner = Instance.new("UICorner", titleLabel)
titleCorner.CornerRadius = UDim.new(0, 12)

local function createButton(text, yPos)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -20, 0, 35)
    button.Position = UDim2.new(0, 10, 0, yPos)
    button.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.SourceSans
    button.TextSize = 16
    button.Text = text
    button.Parent = mainFrame
    local btnCorner = Instance.new("UICorner", button)
    btnCorner.CornerRadius = UDim.new(0, 8)
    return button
end

-- BOTÕES
local setStartButton = createButton("[Set Start]", 40)
local setEndButton = createButton("[Set End]", 80)
local startPathButton = createButton("Start Pathfinding", 120)
startPathButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0) -- Verde
local autowalkButton = createButton("Autowalk: ON", 160)
autowalkButton.BackgroundColor3 = Color3.fromRGB(0, 180, 80) -- Verde claro

local statusLabel = Instance.new("TextLabel", mainFrame)
statusLabel.Size = UDim2.new(1, -20, 0, 40)
statusLabel.Position = UDim2.new(0, 10, 0, 200)
statusLabel.BackgroundColor3 = Color3.fromRGB(55, 55, 55)
statusLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
statusLabel.Font = Enum.Font.SourceSansLight
statusLabel.TextSize = 14
statusLabel.Text = "Status: Idle"
statusLabel.TextWrapped = true
local statusCorner = Instance.new("UICorner", statusLabel)
statusCorner.CornerRadius = UDim.new(0, 8)

-- LÓGICA DO PATHFINDING

local pathVisualizationFolder = Instance.new("Folder", workspace)
pathVisualizationFolder.Name = "PathVisualization"

local function clearPathVisualization()
    pathVisualizationFolder:ClearAllChildren()
end

local function visualizePath(path)
    if not VISUALIZE_PATH then return end
    clearPathVisualization()
    for i, waypoint in ipairs(path:GetWaypoints()) do
        local part = Instance.new("Part")
        part.Shape = Enum.PartType.Ball
        part.Material = Enum.Material.Neon
        part.Size = Vector3.new(0.5, 0.5, 0.5)
        part.Position = waypoint.Position
        part.Anchored = true
        part.CanCollide = false
        part.Color = Color3.fromRGB(255, 255, 0) -- Amarelo
        if i == 1 then
            part.Color = Color3.fromRGB(0, 255, 0) -- Verde para o início
        elseif i == #path:GetWaypoints() then
            part.Color = Color3.fromRGB(255, 0, 0) -- Vermelho para o fim
        end
        part.Parent = pathVisualizationFolder
    end
end

local function walkPath()
    if not currentPath or currentPath.Status ~= Enum.PathStatus.Success then
        statusLabel.Text = "Status: Caminho inválido ou não calculado."
        isWalking = false
        return
    end

    isWalking = true
    local waypoints = currentPath:GetWaypoints()
    visualizePath(currentPath)

    for i, waypoint in ipairs(waypoints) do
        if not isAutowalking or not isWalking then
            statusLabel.Text = "Status: Caminhada pausada."
            break
        end

        statusLabel.Text = string.format("Status: Andando para o ponto %d/%d", i, #waypoints)
        
        -- Se o ponto tiver uma ação de pulo, pule
        if waypoint.Action == Enum.PathWaypointAction.Jump then
            humanoid.Jump = true
        end
        
        humanoid:MoveTo(waypoint.Position)
        
        -- Espera até que o personagem chegue ou o tempo se esgote
        local timeOut = humanoid.WalkSpeed > 0 and (rootPart.Position - waypoint.Position).Magnitude / humanoid.WalkSpeed or 5
        local success = pcall(function()
            humanoid.MoveToFinished:Wait(timeOut + 2)
        end)
        
        if not success then
             -- Se o MoveToFinished não disparar (personagem preso), pare
            statusLabel.Text = "Status: Personagem preso. Parando."
            isWalking = false
            break
        end
    end
    
    if isWalking then
        statusLabel.Text = "Status: Destino alcançado!"
    end
    
    isWalking = false
    clearPathVisualization()
end


-- CONEXÕES DOS BOTÕES

setStartButton.MouseButton1Click:Connect(function()
    startPos = rootPart.Position
    notify("Posição inicial definida!")
    statusLabel.Text = "Início: Definido | Fim: Não definido"
end)

setEndButton.MouseButton1Click:Connect(function()
    endPos = rootPart.Position
    notify("Posição final definida!")
    if startPos then
        statusLabel.Text = "Início: Definido | Fim: Definido"
    else
        statusLabel.Text = "Início: Não definido | Fim: Definido"
    end
end)

autowalkButton.MouseButton1Click:Connect(function()
    isAutowalking = not isAutowalking
    if isAutowalking then
        autowalkButton.Text = "Autowalk: ON"
        autowalkButton.BackgroundColor3 = Color3.fromRGB(0, 180, 80)
        -- Se não estava andando, mas há um caminho, retoma
        if not isWalking and currentPath then
            walkPath()
        end
    else
        autowalkButton.Text = "Autowalk: OFF"
        autowalkButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        isWalking = false -- Força a parada da caminhada no próximo loop
    end
end)

startPathButton.MouseButton1Click:Connect(function()
    if isWalking then
        notify("Já estou andando!")
        return
    end
    
    if not startPos or not endPos then
        notify("Defina a posição inicial e final primeiro!")
        return
    end

    statusLabel.Text = "Status: Calculando caminho..."
    
    -- Teleporta o personagem para o início
    character:SetPrimaryPartCFrame(CFrame.new(startPos + Vector3.new(0, 3, 0))) -- Adiciona 3 studs no Y para não ficar preso no chão
    wait(0.2)
    
    local path = PathfindingService:CreatePath({
        AgentRadius = 3,
        AgentHeight = 6,
        AgentCanJump = true
    })

    local success, err = pcall(function()
        path:ComputeAsync(startPos, endPos)
    end)

    if not success or path.Status ~= Enum.PathStatus.Success then
        statusLabel.Text = "Status: Não foi possível encontrar um caminho!"
        notify("Erro: Não foi possível calcular a rota. O destino pode estar bloqueado.")
        currentPath = nil
        return
    end
    
    currentPath = path
    notify("Caminho calculado! Iniciando caminhada.")
    
    if isAutowalking then
        -- Usa uma coroutine para não travar o script enquanto anda
        coroutine.wrap(walkPath)()
    else
        statusLabel.Text = "Status: Caminho pronto. Ative o Autowalk."
        visualizePath(currentPath)
    end
end)

notify("Script de Pathfinding carregado!")
