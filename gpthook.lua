

--[[
    GPT-Hook Main Script (Organized)
    - All logic is grouped by feature
    - UI and logic are separated
    - Section headers and comments for clarity
    - No logic changes, only organization/cleanup
]]

-------------------------------
-- 1. GLOBALS & UTILITIES
-------------------------------

local Decimals = 4
local Clock = os.clock()

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Camera = Workspace.CurrentCamera
local Terrain = Workspace:FindFirstChildOfClass("Terrain")
local UserInputService = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")

local function hasBallSocketConstraint(model)
    for _, desc in ipairs(model:GetDescendants()) do
        if desc:IsA("BallSocketConstraint") then
            return true
        end
    end
    return false
end

local function copyToClipboard(text)
    setclipboard(text)
    library:SendNotification("Link copied!", 3)
end

-------------------------------
-- 2. STATE TABLES
-------------------------------

local espSettings = {
    BoxEnabled = false,
    HighlightEnabled = false,
    BoxColor = Color3.fromRGB(168, 255, 0),
    HighlightColor = Color3.fromRGB(168, 255, 0),
    OutlineColor = Color3.fromRGB(0, 0, 0),
    BoxThickness = 2,
    BoxTransparency = 0.2,
    HighlightFillTransparency = 0.8,
    OutlineTransparency = 0.5,
    DepthMode = Enum.HighlightDepthMode.Occluded,
    MinimumDistance = 5,
    BoxStyle = "Full",
    CornerSize = 5
}

local headHighlightSettings = {
    Enabled = false,
    FillColor = Color3.fromRGB(255, 255, 0),
    OutlineColor = Color3.fromRGB(0, 0, 0),
    FillTransparency = 0.5,
    OutlineTransparency = 0.2,
    DepthMode = Enum.HighlightDepthMode.Occluded
}

local removalSettings = {
    MaleChildrenTransparent = false,
    LessShadows = false,
    RemoveClouds = false,
    RemoveLeaves = false
}

local originalObjects = {
    maleChildren = {},
    leaves = {}
}

local originalTerrainSettings = {
    shadowsEnabled = nil,
    terrainClouds = {},
    cloudsEnabled = nil
}

local originalLightingChildren = {}
local removedClouds = {}

-------------------------------
-- 3. ESP LOGIC
-------------------------------

local espRunning = false
local espBoxes = {}

local function createESPBox(model)
    local espBox = {}
    -- Drawing objects
    espBox.TopLine = Drawing.new("Line")
    espBox.LeftLine = Drawing.new("Line")
    espBox.RightLine = Drawing.new("Line")
    espBox.BottomLine = Drawing.new("Line")
    espBox.TopLeftCorner1 = Drawing.new("Line")
    espBox.TopLeftCorner2 = Drawing.new("Line")
    espBox.TopRightCorner1 = Drawing.new("Line")
    espBox.TopRightCorner2 = Drawing.new("Line")
    espBox.BottomLeftCorner1 = Drawing.new("Line")
    espBox.BottomLeftCorner2 = Drawing.new("Line")
    espBox.BottomRightCorner1 = Drawing.new("Line")
    espBox.BottomRightCorner2 = Drawing.new("Line")
    local allLines = {
        espBox.TopLine, espBox.LeftLine, espBox.RightLine, espBox.BottomLine,
        espBox.TopLeftCorner1, espBox.TopLeftCorner2, espBox.TopRightCorner1, espBox.TopRightCorner2,
        espBox.BottomLeftCorner1, espBox.BottomLeftCorner2, espBox.BottomRightCorner1, espBox.BottomRightCorner2
    }
    for _, line in pairs(allLines) do
        line.Thickness = espSettings.BoxThickness
        line.Color = espSettings.BoxColor
        line.Transparency = espSettings.BoxTransparency
        line.Visible = false
    end
    -- Highlight
    local highlight = Instance.new("Highlight")
    highlight.DepthMode = espSettings.DepthMode
    highlight.FillColor = espSettings.HighlightColor
    highlight.OutlineColor = espSettings.OutlineColor
    highlight.FillTransparency = espSettings.HighlightFillTransparency
    highlight.OutlineTransparency = espSettings.OutlineTransparency
    highlight.Adornee = model
    highlight.Parent = model
    highlight.Enabled = espSettings.HighlightEnabled
    espBox.Model = model
    espBox.Highlight = highlight
    return espBox
end

