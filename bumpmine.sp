#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#include <smlib2> // https://github.com/laper32/smlib2

#define BUMPMINE_EXPLOSION_DAMAGE 300.0     // 爆炸伤害
#define BUMPMINE_EXPLOSION_RADIUS 450.0     // 爆炸范围
#define BUMPMINE_SENSOR_RADIUS 100.0        // 检测范围

public Plugin myinfo = 
{
    name        = "Explosion Bumpmine", 
    author      = "Kroytz", 
    description = "Made bumpmine as a explosion mine", 
    version     = "1.0", 
    url         = "https://github.com/Kroytz"
};

public void OnEntityCreated(int entity, const char[] classname)
{
    if (strcmp("bumpmine_projectile", classname, false) == 0)
        SDKHook(entity, SDKHook_Spawn, BumpmineSpawnHook);
}

public void BumpmineSpawnHook(int grenade)
{
    // stop hook
    SDKUnhook(grenade, SDKHook_Spawn, BumpmineSpawnHook);

    SetEntProp(grenade, Prop_Data, "m_nNextThinkTick", -1);
    CreateTimer(0.3, GrenadeThinkHook, EntIndexToEntRef(grenade), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);

    // hook player touch
    SDKHook(grenade, SDKHook_StartTouch, BumpmineTouchHook);
}

public Action GrenadeThinkHook(Handle hTimer, int refID)
{
    // Gets entity index from reference key
    int grenade = EntRefToEntIndex(refID);
    
    // Check if the grenade is still valid
    if (grenade != -1)
    {
        if (GetEntProp(grenade, Prop_Send, "m_bArmed"))
        {
            // block grenade
            SetEntProp(grenade, Prop_Data, "m_nNextThinkTick", -1);

            // Gets grenade origin
            float vPosition[3];
            GetEntPropVector(grenade, Prop_Data, "m_vecAbsOrigin", vPosition);

            // sensor radius
            float vSensorPos[3]; float vFinal[3]; bool bFound = false;
            for (int i = 1; i <= MaxClients; i++)
            {
                if (!PlayerEx.IsExist(i))
                    continue;

                GetClientAbsOrigin(i, vSensorPos);
                SubtractVectors(vPosition, vSensorPos, vFinal);

                if (GetVectorLength(vFinal) <= BUMPMINE_SENSOR_RADIUS)
                {
                    bFound = true;
                    BumpmineTouchHook(grenade, i);
                    break;
                }
            }

            if (bFound)
                return Plugin_Stop;
        }

        return Plugin_Continue;
    }

    return Plugin_Stop;
}

public Action BumpmineTouchHook(int grenade, int target)
{
    // invalid entity?
    if (!IsValidEntity(grenade))
        return Plugin_Continue;

    // invalid player?
    if (!PlayerEx.IsExist(target))
        return Plugin_Continue;

    // gets owner
    int owner = GetEntPropEnt(grenade, Prop_Data, "m_hOwnerEntity");

    // gets origin
    float vPosition[3];
    GetEntPropVector(grenade, Prop_Data, "m_vecAbsOrigin", vPosition);

    // trigger explosion
    UTIL.CreateExplosion(vPosition, _, _, BUMPMINE_EXPLOSION_DAMAGE, BUMPMINE_EXPLOSION_RADIUS, "weapon_bumpmine", owner);

    // remove bumpmine
    SDKUnhook(grenade, SDKHook_Touch, BumpmineTouchHook);
    AcceptEntityInput(grenade, "Kill");

    return Plugin_Continue;
}