/* Custom Hooks by Outerbeast
Extension of native hooks for Sven Co-op's Angeslcript API
Usage: import this into your script then build and register your hook functions as you would with regular hooks, making sure to use "g_CustomHooks".
Refer to the AngelScript wiki on how to use hooks: https://github.com/baso88/SC_AngelScript/wiki/Hooks

TO-DO:
- Optimise code to utilise less cpu
- Add stopmodes
- function reflection stuff for getting hook function names
*/
const Vector g_vecWorldMins = Vector( -WORLD_BOUNDARY, -WORLD_BOUNDARY, -WORLD_BOUNDARY );
const Vector g_vecWorldMaxs = Vector( WORLD_BOUNDARY, WORLD_BOUNDARY, WORLD_BOUNDARY );
// Hook IDs
namespace CustomHooks
{

namespace Player
{
const uint32 PlayerSee         = 0x0045;
const uint32 PlayerTouch       = 0x01A4;
}

namespace Monster
{
const uint32 MonsterTakeDamage = 0x029A;
const uint32 MonsterKilled     = 0x0539;
}

}
// Hook signatures
funcdef HookReturnCode PlayerSeeHook(CBasePlayer@, CBaseEntity@, uint& out);
funcdef HookReturnCode PlayerTouchHook(CBasePlayer@, CBaseEntity@, uint& out);
funcdef HookReturnCode MonsterTakeDamageHook(CBaseMonster@, CBaseEntity@, float, int);
funcdef HookReturnCode MonsterKilledHook(CBaseMonster@, CBaseEntity@);
// Hook function handles
array<PlayerSeeHook@>           FN_PLAYER_SEE_HOOKS;
array<PlayerTouchHook@>         FN_PLAYER_TOUCH_HOOKS;
array<MonsterTakeDamageHook@>   FN_MONSTER_TAKEDAMAGE_HOOKS;
array<MonsterKilledHook@>       FN_MONSTER_KILLED_HOOKS;

CCustomHooks g_CustomHooks;

const CScheduledFunction@ fnHookThink = g_Scheduler.SetInterval( g_CustomHooks, "HookThink", 0.1f, g_Scheduler.REPEAT_INFINITE_TIMES );
const bool blMapChangeHook = g_Hooks.RegisterHook( Hooks::Game::MapChange, MapChangeHook( g_CustomHooks.ResetEntityInfo ) );

final class CCustomHooks
{
    protected bool blInitialised;

    protected HookReturnCode hrcPlayerTouchHandled, hrcPlayerSeeHandled, hrcMonsterTakeDamageHandled, hrcMonsterKilledHandled;

    protected int iTotalEntities;
    
    protected array<CBaseEntity@>   P_LIVING_ENTITIES( 128 ), P_BRUSH_ENTITIES( 128 ), P_ALL_ENTITIES;
    protected array<int>            I_PLAYER_SEEN( g_Engine.maxClients + 1 ), I_PLAYER_TOUCHED( g_Engine.maxClients + 1 );
    protected array<float>          FL_MONSTER_LAST_DMG_TAKEN( g_Engine.maxEntities + 1 );
    protected array<bool>           BL_MONSTER_DEAD( g_Engine.maxEntities + 1 );

