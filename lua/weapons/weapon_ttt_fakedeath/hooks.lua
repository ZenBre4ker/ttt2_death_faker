local explode = CreateConVar("ttt_df_explode_on_real_confirm", 0, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_REPLICATED}, "Should the fake body explodes, if the real players body is confirmed")
local trackingTime = CreateConVar("ttt_df_tracking_time", 30, {FCVAR_SERVER_CAN_EXECUTE, FCVAR_ARCHIVE, FCVAR_REPLICATED}, "The time a player is tracked after searching a fake body")

local icon_tid_credits = Material("vgui/ttt/tid/tid_credits")

if TTT2 then
	local function GetFakedDeathGroup(ply)
		if ply:GetNWBool("FakedDeath", false) and ply:TTT2NETGetBool("body_found", false) then
			return GROUP_FOUND
		end
	end
	hook.Add("TTTScoreGroup", "PutsPlayerInRightGroup", GetFakedDeathGroup)
	
	-- add fake credits
	hook.Add("TTTRenderEntityInfo", "FakeBodyFakeCredits", function(tData)
		local client = LocalPlayer()
		local ent = tData:GetEntity()

		-- has to be a ragdoll
		if not IsValid(ent) or ent:GetClass() ~= "prop_ragdoll" then return end
	

		-- add credits info when corpse has credits
		if client:IsActive() and client:IsShopper() and ent:GetNWBool("FakeCredits") then
			tData:AddDescriptionLine(
				LANG.TryTranslation("target_credits"),
				COLOR_YELLOW,
				{icon_tid_credits}
			)
		end
	end)
	
	hook.Add("PreDrawOutlines", "DFTrackConfirmer", function()
		local client = LocalPlayer()

		if client.trackedDFPlayers != nil then
			for i = 1,table.Count(client.trackedDFPlayers) do 
				local tracked = client.trackedDFPlayers[i]
				local startTime = client.trackedDFStarttimes[i]
				
				if IsValid(tracked) && !tracked:GetNoDraw() && startTime + trackingTime:GetFloat() > CurTime() then
					outline.Add(tracked, Color(255, 50, 50))
				end
			end
		end
	end)
else
	local function GetFakedDeathGroup(ply)
		if ply:GetNWBool("FakedDeath", false) and ply:GetNWBool("body_found", false) then
			return GROUP_FOUND
		end
	end
	hook.Add("TTTScoreGroup", "PutsPlayerInRightGroup", GetFakedDeathGroup)
	
	hook.Add("HUDDrawTargetID", "FakeBodyCreditFake", function()
		
		local MAX_TRACE_LENGTH = math.sqrt(3) * 2 * 16384
		local client = LocalPlayer()
		
		local startpos = client:EyePos()
		local endpos = client:GetAimVector()
		endpos:Mul(MAX_TRACE_LENGTH)
		endpos:Add(startpos)

		local trace = util.TraceLine({
		  start = startpos,
		  endpos = endpos,
		  mask = MASK_SHOT,
		  filter = client:GetObserverMode() == OBS_MODE_IN_EYE and {client, client:GetObserverTarget()} or client
		})
		local ent = trace.Entity
		
		local canSeeCredits = false
		
		if TTT2 then
			if client:IsActive() and client:IsShopper() then
				canSeeCredits = true
			end
		elseif ConVarExists("ttt_vote") then
			if client:IsActiveEvil() then
				canSeeCredits = true
			end
		else
			if client:IsActiveTraitor() then
				canSeeCredits = true
			end
		end
		
		--print("test")
		if IsValid(ent) and ent:GetClass() == "prop_ragdoll" and ent:GetNWBool("IsFakeBody") and ent:GetNWBool("FakeCredits") and canSeeCredits then
				
			local GetLang = LANG.GetUnsafeLanguageTable
			local L = GetLang()
			
			local font = "TargetIDSmall"
			surface.SetFont(font)
			local text = L.target_credits
			local clr = COLOR_YELLOW
			
			local y = ScrH() / 2.0 + 95
			local w, h = surface.GetTextSize( text )
			local x = (ScrW() / 2.0) - (w / 2.0)
			--y = y + h + 5

			draw.SimpleText( text, font, x+1, y+1, COLOR_BLACK )
			draw.SimpleText( text, font, x, y, clr )
		end
	end)
	
	hook.Add("PreDrawHalos","DFTrackConfirmer", function()
		local tbl = {}
		if LocalPlayer().trackedDFPlayers != nil then
			for i = 1,table.Count(LocalPlayer().trackedDFPlayers) do 
				local tracked = LocalPlayer().trackedDFPlayers[i]
				local startTime = LocalPlayer().trackedDFStarttimes[i]
				
				if IsValid(tracked) && !tracked:GetNoDraw() && startTime + trackingTime:GetFloat() > CurTime() then
					table.insert(tbl, tracked)
				end
			end
			
			halo.Add(tbl,Color(0,255,0),2,2,2,true,true)
		end
	end)
