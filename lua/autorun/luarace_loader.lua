--[[
	LuaRace - Street Races for Garry's Mod (Glide vehicles)

	This loader includes every file of the addon in the right realm.
	Layout:
		lua/luarace/sh_*.lua  -> shared (run on server + client)
		lua/luarace/sv_*.lua  -> server only
		lua/luarace/cl_*.lua  -> client only (also AddCSLuaFile'd on server)
]]

LuaRace = LuaRace or {}
LuaRace.Version = "0.1.0"

local SHARED = {
	"luarace/sh_config.lua",
	"luarace/sh_util.lua",
}

local SERVER_FILES = {
	"luarace/sv_core.lua",
	"luarace/sv_roles.lua",
	"luarace/sv_vehicles.lua",
	"luarace/sv_bust.lua",
	"luarace/sv_reveal.lua",
	"luarace/sv_commands.lua",
}

local CLIENT_FILES = {
	"luarace/cl_net.lua",
	"luarace/cl_hud.lua",
	"luarace/cl_blips.lua",
	"luarace/cl_menu.lua",
}

-- Make client files downloadable, then run shared + the realm-specific files.
if SERVER then
	for _, f in ipairs( SHARED ) do AddCSLuaFile( f ) end
	for _, f in ipairs( CLIENT_FILES ) do AddCSLuaFile( f ) end

	for _, f in ipairs( SHARED ) do include( f ) end
	for _, f in ipairs( SERVER_FILES ) do include( f ) end
else
	for _, f in ipairs( SHARED ) do include( f ) end
	for _, f in ipairs( CLIENT_FILES ) do include( f ) end
end

print( "[LuaRace] Loaded version " .. LuaRace.Version )
