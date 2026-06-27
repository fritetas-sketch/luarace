--[[ Client: vehicle selection menu. Players pick the car they want for each
     role (Fuyard / Police). The choice is saved client-side and pushed to the
     server, which spawns it when a race starts. ]]

LuaRace = LuaRace or {}

-- Persisted preferences (saved to the client's config).
local cvRunner = CreateClientConVar( "luarace_pref_runner", "", true, false, "Preferred runner car" )
local cvCop    = CreateClientConVar( "luarace_pref_cop", "", true, false, "Preferred cop car" )

local function currentPref( role )
	local cv = role == LuaRace.ROLE_RUNNER and cvRunner or cvCop
	local val = cv:GetString()
	if val == "" or not LuaRace.IsAllowedVehicle( role, val ) then
		val = LuaRace.DefaultVehicle( role )
	end
	return val
end

-- Send a choice to the server.
local function sendPick( role, class )
	net.Start( "LuaRace.PickVehicle" )
		net.WriteUInt( role, 3 )
		net.WriteString( class )
	net.SendToServer()
end

-- Push both stored prefs (e.g. on spawn) so the server is in sync.
local function pushAll()
	sendPick( LuaRace.ROLE_RUNNER, currentPref( LuaRace.ROLE_RUNNER ) )
	sendPick( LuaRace.ROLE_COP, currentPref( LuaRace.ROLE_COP ) )
end

hook.Add( "InitPostEntity", "LuaRace.SendPrefs", function()
	timer.Simple( 2, pushAll )
end )

----------------------------------------------------------------------
-- The menu
----------------------------------------------------------------------

local function buildList( parent, role, cv )
	local scroll = parent:Add( "DScrollPanel" )
	scroll:Dock( FILL )

	local selected = currentPref( role )
	local buttons = {}

	local function refresh()
		for class, btn in pairs( buttons ) do
			btn.isSel = ( class == selected )
		end
	end

	for _, class in ipairs( LuaRace.Vehicles[ role ] or {} ) do
		local btn = scroll:Add( "DButton" )
		btn:Dock( TOP )
		btn:DockMargin( 6, 4, 6, 0 )
		btn:SetTall( 44 )
		btn:SetText( "" )
		btn.isSel = false

		btn.Paint = function( s, w, h )
			local col = s.isSel and Color( 70, 130, 255, 230 )
				or ( s:IsHovered() and Color( 60, 60, 70 ) or Color( 40, 40, 48 ) )
			draw.RoundedBox( 6, 0, 0, w, h, col )
			draw.SimpleText( LuaRace.VehicleLabel( class ), "DermaLarge", 14, h * 0.5,
				color_white, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER )
		end

		btn.DoClick = function()
			selected = class
			RunConsoleCommand( cv, class )
			sendPick( role, class )
			refresh()
			surface.PlaySound( "buttons/button14.wav" )
		end

		buttons[ class ] = btn
	end

	refresh()
	return scroll
end

function LuaRace.OpenMenu()
	if IsValid( LuaRace.Menu ) then LuaRace.Menu:Remove() end

	local frame = vgui.Create( "DFrame" )
	frame:SetSize( 520, 460 )
	frame:Center()
	frame:SetTitle( "LuaRace - Choix du vehicule" )
	frame:MakePopup()
	LuaRace.Menu = frame

	local sheet = frame:Add( "DPropertySheet" )
	sheet:Dock( FILL )
	sheet:DockMargin( 4, 4, 4, 4 )

	local runnerPanel = frame:Add( "DPanel" )
	runnerPanel.Paint = nil
	buildList( runnerPanel, LuaRace.ROLE_RUNNER, "luarace_pref_runner" )
	sheet:AddSheet( "Fuyard (criminel)", runnerPanel, "icon16/car.png" )

	local copPanel = frame:Add( "DPanel" )
	copPanel.Paint = nil
	buildList( copPanel, LuaRace.ROLE_COP, "luarace_pref_cop" )
	sheet:AddSheet( "Police", copPanel, "icon16/shield.png" )

	-- Admin race controls at the bottom.
	if LocalPlayer():IsAdmin() then
		local bar = frame:Add( "DPanel" )
		bar:Dock( BOTTOM )
		bar:DockMargin( 4, 4, 4, 0 )
		bar:SetTall( 40 )
		bar.Paint = nil

		local start = bar:Add( "DButton" )
		start:Dock( LEFT )
		start:DockMargin( 0, 0, 4, 0 )
		start:SetWide( 250 )
		start:SetText( "Lancer la course" )
		start.DoClick = function() RunConsoleCommand( "luarace_start" ) end

		local stop = bar:Add( "DButton" )
		stop:Dock( FILL )
		stop:SetText( "Arreter" )
		stop.DoClick = function() RunConsoleCommand( "luarace_stop" ) end
	end
end

concommand.Add( "luarace_menu", LuaRace.OpenMenu )

-- Server tells us to open the menu (from the "!race car" chat command).
hook.Add( "LuaRace.Event", "LuaRace.OpenMenuEvent", function( name )
	if name == "openmenu" then LuaRace.OpenMenu() end
end )
