#include <sourcemod>
#include <sdktools>
#include <cstrike>

#define PLUGIN_AUTHOR	"rgsilva"
#define PLUGIN_VERSION	"1.0"
#pragma semicolon 1

public Plugin:myinfo =
{
	name = "GameStats",
	author = PLUGIN_AUTHOR,
	description = "Provides a command to get detailed game information",
	version = PLUGIN_VERSION,
	url = "https://github.com/rgsilva/sourcemod-plugins"
};

public OnPluginStart()
{
	RegConsoleCmd("sm_gamestats", Cmd_PlayerStats);
}

public Action Cmd_PlayerStats(int client, int args) {
  PrintToConsole(client, "-- Game stats --");

  for (new i = 1; i <= MaxClients; i++) {
    if (IsClientInGame(i) && !(IsClientSourceTV(i))) {
      int team = GetClientTeam(i);
      if (team == CS_TEAM_CT || team == CS_TEAM_T) {
        int frags = GetEntProp(i, Prop_Data, "m_iFrags");
        int deaths = GetEntProp(i, Prop_Data, "m_iDeaths");
        int money = GetEntProp(i, Prop_Send, "m_iAccount");

        int health;
        if (IsPlayerAlive(i)) {
          health = GetEntProp(i, Prop_Send, "m_iHealth");
        } else {
          health = 0;
        }

        new String:name[MAX_NAME_LENGTH];
        GetClientName(i, name, sizeof(name));

        PrintToConsole(client, "Player: %s, T: %d, K: %d, D: %d, M: %d, H: %d", name, team, frags, deaths, money, health);
      }
    }
  }

  int ct_score = CS_GetTeamScore(CS_TEAM_CT);
  int t_score = CS_GetTeamScore(CS_TEAM_T);

  PrintToConsole(client, "Score: CT: %d, TR: %d", ct_score, t_score);
  PrintToConsole(client, "----");

  return Plugin_Handled;
}