local function updateESPBox(espBox)
    local model = espBox.Model
    if not model or not model.Parent then
        local allLines = {
            espBox.TopLine, espBox.LeftLine, espBox.RightLine, espBox.BottomLine,
            espBox.TopLeftCorner1, espBox.TopLeftCorner2, espBox.TopRightCorner1, espBox.TopRightCorner2,
            espBox.BottomLeftCorner1, espBox.BottomLeftCorner2, espBox.BottomRightCorner1, espBox.BottomRightCorner2
        }
        for _, line in pairs(allLines) do line.Visible = false end
        if espBox.Highlight and espBox.Highlight.Parent then espBox.Highlight:Destroy() end
        return false
    end
    if espBox.Highlight then
        espBox.Highlight.Enabled = espSettings.HighlightEnabled
        espBox.Highlight.FillColor = espSettings.HighlightColor
        espBox.Highlight.OutlineColor = espSettings.OutlineColor
        espBox.Highlight.FillTransparency = espSettings.HighlightFillTransparency
        espBox.Highlight.OutlineTransparency = espSettings.OutlineTransparency
        espBox.Highlight.DepthMode = espSettings.DepthMode
    end
    local parts = {}
    for _, part in pairs(model:GetDescendants()) do
        if part:IsA("BasePart") then table.insert(parts, part) end
    end
    local allLines = {
        espBox.TopLine, espBox.LeftLine, espBox.RightLine, espBox.BottomLine,
        espBox.TopLeftCorner1, espBox.TopLeftCorner2, espBox.TopRightCorner1, espBox.TopRightCorner2,
        espBox.BottomLeftCorner1, espBox.BottomLeftCorner2, espBox.BottomRightCorner1, espBox.BottomRightCorner2
    }
    if #parts == 0 or not espSettings.BoxEnabled then
        for _, line in pairs(allLines) do line.Visible = false end
        return true
    end
    local primaryPart = model.PrimaryPart or parts[1]
    if primaryPart then
        local distance = (Camera.CFrame.Position - primaryPart.Position).Magnitude
        if distance < espSettings.MinimumDistance then
            for _, line in pairs(allLines) do line.Visible = false end
            return true
        end
    end
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local isOnScreen = false
    for _, part in ipairs(parts) do
        local corners = {
            part.Position + Vector3.new(-part.Size.X/2, -part.Size.Y/2, -part.Size.Z/2),
            part.Position + Vector3.new(-part.Size.X/2, -part.Size.Y/2, part.Size.Z/2),
            part.Position + Vector3.new(-part.Size.X/2, part.Size.Y/2, -part.Size.Z/2),
            part.Position + Vector3.new(-part.Size.X/2, part.Size.Y/2, part.Size.Z/2),
            part.Position + Vector3.new(part.Size.X/2, -part.Size.Y/2, -part.Size.Z/2),
            part.Position + Vector3.new(part.Size.X/2, -part.Size.Y/2, part.Size.Z/2),
            part.Position + Vector3.new(part.Size.X/2, part.Size.Y/2, -part.Size.Z/2),
            part.Position + Vector3.new(part.Size.X/2, part.Size.Y/2, part.Size.Z/2)
        }
        for _, corner in ipairs(corners) do
            local screenPoint, onScreen = Camera:WorldToViewportPoint(corner)
            if onScreen then
                isOnScreen = true
                minX = math.min(minX, screenPoint.X)
                minY = math.min(minY, screenPoint.Y)
                maxX = math.max(maxX, screenPoint.X)
                maxY = math.max(maxY, screenPoint.Y)
            end
        end
    end
    for _, line in pairs(allLines) do
        line.Visible = false
        line.Thickness = espSettings.BoxThickness
        line.Color = espSettings.BoxColor
        line.Transparency = espSettings.BoxTransparency
    end
    if isOnScreen then
        if espSettings.BoxStyle == "Full" then
            espBox.TopLine.From = Vector2.new(minX, minY)
            espBox.TopLine.To = Vector2.new(maxX, minY)
            espBox.LeftLine.From = Vector2.new(minX, minY)
            espBox.LeftLine.To = Vector2.new(minX, maxY)
            espBox.RightLine.From = Vector2.new(maxX, minY)
            espBox.RightLine.To = Vector2.new(maxX, maxY)
            espBox.BottomLine.From = Vector2.new(minX, maxY)
            espBox.BottomLine.To = Vector2.new(maxX, maxY)
            espBox.TopLine.Visible = true
            espBox.LeftLine.Visible = true
            espBox.RightLine.Visible = true
            espBox.BottomLine.Visible = true
        else
            local c = espSettings.CornerSize
            espBox.TopLeftCorner1.From = Vector2.new(minX, minY)
            espBox.TopLeftCorner1.To = Vector2.new(minX + c, minY)
            espBox.TopLeftCorner2.From = Vector2.new(minX, minY)
            espBox.TopLeftCorner2.To = Vector2.new(minX, minY + c)
            espBox.TopRightCorner1.From = Vector2.new(maxX, minY)
            espBox.TopRightCorner1.To = Vector2.new(maxX - c, minY)
            espBox.TopRightCorner2.From = Vector2.new(maxX, minY)
            espBox.TopRightCorner2.To = Vector2.new(maxX, minY + c)
            espBox.BottomLeftCorner1.From = Vector2.new(minX, maxY)
            espBox.BottomLeftCorner1.To = Vector2.new(minX + c, maxY)
            espBox.BottomLeftCorner2.From = Vector2.new(minX, maxY)
            espBox.BottomLeftCorner2.To = Vector2.new(minX, maxY - c)
            espBox.BottomRightCorner1.From = Vector2.new(maxX, maxY)
            espBox.BottomRightCorner1.To = Vector2.new(maxX - c, maxY)
            espBox.BottomRightCorner2.From = Vector2.new(maxX, maxY)
            espBox.BottomRightCorner2.To = Vector2.new(maxX, maxY - c)
            espBox.TopLeftCorner1.Visible = true
            espBox.TopLeftCorner2.Visible = true
            espBox.TopRightCorner1.Visible = true
            espBox.TopRightCorner2.Visible = true
            espBox.BottomLeftCorner1.Visible = true
            espBox.BottomLeftCorner2.Visible = true
            espBox.BottomRightCorner1.Visible = true
            espBox.BottomRightCorner2.Visible = true
        end
    end
    return true
