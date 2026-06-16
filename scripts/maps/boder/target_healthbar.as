/*QUAKED target_healthbar (0 1 0) (-8 -8 -8) (8 8 8) PLAYERNAME DISPLAYNAME
* Hook up health bars to monsters using safe HUD text rendering.
* "delay" is how long to show the health bar for after death.
* "message" is their name
* This script was made by Neyami/Nero and heavily modified by Garompa to fix lag
*/

namespace target_healthbar
{

const int SPAWNFLAG_HEALTHBAR_PLAYERNAME  = 2;
const int SPAWNFLAG_HEALTHBAR_DISPLAYNAME = 4;

const int MAX_HEALTH_BARS        = 1;
const int HUD_TEXT_HEALTHBAR     = 1;

array<EHandle> health_bar_entities( MAX_HEALTH_BARS );
string CONFIG_HEALTH_BAR_NAME = "";

class target_healthbar : ScriptBaseEntity
{
	private EHandle m_hTarget;
	private float m_flDelay;
	private int m_iBarValue; // Now represents the amount of characters to draw (0 to 60)
	private float m_flTimeToRemove;
	private int m_iMaxCharacters = 60; //60 characters might be the max amount to display in a line for a 640x480 smallest resolution

	// ULTRA OPTIMIZED REFRESH VARIABLES
	private int m_iLastBarValue = -1;        // Stores the bar value from the previous second
	private float m_flLastRefreshTime = 0.0;  // Tracks when we last physically updated the HUD
	private float m_flFailsafeInterval = 60.0; // Humongous 60-second fallback to save massive resources

	// JOIN & RESPAWN DETECTION TRACKERS
	private int m_iLastConnectedCount = 0;   // Tracks how many total players are on the server
	private int m_iLastAliveCount = 0;       // Tracks how many players are currently alive

	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		if( szKey == "delay" )
		{
			m_flDelay = atof( szValue );
			return true;
		}
		else
			return BaseClass.KeyValue( szKey, szValue );
	}

	void Spawn()
	{
		if( string(pev.target).IsEmpty() )
		{
			g_Game.AlertMessage( at_error, "%1: missing target\n", self.GetClassname() );
			g_EntityFuncs.Remove( self );
			return;
		}

		if( !HasFlags(pev.spawnflags, SPAWNFLAG_HEALTHBAR_PLAYERNAME|SPAWNFLAG_HEALTHBAR_DISPLAYNAME) and string(pev.message).IsEmpty() )
		{
			g_Game.AlertMessage( at_error, "%1: missing message\n", self.GetClassname() );
			g_EntityFuncs.Remove( self );
			return;
		}

		m_iBarValue = m_iMaxCharacters;
		SetUse( UseFunction(this.use_target_healthbar) );
		SetThink( ThinkFunction(this.check_target_healthbar) );
		pev.nextthink = g_Engine.time + 1.0;
	}

	void check_target_healthbar()
	{
		CBaseEntity@ target = g_EntityFuncs.FindEntityByTargetname( null, string(pev.target) );
		if( target is null )
		{
			ClearBossHUD(); // Make sure screen is clean before removal
			g_EntityFuncs.Remove( self );
			return;
		}
	}

	void HealthbarThink()
	{
		UpdateHealthbarValue();

		// If UpdateHealthbarValue triggered a self-removal or delay sequence, stop execution here
		if( m_iBarValue == 0 && (m_flTimeToRemove > 0.0 || pev.nextthink == 0) )
			return;

		// Check player states to catch joins/respawns
		int currentConnected = 0;
		int currentAlive = 0;
		GetPlayerCounts(currentConnected, currentAlive);

		bool forceRefresh = false;

		// If a new player connected, or a dead player respawned, trigger a forced refresh
		if( currentConnected != m_iLastConnectedCount or currentAlive > m_iLastAliveCount )
		{
			forceRefresh = true;
		}

		// Save the new counts for the next second's check
		m_iLastConnectedCount = currentConnected;
		m_iLastAliveCount = currentAlive;

		// SMART CHECK: Update HUD if health changed, OR if a player event occurred, OR if the 60s failsafe ran out
		if( m_iBarValue != m_iLastBarValue or forceRefresh or (g_Engine.time - m_flLastRefreshTime) >= m_flFailsafeInterval )
		{
			DrawText();
			
			m_iLastBarValue = m_iBarValue;
			m_flLastRefreshTime = g_Engine.time;
		}

		// Keep monitoring numbers every 1.0 second (very light logic check)
		pev.nextthink = g_Engine.time + 1.0;
	}

	void use_target_healthbar( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue )
	{
		CBaseEntity@ target = g_EntityFuncs.FindEntityByTargetname( null, string(pev.target) );
		if( target is null )
		{
			g_EntityFuncs.Remove( self );
			return;
		}

		if( health_bar_entities[0].IsValid() )
		{
			g_Game.AlertMessage( at_error, "%1: too many health bars\n", self.GetClassname() );
			g_EntityFuncs.Remove( self );
			return;
		}

		m_hTarget = EHandle( target );
		health_bar_entities[0] = EHandle( self );

		if( target.pev.FlagBitSet(FL_CLIENT) and HasFlags(pev.spawnflags, SPAWNFLAG_HEALTHBAR_PLAYERNAME) )
			CONFIG_HEALTH_BAR_NAME = string( target.pev.netname );
		else if( target.pev.FlagBitSet(FL_MONSTER) and HasFlags(pev.spawnflags, SPAWNFLAG_HEALTHBAR_DISPLAYNAME) )
		{
			CBaseMonster@ pMonster = target.MyMonsterPointer();
			if( pMonster !is null )
				CONFIG_HEALTH_BAR_NAME = string( pMonster.m_FormattedName );
		}
		else
			CONFIG_HEALTH_BAR_NAME = string( pev.message );

		// Initialize player counts on startup so the first frame doesn't accidentally trip a false positive
		GetPlayerCounts(m_iLastConnectedCount, m_iLastAliveCount);

		SetUse( null );
		SetThink( ThinkFunction(this.HealthbarThink) );
		pev.nextthink = g_Engine.time + 1.0;
	}

