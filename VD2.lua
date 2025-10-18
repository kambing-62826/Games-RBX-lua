local Yv = loadstring(game:HttpGet("https://raw.githubusercontent.com/kambing-62826/Yuvi-UI-Libs-Roblox/refs/heads/roblox/Yuvi%20Libs.lua"))()
local MainTab = Yv:createTab("Survival")
local KTab = Yv:createTab("Killer")
local ZTab = Yv:createTab("UI")

MainTab:createSection({Name = "Player Control",Column = 1})
-- NoSkillCheck
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")

local Teams = game:GetService("Teams")
local Lighting = game:GetService("Lighting")
local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
local GeneratorRemotes = Remotes and Remotes:FindFirstChild("Generator")
local SkillCheckEvent = GeneratorRemotes and GeneratorRemotes:FindFirstChild("SkillCheckEvent")

local noSkillEnabled = false
local hookSkillInstalled = false
local oldNamecall

local skillExactNames = {
    SkillCheckPromptGui = true,
    ["SkillCheckPromptGui-con"] = true,
    SkillCheckEvent = true,
    SkillCheckFailEvent = true,
    SkillCheckResultEvent = true
}

local function isExactSkill(inst)
    local n = inst and inst.Name
    if not n then return false end
    if skillExactNames[n] then return true end
    return n:lower():find("skillcheck", 1, true) ~= nil
end

local function hardDelete(obj)
    pcall(function()
        if obj:IsA("ProximityPrompt") then
            obj.Enabled = false
            obj.HoldDuration = 1e9
        end
        if obj:IsA("ScreenGui") or obj:IsA("BillboardGui") or obj:IsA("SurfaceGui") then
            obj.Enabled = false
            obj.Visible = false
            obj.ResetOnSpawn = false
            obj:Destroy()
        else
            obj:Destroy()
        end
    end)
end

local function installSkillBlock()
    if hookSkillInstalled then return end
    if typeof(hookmetamethod) == "function" and typeof(getnamecallmethod) == "function" then
        oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
            local m = getnamecallmethod()
            if noSkillEnabled and typeof(self) == "Instance" and isExactSkill(self) then
                if m == "FireServer" or m == "InvokeServer" then
                    warn("[SkillCheck Blocked] Remote:", self.Name)
                    return nil
                end
            end
            return oldNamecall(self, ...)
        end)
        hookSkillInstalled = true
    end
end

MainTab:createToggle({
    Name = "NoSkillCheck",
    CurrentValue = false,
    Flag = "NoSkillCheck",
    Column = 1,
    Callback = function(s)
    noSkillEnabled = s
    if s then
        Yv:Notify("NoSkillCheck", "NoSkillCheck Enabled", 1.5)
        print("✅ No SkillCheck ENABLED")
        installSkillBlock()
        local pg = LP:FindFirstChild("PlayerGui")
        if pg then
            for _, g in ipairs(pg:GetDescendants()) do
                if isExactSkill(g) then
                    hardDelete(g)
                end
            end
        end
        for _, g in ipairs(StarterGui:GetDescendants()) do
            if isExactSkill(g) then
                hardDelete(g)
            end
        end
        for _, g in ipairs(ReplicatedStorage:GetDescendants()) do
            if isExactSkill(g) then
                hardDelete(g)
            end
        end
        for _, g in ipairs(Workspace:GetDescendants()) do
            if isExactSkill(g) then
                hardDelete(g)
            end
        end
    else
        Yv:Notify("NoSkillCheck", "NoSkillCheck Disabled", 1.5)
        print("❌ No SkillCheck DISABLED")
    end
end})

-- Noclip
MainTab:createLine({Orientation = "Horizontal",Color = Color3.fromRGB(80, 80, 80),Thickness = 1,Length = 1,Column = 1})
local noclipEnabled = false
local player = game.Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

local function getHumanoidRootPart()
    character = player.Character or player.CharacterAdded:Wait()
    return character:WaitForChild("HumanoidRootPart")
end

local humanoidRootPart = getHumanoidRootPart()

MainTab:createToggle({
    Name = "Noclip",
    CurrentValue = false,
    Flag = "NoclipToggle",
    Column = 1,
    Callback = function(state)
        noclipEnabled = state
        if state then
            Yv:Notify("NoClip", "NoClip Enabled", 1.5)
        else
            Yv:Notify("NoClip", "NoClip Disabled", 1.5)
        end
    end
})

game:GetService("RunService").Stepped:Connect(function()
    if not character or not character.Parent then
        humanoidRootPart = getHumanoidRootPart()
    end

    if noclipEnabled and character then
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = false
            end
        end
    elseif character then
        for _, part in pairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = true
            end
        end
    end
end)

-- SpeedLock
MainTab:createSection({Name = "Player Speed", Column = 1})

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

--// VARIABLES
local speedCurrent = 10
local speedLockEnabled = true
local speedPaused = false
local speedHumanoid = nil
local enforceThread = nil
local alive = true
local speedStunUntil, speedSlowUntil = 0, 0

--// HELPERS
local function now()
	return tick()
end

local function setWalkSpeed(h, v)
	if not h or not h.Parent then return end
	pcall(function()
		h.WalkSpeed = v
	end)