end

local function updateESP()
    for _, object in pairs(Workspace:GetChildren()) do
        if object:IsA("Model") and object.Name == "Male" then
            if not hasBallSocketConstraint(object) then
                local found = false
                for _, espBox in pairs(espBoxes) do
                    if espBox.Model == object then found = true break end
                end
                if not found then table.insert(espBoxes, createESPBox(object)) end
            end
        end
    end
    for i = #espBoxes, 1, -1 do
        local box = espBoxes[i]
        if not box.Model or not box.Model.Parent or hasBallSocketConstraint(box.Model) then
            local allLines = {
                box.TopLine, box.LeftLine, box.RightLine, box.BottomLine,
                box.TopLeftCorner1, box.TopLeftCorner2, box.TopRightCorner1, box.TopRightCorner2,
                box.BottomLeftCorner1, box.BottomLeftCorner2, box.BottomRightCorner1, box.BottomRightCorner2
            }
            for _, line in pairs(allLines) do line:Remove() end
            if box.Highlight and box.Highlight.Parent then box.Highlight:Destroy() end
            table.remove(espBoxes, i)
        else
            updateESPBox(box)
        end
    end
end

-------------------------------
-- 4. HEAD HIGHLIGHT LOGIC
-------------------------------

local headHighlights = {}

local function updateHeadHighlights()
    -- Remove highlights for missing heads or if BallSocketConstraint is present
    for i = #headHighlights, 1, -1 do
        local info = headHighlights[i]
        local removeHighlight = false
        if not info.Head or not info.Head.Parent or not headHighlightSettings.Enabled then
            removeHighlight = true
        else
            local parentModel = info.Head.Parent
            if parentModel and parentModel:IsA("Model") and parentModel.Name == "Male" then
                if hasBallSocketConstraint(parentModel) then removeHighlight = true end
            end
        end
        if removeHighlight then
            if info.Highlight then info.Highlight:Destroy() end
            table.remove(headHighlights, i)
        end
    end
    if not headHighlightSettings.Enabled then return end
    -- Add highlights to new heads (skip if BallSocketConstraint exists)
    for _, model in ipairs(Workspace:GetChildren()) do
        if model:IsA("Model") and model.Name == "Male" and not hasBallSocketConstraint(model) then
            local head = model:FindFirstChild("Head")
            if head and head:IsA("MeshPart") then
                local already = false
                for _, info in ipairs(headHighlights) do
                    if info.Head == head then already = true break end
                end
                if not already then
                    local highlight = Instance.new("Highlight")
                    highlight.Adornee = head
                    highlight.FillColor = headHighlightSettings.FillColor
                    highlight.OutlineColor = headHighlightSettings.OutlineColor
                    highlight.FillTransparency = headHighlightSettings.FillTransparency
                    highlight.OutlineTransparency = headHighlightSettings.OutlineTransparency
                    highlight.DepthMode = headHighlightSettings.DepthMode
                    highlight.Parent = head
                    highlight.Enabled = true
                    table.insert(headHighlights, {Head = head, Highlight = highlight})
                end
            end
        end
    end
    -- Update highlight settings
    for _, info in ipairs(headHighlights) do
        if info.Highlight then
            info.Highlight.FillColor = headHighlightSettings.FillColor
            info.Highlight.OutlineColor = headHighlightSettings.OutlineColor
            info.Highlight.FillTransparency = headHighlightSettings.FillTransparency
            info.Highlight.OutlineTransparency = headHighlightSettings.OutlineTransparency
            info.Highlight.DepthMode = headHighlightSettings.DepthMode
            info.Highlight.Enabled = headHighlightSettings.Enabled
        end
    end
end

-------------------------------
-- 5. REMOVALS LOGIC
-------------------------------

local leavesChildAddedConnection = nil
local maleChildAddedConnection = nil

local function processMaleChildren(model)
    if model:IsA("Model") and model.Name == "Male" then
        if not originalObjects.maleChildren[model] then originalObjects.maleChildren[model] = {} end
        local targetModels = {"Default", "DefaultHigh", "FlatTop"}
        for _, childName in ipairs(targetModels) do
            local childModel = model:FindFirstChild(childName)
            if childModel and childModel:IsA("Model") then
                for _, part in pairs(childModel:GetDescendants()) do
                    if part:IsA("BasePart") or part:IsA("MeshPart") then
                        local already = false
                        for _, info in ipairs(originalObjects.maleChildren[model]) do
                            if info.Instance == part then already = true break end
                        end
                        if not already then
                            table.insert(originalObjects.maleChildren[model], {
                                Instance = part,
                                OriginalTransparency = part.Transparency
                            })
                            part.Transparency = 1
                        end
                    end
                end
            end
            local meshPart = model:FindFirstChild(childName)
            if meshPart and (meshPart:IsA("MeshPart") or meshPart:IsA("BasePart")) then
                local already = false
                for _, info in ipairs(originalObjects.maleChildren[model]) do
                    if info.Instance == meshPart then already = true break end
                end
                if not already then
                    table.insert(originalObjects.maleChildren[model], {
                        Instance = meshPart,
                        OriginalTransparency = meshPart.Transparency
                    })
                    meshPart.Transparency = 1
                end
            end
        end
        for _, child in pairs(model:GetChildren()) do
            if child:IsA("Model") and not table.find(targetModels, child.Name) then
                for _, part in pairs(child:GetDescendants()) do
                    if part:IsA("BasePart") or part:IsA("MeshPart") then
                        local already = false
                        for _, info in ipairs(originalObjects.maleChildren[model]) do
                            if info.Instance == part then already = true break end
                        end
                        if not already then
                            table.insert(originalObjects.maleChildren[model], {
                                Instance = part,
                                OriginalTransparency = part.Transparency
                            })
                            part.Transparency = 1
                        end
                    end
                end
            end
        end
    end
