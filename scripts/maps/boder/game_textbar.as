/*QUAKED game_textbar (0 1 0) (-8 -8 -8) (8 8 8) START_INACTIVE START_WITH_SCAN
* Hook up health bars to monsters/breakables using safe, ultra-optimized HUD text rendering.
* Supports up to 2 targets displayed simultaneously on a single HUD channel.
* "delay" is how long to show the health bar for after death.
* "target" can be a single name or two names separated by a semicolon (e.g., boss1;boss2)
* "message" is their name (Overrides automatic naming. Separate with semicolon for two names: Name1;Name2)
* Automatic naming checks: custom message > player netname > monster FormattedName > entity DisplayName > "Boss"
* "color" is the primary text color (R G B format, e.g., 255 0 0)
* "color2" is the scan-out typewriter color (R G B format, e.g., 255 255 255)
* "effect" is the persistent text effect: 0 = normal (default), 1 = credits flicker
* "fadein" is the fade-in speed (Default: 0.0)
* "fadeout" is the fade-out speed (Default: 0.02)
* "fxtime" is the typewriter letter delay for the scan-out intro (Default: 0.06)
* "x" is the horizontal screen position (-1.0 for center)
* "y" is the vertical screen position (0.0 to 1.0)
* "channel" is the HUD text channel to use (1-4)
* Spawnflag START_WITH_SCAN plays a one-time scan-out typewriter effect when the bar first appears,
* then switches to the chosen "effect" for all subsequent updates.
*/

namespace game_textbar
{

const int SF_START_INACTIVE  = 1;
const int SF_START_WITH_SCAN = 2;

const int MAX_HEALTH_BARS   = 1;
const uint MAX_TARGETS      = 2;

array<EHandle> health_bar_entities( MAX_HEALTH_BARS );

class game_textbar : ScriptBaseEntity
{
	private array<EHandle> m_hTargets( MAX_TARGETS );
	private float m_flDelay;
	private array<int> m_iBarValues( MAX_TARGETS );    // Characters to draw per target (0 to 60)
	private float m_flTimeToRemove;
	private int m_iMaxCharacters = 60;                 // 60 characters is safe for 640x480 minimum resolution
	private bool m_bIsActive = false;
	private array<string> m_szBarNames( MAX_TARGETS ); // Display name per target

	// CUSTOMIZABLE VISUAL PARAMETERS (via KeyValues)
	private uint8 m_r = 255;
	private uint8 m_g = 0;
	private uint8 m_b = 0;
	private uint8 m_r2 = 255;
	private uint8 m_g2 = 255;
	private uint8 m_b2 = 255;
	private int m_iEffect = 0;       // Persistent effect: 0 = normal, 1 = credits flicker
	private float m_flFadeIn = 0.0;
	private float m_flFadeOut = 0.02;
	private float m_flFxTime = 0.06; // Typewriter letter speed for scan-out intro
	private float m_flX = -1.0;
	private float m_flY = 0.08;
	private int m_iChannel = 1;

	// SCAN-OUT INTRO STATE
	private bool m_bScanDone = false; // True after the one-time scan-out intro has played

	// ULTRA OPTIMIZED REFRESH VARIABLES
	private array<int> m_iLastBarValues( MAX_TARGETS ); // Bar values from the previous think
	private float m_flLastRefreshTime = 0.0;             // Tracks when we last physically updated the HUD
	private float m_flFailsafeInterval = 60.0;           // Humongous 60-second fallback to save massive resources

	// JOIN & RESPAWN DETECTION TRACKERS
	private int m_iLastConnectedCount = 0;  // Tracks how many total players are on the server
	private int m_iLastAliveCount = 0;      // Tracks how many players are currently alive

	game_textbar()
	{
		for( uint i = 0; i < MAX_TARGETS; i++ )
		{
			m_iBarValues[i] = m_iMaxCharacters;
			m_iLastBarValues[i] = -1;
			m_szBarNames[i] = "";
		}
	}

