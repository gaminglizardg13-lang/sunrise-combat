-- SUNRISE: paste this SAME code into: (1) Script in ServerScriptService, (2) LocalScript in StarterPlayerScripts
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local RS           = game:GetService("ReplicatedStorage")

------------------------------------------------------------
-- SERVER SIDE
------------------------------------------------------------
if RunService:IsServer() then
	-- Put YOUR UserId here (profile URL number). Group-owned games: CreatorId is the group ID.
	local ADMINS = { [game.CreatorId] = true, [123456789] = true }

	local MAX_SPEED = 120
	local MAX_RISE  = 120

	local function isAdmin(plr)
		return RunService:IsStudio() or ADMINS[plr.UserId] == true
	end

	local function markAdmin(plr)
		plr:SetAttribute("NeonAdmin", isAdmin(plr))
	end
	Players.PlayerAdded:Connect(markAdmin)
	for _, p in ipairs(Players:GetPlayers()) do markAdmin(p) end

	local remote = Instance.new("RemoteEvent")
	remote.Name = "NeonAdminAction"
	remote.Parent = RS

	local lastUse = {}
	local cages = {}

	local function getRoot(plr)
		local c = plr.Character
		return c and c:FindFirstChild("HumanoidRootPart"), c and c:FindFirstChildOfClass("Humanoid")
	end

	local function removeCage(targetId)
		local folder = cages[targetId]
		if folder then
			folder:Destroy()
			cages[targetId] = nil
		end
	end

	remote.OnServerEvent:Connect(function(plr, action, targetId)
		if not isAdmin(plr) then return end
		if typeof(action) ~= "string" or typeof(targetId) ~= "number" then return end
		if os.clock() - (lastUse[plr] or 0) < 0.2 then return end
		lastUse[plr] = os.clock()

		local target = Players:GetPlayerByUserId(targetId)
		if not target then return end
		local root, hum = getRoot(target)
		if not (root and hum) then return end

		if action == "Kill" then
			hum.Health = 0
		elseif action == "Fling" then
			hum.Sit = false
			root:SetNetworkOwner(nil)
			local dir = Vector3.new(math.random(-100, 100) / 100, 0.8, math.random(-100, 100) / 100).Unit
			root.AssemblyLinearVelocity = dir * 400
			root.AssemblyAngularVelocity = Vector3.new(30, 30, 30)
			task.delay(1.5, function()
				if root.Parent then pcall(function() root:SetNetworkOwnershipAuto() end) end
			end)
		elseif action == "Bring" then
			local myRoot = getRoot(plr)
			if myRoot then root.CFrame = myRoot.CFrame * CFrame.new(0, 0, -4) end
		elseif action == "Freeze" then
			hum.WalkSpeed = 0
			hum.JumpPower = 0
			hum.UseJumpPower = true
		elseif action == "Unfreeze" then
			hum.WalkSpeed = 16
			hum.JumpPower = 50
		elseif action == "Heal" then
			hum.Health = hum.MaxHealth
		elseif action == "GodMode" then
			hum.MaxHealth = 1e6
			hum.Health = 1e6
		elseif action == "Cage" then
			removeCage(targetId)
			local folder = Instance.new("Folder")
			folder.Name = "Cage_" .. targetId
			folder.Parent = workspace
			local center = root.Position
			local size = Vector3.new(6, 8, 6)
			local offsets = {
				{Vector3.new(0, 0, size.Z/2), Vector3.new(size.X, size.Y, 0.5)},
				{Vector3.new(0, 0, -size.Z/2), Vector3.new(size.X, size.Y, 0.5)},
				{Vector3.new(size.X/2, 0, 0), Vector3.new(0.5, size.Y, size.Z)},
				{Vector3.new(-size.X/2, 0, 0), Vector3.new(0.5, size.Y, size.Z)},
				{Vector3.new(0, size.Y/2, 0), Vector3.new(size.X, 0.5, size.Z)},
				{Vector3.new(0, -size.Y/2 + 1, 0), Vector3.new(size.X, 0.5, size.Z)},
			}
			for _, data in ipairs(offsets) do
				local part = Instance.new("Part")
				part.Anchored = true
				part.CanCollide = true
				part.Transparency = 0.5
				part.Material = Enum.Material.ForceField
				part.Color = Color3.fromRGB(255, 80, 80)
				part.Size = data[2]
				part.Position = center + data[1]
				part.Parent = folder
			end
			cages[targetId] = folder
		elseif action == "Uncage" then
			removeCage(targetId)
		end
	end)

	local last = {}
	RunService.Heartbeat:Connect(function(dt)
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr:GetAttribute("NeonAdmin") then continue end
			local root, hum = getRoot(plr)
			if not (root and hum) or hum.Health <= 0 then last[plr] = nil continue end
			local prev = last[plr]
			if prev and dt > 0 then
				local delta = root.Position - prev.pos
				local horizontal = Vector3.new(delta.X, 0, delta.Z).Magnitude / dt
				local rise = delta.Y / dt
				if (horizontal > MAX_SPEED or rise > MAX_RISE) and not hum.Sit then
					root.CFrame = CFrame.new(prev.pos)
					root.AssemblyLinearVelocity = Vector3.zero
					continue
				end
			end
			last[plr] = { pos = root.Position }
		end
	end)

	Players.PlayerRemoving:Connect(function(p)
		lastUse[p] = nil
		last[p] = nil
		removeCage(p.UserId)
	end)
	return
end

------------------------------------------------------------
-- CLIENT SIDE
------------------------------------------------------------
local UIS          = game:GetService("UserInputService")
local Lighting     = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Teams        = game:GetService("Teams")
local StarterPack  = game:GetService("StarterPack")
local MarketplaceService = game:GetService("MarketplaceService")
local TeleportService = game:GetService("TeleportService")
local TextChatService = game:GetService("TextChatService")

local lp    = Players.LocalPlayer
local cam   = workspace.CurrentCamera
local mouse = lp:GetMouse()

------------------------------------------------------------
-- Data
------------------------------------------------------------
local conns = {}
local function connect(signal, fn)
	local c = signal:Connect(fn)
	table.insert(conns, c)
	return c
end

local State = {
	Freecam = false, Xray = false, ShowPing = true, WalkOnWater = false,
	Sprint = false, SilentAim = false, AutoClicker = false, AutoReconnect = false,
	Aimbot = false, AimAlways = false, Lock = false, TeamCheck = false,
	WallCheck = false, TargetNPCs = true, ShowFOV = true, AimDebug = false,
	Prediction = false,
	ESP = false, Names = true, Tracers = false, Crosshair = false,
	Fullbright = false, CamFOV = false, ChatESP = false, HealthBar = true,
	FadeESP = false, SkeletonESP = false, BoxESP = false, FriendsOnly = false,
	NightVision = false, NoCamShake = false, FPSGraph = false, ServerStats = false,
	Fly = false, Speed = false, JumpBoost = false, InfJump = false,
	Noclip = false, ClickTP = false, LowGravity = false, AntiFall = false,
	Bunnyhop = false, ShowVelocity = false,
	Rainbow = true, Particles = true, ShowFPS = true, MuteSounds = false,
}

local Settings = {
	AimFOV = 200, Smooth = 0.6, LockRange = 1000, AimPart = "Head",
	ESPRange = 1500,
	FlySpeed = 70, WalkSpeed = 60, JumpPower = 100, CamFOV = 90,
	BGSpeed = 1,
	ClickerCPS = 10, Gravity = 196.2, NoclipSpeed = 60, SuperJumpPower = 200,
	TimeOfDay = 14, FogDensity = 0,
	HitboxFOV = 200, CrosshairSize = 16, HUDOpacity = 1, MenuScale = 1,
	CrosshairStyle = "Cross",
}

local NONE = Enum.KeyCode.Unknown
local Binds = {
	Menu = Enum.KeyCode.RightShift,
	ESP = Enum.KeyCode.H,
	Tracers = Enum.KeyCode.T,
	Fullbright = Enum.KeyCode.L,
	Aimbot = Enum.KeyCode.J,
	AimHold = Enum.UserInputType.MouseButton2,
	Lock = Enum.KeyCode.R,
	Fly = Enum.KeyCode.F,
	Speed = Enum.KeyCode.X,
	InfJump = Enum.KeyCode.K,
	Noclip = Enum.KeyCode.N,
	Freecam = Enum.KeyCode.P,
	Xray = Enum.KeyCode.Y,
	SprintKey = Enum.KeyCode.LeftShift,
	Panic = Enum.KeyCode.Backspace,
	SuperJump = Enum.KeyCode.G,
}
local ToggleBinds = { "ESP", "Tracers", "Fullbright", "Aimbot", "Lock", "Fly", "Speed", "InfJump", "Noclip", "Freecam", "Xray" }

local C = {
	bg = Color3.fromRGB(30, 18, 40),
	row = Color3.fromRGB(58, 30, 48),
	accent = Color3.fromRGB(255, 140, 90),
	accent2 = Color3.fromRGB(255, 196, 120),
	pink = Color3.fromRGB(230, 110, 150),
	on = Color3.fromRGB(255, 170, 90),
	off = Color3.fromRGB(90, 55, 70),
	text = Color3.fromRGB(255, 240, 230),
}

local function matches(input, bind)
	if not bind or bind == NONE then return false end
	if bind.EnumType == Enum.KeyCode then
		return input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == bind
	end
	return input.UserInputType == bind
end

local function isBindDown(bind)
	if not bind or bind == NONE then return false end
	if bind.EnumType == Enum.KeyCode then return UIS:IsKeyDown(bind) end
	return UIS:IsMouseButtonPressed(bind)
end

local function bindName(bind)
	if bind == NONE then return "None" end
	if bind == Enum.UserInputType.MouseButton2 then return "RMB" end
	if bind == Enum.UserInputType.MouseButton3 then return "MMB" end
	return bind.Name
end

------------------------------------------------------------
-- GUI base (bigger window, more breathing room)
------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "SunriseMenu"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.Parent = lp:WaitForChild("PlayerGui")

local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.fromOffset(760, 520)
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.Position = UDim2.fromScale(0.5, 0.5)
main.BackgroundColor3 = C.bg
main.BorderSizePixel = 0
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 14)

local mainScale = Instance.new("UIScale", main)

local stroke = Instance.new("UIStroke")
stroke.Thickness = 2.5
stroke.Color = Color3.new(1, 1, 1)
stroke.Parent = main
local strokeGrad = Instance.new("UIGradient", stroke)
local neonSeq = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 170, 90)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(230, 110, 150)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 170, 90)),
})
local rainbowSeq = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 80)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 190, 110)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(230, 130, 180)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(150, 110, 210)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(100, 150, 220)),
})
strokeGrad.Color = rainbowSeq