end

local function processLeavesInParent(leavesParent)
    for _, model in ipairs(leavesParent:GetChildren()) do
        if model:IsA("Model") then
            local leavesPart = model:FindFirstChild("Leaves")
            if leavesPart and leavesPart:IsA("MeshPart") then
                local already = false
                for _, info in ipairs(originalObjects.leaves) do
                    if info.Instance == leavesPart then already = true break end
                end
                if not already then
                    table.insert(originalObjects.leaves, {
                        Instance = leavesPart,
                        OriginalTransparency = leavesPart.Transparency
                    })
                    leavesPart.Transparency = 1
                end
            end
        end
    end
end

local function onNewTree(model)
    if model:IsA("Model") then
        local leavesPart = model:FindFirstChild("Leaves")
        if leavesPart and leavesPart:IsA("MeshPart") then
            local already = false
            for _, info in ipairs(originalObjects.leaves) do
                if info.Instance == leavesPart then already = true break end
            end
            if not already then
                table.insert(originalObjects.leaves, {
                    Instance = leavesPart,
                    OriginalTransparency = leavesPart.Transparency
                })
                leavesPart.Transparency = 1
            end
        end
    end
end

local function toggleMaleChildrenTransparency(state)
    removalSettings.MaleChildrenTransparent = state
    if maleChildAddedConnection then maleChildAddedConnection:Disconnect() maleChildAddedConnection = nil end
    if not state then
        for model, children in pairs(originalObjects.maleChildren) do
            if model and model:IsA("Model") then
                for _, child in pairs(children) do
                    if child.Instance and (child.Instance:IsA("BasePart") or child.Instance:IsA("MeshPart")) then
                        child.Instance.Transparency = child.OriginalTransparency
                    end
                end
            end
        end
        originalObjects.maleChildren = {}
        return
    end
    for _, object in pairs(Workspace:GetChildren()) do
        if object:IsA("Model") and object.Name == "Male" then processMaleChildren(object) end
    end
    maleChildAddedConnection = Workspace.ChildAdded:Connect(function(child)
        if removalSettings.MaleChildrenTransparent then
            if child:IsA("Model") and child.Name == "Male" then processMaleChildren(child) end
        end
    end)
end

local function toggleLeaves(state)
    removalSettings.RemoveLeaves = state
    if leavesChildAddedConnection then leavesChildAddedConnection:Disconnect() leavesChildAddedConnection = nil end
    if not state then
        for _, leafInfo in pairs(originalObjects.leaves) do
            if leafInfo.Instance and leafInfo.Instance:IsA("BasePart") then
                leafInfo.Instance.Transparency = leafInfo.OriginalTransparency
            end
        end
        originalObjects.leaves = {}
        return
    end
    originalObjects.leaves = {}
    local leavesParent = Workspace:GetChildren()[9]
    if leavesParent and (leavesParent:IsA("Folder") or leavesParent:IsA("Model")) then
        processLeavesInParent(leavesParent)
        leavesChildAddedConnection = leavesParent.ChildAdded:Connect(onNewTree)
    end
end

local function toggleLessShadows(state)
    removalSettings.LessShadows = state
    if originalTerrainSettings.shadowsEnabled == nil then
        originalTerrainSettings.shadowsEnabled = Lighting.GlobalShadows
    end
    if state then
        Lighting.GlobalShadows = false
        pcall(function() Lighting.ClockTime = 12 end)
    else
        Lighting.GlobalShadows = originalTerrainSettings.shadowsEnabled
    end
end

local function toggleClouds(state)
    removalSettings.RemoveClouds = state
    if Terrain then
        local clouds = Terrain:FindFirstChildOfClass("Clouds")
        if clouds then
            if state then
                originalTerrainSettings.cloudsEnabled = clouds.Enabled
                clouds.Enabled = false
            else
                if originalTerrainSettings.cloudsEnabled ~= nil then
                    clouds.Enabled = originalTerrainSettings.cloudsEnabled
                else
                    clouds.Enabled = true
                end
            end
        end
    end
end