end

local function suppressFor(sec, kind)
	local u = now() + sec
	if kind == "slow" then
		speedSlowUntil = math.max(speedSlowUntil, u)
	else
		speedStunUntil = math.max(speedStunUntil, u)
	end
end

local function isSuppressed()
	if not speedHumanoid or not speedHumanoid.Parent then return true end
	if speedHumanoid.Health <= 0 then return true end
	if speedHumanoid.PlatformStand or speedHumanoid.Sit then return true end

	local st = speedHumanoid:GetState()
	if st == Enum.HumanoidStateType.Ragdoll
	or st == Enum.HumanoidStateType.FallingDown
	or st == Enum.HumanoidStateType.Physics
	or st == Enum.HumanoidStateType.GettingUp
	or st == Enum.HumanoidStateType.Seated then
		return true
	end

	local hrp = speedHumanoid.Parent:FindFirstChild("HumanoidRootPart")
	if hrp and hrp.Anchored then return true end
	if speedPaused then return true end
	if now() < speedStunUntil or now() < speedSlowUntil then return true end

	local rt = speedHumanoid.Parent:FindFirstChild("RagdollTrigger")
	if rt and rt:IsA("BoolValue") and rt.Value then return true end

	return false
end

--// ENFORCE LOOP
local function startSpeedEnforcer()
	if enforceThread then task.cancel(enforceThread) end
	enforceThread = task.spawn(function()
		while task.wait(0.25) do
			if not alive then break end
			if speedLockEnabled and speedHumanoid and speedHumanoid.Parent and not isSuppressed() then
				if math.abs(speedHumanoid.WalkSpeed - speedCurrent) > 0.05 then
					setWalkSpeed(speedHumanoid, speedCurrent)
				end
			end
		end
	end)
end

--// HOOK HUMANOID
local function hookHumanoid(h)
	if not h then return end
	speedHumanoid = h
	speedPaused = false
	alive = true
	startSpeedEnforcer()

	if speedLockEnabled and not isSuppressed() then
		setWalkSpeed(h, speedCurrent)
	end

	h:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if speedLockEnabled and not isSuppressed() and h.WalkSpeed ~= speedCurrent then
			setWalkSpeed(h, speedCurrent)
		end
	end)

	h.Died:Connect(function()
		alive = false
	end)

	h.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Ragdoll or new == Enum.HumanoidStateType.FallingDown
		or new == Enum.HumanoidStateType.Physics or new == Enum.HumanoidStateType.GettingUp
		or new == Enum.HumanoidStateType.Seated then
			speedPaused = true
			suppressFor(0.5, "stun")
			task.delay(0.6, function()
				speedPaused = false
			end)
		end
	end)

	h:GetPropertyChangedSignal("PlatformStand"):Connect(function()
		speedPaused = h.PlatformStand
	end)

	local ch = h.Parent
	if ch then
		local rt = ch:FindFirstChild("RagdollTrigger")
		if rt and rt:IsA("BoolValue") then
			rt.Changed:Connect(function()
				if rt.Value then
					speedPaused = true
				else
					task.delay(0.1, function() speedPaused = false end)
				end
			end)
		end
	end
end

--// CHARACTER HOOK (auto reconnect each round)
local function onCharacterAdded(char)
	task.defer(function()
		local h = char:WaitForChild("Humanoid", 10)
		if h then hookHumanoid(h) end
	end)
end

if LP.Character then onCharacterAdded(LP.Character) end
LP.CharacterAdded:Connect(onCharacterAdded)

--// UI ELEMENTS
local speedSlider = MainTab:createSlider({
	Name = "Walkspeed",
	Min = 10,
	Max = 100,
	Default = 10,
	Column = 1,
	Callback = function(v)
		speedCurrent = tonumber(v) or 10
		if speedHumanoid and speedHumanoid.Parent and not isSuppressed() then
			setWalkSpeed(speedHumanoid, speedCurrent)
		end
	end
})

MainTab:createButton({
	Name = "Speed Reset",
	Column = 1,
	Callback = function()
		speedCurrent = 10
		if speedHumanoid and speedHumanoid.Parent then
			setWalkSpeed(speedHumanoid, speedCurrent)
		end
	end
})

MainTab:createToggle({
	Name = "Enable SpeedLock",
	CurrentValue = true,
	Column = 1,
	Callback = function(state)
		speedLockEnabled = state
	end
})

--// KEYBINDS
local function updateSpeedUI()
	pcall(function()
		if typeof(speedSlider) == "table" and speedSlider.Slider and speedSlider.Slider.Set then
			speedSlider.Slider:Set(speedCurrent)
		elseif typeof(speedSlider.Set) == "function" then
			speedSlider:Set(speedCurrent)
		end
	end)
end

MainTab:createKeybind({
	Name = "Increase Speed (+)",
	Default = Enum.KeyCode.Equals,
	Column = 1,
	Callback = function()
		speedCurrent = math.clamp(speedCurrent + 5, 10, 100)
		if speedHumanoid and not isSuppressed() then
			setWalkSpeed(speedHumanoid, speedCurrent)
		end
		updateSpeedUI()
	end
})

