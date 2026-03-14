local Players    = game:GetService("Players")
local RS         = game:GetService("ReplicatedStorage")
local UIS        = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse  = player:GetMouse()

local selectedBlock   = nil
local moveStep        = 4.5
local handleButtons   = {}
local isDragging      = false
local dragDir         = nil
local dragStartScreen = nil
local lastMoveSteps   = 0
local DRAG_SENS       = 0.08
local DRAG_THRESHOLD  = 8
local activeHandle    = nil
local activeTouchId   = nil
local previewParts    = {}
local previewOffset   = Vector3.new(0, 0, 0)
local originalTransp  = {}

local PURPLE = Color3.fromRGB(140, 90, 220)
local AXES = {
    {axis="X", dir=Vector3.new( 1, 0, 0)},
    {axis="X", dir=Vector3.new(-1, 0, 0)},
    {axis="Y", dir=Vector3.new( 0, 1, 0)},
    {axis="Y", dir=Vector3.new( 0,-1, 0)},
    {axis="Z", dir=Vector3.new( 0, 0, 1)},
    {axis="Z", dir=Vector3.new( 0, 0,-1)},
}

local function getModelCF(model)
    local ok, pv = pcall(function() return model:GetPivot() end)
    if ok and pv then return pv end
    local mfp = model:FindFirstChild("MouseFilterPart")
    if mfp then return mfp.CFrame end
    local cp = model:FindFirstChild("ColorPart")
    if cp then return cp.CFrame end
    return nil
end

local function getModelSize(model)
    local mfp = model:FindFirstChild("MouseFilterPart")
    if mfp then return mfp.Size end
    local cp = model:FindFirstChild("ColorPart")
    if cp then return cp.Size end
    return Vector3.new(4.5, 4.5, 4.5)
end

local function getBlockUnderMouse()
    local unitRay = camera:ScreenPointToRay(mouse.X, mouse.Y)
    local params  = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    local bm = workspace:FindFirstChild("BuildModel")
    if not bm then return nil end
    params.FilterDescendantsInstances = {bm}
    local res = workspace:Raycast(unitRay.Origin, unitRay.Direction * 500, params)
    if not res then return nil end
    local part = res.Instance
    while part and part.Parent ~= bm do part = part.Parent end
    return part
end

local function hideOriginal(model)
    originalTransp = {}
    for _, desc in ipairs(model:GetDescendants()) do
        if desc:IsA("BasePart") then
            originalTransp[desc] = desc.Transparency
            desc.Transparency = 1
        end
    end
end

local function restoreOriginal()
    for part, tr in pairs(originalTransp) do
        if part and part.Parent then part.Transparency = tr end
    end
    originalTransp = {}
end

local function getVisualParts(model)
    local out = {}
    for _, desc in ipairs(model:GetDescendants()) do
        if not desc:IsA("BasePart") then continue end
        if desc.Name == "MouseFilterPart" then continue end
        local tr = originalTransp[desc] or desc.Transparency
        if tr < 1 then table.insert(out, desc) end
    end
    return out
end

local function destroyPreview()
    for _, p in ipairs(previewParts) do
        if p and p.Parent then p:Destroy() end
    end
    previewParts = {}
    restoreOriginal()
end

local function buildPreview(model)
    destroyPreview()
    if not model then return end
    hideOriginal(model)
    for _, src in ipairs(getVisualParts(model)) do
        local ghost = src:Clone()
        for _, child in ipairs(ghost:GetChildren()) do
            if not (child:IsA("SpecialMesh") or child:IsA("SurfaceAppearance")
                or child:IsA("Decal") or child:IsA("Texture")) then
                child:Destroy()
            end
        end
        ghost.Anchored     = true
        ghost.CanCollide   = false
        ghost.CastShadow   = false
        ghost.Transparency = originalTransp[src] or src.Transparency
        ghost.Name         = "MoveGhost"
        ghost.Parent       = workspace
        table.insert(previewParts, ghost)
    end
end

local function updatePreview(model, offset)
    if #previewParts == 0 then return end
    local srcs = getVisualParts(model)
    for i, ghost in ipairs(previewParts) do
        if srcs[i] then ghost.CFrame = srcs[i].CFrame + offset end
    end
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name           = "MoveTool"
screenGui.ResetOnSpawn   = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.AutoLocalize   = false
screenGui.Parent         = player.PlayerGui

local function uiCorner(p, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 8)
    c.Parent = p
end

