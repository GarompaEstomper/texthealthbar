/*QUAKED target_healthbar (0 1 0) (-8 -8 -8) (8 8 8) PLAYERNAME DISPLAYNAME
* Hook up health bars to monsters using safe HUD text rendering.
* "delay" is how long to show the health bar for after death.
* "message" is their name
* This script was made by Neyami/Nero and heavily modified by Garompa to fix lag
* Sprites looked nice but there was no way to make them centered without splitting the bar in 2 sprites causing issues with other resolutions so they were removed
* By removing sprites we made a healthbar out of text only. Using channel 1 of game_text. We also save resources by making that text global instead of going through each player, generating more lag
* Because the text is now global it made no sense to have the PVS mode, so it was removed, saving on a lot of resources
* Because it uses channel 1 text, it can have a longer holdtime than the refresh time without stacking and causing overflow since it is replaced when refreshing, meaning it won't have the issue of flashing on and off when having lag
* With this, its a simplified and dumbed down version, but it should not lag any servers at all, and it should stop flashing
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
	private int m_iBarValue; // Now represents the amount of characters to draw (0 to 50)
	private float m_flTimeToRemove;
	private int m_iMaxCharacters = 60; // Defined a 50-character bar (each one equals 2% health)

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
			g_EntityFuncs.Remove( self );
			return;
		}
	}

	void HealthbarThink()
	{
		UpdateHealthbarValue();

		// Call DrawText globally
		DrawText();

		// Refresh every 1.0 second
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
			// Replace the first dash with a line to denote that it has one pixel of health left
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
		textParms.holdTime = 1.5; // Perfectly synchronized with the 1.0s RefreshTime (with a minimal margin to prevent flickering)
		textParms.effect = 0;
		textParms.channel = HUD_TEXT_HEALTHBAR;
		textParms.x = -1.0; // Perfect automatic centering on all screens
		textParms.y = 0.08;
		
		// Pure Red Color
		textParms.r1 = 255;  textParms.g1 = 0;  textParms.b1 = 0;
		textParms.r2 = 255;  textParms.g2 = 0;  textParms.b2 = 0;

		// Sends the text message to all players simultaneously
		g_PlayerFuncs.HudMessageAll( textParms, sString + "\n" );
	}

	void UpdateHealthbarValue()
	{
		if( m_flTimeToRemove > 0.0 )
		{
			if( m_flTimeToRemove < g_Engine.time )
				g_EntityFuncs.Remove( self );
		}
		else
		{
			if( !m_hTarget.IsValid() or m_hTarget.GetEntity().pev.health <= 0 or m_hTarget.GetEntity().pev.deadflag != DEAD_NO )
			{
				if( m_flDelay > 0.0 )
				{
					m_flTimeToRemove = g_Engine.time + m_flDelay;
					m_iBarValue = 0;
				}
				else
					g_EntityFuncs.Remove( self );
	
				return;
			}

			// Calculate how many characters out of the 50 total should be drawn based on health percentage
			float health_remaining = m_hTarget.GetEntity().pev.health / m_hTarget.GetEntity().pev.max_health;
			m_iBarValue = int( health_remaining * float(m_iMaxCharacters) );
		}
	}

	void UpdateOnRemove()
	{
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