MainTab:createKeybind({
	Name = "Decrease Speed (-)",
	Default = Enum.KeyCode.Minus,
	Column = 1,
	Callback = function()
		speedCurrent = math.clamp(speedCurrent - 5, 10, 100)
		if speedHumanoid and not isSuppressed() then
			setWalkSpeed(speedHumanoid, speedCurrent)
		end
		updateSpeedUI()
	end
})

MainTab:createKeybind({
	Name = "Reset Speed (R)",
	Default = Enum.KeyCode.R,
	Column = 1,
	Callback = function()
		speedCurrent = 10
		if speedHumanoid then
			setWalkSpeed(speedHumanoid, speedCurrent)
		end
		updateSpeedUI()
	end
})

-- Brightness
MainTab:createSection({Name = "Visual", Column = 2})
local initLighting = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogStart = Lighting.FogStart,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    ExposureCompensation = Lighting.ExposureCompensation,
    ShadowSoftness = Lighting:FindFirstChild("ShadowSoftness") and Lighting.ShadowSoftness or nil,
    EnvironmentDiffuseScale = Lighting:FindFirstChild("EnvironmentDiffuseScale") and Lighting.EnvironmentDiffuseScale or nil,
    EnvironmentSpecularScale = Lighting:FindFirstChild("EnvironmentSpecularScale") and Lighting.EnvironmentSpecularScale or nil,
    Technology = Lighting.Technology
}

local fullbrightEnabled = false
local fbLoop
local desiredClockTime = Lighting.ClockTime
local timeLockActive = false

local function bindTimeLock()
    if timeLockActive then return end
    timeLockActive = true
    RunService:BindToRenderStep("VD_TimeLock", 299, function()
        if Lighting.ClockTime ~= desiredClockTime then
            Lighting.ClockTime = desiredClockTime
        end
    end)
end

local fbLoop
local function bindFullbright()
    if fbLoop then fbLoop:Disconnect() end
    fbLoop = RunService.RenderStepped:Connect(function()
        if fullbrightEnabled then
            Lighting.Brightness = 2
            Lighting.ClockTime = 14
            Lighting.ExposureCompensation = 1
            Lighting.GlobalShadows = false
            Lighting.FogStart = 0
            Lighting.FogEnd = 1e6
        end
    end)
end

bindFullbright()

MainTab:createToggle({
    Name = "Fullbright",
    CurrentValue = false,
    Flag = "Fullbright",
    Column = 2,
    Callback = function(s)
        fullbrightEnabled = s
        if s then
            Yv:Notify("Lighting", "Fullbright Enabled", 1.5)
        else
            Yv:Notify("Lighting", "Fullbright Disabled", 1.5)
            Lighting.Brightness = initLighting.Brightness
            Lighting.ClockTime = initLighting.ClockTime
            Lighting.ExposureCompensation = initLighting.ExposureCompensation
            Lighting.GlobalShadows = initLighting.GlobalShadows
            Lighting.FogStart = initLighting.FogStart or 0
            Lighting.FogEnd = initLighting.FogEnd or 1000
        end
    end})

MainTab:createToggle({
    Name = "No Fog",
    CurrentValue = false,
    Flag = "NoFogToggle",
    Column = 2,
    Callback = function(state)
        if state then
            Yv:Notify("No Fog", "No Fog Enabled", 1.5)
            game.Lighting.FogStart = 0
            game.Lighting.FogEnd = 100000
        else
            Yv:Notify("No Fog", "No Fog Disabled", 1.5)
            game.Lighting.FogStart = 0
            game.Lighting.FogEnd = 1000
        end
        --print("No Fog Enabled:", state)
    end})

MainTab:createSlider({
    Name = "Time Of Day",
    Min = 0,
    Max = 24,
    Default = Lighting.ClockTime,
    Column = 2,
    Callback = function(v)
    desiredClockTime = v
    Lighting.ClockTime = v
    Lighting.Brightness = 1 + (v / 24) * 2
    Lighting.ExposureCompensation = (v / 24) * 1.5
    bindTimeLock()
        --print("Slider value:", v)
    end})

-- Player Esp
MainTab:createSection({Name = "Esp Player & World",Column = 2})
local survivorColor = Color3.fromRGB(0,255,0)
local killerColor = Color3.fromRGB(255,0,0)
local playerESPEnabled = false
local playerConns = {}
local espToggle

local ESP_DEBUG = false

-- === Helpers ===
local function dbg(...)
    if ESP_DEBUG then
        --print("[ESP-DEBUG]", ...)
    end
end

local function clearHighlight(model)
    if not model then return end
    local h = model:FindFirstChildOfClass("Highlight")
    if h then h:Destroy() end

    local head = model:FindFirstChild("Head")
    if head then
        local t = head:FindFirstChild("VD_TagGui")
        if t then pcall(function() t:Destroy() end) end
    end
end

local function ensureHighlight(model, col)
    if not model then return end
    local h = model:FindFirstChildOfClass("Highlight")
    if not h then
        h = Instance.new("Highlight")
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.FillTransparency = 0.7
        h.OutlineTransparency = 0
        h.Parent = model
        pcall(function() h.Adornee = model end)
    end
    h.FillColor = col
    h.OutlineColor = col
