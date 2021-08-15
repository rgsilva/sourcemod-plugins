#include <sourcemod>
#include <sdktools>
#include <cstrike>

#define PLUGIN_AUTHOR	"rgsilva"
#define PLUGIN_VERSION	"1.1"
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
  if (client) {
    return Plugin_Handled;
  }

  PrintToConsole(client, "-- Game stats --");

  for (new i = 1; i <= MaxClients; i++) {
    if (IsClientInGame(i) && !(IsClientSourceTV(i))) {
      int team = GetClientTeam(i);
      if (team == CS_TEAM_CT || team == CS_TEAM_T) {
        // Get frags, deaths and money.
        int frags = GetEntProp(i, Prop_Data, "m_iFrags");
        int deaths = GetEntProp(i, Prop_Data, "m_iDeaths");
        int money = GetEntProp(i, Prop_Send, "m_iAccount");

        // Get health, but only if the player is alive. Otherwise it's zero.
        int health;
        if (IsPlayerAlive(i)) {
          health = GetEntProp(i, Prop_Send, "m_iHealth");
        } else {
          health = 0;
        }

        // Get the player name.
        new String:name[MAX_NAME_LENGTH];
        GetClientName(i, name, sizeof(name));

        // Check if the player has the bomb.
        bool has_bomb = (GetPlayerWeaponSlot(i, CS_SLOT_C4) != -1);

        // Check if the player has a defuse kit.        
        bool has_defuse = (GetEntProp(i, Prop_Send, "m_bHasDefuser"));

        PrintToConsole(client, "Player: %s, %d, %d, %d, %d, %d, %d, %d", name, team, frags, deaths, money, health, has_bomb, has_defuse);
      }
    }
  }

  int ct_score = CS_GetTeamScore(CS_TEAM_CT);
  int t_score = CS_GetTeamScore(CS_TEAM_T);

  PrintToConsole(client, "Score: CT: %d, TR: %d", ct_score, t_score);
  PrintToConsole(client, "----");

  return Plugin_Handled;
}
