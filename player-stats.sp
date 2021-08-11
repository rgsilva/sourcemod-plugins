#include <sourcemod>
#include <sdktools>

#define PLUGIN_AUTHOR	"rgsilva"
#define PLUGIN_VERSION	"1.0"
#pragma semicolon 1

public Plugin:myinfo =
{
	name = "PlayerStats",
	author = PLUGIN_AUTHOR,
	description = "Provides a command to get detailed player information",
	version = PLUGIN_VERSION,
	url = "https://github.com/rgsilva/sourcemod-plugins"
};

public OnPluginStart()
{
	RegConsoleCmd("sm_playerstats", Cmd_PlayerStats);
}

public Action Cmd_PlayerStats(int client, int args)
{
  PrintToConsole(client, "----- Player Stats -----");

  for (new i = 1; i <= MaxClients; i++)
  {
    if (IsClientInGame(i) && !(IsClientSourceTV(i)))
    {
        new String:name[MAX_NAME_LENGTH];
        int frags = GetEntProp(i, Prop_Data, "m_iFrags");
        int deaths = GetEntProp(i, Prop_Data, "m_iDeaths");
        GetClientName(i, name, sizeof(name));
        PrintToConsole(client, "%s, K: %d, D: %d", name, frags, deaths);
    }
  }

  PrintToConsole(client, "------------------------");
}
