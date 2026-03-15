local Players      = game:GetService("Players")
local RS           = game:GetService("ReplicatedStorage")
local UIS          = game:GetService("UserInputService")
local RunService   = game:GetService("RunService")
local HttpService  = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local mouse  = player:GetMouse()
local WindUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/orialdev/WindUI-Boreal/main/WindUI%20Boreal"))()
local SAVE_FILE = "pbm_builds.json"
local function loadBuilds()
    local ok, data = pcall(readfile, SAVE_FILE)
    if not ok or not data or data == "" then return {} end
    local ok2, parsed = pcall(function() return HttpService:JSONDecode(data) end)
    return ok2 and parsed or {}
end
local function saveBuilds(builds)
    local ok, enc = pcall(function() return HttpService:JSONEncode(builds) end)
    if ok then pcall(writefile, SAVE_FILE, enc) end
end
local function getDefaultName(builds)
    local i = 1
    while true do
        local name = "Build" .. i
        local found = false
        for _, b in pairs(builds) do if b.name == name then found = true; break end end
        if not found then return name end
        i = i + 1
    end
end
local CATEGORY_ROOTS = {
    { folder = RS:FindFirstChild("Blocks") },
    { folder = RS:FindFirstChild("BlocksCutscene") },
}
local function getCategoryOfBlock(blockName)
    for _, root in ipairs(CATEGORY_ROOTS) do
        if root.folder then
            for _, cat in pairs(root.folder:GetChildren()) do
                if cat:IsA("Folder") and cat:FindFirstChild(blockName) then
                    return cat.Name
                end
            end
        end
    end
    return "Unknown"
end
local function findBlockInRS(blockName)
    for _, root in ipairs(CATEGORY_ROOTS) do
        if root.folder then
            for _, cat in pairs(root.folder:GetChildren()) do
                local f = cat:FindFirstChild(blockName)
                if f then return f:FindFirstChild(blockName) or f end
            end
        end
    end
    return nil
end
local function getModelBrickColor(model)
    local a = model:GetAttribute("Color")
    if a then local ok, bc = pcall(BrickColor.new, a); if ok then return bc end end
    local cp = model:FindFirstChild("ColorPart"); if cp then return cp.BrickColor end
    local b  = model:FindFirstChild("Base");      if b  then return b.BrickColor end
    return BrickColor.new(1001)
end
local function getModelMaterial(model)
    local a = model:GetAttribute("Material")
    if a then
        local n = tostring(a):match("Enum%.Material%.(.+)")
        if n then local ok, m = pcall(function() return Enum.Material[n] end); if ok and m then return m end end
    end
    local cp = model:FindFirstChild("ColorPart"); if cp then return cp.Material end
    local b  = model:FindFirstChild("Base");      if b  then return b.Material end
    return Enum.Material.Plastic
end
local function getConfiguration(model)
    local c = model:FindFirstChild("Configuration"); if not c then return nil end
    local d = {}
    for _, ch in pairs(c:GetChildren()) do
        if ch:IsA("IntValue") or ch:IsA("NumberValue") or ch:IsA("StringValue") or ch:IsA("BoolValue") then
            d[ch.Name] = ch.Value
        end
    end
    return next(d) and d or nil
end
local function getModelPivot(model)
    local ok, pv = pcall(function() return model:GetPivot() end); if ok and pv then return pv end
    local cp = model:FindFirstChild("ColorPart") or model:FindFirstChild("MouseFilterPart")
    return cp and cp.CFrame or nil
end
local function getRefPart(model)
    return model:FindFirstChild("ColorPart")
        or model:FindFirstChild("MouseFilterPart")
        or model:FindFirstChildWhichIsA("BasePart")
end
local function getBlockUnderMouse()
    local ur = camera:ScreenPointToRay(mouse.X, mouse.Y)
    local p  = RaycastParams.new(); p.FilterType = Enum.RaycastFilterType.Include
    local bm = workspace:FindFirstChild("BuildModel"); if not bm then return nil end
    p.FilterDescendantsInstances = {bm}
    local r = workspace:Raycast(ur.Origin, ur.Direction*500, p); if not r then return nil end
    local part = r.Instance
    while part and part.Parent ~= bm do part = part.Parent end
    return part
end
local function blockInZone(pos, minB, maxB)
    return pos.X>=minB.X-0.1 and pos.X<=maxB.X+0.1
       and pos.Y>=minB.Y-0.1 and pos.Y<=maxB.Y+0.1
       and pos.Z>=minB.Z-0.1 and pos.Z<=maxB.Z+0.1
end
local function getZonePos(block)
    local cp = block:FindFirstChild("ColorPart") or block:FindFirstChild("MouseFilterPart")
    if cp then return cp.Position end
    local ok, pv = pcall(function() return block:GetPivot() end)
    return ok and pv and pv.Position or nil
end
local function cfToTable(cf)  return {cf:GetComponents()} end
local function tableToCF(t)   return CFrame.new(table.unpack(t)) end
local function spawnPosInFrontOfCamera()
    return camera.CFrame * CFrame.new(0, 0, -20)
end
local function findNewBlock(name, pos)
    local bm = workspace:FindFirstChild("BuildModel"); if not bm then return nil end
    local best, bd = nil, 999
    for _, b in pairs(bm:GetChildren()) do
        if b.Name == name then
            local ok, pv = pcall(function() return b:GetPivot() end)
            if ok and pv then local d=(pv.Position-pos).Magnitude; if d<bd then bd=d; best=b end end
        end
    end
    return bd < 10 and best or nil
end
local SAFE_SPAWN = CFrame.new(0, 10000, 0)
local safeOffset = 0
local function placeOneCP(data, nA)
    local t = findBlockInRS(data.name); if not t then return end
    local tCF = nA * data.relCF
    safeOffset = safeOffset + 6
    local spawnCF = SAFE_SPAWN * CFrame.new(safeOffset, 0, 0)
    local nb
    pcall(function() nb = RS.Functions.PlaceBlock:InvokeServer(t, spawnCF, data.brickColor, data.material) end)
    if not nb then pcall(function() nb = RS.Functions.PlaceBlock:InvokeServer(t, spawnCF) end) end
    if not nb then task.wait(0.3); nb = findNewBlock(data.name, spawnCF.Position) end
    if not nb then return end
    pcall(function() RS.Functions.CommitMove:InvokeServer(nb, tCF) end)
    pcall(function() RS.Functions.PaintBlock:InvokeServer(nb, data.brickColor, data.material) end)
    if data.isResized then
        local cp = nb:FindFirstChild("ColorPart")
        if cp then pcall(function() RS.Functions.CommitResize:InvokeServer(nb,{cp,tCF,data.cpSize}) end) end
    end
    if data.config then pcall(function() RS.Functions.UpdateBlockSettings:InvokeServer(nb, data.config) end) end
end
local function placeOneCS(data, nA)
    local t = findBlockInRS(data.name); if not t then return end
    local relCF = tableToCF(data.relCF); local tCF = nA * relCF
    local ok,  bc  = pcall(function() return BrickColor.new(data.brickColor) end)
    local ok2, mat = pcall(function() return Enum.Material[data.material] end)
    local brickColor = ok  and bc  or BrickColor.new(1001)
    local material   = ok2 and mat or Enum.Material.Plastic
    safeOffset = safeOffset + 6
    local spawnCF = SAFE_SPAWN * CFrame.new(safeOffset, 0, 0)
    local nb
    pcall(function() nb = RS.Functions.PlaceBlock:InvokeServer(t, spawnCF, brickColor, material) end)
    if not nb then pcall(function() nb = RS.Functions.PlaceBlock:InvokeServer(t, spawnCF) end) end
    if not nb then task.wait(0.25); nb = findNewBlock(data.name, spawnCF.Position) end
    if not nb then return end
    pcall(function() RS.Functions.CommitMove:InvokeServer(nb, tCF) end)
    pcall(function() RS.Functions.PaintBlock:InvokeServer(nb, brickColor, material) end)
    if data.isResized then
        local cp = nb:FindFirstChild("ColorPart")
        if cp then pcall(function() RS.Functions.CommitResize:InvokeServer(nb,{cp,tCF,Vector3.new(table.unpack(data.cpSize))}) end) end
    end
    if data.config and next(data.config) then
        pcall(function() RS.Functions.UpdateBlockSettings:InvokeServer(nb, data.config) end)
    end
