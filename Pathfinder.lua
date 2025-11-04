-- Roblox Lua Script for A* Pathfinding with Mobile UI
-- This script assumes it's running in a Roblox environment (e.g., via Delta executor on mobile).
-- It creates a simple UI for setting start and end positions, and autowalks using A* pathfinding.
-- Note: This is a basic implementation. A* is grid-based for simplicity (assuming a flat world).
-- Grid size and resolution can be adjusted.

local Players = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local rootPart = character:WaitForChild("HumanoidRootPart")

-- UI Setup (Mobile-friendly with large buttons)
local screenGui = Instance.new("ScreenGui")
screenGui.Parent = player:WaitForChild("PlayerGui")
screenGui.Name = "PathfindingUI"

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0.3, 0, 0.4, 0)
frame.Position = UDim2.new(0.7, 0, 0.6, 0)
frame.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
frame.Parent = screenGui

local setStartButton = Instance.new("TextButton")
setStartButton.Size = UDim2.new(1, 0, 0.2, 0)
setStartButton.Position = UDim2.new(0, 0, 0, 0)
setStartButton.Text = "Set Start"
setStartButton.Parent = frame

local setEndButton = Instance.new("TextButton")
setEndButton.Size = UDim2.new(1, 0, 0.2, 0)
setEndButton.Position = UDim2.new(0, 0, 0.2, 0)
setEndButton.Text = "Set End"
setEndButton.Parent = frame

local startButton = Instance.new("TextButton")
startButton.Size = UDim2.new(1, 0, 0.2, 0)
startButton.Position = UDim2.new(0, 0, 0.4, 0)
startButton.Text = "Start Autowalk"
startButton.Parent = frame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0.4, 0)
statusLabel.Position = UDim2.new(0, 0, 0.6, 0)
statusLabel.Text = "Status: Ready"
statusLabel.Parent = frame

-- Variables for start and end positions
local startPos = nil
local endPos = nil

-- Simple A* Implementation
-- Grid resolution (studs per cell)
local GRID_SIZE = 4

-- Node class for A*
local Node = {}
Node.__index = Node

function Node.new(position, parent)
    local self = setmetatable({}, Node)
    self.position = position
    self.parent = parent
    self.g = 0  -- Cost from start
    self.h = 0  -- Heuristic to end
    self.f = 0  -- Total cost
    return self
end

-- Get grid key for position
local function getGridKey(pos)
    local x = math.floor(pos.X / GRID_SIZE)
    local y = math.floor(pos.Y / GRID_SIZE)
    local z = math.floor(pos.Z / GRID_SIZE)
    return x .. "," .. y .. "," .. z
end

-- Heuristic (Manhattan distance)
local function heuristic(a, b)
    return math.abs(a.X - b.X) + math.abs(a.Y - b.Y) + math.abs(a.Z - b.Z)
end

-- Get neighbors (assuming 6 directions: forward, back, left, right, up, down)
local function getNeighbors(currentPos)
    local directions = {
        Vector3.new(GRID_SIZE, 0, 0),
        Vector3.new(-GRID_SIZE, 0, 0),
        Vector3.new(0, GRID_SIZE, 0),
        Vector3.new(0, -GRID_SIZE, 0),
        Vector3.new(0, 0, GRID_SIZE),
        Vector3.new(0, 0, -GRID_SIZE)
    }
    local neighbors = {}
    for _, dir in ipairs(directions) do
        local neighborPos = currentPos + dir
        -- Check if walkable (using Raycast to detect obstacles)
        local ray = Ray.new(currentPos, dir)
        local hit = workspace:FindPartOnRayWithIgnoreList(ray, {character})
        if not hit then
            table.insert(neighbors, neighborPos)
        end
    end
    return neighbors
end

-- A* Algorithm
local function aStar(start, goal)
    local openSet = {}
    local closedSet = {}
    local startNode = Node.new(start, nil)
    startNode.g = 0
    startNode.h = heuristic(start, goal)
    startNode.f = startNode.g + startNode.h
    table.insert(openSet, startNode)

    while #openSet > 0 do
        -- Find lowest f node
        table.sort(openSet, function(a, b) return a.f < b.f end)
        local current = table.remove(openSet, 1)
        local currentKey = getGridKey(current.position)

        if (current.position - goal).Magnitude < GRID_SIZE then
            -- Reconstruct path
            local path = {}
            while current do
                table.insert(path, 1, current.position)
                current = current.parent
            end
            return path
        end

        closedSet[currentKey] = true

        for _, neighborPos in ipairs(getNeighbors(current.position)) do
            local neighborKey = getGridKey(neighborPos)
            if not closedSet[neighborKey] then
                local tentativeG = current.g + (current.position - neighborPos).Magnitude
                local neighborNode = Node.new(neighborPos, current)
                neighborNode.g = tentativeG
                neighborNode.h = heuristic(neighborPos, goal)
                neighborNode.f = neighborNode.g + neighborNode.h

                -- Check if already in openSet with higher g
                local inOpen = false
                for i, node in ipairs(openSet) do
                    if getGridKey(node.position) == neighborKey then
                        if tentativeG < node.g then
                            openSet[i] = neighborNode
                        end
                        inOpen = true
                        break
                    end
                end
                if not inOpen then
                    table.insert(openSet, neighborNode)
                end
            end
        end
    end
    return nil  -- No path found
end

-- Autowalk function
local function autowalk(path)
    if not path then
        statusLabel.Text = "Status: No path found"
        return
    end
    statusLabel.Text = "Status: Walking..."
    for i = 2, #path do  -- Start from 2 since 1 is current pos
        humanoid:MoveTo(path[i])
        humanoid.MoveToFinished:Wait()
    end
    statusLabel.Text = "Status: Arrived"
end

-- Button Connections
setStartButton.MouseButton1Click:Connect(function()
    startPos = rootPart.Position
    statusLabel.Text = "Status: Start set at " .. tostring(startPos)
end)

setEndButton.MouseButton1Click:Connect(function()
    endPos = rootPart.Position
    statusLabel.Text = "Status: End set at " .. tostring(endPos)
end)

startButton.MouseButton1Click:Connect(function()
    if not startPos or not endPos then
        statusLabel.Text = "Status: Set start and end first"
        return
    end
    -- Teleport to start
    rootPart.CFrame = CFrame.new(startPos)
    wait(0.5)  -- Brief wait for teleport to settle
    
    -- Compute path with A*
    statusLabel.Text = "Status: Computing path..."
    local path = aStar(startPos, endPos)
    
    -- Autowalk
    autowalk(path)
end)

-- Note: This is a simplified A* for demonstration. In a real game, consider using Roblox's PathfindingService for better performance.
-- Adjust GRID_SIZE for accuracy vs performance. This assumes no obstacles above/below; extend for full 3D if needed.
