-- 위치: ServerScriptService / GunServer (Script)
-- 무기 여러 종류 지원: 발사 검증, 데미지, 재장전, 킬/데스

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local function makeEvent(name)
	local e = Instance.new("RemoteEvent")
	e.Name = name
	e.Parent = ReplicatedStorage
	return e
end

local ShootEvent = makeEvent("ShootEvent")
local ReloadEvent = makeEvent("ReloadEvent")
local AmmoUpdate = makeEvent("AmmoUpdate")     -- (weaponName, ammo, magSize)
local EquipEvent = makeEvent("EquipEvent")     -- 클라 -> 서버: 무기 변경 요청
local EquipUpdate = makeEvent("EquipUpdate")   -- 서버 -> 클라: 무기 변경 확정
local ShotFx = makeEvent("ShotFx")         -- 서버 -> 다른 플레이어: (위치, 무기) 발사음 재생용
local KillFeed = makeEvent("KillFeed")        -- 서버 -> 전원: (킬러, 킬러팀색, 무기, 희생자, 희생자팀색, 헤드샷)

-- 무기 목록 (클라이언트 스크립트의 WEAPONS와 순서/이름을 맞춰주세요)
local WEAPONS = {
	Pistol = {
		Damage = 25, Pellets = 1, Spread = 0.5,
		FireRate = 0.25, Auto = false,
		MaxRange = 300, MagSize = 12, ReloadTime = 1.5,
	},
	Rifle = {
		Damage = 20, Pellets = 1, Spread = 1.5,
		FireRate = 0.1, Auto = true,
		MaxRange = 500, MagSize = 30, ReloadTime = 2.2,
	},
	Shotgun = {
		Damage = 12, Pellets = 8, Spread = 6,
		FireRate = 0.9, Auto = false,
		MaxRange = 80, MagSize = 6, ReloadTime = 2.8,
	},
	Sniper = {
		Damage = 90, Pellets = 1, Spread = 0,
		FireRate = 1.5, Auto = false,
		MaxRange = 1000, MagSize = 5, ReloadTime = 3.2,
	},
}
local HEADSHOT_MULT = 2
local DEFAULT_WEAPON = "Rifle"
Players.RespawnTime = 3

-- 팀 데스매치 설정 ---------------------------------------
local Teams = game:GetService("Teams")
local KILL_TARGET = 30      -- 먼저 이 킬 수에 도달한 팀 승리
local ROUND_END_DELAY = 8   -- 승리 후 다음 라운드까지 대기(초)

local TEAM_DEFS = {
	{ Name = "Red",  Color = BrickColor.new("Bright red"),  SpawnPos = Vector3.new(-50, 1, 0) },
	{ Name = "Blue", Color = BrickColor.new("Bright blue"), SpawnPos = Vector3.new(50, 1, 0) },
}
local teamObjs, scoreValues = {}, {}

local scoreFolder = Instance.new("Folder")
scoreFolder.Name = "TeamScores"
scoreFolder.Parent = ReplicatedStorage
local statusValue = Instance.new("StringValue")
statusValue.Name = "Status"
statusValue.Parent = scoreFolder
local targetValue = Instance.new("IntValue")
targetValue.Name = "KillTarget"
targetValue.Value = KILL_TARGET
targetValue.Parent = scoreFolder

-- 기존 중립 스폰은 비활성화 (맵에 직접 팀 스폰을 만들었다면 이름을 RedSpawn/BlueSpawn으로)
for _, d in ipairs(Workspace:GetDescendants()) do
	if d:IsA("SpawnLocation") and d.Neutral then d.Enabled = false end
end

for _, def in ipairs(TEAM_DEFS) do
	local team = Instance.new("Team")
	team.Name = def.Name
	team.TeamColor = def.Color
	team.AutoAssignable = false
	team.Parent = Teams
	teamObjs[def.Name] = team

	local score = Instance.new("IntValue")
	score.Name = def.Name .. "Score"
	score.Parent = scoreFolder
	scoreValues[def.Name] = score

	local spawn = Workspace:FindFirstChild(def.Name .. "Spawn")
	if not spawn then
		spawn = Instance.new("SpawnLocation")
		spawn.Name = def.Name .. "Spawn"
		spawn.Size = Vector3.new(14, 1, 14)
		spawn.Position = def.SpawnPos
		spawn.Anchored = true
		spawn.Parent = Workspace
	end
	spawn.Neutral = false
	spawn.TeamColor = def.Color
	spawn.Duration = 3 -- 스폰 보호 (ForceField)
end

local function assignTeam(player)
	local counts = { Red = 0, Blue = 0 }
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Team and counts[p.Team.Name] then
			counts[p.Team.Name] += 1
		end
	end
	player.Team = counts.Red <= counts.Blue and teamObjs.Red or teamObjs.Blue
end

local roundActive = true
local function endRound(winnerName)
	roundActive = false
	statusValue.Value = winnerName .. " 팀 승리!"
	task.delay(ROUND_END_DELAY, function()
		for _, v in pairs(scoreValues) do v.Value = 0 end
		for _, p in ipairs(Players:GetPlayers()) do
			local ls = p:FindFirstChild("leaderstats")
			if ls then ls.Kills.Value = 0 ls.Deaths.Value = 0 end
			p:LoadCharacter()
		end
		statusValue.Value = ""
		roundActive = true
	end)
