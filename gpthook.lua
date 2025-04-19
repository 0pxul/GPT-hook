local Decimals = 4
local Clock = os.clock()

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local Camera = Workspace.CurrentCamera
local Terrain = Workspace:FindFirstChildOfClass("Terrain")

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

-- Add settings for removals
local removalSettings = {
    MaleChildrenTransparent = false,
    LessShadows = false,
    RemoveClouds = false,
    RemoveLeaves = false
}

-- Store original state references
local originalObjects = {
    maleChildren = {},
    leaves = {}
}

-- Store original terrain states
local originalTerrainSettings = {
    shadowsEnabled = nil,
    terrainClouds = {}
}

-- Store original lighting children
local originalLightingChildren = {}

-- Keep track of removed cloud instances
local removedClouds = {}

local espRunning = false
local espBoxes = {}

local function createESPBox(model)
    local espBox = {}
    
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
        
        for _, line in pairs(allLines) do
            line.Visible = false
        end
        
        if espBox.Highlight and espBox.Highlight.Parent then
            espBox.Highlight:Destroy()
        end
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
        if part:IsA("BasePart") then
            table.insert(parts, part)
        end
    end
    
    local allLines = {
        espBox.TopLine, espBox.LeftLine, espBox.RightLine, espBox.BottomLine,
        espBox.TopLeftCorner1, espBox.TopLeftCorner2, espBox.TopRightCorner1, espBox.TopRightCorner2,
        espBox.BottomLeftCorner1, espBox.BottomLeftCorner2, espBox.BottomRightCorner1, espBox.BottomRightCorner2
    }
    
    if #parts == 0 or not espSettings.BoxEnabled then
        for _, line in pairs(allLines) do
            line.Visible = false
        end
        return true
    end
    
    local primaryPart = model.PrimaryPart or parts[1]
    if primaryPart then
        local distance = (Camera.CFrame.Position - primaryPart.Position).Magnitude
        
        if distance < espSettings.MinimumDistance then
            for _, line in pairs(allLines) do
                line.Visible = false
            end
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
            local cornerSize = espSettings.CornerSize
            
            espBox.TopLeftCorner1.From = Vector2.new(minX, minY)
            espBox.TopLeftCorner1.To = Vector2.new(minX + cornerSize, minY)
            espBox.TopLeftCorner2.From = Vector2.new(minX, minY)
            espBox.TopLeftCorner2.To = Vector2.new(minX, minY + cornerSize)
            
            espBox.TopRightCorner1.From = Vector2.new(maxX, minY)
            espBox.TopRightCorner1.To = Vector2.new(maxX - cornerSize, minY)
            espBox.TopRightCorner2.From = Vector2.new(maxX, minY)
            espBox.TopRightCorner2.To = Vector2.new(maxX, minY + cornerSize)
            
            espBox.BottomLeftCorner1.From = Vector2.new(minX, maxY)
            espBox.BottomLeftCorner1.To = Vector2.new(minX + cornerSize, maxY)
            espBox.BottomLeftCorner2.From = Vector2.new(minX, maxY)
            espBox.BottomLeftCorner2.To = Vector2.new(minX, maxY - cornerSize)
            
            espBox.BottomRightCorner1.From = Vector2.new(maxX, maxY)
            espBox.BottomRightCorner1.To = Vector2.new(maxX - cornerSize, maxY)
            espBox.BottomRightCorner2.From = Vector2.new(maxX, maxY)
            espBox.BottomRightCorner2.To = Vector2.new(maxX, maxY - cornerSize)
            
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
            local found = false
            for _, espBox in pairs(espBoxes) do
                if espBox.Model == object then
                    found = true
                    break
                end
            end
            
            if not found then
                table.insert(espBoxes, createESPBox(object))
            end
        end
    end
    
    for i = #espBoxes, 1, -1 do
        local isValid = updateESPBox(espBoxes[i])
        if not isValid then
            local allLines = {
                espBoxes[i].TopLine, espBoxes[i].LeftLine, espBoxes[i].RightLine, espBoxes[i].BottomLine,
                espBoxes[i].TopLeftCorner1, espBoxes[i].TopLeftCorner2, espBoxes[i].TopRightCorner1, espBoxes[i].TopRightCorner2,
                espBoxes[i].BottomLeftCorner1, espBoxes[i].BottomLeftCorner2, espBoxes[i].BottomRightCorner1, espBoxes[i].BottomRightCorner2
            }
            
            for _, line in pairs(allLines) do
                line:Remove()
            end
            
            table.remove(espBoxes, i)
        end
    end
