local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local Mouse = LocalPlayer:GetMouse()

local SilentAim = {
    Enabled = true,
    TargetPart = "Head",
    FOV = 500,
    HitChance = 100,
    TeamCheck = false,
    VisibilityCheck = true,
    IgnoreWalls = false,
    WhitelistedPlayers = {},
    BlacklistedPlayers = {},
    TargetESP = true,
    ESPColor = Color3.fromRGB(255, 0, 0),
    ESPThickness = 2,
    ESPTransparency = 0.5,
    PredictionEnabled = true,
    PredictionAmount = 0.165 -- useless.
}

local CircleDrawing = Drawing.new("Circle")
CircleDrawing.Thickness = 2
CircleDrawing.Color = Color3.fromRGB(255, 255, 255)
CircleDrawing.Filled = false
CircleDrawing.Transparency = 1
CircleDrawing.NumSides = 100

local TargetESP = Drawing.new("Square")
TargetESP.Thickness = SilentAim.ESPThickness
TargetESP.Color = SilentAim.ESPColor
TargetESP.Filled = false
TargetESP.Transparency = SilentAim.ESPTransparency

local function IsPlayerValid(player)
    if player == LocalPlayer then return false end
    if SilentAim.TeamCheck and player.Team == LocalPlayer.Team then return false end
    if table.find(SilentAim.BlacklistedPlayers, player.Name) then return false end
    if #SilentAim.WhitelistedPlayers > 0 and not table.find(SilentAim.WhitelistedPlayers, player.Name) then return false end
    return true
end

local function PredictPosition(part)
    local velocity = part.Velocity
    local gravity = Vector3.new(0, -Workspace.Gravity, 0)
    local framePrediction = SilentAim.PredictionAmount / RunService.Heartbeat:Wait()
    return part.Position + (velocity * framePrediction) + (0.5 * gravity * framePrediction^2)
end

local function GetClosestPlayerToCursor()
    local ClosestPlayer = nil
    local ShortestDistance = math.huge

    for _, player in pairs(Players:GetPlayers()) do
        if IsPlayerValid(player) then
            local Character = player.Character
            if Character then
                local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
                local Humanoid = Character:FindFirstChild("Humanoid")
                if HumanoidRootPart and Humanoid and Humanoid.Health > 0 then
                    local TargetPosition = SilentAim.PredictionEnabled and PredictPosition(HumanoidRootPart) or HumanoidRootPart.Position
                    local ScreenPosition, OnScreen = Workspace.CurrentCamera:WorldToScreenPoint(TargetPosition)
                    if OnScreen then
                        local Distance = (Vector2.new(ScreenPosition.X, ScreenPosition.Y) - Vector2.new(Mouse.X, Mouse.Y)).Magnitude
                        if Distance < ShortestDistance and Distance <= SilentAim.FOV then
                            if SilentAim.VisibilityCheck then
                                local Ray = Ray.new(Workspace.CurrentCamera.CFrame.Position, (TargetPosition - Workspace.CurrentCamera.CFrame.Position).Unit * 300)
                                local Hit, _ = Workspace:FindPartOnRayWithIgnoreList(Ray, {LocalPlayer.Character, Character})
                                if Hit and not SilentAim.IgnoreWalls then continue end
                            end
                            ClosestPlayer = player
                            ShortestDistance = Distance
                        end
                    end
                end
            end
        end
    end

    return ClosestPlayer
end

