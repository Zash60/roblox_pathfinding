--[[
    Script de Pathfinder Customizado com Algoritmo A*
    Criado para executores como o Delta, com UI mobile-friendly.

    Funcionalidades:
    - Não utiliza o PathfindingService do Roblox.
    - UI para definir ponto de início e fim.
    - Visualização do caminho encontrado.
    - Detecção de obstáculos simples.
]]

-- SERVICES
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

-- CONFIGURAÇÕES
local GRID_SIZE = 4 -- Tamanho de cada "célula" do grid. Menor = mais preciso, porém mais lento.
local MAX_ITERATIONS = 2000 -- Previne que o script trave em caminhos muito longos ou impossíveis.
local VISUALIZATION_COLOR = Color3.fromRGB(0, 255, 127) -- Cor do caminho (verde neon)

-- VARIÁVEIS DE ESTADO
local player = Players.LocalPlayer
local mouse = player:GetMouse()
local isSettingStart = false
local isSettingEnd = false
local startPos, endPos
local pathVisualizationFolder = Instance.new("Folder", workspace)
pathVisualizationFolder.Name = "PathVisualization_A_Star"

--==============================================================================
-- CRIAÇÃO DA INTERFACE (UI)
--==============================================================================
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PathfinderUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0.3, 0, 0.2, 0)
mainFrame.Position = UDim2.new(0.5, 0, 0.95, 0)
mainFrame.AnchorPoint = Vector2.new(0.5, 1)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
mainFrame.BackgroundTransparency = 0.3
mainFrame.BorderSizePixel = 0
mainFrame.Parent = screenGui

local corner = Instance.new("UICorner", mainFrame)
corner.CornerRadius = UDim.new(0, 8)