end

-- Functions for removals
local function toggleMaleChildrenTransparency(state)
    removalSettings.MaleChildrenTransparent = state

    -- Reset transparency if turning off
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

    -- Make children transparent if turning on
    for _, object in pairs(Workspace:GetChildren()) do
        if object:IsA("Model") and object.Name == "Male" then
            originalObjects.maleChildren[object] = {}

            -- Target specific models in Male: Default, DefaultHigh, and FlatTop
            local targetModels = {"Default", "DefaultHigh", "FlatTop"}

            for _, childName in ipairs(targetModels) do
                -- Check for Model child
                local childModel = object:FindFirstChild(childName)
                if childModel and childModel:IsA("Model") then
                    for _, part in pairs(childModel:GetDescendants()) do
                        if part:IsA("BasePart") or part:IsA("MeshPart") then
                            table.insert(originalObjects.maleChildren[object], {
                                Instance = part,
                                OriginalTransparency = part.Transparency
                            })
                            part.Transparency = 1
                        end
                    end
                end
                -- Check for MeshPart or BasePart directly under Male
                local meshPart = object:FindFirstChild(childName)
                if meshPart and (meshPart:IsA("MeshPart") or meshPart:IsA("BasePart")) then
                    table.insert(originalObjects.maleChildren[object], {
                        Instance = meshPart,
                        OriginalTransparency = meshPart.Transparency
                    })
                    meshPart.Transparency = 1
                end
            end

            -- Also check other child models
            for _, child in pairs(object:GetChildren()) do
                if child:IsA("Model") and not table.find(targetModels, child.Name) then
                    for _, part in pairs(child:GetDescendants()) do
                        if part:IsA("BasePart") or part:IsA("MeshPart") then
                            table.insert(originalObjects.maleChildren[object], {
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


local function toggleLeaves(state)
    removalSettings.RemoveLeaves = state

    -- Reset transparency if turning off
    if not state then
        for _, leafInfo in pairs(originalObjects.leaves) do
            if leafInfo.Instance and leafInfo.Instance:IsA("BasePart") then
                leafInfo.Instance.Transparency = leafInfo.OriginalTransparency
            end
        end
        originalObjects.leaves = {}
        return
    end

    -- Only process MeshParts named "Leaves" inside models in workspace:GetChildren()[9]
    originalObjects.leaves = {}

    local leavesParent = Workspace:GetChildren()[9]
    if leavesParent and (leavesParent:IsA("Folder") or leavesParent:IsA("Model")) then
        for _, model in ipairs(leavesParent:GetChildren()) do
            if model:IsA("Model") then
                local leavesPart = model:FindFirstChild("Leaves")
                if leavesPart and leavesPart:IsA("MeshPart") then
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



local function toggleLessShadows(state)
    removalSettings.LessShadows = state
    
    -- Handle shadows via lighting service
    local Lighting = game:GetService("Lighting")
    
    -- Store original shadow settings if we haven't already
    if originalTerrainSettings.shadowsEnabled == nil then
        originalTerrainSettings.shadowsEnabled = Lighting.GlobalShadows
    end
    
    if state then
        -- Disable global shadows
        Lighting.GlobalShadows = false
        
        -- Set time to noon to minimize shadows
        pcall(function()
            Lighting.ClockTime = 12
        end)
    else
        -- Restore original settings
        Lighting.GlobalShadows = originalTerrainSettings.shadowsEnabled
    end
end

local function toggleClouds(state)
    removalSettings.RemoveClouds = state

    -- Remove/restore Terrain Clouds using the Clouds instance
    if Terrain then
        local clouds = Terrain:FindFirstChildOfClass("Clouds")
        if clouds then
            if state then
                -- Store original state
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
    local Lighting = game:GetService("Lighting")
    if state then
        -- Remove all lighting
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
        -- Restore all lighting
        for _, childInfo in pairs(originalLightingChildren) do
            if childInfo.Instance then
                childInfo.Instance.Parent = childInfo.Parent
            end
        end
        originalLightingChildren = {}
        library:SendNotification("Restored lighting effects", 3)
        lightingRemoved = false
    end
end

local function cleanupESP()
    if espRunning then
        RunService:UnbindFromRenderStep("MaleESP")
        espRunning = false
    end
    
    for _, espBox in pairs(espBoxes) do
        local allLines = {
            espBox.TopLine, espBox.LeftLine, espBox.RightLine, espBox.BottomLine,
            espBox.TopLeftCorner1, espBox.TopLeftCorner2, espBox.TopRightCorner1, espBox.TopRightCorner2,
            espBox.BottomLeftCorner1, espBox.BottomLeftCorner2, espBox.BottomRightCorner1, espBox.BottomRightCorner2
        }
        
        for _, line in pairs(allLines) do
            line:Remove()
        end
        
        if espBox.Highlight and espBox.Highlight.Parent then
            espBox.Highlight:Destroy()
        end
    end
    
    espBoxes = {}
    
    -- Restore any removed objects
    toggleMaleChildrenTransparency(false)
    toggleLessShadows(false)
    toggleClouds(false)
    toggleLeaves(false)
    restoreAllLighting()
end

RunService:BindToRenderStep("MaleESP", Enum.RenderPriority.Camera.Value, updateESP)
espRunning = true

local library = loadstring(game:HttpGet("https://raw.githubusercontent.com/drillygzzly/Roblox-UI-Libs/main/1%20Tokyo%20Lib%20(FIXED)/Tokyo%20Lib%20Source.lua"))({
    cheatname = "GPT-Hook",
    gamename = "BHRM 5",
})

local function copyToClipboard(text)
    setclipboard(text)
    library:SendNotification("Link copied!", 3)
end

library:init()

local Window = library.NewWindow({
    title = "GPT-Hook 1.2",
    size = UDim2.new(0, 510, 0.6, 6)
})

local MainTab = Window:AddTab("  Visuals  ")
local CreditsTab = Window:AddTab("  Credits  ")
local SettingsTab = library:CreateSettingsTab(Window)

local MainSection = MainTab:AddSection("ESP Controls", 1)

MainSection:AddToggle({
    text = "Box ESP",
    state = false,
    tooltip = "Enable/Disable 2D box ESP",
    flag = "ESP_Boxes",
    callback = function(state)
        espSettings.BoxEnabled = state
    end
})

MainSection:AddList({
    text = "Box Style",
    tooltip = "Choose box style: Full or Corner",
    values = {"Full", "Corner"},
    selected = "Full",
    flag = "Box_Style",
    callback = function(value)
        espSettings.BoxStyle = value
    end
})

local cornerSizeSlider = MainSection:AddSlider({
    text = "Corner Size",
    flag = "Corner_Size",
    suffix = "px",
    min = 3,
    max = 20,
    increment = 1,
    value = 5,
    callback = function(value)
        espSettings.CornerSize = value
    end
})

MainSection:AddColor({
    text = "Box Color",
    color = espSettings.BoxColor,
    flag = "BoxColor",
    callback = function(color)
        espSettings.BoxColor = color
    end
})

MainSection:AddSeparator({
    text = "Box Properties"
})

MainSection:AddSlider({
    text = "Box Thickness",
    flag = "Box_Thickness",
    suffix = "px",
    min = 1,
    max = 20,
    increment = 1,
    value = 1,
    callback = function(value)
        espSettings.BoxThickness = value
    end
})

MainSection:AddSlider({
    text = "Box Transparency",
    flag = "Box_Transparency",
    min = 0,
    max = 1,
    increment = 0.05,
    value = 1,
    callback = function(value)
        espSettings.BoxTransparency = value
    end
})

MainSection:AddSlider({
    text = "Minimum Box Distance",
    flag = "Min_Distance",
    suffix = " studs",
    min = 0,
    max = 20,
    increment = 1,
    value = 5,
    callback = function(value)
        espSettings.MinimumDistance = value
    end
})

local HighlightSection = MainTab:AddSection("Highlight Controls", 2)

HighlightSection:AddToggle({
    text = "Highlight Models",
    state = false,
    tooltip = "Enable/Disable model highlighting",
    flag = "ESP_Highlights",
    callback = function(state)
        espSettings.HighlightEnabled = state
    end
})

HighlightSection:AddList({
    text = "Highlight Depth Mode",
    tooltip = "Change how highlights appear through walls",
    values = {"AlwaysOnTop", "Occluded"},
    selected = "Occluded",
    flag = "Highlight_DepthMode",
    callback = function(value)
        if value == "AlwaysOnTop" then
            espSettings.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        else
            espSettings.DepthMode = Enum.HighlightDepthMode.Occluded
        end
    end
})

HighlightSection:AddColor({
    text = "Highlight Fill Color",
    color = espSettings.HighlightColor,
    flag = "HighlightColor",
    callback = function(color)
        espSettings.HighlightColor = color
    end
})

HighlightSection:AddColor({
    text = "Highlight Outline Color",
    color = espSettings.OutlineColor,
    flag = "OutlineColor",
    callback = function(color)
        espSettings.OutlineColor = color
    end
})

HighlightSection:AddSeparator({
    text = "Highlight Transparency"
})

HighlightSection:AddSlider({
    text = "Fill Transparency",
    flag = "Highlight_FillTransparency",
    min = 0,
    max = 1,
    increment = 0.05,
    value = 0.8,
    callback = function(value)
        espSettings.HighlightFillTransparency = value
    end
})

HighlightSection:AddSlider({
    text = "Outline Transparency",
    flag = "Highlight_OutlineTransparency",
    min = 0,
    max = 1,
    increment = 0.05,
    value = 0.5,
    callback = function(value)
        espSettings.OutlineTransparency = value
    end
})

-- Updated Removals section with requested features
local RemovalsSection = MainTab:AddSection("Removals", 2)

RemovalsSection:AddToggle({
    text = "Character Addons",
    state = false,
    tooltip = "Make Default, DefaultHigh, FlatTop and other Male models transparent",
    flag = "Transparent_MaleChildren",
    callback = function(state)
        toggleMaleChildrenTransparency(state)
    end
})

RemovalsSection:AddToggle({
    text = "Leaves",
    state = false,
    tooltip = "Find and remove leaves from trees in the environment",
    flag = "Remove_Leaves",
    callback = function(state)
        toggleLeaves(state)
    end
})

RemovalsSection:AddToggle({
    text = "Shadows",
    state = false,
    tooltip = "Reduces shadows by disabling global shadows and setting time to noon",
    flag = "Less_Shadows",
    callback = function(state)
        toggleLessShadows(state)
    end
})

RemovalsSection:AddToggle({
    text = "Clouds",
    state = false,
    tooltip = "Checks Workspace > Terrain for clouds and removes them",
    flag = "Remove_TerrainClouds",
    callback = function(state)
        toggleClouds(state)
    end
})

RemovalsSection:AddToggle({
    text = "Lighting Effects",
    state = false,
    tooltip = "Toggles all Sky, Atmosphere, Bloom, and other visual effects",
    flag = "Remove_AllLighting",
    callback = function(state)
        toggleAllLighting(state)
    end
})

local CreditsSection = CreditsTab:AddSection("Credits & Links", 1)

CreditsSection:AddButton({
    text = "guns.lol/pxul",
    tooltip = "Click to copy website link",
    callback = function()
        copyToClipboard("https://guns.lol/pxul")
    end
})

CreditsSection:AddButton({
    text = "GitHub Source",
    tooltip = "Click to copy GitHub repository link",
    callback = function()
        copyToClipboard("https://github.com/0pxul/GPT-hook")
    end
})

local Time = (string.format("%."..tostring(Decimals).."f", os.clock() - Clock))
library:SendNotification(("ESP Loaded In "..tostring(Time).."s"), 5)

game:GetService("Players").LocalPlayer.OnTeleport:Connect(function()
    cleanupESP()
end)