    bool RegisterHook(const uint32 iHookID, ref @fn)
    {
        if( fn is null )
        {
            g_Log.PrintF( "CCustomHooks::RegisterHook : function is null!\n" );
            return false;
        }

        bool blRegistered;

        switch( iHookID )
        {
            case CustomHooks::Player::PlayerTouch:
            {
                PlayerTouchHook@ fnPlayerTouch = cast<PlayerTouchHook@>( fn );

                if( fnPlayerTouch is null )
                {
                    g_Log.PrintF( "CCustomHooks::RegisterHook : Could not register PlayerTouch Hook: selected hook function is invalid!\n" );
                    break;
                }

                if( FN_PLAYER_TOUCH_HOOKS.findByRef( fnPlayerTouch ) < 0 )
                {
                    FN_PLAYER_TOUCH_HOOKS.insertLast( @fnPlayerTouch );
                    g_Log.PrintF( "CCustomHooks::RegisterHook : Registering hook PlayerTouch\n" );

                    blRegistered = FN_PLAYER_TOUCH_HOOKS.findByRef( fnPlayerTouch ) >= 0;
                }
                else
                    g_Log.PrintF( "CCustomHooks::RegisterHook : PlayerTouch Hook already registered!\n" );

                break;
            }

            case CustomHooks::Player::PlayerSee:
            {
                PlayerSeeHook@ fnPlayerSee = cast<PlayerSeeHook@>( fn );

                if( fnPlayerSee is null )
                {
                    g_Log.PrintF( "CCustomHooks::RegisterHook : Could not register PlayerTouch Hook: selected hook function is invalid!\n" );
                    break;
                }

                if( FN_PLAYER_SEE_HOOKS.findByRef( fnPlayerSee ) < 0 )
                {
                    FN_PLAYER_SEE_HOOKS.insertLast( @fnPlayerSee );
                    g_Log.PrintF( "CCustomHooks::RegisterHook : Registering hook PlayerSee\n" );

                    blRegistered = FN_PLAYER_SEE_HOOKS.findByRef( fnPlayerSee ) >= 0;
                }
                else
                    g_Log.PrintF( "CCustomHooks::RegisterHook : PlayerSee Hook already registered!\n" );

                break;
            }

            case CustomHooks::Monster::MonsterTakeDamage:
            {
                MonsterTakeDamageHook@ fnMonsterTakeDamage = cast<MonsterTakeDamageHook@>( fn );

                if( fnMonsterTakeDamage is null )
                {
                    g_Log.PrintF( "CCustomHooks::RegisterHook : Could not register MonsterTakeDamage Hook: selected hook function is invalid!\n" );
                    break;
                }

                if( FN_MONSTER_TAKEDAMAGE_HOOKS.findByRef( fnMonsterTakeDamage ) < 0 )
                {
                    FN_MONSTER_TAKEDAMAGE_HOOKS.insertLast( @fnMonsterTakeDamage );
                    g_Log.PrintF( "CCustomHooks::RegisterHook : Registering hook MonsterTakeDamage\n" );

                    blRegistered = FN_MONSTER_TAKEDAMAGE_HOOKS.findByRef( fnMonsterTakeDamage ) >= 0;
                }
                else
                    g_Log.PrintF( "CCustomHooks::RegisterHook : MonsterTakeDamage Hook already registered!\n" );

                break;
            }

            case CustomHooks::Monster::MonsterKilled:
            {
                MonsterKilledHook@ fnMonsterKilled = cast<MonsterKilledHook@>( fn );

                if( fnMonsterKilled is null )
                {
                    g_Log.PrintF( "CCustomHooks::RegisterHook : Could not register MonsterKilled Hook: selected hook function is invalid!\n" );
                    break;
                }
                
                if( FN_MONSTER_KILLED_HOOKS.findByRef( fnMonsterKilled ) < 0 )
                {
                    FN_MONSTER_KILLED_HOOKS.insertLast( fnMonsterKilled );
                    g_Log.PrintF( "CCustomHooks::RegisterHook : Registering hook MonsterKilled\n" );

                    blRegistered = FN_MONSTER_KILLED_HOOKS.findByRef( fnMonsterKilled ) >= 0;
                }
                else
                    g_Log.PrintF( "CCustomHooks::RegisterHook : MonsterKilled Hook already registered!\n" );

                break;
            }

            default:
                g_Log.PrintF( "CCustomHooks::RegisterHook : Invalid hook ID!\n" );
        }

        return blRegistered;
    }

