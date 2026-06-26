--[[ Server: periodic "reveal pings" that flash runner positions to cops,
     plus a permanent reveal during the final seconds of the round. ]]

LuaRace = LuaRace or {}

local G = LuaRace.Game
local nextPing = 0

-- Called when the chase begins: schedule the first ping.
function LuaRace.ResetReveal()
	local interval = LuaRace.Cvar( "reveal_interval" )
	nextPing = interval > 0 and ( CurTime() + interval ) or math.huge
end

-- Reveal every active runner for `duration` seconds.
local function RevealAll( duration )
	for _, ply in player.Iterator() do
		if LuaRace.IsRunner( ply ) and not LuaRace.IsBusted( ply ) then
			G.revealed[ ply ] = CurTime() + duration
		end
	end
end

function LuaRace.UpdateReveal( now )
	local timeLeft    = G.stateEnd - now
	local finalReveal = LuaRace.Cvar( "final_reveal" )

	-- Final stretch: keep runners lit up continuously.
	if finalReveal > 0 and timeLeft <= finalReveal then
		RevealAll( 0.5 )
		return
	end

	-- Otherwise, ping on the interval.
	if now >= nextPing then
		local interval = LuaRace.Cvar( "reveal_interval" )
		nextPing = now + interval
		RevealAll( LuaRace.Cvar( "reveal_duration" ) )
		LuaRace.FireEvent( "ping", {} )
	end
end
