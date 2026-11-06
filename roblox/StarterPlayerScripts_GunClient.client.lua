-- 위치: StarterPlayer / StarterPlayerScripts / GunClient (LocalScript)
-- 1~4 숫자키/휠로 무기 교체, 클릭 발사, R 재장전

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

local ShootEvent = ReplicatedStorage:WaitForChild("ShootEvent")
local ReloadEvent = ReplicatedStorage:WaitForChild("ReloadEvent")
local AmmoUpdate = ReplicatedStorage:WaitForChild("AmmoUpdate")
local EquipEvent = ReplicatedStorage:WaitForChild("EquipEvent")
local EquipUpdate = ReplicatedStorage:WaitForChild("EquipUpdate")

-- 서버 WEAPONS와 값(FireRate, Pellets, Spread, MaxRange, Auto)을 맞춰주세요 (화면 효과용)
local WEAPONS = {
	{ Name = "Pistol",  Key = Enum.KeyCode.One,   FireRate = 0.25, Auto = false, Pellets = 1, Spread = 0.5, Range = 300,  Color = Color3.fromRGB(255, 255, 160) },
	{ Name = "Rifle",   Key = Enum.KeyCode.Two,   FireRate = 0.1,  Auto = true,  Pellets = 1, Spread = 1.5, Range = 500,  Color = Color3.fromRGB(255, 220, 100) },
	{ Name = "Shotgun", Key = Enum.KeyCode.Three, FireRate = 0.9,  Auto = false, Pellets = 8, Spread = 6,   Range = 80,   Color = Color3.fromRGB(255, 160, 80) },
	{ Name = "Sniper",  Key = Enum.KeyCode.Four,  FireRate = 1.5,  Auto = false, Pellets = 1, Spread = 0,   Range = 1000, Color = Color3.fromRGB(120, 220, 255) },
}

-- 발사음 / 반동 설정 (무기 이름 기준)
-- SoundId는 임시 내장 효과음입니다. 원하는 총소리를 Roblox에 올리거나 Creator Store에서 찾아
-- "rbxassetid://숫자" 로 바꿔주세요. Pitch로 음 높이를 조절할 수 있어요.
-- Recoil: 한 발당 위로 튀는 각도(도), Kick: 좌우 흔들림 폭(도)
local FX = {
	Pistol  = { SoundId = "rbxasset://sounds/impact_water.mp3", Pitch = 1.6, Volume = 0.8, Recoil = 1.6, Kick = 0.3 },
	Rifle   = { SoundId = "rbxasset://sounds/impact_water.mp3", Pitch = 1.2, Volume = 0.8, Recoil = 0.9, Kick = 0.4 },
	Shotgun = { SoundId = "rbxasset://sounds/impact_water.mp3", Pitch = 0.6, Volume = 1.2, Recoil = 5.0, Kick = 0.8 },
	Sniper  = { SoundId = "rbxasset://sounds/impact_water.mp3", Pitch = 0.45, Volume = 1.3, Recoil = 7.0, Kick = 0.5 },
}
local RECOIL_RECOVERY = 10 -- 클수록 조준이 빨리 돌아옴

local currentIndex = 2 -- Rifle
local holding = false
local lastShot = 0

-- UI -------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "GunGui"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local crosshair = Instance.new("Frame")
crosshair.Size = UDim2.fromOffset(6, 6)
crosshair.Position = UDim2.fromScale(0.5, 0.5)
crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
crosshair.BackgroundColor3 = Color3.new(1, 1, 1)
crosshair.BorderSizePixel = 0
crosshair.Parent = gui
Instance.new("UICorner", crosshair).CornerRadius = UDim.new(1, 0)

local ammoLabel = Instance.new("TextLabel")
ammoLabel.Size = UDim2.fromOffset(260, 50)
ammoLabel.Position = UDim2.new(1, -280, 1, -70)
ammoLabel.BackgroundTransparency = 1
ammoLabel.TextColor3 = Color3.new(1, 1, 1)
ammoLabel.TextStrokeTransparency = 0.5
ammoLabel.Font = Enum.Font.GothamBold
ammoLabel.TextSize = 32
ammoLabel.TextXAlignment = Enum.TextXAlignment.Right
ammoLabel.Text = ""
ammoLabel.Parent = gui