local layout = Instance.new("UIListLayout", mainFrame)
layout.FillDirection = Enum.FillDirection.Horizontal
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 10)

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, -10, 0.3, 0)
statusLabel.Position = UDim2.new(0.5, 0, 0, 0)
statusLabel.AnchorPoint = Vector2.new(0.5, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Pronto para calcular a rota"
statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
statusLabel.Font = Enum.Font.SourceSansBold
statusLabel.TextSize = 16
statusLabel.LayoutOrder = 0
statusLabel.Parent = mainFrame

-- Botões
local function createButton(text, order)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(0.4, 0, 0.5, 0)
    button.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.SourceSansBold
    button.TextSize = 18
    button.Text = text
    button.LayoutOrder = order
    button.Parent = mainFrame
    
    local cornerBtn = Instance.new("UICorner", button)
    cornerBtn.CornerRadius = UDim.new(0, 6)
    
    return button
end

local setStartButton = createButton("Definir Início", 1)
local setEndButton = createButton("Definir Fim", 2)

-- Limpar Visualização
local function clearVisualization()
    pathVisualizationFolder:ClearAllChildren()
end

--==============================================================================
-- ALGORITMO A* (A-STAR)
--==============================================================================

-- Função para "alinhar" uma posição ao nosso grid virtual
local function snapToGrid(pos)
    local x = math.floor(pos.X / GRID_SIZE) * GRID_SIZE + GRID_SIZE / 2
    local y = math.floor(pos.Y / GRID_SIZE) * GRID_SIZE + GRID_SIZE / 2
    local z = math.floor(pos.Z / GRID_SIZE) * GRID_SIZE + GRID_SIZE / 2
    return Vector3.new(x, y, z)
end

-- Heurística: Distância de Manhattan (mais rápida que a Euclidiana)
local function heuristic(posA, posB)
    return math.abs(posA.X - posB.X) + math.abs(posA.Y - posB.Y) + math.abs(posA.Z - posB.Z)
end

-- Verifica se uma posição no grid é "caminhável"
local function isWalkable(position)
    local regionPart = Instance.new("Part")
    regionPart.CanCollide = false
    regionPart.CanQuery = true -- Importante para OverlapParams
    regionPart.Transparency = 1
    regionPart.Anchored = true
    regionPart.Size = Vector3.new(GRID_SIZE, GRID_SIZE, GRID_SIZE)
    regionPart.Position = position
    
    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Blacklist
    overlapParams.FilterDescendantsInstances = {player.Character, pathVisualizationFolder, regionPart}
    
    local partsInRegion = workspace:GetPartsInPart(regionPart, overlapParams)
    regionPart:Destroy()

    for _, part in ipairs(partsInRegion) do
        if part.CanCollide then
            return false -- Encontrou um obstáculo
        end
    end
    return true
end

-- Encontra o caminho usando A*
function findPath(startWorld, endWorld)
    clearVisualization()
    statusLabel.Text = "Calculando rota..."
    
    local startNode = snapToGrid(startWorld)
    local endNode = snapToGrid(endWorld)

    local openSet = {startNode}
    local cameFrom = {}

    -- gScore: custo do início até o nó atual
    local gScore = {[startNode] = 0}
    -- fScore: custo total estimado (gScore + heurística)
    local fScore = {[startNode] = heuristic(startNode, endNode)}
    
    local iterations = 0

    while #openSet > 0 and iterations < MAX_ITERATIONS do
        iterations = iterations + 1

        -- Encontra o nó no openSet com o menor fScore
        local current
        local lowestFScore = math.huge
        for _, node in ipairs(openSet) do
            if fScore[node] < lowestFScore then
                lowestFScore = fScore[node]
                current = node
            end
        end

        -- Se chegamos ao fim, reconstrua o caminho
        if current == endNode then
            statusLabel.Text = "Rota encontrada!"
            local path = {}
            local temp = current
            while temp do
                table.insert(path, 1, temp)
                temp = cameFrom[temp]
            end
            return path
        end
        
        -- Remove o nó atual do openSet
        for i, node in ipairs(openSet) do
            if node == current then
                table.remove(openSet, i)
                break
            end
        end

        -- Explora os vizinhos
        for dx = -1, 1 do
            for dy = -1, 1 do
                for dz = -1, 1 do
                    if dx == 0 and dy == 0 and dz == 0 then continue end
                    
                    local neighbor = current + Vector3.new(dx * GRID_SIZE, dy * GRID_SIZE, dz * GRID_SIZE)
                    
                    if isWalkable(neighbor) then
                        local tentativeGScore = gScore[current] + (current - neighbor).Magnitude
                        
                        if not gScore[neighbor] or tentativeGScore < gScore[neighbor] then
                            cameFrom[neighbor] = current
                            gScore[neighbor] = tentativeGScore
                            fScore[neighbor] = gScore[neighbor] + heuristic(neighbor, endNode)
                            
                            -- Adiciona o vizinho ao openSet se não estiver lá
                            local inOpenSet = false
                            for _, node in ipairs(openSet) do
                                if node == neighbor then
                                    inOpenSet = true
                                    break
                                end
                            end
                            if not inOpenSet then
                                table.insert(openSet, neighbor)
                            end
                        end
                    end
                end
            end
        end
        task.wait() -- Pequena pausa para não travar o jogo em cálculos grandes
    end

    statusLabel.Text = "Não foi possível encontrar uma rota."
    return nil -- Caminho não encontrado
end

-- Função para desenhar o caminho
function visualizePath(path)
    if not path then return end
    
    for i, position in ipairs(path) do
        local part = Instance.new("Part")
        part.Size = Vector3.new(GRID_SIZE * 0.5, GRID_SIZE * 0.5, GRID_SIZE * 0.5)
        part.Position = position
        part.Anchored = true
        part.CanCollide = false
        part.Material = Enum.Material.Neon
        part.Color = VISUALIZATION_COLOR
        part.Parent = pathVisualizationFolder
        
        -- Muda a cor do início e do fim
        if i == 1 then
            part.Color = Color3.fromRGB(0, 255, 0) -- Verde para início
        elseif i == #path then
            part.Color = Color3.fromRGB(255, 0, 0) -- Vermelho para fim
        end
    end
end


--==============================================================================
-- LÓGICA DE INTERAÇÃO
--==============================================================================

-- Botão de Definir Início
setStartButton.MouseButton1Click:Connect(function()
    isSettingStart = true
    isSettingEnd = false
    statusLabel.Text = "Clique no mapa para definir o INÍCIO"
end)

-- Botão de Definir Fim
setEndButton.MouseButton1Click:Connect(function()
    isSettingEnd = true
    isSettingStart = false
    statusLabel.Text = "Clique no mapa para definir o FIM"
end)

-- Detecta o clique/toque no mundo
UserInputService.InputBegan:Connect(function(input, gameProcessedEvent)
    if gameProcessedEvent then return end -- Ignora cliques na UI

    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        local target = mouse.Target
        if not target then return end

        local clickPosition = mouse.Hit.p
        
        if isSettingStart then
            startPos = clickPosition
            isSettingStart = false
            statusLabel.Text = "Início definido! Agora defina o fim."
        elseif isSettingEnd then
            endPos = clickPosition
            isSettingEnd = false
            statusLabel.Text = "Fim definido!"
        end
        
        -- Se ambos foram definidos, calcula o caminho
        if startPos and endPos then
            -- Usar task.spawn para não congelar o jogo durante o cálculo
            task.spawn(function()
                local path = findPath(startPos, endPos)
                if path then
                    visualizePath(path)
                end
                -- Reseta para o próximo cálculo
                startPos, endPos = nil, nil
            end)
        end
    end
end)

-- Limpeza ao sair
game:BindToClose(function()
    screenGui:Destroy()
    pathVisualizationFolder:Destroy()
end)

statusLabel.Text = "Pathfinder customizado carregado."