local function ModifyArgs(Args, Method)
    local ClosestPlayer = GetClosestPlayerToCursor()
    if ClosestPlayer and ClosestPlayer.Character and ClosestPlayer.Character:FindFirstChild(SilentAim.TargetPart) then
        local TargetPart = ClosestPlayer.Character[SilentAim.TargetPart]
        local TargetPosition = SilentAim.PredictionEnabled and PredictPosition(TargetPart) or TargetPart.Position
        if Method == "FindPartOnRayWithIgnoreList" or Method == "FindPartOnRayWithWhitelist" then
            Args[1] = Ray.new(Workspace.CurrentCamera.CFrame.Position, (TargetPosition - Workspace.CurrentCamera.CFrame.Position).Unit * 1000)
        elseif Method == "Raycast" then
            Args[2] = (TargetPosition - Workspace.CurrentCamera.CFrame.Position).Unit * 1000
        elseif Method == "ScreenPointToRay" then
            local ViewportPoint = Workspace.CurrentCamera:WorldToViewportPoint(TargetPosition)
            Args[1] = ViewportPoint.X
            Args[2] = ViewportPoint.Y
        end
    end
    return Args
end

local OldNameCall
OldNameCall = hookmetamethod(game, "__namecall", function(Self, ...)
    local Args = {...}
    local Method = getnamecallmethod()

    if SilentAim.Enabled and not checkcaller() then
        if Method == "FindPartOnRayWithIgnoreList" or Method == "FindPartOnRayWithWhitelist" or Method == "Raycast" or Method == "ScreenPointToRay" then
            Args = ModifyArgs(Args, Method)
            return OldNameCall(Self, unpack(Args))
        elseif Method == "FireServer" then
            local ClosestPlayer = GetClosestPlayerToCursor()
            if ClosestPlayer and ClosestPlayer.Character and ClosestPlayer.Character:FindFirstChild(SilentAim.TargetPart) then
                local TargetPart = ClosestPlayer.Character[SilentAim.TargetPart]
                local TargetPosition = SilentAim.PredictionEnabled and PredictPosition(TargetPart) or TargetPart.Position
                if Self.Name == "RemoteEvent" and Args[1] == "Fire" then
                    Args[2] = TargetPosition
                    return OldNameCall(Self, unpack(Args))
                end
            end
        end
    end

    return OldNameCall(Self, ...)
end)

local OldIndex = nil
OldIndex = hookmetamethod(game, "__index", function(Self, Index)
    if SilentAim.Enabled and not checkcaller() then
        if Index == "Target" or Index == "Hit" or Index == "Position" then
            local ClosestPlayer = GetClosestPlayerToCursor()
            if ClosestPlayer and ClosestPlayer.Character and ClosestPlayer.Character:FindFirstChild(SilentAim.TargetPart) then
                local TargetPart = ClosestPlayer.Character[SilentAim.TargetPart]
                return SilentAim.PredictionEnabled and PredictPosition(TargetPart) or TargetPart.Position
            end
        end
    end

    return OldIndex(Self, Index)
end)

RunService.RenderStepped:Connect(function()
    CircleDrawing.Position = Vector2.new(Mouse.X, Mouse.Y + 36)
    CircleDrawing.Radius = SilentAim.FOV
    CircleDrawing.Visible = SilentAim.Enabled

    local ClosestPlayer = GetClosestPlayerToCursor()
    if ClosestPlayer and SilentAim.TargetESP then
        local Character = ClosestPlayer.Character
        if Character then
            local HumanoidRootPart = Character:FindFirstChild("HumanoidRootPart")
            if HumanoidRootPart then
                local Vector, OnScreen = Workspace.CurrentCamera:WorldToViewportPoint(HumanoidRootPart.Position)
                if OnScreen then
                    TargetESP.Size = Vector2.new(2000 / Vector.Z, 2500 / Vector.Z)
                    TargetESP.Position = Vector2.new(Vector.X - TargetESP.Size.X / 2, Vector.Y - TargetESP.Size.Y / 2)
                    TargetESP.Visible = true
                else
                    TargetESP.Visible = false
                end
            else
                TargetESP.Visible = false
            end
        else
            TargetESP.Visible = false
        end
    else
        TargetESP.Visible = false
    end
end)

UserInputService.InputBegan:Connect(function(Input)
    if Input.KeyCode == Enum.KeyCode.RightAlt then
        SilentAim.Enabled = not SilentAim.Enabled
    end
end)