local bg = Instance.new("Frame")
bg.Name = "Background"
bg.Size = UDim2.fromScale(1, 1)
bg.BackgroundColor3 = Color3.new(1, 1, 1)
bg.BorderSizePixel = 0
bg.ClipsDescendants = true
bg.Parent = main
Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 14)
local bgGrad = Instance.new("UIGradient", bg)
bgGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 90, 150)),
	ColorSequenceKeypoint.new(0.3, Color3.fromRGB(160, 120, 180)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(255, 150, 120)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 200, 130)),
})

local sun = Instance.new("Frame")
sun.AnchorPoint = Vector2.new(0.5, 0.5)
sun.Position = UDim2.fromScale(0.5, 1.05)
sun.Size = UDim2.fromOffset(300, 300)
sun.BackgroundColor3 = Color3.fromRGB(255, 235, 200)
sun.BackgroundTransparency = 0.55
sun.BorderSizePixel = 0
sun.ZIndex = 0
sun.Parent = bg
Instance.new("UICorner", sun).CornerRadius = UDim.new(1, 0)

local rng = Random.new()
local particles = {}
for i = 1, 18 do
	local size = rng:NextInteger(3, 8)
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(size, size)
	f.BackgroundColor3 = (i % 2 == 0) and Color3.fromRGB(255, 210, 150) or Color3.fromRGB(255, 160, 190)
	f.BackgroundTransparency = rng:NextNumber(0.4, 0.8)
	f.BorderSizePixel = 0
	f.Parent = bg
	Instance.new("UICorner", f).CornerRadius = UDim.new(1, 0)
	table.insert(particles, {
		f = f, x = rng:NextNumber(), y = rng:NextNumber(),
		vy = rng:NextNumber(0.03, 0.12), phase = rng:NextNumber(0, 6.28),
	})
end

local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 46)
titleBar.BackgroundColor3 = Color3.fromRGB(8, 4, 20)
titleBar.BackgroundTransparency = 0.35
titleBar.BorderSizePixel = 0
titleBar.Parent = main
Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 14)

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -70, 1, 0)
titleLabel.Position = UDim2.fromOffset(18, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "SUNRISE"
titleLabel.Font = Enum.Font.GothamBlack
titleLabel.TextSize = 19
titleLabel.TextColor3 = Color3.new(1, 1, 1)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = titleBar
local titleGrad = Instance.new("UIGradient", titleLabel)
titleGrad.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 190, 120)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 140, 170)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 140, 220)),
})

task.spawn(function()
	while titleLabel.Parent do
		if main.Visible then
			local t = os.clock()
			titleLabel.Position = UDim2.fromOffset(18, math.sin(t * 2) * 2)
			titleGrad.Offset = Vector2.new(math.sin(t * 0.7) * 0.3, 0)
			titleLabel.TextTransparency = 0.05 + math.abs(math.sin(t * 1.5)) * 0.1
		end
		task.wait()
	end
end)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(32, 32)
closeBtn.Position = UDim2.new(1, -42, 0, 7)
closeBtn.BackgroundColor3 = C.pink
closeBtn.Text = "X"
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 15
closeBtn.TextColor3 = Color3.new(1, 1, 1)
closeBtn.Parent = titleBar
Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 8)
closeBtn.MouseButton1Click:Connect(function() main.Visible = false end)

local sidebar = Instance.new("Frame")
sidebar.Position = UDim2.fromOffset(12, 58)
sidebar.Size = UDim2.new(0, 160, 1, -70)
sidebar.BackgroundColor3 = Color3.fromRGB(8, 4, 20)
sidebar.BackgroundTransparency = 0.4
sidebar.BorderSizePixel = 0
sidebar.Parent = main
Instance.new("UICorner", sidebar).CornerRadius = UDim.new(0, 12)
sidebar.ClipsDescendants = true

local sbScroll = Instance.new("ScrollingFrame")
sbScroll.Size = UDim2.fromScale(1, 1)
sbScroll.BackgroundTransparency = 1
sbScroll.BorderSizePixel = 0
sbScroll.ScrollBarThickness = 3
sbScroll.CanvasSize = UDim2.new()
sbScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
sbScroll.Parent = sidebar
Instance.new("UIListLayout", sbScroll).Padding = UDim.new(0, 8)
local sbPad = Instance.new("UIPadding", sbScroll)
sbPad.PaddingTop = UDim.new(0, 10)
sbPad.PaddingLeft = UDim.new(0, 10)
sbPad.PaddingRight = UDim.new(0, 10)
sbPad.PaddingBottom = UDim.new(0, 10)

local pageHolder = Instance.new("Frame")
pageHolder.Position = UDim2.fromOffset(184, 58)
pageHolder.Size = UDim2.new(1, -196, 1, -70)
pageHolder.BackgroundTransparency = 1
pageHolder.Parent = main

local pages, tabButtons = {}, {}

local function selectTab(name)
	for n, p in pairs(pages) do p.Visible = (n == name) end
	for n, b in pairs(tabButtons) do
		b.BackgroundColor3 = (n == name) and C.accent or C.row
		b.BackgroundTransparency = (n == name) and 0 or 0.3
	end
end

local function addTab(name)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 38)
	btn.BackgroundColor3 = C.row
	btn.BackgroundTransparency = 0.3
	btn.Text = name
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 14
	btn.TextColor3 = C.text
	btn.AutoButtonColor = false
	btn.Parent = sbScroll
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 9)
	tabButtons[name] = btn

	local page = Instance.new("ScrollingFrame")
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.BorderSizePixel = 0
	page.ScrollBarThickness = 5
	page.ScrollBarImageColor3 = C.accent2
	page.CanvasSize = UDim2.new()
	page.AutomaticCanvasSize = Enum.AutomaticSize.Y
	page.Visible = false
	page.Parent = pageHolder
	local pl = Instance.new("UIListLayout", page)
	pl.Padding = UDim.new(0, 10)
	local pp = Instance.new("UIPadding", page)
	pp.PaddingRight = UDim.new(0, 10)
	pp.PaddingTop = UDim.new(0, 2)
	pp.PaddingBottom = UDim.new(0, 10)
	pages[name] = page

	btn.MouseButton1Click:Connect(function() selectTab(name) end)
	return page
end

------------------------------------------------------------
-- Widgets (taller rows, more padding, bigger text)
------------------------------------------------------------
local Refresh, OnToggle = {}, {}
local listening, dragging, windowDrag = nil, nil, nil

local function setToggle(key, v)
	State[key] = v
	if Refresh[key] then Refresh[key]() end
	if OnToggle[key] then OnToggle[key](v) end
end

local function rowBase(page, height)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, height)
	row.BackgroundColor3 = C.row
	row.BackgroundTransparency = 0.25
	row.BorderSizePixel = 0
	row.Parent = page
	Instance.new("UICorner", row).CornerRadius = UDim.new(0, 10)
	local s = Instance.new("UIStroke", row)
	s.Color = C.accent
	s.Transparency = 0.55
	s.Thickness = 1
	return row
end

local function rowLabel(row, text, rightPad)
	local lbl = Instance.new("TextLabel")
	lbl.Position = UDim2.fromOffset(16, 0)
	lbl.Size = UDim2.new(1, -rightPad - 16, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.Font = Enum.Font.GothamMedium
	lbl.TextSize = 14
	lbl.TextColor3 = C.text
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.TextWrapped = true
	lbl.Parent = row
	return lbl
end

local function addHeader(page, text)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, 24)
	l.BackgroundTransparency = 1
	l.Text = text
	l.Font = Enum.Font.GothamBlack
	l.TextSize = 13
	l.TextColor3 = C.accent2
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = page
end

local function makeBindButton(row, bindKey, rightOffset)
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, rightOffset, 0.5, 0)
	b.Size = UDim2.fromOffset(86, 28)
	b.BackgroundColor3 = Color3.fromRGB(10, 6, 28)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextColor3 = C.accent2
	b.Text = bindName(Binds[bindKey])
	b.Parent = row
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
	local s = Instance.new("UIStroke", b)
	s.Color = C.accent2
	s.Transparency = 0.5
	b.MouseButton1Click:Connect(function()
		listening = { key = bindKey, btn = b }
		b.Text = "press key..."
	end)
end

local function addToggle(page, label, key, bindKey)
	local row = rowBase(page, 44)
	rowLabel(row, label, bindKey and 170 or 86)

	local sw = Instance.new("TextButton")
	sw.AnchorPoint = Vector2.new(1, 0.5)
	sw.Position = UDim2.new(1, bindKey and -108 or -16, 0.5, 0)
	sw.Size = UDim2.fromOffset(48, 26)
	sw.Text = ""
	sw.AutoButtonColor = false
	sw.BackgroundColor3 = C.off
	sw.Parent = row
	Instance.new("UICorner", sw).CornerRadius = UDim.new(1, 0)
	local knob = Instance.new("Frame")
	knob.AnchorPoint = Vector2.new(0, 0.5)
	knob.Position = UDim2.new(0, 3, 0.5, 0)
	knob.Size = UDim2.fromOffset(20, 20)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.BorderSizePixel = 0
	knob.Parent = sw
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	Refresh[key] = function()
		local on = State[key]
		local info = TweenInfo.new(0.15)
		TweenService:Create(sw, info, { BackgroundColor3 = on and C.on or C.off }):Play()
		TweenService:Create(knob, info, {
			Position = on and UDim2.new(1, -23, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
		}):Play()
	end
	Refresh[key]()
	sw.MouseButton1Click:Connect(function() setToggle(key, not State[key]) end)

	if bindKey then makeBindButton(row, bindKey, -14) end
end

local function addKeybind(page, label, bindKey)
	local row = rowBase(page, 44)
	rowLabel(row, label, 110)
	makeBindButton(row, bindKey, -14)
end

local function addCycle(page, label, key, options)
	local row = rowBase(page, 44)
	rowLabel(row, label, 130)
	local b = Instance.new("TextButton")
	b.AnchorPoint = Vector2.new(1, 0.5)
	b.Position = UDim2.new(1, -14, 0.5, 0)
	b.Size = UDim2.fromOffset(96, 28)
	b.BackgroundColor3 = C.accent
	b.Font = Enum.Font.GothamBold
	b.TextSize = 12
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = tostring(Settings[key])
	b.Parent = row
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
	b.MouseButton1Click:Connect(function()
		local idx = table.find(options, Settings[key]) or 1
		Settings[key] = options[idx % #options + 1]
		b.Text = tostring(Settings[key])
	end)
end

local function addSlider(page, label, key, min, max, decimals)
	local row = rowBase(page, 60)
	local lbl = rowLabel(row, label, 90)
	lbl.Position = UDim2.fromOffset(16, 6)
	lbl.Size = UDim2.new(1, -106, 0, 22)

	local valLbl = Instance.new("TextLabel")
	valLbl.AnchorPoint = Vector2.new(1, 0)
	valLbl.Position = UDim2.new(1, -16, 0, 6)
	valLbl.Size = UDim2.fromOffset(76, 22)
	valLbl.BackgroundTransparency = 1
	valLbl.Font = Enum.Font.GothamBold
	valLbl.TextSize = 14
	valLbl.TextColor3 = C.accent2
	valLbl.TextXAlignment = Enum.TextXAlignment.Right
	valLbl.Parent = row

	local hit = Instance.new("TextButton")
	hit.Position = UDim2.new(0, 16, 0, 34)
	hit.Size = UDim2.new(1, -32, 0, 20)
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Parent = row

	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0, 0.5)
	bar.Position = UDim2.fromScale(0, 0.5)
	bar.Size = UDim2.new(1, 0, 0, 8)
	bar.BackgroundColor3 = Color3.fromRGB(10, 6, 28)
	bar.BorderSizePixel = 0
	bar.Parent = hit
	Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Color3.new(1, 1, 1)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)
	Instance.new("UIGradient", fill).Color = ColorSequence.new(C.accent2, C.pink)

	local knob = Instance.new("Frame")
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Size = UDim2.fromOffset(16, 16)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.BorderSizePixel = 0
	knob.Parent = bar
	Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

	local function visual()
		local a = (Settings[key] - min) / (max - min)
		fill.Size = UDim2.fromScale(a, 1)
		knob.Position = UDim2.fromScale(a, 0.5)
		valLbl.Text = tostring(Settings[key])
	end
	local function setFromX(x)
		local a = math.clamp((x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
		local mult = 10 ^ decimals
		Settings[key] = math.floor((min + (max - min) * a) * mult + 0.5) / mult
		visual()
	end
	visual()

	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = setFromX
			setFromX(input.Position.X)
		end
	end)
end

local function addButton(page, label, callback)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(1, 0, 0, 44)
	b.BackgroundColor3 = C.pink
	b.Text = label
	b.Font = Enum.Font.GothamBold
	b.TextSize = 14
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Parent = page
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 9)
	b.MouseButton1Click:Connect(callback)