	bool KeyValue( const string& in szKey, const string& in szValue )
	{
		if( szKey == "delay" )
		{
			m_flDelay = atof( szValue );
			return true;
		}
		else if( szKey == "color" )
		{
			array<string> rgb = szValue.Split(" ");
			if( rgb.length() >= 3 )
			{
				m_r = uint8( atoi(rgb[0]) );
				m_g = uint8( atoi(rgb[1]) );
				m_b = uint8( atoi(rgb[2]) );
			}
			return true;
		}
		else if( szKey == "color2" )
		{
			array<string> rgb = szValue.Split(" ");
			if( rgb.length() >= 3 )
			{
				m_r2 = uint8( atoi(rgb[0]) );
				m_g2 = uint8( atoi(rgb[1]) );
				m_b2 = uint8( atoi(rgb[2]) );
			}
			return true;
		}
		else if( szKey == "effect" )
		{
			m_iEffect = atoi( szValue );
			if( m_iEffect < 0 ) m_iEffect = 0;
			if( m_iEffect > 1 ) m_iEffect = 1;
			return true;
		}
		else if( szKey == "fadein" )
		{
			m_flFadeIn = atof( szValue );
			return true;
		}
		else if( szKey == "fadeout" )
		{
			m_flFadeOut = atof( szValue );
			return true;
		}
		else if( szKey == "fxtime" )
		{
			m_flFxTime = atof( szValue );
			return true;
		}
		else if( szKey == "x" )
		{
			m_flX = atof( szValue );
			return true;
		}
		else if( szKey == "y" )
		{
			m_flY = atof( szValue );
			return true;
		}
		else if( szKey == "channel" )
		{
			m_iChannel = atoi( szValue );
			if( m_iChannel < 1 ) m_iChannel = 1;
			if( m_iChannel > 4 ) m_iChannel = 4;
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

		SetUse( UseFunction(this.use_game_textbar) );

		// If START_INACTIVE spawnflag is set, we sit dormant and wait for a Use trigger
		if( (pev.spawnflags & SF_START_INACTIVE) != 0 )
		{
			m_bIsActive = false;
		}
		else
		{
			// Otherwise, wake up automatically 1 second after map startup
			m_bIsActive = true;
			SetThink( ThinkFunction(this.check_game_textbar) );
			pev.nextthink = g_Engine.time + 1.0;
		}
	}

	void check_game_textbar()
	{
		// Try to find at least the first target name listed
		array<string> targetNames = string(pev.target).Split(";");
		CBaseEntity@ target = g_EntityFuncs.FindEntityByTargetname( null, targetNames[0] );
		if( target is null )
		{
			ClearBossHUD();
			g_EntityFuncs.Remove( self );
			return;
		}

		// Target found — hand off to the real activation function
		this.use_game_textbar( null, null, USE_TOGGLE, 0.0 );
	}

	void HealthbarThink()
	{
		UpdateHealthbarValue();

		if( m_flTimeToRemove > 0.0 )
			return;

		int currentConnected = 0;
		int currentAlive = 0;
		GetPlayerCounts(currentConnected, currentAlive);

		bool forceRefresh = false;

		if( currentConnected != m_iLastConnectedCount or currentAlive > m_iLastAliveCount )
		{
			forceRefresh = true;
		}

		m_iLastConnectedCount = currentConnected;
		m_iLastAliveCount = currentAlive;

		// Check if any active target's bar value has changed since last think
		bool valueChanged = false;
		for( uint i = 0; i < MAX_TARGETS; i++ )
		{
			if( m_hTargets[i].IsValid() && m_iBarValues[i] != m_iLastBarValues[i] )
			{
				valueChanged = true;
				break;
			}
		}

		if( valueChanged or forceRefresh or (g_Engine.time - m_flLastRefreshTime) >= m_flFailsafeInterval )
		{
			DrawText();
			for( uint i = 0; i < MAX_TARGETS; i++ )
			{
				m_iLastBarValues[i] = m_iBarValues[i];
			}
			m_flLastRefreshTime = g_Engine.time;
		}

		pev.nextthink = g_Engine.time + 1.0;
	}

	void use_game_textbar( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue )
	{
		// If we are already running the logic loop, ignore further inputs
		if( m_bIsActive and health_bar_entities[0].IsValid() )
			return;

		if( health_bar_entities[0].IsValid() )
		{
			g_Game.AlertMessage( at_error, "%1: too many health bars active\n", self.GetClassname() );
			g_EntityFuncs.Remove( self );
			return;
		}

		array<string> targetNames = string(pev.target).Split(";");
		array<string> overrideNames = string(pev.message).Split(";");

		// Find up to MAX_TARGETS entities. If only one name is given, find the first two
		// entities sharing that name (e.g., two monsters with the same targetname).
		uint foundTargets = 0;
		CBaseEntity@ pSearchFrom = null;

		for( uint i = 0; i < MAX_TARGETS; i++ )
		{
			// Use the second name if provided, otherwise keep searching under the first name
			string szSearchName = ( i < targetNames.length() ) ? targetNames[i] : targetNames[0];

			// When reusing the same name for a second entity, continue the search from
			// where we left off so we don't find the same entity twice
			if( i > 0 && targetNames.length() == 1 )
				@pSearchFrom = m_hTargets[foundTargets - 1].GetEntity();
			else
				@pSearchFrom = null;

			CBaseEntity@ target = g_EntityFuncs.FindEntityByTargetname( pSearchFrom, szSearchName );

			if( target is null )
				continue;

			m_hTargets[foundTargets] = EHandle( target );

			// OPTIMIZED AUTO-NAME CASCADE WITH DIRECT "BOSS N" FALLBACK
			if( foundTargets < overrideNames.length() && !overrideNames[foundTargets].IsEmpty() )
			{
				// Priority 1: Mapper provided a custom 'message' override
				m_szBarNames[foundTargets] = overrideNames[foundTargets];
			}
			else if( target.pev.FlagBitSet(FL_CLIENT) )
			{
				// Priority 2: Target is a Player/Client
				m_szBarNames[foundTargets] = string( target.pev.netname );
			}
			else if( target.pev.FlagBitSet(FL_MONSTER) )
			{
				CBaseMonster@ pMonster = target.MyMonsterPointer();
				if( pMonster !is null && !string(pMonster.m_FormattedName).IsEmpty() )
				{
					// Priority 3: Monster has a formatted display name (Sven Co-op native)
					m_szBarNames[foundTargets] = string( pMonster.m_FormattedName );
				}
				else if( !string(target.pev.message).IsEmpty() )
				{
					// Priority 4: Monster has a DisplayName set in pev.message
					m_szBarNames[foundTargets] = string( target.pev.message );
				}
				else
				{
					m_szBarNames[foundTargets] = ( foundTargets == 0 ) ? "Boss" : "Boss 2";
				}
			}
			else if( !string(target.pev.message).IsEmpty() )
			{
				// Priority 3 (non-monster): Target has a DisplayName set in pev.message
				m_szBarNames[foundTargets] = string( target.pev.message );
			}
			else
			{
				// Ultimate Failsafe: default to "Boss" or "Boss 2" for the second target
				m_szBarNames[foundTargets] = ( foundTargets == 0 ) ? "Boss" : "Boss 2";
			}

			foundTargets++;
		}

		if( foundTargets == 0 )
		{
			g_Game.AlertMessage( at_error, "%1: cannot find any targets on Use activation\n", self.GetClassname() );
			g_EntityFuncs.Remove( self );
			return;
		}

		health_bar_entities[0] = EHandle( self );
		GetPlayerCounts(m_iLastConnectedCount, m_iLastAliveCount);

		m_bScanDone = false;
		m_bIsActive = true;
		SetThink( ThinkFunction(this.HealthbarThink) );
		pev.nextthink = g_Engine.time + 0.1; // Wake up immediately upon trigger
	}

	// Returns true only when every tracked target is confirmed dead
	bool AreAllTargetsDead()
	{
		for( uint i = 0; i < MAX_TARGETS; i++ )
		{
			if( !m_hTargets[i].IsValid() )
				continue;

			CBaseEntity@ pEnt = m_hTargets[i].GetEntity();
			if( pEnt !is null && pEnt.pev.health > 0 && pEnt.pev.deadflag == DEAD_NO )
				return false;
		}
		return true;
	}

	void DrawText( float flHoldTime = -1.0 )
	{
		if( flHoldTime < 0.0 )
			flHoldTime = m_flFailsafeInterval + 0.1;

		string sFinalHUDMessage = "";
		bool bFirstAdded = false;
		bool bInDeathDelay = ( m_flTimeToRemove > 0.0 );

		for( uint idx = 0; idx < MAX_TARGETS; idx++ )
		{
			if( !m_hTargets[idx].IsValid() )
				continue;

			// During normal operation, skip any target that is already dead so its bar
			// disappears from the layout cleanly. During the post-death delay we keep
			// all bars visible (they are frozen at 0) until the entity removes itself.
			if( m_iBarValues[idx] <= 0 && !bInDeathDelay )
				continue;

			string sBar = "";
			for( int i = 0; i < m_iBarValues[idx]; i++ )
				sBar += "|";

			int emptyChars = m_iMaxCharacters - m_iBarValues[idx];
			for( int i = 0; i < emptyChars; i++ )
				sBar += "-";

			if( bFirstAdded )
				sFinalHUDMessage += "\n\n";

			sFinalHUDMessage += m_szBarNames[idx] + "\n" + sBar;
			bFirstAdded = true;
		}

		if( !sFinalHUDMessage.IsEmpty() )
		{
			CG_DrawHUDStringAll( sFinalHUDMessage, flHoldTime );
		}
		else
		{
			// Failsafe: if every target was filtered out, clear the HUD
			ClearBossHUD();
		}
	}

	void CG_DrawHUDStringAll( const string &in sString, float flHoldTime )
	{
		HUDTextParams textParms;
		textParms.channel  = m_iChannel;
		textParms.x        = m_flX;
		textParms.y        = m_flY;
		textParms.holdTime = flHoldTime;
		textParms.r1 = m_r;  textParms.g1 = m_g;  textParms.b1 = m_b;
		textParms.r2 = m_r2; textParms.g2 = m_g2; textParms.b2 = m_b2;

		bool bPlayScan = ( (pev.spawnflags & SF_START_WITH_SCAN) != 0 ) && !m_bScanDone;

		if( bPlayScan )
		{
			// One-time scan-out intro: effect 2 with full typewriter parameters
			textParms.effect      = 2;
			textParms.fadeinTime  = m_flFadeIn;
			textParms.fadeoutTime = m_flFadeOut;
			textParms.fxTime      = m_flFxTime;
			m_bScanDone = true;
		}
		else
		{
			// Persistent effect chosen by mapper (0 = normal, 1 = credits flicker)
			textParms.effect      = m_iEffect;
			textParms.fadeinTime  = ( m_iEffect == 0 ) ? 0.0 : m_flFadeIn;
			textParms.fadeoutTime = ( m_iEffect == 0 ) ? 0.0 : m_flFadeOut;
			textParms.fxTime      = 0.0;
		}

		g_PlayerFuncs.HudMessageAll( textParms, sString + "\n" );
	}

	void ClearBossHUD()
	{
		HUDTextParams textParms;
		textParms.fadeinTime = 0.0;
		textParms.fadeoutTime = 0.0;
		textParms.holdTime = 0.1;
		textParms.channel = m_iChannel;
		textParms.x = m_flX;
		textParms.y = m_flY;
		g_PlayerFuncs.HudMessageAll( textParms, "" );
	}

	void UpdateHealthbarValue()
	{
		if( m_flTimeToRemove > 0.0 )
		{
			if( m_flTimeToRemove < g_Engine.time )
			{
				ClearBossHUD();
				g_EntityFuncs.Remove( self );
			}
			return;
		}

		for( uint i = 0; i < MAX_TARGETS; i++ )
		{
			if( !m_hTargets[i].IsValid() )
				continue;

			CBaseEntity@ pEnt = m_hTargets[i].GetEntity();

			if( pEnt is null or pEnt.pev.health <= 0 or pEnt.pev.deadflag != DEAD_NO )
			{
				m_iBarValues[i] = 0;
				continue;
			}

			float health_remaining = pEnt.pev.health / pEnt.pev.max_health;
			m_iBarValues[i] = int( health_remaining * float(m_iMaxCharacters) );

			// Keep at least one pip visible while the target is confirmed alive.
			// health can round down to 0 characters before deadflag is ever set.
			if( m_iBarValues[i] <= 0 )
				m_iBarValues[i] = 1;
		}

		if( AreAllTargetsDead() )
		{
			if( m_flDelay > 0.0 )
			{
				m_flTimeToRemove = g_Engine.time + m_flDelay;
				DrawText( m_flDelay );
			}
			else
			{
				ClearBossHUD();
				g_EntityFuncs.Remove( self );
			}
		}
	}

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
					outAlive++;
			}
		}
	}

	void UpdateOnRemove()
	{
		ClearBossHUD();

		if( health_bar_entities[0].GetEntity() is self )
			health_bar_entities[0] = EHandle();

		BaseClass.UpdateOnRemove();
	}
}

void Register()
{
	g_CustomEntityFuncs.RegisterCustomEntity( "game_textbar::game_textbar", "game_textbar" );
	g_Game.PrecacheOther( "game_textbar" );
}

} //end of namespace game_textbar