end

local function ModifySearch(processed, raw)
	local plys = player.GetAll()
	local ply

	for i = 1, #plys do
		if plys[i]:Name() == raw.nick then
			ply = plys[i]
		end
	end

	raw.owner = ply
end
hook.Add("TTTBodySearchPopulate", "ModifiesTheSearch", ModifySearch)

hook.Add("TTTPrepareRound", "RemoveDeathFakers", function()
	for k, v in ipairs(player.GetAll()) do
		v:SetNWBool("FakedDeath", false)
		
		v.trackedDFPlayers = {}
		v.trackedDFStarttimes = {}		
		
		v.df_class = nil
		v.df_bodyname = nil
		v.df_role = nil
	end
end)

hook.Add("TTTCanIdentifyCorpse", "GetTrueRoleColorBack", function(ply, corpse, was_traitor)
	local confirmed = CORPSE.GetPlayer(corpse)
	if not corpse.is_fake and IsValid(confirmed) then
		
		confirmed:SetNWBool("FakedDeath", false)

		local fakeBody = confirmed.fake_corpse

		if not explode:GetBool() or not IsValid(fakeBody) then return end

		confirmed:SetNWBool("FakedDeath", false)
		fakeBody:Ignite(5, 5) -- Replicate the burning of a body

		util.PaintDown(fakeBody:GetPos(), "Scorch", fakeBody) -- TTT specific function

		timer.Simple(5, function()
			for k, v in ipairs(player.GetAll()) do -- Tell our Traitor friends that someone's body exploded
				if v:GetRole() == ROLE_TRAITOR then
					CustomMsg(v, confirmed:Nick() .. "'s fake body has been detonated!", Color(200, 0, 0))
				end
			end

			local expl = ents.Create("env_explosion") -- Create a tiny explosion for effect
			expl:SetPos(fakeBody:GetPos()) -- Put it where our body currently is
			expl:SetOwner(confirmed) -- The body owner takes credit it anyone gets damaged...
			expl:Spawn()
			expl:SetKeyValue("iMagnitude", "10")
			expl:Fire("Explode", 0, 0) -- Kablam
			expl:EmitSound("siege/big_explosion.wav", 200, 200)

			fakeBody:Remove()

			confirmed.fake_corpse = nil
		end)
	end
	
	if corpse.is_fake and IsValid(ply) then
		local confirmed = player.GetBySteamID64(corpse.sid64)
		
		if TTT2 then
			confirmed:TTT2NETSetBool("body_found", true)
			confirmed:TTT2NETSetBool("role_found", true)
			if confirmed:TTT2NETGetFloat("t_first_found", -1) < 0 then
				confirmed:TTT2NETSetFloat("t_first_found", CurTime())
			end
			confirmed:TTT2NETSetFloat("t_last_found", CurTime())
		end
			
		local creator = corpse:GetNWEntity("FakeBodyCreator")
		if creator != ply then
			
			net.Start("TTTDFTrackNotification")
			net.WriteEntity(ply)
			net.Send(creator)
		end
	end
end)

if TTTC then

end