end
local cpCorner1, cpCorner2  = nil, nil
local cpCopiedBlocks        = {}
local cpAnchorCF            = nil
local cpSelectingCorner     = 0
local csPendingBlocks       = {}
local csPendingAnchor       = nil
local previewParts          = {}
local previewCenter         = Vector3.new(0,0,0)
local pasteOffset           = Vector3.new(0,0,0)
local pasteStep             = 4.5
local previewTransparent    = false
local rotateMode            = false
local activeBlocks          = nil
local activeAnchorCF        = nil
local activeIsCS            = false
local pasteVisible          = false
local excludedBlocks        = {}
local pendingName           = ""
local selectedBuild         = nil
local handleButtons         = {}
local ringContainers        = {}
local isPressing            = false
local isDragging            = false
local holdTimer             = 0
local HOLD_TIME             = 0.6
local dragDir               = nil
local dragStartScreen       = nil
local lastMoveSteps         = 0
local DRAG_SENS             = 0.08
local cachedScreenDir       = nil
local activeHandleBtn       = nil
local activeTouchId         = nil
local PURPLE = Color3.fromRGB(140, 90, 220)
local AXES = {
    {axis="X", dir=Vector3.new( 1,0,0)},
    {axis="X", dir=Vector3.new(-1,0,0)},
    {axis="Y", dir=Vector3.new( 0,1,0)},
    {axis="Y", dir=Vector3.new( 0,-1,0)},
    {axis="Z", dir=Vector3.new( 0,0, 1)},
    {axis="Z", dir=Vector3.new( 0,0,-1)},
}
local RING_DEFS = {
    { id="X", color=Color3.fromRGB(210,50,50),  rotAxis=Vector3.new(1,0,0), ringU=Vector3.new(0,1,0), ringV=Vector3.new(0,0,1), dot1=Vector3.new(0,0, 1), dot2=Vector3.new(0,0,-1) },
    { id="Y", color=Color3.fromRGB(50,210,60),  rotAxis=Vector3.new(0,1,0), ringU=Vector3.new(1,0,0), ringV=Vector3.new(0,0,1), dot1=Vector3.new( 1,0,0), dot2=Vector3.new(-1,0,0) },
    { id="Z", color=Color3.fromRGB(60,110,230), rotAxis=Vector3.new(0,0,1), ringU=Vector3.new(1,0,0), ringV=Vector3.new(0,1,0), dot1=Vector3.new(0, 1,0), dot2=Vector3.new(0,-1,0) },
}
local RING_SEGS  = 48
local RING_THICK = 3
local DOT_SIZE   = 22
local screenGui = Instance.new("ScreenGui")
screenGui.Name="CopyPasteTool"; screenGui.ResetOnSpawn=false
screenGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset=true; screenGui.AutoLocalize=false
screenGui.Parent=player.PlayerGui
local function mkCorner(p, r)
    local c=Instance.new("UICorner"); c.CornerRadius=UDim.new(0,r or 8); c.Parent=p
end
local function clearPreview()
    for _, p in pairs(previewParts) do
        if typeof(p)=="Instance" and p.Parent then p:Destroy() end
    end
    previewParts={}
