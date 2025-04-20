
-- ===============================
-- AIMBOT TAB AND UI CONTROL!
-- ===============================
local aimbotEnabled = false
local aimbotSmoothing = 0.2
local aiming = false -- This is toggled by the keybind

local TargetParentModelName = "Male"
local TargetHeadPartName = "Head"
local Camera = Workspace.CurrentCamera

local AimbotTab = Window:AddTab("  Aimbot  ")
local AimbotSection = AimbotTab:AddSection("Aimbot Controls", 1)

AimbotSection:AddToggle({
    text = "Enable Aimbot",
    state = aimbotEnabled,
    flag = "Aimbot_Enabled",
    tooltip = "Enable/Disable the aimbot feature",
    callback = function(state)
        aimbotEnabled = state
    end
})

AimbotSection:AddSlider({
    text = "Smoothing",
    flag = "Aimbot_Smoothing",
    min = 0.05,
    max = 1,
    increment = 0.01,
    value = aimbotSmoothing,
    tooltip = "0.05 slowest - 1 instant (aim speed)",
    callback = function(value)
        aimbotSmoothing = value
    end
})

-- Tokyo Lib Keybind for Aimbot Activation
AimbotSection:AddBind({
    enabled = true,
    text = "Aimbot Keybind",
    tooltip = "Hold or toggle this key to activate aimbot aiming",
    mode = "hold", -- "hold" means aiming is true while key is held, "toggle" would flip on/off
    bind = Enum.KeyCode.RightMouse, -- Default to right mouse button
    flag = "Aimbot_Keybind",
    state = false,
    nomouse = false,
    risky = false,
    noindicator = false,
    callback = function(isHeld)
        aiming = isHeld
    end,
    keycallback = function(isHeld)
        aiming = isHeld
    end
})

-- =========
-- AIMBOT CORE (Menu will now control)
-- =========

local function hasBallSocketConstraint(model)
    for _, desc in ipairs(model:GetDescendants()) do
        if desc:IsA("BallSocketConstraint") then
            return true
        end
    end
    return false
end

local function getClosestHead()
    local closestPart = nil
    local closestDist = math.huge
    local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2)
    for _, model in ipairs(Workspace:GetChildren()) do
        if model:IsA("Model") and model.Name == TargetParentModelName and model.Parent then
            -- ALIVE CHECK: skip if model has BallSocketConstraint
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

RunService.RenderStepped:Connect(function()
    if aimbotEnabled and aiming and Camera then
        local target = getClosestHead()
        if target and typeof(target.Position) == "Vector3" then
            local screenPos, onScreen = Camera:WorldToViewportPoint(target.Position)
            if onScreen then
                local mousePos = game:GetService("UserInputService"):GetMouseLocation()
                local relX = screenPos.X - mousePos.X
                local relY = screenPos.Y - mousePos.Y
                local dist = math.sqrt(relX * relX + relY * relY)
                local threshold = 3 -- pixels, snap if closer than this
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