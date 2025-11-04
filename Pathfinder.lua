--[[
    Script de Pathfinding A* com UI Mobile
    Criado para executores como Delta

    Funcionalidades:
    - Algoritmo A* para encontrar caminhos em uma grade.
    - UI simples e funcional para mobile.
    - Set Start: Define o ponto de partida na sua posição atual.
    - Set End: Define o ponto de chegada na sua posição atual.
    - Start Pathfinding: Teleporta para o início e anda automaticamente até o fim.
    - Visualização do caminho (pode ser desativada).
]]

-- ================= CONFIGURAÇÕES =================
local GRID_SIZE = 4 -- Tamanho de cada célula da grade em studs. Menor = mais preciso, porém mais lento. 4 é um bom equilíbrio.
local VISUALIZE_PATH = true -- Mude para 'false' para não desenhar o caminho com blocos.
local CHARACTER_HEIGHT_OFFSET = 3 -- Quão alto acima do chão o caminho deve ser calculado.
local JUMP_DETECTION_HEIGHT = 5 -- Se um obstáculo for menor que essa altura, o script considerará que é possível pular sobre ele.

-- ================= VARIÁVEIS GLOBAIS =================
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local localPlayer = Players.LocalPlayer
local character = localPlayer.Character or localPlayer.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

local startPosition = nil
local endPosition = nil
local isPathfinding = false
local visualizationFolder = nil

-- ================= ALGORITMO A* (A-STAR) =================
-- Esta é a lógica principal do pathfinding.

local A_Star = {}

function A_Star:FindPath(startWorldPos, endWorldPos)
    local function GetNodeFromPos(pos)
        return Vector2.new(math.floor(pos.X / GRID_SIZE), math.floor(pos.Z / GRID_SIZE))
    end

    local function GetWorldPosFromNode(node)
        return Vector3.new(node.X * GRID_SIZE, startWorldPos.Y + CHARACTER_HEIGHT_OFFSET, node.Y * GRID_SIZE)
    end

    -- Função para verificar se um nó é "andável"
    local function IsWalkable(node)
        local worldPos = GetWorldPosFromNode(node)
        
        -- Raycast para baixo para encontrar o chão
        local rayOrigin = worldPos + Vector3.new(0, 50, 0)
        local rayDir = Vector3.new(0, -100, 0)
        local raycastParams = RaycastParams.new()
        raycastParams.FilterType = Enum.RaycastFilterType.Blacklist
        raycastParams.FilterDescendantsInstances = {character}
        
        local rayResult = Workspace:Raycast(rayOrigin, rayDir, raycastParams)

        if not rayResult or not rayResult.Instance.CanCollide then
            return false -- Não há chão abaixo
        end
        
        local groundPos = rayResult.Position
        
        -- Verificar se há obstáculos na altura do personagem
        local partSize = Vector3.new(GRID_SIZE, JUMP_DETECTION_HEIGHT, GRID_SIZE)
        local partCFrame = CFrame.new(Vector3.new(worldPos.X, groundPos.Y + partSize.Y / 2, worldPos.Z))
        
        local overlapParams = OverlapParams.new()
        overlapParams.FilterType = Enum.RaycastFilterType.Blacklist
        overlapParams.FilterDescendantsInstances = {character}

        local partsInRegion = Workspace:GetPartsInPart(Instance.new("Part", nil), overlapParams)
        partsInRegion.Size = partSize
        partsInRegion.CFrame = partCFrame
        
        local obstacles = Workspace:GetPartsInPart(partsInRegion, overlapParams)
        partsInRegion:Destroy()
        
        return #obstacles == 0
    end

    local startNodePos = GetNodeFromPos(startWorldPos)
    local endNodePos = GetNodeFromPos(endWorldPos)

    local openSet = {}
    local closedSet = {}
    
    local nodes = {}
    
    local function GetNode(pos)
        local key = tostring(pos)
        if not nodes[key] then
            nodes[key] = {
                pos = pos,
                gCost = math.huge,
                hCost = math.huge,
                fCost = math.huge,
                parent = nil,
                walkable = IsWalkable(pos)
            }
        end
        return nodes[key]
    end

    local startNode = GetNode(startNodePos)
    startNode.gCost = 0
    startNode.hCost = (startNodePos - endNodePos).Magnitude
    startNode.fCost = startNode.hCost
    
    table.insert(openSet, startNode)

    while #openSet > 0 do
        -- Encontrar o nó com o menor fCost no openSet
        local currentNode = openSet[1]
        local currentIndex = 1
        for i, node in ipairs(openSet) do
            if node.fCost < currentNode.fCost or (node.fCost == currentNode.fCost and node.hCost < currentNode.hCost) then
                currentNode = node
                currentIndex = i
            end
        end

        table.remove(openSet, currentIndex)
        closedSet[tostring(currentNode.pos)] = true

        if currentNode.pos == endNodePos then
            -- Caminho encontrado, reconstruir
            local path = {}
            local temp = currentNode
            while temp do
                table.insert(path, 1, GetWorldPosFromNode(temp.pos))
                temp = temp.parent
            end
            return path
        end

        -- Verificar vizinhos
        for x = -1, 1 do
            for y = -1, 1 do
                if x == 0 and y == 0 then continue end

                local neighborPos = currentNode.pos + Vector2.new(x, y)
                if not closedSet[tostring(neighborPos)] then
                    local neighborNode = GetNode(neighborPos)

                    if not neighborNode.walkable then
                        closedSet[tostring(neighborPos)] = true
                        continue
                    end

                    local moveCost = currentNode.gCost + (Vector2.new(x, y)).Magnitude
                    if moveCost < neighborNode.gCost then
                        neighborNode.gCost = moveCost
                        neighborNode.hCost = (neighborPos - endNodePos).Magnitude
                        neighborNode.fCost = neighborNode.gCost + neighborNode.hCost
                        neighborNode.parent = currentNode

                        local inOpenSet = false
                        for _, openNode in ipairs(openSet) do
                            if openNode.pos == neighborPos then
                                inOpenSet = true
                                break
                            end
                        end
                        if not inOpenSet then
                            table.insert(openSet, neighborNode)
                        end
                    end
                end
            end
        end
    end

    return nil -- Nenhum caminho encontrado