local lightingRemoved = false
local function toggleAllLighting(state)
    if state then
        originalLightingChildren = {}
        for _, child in pairs(Lighting:GetChildren()) do
            if child:IsA("Sky") or child:IsA("Atmosphere") or child:IsA("BloomEffect") or 
               child:IsA("BlurEffect") or child:IsA("ColorCorrectionEffect") or
               child:IsA("DepthOfFieldEffect") or child:IsA("SunRaysEffect") then
                table.insert(originalLightingChildren, {
                    Instance = child,
                    Parent = Lighting
                })
                child.Parent = nil
            end
        end
        library:SendNotification("Removed " .. #originalLightingChildren .. " lighting effects", 3)
        lightingRemoved = true
    else
        for _, childInfo in pairs(originalLightingChildren) do
            if childInfo.Instance then childInfo.Instance.Parent = childInfo.Parent end
        end
        originalLightingChildren = {}
        library:SendNotification("Restored lighting effects", 3)
        lightingRemoved = false
    end
end

local function cleanupESP()
    if espRunning then RunService:UnbindFromRenderStep("MaleESP") espRunning = false end
    for _, espBox in pairs(espBoxes) do
        local allLines = {
            espBox.TopLine, espBox.LeftLine, espBox.RightLine, espBox.BottomLine,
            espBox.TopLeftCorner1, espBox.TopLeftCorner2, espBox.TopRightCorner1, espBox.TopRightCorner2,
            espBox.BottomLeftCorner1, espBox.BottomLeftCorner2, espBox.BottomRightCorner1, espBox.BottomRightCorner2
        }
        for _, line in pairs(allLines) do line:Remove() end
        if espBox.Highlight and espBox.Highlight.Parent then espBox.Highlight:Destroy() end
    end
    espBoxes = {}
    toggleMaleChildrenTransparency(false)
    toggleLessShadows(false)
    toggleClouds(false)
    toggleLeaves(false)
    toggleAllLighting(false)
end

-------------------------------
-- 6. AIMBOT LOGIC
-------------------------------

local aimbotEnabled = false
local aimbotSmoothing = 0.2
local aiming = false

local TargetParentModelName = "Male"
local TargetHeadPartName = "Head"

UserInputService.InputBegan:Connect(function(input, processed)
    if not processed and input.UserInputType == Enum.UserInputType.MouseButton2 then
        aiming = true
    end
end)
UserInputService.InputEnded:Connect(function(input, processed)
    if input.UserInputType == Enum.UserInputType.MouseButton2 then
        aiming = false
    end
end)

local function getClosestHead()
    local closestPart = nil
    local closestDist = math.huge
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, model in ipairs(Workspace:GetChildren()) do
        if model:IsA("Model") and model.Name == TargetParentModelName and model.Parent then
            if not hasBallSocketConstraint(model) then
                local head = model:FindFirstChild(TargetHeadPartName)
                if head and head:IsA("BasePart") then
                    local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position)
                    if onScreen then
                        local dist = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude
                        if dist < closestDist then
                            closestDist = dist
                            closestPart = head
                        end
                    end
                end
            end
        end
    end
    return closestPart
end

-------------------------------
-- 7. UI SETUP
-------------------------------

local library = loadstring(game:HttpGet("https://raw.githubusercontent.com/0pxul/GPT-hook/refs/heads/main/Tokyo%20Lib%20Source.lua"))({
    cheatname = "GPT-Hook",
    gamename = "BHRM 5",
})

library:init()

local Window = library.NewWindow({
    title = "GPT-Hook 1.4",
    size = UDim2.new(0, 510, 0.6, 6)
})

local MainTab = Window:AddTab("  Visuals  ")
local MiscTab = Window:AddTab("  Misc  ")
local AimbotTab = Window:AddTab("  Aimbot  ")
local SettingsTab = library:CreateSettingsTab(Window)

-- ESP Controls
local MainSection = MainTab:AddSection("ESP Controls", 1)
MainSection:AddToggle({
    text = "Box ESP",
    state = false,
    tooltip = "Enable/Disable 2D box ESP",
    flag = "ESP_Boxes",
    callback = function(state) espSettings.BoxEnabled = state end
})
MainSection:AddList({
    text = "Box Style",
    tooltip = "Choose box style: Full or Corner",
    values = {"Full", "Corner"},
    selected = "Full",
    flag = "Box_Style",
    callback = function(value) espSettings.BoxStyle = value end
})
MainSection:AddSlider({
    text = "Corner Size",
    flag = "Corner_Size",
    suffix = "px",
    min = 3,
    max = 20,
    increment = 1,
    value = 5,
    callback = function(value) espSettings.CornerSize = value end
})
MainSection:AddColor({
    text = "Box Color",
    color = espSettings.BoxColor,
    flag = "BoxColor",
    callback = function(color) espSettings.BoxColor = color end
})
MainSection:AddSeparator({ text = "Box Properties" })
MainSection:AddSlider({
    text = "Box Thickness",
    flag = "Box_Thickness",
    suffix = "px",
    min = 1,
    max = 20,
    increment = 1,
    value = 1,
    callback = function(value) espSettings.BoxThickness = value end
})
MainSection:AddSlider({
    text = "Box Transparency",
    flag = "Box_Transparency",
    min = 0,
    max = 1,
    increment = 0.05,
    value = 1,
    callback = function(value) espSettings.BoxTransparency = value end
})
MainSection:AddSlider({
    text = "Minimum Box Distance",
    flag = "Min_Distance",
    suffix = " studs",
    min = 0,
    max = 20,
    increment = 1,
    value = 5,
    callback = function(value) espSettings.MinimumDistance = value end
})

