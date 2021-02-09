if SERVER then
	AddCSLuaFile()
	AddCSLuaFile("hooks.lua")

	resource.AddWorkshop("1473581448")

	util.AddNetworkString("TTTDFSYNC")
	util.AddNetworkString("TTTDFTrackNotification")
end

include("hooks.lua")

local DFROLES = {}

DFROLES.Roles = {
	{ROLE_TRAITOR, "Traitor", Color(250, 20, 20)},
	{ROLE_INNOCENT, "Innocent", Color(20, 250, 20)},
	{ROLE_DETECTIVE, "Detective", Color(20, 20, 250)}
}

if CLIENT then
	SWEP.PrintName = "Death Faker"
	SWEP.Slot = 6
	SWEP.EquipMenuData = {
		type = "item_weapon",
		name = "Death Faker",
		desc = [[
Left-Click:		Spawns a dead body
Reload:			Configure the body
Right-Click:	Quickly change the role of the body
]]
	}
	SWEP.Icon = "vgui/ttt/icon_death_faker_vgui.png"
end

SWEP.HoldType = "slam"
SWEP.Base = "weapon_tttbase"

SWEP.Kind = WEAPON_NONE
SWEP.CanBuy = {ROLE_TRAITOR, ROLE_DETECTIVE}
SWEP.WeaponID = AMMO_BODYSPAWNER

SWEP.UseHands = true
SWEP.ViewModelFlip = false
SWEP.ViewModelFOV = 54
SWEP.ViewModel = Model("models/weapons/cstrike/c_c4.mdl")
SWEP.WorldModel = Model("models/weapons/w_c4.mdl")

SWEP.DrawCrosshair = false
SWEP.ViewModelFlip = false
SWEP.Primary.ClipSize = -1
SWEP.Primary.DefaultClip = -1
SWEP.Primary.Automatic = false
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = 0.1

SWEP.Secondary.ClipSize = -1
SWEP.Secondary.DefaultClip = -1
SWEP.Secondary.Automatic = false
SWEP.Secondary.Ammo = "none"
SWEP.Secondary.Delay = 0.1

SWEP.NoSights = true