end

local state = {} -- [player] = {current, ammo = {무기=탄약}, lastShot, reloading, reloadId}

local function resetAmmo(s)
	s.ammo = {}
	for name, w in pairs(WEAPONS) do s.ammo[name] = w.MagSize end
	s.reloading = false
	s.reloadId = (s.reloadId or 0) + 1
end

local function sendAmmo(player)
	local s = state[player]
	local w = WEAPONS[s.current]
	AmmoUpdate:FireClient(player, s.current, s.ammo[s.current], w.MagSize)
end

local function setupPlayer(player)
	state[player] = { current = DEFAULT_WEAPON, lastShot = 0 }
	resetAmmo(state[player])
	assignTeam(player)

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	for _, n in ipairs({ "Kills", "Deaths" }) do
		local v = Instance.new("IntValue")
		v.Name = n
		v.Parent = stats
	end
	stats.Parent = player

	player.CharacterAdded:Connect(function()
		resetAmmo(state[player])
		EquipUpdate:FireClient(player, state[player].current)
		sendAmmo(player)
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
for _, p in ipairs(Players:GetPlayers()) do setupPlayer(p) end
Players.PlayerRemoving:Connect(function(p) state[p] = nil end)

EquipEvent.OnServerEvent:Connect(function(player, weaponName)
	local s = state[player]
	if not s or not WEAPONS[weaponName] or s.current == weaponName then return end
	s.current = weaponName
	s.reloading = false          -- 무기 교체 시 재장전 취소
	s.reloadId += 1
	EquipUpdate:FireClient(player, weaponName)
	sendAmmo(player)
end)

local function applySpread(direction, spreadDeg)
	if spreadDeg <= 0 then return direction.Unit end
	local rad = math.rad(spreadDeg)
	local rx = (math.random() - 0.5) * 2 * rad
	local ry = (math.random() - 0.5) * 2 * rad
	local cf = CFrame.lookAt(Vector3.zero, direction) * CFrame.Angles(rx, ry, 0)
	return cf.LookVector
end

ShootEvent.OnServerEvent:Connect(function(player, origin, direction)
	local s = state[player]
	local char = player.Character
	if not s or not char then return end
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" then return end
	if direction.Magnitude < 0.01 then return end

	local w = WEAPONS[s.current]
	local now = os.clock()
	if s.reloading or s.ammo[s.current] <= 0 then return end
	if now - s.lastShot < w.FireRate * 0.9 then return end

	local root = char:FindFirstChild("HumanoidRootPart")
	if not root or (origin - root.Position).Magnitude > 15 then return end

	s.lastShot = now
	s.ammo[s.current] -= 1
	sendAmmo(player)

	-- 다른 플레이어에게 발사음 전달 (300 스터드 이내)
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local oc = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			if oc and (oc.Position - root.Position).Magnitude < 300 then
				ShotFx:FireClient(other, root.Position, s.current)
			end
		end
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }

	-- 펠릿별 피해 누적 (샷건은 여러 발)
	local damageMap = {}
	local headshotMap = {}
	for _ = 1, w.Pellets do
		local dir = applySpread(direction, w.Spread)
		local result = Workspace:Raycast(origin, dir * w.MaxRange, params)
		if result then
			local model = result.Instance:FindFirstAncestorOfClass("Model")
			local th = model and model:FindFirstChildOfClass("Humanoid")
			if th and th.Health > 0 then
				local dmg = w.Damage
				if result.Instance.Name == "Head" then
					dmg *= HEADSHOT_MULT
					headshotMap[th] = true
				end
				damageMap[th] = (damageMap[th] or 0) + dmg
			end
		end
	end

	for th, dmg in pairs(damageMap) do
		local victim = Players:GetPlayerFromCharacter(th.Parent)
		-- 아군 사격 차단 / 라운드 종료 후 데미지 차단 / 스폰 보호(ForceField)는 엔진이 처리
		local friendly = victim and victim.Team == player.Team
		if th.Health > 0 and roundActive and not friendly then
			th:TakeDamage(dmg)
			if th.Health <= 0 and victim then
				player.leaderstats.Kills.Value += 1
				victim.leaderstats.Deaths.Value += 1
				KillFeed:FireAllClients(
					player.Name,
					player.Team and player.Team.TeamColor.Color or Color3.new(1, 1, 1),
					s.current,
					victim.Name,
					victim.Team and victim.Team.TeamColor.Color or Color3.new(1, 1, 1),
					headshotMap[th] == true
				)
				local tname = player.Team and player.Team.Name
				if tname and scoreValues[tname] then
					scoreValues[tname].Value += 1
					if scoreValues[tname].Value >= KILL_TARGET then
						endRound(tname)
					end
				end
			end
		end
	end
end)

ReloadEvent.OnServerEvent:Connect(function(player)
	local s = state[player]
	if not s or s.reloading then return end
	local name = s.current
	local w = WEAPONS[name]
	if s.ammo[name] >= w.MagSize then return end

	s.reloading = true
	s.reloadId += 1
	local id = s.reloadId
	task.delay(w.ReloadTime, function()
		local cur = state[player]
		if cur and cur.reloadId == id then
			cur.ammo[name] = w.MagSize
			cur.reloading = false
			if cur.current == name then sendAmmo(player) end
		end
	end)
end)
