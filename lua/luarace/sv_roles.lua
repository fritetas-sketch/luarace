--[[ Server: participant gathering, role assignment, head-start enforcement. ]]

LuaRace = LuaRace or {}

-- Who is eligible for the race right now?
function LuaRace.GatherParticipants()
	local requireVeh = LuaRace.Cvar( "require_vehicle" ) >= 1
	local out = {}

	for _, ply in player.Iterator() do
		if ply:Alive() and not ply:IsBot() then
			if not requireVeh or LuaRace.InGlideVehicle( ply ) then
				out[ #out + 1 ] = ply
			end
		end
	end

	return out
end

-- runners = max(1, floor(players / players_per_runner))
-- 7 -> 1, 10 -> 2, 15 -> 3, etc. (the exponential-feeling threshold ladder).
function LuaRace.CalcRunnerCount( numPlayers )
	local per = math.max( 2, LuaRace.Cvar( "players_per_runner" ) )
	return math.max( 1, math.floor( numPlayers / per ) )
end

-- Pick runners at random, everyone else becomes a cop.
function LuaRace.AssignRoles( participants )
	-- Fisher-Yates shuffle so runner selection is fair.
	local pool = table.Copy( participants )
	for i = #pool, 2, -1 do
		local j = math.random( i )
		pool[ i ], pool[ j ] = pool[ j ], pool[ i ]
	end

	local runnerCount = LuaRace.CalcRunnerCount( #pool )

	for index, ply in ipairs( pool ) do
		local role = ( index <= runnerCount ) and LuaRace.ROLE_RUNNER or LuaRace.ROLE_COP

		ply:SetNWInt( LuaRace.NW_ROLE, role )
		ply:SetNWBool( LuaRace.NW_PARTICIPANT, true )
		ply:SetNWBool( LuaRace.NW_BUSTED, false )
		ply:SetNWFloat( LuaRace.NW_BUSTPROG, 0 )
	end

	-- Anyone not in the pool is reset to spectator.
	for _, ply in player.Iterator() do
		if not table.HasValue( pool, ply ) then
			ply:SetNWInt( LuaRace.NW_ROLE, LuaRace.ROLE_NONE )
			ply:SetNWBool( LuaRace.NW_PARTICIPANT, false )
		end
	end
end

--[[ During the head start, freeze cop vehicles so runners can get away.
     We zero out the physics velocity of each cop's Glide vehicle every tick. ]]
function LuaRace.HoldCops()
	for _, ply in player.Iterator() do
		if LuaRace.IsParticipant( ply ) and LuaRace.IsCop( ply ) then
			local veh = ply.GlideGetVehicle and ply:GlideGetVehicle() or nil
			if IsValid( veh ) then
				local phys = veh:GetPhysicsObject()
				if IsValid( phys ) then
					phys:SetVelocity( vector_origin )
					phys:SetAngleVelocity( vector_origin )
				end
			end
		end
	end
end