	void DrawText()
	{
		// 1. STATIC BAR CONSTRUCTION (Health + Empty)
		string sHealthBarVisual = "";
		
		// Part 1: Fill with vertical lines for current health
		for( int i = 0; i < m_iBarValue; i++ )
		{
			sHealthBarVisual += "|";
		}

		// Part 2: Fill the rest of the bar with dashes to maintain fixed length
		int emptyCharacters = m_iMaxCharacters - m_iBarValue;
		for( int i = 0; i < emptyCharacters; i++ )
		{
			sHealthBarVisual += "-";
		}

		// Emergency case: if the NPC is still alive but the calculation gives 0, leave at least one visual detail
		if( m_iBarValue == 0 && m_hTarget.IsValid() && m_hTarget.GetEntity().pev.health > 0 )
		{
			sHealthBarVisual = "|" + sHealthBarVisual.SubString(1);
		}

		// 2. FINAL ASSEMBLY WITH LINE BREAK
		string sFinalHUDMessage = CONFIG_HEALTH_BAR_NAME + "\n" + sHealthBarVisual;
		
		// Send to the global optimized renderer
		CG_DrawHUDStringAll( sFinalHUDMessage );
	}

	void CG_DrawHUDStringAll( const string &in sString )
	{
		HUDTextParams textParms;
		textParms.fadeinTime = 0.0;
		textParms.fadeoutTime = 0.02;
		
		// Set the hold time slightly higher than our 60 second interval to guarantee it never blinks out
		textParms.holdTime = m_flFailsafeInterval + 0.1; 
		
		textParms.effect = 0;
		textParms.channel = HUD_TEXT_HEALTHBAR;
		textParms.x = -1.0; 
		textParms.y = 0.08;
		
		// Pure Red Color
		textParms.r1 = 255;  textParms.g1 = 0;  textParms.b1 = 0;
		textParms.r2 = 255;  textParms.g2 = 0;  textParms.b2 = 0;

		// Sends the text message to all players simultaneously
		g_PlayerFuncs.HudMessageAll( textParms, sString + "\n" );
	}

	// BLANK MSG PROTOCOL: Instantly clears Channel 1 off everyone's screen by overwriting it with nothing
	void ClearBossHUD()
	{
		HUDTextParams textParms;
		textParms.fadeinTime = 0.0;
		textParms.fadeoutTime = 0.0;
		textParms.holdTime = 0.1; // almost 0 seconds hold = vanishes instantly
		textParms.channel = HUD_TEXT_HEALTHBAR;
		textParms.x = -1.0;
		textParms.y = 0.08;
		g_PlayerFuncs.HudMessageAll( textParms, "" );
	}

	void UpdateHealthbarValue()
	{
		if( m_flTimeToRemove > 0.0 )
		{
			if( m_flTimeToRemove < g_Engine.time )
			{
				ClearBossHUD(); // Wipe HUD after the custom post-death delay ends
				g_EntityFuncs.Remove( self );
			}
		}
		else
		{
			if( !m_hTarget.IsValid() or m_hTarget.GetEntity().pev.health <= 0 or m_hTarget.GetEntity().pev.deadflag != DEAD_NO )
			{
				if( m_flDelay > 0.0 )
				{
					m_flTimeToRemove = g_Engine.time + m_flDelay;
					m_iBarValue = 0;
					DrawText(); // Draw the empty bar state during the death delay duration
				}
				else
				{
					ClearBossHUD(); // Wipe HUD instantly if there is no death delay configured
					g_EntityFuncs.Remove( self );
				}
	
				return;
			}

			// Calculate how many characters out of the total should be drawn based on health percentage
			float health_remaining = m_hTarget.GetEntity().pev.health / m_hTarget.GetEntity().pev.max_health;
			m_iBarValue = int( health_remaining * float(m_iMaxCharacters) );
		}
	}

	// High-speed player scanning loop. Grabs raw stats without text or physics functions.
	void GetPlayerCounts(int &out outConnected, int &out outAlive)
	{
		outConnected = 0;
		outAlive = 0;
		
		for( int i = 1; i <= g_Engine.maxClients; ++i )
		{
			CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( i );
			if( pPlayer !is null && pPlayer.IsConnected() )
			{
				outConnected++;
				if( pPlayer.IsAlive() )
				{
					outAlive++;
				}
			}
		}
	}

	void UpdateOnRemove()
	{
		ClearBossHUD(); // Ultimate safety: if the entity is deleted by a map event, clear the HUD first
		
		if( health_bar_entities[0].GetEntity() is self )
			health_bar_entities[0] = null;

		BaseClass.UpdateOnRemove();
	}

	bool HasFlags( int iFlagVariable, int iFlags )
	{
		return (iFlagVariable & iFlags) != 0;
	}
}

void Register()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "target_healthbar::target_healthbar", "target_healthbar" );
	g_Game.PrecacheOther( "target_healthbar" );
}

} //end of namespace target_healthbar