    void RemoveHook(const uint32 iHookID, ref @fn)
    {
        if( fn is null )
            RemoveHook( iHookID );

        switch( iHookID )
        {
            case CustomHooks::Player::PlayerTouch:
            {
                PlayerTouchHook@ fnPlayerTouch = cast<PlayerTouchHook@>( fn );

                if( fnPlayerTouch is null )
                {
                    g_Log.PrintF( "CCustomHooks::RemoveHook : Could not remove PlayerTouch Hook: selected hook function is invalid!\n" );
                    break;
                }

                if( FN_PLAYER_TOUCH_HOOKS.findByRef( fnPlayerTouch ) >= 0 )
                {
                    FN_PLAYER_TOUCH_HOOKS.removeAt( FN_PLAYER_TOUCH_HOOKS.findByRef( fnPlayerTouch ) );
                    g_Log.PrintF( "CCustomHooks::RemoveHook : Removed hook PlayerTouch\n" );

                    break;
                }                
            }

            case CustomHooks::Player::PlayerSee:
            {
                PlayerSeeHook@ fnPlayerSee = cast<PlayerSeeHook@>( fn );

                if( fnPlayerSee is null )
                {
                    g_Log.PrintF( "CCustomHooks::RemoveHook : Could not remove PlayerSee Hook: selected hook function is invalid!\n" );
                    break;
                }

                if( FN_PLAYER_SEE_HOOKS.findByRef( fnPlayerSee ) >= 0 )
                {
                    FN_PLAYER_SEE_HOOKS.removeAt( FN_PLAYER_SEE_HOOKS.findByRef( fnPlayerSee ) );
                    g_Log.PrintF( "CCustomHooks::RemoveHook : Removed hook PlayerSee\n" );

                    break;
                }
            }

            case CustomHooks::Monster::MonsterTakeDamage:
            {
                MonsterTakeDamageHook@ fnMonsterTakeDamage = cast<MonsterTakeDamageHook@>( fn );

                if( fnMonsterTakeDamage is null )
                {
                    g_Log.PrintF( "CCustomHooks::RemoveHook : Could not remove MonsterTakeDamage Hook: selected hook function is invalid!\n" );
                    break;
                }

                if( FN_MONSTER_TAKEDAMAGE_HOOKS.findByRef( fnMonsterTakeDamage ) >= 0 )
                {
                    FN_MONSTER_TAKEDAMAGE_HOOKS.removeAt( FN_MONSTER_TAKEDAMAGE_HOOKS.findByRef( fnMonsterTakeDamage ) );
                    g_Log.PrintF( "CCustomHooks::RemoveHook : Removed hook MonsterTakeDamage\n" );

                    break;
                }
            }

            case CustomHooks::Monster::MonsterKilled:
            {
                MonsterKilledHook@ fnMonsterKilled = cast<MonsterKilledHook@>( fn );

                if( fnMonsterKilled is null )
                {
                    g_Log.PrintF( "CCustomHooks::RemoveHook : Could not remove MonsterKilled Hook: selected hook function is invalid!\n" );
                    break;
                }
                
                if( FN_MONSTER_KILLED_HOOKS.findByRef( fnMonsterKilled ) >= 0 )
                {
                    FN_MONSTER_KILLED_HOOKS.removeAt( FN_MONSTER_KILLED_HOOKS.findByRef( fnMonsterKilled ) );
                    g_Log.PrintF( "CCustomHooks::RemoveHook : Registering hook MonsterKilled\n" );

                    break;
                }
            }

            default:
                g_Log.PrintF( "CCustomHooks::RemoveHook : Invalid hook ID!\n" );
                break;
        }
    }

    void RemoveHook(const uint32 iHookID)
    {
        switch( iHookID )
        {
            case CustomHooks::Player::PlayerTouch:
            {
                FN_PLAYER_TOUCH_HOOKS.resize( 0 );
                g_Log.PrintF( "CCustomHooks::RemoveHook : All PlayerTouch hooks removed\n" );
                break;
            }

            case CustomHooks::Player::PlayerSee:
                FN_PLAYER_SEE_HOOKS.resize( 0 );
                g_Log.PrintF( "CCustomHooks::RemoveHook : All PlayerSee hooks removed\n" );
                break;
                
            case CustomHooks::Monster::MonsterTakeDamage:
            {
                FN_MONSTER_TAKEDAMAGE_HOOKS.resize( 0 );
                g_Log.PrintF( "CCustomHooks::RemoveHook : All MonsterTakeDamage hooks removed\n" );
                break;
            }
                
            case CustomHooks::Monster::MonsterKilled:
            {
                FN_MONSTER_KILLED_HOOKS.resize( 0 );
                g_Log.PrintF( "CCustomHooks::RemoveHook : All MonsterKilled hooks removed\n" );
                break;
            }

            default:
                g_Log.PrintF( "CCustomHooks::RemoveHook : Invalid hook ID!\n" );
                break;
        }
    }

    protected bool HookInitialise()
    {
        if( blInitialised )
            return true;

        blInitialised = true;

        return blInitialised;
    }

    protected void HookThink()
    {
        if( !blInitialised )
        {
            blInitialised = HookInitialise();
            return;
        }
        // WIP: Only try to refresh entity handles when the total number of entities change, so to save cycles
        //iTotalEntities = g_EngineFuncs.NumberOfEntities();

        //if( iTotalEntities != g_EngineFuncs.NumberOfEntities() )
            GetEntities();

        if( FN_PLAYER_SEE_HOOKS.length() > 0 )
            HookEvent_PlayerSee();

        if( FN_PLAYER_TOUCH_HOOKS.length() > 0 && P_ALL_ENTITIES.length() > 0 )
            HookEvent_PlayerTouch();

        if( FN_MONSTER_TAKEDAMAGE_HOOKS.length() > 0 && P_LIVING_ENTITIES.length() > 0 )
            HookEvent_MonsterTakeDamage();

        if( FN_MONSTER_KILLED_HOOKS.length() > 0  && P_LIVING_ENTITIES.length() > 0  )
            HookEvent_MonsterKilled();
    }

