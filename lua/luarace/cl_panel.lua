--[[ Client: live participant list panel (top-left). Shows every runner with
     their status and the number of cops still hunting. ]]

LuaRace = LuaRace or {}

local C = LuaRace.Client

surface.CreateFont( "LuaRace.PanelHdr", { font = "Roboto", size = 20, weight = 800 } )
surface.CreateFont( "LuaRace.PanelRow", { font = "Roboto", size = 18, weight = 600 } )

-- Gather participants grouped by role from networked vars (client-side).
local function gather()
	local runners, cops = {}, 0
	for _, ply in player.Iterator() do
		if LuaRace.IsParticipant( ply ) then
			local role = LuaRace.GetRole( ply )
			if role == LuaRace.ROLE_RUNNER then
				runners[ #runners + 1 ] = ply
			elseif role == LuaRace.ROLE_COP then
				cops = cops + 1
			end
		end
	end
	return runners, cops
end

local function row( x, y, w, h, label, value, valueCol )
	draw.RoundedBox( 4, x, y, w, h, Color( 0, 0, 0, 120 ) )
	draw.SimpleText( label, "LuaRace.PanelRow", x + 10, y + h * 0.5, color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
	draw.SimpleText( value, "LuaRace.PanelRow", x + w - 10, y + h * 0.5, valueCol, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
end

hook.Add( "HUDPaint", "LuaRace.Panel", function()
	if C.state == LuaRace.STATE_IDLE then return end

	local runners, cops = gather()

	local x, y = 20, 130
	local w = 280
	local rowH = 26
	local pad = 8
	local headH = 30

	local total = headH + ( #runners + 1 ) * ( rowH + 4 ) + pad * 2 + headH
	draw.RoundedBox( 8, x, y, w, total, Color( 18, 18, 24, 215 ) )

	local cy = y + pad

	-- Police header.
	draw.SimpleText( "POLICE", "LuaRace.PanelHdr", x + 12, cy + headH * 0.5,
		LuaRace.RoleColors[ LuaRace.ROLE_COP ], TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
	draw.SimpleText( tostring( cops ) .. " unites", "LuaRace.PanelHdr", x + w - 12, cy + headH * 0.5,
		color_white, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
	cy = cy + headH

	-- Runners header.
	draw.SimpleText( "FUYARDS", "LuaRace.PanelHdr", x + 12, cy + headH * 0.5,
		LuaRace.RoleColors[ LuaRace.ROLE_RUNNER ], TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
	cy = cy + headH

	-- One row per runner.
	for _, ply in ipairs( runners ) do
		local busted = LuaRace.IsBusted( ply )
		local status, col
		if busted then
			status, col = "COFFRE", Color( 150, 150, 150 )
		else
			local prog = ply:GetNWFloat( LuaRace.NW_BUSTPROG, 0 )
			if prog > 0.05 then
				status, col = ("%d%%"):format( math.floor( prog * 100 ) ), Color( 255, 160, 60 )
			else
				status, col = "EN FUITE", Color( 120, 230, 120 )
			end
		end

		local name = ply:Nick()
		if #name > 16 then name = name:sub( 1, 15 ) .. "." end

		row( x + 8, cy, w - 16, rowH, name, status, col )
		cy = cy + rowH + 4
	end
end )