-- 하단 무기 슬롯 바
local slots = {}
local bar = Instance.new("Frame")
bar.Size = UDim2.fromOffset(#WEAPONS * 110, 44)
bar.Position = UDim2.new(0.5, 0, 1, -60)
bar.AnchorPoint = Vector2.new(0.5, 0)
bar.BackgroundTransparency = 1
bar.Parent = gui
local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Horizontal
layout.Padding = UDim.new(0, 6)
layout.Parent = bar

for i, w in ipairs(WEAPONS) do
	local f = Instance.new("TextLabel")
	f.Size = UDim2.fromOffset(104, 44)
	f.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
	f.BackgroundTransparency = 0.4
	f.TextColor3 = Color3.new(1, 1, 1)
	f.Font = Enum.Font.GothamBold
	f.TextSize = 16
	f.Text = i .. "  " .. w.Name
	f.Parent = bar
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 2
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Enabled = false
	stroke.Parent = f
	slots[i] = { frame = f, stroke = stroke }
end

local function refreshSlots()
	for i, s in ipairs(slots) do
		s.stroke.Enabled = (i == currentIndex)
		s.frame.BackgroundTransparency = (i == currentIndex) and 0.1 or 0.5
	end
end
refreshSlots()

local function indexOf(name)
	for i, w in ipairs(WEAPONS) do
		if w.Name == name then return i end
	end
end

-- 팀 스코어 HUD ---------------------------------------
local scores = ReplicatedStorage:WaitForChild("TeamScores")
local redScore = scores:WaitForChild("RedScore")
local blueScore = scores:WaitForChild("BlueScore")
local statusValue = scores:WaitForChild("Status")
local killTarget = scores:WaitForChild("KillTarget")

local function makeScoreLabel(posX, color)
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromOffset(110, 44)
	l.Position = UDim2.new(0.5, posX, 0, 12)
	l.BackgroundColor3 = color
	l.BackgroundTransparency = 0.25
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.GothamBold
	l.TextSize = 28
	l.Parent = gui
	Instance.new("UICorner", l).CornerRadius = UDim.new(0, 8)
	return l
end
local redLabel = makeScoreLabel(-120, Color3.fromRGB(200, 40, 40))
local blueLabel = makeScoreLabel(10, Color3.fromRGB(40, 90, 200))

local targetLabel = Instance.new("TextLabel")
targetLabel.Size = UDim2.fromOffset(120, 20)
targetLabel.Position = UDim2.new(0.5, -60, 0, 58)
targetLabel.BackgroundTransparency = 1
targetLabel.TextColor3 = Color3.new(1, 1, 1)
targetLabel.TextStrokeTransparency = 0.5
targetLabel.Font = Enum.Font.Gotham
targetLabel.TextSize = 14
targetLabel.Parent = gui

local banner = Instance.new("TextLabel")
banner.Size = UDim2.fromOffset(500, 70)
banner.Position = UDim2.new(0.5, -250, 0.25, 0)
banner.BackgroundTransparency = 1
banner.TextColor3 = Color3.new(1, 1, 1)
banner.TextStrokeTransparency = 0
banner.Font = Enum.Font.GothamBlack
banner.TextSize = 48
banner.Text = ""
banner.Parent = gui

local function refreshScores()
	redLabel.Text = tostring(redScore.Value)
	blueLabel.Text = tostring(blueScore.Value)
	targetLabel.Text = "목표 " .. killTarget.Value .. "킬"
	banner.Text = statusValue.Value
end
for _, v in ipairs({ redScore, blueScore, statusValue, killTarget }) do
	v.Changed:Connect(refreshScores)
end
refreshScores()

-- 킬 피드 (오른쪽 위) ---------------------------------
local KillFeed = ReplicatedStorage:WaitForChild("KillFeed")
local MAX_FEED = 5
local FEED_TIME = 5

local feed = Instance.new("Frame")
feed.Size = UDim2.fromOffset(340, 200)
feed.Position = UDim2.new(1, -350, 0, 12)
feed.BackgroundTransparency = 1
feed.Parent = gui
local feedLayout = Instance.new("UIListLayout")
feedLayout.Padding = UDim.new(0, 4)
feedLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
feedLayout.SortOrder = Enum.SortOrder.LayoutOrder
feedLayout.Parent = feed

local feedOrder = 0
local function rich(color, text)
	return string.format('<font color="rgb(%d,%d,%d)">%s</font>',
		color.R * 255, color.G * 255, color.B * 255, text)
end

KillFeed.OnClientEvent:Connect(function(killer, killerColor, weapon, victim, victimColor, headshot)
	feedOrder += 1
	local l = Instance.new("TextLabel")
	l.LayoutOrder = feedOrder
	l.AutomaticSize = Enum.AutomaticSize.XY
	l.Size = UDim2.fromOffset(0, 26)
	l.BackgroundColor3 = Color3.new(0, 0, 0)
	l.BackgroundTransparency = 0.45
	l.RichText = true
	l.Font = Enum.Font.GothamBold
	l.TextSize = 16
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Text = rich(killerColor, killer) .. "  [" .. weapon .. "]" .. (headshot and " 💀" or "") .. "  " .. rich(victimColor, victim)
	if killer == player.Name or victim == player.Name then
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(255, 220, 80)
		stroke.Thickness = 1.5
		stroke.Parent = l
	end
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = l
	Instance.new("UICorner", l).CornerRadius = UDim.new(0, 5)
	l.Parent = feed

	-- 오래된 항목 제거
	local items = {}
	for _, c in ipairs(feed:GetChildren()) do
		if c:IsA("TextLabel") then table.insert(items, c) end
	end
	table.sort(items, function(a, b) return a.LayoutOrder < b.LayoutOrder end)
	while #items > MAX_FEED do
		table.remove(items, 1):Destroy()
	end
	Debris:AddItem(l, FEED_TIME)
end)

-- 서버 신호 -------------------------------------------
AmmoUpdate.OnClientEvent:Connect(function(weaponName, ammo, mag)
	ammoLabel.Text = weaponName .. "  " .. ammo .. " / " .. mag
	ammoLabel.TextColor3 = ammo <= math.max(1, mag * 0.2) and Color3.fromRGB(255, 80, 80) or Color3.new(1, 1, 1)
end)

EquipUpdate.OnClientEvent:Connect(function(weaponName)
	currentIndex = indexOf(weaponName) or currentIndex
	refreshSlots()
end)

-- 무기 교체 -------------------------------------------
local function equip(i)
	if i < 1 then i = #WEAPONS elseif i > #WEAPONS then i = 1 end
	if i == currentIndex then return end
	currentIndex = i
	refreshSlots()
	EquipEvent:FireServer(WEAPONS[i].Name)
end

-- 발사 ------------------------------------------------
local function showTracer(from, to, color)
	local dist = (to - from).Magnitude
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Size = Vector3.new(0.1, 0.1, dist)
	part.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -dist / 2)
	part.Parent = workspace
	Debris:AddItem(part, 0.05)