    protected void GetEntities()
    {
        int iNumLivingEntities = g_EntityFuncs.EntitiesInBox( @P_LIVING_ENTITIES, g_vecWorldMins, g_vecWorldMaxs, FL_MONSTER );
        int iNumBrushes = g_EntityFuncs.BrushEntsInBox( @P_BRUSH_ENTITIES, g_vecWorldMins, g_vecWorldMaxs );
        // Speed up processing by clearing out any nullptrs
        while( P_LIVING_ENTITIES.find( null ) >= 0 )
            P_LIVING_ENTITIES.removeAt( P_LIVING_ENTITIES.find( null ) );
            
        while( P_BRUSH_ENTITIES.find( null ) >= 0 )
            P_BRUSH_ENTITIES.removeAt( P_BRUSH_ENTITIES.find( null ) );
        // Theres no way to adjoin two arrays together in AngelScript.
        for( uint i = 0; i < P_LIVING_ENTITIES.length(); i++ )
        {
            if( P_LIVING_ENTITIES[i] is null )
                continue;

            P_ALL_ENTITIES.insertLast( P_LIVING_ENTITIES[i] );
        }

        for( uint i = 0; i < P_BRUSH_ENTITIES.length(); i++ )
        {
            if( P_BRUSH_ENTITIES[i] is null )
                continue;

            P_ALL_ENTITIES.insertLast( P_BRUSH_ENTITIES[i] );
        }
    }