end

local function addLabel(page, text)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.new(1, 0, 0, 0)
	l.AutomaticSize = Enum.AutomaticSize.Y
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.GothamMedium
	l.TextSize = 13
	l.TextColor3 = C.text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextWrapped = true
	l.Text = text
	l.Parent = page
	return l
end

------------------------------------------------------------
-- Build pages
------------------------------------------------------------
local priority  = addTab("Priority")
local combat    = addTab("Combat")
local visuals   = addTab("Visuals")
local movement  = addTab("Movement")
local social    = addTab("Social")
local emotes    = addTab("Emotes")
local qol       = addTab("QoL")
local settings  = addTab("Settings")

addHeader(priority, "VIEW & VISUAL")
addToggle(priority, "Freecam", "Freecam", "Freecam")
addToggle(priority, "X-Ray Terrain", "Xray", "Xray")
addToggle(priority, "Show Ping", "ShowPing")
addHeader(priority, "MOVEMENT")
addToggle(priority, "Walk On Water", "WalkOnWater")
addToggle(priority, "Sprint (hold key)", "Sprint")
addKeybind(priority, "Sprint Key", "SprintKey")
addHeader(priority, "COMBAT")
addToggle(priority, "Silent Aim", "SilentAim")
addHeader(priority, "UTILITY")
addToggle(priority, "Auto Clicker (Studio only)", "AutoClicker")
addSlider(priority, "Clicker CPS", "ClickerCPS", 1, 30, 0)
addButton(priority, "Server Hop", function() end)
addToggle(priority, "Auto-Reconnect on Disconnect", "AutoReconnect")
addHeader(priority, "EMERGENCY")
addKeybind(priority, "Panic Key (turn off ESP/Aimbot/Fly)", "Panic")
addButton(priority, "PANIC - Turn Off ESP/Aimbot/Fly", function()
	setToggle("ESP", false)
	setToggle("Aimbot", false)
	setToggle("Lock", false)
	setToggle("Fly", false)
	setToggle("Tracers", false)
	setToggle("Noclip", false)
end)

addHeader(combat, "AIMBOT")
addToggle(combat, "Aimbot", "Aimbot", "Aimbot")
addKeybind(combat, "Aim Hold Key", "AimHold")
addToggle(combat, "Auto Aim (no hold)", "AimAlways")
addCycle(combat, "Aim Part", "AimPart", { "Head", "Torso" })
addSlider(combat, "Aim Strength", "Smooth", 0.05, 1, 2)
addToggle(combat, "Prediction (lead moving targets)", "Prediction")
addToggle(combat, "Aim Debug Text", "AimDebug")
addHeader(combat, "TARGET LOCK (closest to you)")
addToggle(combat, "Target Lock", "Lock", "Lock")
addSlider(combat, "Lock Range", "LockRange", 50, 3000, 0)
addHeader(combat, "FILTERS")
addToggle(combat, "Team Check", "TeamCheck")
addToggle(combat, "Wall Check (visible only)", "WallCheck")
addToggle(combat, "Target NPCs / Dummies", "TargetNPCs")
addHeader(combat, "FOV")
addToggle(combat, "Show FOV Circle", "ShowFOV")
addSlider(combat, "Aim FOV Radius", "AimFOV", 30, 800, 0)
addSlider(combat, "Hitbox FOV (separate)", "HitboxFOV", 30, 800, 0)
addHeader(combat, "UTILITY")
addButton(combat, "Distance Checker (click a point)", function() end)

addHeader(visuals, "ESP")
addToggle(visuals, "ESP / Wallhack", "ESP", "ESP")
addToggle(visuals, "Name + Health + Distance", "Names")
addToggle(visuals, "Health Bar Overlay", "HealthBar")
addToggle(visuals, "Fade ESP by Distance", "FadeESP")
addToggle(visuals, "Box ESP", "BoxESP")
addToggle(visuals, "Friends-Only ESP", "FriendsOnly")
addToggle(visuals, "Tracers", "Tracers", "Tracers")
addToggle(visuals, "Chat ESP (floating messages)", "ChatESP")
addSlider(visuals, "ESP Range", "ESPRange", 100, 5000, 0)
addHeader(visuals, "WORLD / SCREEN")
addToggle(visuals, "Fullbright", "Fullbright", "Fullbright")
addToggle(visuals, "Night Vision", "NightVision")
addToggle(visuals, "Crosshair", "Crosshair")
addCycle(visuals, "Crosshair Style", "CrosshairStyle", { "Cross", "Dot", "Circle" })
addSlider(visuals, "Crosshair Size", "CrosshairSize", 4, 40, 0)
addToggle(visuals, "Custom Camera FOV", "CamFOV")
addSlider(visuals, "Camera FOV", "CamFOV", 40, 120, 0)
addSlider(visuals, "Time of Day", "TimeOfDay", 0, 24, 1)
addSlider(visuals, "Fog Density", "FogDensity", 0, 1, 2)
addHeader(visuals, "STATS")
addToggle(visuals, "FPS Graph", "FPSGraph")
addToggle(visuals, "Server Stats Display", "ServerStats")

addHeader(movement, "FLIGHT")
addToggle(movement, "Fly (WASD / Space / Ctrl)", "Fly", "Fly")
addSlider(movement, "Fly Speed", "FlySpeed", 10, 300, 0)
addHeader(movement, "MOVEMENT")
addToggle(movement, "Speed Boost", "Speed", "Speed")
addSlider(movement, "Walk Speed (max 120)", "WalkSpeed", 16, 120, 0)
addToggle(movement, "Jump Boost", "JumpBoost")
addSlider(movement, "Jump Power", "JumpPower", 50, 300, 0)
addToggle(movement, "Infinite Jump", "InfJump", "InfJump")
addKeybind(movement, "Super Jump Key", "SuperJump")
addSlider(movement, "Super Jump Power", "SuperJumpPower", 50, 400, 0)
addToggle(movement, "Noclip", "Noclip", "Noclip")
addSlider(movement, "Noclip Speed", "NoclipSpeed", 10, 200, 0)
addToggle(movement, "Auto-Bunnyhop", "Bunnyhop")
addToggle(movement, "Ctrl + Click Teleport", "ClickTP")
addHeader(movement, "PHYSICS")
addToggle(movement, "Low Gravity", "LowGravity")
addSlider(movement, "Gravity", "Gravity", 20, 196.2, 0)
addToggle(movement, "Anti Fall Damage", "AntiFall")
addToggle(movement, "Show Velocity (studs/sec)", "ShowVelocity")
addButton(movement, "Reset Character Position", function()
	local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	if root then root.CFrame = root.CFrame + Vector3.new(0, 10, 0) end
end)
addButton(movement, "Respawn Character", function()
	local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
	if hum then hum.Health = 0 end
end)

addHeader(emotes, "EMOTES (visible to everyone)")
local EMOTES = {
	{ name = "Wave",    id = "rbxassetid://507770239" },
	{ name = "Point",   id = "rbxassetid://507770453" },
	{ name = "Dance 1", id = "rbxassetid://507771019" },
	{ name = "Dance 2", id = "rbxassetid://507776043" },
	{ name = "Dance 3", id = "rbxassetid://507777268" },
	{ name = "Laugh",   id = "rbxassetid://507770818" },
	{ name = "Cheer",   id = "rbxassetid://507770677" },
}
local currentEmoteTrack = nil
local function stopEmote()
	if currentEmoteTrack then
		currentEmoteTrack:Stop(0.2)
		currentEmoteTrack = nil
	end
end
local function playEmote(animId)
	local char = lp.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum then return end
	stopEmote()
	local anim = Instance.new("Animation")
	anim.AnimationId = animId
	local ok, track = pcall(function() return hum:LoadAnimation(anim) end)
	if ok and track then
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Action
		track:Play(0.2)
		currentEmoteTrack = track
	end
end
for _, e in ipairs(EMOTES) do
	addButton(emotes, e.name, function() playEmote(e.id) end)
end
addButton(emotes, "Stop Emote", stopEmote)

