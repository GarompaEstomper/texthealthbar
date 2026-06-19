/*QUAKED game_textbar (0 1 0) (-8 -8 -8) (8 8 8) START_INACTIVE
* Hook up health bars to monsters/breakables using safe, ultra-optimized HUD text rendering.
* "delay" is how long to show the health bar for after death.
* "message" is their name (Overrides automatic naming)
* "color" is the text color (R G B format, e.g., 255 0 0)
* "x" is the horizontal screen position (-1.0 for center)
* "y" is the vertical screen position (0.0 to 1.0)
* "channel" is the HUD text channel to use (1-4)
*/

namespace game_textbar
{

const int SF_START_INACTIVE = 1;
const int MAX_HEALTH_BARS   = 1;

array<EHandle> health_bar_entities( MAX_HEALTH_BARS );

class game_textbar : ScriptBaseEntity
{
    private EHandle m_hTarget;
    private float m_flDelay;
    private int m_iBarValue; // Represents the amount of characters to draw (0 to 60)
    private float m_flTimeToRemove;
    private int m_iMaxCharacters = 60; // 60 characters is safe for 640x480 minimum resolution
    private bool m_bIsActive = false;
    private string m_szBarName = ""; 

    // CUSTOMIZABLE VISUAL PARAMETERS (via KeyValues)
    private uint8 m_r = 255;
    private uint8 m_g = 0;
    private uint8 m_b = 0;
    private float m_flX = -1.0;
    private float m_flY = 0.08;
    private int m_iChannel = 1;

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

        m_iBarValue = m_iMaxCharacters;
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

    void check_game_textbar()
    {
        CBaseEntity@ target = g_EntityFuncs.FindEntityByTargetname( null, string(pev.target) );
        if( target is null )
        {
            ClearBossHUD();
            g_EntityFuncs.Remove( self );
            return;
        }
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

        if( m_iBarValue != m_iLastBarValue or forceRefresh or (g_Engine.time - m_flLastRefreshTime) >= m_flFailsafeInterval )
        {
            DrawText( m_flFailsafeInterval + 0.1 );
            m_iLastBarValue = m_iBarValue;
            m_flLastRefreshTime = g_Engine.time;
        }

        pev.nextthink = g_Engine.time + 1.0;
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

        CBaseEntity@ target = g_EntityFuncs.FindEntityByTargetname( null, string(pev.target) );
        if( target is null )
        {
            pev.nextthink = g_Engine.time + 1.0;
            if( pActivator is null )
                SetThink( ThinkFunction(this.AutoStartThink) );
            else
                g_Game.AlertMessage( at_error, "%1: cannot find target '%2' on Use activation\n", self.GetClassname(), string(pev.target) );
            return;
        }

        m_hTarget = EHandle( target );
        health_bar_entities[0] = EHandle( self );

        // 1. Priority Override: Did the mapper set a custom message name directly on this textbar?
        if( !string(pev.message).IsEmpty() )
        {
            m_szBarName = string( pev.message );
        }
        // 2. Is the target a player? Use their network handle profile name
        else if( target.pev.FlagBitSet(FL_CLIENT) )
        {
            m_szBarName = string( target.pev.netname );
        }
        // 3. Mimicking Original Script: Extract Sven's auto-processed displayname formatting safely
        else if( target.pev.FlagBitSet(FL_MONSTER) )
        {
            CBaseMonster@ pMonster = target.MyMonsterPointer();
            if( pMonster !is null && !string(pMonster.m_FormattedName).IsEmpty() )
            {
                m_szBarName = string( pMonster.m_FormattedName );
            }
            else if( !string(target.pev.message).IsEmpty() )
            {
                m_szBarName = string( target.pev.message );
            }
            else
            {
                m_szBarName = "Boss";
            }
        }
        // 4. Final Fallback if targeted at a breakable wall or general entity
        else if( !string(target.pev.message).IsEmpty() )
        {
            m_szBarName = string( target.pev.message );
        }
        else
        {
            m_szBarName = "Boss";
        }

        GetPlayerCounts(m_iLastConnectedCount, m_iLastAliveCount);

        m_bIsActive = true;
        SetThink( ThinkFunction(this.HealthbarThink) );
        pev.nextthink = g_Engine.time + 0.1;
    }

    void DrawText( float flCustomHoldTime )
    {
        string sHealthBarVisual = "";

        for( int i = 0; i < m_iBarValue; i++ )
        {
            sHealthBarVisual += "|";
        }

        int emptyCharacters = m_iMaxCharacters - m_iBarValue;
        for( int i = 0; i < emptyCharacters; i++ )
        {
            sHealthBarVisual += "-";
        }

        string sFinalHUDMessage = m_szBarName + "\n" + sHealthBarVisual;
        CG_DrawHUDStringAll( sFinalHUDMessage, flCustomHoldTime );
    }

    void CG_DrawHUDStringAll( const string &in sString, float flHoldTime )
    {
        HUDTextParams textParms;
        textParms.fadeinTime = 0.0;
        textParms.fadeoutTime = 0.02;
        textParms.holdTime = flHoldTime;
        textParms.effect = 0;
        textParms.channel = m_iChannel;
        textParms.x = m_flX; 
        textParms.y = m_flY;
        textParms.r1 = m_r;  textParms.g1 = m_g;  textParms.b1 = m_b;
        textParms.r2 = m_r;  textParms.g2 = m_g;  textParms.b2 = m_b;

        g_PlayerFuncs.HudMessageAll( textParms, sString + "\n" );
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
        }
        else
        {
            if( !m_hTarget.IsValid() or m_hTarget.GetEntity().pev.health <= 0 or m_hTarget.GetEntity().pev.deadflag != DEAD_NO )
            {
                if( m_flDelay > 0.0 )
                {
                    m_flTimeToRemove = g_Engine.time + m_flDelay;
                    m_iBarValue = 0; 
                    DrawText( m_flDelay ); 
                }
                else
                {
                    ClearBossHUD(); 
                    g_EntityFuncs.Remove( self );
                }
    
                return;
            }

            float health_remaining = m_hTarget.GetEntity().pev.health / m_hTarget.GetEntity().pev.max_health;
            m_iBarValue = int( health_remaining * float(m_iMaxCharacters) );

            if( m_iBarValue <= 0 )
            {
                m_iBarValue = 1;
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