--[[ Server: admin commands to drive races (console + chat). ]]

LuaRace = LuaRace or {}

local function notify( ply, msg )
	if IsValid( ply ) then
		ply:ChatPrint( "[LuaRace] " .. msg )
	else
		print( "[LuaRace] " .. msg )
	end
end

local function canManage( ply )
	-- Server console (ply == nil) or admins.
	return not IsValid( ply ) or ply:IsAdmin()
end

local function doStart( ply )
	if not canManage( ply ) then return notify( ply, "Reserve aux admins." ) end
	local ok, err = LuaRace.StartRace()
	if not ok then notify( ply, err ) end
end

local function doStop( ply )
	if not canManage( ply ) then return notify( ply, "Reserve aux admins." ) end
	LuaRace.StopRace( "admin" )
	notify( ply, "Course arretee." )
end

local function doMenu( ply )
	if not IsValid( ply ) then return end
	net.Start( "LuaRace.Event" )
		net.WriteString( "openmenu" )
		net.WriteString( "" )
	net.Send( ply )
end

local function doInfo( ply )
	local cops, runners, active = LuaRace.CountRoles()
	notify( ply, ("Etat: %d | Police: %d | Fuyards: %d (%d en fuite)")
		:format( LuaRace.Game.state, cops, runners, active ) )
end

-- Console commands.
concommand.Add( "luarace_start", doStart )
concommand.Add( "luarace_stop",  doStop )
concommand.Add( "luarace_info",  doInfo )

-- Chat commands: !race start / !race stop / !race info
hook.Add( "PlayerSay", "LuaRace.Chat", function( ply, text )
	local args = string.Explode( " ", string.lower( string.Trim( text ) ) )
	if args[ 1 ] ~= "!race" and args[ 1 ] ~= "!course" then return end

	local sub = args[ 2 ] or "info"
	if sub == "start" or sub == "go" then
		doStart( ply )
	elseif sub == "stop" then
		doStop( ply )
	elseif sub == "car" or sub == "menu" or sub == "voiture" then
		doMenu( ply )
	else
		doInfo( ply )
	end

	return "" -- swallow the command from public chat
end )