addHeader(social, "NAMETAG")
local TAG_COLORS = { Color3.fromRGB(255, 196, 120), Color3.fromRGB(255, 110, 150), Color3.fromRGB(150, 110, 255), Color3.fromRGB(110, 255, 170), Color3.fromRGB(255, 255, 255) }
local tagColorIndex = 1
addButton(social, "Cycle My Nametag Color", function()
	tagColorIndex = (tagColorIndex % #TAG_COLORS) + 1
end)
addHeader(social, "INFO")
local teamCountLabel = addLabel(social, "Click below to see team counts.")
addButton(social, "Refresh Team Counts", function()
	local counts = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		local teamName = plr.Team and plr.Team.Name or "No Team"
		counts[teamName] = (counts[teamName] or 0) + 1
	end
	local lines = {}
	for name, count in pairs(counts) do
		table.insert(lines, name .. ": " .. count)
	end
	teamCountLabel.Text = table.concat(lines, "\n")
end)
addHeader(social, "QUICK CHAT")
local quickMessages = { "gg", "nice", "thanks", "sorry", "lol", "one sec" }
for _, msg in ipairs(quickMessages) do
	addButton(social, msg, function()
		pcall(function()
			local channel = TextChatService.TextChannels and TextChatService.TextChannels:FindFirstChild("RBXGeneral")
			if channel then channel:SendAsync(msg) end
		end)
	end)
end

addHeader(qol, "SERVER")
local jobIdLabel = addLabel(qol, "JobId: " .. game.JobId .. "\n(select and copy manually)")
addHeader(qol, "SETTINGS EXPORT")
local exportBox = Instance.new("TextBox")
exportBox.Size = UDim2.new(1, 0, 0, 70)
exportBox.BackgroundColor3 = Color3.fromRGB(10, 6, 28)
exportBox.Text = ""
exportBox.PlaceholderText = "Export/import code appears here"
exportBox.TextWrapped = true
exportBox.ClearTextOnFocus = false
exportBox.MultiLine = true
exportBox.Font = Enum.Font.Code
exportBox.TextSize = 12
exportBox.TextColor3 = C.accent2
exportBox.Parent = qol
Instance.new("UICorner", exportBox).CornerRadius = UDim.new(0, 9)

local function exportSettings()
	local parts = {}
	for k, v in pairs(Settings) do
		table.insert(parts, k .. "=" .. tostring(v))
	end
	exportBox.Text = table.concat(parts, ";")
end

local function importSettings()
	local text = exportBox.Text
	for pair in text:gmatch("[^;]+") do
		local k, v = pair:match("([^=]+)=(.+)")
		if k and v and Settings[k] ~= nil then
			local num = tonumber(v)
			if num then
				Settings[k] = num
			elseif typeof(Settings[k]) == "string" then
				Settings[k] = v
			end
		end
	end
	for key in pairs(Refresh) do Refresh[key]() end
end

addButton(qol, "Export Current Settings", exportSettings)
addButton(qol, "Import From Box Above", importSettings)
addHeader(qol, "RESET")
addButton(qol, "Reset All Settings to Default", function()
	Settings.AimFOV = 200
	Settings.Smooth = 0.6
	Settings.LockRange = 1000
	Settings.ESPRange = 800
	Settings.FlySpeed = 70
	Settings.WalkSpeed = 60
	Settings.JumpPower = 100
	Settings.CamFOV = 90
	Settings.BGSpeed = 1
	for key in pairs(Refresh) do Refresh[key]() end
end)
addHeader(qol, "KEYBINDS")
local bindListLabel = addLabel(qol, "")
local function refreshBindList()
	local lines = {}
	for k, v in pairs(Binds) do
		table.insert(lines, k .. ": " .. bindName(v))
	end
	table.sort(lines)
	bindListLabel.Text = table.concat(lines, "\n")
end
addButton(qol, "Show Current Keybinds", refreshBindList)
addHeader(qol, "MISC")
addToggle(qol, "Mute All Sounds", "MuteSounds")
local timerRunning, timerStart = false, 0
addButton(qol, "Start/Stop Timer", function()
	timerRunning = not timerRunning
	if timerRunning then timerStart = os.clock() end
end)

addHeader(settings, "MENU")
addKeybind(settings, "Toggle Menu Key", "Menu")
addToggle(settings, "Rainbow Border", "Rainbow")
addToggle(settings, "Menu Particles", "Particles")
addToggle(settings, "Show FPS", "ShowFPS")
addSlider(settings, "Background Speed", "BGSpeed", 0, 5, 1)
addSlider(settings, "HUD Opacity", "HUDOpacity", 0, 1, 2)
addSlider(settings, "Menu Scale", "MenuScale", 0.6, 1.3, 2)

addHeader(settings, "GAME MODE")

addHeader(settings, "CURRENT GAME")
local gameInfoLabel = Instance.new("TextLabel")
gameInfoLabel.Size = UDim2.new(1, 0, 0, 0)
gameInfoLabel.AutomaticSize = Enum.AutomaticSize.Y
gameInfoLabel.BackgroundTransparency = 1
gameInfoLabel.Font = Enum.Font.GothamMedium
gameInfoLabel.TextSize = 13
gameInfoLabel.TextColor3 = C.text
gameInfoLabel.TextXAlignment = Enum.TextXAlignment.Left
gameInfoLabel.TextWrapped = true
gameInfoLabel.Visible = false
gameInfoLabel.Text = ""
gameInfoLabel.Parent = settings
addButton(settings, "Show Current Game", function()
	if gameInfoLabel.Visible then
		gameInfoLabel.Visible = false
		return
	end
	local name = "Unknown"
	local ok, info = pcall(function() return MarketplaceService:GetProductInfo(game.PlaceId) end)
	if ok and info then name = info.Name end
	gameInfoLabel.Text = string.format(
		"Game: %s\nPlaceId: %d\nUniverseId: %d\nJobId: %s\nPlayers: %d",
		name, game.PlaceId, game.GameId, game.JobId, #Players:GetPlayers()
	)
	gameInfoLabel.Visible = true
end)

addHeader(settings, "COMMUNITY")
local DISCORD_LINK = "https://discord.gg/etVBgHScx"
local dcButton = Instance.new("TextButton")
dcButton.Size = UDim2.new(1, 0, 0, 44)
dcButton.BackgroundColor3 = Color3.fromRGB(230, 110, 150)
dcButton.Text = "Join our Discord"
dcButton.Font = Enum.Font.GothamBold
dcButton.TextSize = 14
dcButton.TextColor3 = Color3.new(1, 1, 1)
dcButton.Parent = settings
Instance.new("UICorner", dcButton).CornerRadius = UDim.new(0, 9)
local dcBox = Instance.new("TextBox")
dcBox.Size = UDim2.new(1, 0, 0, 36)
dcBox.BackgroundColor3 = Color3.fromRGB(10, 6, 28)
dcBox.Text = DISCORD_LINK
dcBox.TextEditable = false
dcBox.ClearTextOnFocus = false
dcBox.Font = Enum.Font.GothamBold
dcBox.TextSize = 13
dcBox.TextColor3 = C.accent2
dcBox.Visible = false
dcBox.Parent = settings
Instance.new("UICorner", dcBox).CornerRadius = UDim.new(0, 9)
Instance.new("UIStroke", dcBox).Color = Color3.fromRGB(230, 110, 150)
dcButton.MouseButton1Click:Connect(function()
	dcBox.Visible = not dcBox.Visible
	dcButton.Text = dcBox.Visible and "Click the link, Ctrl+A, Ctrl+C" or "Join our Discord"
end)

selectTab("Priority")

------------------------------------------------------------
-- HUD
------------------------------------------------------------
local fovCircle = Instance.new("Frame")
fovCircle.AnchorPoint = Vector2.new(0.5, 0.5)
fovCircle.BackgroundTransparency = 1
fovCircle.Parent = gui
Instance.new("UICorner", fovCircle).CornerRadius = UDim.new(1, 0)
local fovStroke = Instance.new("UIStroke", fovCircle)
fovStroke.Thickness = 1.5
fovStroke.Color = C.accent2

local crossH = Instance.new("Frame")
crossH.AnchorPoint = Vector2.new(0.5, 0.5)
crossH.Position = UDim2.fromScale(0.5, 0.5)
crossH.BackgroundColor3 = C.on
crossH.BorderSizePixel = 0
crossH.Visible = false
crossH.Parent = gui
local crossV = crossH:Clone()
crossV.Parent = gui
local crossCircle = Instance.new("Frame")
crossCircle.AnchorPoint = Vector2.new(0.5, 0.5)
crossCircle.Position = UDim2.fromScale(0.5, 0.5)
crossCircle.BackgroundTransparency = 1
crossCircle.Visible = false
crossCircle.Parent = gui
Instance.new("UICorner", crossCircle).CornerRadius = UDim.new(1, 0)
local crossCircleStroke = Instance.new("UIStroke", crossCircle)
crossCircleStroke.Color = C.on
crossCircleStroke.Thickness = 2
local crossDot = Instance.new("Frame")
crossDot.AnchorPoint = Vector2.new(0.5, 0.5)
crossDot.Position = UDim2.fromScale(0.5, 0.5)
crossDot.BackgroundColor3 = C.on
crossDot.BorderSizePixel = 0
crossDot.Visible = false
crossDot.Parent = gui
Instance.new("UICorner", crossDot).CornerRadius = UDim.new(1, 0)

local lockLabel = Instance.new("TextLabel")
lockLabel.AnchorPoint = Vector2.new(0.5, 0)
lockLabel.Position = UDim2.new(0.5, 0, 0, 60)
lockLabel.Size = UDim2.fromOffset(300, 26)
lockLabel.BackgroundColor3 = Color3.fromRGB(10, 6, 28)
lockLabel.BackgroundTransparency = 0.25
lockLabel.Font = Enum.Font.GothamBold
lockLabel.TextSize = 14
lockLabel.TextColor3 = C.pink
lockLabel.Visible = false
lockLabel.Parent = gui
Instance.new("UICorner", lockLabel).CornerRadius = UDim.new(0, 8)

local fpsLabel = Instance.new("TextLabel")
fpsLabel.AnchorPoint = Vector2.new(1, 0)
fpsLabel.Position = UDim2.new(1, -10, 0, 8)
fpsLabel.Size = UDim2.fromOffset(100, 20)
fpsLabel.BackgroundTransparency = 1
fpsLabel.Font = Enum.Font.GothamBold
fpsLabel.TextSize = 13
fpsLabel.TextColor3 = C.on
fpsLabel.TextXAlignment = Enum.TextXAlignment.Right
fpsLabel.TextStrokeTransparency = 0.5
fpsLabel.Parent = gui

local pingLabel = Instance.new("TextLabel")
pingLabel.AnchorPoint = Vector2.new(1, 0)
pingLabel.Position = UDim2.new(1, -10, 0, 28)
pingLabel.Size = UDim2.fromOffset(100, 20)
pingLabel.BackgroundTransparency = 1
pingLabel.Font = Enum.Font.GothamBold
pingLabel.TextSize = 13
pingLabel.TextColor3 = C.accent2
pingLabel.TextXAlignment = Enum.TextXAlignment.Right
pingLabel.TextStrokeTransparency = 0.5
pingLabel.Parent = gui

local velocityLabel = Instance.new("TextLabel")
velocityLabel.AnchorPoint = Vector2.new(1, 0)
velocityLabel.Position = UDim2.new(1, -10, 0, 48)
velocityLabel.Size = UDim2.fromOffset(160, 20)
velocityLabel.BackgroundTransparency = 1
velocityLabel.Font = Enum.Font.GothamBold
velocityLabel.TextSize = 13
velocityLabel.TextColor3 = C.pink
velocityLabel.TextXAlignment = Enum.TextXAlignment.Right
velocityLabel.TextStrokeTransparency = 0.5
velocityLabel.Visible = false
velocityLabel.Parent = gui

local serverStatsLabel = Instance.new("TextLabel")
serverStatsLabel.AnchorPoint = Vector2.new(1, 0)
serverStatsLabel.Position = UDim2.new(1, -10, 0, 68)
serverStatsLabel.Size = UDim2.fromOffset(160, 20)
serverStatsLabel.BackgroundTransparency = 1
serverStatsLabel.Font = Enum.Font.GothamMedium
serverStatsLabel.TextSize = 12
serverStatsLabel.TextColor3 = C.accent2
serverStatsLabel.TextXAlignment = Enum.TextXAlignment.Right
serverStatsLabel.TextStrokeTransparency = 0.5
serverStatsLabel.Visible = false
serverStatsLabel.Parent = gui

local timerDisplay = Instance.new("TextLabel")
timerDisplay.Position = UDim2.new(0, 10, 0, 28)
timerDisplay.Size = UDim2.fromOffset(150, 20)
timerDisplay.BackgroundTransparency = 1
timerDisplay.Font = Enum.Font.GothamBold
timerDisplay.TextSize = 13
timerDisplay.TextColor3 = C.accent2
timerDisplay.TextXAlignment = Enum.TextXAlignment.Left
timerDisplay.TextStrokeTransparency = 0.5
timerDisplay.Visible = false
timerDisplay.Parent = gui

local aimDebug = Instance.new("TextLabel")
aimDebug.Position = UDim2.fromOffset(10, 46)
aimDebug.Size = UDim2.fromOffset(420, 18)
aimDebug.BackgroundTransparency = 1
aimDebug.Font = Enum.Font.GothamBold
aimDebug.TextSize = 12
aimDebug.TextColor3 = C.accent2
aimDebug.TextXAlignment = Enum.TextXAlignment.Left
aimDebug.TextStrokeTransparency = 0.5
aimDebug.Parent = gui

local fpsGraphFrame = Instance.new("Frame")
fpsGraphFrame.AnchorPoint = Vector2.new(1, 0)
fpsGraphFrame.Position = UDim2.new(1, -10, 0, 90)
fpsGraphFrame.Size = UDim2.fromOffset(120, 40)
fpsGraphFrame.BackgroundColor3 = Color3.fromRGB(10, 6, 28)
fpsGraphFrame.BackgroundTransparency = 0.3
fpsGraphFrame.BorderSizePixel = 0
fpsGraphFrame.Visible = false
fpsGraphFrame.Parent = gui
Instance.new("UICorner", fpsGraphFrame).CornerRadius = UDim.new(0, 6)
local fpsBars = {}
for i = 1, 24 do
	local bar = Instance.new("Frame")
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.new(0, (i - 1) * 5, 1, 0)
	bar.Size = UDim2.fromOffset(4, 2)
	bar.BackgroundColor3 = C.on
	bar.BorderSizePixel = 0
	bar.Parent = fpsGraphFrame
	table.insert(fpsBars, bar)
end

------------------------------------------------------------
-- Target tracking (event based)
------------------------------------------------------------
local chars = {}

local function track(d)
	if d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model") then
		chars[d.Parent] = d
	end
end
for _, d in ipairs(workspace:GetDescendants()) do track(d) end
connect(workspace.DescendantAdded, track)
connect(workspace.DescendantRemoving, function(d)
	if d:IsA("Humanoid") and d.Parent then chars[d.Parent] = nil end
end)

local function isFriend(plr)
	local ok, result = pcall(function() return lp:IsFriendsWith(plr.UserId) end)
	return ok and result
end

local function passesFilter(char)
	if char == lp.Character then return false end
	local plr = Players:GetPlayerFromCharacter(char)
	if plr then
		if State.TeamCheck and plr.Team ~= nil and plr.Team == lp.Team then return false end
		if State.FriendsOnly and not isFriend(plr) then return false end
	elseif not State.TargetNPCs then
		return false
	end
	return true
end

local function getPart(char)
	if Settings.AimPart == "Torso" then
		return char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Head")
	end
	return char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart")
end

local function isValid(char)
	local hum = chars[char]
	if not hum or not char.Parent or hum.Health <= 0 then return false end
	if not passesFilter(char) then return false end
	return getPart(char) ~= nil
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function isVisible(char, part)
	rayParams.FilterDescendantsInstances = { lp.Character, char }
	local origin = cam.CFrame.Position
	return workspace:Raycast(origin, part.Position - origin, rayParams) == nil
end

local function aimCenter()
	if UIS.MouseBehavior == Enum.MouseBehavior.LockCenter then
		return cam.ViewportSize / 2
	end
	return UIS:GetMouseLocation()
end

local function predictPosition(char, part)
	if not State.Prediction then return part.Position end
	local vel = part.AssemblyLinearVelocity
	return part.Position + vel * 0.15
end

local function getClosestToCursor()
	local center = aimCenter()
	local best, bestDist = nil, Settings.AimFOV
	for char in pairs(chars) do
		if isValid(char) then
			local part = getPart(char)
			local sp, onScreen = cam:WorldToViewportPoint(predictPosition(char, part))
			if onScreen then
				local d = (Vector2.new(sp.X, sp.Y) - center).Magnitude
				if d < bestDist and (not State.WallCheck or isVisible(char, part)) then
					best, bestDist = char, d
				end
			end
		end
	end
	return best
end

local function getClosestToMe()
	local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	local origin = root and root.Position or cam.CFrame.Position
	local best, bestDist = nil, Settings.LockRange
	for char in pairs(chars) do
		if isValid(char) then
			local part = getPart(char)
			local d = (part.Position - origin).Magnitude
			if d < bestDist and (not State.WallCheck or isVisible(char, part)) then
				best, bestDist = char, d
			end
		end
	end
	return best, bestDist
end

------------------------------------------------------------
-- Aim: runs at the LAST render priority so nothing can overwrite it
------------------------------------------------------------
local aimLook, lockTarget, lockTimer = nil, nil, 0

local function aimStep(dt)
	cam = workspace.CurrentCamera
	if not cam then return end

	local target

	if State.Lock then
		lockTimer -= dt
		if lockTimer <= 0 or not (lockTarget and isValid(lockTarget)) then
			lockTimer = 0.1
			local dist
			lockTarget, dist = getClosestToMe()
			if lockTarget then
				local plr = Players:GetPlayerFromCharacter(lockTarget)
				lockLabel.Text = string.format("LOCKED: %s  [%d]", plr and plr.DisplayName or lockTarget.Name, math.floor(dist))
			end
		end
		target = lockTarget
		lockLabel.Visible = target ~= nil
	else
		lockTarget = nil
		lockLabel.Visible = false
	end

	local holding = State.AimAlways or isBindDown(Binds.AimHold)
	if not target and State.Aimbot and holding then
		target = getClosestToCursor()
	end

	if State.AimDebug then
		local count = 0
		for char in pairs(chars) do if isValid(char) then count += 1 end end
		aimDebug.Visible = true
		aimDebug.Text = string.format("AIM: %s | holding: %s | valid targets: %d | aiming: %s",
			State.Aimbot and "ON" or "OFF", tostring(holding), count,
			target and target.Name or "none")
	else
		aimDebug.Visible = false
	end

	if State.SilentAim and target then
		return
	end

	if target then
		local part = getPart(target)
		if part then
			local pos = cam.CFrame.Position
			local want = predictPosition(target, part) - pos
			if want.Magnitude > 0.01 then
				want = want.Unit
				local a = (Settings.Smooth >= 1) and 1 or (1 - (1 - Settings.Smooth) ^ (dt * 60))
				local look = (aimLook or cam.CFrame.LookVector):Lerp(want, a)
				if look.Magnitude < 0.01 then look = want end
				aimLook = look.Unit
				if math.abs(aimLook.Y) > 0.999 then aimLook = want end
				cam.CFrame = CFrame.lookAt(pos, pos + aimLook)
			end
		end
	else
		aimLook = nil
	end
end

pcall(function() RunService:UnbindFromRenderStep("NeonAim") end)
RunService:BindToRenderStep("NeonAim", Enum.RenderPriority.Last.Value, aimStep)

------------------------------------------------------------
-- Camera FOV: always-last binding so nothing can overwrite it
------------------------------------------------------------
pcall(function() RunService:UnbindFromRenderStep("NeonCamFOV") end)
RunService:BindToRenderStep("NeonCamFOV", Enum.RenderPriority.Camera.Value + 2, function()
	cam = workspace.CurrentCamera
	if not cam then return end
	if State.CamFOV then
		cam.FieldOfView = Settings.CamFOV
	elseif cam.FieldOfView ~= 70 then
		cam.FieldOfView = 70
	end
end)

------------------------------------------------------------
-- ESP (~15 Hz)
------------------------------------------------------------
local esp = {}
local boxESPFrames = {}

local function clearESP(char)
	local e = esp[char]
	if e then
		e.hl:Destroy()
		e.bb:Destroy()
		esp[char] = nil
	end
	local box = boxESPFrames[char]
	if box then
		box:Destroy()
		boxESPFrames[char] = nil
	end
end

local function updateESP()
	if not State.ESP then
		for char in pairs(esp) do clearESP(char) end
		return
	end
	local camPos = cam.CFrame.Position

	for char in pairs(esp) do
		if not chars[char] or not char.Parent then clearESP(char) end
	end

	for char, hum in pairs(chars) do
		local head = char.Parent and (char:FindFirstChild("Head") or char:FindFirstChild("HumanoidRootPart"))
		local show = head and hum.Health > 0 and passesFilter(char)
			and (head.Position - camPos).Magnitude <= Settings.ESPRange
		if show then
			local dist = (head.Position - camPos).Magnitude
			local e = esp[char]
			if not e then
				local hl = Instance.new("Highlight")
				hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
				hl.FillTransparency = 0.55
				hl.OutlineColor = Color3.new(1, 1, 1)
				hl.Parent = char

				local bb = Instance.new("BillboardGui")
				bb.Size = UDim2.fromOffset(170, 54)
				bb.StudsOffset = Vector3.new(0, 2.6, 0)
				bb.AlwaysOnTop = true
				bb.Adornee = head
				bb.Parent = head

				local tl = Instance.new("TextLabel")
				tl.Size = UDim2.new(1, 0, 0, 36)
				tl.BackgroundTransparency = 1
				tl.Font = Enum.Font.GothamBold
				tl.TextSize = 13
				tl.TextColor3 = Color3.new(1, 1, 1)
				tl.TextStrokeTransparency = 0
				tl.Parent = bb

				local barBg = Instance.new("Frame")
				barBg.Size = UDim2.new(1, 0, 0, 6)
				barBg.Position = UDim2.new(0, 0, 1, -8)
				barBg.BackgroundColor3 = Color3.fromRGB(10, 6, 28)
				barBg.BorderSizePixel = 0
				barBg.Parent = bb
				local barFill = Instance.new("Frame")
				barFill.Size = UDim2.fromScale(1, 1)
				barFill.BackgroundColor3 = Color3.fromRGB(0, 255, 100)
				barFill.BorderSizePixel = 0
				barFill.Parent = barBg

				e = { hl = hl, bb = bb, label = tl, barBg = barBg, barFill = barFill }
				esp[char] = e
			end
			if State.FadeESP then
				local fade = math.clamp(dist / Settings.ESPRange, 0.2, 0.85)
				e.hl.FillTransparency = fade
			else
				e.hl.FillTransparency = 0.55
			end
			local frac = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
			e.hl.FillColor = Color3.fromHSV(frac * 0.33, 1, 1)
			e.bb.Enabled = State.Names
			e.barBg.Visible = State.HealthBar
			if State.HealthBar then
				e.barFill.Size = UDim2.new(frac, 0, 1, 0)
				e.barFill.BackgroundColor3 = Color3.fromHSV(frac * 0.33, 1, 1)
			end
			if State.Names then
				local plr = Players:GetPlayerFromCharacter(char)
				e.label.Text = string.format("%s\n%d HP | %d studs",
					plr and plr.DisplayName or char.Name,
					math.floor(hum.Health), math.floor(dist))
			end

			if State.BoxESP then
				local box = boxESPFrames[char]
				if not box then
					box = Instance.new("Frame")
					box.BackgroundTransparency = 1
					box.BorderSizePixel = 0
					box.Parent = gui
					local bs = Instance.new("UIStroke", box)
					bs.Color = C.on
					bs.Thickness = 2
					boxESPFrames[char] = box
				end
				local top, onTop = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 1.2, 0))
				local bottom, onBottom = cam:WorldToViewportPoint(head.Position - Vector3.new(0, 3, 0))
				if onTop and onBottom then
					local h = math.abs(top.Y - bottom.Y)
					local w = h * 0.55
					box.Visible = true
					box.Size = UDim2.fromOffset(w, h)
					box.Position = UDim2.fromOffset(top.X - w / 2, top.Y)
				else
					box.Visible = false
				end
			else
				local box = boxESPFrames[char]
				if box then box.Visible = false end
			end
		else
			clearESP(char)
		end
	end