-- Highlight Controls
local HighlightSection = MainTab:AddSection("Highlight Controls", 2)
HighlightSection:AddToggle({
    text = "Highlight Models",
    state = false,
    tooltip = "Enable/Disable model highlighting",
    flag = "ESP_Highlights",
    callback = function(state) espSettings.HighlightEnabled = state end
})
HighlightSection:AddList({
    text = "Highlight Depth Mode",
    tooltip = "Change how highlights appear through walls",
    values = {"AlwaysOnTop", "Occluded"},
    selected = "Occluded",
    flag = "Highlight_DepthMode",
    callback = function(value)
        espSettings.DepthMode = (value == "AlwaysOnTop") and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
    end
})
HighlightSection:AddColor({
    text = "Highlight Fill Color",
    color = espSettings.HighlightColor,
    flag = "HighlightColor",
    callback = function(color) espSettings.HighlightColor = color end
})
HighlightSection:AddColor({
    text = "Highlight Outline Color",
    color = espSettings.OutlineColor,
    flag = "OutlineColor",
    callback = function(color) espSettings.OutlineColor = color end
})
HighlightSection:AddSeparator({ text = "Highlight Transparency" })
HighlightSection:AddSlider({
    text = "Fill Transparency",
    flag = "Highlight_FillTransparency",
    min = 0,
    max = 1,
    increment = 0.05,
    value = 0.8,
    callback = function(value) espSettings.HighlightFillTransparency = value end
})
HighlightSection:AddSlider({
    text = "Outline Transparency",
    flag = "Highlight_OutlineTransparency",
    min = 0,
    max = 1,
    increment = 0.05,
    value = 0.5,
    callback = function(value) espSettings.OutlineTransparency = value end
})
HighlightSection:AddToggle({
    text = "Highlight Head",
    state = false,
    tooltip = "Highlight the Head MeshPart in Male models",
    flag = "Highlight_Head",
    callback = function(state) headHighlightSettings.Enabled = state end
})
HighlightSection:AddColor({
    text = "Head Fill Color",
    color = headHighlightSettings.FillColor,
    flag = "HeadHighlight_FillColor",
    callback = function(color) headHighlightSettings.FillColor = color end
})
HighlightSection:AddColor({
    text = "Head Outline Color",
    color = headHighlightSettings.OutlineColor,
    flag = "HeadHighlight_OutlineColor",
    callback = function(color) headHighlightSettings.OutlineColor = color end
})
HighlightSection:AddSlider({
    text = "Head Fill Transparency",
    flag = "HeadHighlight_FillTransparency",
    min = 0,
    max = 1,
    increment = 0.05,
    value = headHighlightSettings.FillTransparency,
    callback = function(value) headHighlightSettings.FillTransparency = value end
})
HighlightSection:AddSlider({
    text = "Head Outline Transparency",
    flag = "HeadHighlight_OutlineTransparency",
    min = 0,
    max = 1,
    increment = 0.05,
    value = headHighlightSettings.OutlineTransparency,
    callback = function(value) headHighlightSettings.OutlineTransparency = value end
})
HighlightSection:AddList({
    text = "Head Highlight Depth Mode",
    tooltip = "Change how head highlights appear through walls",
    values = {"AlwaysOnTop", "Occluded"},
    selected = "Occluded",
    flag = "HeadHighlight_DepthMode",
    callback = function(value)
        headHighlightSettings.DepthMode = (value == "AlwaysOnTop") and Enum.HighlightDepthMode.AlwaysOnTop or Enum.HighlightDepthMode.Occluded
    end
})

-- Removals (now in Misc tab)
local RemovalsSection = MiscTab:AddSection("Removals", 1)
RemovalsSection:AddToggle({
    text = "Character Addons",
    state = false,
    tooltip = "Make Default, DefaultHigh, FlatTop and other Male models transparent",
    flag = "Transparent_MaleChildren",
    callback = function(state) toggleMaleChildrenTransparency(state) end
})
RemovalsSection:AddToggle({
    text = "Leaves",
    state = false,
    tooltip = "Find and remove leaves from trees in the environment",
    flag = "Remove_Leaves",
    callback = function(state) toggleLeaves(state) end
})
RemovalsSection:AddToggle({
    text = "Shadows",
    state = false,
    tooltip = "Reduces shadows by disabling global shadows and setting time to noon",
    flag = "Less_Shadows",
    callback = function(state) toggleLessShadows(state) end
})
RemovalsSection:AddToggle({
    text = "Clouds",
    state = false,
    tooltip = "Checks Workspace > Terrain for clouds and removes them",
    flag = "Remove_TerrainClouds",
    callback = function(state) toggleClouds(state) end
})
RemovalsSection:AddToggle({
    text = "Lighting Effects",
    state = false,
    tooltip = "Toggles all Sky, Atmosphere, Bloom, and other visual effects",
    flag = "Remove_AllLighting",
    callback = function(state) toggleAllLighting(state) end
})

-- Aimbot UI
local AimbotSection = AimbotTab:AddSection("Aimbot Controls", 1)
AimbotSection:AddToggle({
    text = "Enable Aimbot",
    state = aimbotEnabled,
    flag = "Aimbot_Enabled",
    tooltip = "Hold right mouse to lock on to nearest head",
    callback = function(state) aimbotEnabled = state end
})
AimbotSection:AddSlider({
    text = "Smoothing",
    flag = "Aimbot_Smoothing",
    min = 0.05,
    max = 1,
    increment = 0.01,
    value = aimbotSmoothing,
    tooltip = "0.05 slowest - 1 instant (aim speed)",
    callback = function(value) aimbotSmoothing = value end
})

-------------------------------
-- 8. RUNTIME HOOKS
-------------------------------

