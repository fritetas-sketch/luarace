--[[ Shared configuration. Server values come from ConVars so server owners
     can tweak everything live with `luarace_*` console commands. ]]

LuaRace = LuaRace or {}
LuaRace.Config = LuaRace.Config or {}

-- Game states.
LuaRace.STATE_IDLE      = 0 -- no race running
LuaRace.STATE_COUNTDOWN = 1 -- roles assigned, runners get a head start
LuaRace.STATE_RUNNING   = 2 -- the chase is on
LuaRace.STATE_ENDED     = 3 -- showing results before going back to IDLE

-- Roles.
LuaRace.ROLE_NONE   = 0 -- spectator / not participating
LuaRace.ROLE_COP    = 1 -- police, hunts runners
LuaRace.ROLE_RUNNER = 2 -- fugitive, must survive the timer

LuaRace.RoleColors = {
	[LuaRace.ROLE_COP]    = Color( 70, 130, 255 ),
	[LuaRace.ROLE_RUNNER] = Color( 255, 80, 80 ),
	[LuaRace.ROLE_NONE]   = Color( 180, 180, 180 ),
}

LuaRace.RoleNames = {
	[LuaRace.ROLE_COP]    = "POLICE",
	[LuaRace.ROLE_RUNNER] = "FUYARD",
	[LuaRace.ROLE_NONE]   = "SPECTATEUR",
}

--[[ Vehicle pools per role. Players pick which car they want from their side's
     list; the addon spawns it for them when a race starts.
     These are Glide entity classes from the NFS Undercover car pack. ]]
LuaRace.Vehicles = {
	[LuaRace.ROLE_RUNNER] = {
		"nfsuc_toy_sup_stk_98custom",
		"nfsuc_nis_sky_r34_99_custom",
		"nfsuc_mit_evo_ix_06_extra",
		"nfsuc_nis_sky_aer_99_custom",
		"nfsuc_nis_sky_aer_99_kingai",
		"nfsuc_toy_sup_stk_98_darius",
		"nfsuc_bmw_m3_e46_03_legendmw",
	},
	[LuaRace.ROLE_COP] = {
		"nfsuc_dod_chr_bee_07_tcbpd",
		"nfsuc_cop_car_suvl_04",
		"nfsuc_for_mus_gt_06_tcb",
		"nfsuc_cop_car_mus_08_reformed",
		"nfsuc_cop_car_mus_08",
	},
}

-- Friendly names shown in the selection menu.
LuaRace.VehicleNames = {
	[ "nfsuc_toy_sup_stk_98custom" ]   = "Toyota Supra (Custom)",
	[ "nfsuc_nis_sky_r34_99_custom" ]  = "Nissan Skyline R34 (Custom)",
	[ "nfsuc_mit_evo_ix_06_extra" ]    = "Mitsubishi Lancer Evo IX",
	[ "nfsuc_nis_sky_aer_99_custom" ]  = "Nissan Skyline AERO (Custom)",
	[ "nfsuc_nis_sky_aer_99_kingai" ]  = "Nissan Skyline AERO (King AI)",
	[ "nfsuc_toy_sup_stk_98_darius" ]  = "Toyota Supra (Darius)",
	[ "nfsuc_bmw_m3_e46_03_legendmw" ] = "BMW M3 E46 (Legend)",
	[ "nfsuc_dod_chr_bee_07_tcbpd" ]   = "Dodge Charger SRT8 (Police)",
	[ "nfsuc_cop_car_suvl_04" ]        = "SUV de Police",
	[ "nfsuc_for_mus_gt_06_tcb" ]      = "Ford Mustang GT (TCB)",
	[ "nfsuc_cop_car_mus_08_reformed" ]= "Police Mustang (Reformed)",
	[ "nfsuc_cop_car_mus_08" ]         = "Police Mustang",
}

-- Pretty label for a class, falling back to the raw class name.
function LuaRace.VehicleLabel( class )
	return LuaRace.VehicleNames[ class ] or class
end

-- Is `class` a valid choice for `role`?
function LuaRace.IsAllowedVehicle( role, class )
	local list = LuaRace.Vehicles[ role ]
	if not list then return false end
	for _, c in ipairs( list ) do
		if c == class then return true end
	end
	return false
end

-- Default car for a role (first in the list).
function LuaRace.DefaultVehicle( role )
	local list = LuaRace.Vehicles[ role ]
	return list and list[ 1 ] or ""
end

--[[ ConVars (server-authoritative, replicated so the client can read them). ]]
if SERVER then
	local FCVAR = { FCVAR_ARCHIVE, FCVAR_REPLICATED, FCVAR_NOTIFY }

	-- How many players share one runner. floor(players / this) runners (min 1).
	-- 7 players -> 1 runner, 10 -> 2, 15 -> 3. Matches the requested ratio.
	CreateConVar( "luarace_players_per_runner", "5", FCVAR, "Players per runner. runners = max(1, floor(players / value))", 2, 50 )

	-- Round length in seconds. Runners win if at least one survives this long.
	CreateConVar( "luarace_round_time", "120", FCVAR, "Race duration in seconds", 30, 1800 )

	-- Head start for runners before cops are released (seconds).
	CreateConVar( "luarace_headstart", "15", FCVAR, "Runner head start in seconds", 0, 120 )

	-- Bust: a cop must stay within this radius of a runner...
	CreateConVar( "luarace_bust_radius", "350", FCVAR, "Distance (units) at which a cop can bust a runner", 100, 2000 )
	-- ...for this many continuous seconds to bust them.
	CreateConVar( "luarace_bust_time", "4", FCVAR, "Seconds a cop must stay close to bust a runner", 0.5, 30 )

	-- Reveal pings: every interval, runner positions flash to cops for a duration.
	CreateConVar( "luarace_reveal_interval", "20", FCVAR, "Seconds between runner reveal pings", 0, 300 )
	CreateConVar( "luarace_reveal_duration", "5", FCVAR, "How long each reveal ping lasts", 1, 60 )
	-- During the final N seconds, runners are permanently revealed.
	CreateConVar( "luarace_final_reveal", "30", FCVAR, "Permanently reveal runners during the last N seconds", 0, 300 )

	-- If 1, only players currently in a Glide vehicle take part in the race.
	CreateConVar( "luarace_require_vehicle", "0", FCVAR, "Only count players inside a Glide vehicle as participants", 0, 1 )

	-- If 1, the addon spawns each player's chosen role car and seats them in it.
	CreateConVar( "luarace_give_vehicles", "1", FCVAR, "Spawn role vehicles for participants at race start", 0, 1 )

	-- Minimum players needed to start a race.
	CreateConVar( "luarace_min_players", "2", FCVAR, "Minimum participants required to start", 1, 64 )

	-- Seconds the results screen stays up before returning to idle.
	CreateConVar( "luarace_results_time", "10", FCVAR, "Seconds the end-of-round results stay up", 1, 60 )
end

-- Convenience accessor used everywhere instead of GetConVar spam.
function LuaRace.Cvar( name )
	local cv = GetConVar( "luarace_" .. name )
	return cv and cv:GetFloat() or 0
end