local identify = CreateConVar("ttt_df_identify_body", 0, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Should the fake body automatically get identified by a random player after being dropped")
local trackingTime = GetConVar("ttt_df_tracking_time")

local function firstToUpper(str)
	return str:gsub("^%l", string.upper)
end

local function GetSidekickTableForRole(role)
	if role ~= nil then
		local siki_deagle = GetEquipmentByName("weapon_ttt2_sidekickdeagle")
		if istable(siki_deagle) and istable(siki_deagle.CanBuy) and table.HasValue(siki_deagle.CanBuy, role.index) and isfunction(GetDarkenColor) then
			local siki_mod_table =  table.Copy(GetRoleByIndex(ROLE_SIDEKICK))
			siki_mod_table.color = GetDarkenColor(role.color)
			siki_mod_table.dkcolor = GetDarkenColor(role.dkcolor)
			siki_mod_table.bgcolor = GetDarkenColor(role.bgcolor)
			return siki_mod_table
		end
	end
end

if CLIENT then
	net.Receive("TTTDFSYNC", function()
		local size = net.ReadUInt(ROLE_BITS)

		DFROLES.Roles = {}

		for i = 1, size do
			local role = net.ReadUInt(ROLE_BITS)
			local v = GetRoleByIndex(role)
			local color = v.color
			if role == ROLE_SIDEKICK then
				color = net.ReadColor()
			end

			DFROLES.Roles[#DFROLES.Roles + 1] = {
				role,
				firstToUpper(v.name),
				color
			}
		end
	end)

	net.Receive("TTTDFTrackNotification", function()
		local tracked = net.ReadEntity()
		local startTime = CurTime()

		if (LocalPlayer().trackedDFPlayers == nil or LocalPlayer().trackedDFStarttimes == nil) then
			LocalPlayer().trackedDFPlayers = {}
			LocalPlayer().trackedDFStarttimes = {}
		end

		table.insert(LocalPlayer().trackedDFPlayers, tracked)
		table.insert(LocalPlayer().trackedDFStarttimes, startTime)

		local trackingTimeFloat = trackingTime:GetFloat()

		chat.AddText(
			Color(200, 20, 20),
			"[Death Faker] ",
			Color(250, 250, 250),
			"Your fake body was searched by ",
			tracked,
			". You will now track him for ",
			tostring(trackingTimeFloat),
			" seconds."
		)

		chat.PlaySound()

	end)
else
	hook.Add("TTTBeginRound", "TTTDFInit", function()
		if TTT2 then
			DFROLES.Roles = {{
						TRAITOR.index,
						firstToUpper(TRAITOR.name),
						TRAITOR.color
					}}

			local t_siki = GetSidekickTableForRole(TRAITOR)
			if t_siki then
				DFROLES.Roles[#DFROLES.Roles + 1] = {
				t_siki.index,
				firstToUpper(t_siki.name),
				t_siki.color
				}
			end

			for _, v in pairs(GetRoles()) do
				if IsRoleSelectable(v) and v.index ~= TRAITOR.index then
					DFROLES.Roles[#DFROLES.Roles + 1] = {
						v.index,
						firstToUpper(v.name),
						v.color
					}

					local siki = GetSidekickTableForRole(v)
					if siki then
						DFROLES.Roles[#DFROLES.Roles + 1] = {
						siki.index,
						firstToUpper(siki.name),
						siki.color
						}
					end
				end
			end

			net.Start("TTTDFSYNC")
			net.WriteUInt(#DFROLES.Roles, ROLE_BITS)

			for i = 1, #DFROLES.Roles do
				local roleIndex = DFROLES.Roles[i][1]
				net.WriteUInt(roleIndex, ROLE_BITS)
				if roleIndex == ROLE_SIDEKICK then
					net.WriteColor(DFROLES.Roles[i][3])
				end
			end

			net.Broadcast()
		end
	end)
end

function SWEP:Initialize()
	if ConVarExists("ttt_vote") then
		DFROLES.Roles = {}

		for k, v in pairs(TTTRoles) do
			local convar = "ttt_" .. v.String .. "_enabled"

			if v.IsDefault or not ConVarExists(convar) or GetConVar(convar):GetBool() then
				DFROLES.Roles[#DFROLES.Roles + 1] = {
					k,
					v.Rolename,
					v.DefaultColor
				}
			end
		end
	end

	self.CurrentRole = DFROLES.Roles[1]
	self.ReloadingTime = CurTime()

	if CLIENT then
		if TTT2 then
			self:AddTTT2HUDHelp("Spawn a corpse", "Quickly change the role of the corpse")
			self:AddHUDHelpLine("Customize the corpse (name, role, cause of death)", Key("+reload", "R"))
		else
			self:AddHUDHelp("MOUSE2 to quickly change the role of the corpse", "Reload to customize the corpse (name, role, cause of death)", false)
		end
	end
end

function SWEP:CreateGUI()
	local ply = LocalPlayer()

	local w, h = 300, 195

	local Panel = vgui.Create("DFrame")
	--Panel:SetPaintBackground(false)
	Panel:SetSize(w, h)
	Panel:Center()
	Panel:MakePopup()
	Panel:IsActive()
	Panel:SetTitle("Death Faker Config")
	Panel:SetVisible(true)
	Panel:ShowCloseButton(true)
	Panel:SetMouseInputEnabled(true)
	Panel:SetDeleteOnClose(true)
	Panel:SetKeyboardInputEnabled(false)

	local FakeCreditsCB = vgui.Create("DCheckBoxLabel", Panel)
	FakeCreditsCB:SetText("Fake Credits")
	FakeCreditsCB:SetPos(10, 30)
	FakeCreditsCB:SetSize(100, 20)
	FakeCreditsCB:SetChecked(ply.df_fakecredits)
	FakeCreditsCB.OnChange = function()
		if FakeCreditsCB:GetChecked() then
			RunConsoleCommand("ttt_df_fakecredits", "1")
			ply.df_fakecredits = true
		else
			RunConsoleCommand("ttt_df_fakecredits", "0")
			ply.df_fakecredits = false
		end
	end

	local HeadshotCB = vgui.Create("DCheckBoxLabel", Panel)
	HeadshotCB:SetText("Headshot")
	HeadshotCB:SetPos(10, 50)
	HeadshotCB:SetSize(100, 20)
	HeadshotCB:SetChecked(ply.df_headshot)
	HeadshotCB.OnChange = function()
		if HeadshotCB:GetChecked() then
			RunConsoleCommand("ttt_df_headshot", "1")
			ply.df_headshot = true
			ply.bloodmode = true
		else
			RunConsoleCommand("ttt_df_headshot", "0")
			ply.df_headshot = false
			ply.bloodmode = false
		end
	end

	local DLabel = vgui.Create("DLabel", Panel)
	DLabel:SetPos(10, 70)
	DLabel:SetSize(100, 20)
	DLabel:SetText("Body Name:")

	local NameComboBox = vgui.Create("DComboBox", Panel)
	NameComboBox:SetPos(150, 70)
	NameComboBox:SetSize(140, 20)

	local plys = player.GetAll()
	local value = ply:Name()

	if ply.df_bodyname and player.GetByUniqueID(ply.df_bodyname) then
		value = player.GetByUniqueID(ply.df_bodyname):Name()
	end

	NameComboBox:SetValue(value)
	for i = 1, #plys do
		NameComboBox:AddChoice(plys[i]:Name(), plys[i]:UniqueID())
	end

	NameComboBox.OnSelect = function(panel, index, _, data)
		RunConsoleCommand("ttt_df_select_player", data)

		ply.df_bodyname = data
	end

	local DLabel2 = vgui.Create("DLabel", Panel)
	DLabel2:SetPos(10, 95)
	DLabel2:SetSize(100, 20)
	DLabel2:SetText("Body Role:")

	local RoleComboBox = vgui.Create("DComboBox", Panel)
	RoleComboBox:SetPos(150, 95)
	RoleComboBox:SetSize(140, 20)

	local data = 1

	if ply.df_role then
		data = ply.df_role
	end

	if TTT2 then
		for _, v in ipairs(DFROLES.Roles) do
			RoleComboBox:AddChoice(v[2], v[1], data == v[1])
		end
	elseif ConVarExists("ttt_vote") then
		for k, v in pairs(TTTRoles) do
			local convar = "ttt_" .. v.String .. "_enabled"

			if v.IsDefault or not ConVarExists(convar) or GetConVar(convar):GetBool() then
				RoleComboBox:AddChoice(v.Rolename, k, data == k)
			end
		end
	else
		RoleComboBox:AddChoice("Innocent", ROLE_INNOCENT, data == ROLE_INNOCENT)
		RoleComboBox:AddChoice("Traitor", ROLE_TRAITOR, data == ROLE_TRAITOR)
		RoleComboBox:AddChoice("Detective", ROLE_DETECTIVE, data == ROLE_DETECTIVE)

		local jackal_enabled = ConVarExists("ttt_jackal_enabled") and GetConVar("ttt_jackal_enabled"):GetInt() == 1
		local dealer_enabled = false

		for _, v in ipairs(player.GetAll()) do
			if v:GetRole() == ROLE_DEALER then
				dealer_enabled = true

				break
			end
		end

		if ConVarExists("ttt_vote") then
			jackal_enabled = true
		end

		if jackal_enabled then
			RoleComboBox:AddChoice("Jackal", ROLE_JACKAL, data == ROLE_JACKAL)
			RoleComboBox:AddChoice("Sidekick", ROLE_SIDEKICK, data == ROLE_SIDEKICK)
		end

		if dealer_enabled then
			RoleComboBox:AddChoice("Dealer", ROLE_DEALER, data == ROLE_DEALER)
		end
	end

	RoleComboBox.OnSelect = function(panel, index, _, dat)
		RunConsoleCommand("ttt_df_select_role", dat)

		ply.df_role = dat
	end

	local floatingY = 120
	if TTTC and GetGlobalBool("ttt2_classes") then
		local DLabel4 = vgui.Create("DLabel", Panel)
		DLabel4:SetPos(10, floatingY)
		DLabel4:SetSize(100, 20)
		DLabel4:SetText("Body Class:")

		if not ply.df_class then
			ply.df_class = 1
		end

		local ClassComboBox = vgui.Create("DComboBox", Panel)
		ClassComboBox:SetPos(150, floatingY)
		ClassComboBox:SetSize(140, 20)

		for _, v in pairs(CLASS.GetSortedClasses()) do
			ClassComboBox:AddChoice(CLASS.GetClassTranslation(v), v.index, ply.df_class == v.index)
		end

		ClassComboBox.OnSelect = function(panel, index, _, dat)
			RunConsoleCommand("ttt_df_select_class", dat)

			ply.df_class = dat
		end

		floatingY = floatingY + 25
	end

	local DLabel3 = vgui.Create("DLabel", Panel)
	DLabel3:SetPos(10, floatingY)
	DLabel3:SetSize(100, 20)
	DLabel3:SetText("Used Weapon:")

	local WeaponCB = vgui.Create("DComboBox", Panel)
	WeaponCB:SetPos(150, floatingY)
	WeaponCB:SetSize(140, 20)

	local weps = weapons.GetList()

	if not ply.df_weapon then
		ply.df_weapon = "weapon_ttt_m16"
	end

	for i = 1, #weps do
		if weps[i]["Base"] == "weapon_tttbase" and weps[i]["Primary"]["Ammo"] ~= "none" then
			WeaponCB:AddChoice(weps[i]["PrintName"], weps[i]["ClassName"], weps[i]["ClassName"] == ply.df_weapon)
		end
	end

	WeaponCB:AddChoice("Fall Damage", "-1", ply.df_weapon == "-1")
	WeaponCB:AddChoice("Explosion Damage", "-2", ply.df_weapon == "-2")
	WeaponCB:AddChoice("Object Damage", "-3", ply.df_weapon == "-3")
	WeaponCB:AddChoice("Fire Damage", "-4", ply.df_weapon == "-4")
	WeaponCB:AddChoice("Water Damage", "-5", ply.df_weapon == "-5")

	WeaponCB.OnSelect = function(panel, index, _, dat)
		RunConsoleCommand("ttt_df_select_weapon", dat)

		ply.df_weapon = dat
	end

	self.GUI = Panel
end

function SWEP:PrimaryAttack()
	local ply = self:GetOwner()

	if not IsValid(ply) then return end

	if not ply.df_role then
		ply.df_role = self.CurrentRole[1]
	end

	if SERVER then
		self:BodyDrop()
		self:Remove()
	end
end

function SWEP:SecondaryAttack()
	if not IsFirstTimePredicted() then return end

	local key = 0
	local currentRole = self.CurrentRole[1]
	if self:GetOwner().df_role then
		currentRole = self:GetOwner().df_role
	end

	for k, v in ipairs(DFROLES.Roles) do
		if v[1] == currentRole then
			key = k

			break
		end
	end

	key = key + 1

	if key > #DFROLES.Roles then
		key = 1
	end

	self.CurrentRole = DFROLES.Roles[key]
	self:GetOwner().df_role = self.CurrentRole[1]

	if CLIENT then
		chat.AddText(
			Color(200, 20, 20),
			"[Death Faker] ",
			Color(250, 250, 250),
			"Your body's role will be ",
			self.CurrentRole[3],
			self.CurrentRole[2]
		)
		chat.PlaySound()
	end
end

local function changeBodyModel(ply, dead, rag)
	rag:SetModel(dead:GetModel())
	rag:SetSkin(dead:GetSkin())
	rag:SetColor(dead:GetColor())

	-- To enable changes respawn and activate ragdoll again for a new physics model
	rag:Spawn()
	rag:Activate()

	-- Get relative position of the using player to the "dead" player
	local relPos = ply:GetPos() - dead:GetPos()
	local relAng = ply:GetAngles() - dead:GetAngles()

	-- Now correct the bones
	local num = (rag:GetPhysicsObjectCount() - 1)
	for i = 0, num do
		local bone = rag:GetPhysicsObjectNum(i)

		if IsValid(bone) then
			local bp, ba = dead:GetBonePosition(rag:TranslatePhysBoneToBone(i))

			if bp and ba then
				bone:SetPos(bp + relPos)
				bone:SetAngles(ba + relAng)
			end
		end
	end
end

-- This function keeps the nickname, but disables any related entity, that could get revived
-- Uses direct Datatable access and needs to be called after setting a nickname
-- TODO: Disable Revive either with this hack or by modifying TTT2 directly
local function disableRevive(rag)
	--local dti = CORPSE.dti

	--rag:SetDTEntity(dti.ENT_PLAYER, nil)
end

function SWEP:BodyDrop()
	local dmg = DamageInfo()

	local ply = self:GetOwner()

	local dead = ply

	if ply.df_bodyname then
		dead = player.GetByUniqueID(ply.df_bodyname) or dead
	end

	dmg:SetAttacker(ply)
	dmg:SetDamage(10)

	if ply.df_weapon == "-1" then
		dmg:SetDamageType(DMG_FALL)
	elseif ply.df_weapon == "-2" then
		dmg:SetDamageType(DMG_BLAST)
	elseif ply.df_weapon == "-3" then
		dmg:SetDamageType(DMG_CRUSH)
	elseif ply.df_weapon == "-4" then
		dmg:SetDamageType(DMG_BURN)
	elseif ply.df_weapon == "-5" then
		dmg:SetDamageType(DMG_DROWN)
	else
		dmg:SetDamageType(DMG_BULLET)
	end

	dead:SetNWBool("FakedDeath", true)

	local rag = CORPSE.Create(ply, ply, dmg)
	CORPSE.SetCredits(rag, 0)
	CORPSE.SetPlayerNick(rag, dead)

	disableRevive(rag) -- TODO: Disable Revive

	if dead ~= ply then changeBodyModel(ply, dead, rag) end

	rag.sid = dead:SteamID()
	rag.sid64 = dead:SteamID64()

	rag.is_fake = true
	rag:SetNWBool("IsFakeBody", true)

	rag:SetNWEntity("FakeBodyCreator", ply)

	dead.fake_corpse = rag -- Tie the body to the player

	if TTTC then
		dead.oldClass = ply.df_class
	end

	if not ply.df_weapon then
		rag.dmgwep = "weapon_ttt_m16"
	elseif weapons.Get(ply.df_weapon) then
		rag.dmgwep = ply.df_weapon
	else
		rag.dmgwep = ""
	end

	if not ply.df_headshot then
		rag.was_headshot = false
	else
		rag.was_headshot = ply.df_headshot
	end

	if not ply.df_fakecredits then
		rag:SetNWBool("FakeCredits", false)
	else
		rag:SetNWBool("FakeCredits", ply.df_fakecredits)
	end

	if ply.df_role then
		rag.was_role = ply.df_role
	else
		rag.was_role = 1
	end

	rag.killer_sample = nil

	dead:SetNWInt("FakeCorpseRole", rag.was_role)
	local key = 0
	for k, v in ipairs(DFROLES.Roles) do
		if v[1] == ply.df_role then
			key = k

			break
		end
	end
	dead:SetNWInt("FakeCorpseIndex", key)
	rag.role_color = DFROLES.Roles[key][3]

	rag:EmitSound("vo/npc/male01/pain07.wav")

	if identify:GetBool() then -- Automatically identify the body after dropping it
		CORPSE.SetFound(rag, true)

		if TTT2 then
			dead:TTT2NETSetBool("body_found", true)
		end
		dead:SetNWBool("body_found", true)

		-- We are going to use a random player to identify this fake body.
		local finder = table.Random(player.GetAll())
		if finder == dead or finder:IsSpec() or not finder:Alive() then
			finder = table.Random(player.GetAll())
		end

		for _, v in ipairs(player.GetAll()) do -- Tell the other player's that this body has been 'found'
			CustomMsg(v, finder:Nick() .. " found the body of " .. dead:Nick() .. ". He was a Traitor!", color_white)
		end
	end

	for i = 1, 10 do
		local jitter = VectorRand() * 60
		jitter.z = 20

		util.PaintDown(rag:GetPos() + jitter, "Blood", rag)
	end

	return rag
end

function SWEP:Reload()
	if not IsFirstTimePredicted() or SERVER or CurTime() <= self.ReloadingTime then return end

	if not self.GUI or not self.GUI:IsValid() then
		self:CreateGUI()
	else
		self.GUI:Close()
	end

	self.ReloadingTime = CurTime() + 0.2
end

function SWEP:OnRemove()
	if CLIENT and IsValid(self:GetOwner()) and self:GetOwner() == LocalPlayer() and self:GetOwner():Alive() then
		RunConsoleCommand("lastinv")
	end
end

if SERVER then
	function SelectHeadshot(ply, cmd, args)
		if #args ~= 1 then return end

		if args[1] == "0" then
			ply.df_headshot = false
		else
			ply.df_headshot = true
		end
	end
	concommand.Add("ttt_df_headshot", SelectHeadshot)

	function SelectFakeCredits(ply, cmd, args)
		if #args ~= 1 then return end

		if args[1] == "0" then
			ply.df_fakecredits = false
		else
			ply.df_fakecredits = true
		end
	end
	concommand.Add("ttt_df_fakecredits", SelectFakeCredits)

	function SelectWeapon(ply, cmd, args)
		if #args ~= 1 then return end

		ply.df_weapon = args[1]
	end
	concommand.Add("ttt_df_select_weapon", SelectWeapon)

	function SelectRole(ply, cmd, args)
		if #args ~= 1 then return end

		ply.df_role = math.floor(args[1])
	end
	concommand.Add("ttt_df_select_role", SelectRole)

	function SelectClass(ply, cmd, args)
		if #args ~= 1 then return end

		ply.df_class = args[1]
	end
	concommand.Add("ttt_df_select_class", SelectClass)

	function SelectPlayer(ply, cmd, args)
		if #args ~= 1 then return end

		ply.df_bodyname = args[1]
	end
	concommand.Add("ttt_df_select_player", SelectPlayer)
end

if TTT2 then
	hook.Add("TTTScoreboardRowColorForPlayer", "FakeBodyColorFake", function(ply)
		if IsValid(ply) and ply:GetNWBool("FakedDeath") and ply:TTT2NETGetBool("body_found") then
			local role = ply:GetNWInt("FakeCorpseRole")
			local color = Color(0, 0, 0, 0)

			if role ~= ROLE_INNOCENT then
				local index = ply:GetNWInt("FakeCorpseIndex")
				color = DFROLES.Roles[index][3]
			end

			return color
		end
	end)

	hook.Add("TTT2ModifyMiniscoreboardColor", "FakeBodyColorFake", function(ply, col)
		if IsValid(ply) and ply:GetNWBool("FakedDeath") and ply:TTT2NETGetBool("body_found") then
			--local role = ply:GetNWInt("FakeCorpseRole")
			local color = Color(0, 0, 0, 0)


			local index = ply:GetNWInt("FakeCorpseIndex")
			color = DFROLES.Roles[index][3]

			color = Color(color.r, color.g, color.b, col.a)

			return color
		end
	end)
else
	hook.Add("TTTScoreboardRowColorForPlayer", "FakeBodyColorFake", function(ply)
		if IsValid(ply) and ply:GetNWBool("FakedDeath") and ply:GetNWBool("body_found") then
			local role = ply:GetNWInt("FakeCorpseRole")
			local color = Color(0, 0, 0, 0)

			if role == ROLE_INNOCENT then
				color = Color(0, 0, 0, 0)
			elseif role == ROLE_TRAITOR then
				color = Color(255, 0, 0, 30)
			elseif role == ROLE_DETECTIVE then
				color = Color(0, 0, 255, 30)
			elseif ConVarExists("ttt_vote") then
				local color3 = GetRoleTableByID(role).DefaultColor
				color = Color(color3.r, color3.g, color3.b, 70)
			end

			return color
		end
	end)
end
