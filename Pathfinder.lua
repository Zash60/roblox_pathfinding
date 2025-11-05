-- =============================================================================
-- Script de Pathfinding para Roblox com UI Móvel Avançada
-- Versão Final: Completo, com pulos automáticos, UI arrastável e visualização.
-- =============================================================================

-- Serviços do Roblox
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")

-- Variáveis do Jogador (serão atualizadas no respawn)
local player = Players.LocalPlayer
local character
local humanoid
local rootPart

-- Variáveis de Estado
local startPos = nil
local endPos = nil
local isWalking = false
local isSettingEnd = false

-- Configurações do Agente de Pathfinding (personagem)
local AGENT_PARAMS = {
    AgentRadius = 2.5,   -- Largura do personagem
    AgentHeight = 6,     -- Altura do personagem
    AgentCanJump = true, -- ESSENCIAL: Permite que o pathfinder planeje pulos
    WaypointSpacing = 4  -- Distância entre os pontos do caminho
}

-- Pasta para guardar os visuais do caminho no mundo
local pathVisualsFolder = workspace:FindFirstChild("PathVisuals") or Instance.new("Folder")
pathVisualsFolder.Name = "PathVisuals"
pathVisualsFolder.Parent = workspace

-- =============================================================================
-- SETUP DA INTERFACE DE USUÁRIO (UI)
-- =============================================================================

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PathfindingUI"
screenGui.ResetOnSpawn = false -- Para a UI não resetar a posição no respawn
screenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 250)
frame.Position = UDim2.new(0.8, -200, 0.5, -125)
frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
frame.BorderSizePixel = 0
frame.Draggable = true -- Habilita o arrasto do Frame
frame.Active = true
frame.Parent = screenGui

local titleBar = Instance.new("TextLabel")
titleBar.Size = UDim2.new(1, 0, 0, 30)
titleBar.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
titleBar.Text = "Pathfinder"
titleBar.TextColor3 = Color3.fromRGB(255, 255, 255)
titleBar.Font = Enum.Font.SourceSansBold
titleBar.Parent = frame

local minimizeButton = Instance.new("TextButton")
minimizeButton.Size = UDim2.new(0, 25, 0, 25)
minimizeButton.Position = UDim2.new(1, -28, 0, 3)
minimizeButton.Text = "-"
minimizeButton.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
minimizeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
minimizeButton.Parent = titleBar

local mainContainer = Instance.new("Frame")
mainContainer.Size = UDim2.new(1, 0, 1, -30)
mainContainer.Position = UDim2.new(0, 0, 0, 30)
mainContainer.BackgroundTransparency = 1
mainContainer.Parent = frame

local setStartButton = Instance.new("TextButton")
setStartButton.Size = UDim2.new(0.9, 0, 0, 35)
setStartButton.Position = UDim2.new(0.05, 0, 0, 10)
setStartButton.Text = "Set Start (Current Pos)"
setStartButton.Parent = mainContainer

local setEndButton = Instance.new("TextButton")
setEndButton.Size = UDim2.new(0.9, 0, 0, 35)
setEndButton.Position = UDim2.new(0.05, 0, 0, 50)
setEndButton.Text = "Set End (Click Map)"
setEndButton.Parent = mainContainer

local startButton = Instance.new("TextButton")
startButton.Size = UDim2.new(0.9, 0, 0, 35)
startButton.Position = UDim2.new(0.05, 0, 0, 90)
startButton.Text = "Start Autowalk"
startButton.BackgroundColor3 = Color3.fromRGB(30, 150, 30)
startButton.Parent = mainContainer

local stopButton = Instance.new("TextButton")
stopButton.Size = UDim2.new(0.9, 0, 0, 35)
stopButton.Position = UDim2.new(0.05, 0, 0, 130)
stopButton.Text = "Stop Autowalk"
stopButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
stopButton.Parent = mainContainer

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0.9, 0, 0, 40)
statusLabel.Position = UDim2.new(0.05, 0, 1, -40)
statusLabel.Text = "Status: Ready"
statusLabel.TextWrapped = true
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.Parent = mainContainer

-- =============================================================================
-- LÓGICA DO PATHFINDING E VISUALIZAÇÃO
-- =============================================================================

-- Visualiza o caminho com partes de neon
local function visualizePath(waypoints)
    pathVisualsFolder:ClearAllChildren()
    if not waypoints then return end

    for _, waypoint in ipairs(waypoints) do
        local part = Instance.new("Part")
        part.Size = Vector3.new(1, 1, 1)
        part.Position = waypoint.Position
        -- Amarelo para pulo, verde para andar
        part.Color = (waypoint.Action == Enum.PathWaypointAction.Jump) and Color3.new(1, 1, 0) or Color3.new(0, 1, 0)
        part.Material = Enum.Material.Neon
        part.Anchored = true
        part.CanCollide = false
        part.Parent = pathVisualsFolder
    end
end

-- Calcula o caminho usando o serviço do Roblox
local function computePath(startVec, endVec)
    local path = PathfindingService:CreatePath(AGENT_PARAMS)
    path:ComputeAsync(startVec, endVec)

    if path.Status == Enum.PathStatus.Success then
        return path:GetWaypoints()
    else
        warn("Path not found: ", path.Status)
        return nil
    end