RunService:BindToRenderStep("MaleESP", Enum.RenderPriority.Camera.Value, updateESP)
espRunning = true
RunService:BindToRenderStep("HeadHighlight", Enum.RenderPriority.Camera.Value + 1, updateHeadHighlights)

RunService.RenderStepped:Connect(function()
    if aimbotEnabled and aiming and Camera then
        local target = getClosestHead()
        if target and typeof(target.Position) == "Vector3" then
            local screenPos, onScreen = Camera:WorldToViewportPoint(target.Position)
            if onScreen then
                local mousePos = UserInputService:GetMouseLocation()
                local relX = screenPos.X - mousePos.X
                local relY = screenPos.Y - mousePos.Y
                local dist = math.sqrt(relX * relX + relY * relY)
                local threshold = 3
                if dist > threshold then
                    local moveX = math.abs(relX) < threshold and relX or relX * aimbotSmoothing
                    local moveY = math.abs(relY) < threshold and relY or relY * aimbotSmoothing
                    if math.abs(moveX) > math.abs(relX) then moveX = relX end
                    if math.abs(moveY) > math.abs(relY) then moveY = relY end
                    if mousemoverel then
                        mousemoverel(moveX, moveY)
                    elseif mousemoveabs then
                        mousemoveabs(mousePos.X + moveX, mousePos.Y + moveY)
                    end
                else
                    if mousemoverel then
                        mousemoverel(relX, relY)
                    elseif mousemoveabs then
                        mousemoveabs(screenPos.X, screenPos.Y)
                    end
                end
            end
        end
    end
end)

game:GetService("Players").LocalPlayer.OnTeleport:Connect(function()
    cleanupESP()
end)

local Time = (string.format("%."..tostring(Decimals).."f", os.clock() - Clock))
library:SendNotification(("ESP Loaded In "..tostring(Time).."s"), 5)




-- ===============================
-- Debug Section in Misc Tab
-- ===============================
local DebugSection = MiscTab:AddSection("Debug", 2)

DebugSection:AddButton({
    text = "Load Dex Explorer",
    tooltip = "Loads Dex Explorer (infyiff/backup)",
    confirm = true,
    risky = true,
    callback = function()
        local success, err = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/infyiff/backup/main/dex.lua"))()
        end)
        if success then
            library:SendNotification("Dex loaded!", 3)
        else
            library:SendNotification("Failed to load Dex: " .. tostring(err), 5)
        end
    end
})

DebugSection:AddButton({
    text = "Load IY",
    tooltip = "Load Infinite yield",
    confirm = true,
    risky = true,
    callback = function()
        local success, err = pcall(function()
            loadstring(game:HttpGet('https://raw.githubusercontent.com/DarkNetworks/Infinite-Yield/main/latest.lua'))()
        end)
        if success then
            library:SendNotification("IY loaded!", 3)
        else
            library:SendNotification("Failed to load IY: " .. tostring(err), 5)
        end
    end
})




-- ===============================
-- BoxChams Feature (Visuals Tab) with Outline Option
-- ===============================

local boxChamsSettings = {
    Enabled = false,
    Color = Color3.fromRGB(255, 0, 255),
    Transparency = 0.5,
    OutlineEnabled = true,
    OutlineColor = Color3.fromRGB(0, 0, 0),
    OutlineTransparency = 0.7,
    OutlineScale = 1.15, -- How much bigger the outline box is
}

local boxChamsParts = {
    "Head",
    "LeftFoot",
    "LeftHand",
    "LeftLowerArm",
    "LeftLowerLeg",
    "LeftUpperArm",
    "LeftUpperLeg",
    "LowerTorso",
    "RightFoot",
    "RightHand",
    "RightLowerArm",
    "RightLowerLeg",
    "RightUpperArm",
    "RightUpperLeg",
    "UpperTorso"
}

local boxChamsInstances = {} -- [MeshPart] = {main=BoxHandleAdornment, outline=BoxHandleAdornment}
local boxChamsConnections = {}

local function createBoxChams(part)
    if not (part:IsA("MeshPart") or part:IsA("BasePart")) then return end
    if boxChamsInstances[part] then return end

    -- Main Box
    local box = Instance.new("BoxHandleAdornment")
    box.Adornee = part
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Size = part.Size
    box.Color3 = boxChamsSettings.Color
    box.Transparency = boxChamsSettings.Transparency
    box.Parent = part

    -- Outline Box (slightly bigger, AlwaysOnTop = false)
    local outlineBox = Instance.new("BoxHandleAdornment")
    outlineBox.Adornee = part
    outlineBox.AlwaysOnTop = false
    outlineBox.ZIndex = 9
    outlineBox.Size = part.Size * boxChamsSettings.OutlineScale
    outlineBox.Color3 = boxChamsSettings.OutlineColor
    outlineBox.Transparency = boxChamsSettings.OutlineTransparency
    outlineBox.Parent = part
    outlineBox.Visible = boxChamsSettings.OutlineEnabled

    boxChamsInstances[part] = {main = box, outline = outlineBox}
end

local function removeBoxChams(part)
    local pair = boxChamsInstances[part]
    if pair then
        if pair.main and pair.main.Parent then pair.main:Destroy() end
        if pair.outline and pair.outline.Parent then pair.outline:Destroy() end
    end
    boxChamsInstances[part] = nil
end

