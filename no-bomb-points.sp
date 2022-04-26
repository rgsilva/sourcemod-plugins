#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <halflife>

#define PLUGIN_AUTHOR	"rgsilva"
#define PLUGIN_VERSION	"1.0"
#pragma semicolon 1

public Plugin:myinfo =
{
	name = "NoBombPoints",
	author = PLUGIN_AUTHOR,
	description = "Removes the extra 3 points you gain from exploding or defusing a bomb",
	version = PLUGIN_VERSION,
	url = "https://github.com/rgsilva/sourcemod-plugins"
};

new Handle:cvarPluginEnabled;
new bool:pluginEnabled;

public OnPluginStart()
{
    pluginEnabled = true;
    cvarPluginEnabled = CreateConVar("sm_nobombpoints", "1", "Is No Bomb Points enabled? 1 = true (no points) 0 = false (points)", _, true, 0.0, true, 1.0);
    HookConVarChange(cvarPluginEnabled, OnConVarChanged);

    HookEvent("bomb_exploded", OnBombExploded);
    HookEvent("bomb_defused", OnBombDefused);
}

public OnConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[]) {
    if (convar == cvarPluginEnabled) {
        pluginEnabled = GetConVarBool(cvarPluginEnabled);
    }
}

public Action:OnBombExploded(Handle:event, const String:name[], bool:dontBroadcast) {
    if (!pluginEnabled) {
        return Plugin_Handled;
    }

    int clientId = GetClientOfUserId(GetEventInt(event, "userid"));
    int currentFrags = GetEntProp(clientId, Prop_Data, "m_iFrags");
    SetEntProp(clientId, Prop_Data, "m_iFrags", currentFrags - 3);

    return Plugin_Handled;
}

public Action:OnBombDefused(Handle:event, const String:name[], bool:dontBroadcast) {
    if (!pluginEnabled) {
        return Plugin_Handled;
    }

    int clientId = GetClientOfUserId(GetEventInt(event, "userid"));
    int currentFrags = GetEntProp(clientId, Prop_Data, "m_iFrags");
    SetEntProp(clientId, Prop_Data, "m_iFrags", currentFrags - 3);

    return Plugin_Handled;
}