    protected void HookEvent_PlayerSee()
    {
        for( int iPlayer = 1; iPlayer <= g_PlayerFuncs.GetNumPlayers(); iPlayer++ )
        {
            CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayer );

            if( pPlayer is null || !pPlayer.IsConnected() || !pPlayer.IsInWorld() )
            {
                I_PLAYER_SEEN[iPlayer] = 0;
                continue;
            }

            CBaseEntity@ pOther = g_Utility.FindEntityForward( pPlayer );

            if( pOther is null )
            {
                I_PLAYER_SEEN[iPlayer] = 0;
                continue;
            }

            if( I_PLAYER_SEEN[iPlayer] != pOther.entindex() )
            {
                for( uint j = 0; j < FN_PLAYER_SEE_HOOKS.length(); j++ )
                {
                    if( FN_PLAYER_SEE_HOOKS[j] is null )
                        continue;

                    uint uiConstantSeeOut;

                    hrcPlayerSeeHandled = FN_PLAYER_SEE_HOOKS[j]( pPlayer, pOther, uiConstantSeeOut );

                    if( uiConstantSeeOut < 1 )
                        I_PLAYER_SEEN[iPlayer] = pOther.entindex();
                }
            }
        }
    }
    // This likely whats causing a lot of cpu usage
    protected void HookEvent_PlayerTouch()
    {
        for( int iPlayer = 1; iPlayer <= g_PlayerFuncs.GetNumPlayers(); iPlayer++ )
        {
            CBasePlayer@ pPlayer = g_PlayerFuncs.FindPlayerByIndex( iPlayer );

            if( pPlayer is null || !pPlayer.IsConnected() || !pPlayer.IsInWorld() )
            {
                I_PLAYER_TOUCHED[iPlayer] = 0;
                continue;
            }
            
            if( I_PLAYER_TOUCHED[iPlayer] > 0 && g_EntityFuncs.Instance( I_PLAYER_TOUCHED[iPlayer] ) !is null )
            {
                if( !pPlayer.Intersects( g_EntityFuncs.Instance( I_PLAYER_TOUCHED[iPlayer] ) ) )
                    I_PLAYER_TOUCHED[iPlayer] = 0;
            }

            for( uint i = 0; i < P_ALL_ENTITIES.length(); i++ )
            {
                CBaseEntity@ pEntity = P_ALL_ENTITIES[i];

                if( pEntity is null || pPlayer is pEntity || cast<CBasePlayerItem@>( pEntity ) !is null )
                    continue;

                if( pEntity.pev.size == g_vecZero )
                    continue;

                if( pPlayer.Intersects( pEntity ) && I_PLAYER_TOUCHED[iPlayer] != pEntity.entindex() )
                {
                    for( uint j = 0; j < FN_PLAYER_TOUCH_HOOKS.length(); j++ )
                    {
                        if( FN_PLAYER_TOUCH_HOOKS[j] is null )
                            continue;

                        uint uiTouchSettingOut;

                        hrcPlayerTouchHandled = FN_PLAYER_TOUCH_HOOKS[j]( pPlayer, pEntity, uiTouchSettingOut );

                        if( uiTouchSettingOut < 1 )
                            I_PLAYER_TOUCHED[iPlayer] = pEntity.entindex();
                    }
                }
            }
        }
    }

    protected void HookEvent_MonsterTakeDamage()
    {
        for( uint i = 0; i < P_LIVING_ENTITIES.length(); i++ )
        {
            CBaseMonster@ pMonster = cast<CBaseMonster@>( P_LIVING_ENTITIES[i] );

            if( pMonster is null || pMonster.IsPlayer() || !pMonster.IsMonster() || !pMonster.IsAlive() )
                continue;

            if( pMonster.pev.dmg_take != FL_MONSTER_LAST_DMG_TAKEN[i] )
            {
                FL_MONSTER_LAST_DMG_TAKEN[i] = pMonster.pev.dmg_take;

                for( uint j = 0; j < FN_MONSTER_TAKEDAMAGE_HOOKS.length(); j++ )
                {
                    if( FN_MONSTER_TAKEDAMAGE_HOOKS[j] is null )
                        continue;

                    float flDamage = pMonster.pev.dmg_take;
                    int bitsDamageType = pMonster.m_bitsDamageType;

                    hrcMonsterTakeDamageHandled = 
                        FN_MONSTER_TAKEDAMAGE_HOOKS[j]( pMonster, g_EntityFuncs.Instance( pMonster.pev.dmg_inflictor ), flDamage, bitsDamageType );
                    //!-LIMITATION-!: Can't use this because "Only object types that support object handles can use &inout. Use &in or &out instead". AngelScript was made by toddlers
                    //if( pMonster.IsAlive() && flDamage != pMonster.pev.dmg_take ) // Means that the function overridden the damage value passed in
                        //pMonster.TakeDamage( g_EntityFuncs.Instance( pMonster.pev.dmg_inflictor ), g_EntityFuncs.Instance( pMonster.pev.dmg_inflictor ), flDamage, bitsDamageType );
                }
            }
        }
    }
    // Hook is being called while the npc is dead, not only when the moment it was killed
    // !-BUG-!: Hook is not called again if the npc was revived
    protected void HookEvent_MonsterKilled()
    {
        for( uint i = 0; i < P_LIVING_ENTITIES.length(); i++ )
        {
            CBaseMonster@ pMonster = cast<CBaseMonster@>( P_LIVING_ENTITIES[i] );

            if( pMonster is null || 
                pMonster.IsPlayer() || 
                !pMonster.IsMonster() /* || 
                BL_MONSTER_DEAD[pMonster.entindex()] */ )
                continue;
            // !-BUG-!: only health < 1 catches the entity being killed, other 2 methods don't work
            if( !pMonster.IsAlive() || pMonster.pev.deadflag != DEAD_NO || pMonster.pev.health < 1.0f ) 
            {
                BL_MONSTER_DEAD[pMonster.entindex()] = true;

                for( uint j = 0; j < FN_MONSTER_KILLED_HOOKS.length(); j++ )
                {
                    if( FN_MONSTER_KILLED_HOOKS[j] is null )
                        continue;

                    hrcMonsterKilledHandled = FN_MONSTER_KILLED_HOOKS[j]( pMonster, g_EntityFuncs.Instance( pMonster.pev.dmg_inflictor ) );
                }
            }
        }

        for( uint k = 0; k < BL_MONSTER_DEAD.length(); k++ )
        {
            if( !BL_MONSTER_DEAD[k] )
                continue;

            CBaseEntity@ pMonster = cast<CBaseMonster@>( g_EntityFuncs.Instance( k ) );

            if( pMonster is null || pMonster.IsAlive() )
                BL_MONSTER_DEAD[k] = false;
        }
    }

    HookReturnCode ResetEntityInfo()
    {
        if( !blInitialised )
            return HOOK_CONTINUE;

        P_LIVING_ENTITIES.resize( 0 );
        P_BRUSH_ENTITIES.resize( 0 );
        P_ALL_ENTITIES.resize( 0 );

        I_PLAYER_TOUCHED.resize( 0 );
        I_PLAYER_SEEN.resize( 0 );
        FL_MONSTER_LAST_DMG_TAKEN.resize( 0 );
        BL_MONSTER_DEAD.resize( 0 );

        I_PLAYER_TOUCHED.resize( g_Engine.maxClients + 1 );
        I_PLAYER_SEEN.resize( g_Engine.maxClients + 1 );
        FL_MONSTER_LAST_DMG_TAKEN.resize( g_Engine.maxEntities + 1 );
        BL_MONSTER_DEAD.resize( g_Engine.maxEntities + 1 );

        blInitialised = false;

        return HOOK_CONTINUE;
    }
}