end

local function makeBillboard(txt, col)
    local bb = Instance.new("BillboardGui")
    bb.Name = "VD_TagGui"
    bb.Size = UDim2.new(0,200,0,50)
    bb.StudsOffset = Vector3.new(0,2.5,0)
    bb.AlwaysOnTop = true

    local tl = Instance.new("TextLabel")
    tl.Name = "Label"
    tl.Size = UDim2.new(1,0,1,0)
    tl.BackgroundTransparency = 1
    tl.Text = txt
    tl.TextColor3 = col
    tl.TextStrokeTransparency = 0.2
    tl.TextScaled = true
    tl.Parent = bb

    return bb
end

local KILLER_TOOLS = {
    knife = true, katana = true, sword = true, gun = true, crowbar = true, axe = true, hammer = true, machete = true
}

local function getRole(p)
    if not p or p == LP then return "Survivor" end
    local c = p.Character

    if p.Team and p.Team.Name and string.find(string.lower(p.Team.Name), "kill") then
        dbg(p.Name, "-> Killer (team)")
        return "Killer"
    end

    local attrRole = p:GetAttribute("Role") or p:GetAttribute("IsKiller")
    if attrRole and (tostring(attrRole) == "Killer" or tostring(attrRole) == "true" or tostring(attrRole) == "1") then
        dbg(p.Name, "-> Killer (attribute)", attrRole)
        return "Killer"
    end
    local isKVal = p:FindFirstChild("IsKiller")
    if isKVal and (isKVal.Value == true or tostring(isKVal.Value) == "Killer") then
        dbg(p.Name, "-> Killer (BoolValue on player)")
        return "Killer"
    end
    if c and c:FindFirstChild("Killer") then
        dbg(p.Name, "-> Killer (character has Killer child)")
        return "Killer"
    end

    local killersFolder = ReplicatedStorage:FindFirstChild("Killers") or ReplicatedStorage:FindFirstChild("Killer")
    if killersFolder then
        if killersFolder:FindFirstChild(p.Name) then
            dbg(p.Name, "-> Killer (killersFolder contains child named)")
            return "Killer"
        end

        for _,child in ipairs(killersFolder:GetChildren()) do
            if child:IsA("ObjectValue") and child.Value == p then
                dbg(p.Name, "-> Killer (ObjectValue in killersFolder)", child)
                return "Killer"
            end
            if child:IsA("StringValue") and child.Value == p.Name then
                dbg(p.Name, "-> Killer (StringValue in killersFolder)", child)
                return "Killer"
            end
            local model = child:FindFirstChild("Model")
            if model and p.Character and model == p.Character then
                dbg(p.Name, "-> Killer (Model match in killersFolder.Killer.Model)")
                return "Killer"
            end
        end
    end

    if c then
        local function checkTools(container)
            if not container then return false end
            for _,obj in ipairs(container:GetChildren()) do
                if obj:IsA("Tool") then
                    local nm = string.lower(obj.Name)
                    for toolName, _ in pairs(KILLER_TOOLS) do
                        if nm:find(toolName, 1, true) then
                            dbg(p.Name, "-> Killer (tool heuristic)", obj.Name)
                            return true
                        end
                    end
                end
            end
            return false
        end

        if checkTools(c) or checkTools(p:FindFirstChildOfClass("Backpack")) then
            return "Killer"
        end
    end

    return "Survivor"
end

local function applyPlayerESP(p)
    if not p or p == LP then return end
    local c = p.Character
    if not c or not c:FindFirstChild("HumanoidRootPart") then
        if p.Character then clearHighlight(p.Character) end
        return
    end

    local role = getRole(p)
    local col = (role == "Killer") and killerColor or survivorColor

    if playerESPEnabled then
        if c:IsDescendantOf(Workspace) then
            ensureHighlight(c, col)
        end

        local head = c:FindFirstChild("Head")
        if head then
            local tag = head:FindFirstChild("VD_TagGui")
            if not tag then
                tag = makeBillboard(p.Name, col)
                tag.Name = "VD_TagGui"
                tag.Parent = head
            end
            local l = tag:FindFirstChild("Label")
            if l then
                l.Text = p.Name .. ((role == "Killer") and " [KILLER]" or "")
                l.TextColor3 = col
            end
        end
    else
        clearHighlight(c)
    end
end

local function connectPlayerEvents(p)
    if not p then return end
    if playerConns[p] then
        for _,cn in ipairs(playerConns[p]) do cn:Disconnect() end
    end
    playerConns[p] = {}

    table.insert(playerConns[p], p.CharacterAdded:Connect(function(char)
        task.delay(0.12, function() applyPlayerESP(p) end)
        char.ChildAdded:Connect(function(ch)
            if ch:IsA("Tool") then task.delay(0.08, function() applyPlayerESP(p) end) end
        end)
        char.ChildRemoved:Connect(function(ch)
            if ch:IsA("Tool") then task.delay(0.08, function() applyPlayerESP(p) end) end
        end)
    end))

    table.insert(playerConns[p], p:GetAttributeChangedSignal("Role"):Connect(function() applyPlayerESP(p) end))
    table.insert(playerConns[p], p:GetAttributeChangedSignal("IsKiller"):Connect(function() applyPlayerESP(p) end))

    local ok, bp = pcall(function() return p:FindFirstChildOfClass("Backpack") end)
    if bp then
        table.insert(playerConns[p], bp.ChildAdded:Connect(function() task.delay(0.05, function() applyPlayerESP(p) end) end))
        table.insert(playerConns[p], bp.ChildRemoved:Connect(function() task.delay(0.05, function() applyPlayerESP(p) end) end))
    end

    applyPlayerESP(p)
