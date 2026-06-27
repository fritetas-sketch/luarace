--[[ Client: the race HUD (timer, role, counts, bust meter, popups). ]]

LuaRace = LuaRace or {}

local C = LuaRace.Client

surface.CreateFont( "LuaRace.Huge", { font = "Roboto", size = 200, weight = 900 } )
surface.CreateFont( "LuaRace.Big", { font = "Roboto", size = 46, weight = 800 } )
surface.CreateFont( "LuaRace.Med", { font = "Roboto", size = 26, weight = 700 } )
surface.CreateFont( "LuaRace.Small", { font = "Roboto", size = 19, weight = 600 } )

local function drawShadowText( text, font, x, y, col, ax, ay )
	draw.SimpleText( text, font, x + 2, y + 2, Color( 0, 0, 0, 200 ), ax, ay )
	draw.SimpleText( text, font, x, y, col, ax, ay )
end

-- Top-center panel: chrono + role banner + side counts.
local function drawMainPanel()
	local sw = ScrW()
	local cx = sw * 0.5
	local top = 24

	local state = C.state
	local timeLeft = LuaRace.GetTimeLeft()

	-- Background plate.
	local pw, ph = 320, 86
	draw.RoundedBox( 10, cx - pw * 0.5, top, pw, ph, Color( 20, 20, 25, 210 ) )

	if state == LuaRace.STATE_COUNTDOWN then
		drawShadowText( "DEPART DANS", "LuaRace.Small", cx, top + 16, Color( 255, 220, 80 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		drawShadowText( LuaRace.FormatTime( timeLeft ), "LuaRace.Big", cx, top + 52, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	elseif state == LuaRace.STATE_RUNNING then
		local urgent = timeLeft <= 30
		local timeCol = urgent and Color( 255, 90, 90 ) or color_white
		drawShadowText( "TEMPS RESTANT", "LuaRace.Small", cx, top + 16, Color( 200, 200, 210 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		drawShadowText( LuaRace.FormatTime( timeLeft ), "LuaRace.Big", cx, top + 52, timeCol, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	elseif state == LuaRace.STATE_ENDED then
		local txt = C.winner == LuaRace.ROLE_COP and "POLICE" or "FUYARDS"
		local col = LuaRace.RoleColors[ C.winner ] or color_white
		drawShadowText( "VAINQUEUR", "LuaRace.Small", cx, top + 16, Color( 200, 200, 210 ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		drawShadowText( txt, "LuaRace.Big", cx, top + 52, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
	end

	-- Side counts.
	drawShadowText( ("POLICE  %d"):format( C.cops ), "LuaRace.Med",
		cx - pw * 0.5 - 14, top + ph * 0.5, LuaRace.RoleColors[ LuaRace.ROLE_COP ], TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER )
	drawShadowText( ("%d  FUYARDS"):format( C.activeRunners ), "LuaRace.Med",
		cx + pw * 0.5 + 14, top + ph * 0.5, LuaRace.RoleColors[ LuaRace.ROLE_RUNNER ], TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
end

-- Bottom-center role banner.
local function drawRoleBanner()
	local ply = LocalPlayer()
	if not LuaRace.IsParticipant( ply ) then return end

	local role = LuaRace.GetRole( ply )
	local busted = LuaRace.IsBusted( ply )
	local sw, sh = ScrW(), ScrH()
	local cx = sw * 0.5

	local label
	local col = LuaRace.RoleColors[ role ]
	if busted then
		label = "COFFRE - vous etes hors-jeu"
		col = Color( 150, 150, 150 )
	else
		label = "VOUS ETES : " .. ( LuaRace.RoleNames[ role ] or "?" )
	end

	local y = sh - 70
	draw.RoundedBox( 8, cx - 200, y, 400, 40, Color( 15, 15, 20, 200 ) )
	drawShadowText( label, "LuaRace.Med", cx, y + 20, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
end

-- Runner's own "being busted" meter.
local function drawBustMeter()
	local ply = LocalPlayer()
	if not LuaRace.IsRunner( ply ) or LuaRace.IsBusted( ply ) then return end

	local prog = ply:GetNWFloat( LuaRace.NW_BUSTPROG, 0 )
	if prog <= 0.01 then return end

	local sw, sh = ScrW(), ScrH()
	local cx = sw * 0.5
	local w, h = 360, 22
	local y = sh - 120

	draw.RoundedBox( 6, cx - w * 0.5, y, w, h, Color( 0, 0, 0, 200 ) )
	local col = prog > 0.66 and Color( 255, 60, 60 ) or Color( 255, 160, 60 )
	draw.RoundedBox( 6, cx - w * 0.5, y, w * prog, h, col )
	drawShadowText( "ARRESTATION EN COURS !", "LuaRace.Small", cx, y + h * 0.5, color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
end

-- Center popup messages.
local function drawPopup()
	local p = LuaRace.Popup
	if not p or RealTime() > p.until_ then return end

	local a = math.Clamp( ( p.until_ - RealTime() ) * 255, 0, 255 )
	local col = Color( p.color.r, p.color.g, p.color.b, a )
	drawShadowText( p.text, "LuaRace.Big", ScrW() * 0.5, ScrH() * 0.32, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
end

-- Full-screen "3 . 2 . 1 . GO !" around the head-start transition.
local function drawStartCountdown()
	local cx, cy = ScrW() * 0.5, ScrH() * 0.42

	-- The GO flash takes priority for its short window.
	if LuaRace.GoFlashUntil and RealTime() < LuaRace.GoFlashUntil then
		local left = LuaRace.GoFlashUntil - RealTime()
		local a = math.Clamp( left * 255, 0, 255 )
		drawShadowText( "GO !", "LuaRace.Huge", cx, cy, Color( 90, 255, 120, a ), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
		return
	end

	if C.state ~= LuaRace.STATE_COUNTDOWN then return end

	local tl = LuaRace.GetTimeLeft()
	if tl <= 0 or tl > 3.99 then return end

	local n = math.ceil( tl )
	local frac = tl - ( n - 1 ) -- 1 -> 0 as the second elapses
	local a = math.Clamp( frac * 255 + 40, 0, 255 )
	local col = Color( 255, 210, 80, a )
	drawShadowText( tostring( n ), "LuaRace.Huge", cx, cy, col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER )
end

hook.Add( "HUDPaint", "LuaRace.HUD", function()
	-- Popups can show even between rounds.
	drawPopup()
	drawStartCountdown()

	if C.state == LuaRace.STATE_IDLE then return end

	drawMainPanel()
	drawRoleBanner()
	drawBustMeter()
end )