end

------------------------------------------------------------
-- Tracers
------------------------------------------------------------
local tracers = {}

local function hideTracers()
	for _, t in pairs(tracers) do t.Visible = false end
end

local function updateTracers()
	local vs = cam.ViewportSize
	local from = Vector2.new(vs.X / 2, vs.Y)
	local camPos = cam.CFrame.Position
	for char, t in pairs(tracers) do
		if not chars[char] or not char.Parent then
			t:Destroy()
			tracers[char] = nil
		end
	end
	for char, hum in pairs(chars) do
		local root = char.Parent and char:FindFirstChild("HumanoidRootPart")
		local t = tracers[char]
		local drawn = false
		if root and hum.Health > 0 and passesFilter(char)
			and (root.Position - camPos).Magnitude <= Settings.ESPRange then
			local sp, onScreen = cam:WorldToViewportPoint(root.Position)
			if onScreen and sp.Z > 0 then
				if not t then
					t = Instance.new("Frame")
					t.AnchorPoint = Vector2.new(0.5, 0.5)
					t.BorderSizePixel = 0
					t.BackgroundColor3 = C.pink
					t.ZIndex = 0
					t.Parent = gui
					tracers[char] = t
				end
				local to = Vector2.new(sp.X, sp.Y)
				local diff = to - from
				t.Size = UDim2.fromOffset(diff.Magnitude, 1.5)
				t.Position = UDim2.fromOffset((from.X + to.X) / 2, (from.Y + to.Y) / 2)
				t.Rotation = math.deg(math.atan2(diff.Y, diff.X))
				t.Visible = true
				drawn = true
			end
		end
		if t and not drawn then t.Visible = false end
	end
