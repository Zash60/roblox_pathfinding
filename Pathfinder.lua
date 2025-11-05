-- =============================================================================
-- Script de Pathfinding para Roblox com UI Móvel Avançada
-- VERSÃO CORRIGIDA: Lógica de pulo precisa, esperando o personagem se aproximar da beirada.
-- =============================================================================

-- Serviços do Roblox
local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

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

-- Configurações do Agente de Pathfinding
local AGENT_PARAMS = {
    AgentRadius = 2.5,
    AgentHeight = 6,
    AgentCanJump = true,
    WaypointSpacing = 2
}

-- Pasta para visuais do caminho
local pathVisualsFolder = workspace:FindFirstChild("PathVisuals") or Instance.new("Folder")
pathVisualsFolder.Name = "PathVisuals"
pathVisualsFolder.Parent = workspace

-- =============================================================================
-- SETUP DA INTERFACE DE USUÁRIO (UI)
-- =============================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PathfindingUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 200, 0, 250)
frame.Position = UDim2.new(0.8, -200, 0.5, -125)
frame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
frame.BorderSizePixel = 0
frame.Draggable = true
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

local function visualizePath(waypoints)
    pathVisualsFolder:ClearAllChildren()
    if not waypoints then return end
    for _, waypoint in ipairs(waypoints) do
        local part = Instance.new("Part")
        part.Size = Vector3.new(1, 1, 1)
        part.Position = waypoint.Position
        part.Color = (waypoint.Action == Enum.PathWaypointAction.Jump) and Color3.new(1, 1, 0) or Color3.new(0, 1, 0)
        part.Material = Enum.Material.Neon
        part.Anchored = true
        part.CanCollide = false
        part.Parent = pathVisualsFolder
    end
end

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
-- LÓGICA DE MOVIMENTO (AUTOWALK COM PULOS CORRIGIDO E PRECISO)
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
            humanoid:MoveTo(rootPart.Position) -- Para o movimento atual
            break
        end

        local waypoint = waypoints[i]
        
        -- Inicia o movimento para o próximo ponto
        humanoid:MoveTo(waypoint.Position)
        
        -- ===========================================================================
        --                NOVO SISTEMA DE PULO PRECISO
        -- ===========================================================================
        -- Se o waypoint atual exige um pulo, nós não pulamos imediatamente.
        -- Em vez disso, esperamos até que o personagem esteja perto o suficiente da beirada.
        if waypoint.Action == Enum.PathWaypointAction.Jump then
            statusLabel.Text = "Status: Approaching jump..."
            
            -- Espera até que a distância horizontal até o ponto de pulo seja pequena
            -- O "4" é um bom valor inicial, pode ser ajustado se necessário.
            while (rootPart.Position - waypoint.Position).Magnitude > 4 do
                if not isWalking then break end -- Permite que o botão de parar funcione durante a espera
                RunService.Heartbeat:Wait() -- Espera um único frame, mais preciso que task.wait()
            end
            
            -- Se o usuário não cancelou, força o estado de pulo agora que estamos na beirada
            if isWalking then
                statusLabel.Text = "Status: Jumping!"
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
        -- ===========================================================================

        -- Espera a conclusão do movimento (seja andar ou o pulo)
        local success = humanoid.MoveToFinished:Wait(10)

        -- Se MoveTo demorou mais de 10 segundos e ainda estávamos andando, algo bloqueou o caminho.
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
    visualizePath(nil)
end


-- =============================================================================
-- CONEXÕES DOS BOTÕES E EVENTOS
-- =============================================================================

local isMinimized = false
local originalSize = frame.Size
minimizeButton.MouseButton1Click:Connect(function()
    isMinimized = not isMinimized
    mainContainer.Visible = not isMinimized
    minimizeButton.Text = isMinimized and "+" or "-"
    frame.Size = isMinimized and UDim2.new(0, 200, 0, 30) or originalSize
end)

setStartButton.MouseButton1Click:Connect(function()
    if not rootPart then return end
    startPos = rootPart.Position
    statusLabel.Text = "Status: Start point set."
end)

setEndButton.MouseButton1Click:Connect(function()
    isSettingEnd = true
    statusLabel.Text = "Status: Click anywhere on the map to set the end point."
end)

startButton.MouseButton1Click:Connect(function()
    if isWalking or not rootPart then return end
    if not startPos or not endPos then
        statusLabel.Text = "Status: Set start and end points first!"
        return
    end
    -- Teleporta para o início para garantir consistência
    rootPart.CFrame = CFrame.new(startPos + Vector3.new(0, 3, 0))
    task.wait(0.5)
    
    statusLabel.Text = "Status: Computing path..."
    local waypoints = computePath(startPos, endPos)
    visualizePath(waypoints)
    
    if waypoints then
        autowalk(waypoints)
    else
        statusLabel.Text = "Status: Path calculation failed."
    end
end)

stopButton.MouseButton1Click:Connect(function()
    if isWalking then
        isWalking = false
    end
end)

UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if gameProcessedEvent or not isSettingEnd then return end
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        isSettingEnd = false
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        raycastParams.FilterDescendantsInstances = {character, pathVisualsFolder}
        local ray = workspace.CurrentCamera:ScreenPointToRay(input.Position.X, input.Position.Y)
        local result = workspace:Raycast(ray.Origin, ray.Direction * 1500, raycastParams)
        
        if result and result.Position then
            endPos = result.Position
            statusLabel.Text = "Status: End point set."
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

-- Função para configurar o personagem
local function onCharacterAdded(newCharacter)
    character = newCharacter
    humanoid = newCharacter:WaitForChild("Humanoid")
    rootPart = newCharacter:WaitForChild("HumanoidRootPart")
    
    -- Se o personagem morrer, pare o autowalk
    humanoid.Died:Connect(function()
        isWalking = false
        pathVisualsFolder:ClearAllChildren()
    end)
end

-- Conecta a função ao evento de personagem adicionado
player.CharacterAdded:Connect(onCharacterAdded)
-- Se o personagem já existir quando o script rodar, configura-o
if player.Character then
    onCharacterAdded(player.Character)
end

print("Advanced Pathfinder script (Precise Jump Fix) loaded successfully.")