local function updateAllBoxChams()
    for part, pair in pairs(boxChamsInstances) do
        if pair.main and pair.main.Parent then
            pair.main.Color3 = boxChamsSettings.Color
            pair.main.Transparency = boxChamsSettings.Transparency
        end
        if pair.outline and pair.outline.Parent then
            pair.outline.Color3 = boxChamsSettings.OutlineColor
            pair.outline.Transparency = boxChamsSettings.OutlineTransparency
            pair.outline.Size = part.Size * boxChamsSettings.OutlineScale
            pair.outline.Visible = boxChamsSettings.OutlineEnabled
        end
    end
end

local function enableBoxChams()
    for _, model in ipairs(Workspace:GetChildren()) do
        if model:IsA("Model") and model.Name == "Male" then
            for _, partName in ipairs(boxChamsParts) do
                local part = model:FindFirstChild(partName)
                if part and (part:IsA("MeshPart") or part:IsA("BasePart")) then
                    createBoxChams(part)
                end
            end
        end
    end
end

local function disableBoxChams()
    for part, pair in pairs(boxChamsInstances) do
        if pair.main and pair.main.Parent then pair.main:Destroy() end
        if pair.outline and pair.outline.Parent then pair.outline:Destroy() end
    end
    boxChamsInstances = {}
end

local function disconnectBoxChamsConnections()
    for _, conn in ipairs(boxChamsConnections) do
        conn:Disconnect()
    end
    boxChamsConnections = {}
end

local function setupBoxChamsListeners()
    disconnectBoxChamsConnections()
    -- Listen for new Male models
    table.insert(boxChamsConnections, Workspace.ChildAdded:Connect(function(child)
        if not boxChamsSettings.Enabled then return end
        if child:IsA("Model") and child.Name == "Male" then
            for _, partName in ipairs(boxChamsParts) do
                local part = child:FindFirstChild(partName)
                if part and (part:IsA("MeshPart") or part:IsA("BasePart")) then
                    createBoxChams(part)
                end
            end
            -- Listen for new parts in this model
            table.insert(boxChamsConnections, child.ChildAdded:Connect(function(desc)
                if not boxChamsSettings.Enabled then return end
                for _, partName in ipairs(boxChamsParts) do
                    if desc.Name == partName and (desc:IsA("MeshPart") or desc:IsA("BasePart")) then
                        createBoxChams(desc)
                    end
                end
            end))
        end
    end))
    -- Listen for removal of parts/models
    table.insert(boxChamsConnections, Workspace.DescendantRemoving:Connect(function(desc)
        if boxChamsInstances[desc] then
            removeBoxChams(desc)
        end
    end))
end

local function toggleBoxChams(state)
    boxChamsSettings.Enabled = state
    if state then
        enableBoxChams()
        setupBoxChamsListeners()
    else
        disableBoxChams()
        disconnectBoxChamsConnections()
    end
end

-- ===============================
-- Add UI Controls to Visuals Tab
-- ===============================

local BoxChamsSection = MainTab:AddSection("BoxChams", 3)

BoxChamsSection:AddToggle({
    text = "Enable BoxChams",
    state = boxChamsSettings.Enabled,
    tooltip = "Draws colored BoxHandles on specific Male MeshParts",
    flag = "BoxChams_Enabled",
    callback = function(state)
        toggleBoxChams(state)
    end
})

BoxChamsSection:AddColor({
    text = "Chams Color",
    color = boxChamsSettings.Color,
    flag = "BoxChams_Color",
    callback = function(color)
        boxChamsSettings.Color = color
        updateAllBoxChams()
    end
})

BoxChamsSection:AddSlider({
    text = "Chams Transparency",
    flag = "BoxChams_Transparency",
    min = 0,
    max = 1,
    increment = 0.05,
    value = boxChamsSettings.Transparency,
    callback = function(value)
        boxChamsSettings.Transparency = value
        updateAllBoxChams()
    end
})

BoxChamsSection:AddToggle({
    text = "Outline Enabled",
    state = boxChamsSettings.OutlineEnabled,
    flag = "BoxChams_OutlineEnabled",
    callback = function(state)
        boxChamsSettings.OutlineEnabled = state
        updateAllBoxChams()
    end
})

BoxChamsSection:AddColor({
    text = "Outline Color",
    color = boxChamsSettings.OutlineColor,
    flag = "BoxChams_OutlineColor",
    callback = function(color)
        boxChamsSettings.OutlineColor = color
        updateAllBoxChams()
    end
})

BoxChamsSection:AddSlider({
    text = "Outline Transparency",
    flag = "BoxChams_OutlineTransparency",
    min = 0,
    max = 1,
    increment = 0.05,
    value = boxChamsSettings.OutlineTransparency,
    callback = function(value)
        boxChamsSettings.OutlineTransparency = value
        updateAllBoxChams()
    end
})

BoxChamsSection:AddSlider({
    text = "Outline Scale",
    flag = "BoxChams_OutlineScale",
    min = 1.01,
    max = 1.5,
    increment = 0.01,
    value = boxChamsSettings.OutlineScale,
    callback = function(value)
        boxChamsSettings.OutlineScale = value
        updateAllBoxChams()
    end
})

-- Optional: Clean up on script exit/reload
game:BindToClose(function()
    disableBoxChams()
    disconnectBoxChamsConnections()
end)