end

------------------------------------------------------------
-- Chat ESP
------------------------------------------------------------
local chatBubbles = {}
local function showChatBubble(plr, message)
	if not State.ChatESP then return end
	local char = plr.Character
	local head = char and char:FindFirstChild("Head")
	if not head then return end

	local old = chatBubbles[plr]
	if old then old:Destroy() end

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(200, 50)
	bb.StudsOffset = Vector3.new(0, 3.6, 0)
	bb.AlwaysOnTop = true
	bb.Adornee = head
	bb.Parent = head

	local tl = Instance.new("TextLabel")
	tl.Size = UDim2.fromScale(1, 1)
	tl.BackgroundColor3 = Color3.fromRGB(10, 6, 28)
	tl.BackgroundTransparency = 0.2
	tl.TextWrapped = true
	tl.Font = Enum.Font.GothamMedium
	tl.TextSize = 12
	tl.TextColor3 = Color3.new(1, 1, 1)
	tl.Text = message
	tl.Parent = bb
	Instance.new("UICorner", tl).CornerRadius = UDim.new(0, 6)

	chatBubbles[plr] = bb
	task.delay(5, function()
		if chatBubbles[plr] == bb then
			bb:Destroy()
			chatBubbles[plr] = nil
		end
	end)
end
connect(Players.PlayerAdded, function(plr)
	connect(plr.Chatted, function(msg) showChatBubble(plr, msg) end)
end)
for _, plr in ipairs(Players:GetPlayers()) do
	connect(plr.Chatted, function(msg) showChatBubble(plr, msg) end)
end

------------------------------------------------------------
-- Toggle hooks
------------------------------------------------------------
local lightBackup
OnToggle.Fullbright = function(on)
	if on then
		lightBackup = {
			Brightness = Lighting.Brightness, ClockTime = Lighting.ClockTime,
			GlobalShadows = Lighting.GlobalShadows, Ambient = Lighting.Ambient,
		}
		Lighting.Brightness = 2
		Lighting.ClockTime = 14
		Lighting.GlobalShadows = false
		Lighting.Ambient = Color3.fromRGB(200, 200, 200)
	elseif lightBackup then
		for k, v in pairs(lightBackup) do Lighting[k] = v end
		lightBackup = nil
	end
end

local nvBackup
OnToggle.NightVision = function(on)
	if on then
		nvBackup = Lighting.Ambient
		Lighting.Ambient = Color3.fromRGB(140, 140, 140)
	elseif nvBackup then
		Lighting.Ambient = nvBackup
		nvBackup = nil
	end
end

OnToggle.Rainbow = function(on)
	strokeGrad.Color = on and rainbowSeq or neonSeq
end
OnToggle.Rainbow(State.Rainbow)

OnToggle.Tracers = function(on)
	if not on then hideTracers() end
end

OnToggle.Lock = function(on)
	if not on then
		lockTarget = nil
		lockLabel.Visible = false
	end
end

OnToggle.Xray = function(on)
	for _, part in ipairs(workspace:GetDescendants()) do
		if part:IsA("BasePart") and part:GetAttribute("_sunriseOrigTrans") == nil then
			part:SetAttribute("_sunriseOrigTrans", part.Transparency)
		end
	end
	for _, part in ipairs(workspace:GetDescendants()) do
		if part:IsA("BasePart") and not Players:GetPlayerFromCharacter(part.Parent) then
			local orig = part:GetAttribute("_sunriseOrigTrans")
			if orig ~= nil and orig < 1 then
				part.LocalTransparencyModifier = on and 0.6 or 0
			end
		end
	end
end
connect(workspace.DescendantAdded, function(d)
	if State.Xray and d:IsA("BasePart") and not Players:GetPlayerFromCharacter(d.Parent) then
		task.wait()
		if d.Parent and d.Transparency < 1 then d.LocalTransparencyModifier = 0.6 end
	end
end)

OnToggle.MuteSounds = function(on)
	for _, s in ipairs(workspace:GetDescendants()) do
		if s:IsA("Sound") then
			if on then
				if s:GetAttribute("_origVol") == nil then s:SetAttribute("_origVol", s.Volume) end
				s.Volume = 0
			else
				s.Volume = s:GetAttribute("_origVol") or s.Volume
			end
		end
	end
end

local autoReconnectEnabled = false
OnToggle.AutoReconnect = function(on) autoReconnectEnabled = on end
pcall(function()
	game:GetService("GuiService").ErrorMessageChanged:Connect(function()
		if autoReconnectEnabled then
			task.wait(2)
			pcall(function() TeleportService:Teleport(game.PlaceId, lp) end)
		end
	end)
end)

------------------------------------------------------------
-- Input
------------------------------------------------------------
connect(UIS.InputBegan, function(input)
	if listening then
		local newBind
		if input.UserInputType == Enum.UserInputType.Keyboard then
			if input.KeyCode == Enum.KeyCode.Escape then
				if listening.key ~= "Menu" then newBind = NONE end
			else
				newBind = input.KeyCode
			end
		elseif input.UserInputType == Enum.UserInputType.MouseButton2
			or input.UserInputType == Enum.UserInputType.MouseButton3 then
			newBind = input.UserInputType
		end
		if newBind then
			Binds[listening.key] = newBind
			listening.btn.Text = bindName(newBind)
			listening = nil
		end
		return
	end

	if UIS:GetFocusedTextBox() then return end

	if matches(input, Binds.Menu) then main.Visible = not main.Visible end
	if matches(input, Binds.Panic) then
		setToggle("ESP", false)
		setToggle("Aimbot", false)
		setToggle("Lock", false)
		setToggle("Fly", false)
		setToggle("Tracers", false)
		setToggle("Noclip", false)
	end
	for _, k in ipairs(ToggleBinds) do
		if matches(input, Binds[k]) then setToggle(k, not State[k]) end
	end

	if State.ClickTP and input.UserInputType == Enum.UserInputType.MouseButton1 and UIS:IsKeyDown(Enum.KeyCode.LeftControl) then
		local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		if root and mouse.Hit then
			root.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0, 3, 0))
		end
	end
