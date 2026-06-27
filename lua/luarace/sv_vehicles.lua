--[[ Server: per-player vehicle choices + spawning the role car at race start. ]]

LuaRace = LuaRace or {}

-- [SteamID64] = { [ROLE_RUNNER] = class, [ROLE_COP] = class }
LuaRace.Choices = LuaRace.Choices or {}

-- Vehicles spawned by the addon this round (cleaned up on reset).
LuaRace.SpawnedVehicles = LuaRace.SpawnedVehicles or {}

-- Receive a player's preferred car for a given role.
net.Receive( "LuaRace.PickVehicle", function( _, ply )
	if not IsValid( ply ) then return end

	local role  = net.ReadUInt( 3 )
	local class = net.ReadString()

	if role ~= LuaRace.ROLE_RUNNER and role ~= LuaRace.ROLE_COP then return end
	if not LuaRace.IsAllowedVehicle( role, class ) then return end

	local id = ply:SteamID64()
	LuaRace.Choices[ id ] = LuaRace.Choices[ id ] or {}

	-- Only confirm in chat when it actually changes (avoids spam on the
	-- automatic sync at spawn), and only to this player: the choice is
	-- strictly individual.
	if LuaRace.Choices[ id ][ role ] ~= class then
		local roleName = role == LuaRace.ROLE_RUNNER and "Fuyard" or "Police"
		ply:ChatPrint( "[LuaRace] Votre voiture (" .. roleName .. ") : " .. LuaRace.VehicleLabel( class ) )
	end

	LuaRace.Choices[ id ][ role ] = class
end )

-- Which car should this player get for this role? (choice or default)
function LuaRace.GetChosenVehicle( ply, role )
	local id = ply:SteamID64()
	local choice = LuaRace.Choices[ id ] and LuaRace.Choices[ id ][ role ]
	if choice and LuaRace.IsAllowedVehicle( role, choice ) then
		return choice
	end
	return LuaRace.DefaultVehicle( role )
end

-- Trace down from a position to find a safe spawn height on the ground.
local function groundPos( pos )
	local tr = util.TraceLine( {
		start  = pos + Vector( 0, 0, 64 ),
		endpos = pos - Vector( 0, 0, 256 ),
		mask   = MASK_SOLID_BRUSHONLY,
	} )
	return ( tr.Hit and tr.HitPos or pos ) + Vector( 0, 0, 20 )
end

-- Spawn `class` for `ply` near where they stand and seat them in it.
local function spawnFor( ply, class )
	local ang = Angle( 0, ply:EyeAngles().yaw, 0 )
	local pos = groundPos( ply:GetPos() + ang:Forward() * 60 )

	local veh = ents.Create( class )
	if not IsValid( veh ) then
		-- Class not registered (NFS pack missing?) -> tell the player.
		ply:ChatPrint( "[LuaRace] Vehicule introuvable: " .. class .. " (pack NFS installe ?)" )
		return nil
	end

	veh:SetPos( pos )
	veh:SetAngles( ang )
	veh:Spawn()
	veh:Activate()

	if Glide and Glide.SetEntityCreator then
		Glide.SetEntityCreator( veh, ply )
	end

	-- Seat them a tick later so the Glide vehicle is fully initialised.
	timer.Simple( 0.15, function()
		if IsValid( veh ) and IsValid( ply ) then
			ply:EnterVehicle( veh )
		end
	end )

	return veh
end

-- Spawn every participant's role car. Called when a race starts.
function LuaRace.SpawnRoleVehicles()
	if LuaRace.Cvar( "give_vehicles" ) < 1 then return end

	LuaRace.CleanupVehicles()

	for _, ply in player.Iterator() do
		if LuaRace.IsParticipant( ply ) then
			-- Get them out of whatever they're in first.
			if ply:InVehicle() then ply:ExitVehicle() end

			local role  = LuaRace.GetRole( ply )
			local class = LuaRace.GetChosenVehicle( ply, role )
			local veh   = spawnFor( ply, class )
			if IsValid( veh ) then
				LuaRace.SpawnedVehicles[ #LuaRace.SpawnedVehicles + 1 ] = veh
			end
		end
	end
end

-- Remove all addon-spawned vehicles (ejects occupants automatically).
function LuaRace.CleanupVehicles()
	for _, veh in ipairs( LuaRace.SpawnedVehicles ) do
		if IsValid( veh ) then veh:Remove() end
	end
	LuaRace.SpawnedVehicles = {}
end
