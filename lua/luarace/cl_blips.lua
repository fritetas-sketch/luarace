--[[ Client: runner blips for cops. Revealed runners get a floating marker
     on screen, or a directional arrow at the screen edge when off-screen. ]]

LuaRace = LuaRace or {}

local C = LuaRace.Client

local function meters( units )
	-- ~1 unit = 1.905 cm in Source; show a rough metre distance.
	return math.Round( units * 0.01905 )
end

-- Draw a small diamond marker.
local function diamond( x, y, r, col )
	draw.NoTexture()
	surface.SetDrawColor( col.r, col.g, col.b, col.a or 255 )
	local poly = {
		{ x = x,     y = y - r },
		{ x = x + r, y = y     },
		{ x = x,     y = y + r },
		{ x = x - r, y = y     },
	}
	surface.DrawPoly( poly )
end

local function drawRunnerBlip( pos, name )
	local col = LuaRace.RoleColors[ LuaRace.ROLE_RUNNER ]
	local localPos = EyePos()
	local dist = meters( localPos:Distance( pos ) )

	-- World-space marker floats a bit above the car.
	local screen = ( pos + Vector( 0, 0, 90 ) ):ToScreen()

	local sw, sh = ScrW(), ScrH()
	local onScreen = screen.visible and screen.x >= 0 and screen.x <= sw and screen.y >= 0 and screen.y <= sh

	if onScreen then
		diamond( screen.x, screen.y, 12, col )
		diamond( screen.x, screen.y, 6, Color( 255, 255, 255 ) )
		draw.SimpleTextOutlined( name, "LuaRace.Small", screen.x, screen.y - 26,
			col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black )
		draw.SimpleTextOutlined( dist .. " m", "LuaRace.Small", screen.x, screen.y + 22,
			color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black )
	else
		-- Off-screen: clamp to a ring and draw an arrow pointing there.
		local cx, cy = sw * 0.5, sh * 0.5
		local dx, dy = screen.x - cx, screen.y - cy
		if screen.visible == false then dx, dy = -dx, -dy end -- behind us
		local ang = math.atan2( dy, dx )
		local rx, ry = sw * 0.42, sh * 0.42
		local ex = cx + math.cos( ang ) * rx
		local ey = cy + math.sin( ang ) * ry

		diamond( ex, ey, 11, col )
		draw.SimpleTextOutlined( dist .. " m", "LuaRace.Small", ex, ey + 20,
			color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black )
	end
end

hook.Add( "HUDPaint", "LuaRace.Blips", function()
	if C.state ~= LuaRace.STATE_RUNNING then return end

	local ply = LocalPlayer()
	-- Only the hunters (and spectators) get to see revealed runners.
	if LuaRace.IsRunner( ply ) and not LuaRace.IsBusted( ply ) then return end

	for _, info in ipairs( C.revealed ) do
		local name = IsValid( info.ent ) and info.ent:Nick() or "Fuyard"
		drawRunnerBlip( info.pos, name )
	end
end )