end)

connect(UIS.InputEnded, function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging = nil
		windowDrag = nil
	end
end)

connect(UIS.InputChanged, function(input)
	if input.UserInputType ~= Enum.UserInputType.MouseMovement
		and input.UserInputType ~= Enum.UserInputType.Touch then return end
	if dragging then
		dragging(input.Position.X)
	elseif windowDrag then
		local d = input.Position - windowDrag.start
		main.Position = UDim2.new(
			windowDrag.pos.X.Scale, windowDrag.pos.X.Offset + d.X,
			windowDrag.pos.Y.Scale, windowDrag.pos.Y.Offset + d.Y)
	end
end)

titleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		windowDrag = { start = input.Position, pos = main.Position }
	end
end)

connect(UIS.JumpRequest, function()
	if State.InfJump then
		local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
		if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
	end
end)

connect(UIS.InputBegan, function(input)
	if matches(input, Binds.SuperJump) then
		local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		if root then
			root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, Settings.SuperJumpPower, root.AssemblyLinearVelocity.Z)
		end
	end
end)

------------------------------------------------------------
-- Distance checker
------------------------------------------------------------
local checkerActive = false
connect(mouse.Button1Down, function()
	if checkerActive then
		checkerActive = false
		local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		if root and mouse.Hit then
			local d = (mouse.Hit.Position - root.Position).Magnitude
			aimDebug.Visible = true
			aimDebug.Text = string.format("Distance to clicked point: %.1f studs", d)
			task.delay(4, function()
				if not State.AimDebug then aimDebug.Visible = false end
			end)
		end
	end
end)
for _, child in ipairs(combat:GetChildren()) do
	if child:IsA("TextButton") and child.Text == "Distance Checker (click a point)" then
		child.MouseButton1Click:Connect(function() checkerActive = true end)
	end
end

------------------------------------------------------------
-- Freecam
------------------------------------------------------------
local freecamPos, freecamAngleX, freecamAngleY = nil, 0, 0
OnToggle.Freecam = function(on)
	if on then
		freecamPos = cam.CFrame.Position
		cam.CameraType = Enum.CameraType.Scriptable
	else
		cam.CameraType = Enum.CameraType.Custom
	end
end
connect(RunService.RenderStepped, function(dt)
	if State.Freecam and freecamPos then
		local delta = UIS:GetMouseDelta()
		if UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
			freecamAngleY -= delta.X * 0.003
			freecamAngleX = math.clamp(freecamAngleX - delta.Y * 0.003, -1.5, 1.5)
		end
		local rot = CFrame.Angles(0, freecamAngleY, 0) * CFrame.Angles(freecamAngleX, 0, 0)
		local dir = Vector3.zero
		if UIS:IsKeyDown(Enum.KeyCode.W) then dir += rot.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= rot.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.D) then dir += rot.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= rot.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
		if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end
		if dir.Magnitude > 0 then
			freecamPos += dir.Unit * 60 * dt
		end
		cam.CFrame = CFrame.new(freecamPos) * rot
	end
end)

------------------------------------------------------------
-- Movement
------------------------------------------------------------
local flying, speedApplied, jumpApplied, gravityApplied = false, false, false, false

connect(RunService.Heartbeat, function()
	local char = lp.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not (root and hum) then return end

	local targetSpeed = 16
	if State.Speed then targetSpeed = math.min(Settings.WalkSpeed, 120) end
	if State.Sprint and isBindDown(Binds.SprintKey) then
		targetSpeed = math.max(targetSpeed, 32)
	end
	if targetSpeed ~= 16 or speedApplied then
		hum.WalkSpeed = targetSpeed
		speedApplied = targetSpeed ~= 16
	end

	if State.JumpBoost then
		hum.UseJumpPower = true
		hum.JumpPower = Settings.JumpPower
		jumpApplied = true
	elseif jumpApplied then
		hum.JumpPower = 50
		jumpApplied = false
	end

	if State.WalkOnWater then
		if root.Position.Y < workspace.Terrain.WaterWaveSize + 2 then
			root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z)
		end
	end

	hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, not State.AntiFall)
	hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, not State.AntiFall)

	if State.Fly then
		flying = true
		hum.PlatformStand = true
		local c = workspace.CurrentCamera.CFrame
		local dir = Vector3.zero
		if UIS:IsKeyDown(Enum.KeyCode.W) then dir += c.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= c.LookVector end
		if UIS:IsKeyDown(Enum.KeyCode.D) then dir += c.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= c.RightVector end
		if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
		if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end

		root.AssemblyLinearVelocity = dir.Magnitude > 0 and dir.Unit * Settings.FlySpeed or Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero

		local flat = Vector3.new(c.LookVector.X, 0, c.LookVector.Z)
		if flat.Magnitude > 0.01 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
		end
	elseif flying then
		flying = false
		hum.PlatformStand = false
	end
end)

local speedConn
local function hookSpeed(char)
	if speedConn then speedConn:Disconnect() end
	local hum = char:WaitForChild("Humanoid", 5)
	if not hum then return end
	speedConn = hum:GetPropertyChangedSignal("WalkSpeed"):Connect(function()
		if State.Speed then
			local want = math.min(Settings.WalkSpeed, 120)
			if hum.WalkSpeed ~= want then hum.WalkSpeed = want end
		end
	end)
end
if lp.Character then task.spawn(hookSpeed, lp.Character) end

connect(RunService.Stepped, function(_, dt)
	if State.Bunnyhop then
		local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
		if hum and hum:GetState() == Enum.HumanoidStateType.Landed then
			hum:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end

	if not State.Noclip or not lp.Character then return end

	-- disable collision every frame on every part, including ones added mid-animation
	for _, p in ipairs(lp.Character:GetDescendants()) do
		if p:IsA("BasePart") and p.CanCollide then
			p.CanCollide = false
		end
	end

	local root = lp.Character:FindFirstChild("HumanoidRootPart")
	local hum = lp.Character:FindFirstChildOfClass("Humanoid")
	if root and hum then
		hum.PlatformStand = true -- stop the Humanoid's own physics from fighting our movement

		if not State.Fly then
			local dir = Vector3.zero
			local c = workspace.CurrentCamera.CFrame
			if UIS:IsKeyDown(Enum.KeyCode.W) then dir += c.LookVector end
			if UIS:IsKeyDown(Enum.KeyCode.S) then dir -= c.LookVector end
			if UIS:IsKeyDown(Enum.KeyCode.D) then dir += c.RightVector end
			if UIS:IsKeyDown(Enum.KeyCode.A) then dir -= c.RightVector end
			if UIS:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.yAxis end
			if UIS:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.yAxis end

			root.AssemblyLinearVelocity = dir.Magnitude > 0 and dir.Unit * Settings.NoclipSpeed or Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero

			local flat = Vector3.new(c.LookVector.X, 0, c.LookVector.Z)
			if flat.Magnitude > 0.01 then
				root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
			end
		end
	end
end)

connect(RunService.Stepped, function()
	if not State.Noclip then
		local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
		if hum and not State.Fly then hum.PlatformStand = false end
	end
end)

connect(lp.CharacterAdded, function(c)
	flying, speedApplied, jumpApplied = false, false, false
	noclipTimer = 0
	lockTarget = nil
	currentEmoteTrack = nil
	task.spawn(hookSpeed, c)
end)

------------------------------------------------------------
-- Gravity
------------------------------------------------------------
connect(RunService.Heartbeat, function()
	if State.LowGravity then
		workspace.Gravity = Settings.Gravity
		gravityApplied = true
	elseif gravityApplied then
		workspace.Gravity = 196.2
		gravityApplied = false
	end
end)

------------------------------------------------------------
-- Server hop
------------------------------------------------------------
local function serverHop()
	pcall(function()
		TeleportService:Teleport(game.PlaceId, lp)
	end)
end
for _, child in ipairs(priority:GetChildren()) do
	if child:IsA("TextButton") and child.Text == "Server Hop" then
		child.MouseButton1Click:Connect(serverHop)
	end
end

------------------------------------------------------------
-- Main render loop
------------------------------------------------------------
local espTimer, fpsTimer, fpsFrames = 0, 0, 0
local fpsGraphIndex = 1

