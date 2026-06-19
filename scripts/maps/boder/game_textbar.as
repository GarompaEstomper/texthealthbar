/*QUAKED game_textbar (0 1 0) (-8 -8 -8) (8 8 8) START_INACTIVE
* Hook up health bars to monsters/breakables using safe, ultra-optimized HUD text rendering.
* Supports up to 2 targets displayed simultaneously on a single HUD channel.
* "delay" is how long to show the health bar for after death.
* "target" can be a single name or two names separated by a semicolon (e.g., boss1;boss2)
* "message" is their name (Overrides automatic naming. Separate with semicolon for two names: Name1;Name2)
* "color" is the primary text color (R G B format, e.g., 255 0 0)
* "color2" is the effect / typewriter background color (R G B format, e.g., 255 255 255)
* "effect" is the text effect (0 = Fade in/out, 1 = Credits/Flicker, 2 = Scan out)
* "fadein" is the fade-in or character transition speed (Default: 0.03)
* "fadeout" is the fade-out speed.
* "fxtime" is the typewriter letter delay speed for Scan Out (Default: 1.0)
* "x" is the horizontal screen position (-1.0 for center)
* "y" is the vertical screen position (0.0 to 1.0)
* "channel" is the HUD text channel to use (1-4)
*/

namespace game_textbar
{

const int SF_START_INACTIVE = 1;
const int MAX_HEALTH_BARS   = 1;
const uint MAX_TARGETS      = 2; 

array<EHandle> health_bar_entities( MAX_HEALTH_BARS );

class game_textbar : ScriptBaseEntity
{
    private array<EHandle> m_hTargets( MAX_TARGETS );
    private float m_flDelay;
    private array<int> m_iBarValues( MAX_TARGETS );
    private float m_flTimeToRemove;
    private int m_iMaxCharacters = 60; 
    private bool m_bIsActive = false;
    private array<string> m_szBarNames( MAX_TARGETS ); 

    // CUSTOMIZABLE VISUAL PARAMETERS (via KeyValues)
    private uint8 m_r = 255;
    private uint8 m_g = 0;
    private uint8 m_b = 0;
    private uint8 m_r2 = 100;
    private uint8 m_g2 = 100;
    private uint8 m_b2 = 200;
	
    private int m_iEffect = 2;
    private float m_flFadeIn = 0.02;
    private float m_flFadeOut = 0.02;  
    private float m_flFxTime = 0.6;

    private float m_flX = -1.0;
    private float m_flY = 0.05; 
    private int m_iChannel = 1;

    // STATE TRACKING FOR SCAN OUT EFFECT
    private bool m_bFirstDrawDone = false; 

    // ULTRA OPTIMIZED REFRESH VARIABLES
    private array<int> m_iLastBarValues( MAX_TARGETS ); 
    private float m_flLastRefreshTime = 0.0; 
    private float m_flFailsafeInterval = 60.0; 

    // JOIN & RESPAWN DETECTION TRACKERS
    private int m_iLastConnectedCount = 0; 
    private int m_iLastAliveCount = 0; 

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
        if( (pev.spawnflags & SF_START_INACTIVE) != 0 )
        {
            m_bIsActive = false;
        }
        else
        {
            SetThink( ThinkFunction(this.AutoStartThink) );
            pev.nextthink = g_Engine.time + 1.0;
        }
    }

    void AutoStartThink()
    {
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
            DrawText( m_flFailsafeInterval + 0.1 );
            for( uint i = 0; i < MAX_TARGETS; i++ )
            {
                m_iLastBarValues[i] = m_iBarValues[i];
            }
            m_flLastRefreshTime = g_Engine.time;
        }

