if engine.ActiveGamemode() ~= "nzombies" then return end

resource.AddSingleFile("materials/bar/bloodline_bar.png")
resource.AddSingleFile("materials/bar/bloodline_bar_back.png")
util.AddNetworkString("nz_progress_bar")

--locals
local player_sync_cooldowns = {}
local nz_progbar_update_rate = CreateConVar("nz_progbar_update_rate", "0.25", bit.bor(FCVAR_NOTIFY, FCVAR_NEVER_AS_STRING, FORCE_NUMBER), "Delay between updates to the client. Lower values, mean more frequent but higher cost.", 0.1, 10.0)
local update_rate = nz_progbar_update_rate:GetFloat()
local zombies_killed = 0
local zombies_killed_cache = 0

--local functions
local function stop_client_update_timer() timer.Remove("nz_progress_bar") end

--hooks
hook.Add("OnRoundCreative", "NZProgressBar", stop_client_update_timer)
hook.Add("OnRoundEnd", "NZProgressBar", stop_client_update_timer)
hook.Add("OnRoundPreparation", "NZProgressBar", stop_client_update_timer)

hook.Add("OnRoundStart", "NZProgressBar", function()
	net.Start("nz_progress_bar")
	net.WriteBool(true)
	net.WriteUInt(nzRound:GetZombiesMax(), 32)
	net.Broadcast()
	
	zombies_killed_cache = 0
	
	timer.Create("nz_progress_bar", update_rate, 0, function()
		zombies_killed = nzRound:GetZombiesKilled()
		
		--only send if there has been a change, saves network usage and CPU usage.
		if zombies_killed_cache < zombies_killed then
			net.Start("nz_progress_bar")
			net.WriteBool(false)
			net.WriteUInt(zombies_killed, 32)
			net.Broadcast()
			
			zombies_killed_cache = zombies_killed
		end
	end)
end)

--cvars
cvars.AddChangeCallback("nz_progbar_update_rate", function(name, old_value, new_value) update_rate = nz_progbar_update_rate:GetFloat() or 0.25 end)

--net
net.Receive("nz_progress_bar", function(ply, length)
	local cooldown = player_sync_cooldowns[ply]
	local cur_time = CurTime()
	
	if cooldown and cooldown > cur_time then return end
	
	local zombies_max = nzRound:GetZombiesMax()
	player_sync_cooldowns[ply] = cur_time + 1
		
	if zombies_max and zombies_max > 1 then
		net.Start("nz_progress_bar")
		net.WriteBool(true)
		net.WriteUInt(nzRound:GetZombiesMax(), 32)
		net.Send(ply)
	end
end)