end

local function disconnectPlayerEvents(p)
    if playerConns[p] then
        for _,cn in ipairs(playerConns[p]) do
            pcall(function() cn:Disconnect() end)
        end
    end
    playerConns[p] = nil
    if p.Character then clearHighlight(p.Character) end
end

local function connectKillersFolderListeners()
    local f = ReplicatedStorage:FindFirstChild("Killers") or ReplicatedStorage:FindFirstChild("Killer")
    if not f then return end
    
    if f:GetAttribute("__esp_listening") then return end
    f:SetAttribute("__esp_listening", true)
    
    local function refreshAll()
        for _,pl in ipairs(Players:GetPlayers()) do applyPlayerESP(pl) end
    end

    f.ChildAdded:Connect(function() task.delay(0.1, refreshAll) end)
    f.ChildRemoved:Connect(function() task.delay(0.1, refreshAll) end)
    f.DescendantAdded:Connect(function() task.delay(0.1, refreshAll) end)
    f.DescendantRemoving:Connect(function() task.delay(0.1, refreshAll) end)
end

if MainTab and type(MainTab.createToggle) == "function" then
MainTab:createToggle({
    Name = "Player ESP",
    CurrentValue = false,
    Flag = "PlayerESP",
    Column = 2,
    Callback = function(s)
        playerESPEnabled = s
        for _,pl in ipairs(Players:GetPlayers()) do
            if pl ~= LP then
                applyPlayerESP(pl)
            end
        end
        Yv:Notify("ESP " .. (s and "Enabled" or "Disabled"), 1.5)
        print("Selected Toggle:", s)
    end})
end

for _,p in ipairs(Players:GetPlayers()) do
    if p ~= LP then connectPlayerEvents(p) end
end
Players.PlayerAdded:Connect(function(p)
    if p ~= LP then connectPlayerEvents(p) end
end)
Players.PlayerRemoving:Connect(function(p)
    if p ~= LP then disconnectPlayerEvents(p) end
end)

ReplicatedStorage.ChildAdded:Connect(function(child)
    if child.Name == "Killers" or child.Name == "Killer" then
        connectKillersFolderListeners()
        for _,pl in ipairs(Players:GetPlayers()) do applyPlayerESP(pl) end
    end
end)
connectKillersFolderListeners()

task.spawn(function()
    while task.wait(2) do
        if playerESPEnabled then
            for _,pl in ipairs(Players:GetPlayers()) do
                if pl ~= LP then applyPlayerESP(pl) end
            end
        end
    end
end)

local function dumpKillersFolder()
    local f = ReplicatedStorage:FindFirstChild("Killers") or ReplicatedStorage:FindFirstChild("Killer")
    if not f then
        --print("No Killers folder in ReplicatedStorage")
        return
    end
    --print("=== Killers folder contents ===")
    for _,c in ipairs(f:GetChildren()) do
        --print("-", c.Name, c.ClassName)
        for _,d in ipairs(c:GetChildren()) do
            --print("  >", d.Name, d.ClassName, (d:IsA("ObjectValue") and tostring(d.Value) or (d:IsA("StringValue") and d.Value or "")))
        end
    end
    --print("=== End dump ===")
end

_G.ESP_DEBUG = ESP_DEBUG
_G.ESP_DUMP_KILLERS = dumpKillersFolder
--print("[ESP] Enhanced ESP loaded. Debug:", ESP_DEBUG, "Use _G.ESP_DEBUG=true to enable debug prints. Run _G.ESP_DUMP_KILLERS() to inspect ReplicatedStorage.Killers.")

-- World Esp
MainTab:createLine({ Orientation = "Horizontal", Color = Color3.fromRGB(80, 80, 80), Thickness = 1, Length = 1, Column = 2})
MainTab:createLabel({Text = "World Esp.", TextSize = 14, Column = 2})
local worldColors = {
    Generator = Color3.fromRGB(0,170,255),
    Hook      = Color3.fromRGB(255,0,0),
    Gate      = Color3.fromRGB(255,225,0),
    Window    = Color3.fromRGB(255,255,255),
    Palletwrong = Color3.fromRGB(255,140,0)
}
local worldEnabled = {
    Generator=false,
    Hook=false,
    Gate=false,
    Window=false,
    Palletwrong=false
}
local validCats = {
    Generator=true,
    Hook=true,
    Gate=true,
    Window=true,
    Palletwrong=true
}
local worldReg = {
    Generator={},
    Hook={},
    Gate={},
    Window={},
    Palletwrong={}
}
local mapAdd, mapRem = {}, {}
local palletState = setmetatable({}, {__mode="k"})
local windowState = setmetatable({}, {__mode="k"})