end

-- ================= UI (INTERFACE DE USUÁRIO) =================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PathfinderUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = game:GetService("CoreGui") or localPlayer:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0.3, 0, 0.25, 0)
mainFrame.Position = UDim2.new(0.02, 0, 0.5, 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BackgroundTransparency = 0.3
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, 0, 0.2, 0)
titleLabel.Text = "A* Pathfinding"
titleLabel.TextColor3 = Color3.new(1, 1, 1)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.SourceSansBold
titleLabel.TextSize = 18
titleLabel.Parent = mainFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(0.9, 0, 0.15, 0)
statusLabel.Position = UDim2.new(0.05, 0, 0.2, 0)
statusLabel.Text = "Status: Idle"
statusLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.SourceSans
statusLabel.TextSize = 14
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Parent = mainFrame

local function createButton(text, position, callback)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0.9, 0, 0.18, 0)
    button.Position = position
    button.Text = text
    button.BackgroundColor3 = Color3.fromRGB(80, 80, 150)
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Font = Enum.Font.SourceSansBold
    button.TextSize = 16
    button.Parent = mainFrame
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = button
    
    button.MouseButton1Click:Connect(callback)
    return button
end

local setStartButton = createButton("Set Start", UDim2.new(0.05, 0, 0.35, 0), function()
    startPosition = rootPart.Position
    statusLabel.Text = "Start definido! Defina o fim."
    statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
end)

local setEndButton = createButton("Set End", UDim2.new(0.05, 0, 0.55, 0), function()
    endPosition = rootPart.Position
    statusLabel.Text = "End definido! Pronto para iniciar."
    statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
end)

local startButton = createButton("Start Pathfinding", UDim2.new(0.05, 0, 0.75, 0), function()
    if isPathfinding then return end
    if not startPosition or not endPosition then
        statusLabel.Text = "Defina Start e End primeiro!"
        statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        return
    end

    isPathfinding = true
    startButton.Text = "Calculando..."
    startButton.BackgroundColor3 = Color3.fromRGB(150, 80, 80)
    
    -- Inicia o pathfinding em uma nova thread para não congelar o jogo
    task.spawn(function()
        -- 1. Teleportar para o início
        rootPart.CFrame = CFrame.new(startPosition)
        task.wait(0.2)
        
        -- 2. Calcular o caminho
        statusLabel.Text = "Calculando caminho A*..."
        local path = A_Star:FindPath(startPosition, endPosition)

        -- 3. Limpar visualização antiga
        if visualizationFolder then
            visualizationFolder:Destroy()
        end
        visualizationFolder = Instance.new("Folder", Workspace)
        visualizationFolder.Name = "PathVisualization"

        if path then
            statusLabel.Text = "Caminho encontrado! Andando..."
            statusLabel.TextColor3 = Color3.fromRGB(100, 200, 255)
            
            -- 4. Visualizar e andar
            for i, waypoint in ipairs(path) do
                if not isPathfinding then break end -- Permite cancelar

                if VISUALIZE_PATH then
                    local part = Instance.new("Part")
                    part.Size = Vector3.new(1, 1, 1)
                    part.Position = waypoint
                    part.Anchored = true
                    part.CanCollide = false
                    part.BrickColor = BrickColor.new("Lime green")
                    part.Material = Enum.Material.Neon
                    part.Transparency = 0.5
                    part.Parent = visualizationFolder
                end

                humanoid:MoveTo(waypoint)
                humanoid.MoveToFinished:Wait()
            end
            
            if isPathfinding then
                statusLabel.Text = "Chegou ao destino!"
                statusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
            end
        else
            statusLabel.Text = "Nenhum caminho encontrado!"
            statusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        end
        
        isPathfinding = false
        startButton.Text = "Start Pathfinding"
        startButton.BackgroundColor3 = Color3.fromRGB(80, 80, 150)
    end)
end)

-- Adicionar um botão de parada (opcional mas útil)
mainFrame.Draggable = true
local stopButton = Instance.new("TextButton")
stopButton.Size = UDim2.new(0.15, 0, 0.15, 0)
stopButton.Position = UDim2.new(0.8, 0, 0.02, 0)
stopButton.Text = "X"
stopButton.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
stopButton.TextColor3 = Color3.new(1, 1, 1)
stopButton.Font = Enum.Font.SourceSansBold
stopButton.Parent = mainFrame
stopButton.MouseButton1Click:Connect(function()
    isPathfinding = false
    humanoid:MoveTo(rootPart.Position) -- Para a caminhada atual
    screenGui:Destroy()
    if visualizationFolder then
        visualizationFolder:Destroy()
    end
end)