end

-- 발사음: position이 있으면 3D(다른 플레이어), 없으면 내 발사음
local function playShotSound(weaponName, position)
	local fx = FX[weaponName]
	if not fx then return end
	local s = Instance.new("Sound")
	s.SoundId = fx.SoundId
	s.PlaybackSpeed = fx.Pitch * (0.95 + math.random() * 0.1) -- 약간의 변주
	s.Volume = fx.Volume
	if position then
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.Transparency = 1
		p.Size = Vector3.one
		p.Position = position
		p.Parent = workspace
		s.RollOffMaxDistance = 250
		s.Parent = p
		Debris:AddItem(p, 3)
	else
		s.Parent = workspace.CurrentCamera
		Debris:AddItem(s, 3)
	end
	s:Play()
end

ReplicatedStorage:WaitForChild("ShotFx").OnClientEvent:Connect(playShotSound)

-- 반동: 카메라를 위로 튀겼다가 부드럽게 복귀
local recoilPitch, recoilYaw = 0, 0
local function addRecoil(weaponName)
	local fx = FX[weaponName]
	if not fx then return end
	recoilPitch += math.rad(fx.Recoil)
	recoilYaw += math.rad((math.random() - 0.5) * 2 * fx.Kick)
end

RunService:BindToRenderStep("GunRecoil", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if math.abs(recoilPitch) > 1e-4 or math.abs(recoilYaw) > 1e-4 then
		camera.CFrame = camera.CFrame * CFrame.Angles(recoilPitch, recoilYaw, 0)
		local k = math.clamp(RECOIL_RECOVERY * dt, 0, 1)
		recoilPitch -= recoilPitch * k
		recoilYaw -= recoilYaw * k
	end
end)

local function shoot()
	local char = player.Character
	if not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end

	local w = WEAPONS[currentIndex]
	local now = os.clock()
	if now - lastShot < w.FireRate then return end
	lastShot = now

	local vp = camera.ViewportSize
	local ray = camera:ViewportPointToRay(vp.X / 2, vp.Y / 2)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }

	local root = char:FindFirstChild("HumanoidRootPart")
	local muzzle = root and (root.Position + Vector3.new(0, 1.5, 0)) or ray.Origin
	for _ = 1, w.Pellets do
		local dir = ray.Direction
		if w.Spread > 0 then
			local r = math.rad(w.Spread)
			dir = (CFrame.lookAt(Vector3.zero, dir) * CFrame.Angles((math.random() - 0.5) * 2 * r, (math.random() - 0.5) * 2 * r, 0)).LookVector
		end
		local hit = workspace:Raycast(ray.Origin, dir * w.Range, params)
		showTracer(muzzle, hit and hit.Position or (ray.Origin + dir * w.Range), w.Color)
	end

	ShootEvent:FireServer(ray.Origin, ray.Direction)
	playShotSound(w.Name)
	addRecoil(w.Name)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		holding = true
		if not WEAPONS[currentIndex].Auto then shoot() end -- 단발 무기는 클릭당 1발
	elseif input.KeyCode == Enum.KeyCode.R then
		ReloadEvent:FireServer()
	else
		for i, w in ipairs(WEAPONS) do
			if input.KeyCode == w.Key then equip(i) end
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		holding = false
	end
end)

-- 마우스 휠로 교체
UserInputService.InputChanged:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		equip(currentIndex + (input.Position.Z > 0 and -1 or 1))
	end
end)

RunService.RenderStepped:Connect(function()
	if holding and WEAPONS[currentIndex].Auto then shoot() end
end)

player.CameraMode = Enum.CameraMode.LockFirstPerson