-- === HELPER FUNCTION ===
local function alive(x) return x and x.Parent end
local function clamp(v,min,max) return (v<min and min) or (v>max and max) or v end
local function validPart(p) return p and p:IsA("BasePart") end
local function firstBasePart(m) for _,v in ipairs(m:GetDescendants()) do if v:IsA("BasePart") then return v end end end

local function labelForPallet(model)
    local st=palletState[model] or "UP"
    if st=="DOWN" then return "Pallet (down)" end
    if st=="DEST" then return "Pallet (destroyed)" end
    if st=="SLIDE" then return "Pallet (slide)" end
    return "Pallet"
end
local function labelForWindow(model)
    local st=windowState[model] or "READY"
    return st=="BUSY" and "Window (busy)" or "Window"
end

local function pickRep(model, cat)
    if not (model and alive(model)) then return nil end
    if cat == "Generator" then
        local hb = model:FindFirstChild("HitBox", true)
        if validPart(hb) then return hb end
    elseif cat == "Palletwrong" then
        for _,name in ipairs({"HumanoidRootPart","PrimaryPartPallet","Primary1","Primary2"}) do
            local part = model:FindFirstChild(name,true)
            if validPart(part) then return part end
        end
    end
    return firstBasePart(model)
end

local function genLabelData(model)
    local pct = tonumber(model:GetAttribute("RepairProgress")) or 0
    if pct<=1.001 then pct = pct*100 end
    pct = clamp(pct,0,100)
    local repairers = tonumber(model:GetAttribute("PlayersRepairingCount")) or 0
    local paused = (model:GetAttribute("ProgressPaused")==true)
    local kickcount = tonumber(model:GetAttribute("kickcount")) or 0
    local abyss50 = (model:GetAttribute("Abyss50Triggered")==true)

    local parts = {"Gen "..tostring(math.floor(pct+0.5)).."%"}
    if repairers>0 then parts[#parts+1]="("..repairers.."p)" end
    if paused then parts[#parts+1]="⏸" end
    if abyss50 then parts[#parts+1]="⚠" end
    if kickcount and kickcount>0 then parts[#parts+1]="K:"..kickcount end

    local text = table.concat(parts," ")
    local hue = clamp((pct/100)*0.33,0,0.33)
    local labelColor = Color3.fromHSV(hue,1,1)
    return text, labelColor
end

-- === ESP BUAT OBJECT ===
local function makeBillboard(txt,col)
    local bb = Instance.new("BillboardGui")
    bb.Size = UDim2.new(0,200,0,50)
    bb.AlwaysOnTop = true
    bb.LightInfluence = 0
    bb.MaxDistance = 150
    local lbl = Instance.new("TextLabel", bb)
    lbl.Name="Label"
    lbl.Size = UDim2.new(1,0,1,0)
    lbl.BackgroundTransparency = 1
    lbl.TextStrokeTransparency = 0.5
    lbl.TextColor3 = col
    lbl.Text = txt
    lbl.Font = Enum.Font.SourceSansBold
    lbl.TextScaled = true
    return bb
end

local function ensureBoxESP(part,tagName,col)
    if not part or part:FindFirstChild(tagName) then return end
    local box = Instance.new("BoxHandleAdornment")
    box.Name = tagName
    box.Adornee = part
    box.AlwaysOnTop = true
    box.ZIndex = 10
    box.Size = part.Size + Vector3.new(0.05,0.05,0.05)
    box.Color3 = col
    box.Transparency = 0.6
    box.Parent = part
end

local function clearChild(part, name)
    if part and part:FindFirstChild(name) then
        part:FindFirstChild(name):Destroy()
    end
end

local function ensureWorldEntry(cat, model)
    if not alive(model) or worldReg[cat][model] then return end
    local rep = pickRep(model, cat)
    if not validPart(rep) then return end
    worldReg[cat][model] = {part = rep}
end
local function removeWorldEntry(cat, model)
    local e = worldReg[cat][model]
    if not e then return end
    clearChild(e.part,"VD_"..cat)
    clearChild(e.part,"VD_Text_"..cat)
    worldReg[cat][model] = nil
end

local function registerFromDescendant(obj)
    if obj:IsA("Model") and validCats[obj.Name] then
        ensureWorldEntry(obj.Name, obj)
    elseif obj:IsA("BasePart") and obj.Parent and obj.Parent:IsA("Model") and validCats[obj.Parent.Name] then
        ensureWorldEntry(obj.Parent.Name, obj.Parent)
    end
end
local function unregisterFromDescendant(obj)
    if obj:IsA("Model") and validCats[obj.Name] then
        removeWorldEntry(obj.Name,obj)
    elseif obj:IsA("BasePart") and obj.Parent and obj.Parent:IsA("Model") and validCats[obj.Parent.Name] then
        local e = worldReg[obj.Parent.Name][obj.Parent]
        if e and e.part == obj then removeWorldEntry(obj.Parent.Name,obj.Parent) end
    end
end

local function attachRoot(root)
    if not root or mapAdd[root] then return end
    mapAdd[root] = root.DescendantAdded:Connect(registerFromDescendant)
    mapRem[root] = root.DescendantRemoving:Connect(unregisterFromDescendant)
    for _,d in ipairs(root:GetDescendants()) do registerFromDescendant(d) end
end
local function refreshRoots()
    for _,cn in pairs(mapAdd) do if cn then cn:Disconnect() end end
    for _,cn in pairs(mapRem) do if cn then cn:Disconnect() end end
    mapAdd, mapRem = {}, {}
    local r1 = workspace:FindFirstChild("Map")
    local r2 = workspace:FindFirstChild("Map1")
    if r1 then attachRoot(r1) end
    if r2 then attachRoot(r2) end
end
refreshRoots()
workspace.ChildAdded:Connect(function(ch) if ch.Name=="Map" or ch.Name=="Map1" then attachRoot(ch) end end)

-- === LOOP ESP ===
local worldLoopThread=nil
local function anyWorldEnabled() for _,v in pairs(worldEnabled) do if v then return true end end return false end
local function startWorldLoop()
    if worldLoopThread then return end
    worldLoopThread = task.spawn(function()
        while anyWorldEnabled() do
            for cat,models in pairs(worldReg) do
                if worldEnabled[cat] then
                    local col,tagName,textName = worldColors[cat], "VD_"..cat, "VD_Text_"..cat
                    for model,entry in pairs(models) do
                        local part = entry.part
                        if model and alive(model) then
                            if not validPart(part) or (model:IsA("Model") and not part:IsDescendantOf(model)) then
                                entry.part = pickRep(model,cat); part=entry.part
                            end
                            if validPart(part) then
                                ensureBoxESP(part,tagName,col)
                                local bb = part:FindFirstChild(textName)
                                if not bb then
                                    local newbb = makeBillboard(cat,col)
                                    newbb.Name = textName
                                    newbb.Parent = part
                                    bb=newbb
                                end
                                local lbl=bb:FindFirstChild("Label")
                                if lbl then
                                    if cat=="Generator" then local txt,lblCol=genLabelData(model) lbl.Text=txt lbl.TextColor3=lblCol
                                    elseif cat=="Palletwrong" then lbl.Text=labelForPallet(model) lbl.TextColor3=col
                                    elseif cat=="Window" then lbl.Text=labelForWindow(model) lbl.TextColor3=col
                                    else lbl.Text=cat lbl.TextColor3=col end
                                end
                            end
                        else removeWorldEntry(cat,model) end
                    end
                end
            end
            task.wait(0.25)
        end
        worldLoopThread=nil
    end)
end

local function setWorldToggle(cat,state)
    worldEnabled[cat]=state
    if state then
        if not worldLoopThread then startWorldLoop() end
    else
        for _,entry in pairs(worldReg[cat]) do
            if entry and entry.part then
                clearChild(entry.part,"VD_"..cat)
                clearChild(entry.part,"VD_Text_"..cat)
            end
        end
    end
end

-- === GUI TOGGLE ===
MainTab:createToggle({Name = "ESP Generators", CurrentValue = false, Flag = "ESPGens", Column = 2, Callback = function(state)setWorldToggle("Generator", state)end})
MainTab:createToggle({Name = "ESP Hooks", CurrentValue = false, Flag = "ESPHooks", Column = 2, Callback = function(state)setWorldToggle("Hook", state) end})
MainTab:createToggle({Name = "ESP Gates", CurrentValue = false, Flag = "ESPGates", Column = 2, Callback = function(state)setWorldToggle("Gate", state) end})
MainTab:createToggle({Name = "ESP Windows", CurrentValue = false,Flag = "ESPWindows", Column = 2, Callback = function(state)setWorldToggle("Window", state) end})
MainTab:createToggle({Name = "ESP Pallets", CurrentValue = false, Flag = "ESPPallets", Column = 2, Callback = function(state)setWorldToggle("Palletwrong", state) end})

-- Killer Controler
KTab:createSection({Name = "Jason",Column = 1})
local BasicAttack = ReplicatedStorage.Remotes.Attacks.BasicAttack

--// Variables
local attacking = false

local function setAutoAttack(s)
	attacking = s
	print("Auto Attack:", attacking)

	if attacking then
	    Yv:Notify("Auto Attack", "Auto Attack Enabled", 1.5)
		task.spawn(function()
			while attacking do
				BasicAttack:FireServer()
				task.wait(5)
			end
		end)
	else
		Yv:Notify("Auto Attack", "Auto Attack Disabled", 1.5)
	end
end

--// Toggle
KTab:createToggle({
	Name = "Auto Basic Attack",
	CurrentValue = false,
	Flag = "AutoBasicAttack",
	Column = 1,
	Callback = function(s)
		setAutoAttack(s)
	end})

--// Keybind
KTab:createKeybind({
    Name = "Auto Attack Keybind",
    Default = Enum.KeyCode.F,
    Column = 1,
    Callback = function()
        setAutoAttack(not attacking)
        if library and library.flags then
            library.flags["AutoBasicAttack"] = attacking
        end
    end})

KTab:createLine({Orientation = "Horizontal", Color = Color3.fromRGB(80, 80, 80), Thickness = 1, Length = 1, Column = 1})
local Pursuit = ReplicatedStorage.Remotes.Killers.Jason.Pursuit
local pursuit = false
local function setPursuit(s)
	pursuit = s
	print("Infinite Pursuit:", pursuit)

	if pursuit then
	    Pursuit:FireServer(true)
	    Yv:Notify("Infinite Pursuit", "Infinite Pursuit Enabled", 1.5)
		task.spawn(function()
			while pursuit do
				Pursuit:FireServer(true)
				task.wait(60)
			end
		end)
	else
	    Pursuit:FireServer(false)
	    Yv:Notify("Infinite Pursuit", "Infinite Pursuit Disabled", 1.5)
	end
end

--// Toggle UI
KTab:createToggle({
	Name = "Infinite Skill Pursuit",
	CurrentValue = false,
	Flag = "InfinitePursuit",
	Column = 1,
	Callback = function(s)
		setPursuit(s)
	end})

KTab:createKeybind({
    Name = "Infinite Pursuit Keybind",
    Default = Enum.KeyCode.E,
    Column = 1,
    Callback = function()
        setPursuit(not pursuit)
        if library and library.flags then
            library.flags["InfinitePursuit"] = pursuit
        end
    end})

KTab:createLine({Orientation = "Horizontal", Color = Color3.fromRGB(80, 80, 80), Thickness = 1, Length = 1, Column = 1})
local LakeMist = ReplicatedStorage.Remotes.Killers.Jason.LakeMist
local lakeMistEnabled = false
local function setLakeMist(s)
	lakeMist = s
	print("Infinite LakeMist:", lakeMist)

	if lakeMist then
	    Yv:Notify("Infinite LakeMist", "Infinite LakeMist Enabled", 1.5)
		LakeMist:FireServer(true)
		task.spawn(function()
			while lakeMist do
				LakeMist:FireServer(true)
				task.wait(60)
			end
		end)
	else
		LakeMist:FireServer(false)
		Yv:Notify("Infinite LakeMist", "Infinite LakeMist Disabled", 1.5)
	end
end

--// Toggle UI
KTab:createToggle({
	Name = "Infinite Skill LakeMist",
	CurrentValue = false,
	Flag = "InfiniteLakeMist",
	Column = 1,
	Callback = function(s)
		setLakeMist(s)
	end})

KTab:createKeybind({
    Name = "Infinite LakeMist Keybind",
    Default = Enum.KeyCode.Q,
    Column = 1,
    Callback = function()
        setLakeMist(not lakeMist)
        if library and library.flags then
            library.flags["InfiniteLakeMist"] = lakeMist
        end
    end})

-- Masked 
KTab:createSection({Name = "Masked",Column = 2})
local Activatepower = ReplicatedStorage.Remotes.Killers.Masked:WaitForChild("Activatepower")
--// Variables
local powers = {
	"Alex",
	"Brandon",
	"Rabbit",
	"Cobra",
	"Richter",
	"Tony"
}

local activePowers = {}

local function setActivatePower(name, state)
	activePowers[name] = state

	if state then
		Yv:Notify(name .. " Power", "Enabled ⚡", 1.5)
		Activatepower:FireServer(name)

		task.spawn(function()
			while activePowers[name] do
				Activatepower:FireServer(name)
				task.wait(120)
			end
		end)
	else
		pcall(function()
			Activatepower:FireServer(false)
		end)
		Yv:Notify(name .. " Power", "Disabled ❌", 1.5)
	end
end

for _, powerName in ipairs(powers) do
	KTab:createToggle({
		Name = powerName,
		CurrentValue = false,
		Flag = "Power_" .. powerName,
		Column = 2,
		Callback = function(state)
			setActivatePower(powerName, state)
		end
	})
end

ZTab:createSection({Name = "UI",Column = 1})
ZTab:createKeybind({
    Name = "Visible UI",
    Default = Enum.KeyCode.T,
    Column = 1,
    Callback = function()
        Yv:ToggleUI()
    end
})

ZTab:createSection({Name = "UI",Column = 2})
ZTab:createColorPicker({
    Name = "Accent",
    Default = Color3.fromRGB(255,0,0),
    Callback = function(c) print("picked:", c) end,
    Column = 2
})

ZTab:createLine({Orientation = "Horizontal",Color = Color3.fromRGB(80, 80, 80),Thickness = 1,Length = 1,Column = 2})
-- 🎨 UI Theme
local ThemeNames = {}
for name in pairs(Yv.Themes or {}) do
    table.insert(ThemeNames, name)
end

ZTab:createDropdown({
    Name = "Select Theme",
    Options = ThemeNames,
    CurrentOption = "Dark Red",
    Column = 2,
    Callback = function(selectedThemeName)
        if selectedThemeName then
            Yv:ApplyTheme(selectedThemeName)
            if Yv.Notify then
                Yv:Notify("Theme Changed", "UI theme set to: " .. selectedThemeName, 1.5)
            else
                notify("Theme Changed", "UI theme set to: " .. selectedThemeName, 1.5)
            end
        end
    end
})
