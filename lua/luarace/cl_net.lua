--[[ Client: receive state sync + one-off events. ]]

LuaRace = LuaRace or {}

LuaRace.Client = LuaRace.Client or {
	state         = LuaRace.STATE_IDLE,
	timeLeft      = 0,
	syncAt        = 0,    -- RealTime() when timeLeft was received (for smooth countdown)
	cops          = 0,
	runners       = 0,
	activeRunners = 0,
	winner        = -1,
	revealed      = {},   -- { { ent = Player, pos = Vector }, ... }
}

local C = LuaRace.Client

net.Receive( "LuaRace.Sync", function()
	C.state         = net.ReadUInt( 3 )
	C.timeLeft      = net.ReadFloat()
	C.syncAt        = RealTime()
	C.cops          = net.ReadUInt( 8 )
	C.runners       = net.ReadUInt( 8 )
	C.activeRunners = net.ReadUInt( 8 )
	C.winner        = net.ReadInt( 8 )

	local n = net.ReadUInt( 8 )
	local revealed = {}
	for i = 1, n do
		revealed[ i ] = {
			ent = net.ReadEntity(),
			pos = net.ReadVector(),
		}
	end
	C.revealed = revealed
end )

-- Smooth, locally-predicted time remaining for the HUD.
function LuaRace.GetTimeLeft()
	if C.state == LuaRace.STATE_IDLE then return 0 end
	return math.max( 0, C.timeLeft - ( RealTime() - C.syncAt ) )
end

----------------------------------------------------------------------
-- Events (sounds + on-screen popups)
----------------------------------------------------------------------

LuaRace.Popup = { text = "", color = color_white, until_ = 0 }

local function popup( text, col, dur )
	LuaRace.Popup.text   = text
	LuaRace.Popup.color  = col or color_white
	LuaRace.Popup.until_ = RealTime() + ( dur or 4 )
end

local handlers = {
	start = function()
		popup( "PREPAREZ-VOUS...", Color( 255, 220, 80 ), 3 )
		surface.PlaySound( "buttons/button17.wav" )
	end,
	chase = function()
		local role = LuaRace.GetRole( LocalPlayer() )
		if role == LuaRace.ROLE_COP then
			popup( "LACHEZ LES CHIENS ! Attrapez les fuyards.", LuaRace.RoleColors[ LuaRace.ROLE_COP ], 4 )
		elseif role == LuaRace.ROLE_RUNNER then
			popup( "FUYEZ ! Survivez jusqu'a la fin du chrono.", LuaRace.RoleColors[ LuaRace.ROLE_RUNNER ], 4 )
		else
			popup( "La course commence !", color_white, 3 )
		end
		surface.PlaySound( "ambient/alarms/police_loop.wav" )
	end,
	ping = function()
		if LuaRace.IsCop( LocalPlayer() ) then
			surface.PlaySound( "buttons/blip1.wav" )
		end
	end,
	bust = function( data )
		popup( ( data.runner or "?" ) .. " s'est fait coffrer !", Color( 255, 120, 60 ), 4 )
		surface.PlaySound( "buttons/combine_button7.wav" )
	end,
	["end"] = function( data )
		local winnerRole = tonumber( data.winner ) or -1
		local txt = winnerRole == LuaRace.ROLE_COP and "LA POLICE GAGNE" or "LES FUYARDS GAGNENT"
		popup( txt, LuaRace.RoleColors[ winnerRole ] or color_white, 8 )
		surface.PlaySound( "ambient/levels/labs/electric_explosion4.wav" )
	end,
	stop = function()
		popup( "Course annulee.", color_white, 3 )
	end,
}

net.Receive( "LuaRace.Event", function()
	local name = net.ReadString()
	local raw  = net.ReadString()
	local data = raw ~= "" and util.JSONToTable( raw ) or {}
	local h = handlers[ name ]
	if h then h( data or {} ) end
end )