end

-- =============================================================================
-- LÓGICA DE MOVIMENTO (AUTOWALK COM PULOS)
-- =============================================================================

local function autowalk(waypoints)
    if not waypoints or #waypoints < 2 then
        statusLabel.Text = "Status: Invalid path"
        return
    end

    isWalking = true
    statusLabel.Text = "Status: Walking..."

    for i = 2, #waypoints do
        if not isWalking then
            statusLabel.Text = "Status: Stopped by user"
            humanoid:MoveTo(rootPart.Position) -- Cancela movimento atual
            break
        end

        local waypoint = waypoints[i]
        
        -- SISTEMA DE PULO AUTOMÁTICO CORRIGIDO
        if waypoint.Action == Enum.PathWaypointAction.Jump then
            local currentState = humanoid:GetState()
            -- Só pula se estiver no chão para evitar pulos duplos
            if currentState ~= Enum.HumanoidStateType.Jumping and currentState ~= Enum.HumanoidStateType.Freefall then
                statusLabel.Text = "Status: Jumping!"
                humanoid.Jump = true
                -- CRÍTICO: Espera o personagem realmente sair do chão antes de continuar
                humanoid.StateChanged:Wait()
            end
        end

        -- Guia o personagem para o próximo ponto (andando ou no ar)
        humanoid:MoveTo(waypoint.Position)
        
        -- Espera o personagem chegar, com um timeout para evitar travamentos
        local success = humanoid.MoveToFinished:Wait(10)

        if not success and isWalking then
            statusLabel.Text = "Status: Path blocked. Stopping."
            isWalking = false
            break
        end
    end
    
    if isWalking then
        statusLabel.Text = "Status: Arrived!"
    end
    isWalking = false
    visualizePath(nil) -- Limpa a visualização ao chegar
end

-- =============================================================================
-- CONEXÕES DOS BOTÕES E EVENTOS
-- =============================================================================

-- Lógica para Minimizar/Maximizar a UI
local isMinimized = false
local originalSize = frame.Size
minimizeButton.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    mainContainer.Visible = not isMinimized
    minimizeButton.Text = isMinimized and "+" or "-"
    frame.Size = isMinimized and UDim2.new(0, 200, 0, 30) or originalSize
end)

-- Definir Ponto de Início
setStartButton.MouseButton1Click:Connect(function()
    if not rootPart then return end
    startPos = rootPart.Position
    statusLabel.Text = "Status: Start point set."
end)

-- Habilitar modo de "clicar para definir o fim"
setEndButton.MouseButton1Click:Connect(function()
    isSettingEnd = true
    statusLabel.Text = "Status: Click anywhere on the map to set the end point."
end)

-- Iniciar o autowalk
startButton.MouseButton1Click:Connect(function()
    if isWalking or not rootPart then return end
    if not startPos or not endPos then
        statusLabel.Text = "Status: Set start and end points first!"
        return
    end

    rootPart.CFrame = CFrame.new(startPos + Vector3.new(0, 3, 0)) -- Teleporta um pouco acima para não ficar preso
    task.wait(0.5)
    
    statusLabel.Text = "Status: Computing path..."
    local waypoints = computePath(startPos, endPos)
    
    visualizePath(waypoints)
    
    autowalk(waypoints)
end)

-- Parar o autowalk
stopButton.MouseButton1Click:Connect(function()
    if isWalking then
        isWalking = false
    end
end)

-- Lógica para definir o ponto final com um clique no mundo
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if gameProcessedEvent or not isSettingEnd then return end
    
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isSettingEnd = false -- Desativa o modo após um clique
        
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        raycastParams.FilterDescendantsInstances = {character, pathVisualsFolder}
        
        local ray = workspace.CurrentCamera:ScreenPointToRay(input.Position.X, input.Position.Y)
        local result = workspace:Raycast(ray.Origin, ray.Direction * 1500, raycastParams)
        
        if result and result.Position then
            endPos = result.Position
            statusLabel.Text = "Status: End point set."
            
            -- Visualizar o ponto final com um marcador vermelho
            pathVisualsFolder:ClearAllChildren()
            local endMarker = Instance.new("Part")
            endMarker.Size = Vector3.new(3,3,3)
            endMarker.Position = endPos
            endMarker.Color = Color3.new(1,0,0)
            endMarker.Material = Enum.Material.Neon
            endMarker.Anchored = true
            endMarker.CanCollide = false
            endMarker.Parent = pathVisualsFolder
        else
            statusLabel.Text = "Status: Click failed. Try again."
        end
    end
end)

-- =============================================================================
-- GERENCIAMENTO DO PERSONAGEM (MORTE E RESPAWN)
-- =============================================================================
local function onCharacterAdded(newCharacter)
    character = newCharacter
    humanoid = newCharacter:WaitForChild("Humanoid")
    rootPart = newCharacter:WaitForChild("HumanoidRootPart")
    
    humanoid.Died:Connect(function()
        isWalking = false
        pathVisualsFolder:ClearAllChildren()
    end)
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
    onCharacterAdded(player.Character)
end

print("Advanced Pathfinder script loaded successfully.")