        pev.nextthink = g_Engine.time + 0.2; 
    }

    void use_game_textbar( CBaseEntity@ pActivator, CBaseEntity@ pCaller, USE_TYPE useType, float flValue )
    {
        if( health_bar_entities[0].IsValid() )
        {
            if( health_bar_entities[0].GetEntity() is self )
                return;
            g_Game.AlertMessage( at_error, "%1: too many health bars active\n", self.GetClassname() );
            g_EntityFuncs.Remove( self );
            return;
        }

        health_bar_entities[0] = EHandle( self );

        array<string> targetNames = string(pev.target).Split(";");
        array<string> overrideNames = string(pev.message).Split(";");

        uint foundTargets = 0;
        
        for( uint i = 0; i < MAX_TARGETS; i++ )
        {
            string currentSearchName = (i < targetNames.length()) ? targetNames[i] : targetNames[0];
            CBaseEntity@ target = null;

            if( i == 1 && targetNames.length() == 1 )
            {
                @target = g_EntityFuncs.FindEntityByTargetname( m_hTargets[0].GetEntity(), currentSearchName );
            }
            else
            {
                @target = g_EntityFuncs.FindEntityByTargetname( null, currentSearchName );
            }

            if( target is null )
                continue;

            m_hTargets[foundTargets] = EHandle( target );

            if( i < overrideNames.length() && !overrideNames[i].IsEmpty() )
            {
                m_szBarNames[foundTargets] = overrideNames[i];
            }
            else if( target.pev.FlagBitSet(FL_CLIENT) )
            {
                m_szBarNames[foundTargets] = string( target.pev.netname );
            }
            else if( target.pev.FlagBitSet(FL_MONSTER) )
            {
                CBaseMonster@ pMonster = target.MyMonsterPointer();
                if( pMonster !is null && !string(pMonster.m_FormattedName).IsEmpty() )
                {
                    m_szBarNames[foundTargets] = string( pMonster.m_FormattedName );
                }
                else if( !string(target.pev.message).IsEmpty() )
                {
                    m_szBarNames[foundTargets] = string( target.pev.message );
                }
                else
                {
                    m_szBarNames[foundTargets] = "Boss " + (foundTargets + 1);
                }
            }
            else if( !string(target.pev.message).IsEmpty() )
            {
                m_szBarNames[foundTargets] = string( target.pev.message );
            }
            else
            {
                m_szBarNames[foundTargets] = "Boss " + (foundTargets + 1);
            }

            foundTargets++;
        }

        if( foundTargets == 0 )
        {
            pev.nextthink = g_Engine.time + 1.0;
            if( pActivator is null )
                SetThink( ThinkFunction(this.AutoStartThink) );
            else
                g_Game.AlertMessage( at_error, "%1: cannot find any targets on Use activation\n", self.GetClassname() );
            return;
        }

        GetPlayerCounts(m_iLastConnectedCount, m_iLastAliveCount);

        m_bIsActive = true;
        m_bFirstDrawDone = false; 
        SetThink( ThinkFunction(this.HealthbarThink) );
        pev.nextthink = g_Engine.time + 0.1;
    }

    // CHECK IF ALL POTENTIAL BOSSES ARE ALREADY DEAD
    bool AreAllTargetsDead()
    {
        for( uint i = 0; i < MAX_TARGETS; i++ )
        {
            if( !m_hTargets[i].IsValid() )
                continue;

            CBaseEntity@ pTargetEnt = m_hTargets[i].GetEntity();
            if( pTargetEnt !is null && pTargetEnt.pev.health > 0 && pTargetEnt.pev.deadflag == DEAD_NO )
            {
                return false; 
            }
        }
        return true;
    }

    void DrawText( float flCustomHoldTime )
    {
        string sFinalHUDMessage = "";
        bool bFirstAdded = false;
        bool bShowAllDeadDelay = (m_flTimeToRemove > 0.0);

        for( uint idx = 0; idx < MAX_TARGETS; idx++ )
        {
            if( !m_hTargets[idx].IsValid() )
                continue;

            // DYNAMIC LAYOUT REARRANGEMENT: 
            // If the boss is dead, don't draw it at all, EXCEPT if ALL bosses are dead and we are currently processing the post-death delay.
            if( m_iBarValues[idx] <= 0 && !bShowAllDeadDelay )
                continue;

            string sHealthBarVisual = "";
            for( int i = 0; i < m_iBarValues[idx]; i++ )
            {
                sHealthBarVisual += "|";
            }

            int emptyCharacters = m_iMaxCharacters - m_iBarValues[idx];
            for( int i = 0; i < emptyCharacters; i++ )
            {
                sHealthBarVisual += "-";
            }

            if( bFirstAdded )
                sFinalHUDMessage += "\n\n"; 

            sFinalHUDMessage += m_szBarNames[idx] + "\n" + sHealthBarVisual;
            bFirstAdded = true;
        }

        if( !sFinalHUDMessage.IsEmpty() )
        {
            CG_DrawHUDStringAll( sFinalHUDMessage, flCustomHoldTime );
        }
        else
        {
            // Failsafe: if layout results in an empty message, clear the screen
            ClearBossHUD();
        }
    }

    void CG_DrawHUDStringAll( const string &in sString, float flHoldTime )
    {
        HUDTextParams textParms;
        textParms.channel = m_iChannel;
        textParms.x = m_flX;
        textParms.y = m_flY;
        textParms.holdTime = flHoldTime;
        
        if( !m_bFirstDrawDone )
        {
            textParms.effect = m_iEffect;
            textParms.fadeinTime = m_flFadeIn;
            textParms.fadeoutTime = m_flFadeOut;
            textParms.fxTime = m_flFxTime;
        }
        else
        {
            textParms.effect = 0;
            textParms.fadeinTime = 0.0;
            textParms.fadeoutTime = 0.0;
            textParms.fxTime = 0.0;
        }
        
        textParms.r1 = m_r;  textParms.g1 = m_g;  textParms.b1 = m_b;
        textParms.r2 = m_r2; textParms.g2 = m_g2; textParms.b2 = m_b2;

        g_PlayerFuncs.HudMessageAll( textParms, sString + "\n" );

        if( !m_bFirstDrawDone )
        {
            m_bFirstDrawDone = true;
        }
    }

    void ClearBossHUD()
    {
        HUDTextParams textParms;
        textParms.fadeinTime = 0.0;
        textParms.fadeoutTime = 0.0;
        textParms.holdTime = 0.01; 
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

        bool allDead = AreAllTargetsDead();

        for( uint i = 0; i < MAX_TARGETS; i++ )
        {
            if( !m_hTargets[i].IsValid() )
                continue;

            CBaseEntity@ pTargetEnt = m_hTargets[i].GetEntity();

            if( pTargetEnt is null or pTargetEnt.pev.health <= 0 or pTargetEnt.pev.deadflag != DEAD_NO )
            {
                // Force dead bosses to 0 layout length so they get filtered out of the layout
                m_iBarValues[i] = 0; 
                continue; 
            }

            float health_remaining = pTargetEnt.pev.health / pTargetEnt.pev.max_health;
            m_iBarValues[i] = int( health_remaining * float(m_iMaxCharacters) );

            if( m_iBarValues[i] <= 0 )
            {
                m_iBarValues[i] = 1;
            }
        }

        if( allDead )
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
                {
                    outAlive++;
                }
            }
        }
    }

    void UpdateOnRemove()
    {
        ClearBossHUD();
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