local function clearHandles()
    for _, h in ipairs(handleButtons) do
        if h.button and h.button.Parent then h.button:Destroy() end
    end
    handleButtons   = {}
    isDragging      = false
    dragDir         = nil
    activeHandle    = nil
    activeTouchId   = nil
    lastMoveSteps   = 0
    previewOffset   = Vector3.new(0, 0, 0)
end

local function spawnHandles(model)
    clearHandles()
    if not model then return end
    for _, axDef in ipairs(AXES) do
        local btn = Instance.new("TextButton")
        btn.Size             = UDim2.new(0, 26, 0, 26)
        btn.AnchorPoint      = Vector2.new(0.5, 0.5)
        btn.Position         = UDim2.new(0, -200, 0, -200)
        btn.BackgroundColor3 = PURPLE
        btn.BackgroundTransparency = 0.2
        btn.Text             = ""
        btn.BorderSizePixel  = 0
        btn.ZIndex           = 10
        btn.Visible          = false
        btn.Parent           = screenGui
        uiCorner(btn, 999)
        local st = Instance.new("UIStroke")
        st.Color       = Color3.fromRGB(255, 255, 255)
        st.Transparency = 0.6
        st.Thickness   = 1.5
        st.Parent      = btn

        local capturedDir = axDef.dir
        btn.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.Touch and
               input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
            if activeHandle ~= nil then return end
            activeHandle    = btn
            activeTouchId   = input
            isDragging      = true
            dragDir         = capturedDir
            dragStartScreen = Vector2.new(input.Position.X, input.Position.Y)
            lastMoveSteps   = 0
            previewOffset   = Vector3.new(0, 0, 0)
            btn.BackgroundTransparency = 0.0
            buildPreview(selectedBlock)
        end)
        table.insert(handleButtons, {button=btn, dir=axDef.dir, axis=axDef.axis})
    end
end

RunService.RenderStepped:Connect(function()
    if selectedBlock and #handleButtons > 0 then
        local cf = getModelCF(selectedBlock)
        local sz = getModelSize(selectedBlock)
        if cf then
            for i, h in ipairs(handleButtons) do
                local d  = AXES[i].dir
                local wp = cf.Position + Vector3.new(
                    d.X*(sz.X*0.5+3), d.Y*(sz.Y*0.5+3), d.Z*(sz.Z*0.5+3))
                local sp, vis = camera:WorldToScreenPoint(wp)
                h.button.Visible = vis and sp.Z > 0
                if h.button.Visible then
                    h.button.Position = UDim2.new(0, sp.X, 0, sp.Y)
                end
            end
        end
    end
end)

UIS.InputChanged:Connect(function(input)
    if not isDragging or not selectedBlock or not dragDir then return end
    if activeTouchId and input ~= activeTouchId then return end
    if input.UserInputType ~= Enum.UserInputType.MouseMovement and
       input.UserInputType ~= Enum.UserInputType.Touch then return end
    local cur   = Vector2.new(input.Position.X, input.Position.Y)
    local delta = cur - dragStartScreen
    if delta.Magnitude < DRAG_THRESHOLD then return end
    local cf = getModelCF(selectedBlock)
    if not cf then return end
    local s0 = camera:WorldToScreenPoint(cf.Position)
    local s1 = camera:WorldToScreenPoint(cf.Position + dragDir * 10)
    local sd  = Vector2.new(s1.X - s0.X, s1.Y - s0.Y)
    if sd.Magnitude < 1 then return end
    local proj  = delta:Dot(sd / sd.Magnitude)
    local total = math.floor(proj * DRAG_SENS / moveStep)
    if total ~= lastMoveSteps then
        lastMoveSteps = total
        previewOffset = dragDir * (total * moveStep)
        updatePreview(selectedBlock, previewOffset)
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType ~= Enum.UserInputType.Touch and
       input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
    if activeTouchId ~= nil and input ~= activeTouchId then return end
    if isDragging and selectedBlock and lastMoveSteps ~= 0 then
        local newCF = getModelCF(selectedBlock) + previewOffset
        pcall(function() RS.Functions.CommitMove:InvokeServer(selectedBlock, newCF) end)
    end
    destroyPreview()
    if activeHandle and activeHandle.Parent then
        activeHandle.BackgroundTransparency = 0.2
    end
    isDragging    = false
    dragDir       = nil
    lastMoveSteps = 0
    activeHandle  = nil
    activeTouchId = nil
    previewOffset = Vector3.new(0, 0, 0)
end)

local M = {}

function M.activate(model)
    selectedBlock = model
    spawnHandles(model)
end

function M.deactivate()
    selectedBlock = nil
    clearHandles()
    destroyPreview()
end

function M.setStep(step)
    moveStep = step
end

_G.MoveTool = M