end
local function buildPreview()
    clearPreview()
    if not activeBlocks or not activeAnchorCF then return end
    local nA = CFrame.new(activeAnchorCF.Position+pasteOffset)*(activeAnchorCF-activeAnchorCF.Position)
    local s  = Vector3.new(0,0,0)
    local tr = previewTransparent and 0.5 or 0
    local bm = workspace:FindFirstChild("BuildModel")
    for _, data in pairs(activeBlocks) do
        if not excludedBlocks[data.name] then
            local relCF = activeIsCS and tableToCF(data.relCF) or data.relCF
            local tCF   = nA * relCF
            if not activeIsCS and bm then
                local srcModel = bm:FindFirstChild(data.name)
                if srcModel then
                    local modelCF = getModelPivot(srcModel)
                    if modelCF then
                        for _, desc in ipairs(srcModel:GetDescendants()) do
                            if desc:IsA("BasePart") and desc.Name ~= "MouseFilterPart" then
                                if desc.Transparency >= 1 then continue end
                                local ghost = desc:Clone()
                                for _, child in ipairs(ghost:GetChildren()) do
                                    if not (child:IsA("SpecialMesh") or child:IsA("SurfaceAppearance")
                                        or child:IsA("Decal") or child:IsA("Texture")) then
                                        child:Destroy()
                                    end
                                end
                                ghost.Anchored=true; ghost.CanCollide=false
                                ghost.CastShadow=false; ghost.Transparency=tr
                                if desc.Name == "ColorPart" then
                                    ghost.BrickColor = data.brickColor
                                    ghost.Material   = data.material
                                    if data.isResized then ghost.Size = data.cpSize end
                                end
                                local relPart = modelCF:ToObjectSpace(desc.CFrame)
                                ghost.CFrame = tCF * relPart
                                ghost.Name="CPGhost"; ghost.Parent=workspace
                                table.insert(previewParts, ghost)
                                s = s + ghost.CFrame.Position
                            end
                        end
                        continue
                    end
                end
            end
            local sz = activeIsCS and Vector3.new(table.unpack(data.cpSize)) or data.cpSize
            local p  = Instance.new("Part")
            p.Size=sz; p.CFrame=tCF; p.Anchored=true
            p.CanCollide=false; p.CastShadow=false; p.Transparency=tr
            if activeIsCS then
                local ok,bc   = pcall(function() return BrickColor.new(data.brickColor) end)
                local ok2,mat = pcall(function() return Enum.Material[data.material] end)
                p.BrickColor=ok and bc or BrickColor.new(1001)
                p.Material=ok2 and mat or Enum.Material.Plastic
            else
                p.BrickColor=data.brickColor; p.Material=data.material
            end
            p.Name="CPGhost"; p.Parent=workspace
            table.insert(previewParts, p); s=s+tCF.Position
        end
    end
    previewCenter = s / math.max(#previewParts, 1)
end
local function clearHandlesFunc()
    isPressing=false; isDragging=false; holdTimer=0
    dragDir=nil; lastMoveSteps=0; cachedScreenDir=nil
    if activeHandleBtn and activeHandleBtn.Parent then
        activeHandleBtn.BackgroundTransparency=0.1
    end
    activeHandleBtn=nil; activeTouchId=nil
    for _, h in ipairs(handleButtons) do
        if h.button and h.button.Parent then h.button:Destroy() end
    end
    handleButtons={}
    for _, rc in ipairs(ringContainers) do
        if rc.container and rc.container.Parent then rc.container:Destroy() end
    end
    ringContainers={}
end
local function hideRing(rc)
    for _, seg in ipairs(rc.segs) do seg.Visible=false end
end
local function spawnHandlesFunc()
    clearHandlesFunc()
    for _, axDef in ipairs(AXES) do
        local btn=Instance.new("TextButton")
        btn.Size=UDim2.new(0,DOT_SIZE,0,DOT_SIZE); btn.AnchorPoint=Vector2.new(0.5,0.5)
        btn.Position=UDim2.new(0,-300,0,-300)
        btn.BackgroundColor3=PURPLE; btn.BackgroundTransparency=0.1
        btn.Text=""; btn.BorderSizePixel=0; btn.ZIndex=12; btn.Visible=false
        btn.Parent=screenGui; mkCorner(btn,999)
        local st=Instance.new("UIStroke")
        st.Color=Color3.fromRGB(255,255,255); st.Transparency=0.5; st.Thickness=1.5; st.Parent=btn
        local cd=axDef.dir
        btn.InputBegan:Connect(function(input)
            if input.UserInputType~=Enum.UserInputType.Touch and
               input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
            if activeHandleBtn~=nil then return end
            isPressing=true; isDragging=false; holdTimer=0
            lastMoveSteps=0; cachedScreenDir=nil
            dragDir=cd; dragStartScreen=Vector2.new(input.Position.X,input.Position.Y)
            activeHandleBtn=btn; activeTouchId=input; btn.BackgroundTransparency=0.0
        end)
        table.insert(handleButtons,{button=btn, dir=cd, axis=axDef.axis, isRotate=false})
    end
    for _, rd in ipairs(RING_DEFS) do
        local container=Instance.new("Frame")
        container.Size=UDim2.new(1,0,1,0); container.BackgroundTransparency=1
        container.BorderSizePixel=0; container.ZIndex=6; container.Parent=screenGui
        local segs={}
        for i=1,RING_SEGS do
            local seg=Instance.new("Frame")
            seg.BackgroundColor3=rd.color; seg.BackgroundTransparency=0.25
            seg.BorderSizePixel=0; seg.ZIndex=6; seg.Visible=false; seg.Parent=container
            table.insert(segs,seg)
        end
        for dotIdx=1,2 do
            local btn=Instance.new("TextButton")
            btn.Size=UDim2.new(0,DOT_SIZE,0,DOT_SIZE); btn.AnchorPoint=Vector2.new(0.5,0.5)
            btn.Position=UDim2.new(0,-300,0,-300)
            btn.BackgroundColor3=rd.color; btn.BackgroundTransparency=0.1
            btn.Text=""; btn.BorderSizePixel=0; btn.ZIndex=12; btn.Visible=false
            btn.Parent=screenGui; mkCorner(btn,999)
            local st=Instance.new("UIStroke")
            st.Color=Color3.fromRGB(255,255,255); st.Transparency=0.5; st.Thickness=1.5; st.Parent=btn
            local capturedRd=rd
            btn.InputBegan:Connect(function(input)
                if input.UserInputType~=Enum.UserInputType.Touch and
                   input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
                if activeHandleBtn~=nil then return end
                isPressing=true; isDragging=false; holdTimer=0
                lastMoveSteps=0; cachedScreenDir=nil
                dragDir=capturedRd.rotAxis
                dragStartScreen=Vector2.new(input.Position.X,input.Position.Y)
                activeHandleBtn=btn; activeTouchId=input; btn.BackgroundTransparency=0.0
            end)
            table.insert(handleButtons,{button=btn, dir=rd.rotAxis, axis=rd.id, isRotate=true, dotIdx=dotIdx, ringDef=rd})
        end
        table.insert(ringContainers,{ringDef=rd, container=container, segs=segs})
    end
end
local function activatePaste(blocks, anchorCF, isCS)
    clearPreview(); clearHandlesFunc()
    activeBlocks=blocks; activeAnchorCF=anchorCF; activeIsCS=isCS
    excludedBlocks={}
    pasteOffset = spawnPosInFrontOfCamera().Position - anchorCF.Position
    pasteVisible=true
    buildPreview(); spawnHandlesFunc()
end
local function deactivatePaste()
    clearPreview(); clearHandlesFunc()
    activeBlocks=nil; activeAnchorCF=nil
    pasteOffset=Vector3.new(0,0,0); pasteVisible=false
end
local function collectCP()
    cpCopiedBlocks={}; cpAnchorCF=nil
    local bm=workspace:FindFirstChild("BuildModel")
    if not bm or not cpCorner1 or not cpCorner2 then return 0 end
    local minB=Vector3.new(math.min(cpCorner1.X,cpCorner2.X)-2.4, math.min(cpCorner1.Y,cpCorner2.Y)-2.4, math.min(cpCorner1.Z,cpCorner2.Z)-2.4)
    local maxB=Vector3.new(math.max(cpCorner1.X,cpCorner2.X)+2.4, math.max(cpCorner1.Y,cpCorner2.Y)+2.4, math.max(cpCorner1.Z,cpCorner2.Z)+2.4)
    local raw={}
    for _, block in pairs(bm:GetChildren()) do
        local zp=getZonePos(block)
        if zp and blockInZone(zp,minB,maxB) then
            local pv=getModelPivot(block); if pv then table.insert(raw,{block=block,pivotCF=pv}) end
        end
    end
    if #raw==0 then return 0 end
    table.sort(raw,function(a,b)
        local pa,pb=a.pivotCF.Position,b.pivotCF.Position
        if math.abs(pa.X-pb.X)>0.01 then return pa.X<pb.X end
        if math.abs(pa.Y-pb.Y)>0.01 then return pa.Y<pb.Y end
        return pa.Z<pb.Z
    end)
    cpAnchorCF=raw[1].pivotCF
    for _,e in ipairs(raw) do
        local relCF=cpAnchorCF:ToObjectSpace(e.pivotCF)
        local cp=getRefPart(e.block); local sz=cp and cp.Size or Vector3.new(4.5,4.5,4.5)
        local isr=math.abs(sz.X-4.5)>0.1 or math.abs(sz.Y-4.5)>0.1 or math.abs(sz.Z-4.5)>0.1
        table.insert(cpCopiedBlocks,{
            name=e.block.Name, relCF=relCF, cpSize=sz,
            brickColor=getModelBrickColor(e.block), material=getModelMaterial(e.block),
            isResized=isr, config=getConfiguration(e.block),
        })
    end
    return #cpCopiedBlocks
end
local function collectCS(c1, c2)
    local blocks={}
    local bm=workspace:FindFirstChild("BuildModel")
    if not bm or not c1 or not c2 then return blocks,nil end
    local minB=Vector3.new(math.min(c1.X,c2.X)-2.4, math.min(c1.Y,c2.Y)-2.4, math.min(c1.Z,c2.Z)-2.4)
    local maxB=Vector3.new(math.max(c1.X,c2.X)+2.4, math.max(c1.Y,c2.Y)+2.4, math.max(c1.Z,c2.Z)+2.4)
    local raw={}
    for _,block in pairs(bm:GetChildren()) do
        local zp=getZonePos(block)
        if zp and blockInZone(zp,minB,maxB) then
            local pv=getModelPivot(block); if pv then table.insert(raw,{block=block,pivotCF=pv}) end
        end
    end
    if #raw==0 then return blocks,nil end
    table.sort(raw,function(a,b)
        local pa,pb=a.pivotCF.Position,b.pivotCF.Position
        if math.abs(pa.X-pb.X)>0.01 then return pa.X<pb.X end
        if math.abs(pa.Y-pb.Y)>0.01 then return pa.Y<pb.Y end
        return pa.Z<pb.Z
    end)
    local anchorCF=raw[1].pivotCF
    for _,e in ipairs(raw) do
        local relCF=anchorCF:ToObjectSpace(e.pivotCF)
        local cp=getRefPart(e.block); local sz=cp and cp.Size or Vector3.new(4.5,4.5,4.5)
        local isr=math.abs(sz.X-4.5)>0.1 or math.abs(sz.Y-4.5)>0.1 or math.abs(sz.Z-4.5)>0.1
        local bc=getModelBrickColor(e.block); local mat=getModelMaterial(e.block)
        table.insert(blocks,{
            name=e.block.Name, relCF=cfToTable(relCF),
            cpSize={sz.X,sz.Y,sz.Z},
            brickColor=bc.Name,
            material=tostring(mat):match("Enum%.Material%.(.+)"),
            isResized=isr, config=getConfiguration(e.block),
            category=getCategoryOfBlock(e.block.Name),
        })
    end
    return blocks,cfToTable(anchorCF)
end
local regionParts            = {}
local cpPos1Box, cpPos2Box   = nil, nil
local function clearRegionBox()
    for _,p in pairs(regionParts) do if typeof(p)=="Instance" and p.Parent then p:Destroy() end end
    regionParts={}
end
local function updateRegionBox(c1, c2)
    clearRegionBox(); if not c1 or not c2 then return end
    local cen=(c1+c2)/2
    local sz=Vector3.new(math.abs(c2.X-c1.X)+4.5, math.abs(c2.Y-c1.Y)+4.5, math.abs(c2.Z-c1.Z)+4.5)
    local rp=Instance.new("Part"); rp.Size=sz; rp.CFrame=CFrame.new(cen)
    rp.Anchored=true; rp.CanCollide=false; rp.Transparency=1; rp.Parent=workspace
    local rb=Instance.new("SelectionBox"); rb.Color3=Color3.fromRGB(100,140,255)
    rb.LineThickness=0.05; rb.Adornee=rp; rb.Parent=workspace
    table.insert(regionParts,rp); table.insert(regionParts,rb)
end
local hoverBox, hoverBlock = nil, nil
RunService.Heartbeat:Connect(function()
    if cpSelectingCorner==0 then
        if hoverBox then hoverBox:Destroy(); hoverBox=nil end; hoverBlock=nil; return
    end
    local model=getBlockUnderMouse()
    if model and model~=hoverBlock then
        if hoverBox then hoverBox:Destroy() end; hoverBlock=model
        hoverBox=Instance.new("SelectionBox"); hoverBox.Color3=Color3.fromRGB(255,255,255); hoverBox.LineThickness=0.03
        local adorn=model:FindFirstChild("ColorPart") or model:FindFirstChild("MouseFilterPart") or model
        hoverBox.Adornee=adorn; hoverBox.Parent=workspace
    elseif not model then
        if hoverBox then hoverBox:Destroy(); hoverBox=nil end; hoverBlock=nil
    end
end)
UIS.InputBegan:Connect(function(input,gpe)
    if gpe then return end
    if input.UserInputType~=Enum.UserInputType.MouseButton1 and
       input.UserInputType~=Enum.UserInputType.Touch then return end
    if cpSelectingCorner==0 then return end
    local model=getBlockUnderMouse(); if not model then return end
    local zp=getZonePos(model); if not zp then return end
    local adorn=model:FindFirstChild("ColorPart") or model:FindFirstChild("MouseFilterPart") or model
    if cpSelectingCorner==1 then
        cpCorner1=zp; if cpPos1Box then cpPos1Box:Destroy() end
        cpPos1Box=Instance.new("SelectionBox"); cpPos1Box.Color3=Color3.fromRGB(55,185,100)
        cpPos1Box.LineThickness=0.07; cpPos1Box.Adornee=adorn; cpPos1Box.Parent=workspace
        cpSelectingCorner=0; updateRegionBox(cpCorner1,cpCorner2)
    elseif cpSelectingCorner==2 then
        cpCorner2=zp; if cpPos2Box then cpPos2Box:Destroy() end
        cpPos2Box=Instance.new("SelectionBox"); cpPos2Box.Color3=Color3.fromRGB(200,55,55)
        cpPos2Box.LineThickness=0.07; cpPos2Box.Adornee=adorn; cpPos2Box.Parent=workspace
        cpSelectingCorner=0; updateRegionBox(cpCorner1,cpCorner2)
    end
end)
RunService.RenderStepped:Connect(function(dt)
    if isPressing and not isDragging then
        holdTimer=holdTimer+dt
        if holdTimer>=HOLD_TIME then
            isDragging=true; lastMoveSteps=0
            if dragDir then
                local s0=camera:WorldToScreenPoint(previewCenter)
                local s1=camera:WorldToScreenPoint(previewCenter+dragDir*10)
                local sd=Vector2.new(s1.X-s0.X,s1.Y-s0.Y)
                if sd.Magnitude>1 then cachedScreenDir=sd/sd.Magnitude end
            end
            if activeHandleBtn and activeHandleBtn.Parent then
                activeHandleBtn.BackgroundTransparency=0.45
            end
        end
    end
    if pasteVisible then
        local r=14
        if not rotateMode then
            for _,rc in ipairs(ringContainers) do hideRing(rc) end
            for _,h in ipairs(handleButtons) do
                if not h.isRotate then
                    local wp=previewCenter+h.dir*r
                    local sp,vis=camera:WorldToScreenPoint(wp)
                    h.button.Visible=vis and sp.Z>0
                    if h.button.Visible then h.button.Position=UDim2.new(0,sp.X,0,sp.Y) end
                else
                    h.button.Visible=false
                end
            end
        else
            for _,h in ipairs(handleButtons) do
                if not h.isRotate then h.button.Visible=false end
            end
            local sp0=camera:WorldToScreenPoint(previewCenter)
            for _,rc in ipairs(ringContainers) do
                local rd=rc.ringDef
                if sp0.Z<=0 then hideRing(rc); continue end
                local n=#rc.segs; local pts={}
                for i=0,n do
                    local t=(i/n)*math.pi*2
                    local wp=previewCenter+rd.ringU*(math.cos(t)*r)+rd.ringV*(math.sin(t)*r)
                    local sp=camera:WorldToScreenPoint(wp)
                    table.insert(pts,{x=sp.X,y=sp.Y,vis=sp.Z>0})
                end
                local isActive=activeHandleBtn~=nil and dragDir==rd.rotAxis
                local transp=isActive and 0.05 or 0.25
                for i=1,n do
                    local p1=pts[i]; local p2=pts[i+1]; local seg=rc.segs[i]
                    if not p1.vis or not p2.vis then seg.Visible=false; continue end
                    local midX=(p1.x+p2.x)*0.5; local midY=(p1.y+p2.y)*0.5
                    local dx=p2.x-p1.x; local dy=p2.y-p1.y
                    local len=math.sqrt(dx*dx+dy*dy)
                    seg.Size=UDim2.new(0,len+1,0,RING_THICK)
                    seg.Position=UDim2.new(0,midX-(len+1)*0.5,0,midY-RING_THICK*0.5)
                    seg.Rotation=math.deg(math.atan2(dy,dx))
                    seg.BackgroundColor3=rd.color; seg.BackgroundTransparency=transp; seg.Visible=true
                end
            end
            for _,h in ipairs(handleButtons) do
                if h.isRotate then
                    local rd=h.ringDef
                    local dir=h.dotIdx==1 and rd.dot1 or rd.dot2
                    local wp=previewCenter+dir*r
                    local sp,vis=camera:WorldToScreenPoint(wp)
                    h.button.Visible=vis and sp.Z>0
                    if h.button.Visible then h.button.Position=UDim2.new(0,sp.X,0,sp.Y) end
                end
            end
        end
    else
        for _,h in ipairs(handleButtons) do h.button.Visible=false end
        for _,rc in ipairs(ringContainers) do hideRing(rc) end
    end
end)
UIS.InputChanged:Connect(function(input)
    if not isDragging or not dragDir or not cachedScreenDir then return end
    if activeTouchId and input~=activeTouchId then return end
    if input.UserInputType~=Enum.UserInputType.MouseMovement and
       input.UserInputType~=Enum.UserInputType.Touch then return end
    local delta=Vector2.new(input.Position.X,input.Position.Y)-dragStartScreen
    local proj=delta:Dot(cachedScreenDir)
    local total=math.floor(proj*DRAG_SENS/pasteStep)
    local diff=total-lastMoveSteps
    if diff~=0 then
        lastMoveSteps=total
        if rotateMode then
            local angle=math.rad(pasteStep*diff)
            local rotCF=CFrame.fromAxisAngle(dragDir,angle)
            local pos=activeAnchorCF.Position+pasteOffset
            activeAnchorCF=CFrame.new(pos)*rotCF*(activeAnchorCF-activeAnchorCF.Position)-pasteOffset
        else
            pasteOffset=pasteOffset+dragDir*(diff*pasteStep)
        end
        buildPreview()
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType~=Enum.UserInputType.Touch and
       input.UserInputType~=Enum.UserInputType.MouseButton1 then return end
    if activeTouchId~=nil and input~=activeTouchId then return end
    isPressing=false; isDragging=false; holdTimer=0; cachedScreenDir=nil; lastMoveSteps=0; dragDir=nil
    if activeHandleBtn and activeHandleBtn.Parent then activeHandleBtn.BackgroundTransparency=0.1 end
    activeHandleBtn=nil; activeTouchId=nil
end)
local previewGui    = nil
local vpCamera      = nil
local vpWorld       = nil
local vpParts       = {}
local vpDragging    = false
local vpLastInput   = nil
local vpRotX        = 0
local vpRotY        = 0
local VP_DIST       = 25
local function destroyPreviewGui()
    if previewGui and previewGui.Parent then previewGui:Destroy() end
    previewGui=nil; vpCamera=nil; vpWorld=nil; vpParts={}
end
local function buildVPParts(build, isTransparent)
    if not vpWorld then return end
    for _, p in pairs(vpParts) do if p and p.Parent then p:Destroy() end end
    vpParts = {}
    if not build or not build.blocks or not build.anchor then return end
    local anchorCF = tableToCF(build.anchor)
    local tr = isTransparent and 0.5 or 0
    for _, data in ipairs(build.blocks) do
        local relCF = tableToCF(data.relCF)
        local tCF   = anchorCF * relCF
        local ok, bc   = pcall(function() return BrickColor.new(data.brickColor) end)
        local ok2, mat = pcall(function() return Enum.Material[data.material] end)
        local brickColor = ok  and bc  or BrickColor.new(1001)
        local material   = ok2 and mat or Enum.Material.Plastic
        local rsModel = findBlockInRS(data.name)
        local placed  = false
        if rsModel then
            local modelCF = getModelPivot(rsModel)
            if modelCF then
                for _, desc in ipairs(rsModel:GetDescendants()) do
                    if desc:IsA("BasePart") and desc.Name ~= "MouseFilterPart" then
                        if desc.Transparency >= 1 then continue end
                        local ghost = desc:Clone()
                        for _, child in ipairs(ghost:GetChildren()) do
                            if not (child:IsA("SpecialMesh") or child:IsA("SurfaceAppearance")
                                or child:IsA("Decal") or child:IsA("Texture")) then
                                child:Destroy()
                            end
                        end
                        ghost.Anchored = true; ghost.CanCollide = false
                        ghost.CastShadow = false; ghost.Transparency = tr
                        if desc.Name == "ColorPart" then
                            ghost.BrickColor = brickColor
                            ghost.Material   = material
                            if data.isResized then
                                ghost.Size = Vector3.new(table.unpack(data.cpSize))
                            end
                        end
                        local relPart = modelCF:ToObjectSpace(desc.CFrame)
                        ghost.CFrame  = tCF * relPart
                        ghost.Name    = "VPGhost"
                        ghost.Parent  = vpWorld
                        table.insert(vpParts, ghost)
                        placed = true
                    end
                end
            end
        end
        if not placed then
            local sz = Vector3.new(table.unpack(data.cpSize))
            local p  = Instance.new("Part")
            p.Size = sz; p.CFrame = tCF; p.Anchored = true
            p.CanCollide = false; p.CastShadow = false; p.Transparency = tr
            p.BrickColor = brickColor; p.Material = material
            p.Name = "VPGhost"; p.Parent = vpWorld
            table.insert(vpParts, p)
        end
    end
    local s = Vector3.new(0, 0, 0)
    for _, p in pairs(vpParts) do s = s + p.CFrame.Position end
    local center = s / math.max(#vpParts, 1)
    if vpCamera then
        vpCamera.CFrame = CFrame.new(center + Vector3.new(0, 0, VP_DIST), center)
    end
end
local function openPreviewGui(buildArg)
    destroyPreviewGui()
    if not buildArg then return end
    local build = buildArg
    previewGui = Instance.new("ScreenGui")
    previewGui.Name = "CPPreviewGui"
    previewGui.ResetOnSpawn = false
    previewGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    previewGui.IgnoreGuiInset = true
    previewGui.AutoLocalize = false
    previewGui.Parent = player.PlayerGui
    local W = 300
    local H = 300
    local bg = Instance.new("Frame")
    bg.Name = "BG"
    bg.Size = UDim2.new(0, W, 0, H)
    bg.AnchorPoint = Vector2.new(0.5, 0.5)
    bg.Position = UDim2.new(0.5, 0, 0.5, 0)
    bg.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
    bg.BorderSizePixel = 0
    bg.ZIndex = 2
    bg.Parent = previewGui
    mkCorner(bg, 12)
    local bgStroke = Instance.new("UIStroke")
    bgStroke.Color = Color3.fromRGB(55, 55, 75)
    bgStroke.Thickness = 1
    bgStroke.Parent = bg
    local SIDE_W = 150
    local sideOpen = false
    local sidePanel = Instance.new("Frame")
    sidePanel.Name = "SidePanel"
    sidePanel.Size = UDim2.new(0, SIDE_W, 0, H)
    sidePanel.AnchorPoint = Vector2.new(0, 0.5)
    sidePanel.Position = UDim2.new(0.5, W / 2 + 8, 0.5, 0)
    sidePanel.BackgroundColor3 = Color3.fromRGB(14, 14, 20)
    sidePanel.BorderSizePixel = 0
    sidePanel.ZIndex = 2
    sidePanel.Visible = false
    sidePanel.Parent = previewGui
    mkCorner(sidePanel, 10)
    local sideStroke = Instance.new("UIStroke")
    sideStroke.Color = Color3.fromRGB(55, 55, 75)
    sideStroke.Thickness = 1
    sideStroke.Parent = sidePanel
    local sideTitleLbl = Instance.new("TextLabel")
    sideTitleLbl.Size = UDim2.new(1, 0, 0, 22)
    sideTitleLbl.Position = UDim2.new(0, 0, 0, 4)
    sideTitleLbl.BackgroundTransparency = 1
    sideTitleLbl.Text = "Categories"
    sideTitleLbl.TextColor3 = Color3.fromRGB(175, 165, 220)
    sideTitleLbl.Font = Enum.Font.GothamBold
    sideTitleLbl.TextSize = 11
    sideTitleLbl.ZIndex = 3
    sideTitleLbl.Parent = sidePanel
    local sideScroll = Instance.new("ScrollingFrame")
    sideScroll.Size = UDim2.new(1, -8, 1, -30)
    sideScroll.Position = UDim2.new(0, 4, 0, 28)
    sideScroll.BackgroundTransparency = 1
    sideScroll.BorderSizePixel = 0
    sideScroll.ScrollBarThickness = 3
    sideScroll.ZIndex = 3
    sideScroll.Parent = sidePanel
    local sideLayout = Instance.new("UIListLayout")
    sideLayout.Padding = UDim.new(0, 2)
    sideLayout.Parent = sideScroll
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.Size = UDim2.new(1, 0, 0, 36)
    header.Position = UDim2.new(0, 0, 0, 0)
    header.BackgroundTransparency = 1
    header.ZIndex = 3
    header.Parent = bg
    local titleLbl = Instance.new("TextLabel")
    titleLbl.Size = UDim2.new(1, -80, 1, 0)
    titleLbl.Position = UDim2.new(0, 10, 0, 0)
    titleLbl.BackgroundTransparency = 1
    titleLbl.Text = build.name
    titleLbl.TextColor3 = Color3.fromRGB(220, 215, 255)
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 12
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.TextTruncate = Enum.TextTruncate.AtEnd
    titleLbl.ZIndex = 4
    titleLbl.Parent = header
    local catBtn = Instance.new("TextButton")
    catBtn.Size = UDim2.new(0, 28, 0, 20)
    catBtn.AnchorPoint = Vector2.new(0, 0.5)
    catBtn.Position = UDim2.new(1, -62, 0.5, 0)
    catBtn.BackgroundColor3 = Color3.fromRGB(45, 40, 70)
    catBtn.BorderSizePixel = 0
    catBtn.Text = "Cat >"
    catBtn.TextColor3 = Color3.fromRGB(175, 165, 218)
    catBtn.Font = Enum.Font.Gotham
    catBtn.TextSize = 9
    catBtn.ZIndex = 4
    catBtn.Parent = header
    mkCorner(catBtn, 4)
    local closeBtn = Instance.new("TextButton")
    closeBtn.Size = UDim2.new(0, 28, 0, 20)
    closeBtn.AnchorPoint = Vector2.new(0, 0.5)
    closeBtn.Position = UDim2.new(1, -30, 0.5, 0)
    closeBtn.BackgroundColor3 = Color3.fromRGB(78, 24, 24)
    closeBtn.BorderSizePixel = 0
    closeBtn.Text = "X"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 10
    closeBtn.ZIndex = 4
    closeBtn.Parent = header
    mkCorner(closeBtn, 4)
    local sep1 = Instance.new("Frame")
    sep1.Size = UDim2.new(1, -16, 0, 1)
    sep1.Position = UDim2.new(0, 8, 0, 36)
    sep1.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    sep1.BorderSizePixel = 0
    sep1.ZIndex = 3
    sep1.Parent = bg
    local vp = Instance.new("ViewportFrame")
    vp.Size = UDim2.new(1, -16, 0, 160)
    vp.Position = UDim2.new(0, 8, 0, 42)
    vp.BackgroundColor3 = Color3.fromRGB(16, 16, 26)
    vp.BorderSizePixel = 0
    vp.ZIndex = 3
    vp.Parent = bg
    mkCorner(vp, 8)
    vpCamera = Instance.new("Camera")
    vpCamera.Parent = vp
    vp.CurrentCamera = vpCamera
    vpWorld = Instance.new("WorldModel")
    vpWorld.Parent = vp
    local lp = Instance.new("Part")
    lp.Anchored = true; lp.CanCollide = false; lp.Transparency = 1
    lp.Size = Vector3.new(1, 1, 1); lp.CFrame = CFrame.new(0, 50, 0)
    local li = Instance.new("PointLight"); li.Range = 200; li.Brightness = 2; li.Parent = lp
    lp.Parent = vpWorld
    local vpTransparent = false
    buildVPParts(build, vpTransparent)
    local ctrlRow = Instance.new("Frame")
    ctrlRow.Size = UDim2.new(1, -16, 0, 22)
    ctrlRow.Position = UDim2.new(0, 8, 0, 207)
    ctrlRow.BackgroundTransparency = 1
    ctrlRow.ZIndex = 3
    ctrlRow.Parent = bg
    local transpBtn = Instance.new("TextButton")
    transpBtn.Size = UDim2.new(0, 55, 1, 0)
    transpBtn.BackgroundColor3 = Color3.fromRGB(36, 34, 56)
    transpBtn.BorderSizePixel = 0
    transpBtn.Text = "Solid"
    transpBtn.TextColor3 = Color3.fromRGB(185, 178, 225)
    transpBtn.Font = Enum.Font.Gotham
    transpBtn.TextSize = 9
    transpBtn.ZIndex = 4
    transpBtn.Parent = ctrlRow
    mkCorner(transpBtn, 4)
    local countLbl = Instance.new("TextLabel")
    countLbl.Size = UDim2.new(0, 55, 1, 0)
    countLbl.Position = UDim2.new(0, 59, 0, 0)
    countLbl.BackgroundTransparency = 1
    countLbl.Text = #build.blocks .. " blks"
    countLbl.TextColor3 = Color3.fromRGB(105, 100, 135)
    countLbl.Font = Enum.Font.Gotham
    countLbl.TextSize = 9
    countLbl.ZIndex = 4
    countLbl.Parent = ctrlRow
    local otherBtn = Instance.new("TextButton")
    otherBtn.Size = UDim2.new(1, -118, 1, 0)
    otherBtn.Position = UDim2.new(0, 118, 0, 0)
    otherBtn.BackgroundColor3 = Color3.fromRGB(36, 34, 56)
    otherBtn.BorderSizePixel = 0
    otherBtn.Text = "Other builds v"
    otherBtn.TextColor3 = Color3.fromRGB(160, 152, 205)
    otherBtn.Font = Enum.Font.Gotham
    otherBtn.TextSize = 9
    otherBtn.ZIndex = 4
    otherBtn.Parent = ctrlRow
    mkCorner(otherBtn, 4)
    local otherPopup = Instance.new("Frame")
    otherPopup.Size = UDim2.new(1, -16, 0, 0)
    otherPopup.Position = UDim2.new(0, 8, 0, 232)
    otherPopup.BackgroundColor3 = Color3.fromRGB(20, 18, 32)
    otherPopup.BorderSizePixel = 0
    otherPopup.ZIndex = 5
    otherPopup.Visible = false
    otherPopup.ClipsDescendants = true
    otherPopup.Parent = bg
    mkCorner(otherPopup, 6)
    local popupStroke = Instance.new("UIStroke")
    popupStroke.Color = Color3.fromRGB(50, 50, 70); popupStroke.Thickness = 1; popupStroke.Parent = otherPopup
    local popupScroll = Instance.new("ScrollingFrame")
    popupScroll.Size = UDim2.new(1, 0, 1, 0)
    popupScroll.BackgroundTransparency = 1; popupScroll.BorderSizePixel = 0
    popupScroll.ScrollBarThickness = 3; popupScroll.ZIndex = 6; popupScroll.Parent = otherPopup
    local popupLayout = Instance.new("UIListLayout")
    popupLayout.Padding = UDim.new(0, 2); popupLayout.Parent = popupScroll
    local popupPad = Instance.new("UIPadding")
    popupPad.PaddingTop = UDim.new(0, 3); popupPad.PaddingLeft = UDim.new(0, 4)
    popupPad.PaddingRight = UDim.new(0, 4); popupPad.Parent = popupScroll
    local otherOpen = false
    local blockChecked = {}
    local function rebuildVP()
        if not vpWorld then return end
        for _, p in pairs(vpParts) do if p and p.Parent then p:Destroy() end end
        vpParts = {}
        if not build.anchor then return end
        local anchorCF = tableToCF(build.anchor)
        local tr = vpTransparent and 0.5 or 0
        for _, data in ipairs(build.blocks) do
            if not blockChecked[data.name] then
                local relCF = tableToCF(data.relCF)
                local tCF   = anchorCF * relCF
                local ok, bc   = pcall(function() return BrickColor.new(data.brickColor) end)
                local ok2, mat = pcall(function() return Enum.Material[data.material] end)
                local brickColor = ok  and bc  or BrickColor.new(1001)
                local material   = ok2 and mat or Enum.Material.Plastic
                local rsModel = findBlockInRS(data.name)
                local placed  = false
                if rsModel then
                    local modelCF = getModelPivot(rsModel)
                    if modelCF then
                        for _, desc in ipairs(rsModel:GetDescendants()) do
                            if desc:IsA("BasePart") and desc.Name ~= "MouseFilterPart" then
                                if desc.Transparency >= 1 then continue end
                                local ghost = desc:Clone()
                                for _, child in ipairs(ghost:GetChildren()) do
                                    if not (child:IsA("SpecialMesh") or child:IsA("SurfaceAppearance")
                                        or child:IsA("Decal") or child:IsA("Texture")) then
                                        child:Destroy()
                                    end
                                end
                                ghost.Anchored = true; ghost.CanCollide = false
                                ghost.CastShadow = false; ghost.Transparency = tr
                                if desc.Name == "ColorPart" then
                                    ghost.BrickColor = brickColor
                                    ghost.Material   = material
                                    if data.isResized then
                                        ghost.Size = Vector3.new(table.unpack(data.cpSize))
                                    end
                                end
                                local relPart = modelCF:ToObjectSpace(desc.CFrame)
                                ghost.CFrame  = tCF * relPart
                                ghost.Name    = "VPGhost"
                                ghost.Parent  = vpWorld
                                table.insert(vpParts, ghost)
                                placed = true
                            end
                        end
                    end
                end
                if not placed then
                    local sz = Vector3.new(table.unpack(data.cpSize))
                    local p  = Instance.new("Part")
                    p.Size = sz; p.CFrame = tCF; p.Anchored = true
                    p.CanCollide = false; p.CastShadow = false; p.Transparency = tr
                    p.BrickColor = brickColor; p.Material = material
                    p.Name = "VPGhost"; p.Parent = vpWorld
                    table.insert(vpParts, p)
                end
            end
        end
        local s = Vector3.new(0, 0, 0)
        for _, p in pairs(vpParts) do s = s + p.CFrame.Position end
        local center = s / math.max(#vpParts, 1)
        if vpCamera then
            local rot = CFrame.Angles(math.rad(vpRotX), math.rad(vpRotY), 0)
            vpCamera.CFrame = CFrame.new(center) * rot * CFrame.new(0, 0, VP_DIST)
        end
    end
    local function loadBuild(b)
        build = b
        titleLbl.Text = build.name
        countLbl.Text = #build.blocks .. " blks"
        blockChecked = {}
        vpTransparent = false; transpBtn.Text = "Solid"
        buildVPParts(build, false)
        populateSide()
    end
    local function populateOther()
        for _, c in pairs(popupScroll:GetChildren()) do
            if c:IsA("TextButton") then c:Destroy() end
        end
        local allBuilds = loadBuilds()
        local count = 0
        for _, b in ipairs(allBuilds) do
            if b.name ~= build.name then
                count = count + 1
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(1, 0, 0, 22)
                btn.BackgroundColor3 = Color3.fromRGB(30, 28, 44)
                btn.BorderSizePixel = 0
                btn.Text = b.name .. " (" .. #b.blocks .. ")"
                btn.TextColor3 = Color3.fromRGB(155, 148, 192)
                btn.Font = Enum.Font.Gotham; btn.TextSize = 9
                btn.TextXAlignment = Enum.TextXAlignment.Left
                btn.ZIndex = 6; btn.Parent = popupScroll; mkCorner(btn, 3)
                local pp = Instance.new("UIPadding"); pp.PaddingLeft = UDim.new(0, 6); pp.Parent = btn
                local cap = b
                btn.MouseButton1Click:Connect(function()
                    otherOpen = false
                    TweenService:Create(otherPopup, TweenInfo.new(0.1), {Size=UDim2.new(1,-16,0,0)}):Play()
                    task.delay(0.1, function() otherPopup.Visible = false end)
                    otherBtn.Text = "Other builds v"
                    loadBuild(cap)
                end)
            end
        end
        popupScroll.CanvasSize = UDim2.new(0, 0, 0, popupLayout.AbsoluteContentSize.Y + 6)
        return count
    end
    otherBtn.MouseButton1Click:Connect(function()
        otherOpen = not otherOpen
        if otherOpen then
            local cnt = populateOther()
            if cnt == 0 then otherOpen = false; return end
            otherPopup.Visible = true
            local h = math.min(cnt * 24 + 8, 88)
            TweenService:Create(otherPopup, TweenInfo.new(0.15), {Size=UDim2.new(1,-16,0,h)}):Play()
            otherBtn.Text = "Other builds ^"
        else
            TweenService:Create(otherPopup, TweenInfo.new(0.1), {Size=UDim2.new(1,-16,0,0)}):Play()
            task.delay(0.1, function() otherPopup.Visible = false end)
            otherBtn.Text = "Other builds v"
        end
    end)
    transpBtn.MouseButton1Click:Connect(function()
        vpTransparent = not vpTransparent
        transpBtn.Text = vpTransparent and "Ghost" or "Solid"
        rebuildVP()
    end)
    local sep2 = Instance.new("Frame")
    sep2.Size = UDim2.new(1, -16, 0, 1)
    sep2.Position = UDim2.new(0, 8, 0, 233)
    sep2.BackgroundColor3 = Color3.fromRGB(50, 50, 70)
    sep2.BorderSizePixel = 0; sep2.ZIndex = 3; sep2.Parent = bg
    local loadBtn = Instance.new("TextButton")
    loadBtn.Size = UDim2.new(0.5, -12, 0, 30)
    loadBtn.Position = UDim2.new(0, 8, 0, 240)
    loadBtn.BackgroundColor3 = Color3.fromRGB(45, 160, 85)
    loadBtn.BorderSizePixel = 0
    loadBtn.Text = "Load"
    loadBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    loadBtn.Font = Enum.Font.GothamBold; loadBtn.TextSize = 12
    loadBtn.ZIndex = 3; loadBtn.Parent = bg; mkCorner(loadBtn, 7)
    local cancelBtn = Instance.new("TextButton")
    cancelBtn.Size = UDim2.new(0.5, -12, 0, 30)
    cancelBtn.Position = UDim2.new(0.5, 4, 0, 240)
    cancelBtn.BackgroundColor3 = Color3.fromRGB(95, 26, 26)
    cancelBtn.BorderSizePixel = 0
    cancelBtn.Text = "Cancel"
    cancelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    cancelBtn.Font = Enum.Font.GothamBold; cancelBtn.TextSize = 12
    cancelBtn.ZIndex = 3; cancelBtn.Parent = bg; mkCorner(cancelBtn, 7)
    function populateSide()
        for _, c in pairs(sideScroll:GetChildren()) do
            if c:IsA("Frame") or c:IsA("TextButton") then c:Destroy() end
        end
        local catMap = {}
        for _, data in ipairs(build.blocks) do
            local cat = data.category or "Unknown"
            if not catMap[cat] then catMap[cat] = {} end
            local found = false
            for _, n in pairs(catMap[cat]) do if n == data.name then found = true; break end end
            if not found then table.insert(catMap[cat], data.name) end
        end
        local catOrder = {}
        for cat, _ in pairs(catMap) do table.insert(catOrder, cat) end
        table.sort(catOrder)
        local idx = 0
        for _, cat in ipairs(catOrder) do
            idx = idx + 1
            local catRow = Instance.new("Frame")
            catRow.Size = UDim2.new(1, 0, 0, 22)
            catRow.BackgroundColor3 = Color3.fromRGB(36, 32, 56)
            catRow.BorderSizePixel = 0; catRow.ZIndex = 4
            catRow.LayoutOrder = idx; catRow.Parent = sideScroll; mkCorner(catRow, 4)
            local catLbl = Instance.new("TextButton")
            catLbl.Size = UDim2.new(1, 0, 1, 0); catLbl.BackgroundTransparency = 1
            catLbl.Text = "+ " .. cat
            catLbl.TextColor3 = Color3.fromRGB(160, 152, 204)
            catLbl.Font = Enum.Font.GothamBold; catLbl.TextSize = 9
            catLbl.TextXAlignment = Enum.TextXAlignment.Left
            catLbl.ZIndex = 5; catLbl.Parent = catRow
            local catPad = Instance.new("UIPadding"); catPad.PaddingLeft = UDim.new(0, 6); catPad.Parent = catLbl
            local blockFrames = {}; local catOpen = false
            local names = catMap[cat]; table.sort(names)
            for _, blockName in ipairs(names) do
                idx = idx + 1
                local bRow = Instance.new("Frame")
                bRow.Size = UDim2.new(1, 0, 0, 18)
                bRow.BackgroundColor3 = Color3.fromRGB(20, 18, 32)
                bRow.BorderSizePixel = 0; bRow.ZIndex = 4
                bRow.LayoutOrder = idx; bRow.Visible = false
                bRow.Parent = sideScroll; mkCorner(bRow, 3)
                local cb = Instance.new("TextButton")
                cb.Size = UDim2.new(0, 12, 0, 12); cb.AnchorPoint = Vector2.new(0, 0.5)
                cb.Position = UDim2.new(0, 5, 0.5, 0)
                cb.BackgroundColor3 = Color3.fromRGB(42, 158, 80)
                cb.BorderSizePixel = 0; cb.Text = "V"
                cb.TextColor3 = Color3.fromRGB(255, 255, 255)
                cb.Font = Enum.Font.GothamBold; cb.TextSize = 7
                cb.ZIndex = 5; cb.Parent = bRow; mkCorner(cb, 3)
                local bLbl = Instance.new("TextLabel")
                bLbl.Size = UDim2.new(1, -22, 1, 0); bLbl.Position = UDim2.new(0, 20, 0, 0)
                bLbl.BackgroundTransparency = 1; bLbl.Text = blockName
                bLbl.TextColor3 = Color3.fromRGB(130, 124, 165)
                bLbl.Font = Enum.Font.Gotham; bLbl.TextSize = 8
                bLbl.TextXAlignment = Enum.TextXAlignment.Left
                bLbl.TextTruncate = Enum.TextTruncate.AtEnd
                bLbl.ZIndex = 5; bLbl.Parent = bRow
                local n = blockName
                cb.MouseButton1Click:Connect(function()
                    if blockChecked[n] then
                        blockChecked[n] = nil
                        cb.BackgroundColor3 = Color3.fromRGB(42, 158, 80); cb.Text = "V"
                    else
                        blockChecked[n] = true
                        cb.BackgroundColor3 = Color3.fromRGB(85, 24, 24); cb.Text = "X"
                    end
                    rebuildVP()
                end)
                table.insert(blockFrames, bRow)
            end
            catLbl.MouseButton1Click:Connect(function()
                catOpen = not catOpen
                catLbl.Text = (catOpen and "- " or "+ ") .. cat
                for _, bf in pairs(blockFrames) do bf.Visible = catOpen end
                sideScroll.CanvasSize = UDim2.new(0, 0, 0, sideLayout.AbsoluteContentSize.Y + 6)
            end)
        end
        sideScroll.CanvasSize = UDim2.new(0, 0, 0, sideLayout.AbsoluteContentSize.Y + 6)
    end
    populateSide()
    catBtn.MouseButton1Click:Connect(function()
        sideOpen = not sideOpen
        sidePanel.Visible = sideOpen
        catBtn.Text = sideOpen and "Cat <" or "Cat >"
    end)
    local zoomRow = Instance.new("Frame")
    zoomRow.Size = UDim2.new(0, 52, 0, 22)
    zoomRow.Position = UDim2.new(1, -60, 0, 42)
    zoomRow.BackgroundTransparency = 1
    zoomRow.ZIndex = 4
    zoomRow.Parent = bg
    local zoomInBtn = Instance.new("TextButton")
    zoomInBtn.Size = UDim2.new(0, 24, 1, 0)
    zoomInBtn.BackgroundColor3 = Color3.fromRGB(38, 36, 58)
    zoomInBtn.BorderSizePixel = 0
    zoomInBtn.Text = "+"
    zoomInBtn.TextColor3 = Color3.fromRGB(200, 195, 240)
    zoomInBtn.Font = Enum.Font.GothamBold
    zoomInBtn.TextSize = 13
    zoomInBtn.ZIndex = 5
    zoomInBtn.Parent = zoomRow
    mkCorner(zoomInBtn, 4)
    local zoomOutBtn = Instance.new("TextButton")
    zoomOutBtn.Size = UDim2.new(0, 24, 1, 0)
    zoomOutBtn.Position = UDim2.new(0, 28, 0, 0)
    zoomOutBtn.BackgroundColor3 = Color3.fromRGB(38, 36, 58)
    zoomOutBtn.BorderSizePixel = 0
    zoomOutBtn.Text = "-"
    zoomOutBtn.TextColor3 = Color3.fromRGB(200, 195, 240)
    zoomOutBtn.Font = Enum.Font.GothamBold
    zoomOutBtn.TextSize = 13
    zoomOutBtn.ZIndex = 5
    zoomOutBtn.Parent = zoomRow
    mkCorner(zoomOutBtn, 4)
    local vpDist = VP_DIST
    local function updateVPCamera()
        local s = Vector3.new(0, 0, 0)
        for _, p in pairs(vpParts) do s = s + p.CFrame.Position end
        local center = s / math.max(#vpParts, 1)
        if vpCamera then
            local rot = CFrame.Angles(math.rad(vpRotX), math.rad(vpRotY), 0)
            vpCamera.CFrame = CFrame.new(center) * rot * CFrame.new(0, 0, vpDist)
        end
    end
    zoomInBtn.MouseButton1Click:Connect(function()
        vpDist = math.max(vpDist - 3, 3)
        updateVPCamera()
    end)
    zoomOutBtn.MouseButton1Click:Connect(function()
        vpDist = math.min(vpDist + 3, 120)
        updateVPCamera()
    end)
    local savedCameraType = camera.CameraType
    camera.CameraType = Enum.CameraType.Scriptable
    local Players2 = game:GetService("Players")
    local char = Players2.LocalPlayer.Character
    local humanoid = char and char:FindFirstChildOfClass("Humanoid")
    if humanoid then humanoid.WalkSpeed = 0; humanoid.JumpPower = 0 end
    local vpTouchId   = nil
    local vpDragStart = nil
    local hdrTouchId  = nil
    local hdrDragStart = nil
    local hdrPosStart  = nil
    local dragConn    = nil
    local guiTouches = {}
    local blockConn = UIS.InputBegan:Connect(function(input, gpe)
        if input.UserInputType ~= Enum.UserInputType.Touch then return end
        local pos = Vector2.new(input.Position.X, input.Position.Y)
        local bgPos = bg.AbsolutePosition
        local bgSz  = bg.AbsoluteSize
        local inBg  = pos.X >= bgPos.X and pos.X <= bgPos.X + bgSz.X
                   and pos.Y >= bgPos.Y and pos.Y <= bgPos.Y + bgSz.Y
        local inSide = false
        if sidePanel.Visible then
            local sp = sidePanel.AbsolutePosition
            local ss = sidePanel.AbsoluteSize
            inSide = pos.X >= sp.X and pos.X <= sp.X + ss.X
                  and pos.Y >= sp.Y and pos.Y <= sp.Y + ss.Y
        end
        if inBg or inSide then
            guiTouches[input] = true
        end
    end)
    local blockEndConn = UIS.InputEnded:Connect(function(input)
        guiTouches[input] = nil
    end)
    vp.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch and
           input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if vpTouchId ~= nil then return end
        vpTouchId   = input
        vpDragStart = Vector2.new(input.Position.X, input.Position.Y)
    end)
    vp.InputEnded:Connect(function(input)
        if input == vpTouchId then vpTouchId = nil; vpDragStart = nil end
    end)
    header.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch and
           input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
        if vpTouchId ~= nil then return end
        if hdrTouchId ~= nil then return end
        hdrTouchId   = input
        hdrDragStart = Vector2.new(input.Position.X, input.Position.Y)
        hdrPosStart  = bg.Position
    end)
    header.InputEnded:Connect(function(input)
        if input == hdrTouchId then
            hdrTouchId = nil; hdrDragStart = nil; hdrPosStart = nil
        end
    end)
    dragConn = UIS.InputChanged:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.Touch and
           input.UserInputType ~= Enum.UserInputType.MouseMovement then return end
        if input == vpTouchId and vpDragStart then
            local cur = Vector2.new(input.Position.X, input.Position.Y)
            local delta = cur - vpDragStart; vpDragStart = cur
            vpRotY = vpRotY + delta.X * 0.5
            vpRotX = vpRotX + delta.Y * 0.5
            updateVPCamera()
        elseif input == hdrTouchId and hdrDragStart and hdrPosStart then
            local d = input.Position - hdrDragStart
            bg.Position = UDim2.new(
                hdrPosStart.X.Scale, hdrPosStart.X.Offset + d.X,
                hdrPosStart.Y.Scale, hdrPosStart.Y.Offset + d.Y
            )
            local bgAbs = bg.AbsolutePosition
            local bgW   = bg.AbsoluteSize.X
            sidePanel.Position = UDim2.new(0, bgAbs.X + bgW + 8, 0, bgAbs.Y)
            sidePanel.AnchorPoint = Vector2.new(0, 0)
        end
    end)
    local function cleanupAndClose()
        camera.CameraType = savedCameraType
        if humanoid then humanoid.WalkSpeed = 16; humanoid.JumpPower = 50 end
        if dragConn    then dragConn:Disconnect();    dragConn    = nil end
        if blockConn   then blockConn:Disconnect();   blockConn   = nil end
        if blockEndConn then blockEndConn:Disconnect(); blockEndConn = nil end
        vpTouchId = nil; hdrTouchId = nil; guiTouches = {}
        destroyPreviewGui()
    end
    closeBtn.MouseButton1Click:Connect(cleanupAndClose)
    loadBtn.MouseButton1Click:Connect(function()
        if not build.anchor then return end
        for name, _ in pairs(blockChecked) do excludedBlocks[name] = true end
        activatePaste(build.blocks, tableToCF(build.anchor), true)
        cleanupAndClose()
    end)
    cancelBtn.MouseButton1Click:Connect(cleanupAndClose)
end
local Window=WindUI:CreateWindow({
    Title="Copy & Paste", Author="PBM Tools", Folder="PBM",
    Size=UDim2.fromOffset(560,500), Icon="copy",
    ModernLayout=true, BottomDragBarEnabled=true,
})
local CPTab=Window:Tab({Title="Build",          Icon="clipboard"})
local SLTab=Window:Tab({Title="Structure Loader",Icon="database"})
local cpStatusPara=nil; local csStatusPara=nil
local buildsDropdown=nil; local buildsCache={}
local function cpStatus(txt)
    if cpStatusPara then pcall(function() cpStatusPara:Set({Title="Status",Content=txt}) end) end
end
local function csStatus(txt)
    if csStatusPara then pcall(function() csStatusPara:Set({Title="Status",Content=txt}) end) end
end
CPTab:Section({Title="Build"})
cpStatusPara=CPTab:Paragraph({Title="Status",Content="Pick Pos 1"})
CPTab:Button({Title="Set Pos 1", Callback=function()
    cpSelectingCorner=1; cpStatus("Click Pos 1 block...")
end})
CPTab:Button({Title="Set Pos 2", Callback=function()
    if not cpCorner1 then cpStatus("Pick Pos 1 first!"); return end
    cpSelectingCorner=2; cpStatus("Click Pos 2 block...")
end})
CPTab:Button({Title="Copy Zone", Callback=function()
    if not cpCorner1 or not cpCorner2 then cpStatus("Pick both positions!"); return end
    local count=collectCP()
    if count==0 then cpStatus("No blocks in zone!"); return end
    cpStatus("Copied "..count.." blocks")
    activatePaste(cpCopiedBlocks, cpAnchorCF, false)
end})
CPTab:Button({Title="Reset", Callback=function()
    cpCorner1=nil; cpCorner2=nil; cpCopiedBlocks={}; cpSelectingCorner=0; cpAnchorCF=nil
    clearRegionBox(); deactivatePaste()
    if cpPos1Box then cpPos1Box:Destroy(); cpPos1Box=nil end
    if cpPos2Box then cpPos2Box:Destroy(); cpPos2Box=nil end
    cpStatus("Pick Pos 1")
end})
CPTab:Divider({Title="Paste"})
CPTab:Button({Title="Paste", Callback=function()
    if not activeBlocks or #activeBlocks==0 or not activeAnchorCF then
        cpStatus("Nothing to paste!"); return
    end
    local blocks=activeBlocks; local anchorCF=activeAnchorCF; local offset=pasteOffset
    deactivatePaste()
    task.spawn(function()
        safeOffset=0
        local nA=CFrame.new(anchorCF.Position+offset)*(anchorCF-anchorCF.Position)
        for _,d in pairs(blocks) do placeOneCP(d,nA); task.wait(0.05) end
    end)
end})
CPTab:Button({Title="Cancel", Callback=function()
    deactivatePaste(); cpStatus("Cancelled")
end})
CPTab:Button({Title="Delete Zone", Callback=function()
    if not cpCorner1 or not cpCorner2 then cpStatus("Pick both positions first!"); return end
    local bm=workspace:FindFirstChild("BuildModel")
    if not bm then cpStatus("No BuildModel!"); return end
    local minB=Vector3.new(math.min(cpCorner1.X,cpCorner2.X)-2.4, math.min(cpCorner1.Y,cpCorner2.Y)-2.4, math.min(cpCorner1.Z,cpCorner2.Z)-2.4)
    local maxB=Vector3.new(math.max(cpCorner1.X,cpCorner2.X)+2.4, math.max(cpCorner1.Y,cpCorner2.Y)+2.4, math.max(cpCorner1.Z,cpCorner2.Z)+2.4)
    local toDelete={}
    for _,block in pairs(bm:GetChildren()) do
        local zp=getZonePos(block)
        if zp and blockInZone(zp,minB,maxB) then
            table.insert(toDelete, block)
        end
    end
    if #toDelete==0 then cpStatus("No blocks in zone!"); return end
    cpStatus("Deleting "..#toDelete.." blocks...")
    task.spawn(function()
        for _,block in ipairs(toDelete) do
            pcall(function() RS.Functions.DestroyBlock:InvokeServer(block) end)
            task.wait(0.05)
        end
        cpStatus("Deleted "..#toDelete.." blocks")
    end)
end})
CPTab:Section({Title="Save Build"})
CPTab:Input({Title="Build Name", Placeholder="Auto if empty", Callback=function(text)
    pendingName=text
end})
CPTab:Button({Title="Save to File", Callback=function()
    if not cpCorner1 or not cpCorner2 then cpStatus("Copy zone first!"); return end
    local blocks,anchor=collectCS(cpCorner1,cpCorner2)
    if #blocks==0 then cpStatus("No blocks in zone!"); return end
    local builds=loadBuilds()
    local name=(pendingName~="" and pendingName) or getDefaultName(builds)
    table.insert(builds,{name=name, blocks=blocks, anchor=anchor, date=os.date("%d.%m %H:%M")})
    saveBuilds(builds); cpStatus("Saved: "..name.." ("..#blocks.." blocks)")
    pendingName=""
end})
CPTab:Section({Title="Other"})
CPTab:Dropdown({Title="Handle Mode", Values={"Move","Rotate"}, Default="Move", Callback=function(v)
    rotateMode=v=="Rotate"
end})
CPTab:Toggle({Title="Transparent Preview", State=false, Callback=function(s)
    previewTransparent=s; buildPreview()
end})
CPTab:Slider({Title="Value", Value={Min=0.1,Max=13.5,Default=4.5}, Callback=function(v)
    pasteStep = math.max(v, 0.1)
end})
SLTab:Section({Title="Structure Loader"})
csStatusPara=SLTab:Paragraph({Title="Status",Content="Select a build"})
local function getBuildsForDropdown()
    local builds=loadBuilds(); buildsCache=builds
    local names={}
    for _,b in ipairs(builds) do
        table.insert(names, b.name.." | "..#b.blocks.." blks")
    end
    return names
end
local function refreshDropdown()
    local names=getBuildsForDropdown()
    if buildsDropdown then
        pcall(function() buildsDropdown:Refresh(names,true) end)
    end
end
buildsDropdown=SLTab:Dropdown({
    Title="Select Build", Values=getBuildsForDropdown(), Default=nil,
    Callback=function(val)
        for _,b in ipairs(buildsCache) do
            if b.name.." | "..#b.blocks.." blks"==val then
                selectedBuild=b
                csStatus("Selected: "..b.name)
                break
            end
        end
    end,
})
SLTab:Button({Title="Refresh", Callback=refreshDropdown})
SLTab:Button({Title="Open 3D Preview", Icon="eye", Callback=function()
    if not selectedBuild then csStatus("Select a build first!"); return end
    openPreviewGui(selectedBuild)
end})
SLTab:Button({Title="Delete Selected", Callback=function()
    if not selectedBuild then return end
    local builds=loadBuilds()
    for i,b in ipairs(builds) do
        if b.name==selectedBuild.name then table.remove(builds,i); break end
    end
    saveBuilds(builds); selectedBuild=nil
    csStatus("Deleted"); refreshDropdown()
end})
SLTab:Section({Title="Other"})
SLTab:Dropdown({Title="Handle Mode", Values={"Move","Rotate"}, Default="Move", Callback=function(v)
    rotateMode=v=="Rotate"
end})
SLTab:Toggle({Title="Transparent Preview", State=false, Callback=function(s)
    previewTransparent=s; buildPreview()
end})
SLTab:Slider({Title="Value", Value={Min=0.1,Max=13.5,Default=4.5}, Callback=function(v)
    pasteStep = math.max(v, 0.1)
end})
SLTab:Button({Title="Paste", Icon="check", Callback=function()
    if not activeBlocks or #activeBlocks==0 or not activeAnchorCF then
        csStatus("Nothing to paste!"); return
    end
    local blocks=activeBlocks; local anchorCF=activeAnchorCF; local offset=pasteOffset; local isCS=activeIsCS
    deactivatePaste()
    task.spawn(function()
        safeOffset=0
        local nA=CFrame.new(anchorCF.Position+offset)*(anchorCF-anchorCF.Position)
        for _,d in pairs(blocks) do
            if not excludedBlocks[d.name] then
                if isCS then placeOneCS(d,nA) else placeOneCP(d,nA) end
                task.wait(0.05)
            end
        end
    end)
end})
SLTab:Button({Title="Cancel", Callback=function()
    deactivatePaste(); csStatus("Cancelled")
end})
refreshDropdown()
_G.CopyPasteTool={
    deactivate=deactivatePaste,
    openPreview=openPreviewGui,
}