connect(RunService.RenderStepped, function(dt)
	cam = workspace.CurrentCamera
	local t = os.clock()

	mainScale.Scale = Settings.MenuScale
	main.BackgroundTransparency = 1 - Settings.HUDOpacity

	if main.Visible then
		strokeGrad.Rotation = (t * 90) % 360
		bgGrad.Rotation = (t * 20 * Settings.BGSpeed) % 360
		if State.Particles then
			for _, p in ipairs(particles) do
				p.f.Visible = true
				p.y -= p.vy * dt * Settings.BGSpeed
				if p.y < -0.05 then
					p.y = 1.05
					p.x = rng:NextNumber()
				end
				p.f.Position = UDim2.fromScale(p.x + math.sin(t + p.phase) * 0.02, p.y)
			end
		else
			for _, p in ipairs(particles) do p.f.Visible = false end
		end
	end

	fovCircle.Visible = State.ShowFOV and (State.Aimbot or State.Lock)
	if fovCircle.Visible then
		local c = aimCenter()
		fovCircle.Size = UDim2.fromOffset(Settings.AimFOV * 2, Settings.AimFOV * 2)
		fovCircle.Position = UDim2.fromOffset(c.X, c.Y)
		fovStroke.Color = (State.Lock and lockTarget) and C.pink or C.accent2
	end

	crossH.Visible = State.Crosshair and Settings.CrosshairStyle == "Cross"
	crossV.Visible = State.Crosshair and Settings.CrosshairStyle == "Cross"
	crossDot.Visible = State.Crosshair and Settings.CrosshairStyle == "Dot"
	crossCircle.Visible = State.Crosshair and Settings.CrosshairStyle == "Circle"
	if State.Crosshair then
		local size = Settings.CrosshairSize
		crossH.Size = UDim2.fromOffset(size, 2)
		crossV.Size = UDim2.fromOffset(2, size)
		crossDot.Size = UDim2.fromOffset(4, 4)
		crossCircle.Size = UDim2.fromOffset(size, size)
	end

	espTimer -= dt
	if espTimer <= 0 then
		espTimer = 1 / 15
		updateESP()
	end

	if State.Tracers then updateTracers() end

	pingLabel.Visible = State.ShowPing
	if State.ShowPing then
		local ok, stats = pcall(function()
			return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValueString()
		end)
		pingLabel.Text = ok and ("Ping: " .. stats) or "Ping: --"
	end

	velocityLabel.Visible = State.ShowVelocity
	if State.ShowVelocity then
		local root = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local v = root.AssemblyLinearVelocity
			velocityLabel.Text = string.format("Speed: %.0f studs/s", Vector3.new(v.X, 0, v.Z).Magnitude)
		end
	end

	serverStatsLabel.Visible = State.ServerStats
	if State.ServerStats then
		serverStatsLabel.Text = string.format("Players: %d/%d", #Players:GetPlayers(), Players.MaxPlayers)
	end

	timerDisplay.Visible = timerRunning
	if timerRunning then
		local elapsed = os.clock() - timerStart
		local mins = math.floor(elapsed / 60)
		local secs = elapsed % 60
		timerDisplay.Text = string.format("Timer: %02d:%04.1f", mins, secs)
	end

	pcall(function()
		Lighting.ClockTime = Settings.TimeOfDay
		Lighting.FogEnd = Settings.FogDensity > 0 and (2000 * (1 - Settings.FogDensity) + 50) or 100000
	end)

	fpsLabel.Visible = State.ShowFPS
	fpsFrames += 1
	fpsTimer += dt
	if fpsTimer >= 0.5 then
		local fps = math.floor(fpsFrames / fpsTimer + 0.5)
		fpsLabel.Text = "FPS: " .. fps
		fpsFrames, fpsTimer = 0, 0

		if State.FPSGraph then
			fpsGraphFrame.Visible = true
			local bar = fpsBars[fpsGraphIndex]
			bar.Size = UDim2.fromOffset(4, math.clamp(fps / 3, 2, 38))
			fpsGraphIndex = fpsGraphIndex % #fpsBars + 1
		else
			fpsGraphFrame.Visible = false
		end
	end
end)

------------------------------------------------------------
-- Auto game-type detection (presets)
------------------------------------------------------------
local function detectGameType()
	local toolCount = #StarterPack:GetChildren()
	local bp = lp:FindFirstChildOfClass("Backpack")
	if bp then toolCount += #bp:GetChildren() end

	local npcCount = 0
	for char in pairs(chars) do
		if not Players:GetPlayerFromCharacter(char) then npcCount += 1 end
	end
	local hazards = 0
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BasePart") then
			local n = d.Name:lower()
			if n:find("kill") or n:find("lava") or n:find("checkpoint") then
				hazards += 1
				if hazards > 10 then break end
			end
		end
	end

	local hasTeams = #Teams:GetTeams() > 1
	local extent = workspace:GetExtentsSize().Magnitude

	if hazards > 10 then return "Obby" end
	if toolCount > 0 and hasTeams then return "Team Shooter" end
	if toolCount > 0 then return "Shooter" end
	if npcCount > 3 then return "PvE / Survival" end
	if extent > 3000 then return "Open World" end
	return "General"
end

local Presets = {
	["Obby"]           = { Fly = false, Speed = true, JumpBoost = true, Noclip = false, ESP = false, Aimbot = false, Lock = false },
	["Team Shooter"]   = { TeamCheck = true, ESP = true, Names = true, Aimbot = true, WallCheck = true, TargetNPCs = false },
	["Shooter"]        = { ESP = true, Names = true, Aimbot = true, WallCheck = true },
	["PvE / Survival"] = { TargetNPCs = true, ESP = true, Names = true, Aimbot = true },
	["Open World"]     = { Fly = true, Speed = true, ESP = false, Aimbot = false },
	["General"]        = {},
}

local function applyPreset(name)
	for key, value in pairs(Presets[name] or {}) do
		setToggle(key, value)
	end
end

local gameType = detectGameType()
applyPreset(gameType)

local typeLabel = Instance.new("TextLabel")
typeLabel.Position = UDim2.fromOffset(10, 28)
typeLabel.Size = UDim2.fromOffset(200, 18)
typeLabel.BackgroundTransparency = 1
typeLabel.Font = Enum.Font.GothamBold
typeLabel.TextSize = 12
typeLabel.TextColor3 = C.accent2
typeLabel.TextXAlignment = Enum.TextXAlignment.Left
typeLabel.TextStrokeTransparency = 0.5
typeLabel.Text = "Mode: " .. gameType
typeLabel.Parent = gui

local modeNames = { "Obby", "Team Shooter", "Shooter", "PvE / Survival", "Open World", "General" }
addButton(settings, "Re-detect Game Type", function()
	gameType = detectGameType()
	applyPreset(gameType)
	typeLabel.Text = "Mode: " .. gameType
end)
addButton(settings, "Cycle Mode Manually", function()
	local i = table.find(modeNames, gameType) or 0
	gameType = modeNames[i % #modeNames + 1]
	applyPreset(gameType)
	typeLabel.Text = "Mode: " .. gameType
end)

------------------------------------------------------------
-- Players tab (admin-only server actions)
------------------------------------------------------------
local adminRemote = RS:WaitForChild("NeonAdminAction", 5)

local playersPage = addTab("Players")
addHeader(playersPage, "PLAYERS IN SERVER (admin actions require server-side admin check)")

if not adminRemote then
	local warnLbl = Instance.new("TextLabel")
	warnLbl.Size = UDim2.new(1, 0, 0, 36)
	warnLbl.BackgroundTransparency = 1
	warnLbl.TextWrapped = true
	warnLbl.Font = Enum.Font.GothamMedium
	warnLbl.TextSize = 12
	warnLbl.TextColor3 = C.pink
	warnLbl.Text = "Server script missing: admin actions need the Script in ServerScriptService."
	warnLbl.Parent = playersPage
end

local listHolder = Instance.new("Frame")
listHolder.Size = UDim2.new(1, 0, 0, 0)
listHolder.AutomaticSize = Enum.AutomaticSize.Y
listHolder.BackgroundTransparency = 1
listHolder.Parent = playersPage
local listLayout = Instance.new("UIListLayout", listHolder)
listLayout.Padding = UDim.new(0, 10)
listLayout.SortOrder = Enum.SortOrder.Name

local function teleportTo(plr)
	local myRoot = lp.Character and lp.Character:FindFirstChild("HumanoidRootPart")
	local theirRoot = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
	if myRoot and theirRoot then
		myRoot.CFrame = theirRoot.CFrame * CFrame.new(0, 0, 4)
	end
end

local function rebuildPlayerList()
	for _, child in ipairs(listHolder:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= lp then
			local row = rowBase(listHolder, 94)
			row.Name = plr.Name
			local name = rowLabel(row, plr.DisplayName .. "  (@" .. plr.Name .. ")", 20)
			name.Size = UDim2.new(1, -24, 0, 22)
			name.Position = UDim2.fromOffset(14, 4)
			name.TextSize = 13
			name.TextTruncate = Enum.TextTruncate.AtEnd

			local btnRow1 = Instance.new("Frame")
			btnRow1.Size = UDim2.new(1, -24, 0, 28)
			btnRow1.Position = UDim2.fromOffset(12, 30)
			btnRow1.BackgroundTransparency = 1
			btnRow1.Parent = row
			local layout1 = Instance.new("UIListLayout", btnRow1)
			layout1.FillDirection = Enum.FillDirection.Horizontal
			layout1.Padding = UDim.new(0, 6)

			local function smallBtn(parent, text, color, callback)
				local b = Instance.new("TextButton")
				b.Size = UDim2.fromOffset(70, 28)
				b.BackgroundColor3 = color
				b.Font = Enum.Font.GothamBold
				b.TextSize = 11
				b.TextColor3 = Color3.new(1, 1, 1)
				b.Text = text
				b.Parent = parent
				Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
				b.MouseButton1Click:Connect(callback)
			end

			smallBtn(btnRow1, "TP", C.accent2, function() teleportTo(plr) end)
			smallBtn(btnRow1, "Bring", C.accent, function()
				if adminRemote then adminRemote:FireServer("Bring", plr.UserId) end
			end)
			smallBtn(btnRow1, "Kill", C.pink, function()
				if adminRemote then adminRemote:FireServer("Kill", plr.UserId) end
			end)
			smallBtn(btnRow1, "Fling", Color3.fromRGB(255, 140, 0), function()
				if adminRemote then adminRemote:FireServer("Fling", plr.UserId) end
			end)

			local btnRow2 = Instance.new("Frame")
			btnRow2.Size = UDim2.new(1, -24, 0, 28)
			btnRow2.Position = UDim2.fromOffset(12, 62)
			btnRow2.BackgroundTransparency = 1
			btnRow2.Parent = row
			local layout2 = Instance.new("UIListLayout", btnRow2)
			layout2.FillDirection = Enum.FillDirection.Horizontal
			layout2.Padding = UDim.new(0, 6)

			smallBtn(btnRow2, "Freeze", Color3.fromRGB(100, 180, 255), function()
				if adminRemote then adminRemote:FireServer("Freeze", plr.UserId) end
			end)
			smallBtn(btnRow2, "Unfrz", Color3.fromRGB(100, 220, 150), function()
				if adminRemote then adminRemote:FireServer("Unfreeze", plr.UserId) end
			end)
			smallBtn(btnRow2, "Heal", Color3.fromRGB(100, 255, 150), function()
				if adminRemote then adminRemote:FireServer("Heal", plr.UserId) end
			end)
			smallBtn(btnRow2, "Cage", Color3.fromRGB(200, 60, 60), function()
				if adminRemote then adminRemote:FireServer("Cage", plr.UserId) end
			end)
		end
	end
end

rebuildPlayerList()
connect(Players.PlayerAdded, rebuildPlayerList)
connect(Players.PlayerRemoving, function() task.defer(rebuildPlayerList) end)
addButton(playersPage, "Refresh List", rebuildPlayerList)

------------------------------------------------------------
-- Unload
------------------------------------------------------------
addButton(settings, "Unload Menu", function()
	for _, c in ipairs(conns) do c:Disconnect() end
	if speedConn then speedConn:Disconnect() end
	pcall(function() RunService:UnbindFromRenderStep("NeonAim") end)
	pcall(function() RunService:UnbindFromRenderStep("NeonCamFOV") end)
	stopEmote()
	for char in pairs(esp) do clearESP(char) end
	for _, tr in pairs(tracers) do tr:Destroy() end
	if State.Fullbright then OnToggle.Fullbright(false) end
	if State.Xray then OnToggle.Xray(false) end
	if cam then cam.FieldOfView = 70 end
	if State.Freecam then cam.CameraType = Enum.CameraType.Custom end
	local hum = lp.Character and lp.Character:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.PlatformStand = false
		if speedApplied then hum.WalkSpeed = 16 end
		if jumpApplied then hum.JumpPower = 50 end
	end
	workspace.Gravity = 196.2
	gui:Destroy()
end)
