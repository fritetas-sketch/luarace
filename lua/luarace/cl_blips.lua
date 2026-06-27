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

local function drawRunnerBlip( pos, name, bustable )
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

		-- Hint to cops: this runner is slow enough to be arrested right now.
		if bustable then
			local pulse = 160 + math.sin( CurTime() * 8 ) * 95
			draw.SimpleTextOutlined( "IMMOBILISEZ-LE !", "LuaRace.Med", screen.x, screen.y - 50,
				Color( 255, 230, 60, pulse ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black )
		end
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

-- Small filled circle helper (uses a rounded box at full corner radius).
local function dot( x, y, r, col )
	draw.RoundedBox( r, x - r, y - r, r * 2, r * 2, col )
end

-- Bottom-right circular radar: plots revealed runners around the viewer,
-- rotated so "up" is the direction the viewer is facing.
local RADAR_RANGE = 6000
local function drawRadar()
	local radius = 96
	local cx = ScrW() - radius - 28
	local cy = ScrH() - radius - 28

	-- Dish.
	draw.RoundedBox( radius, cx - radius, cy - radius, radius * 2, radius * 2, Color( 12, 14, 20, 205 ) )

	-- Cross lines.
	surface.SetDrawColor( 60, 60, 75, 120 )
	surface.DrawLine( cx - radius, cy, cx + radius, cy )
	surface.DrawLine( cx, cy - radius, cx, cy + radius )

	-- Viewer in the centre, facing up.
	dot( cx, cy, 4, Color( 90, 200, 255 ) )
	draw.SimpleText( "AV", "LuaRace.Small", cx, cy - radius + 11, Color( 170, 170, 185 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )

	local ang   = Angle( 0, EyeAngles().yaw, 0 )
	local fwd   = ang:Forward()
	local right = ang:Right()
	local loc   = LocalPlayer():GetPos()
	local col   = LuaRace.RoleColors[ LuaRace.ROLE_RUNNER ]

	for _, info in ipairs( C.revealed ) do
		local d = info.pos - loc
		d.z = 0

		local up = d:Dot( fwd )
		local rt = d:Dot( right )

		local px = rt / RADAR_RANGE * radius
		local py = -up / RADAR_RANGE * radius

		-- Clamp to the rim if out of range, with a hollow look.
		local mag = math.sqrt( px * px + py * py )
		local atEdge = mag > radius - 6
		if atEdge and mag > 0 then
			local s = ( radius - 6 ) / mag
			px, py = px * s, py * s
		end

		dot( cx + px, cy + py, atEdge and 4 or 6, col )
	end
end

hook.Add( "HUDPaint", "LuaRace.Blips", function()
	if C.state ~= LuaRace.STATE_RUNNING then return end

	local ply = LocalPlayer()
	-- Only the hunters (and spectators) get to see revealed runners.
	if LuaRace.IsRunner( ply ) and not LuaRace.IsBusted( ply ) then return end

	for _, info in ipairs( C.revealed ) do
		local name = IsValid( info.ent ) and info.ent:Nick() or "Fuyard"
		local bustable = IsValid( info.ent ) and info.ent:GetNWBool( LuaRace.NW_BUSTABLE, false )
		drawRunnerBlip( info.pos, name, bustable )
	end

	drawRadar()
end )
