#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <files>

#define PLUGIN_AUTHOR	"rgsilva"
#define PLUGIN_VERSION	"1.3"
#pragma semicolon 1

#define MAX_PASSWORD_LENGTH 32
#define PASSWORD_FILE "plugins/game-stats.pass"

new String:pluginPassword[MAX_PASSWORD_LENGTH];

public Plugin:myinfo =
{
	name = "GameStats",
	author = PLUGIN_AUTHOR,
	description = "Provides a password-protected command to get detailed game information",
	version = PLUGIN_VERSION,
	url = "https://github.com/rgsilva/sourcemod-plugins"
};


public OnPluginStart()
{
  LoadPasswordFromFile();
  RegConsoleCmd("sm_gamestats", Cmd_GameStats);
}

void LoadPasswordFromFile() {
  new String:passFilePath[PLATFORM_MAX_PATH];
  BuildPath(Path_SM, passFilePath, sizeof(passFilePath), PASSWORD_FILE);

  File passFile = OpenFile(passFilePath, "r");
  if (passFile) {
    passFile.ReadLine(pluginPassword, sizeof(pluginPassword));
    TrimString(pluginPassword);
    passFile.Close();
  } else {
    strcopy(pluginPassword, MAX_PASSWORD_LENGTH, "");
  }
}

public Action Cmd_GameStats(int client, int args) {
  if (!IsPluginConfigured()) {
    ReplyToCommand(client, "[SM] Plugin is not configured: the password file (%s) is missing!", PASSWORD_FILE);
    return Plugin_Handled;
  }

  if (args != 1) {
    ReplyToCommand(client, "[SM] Usage: sm_gamestats <password>");
    return Plugin_Handled;
  }

  new String:password[MAX_NAME_LENGTH];
  GetCmdArg(1, password, sizeof(password));
  if (!IsPasswordCorrect(password)) {
    ReplyToCommand(client, "[SM] Nice try, but that's the wrong password.");
    return Plugin_Handled;
  }

  PrintGameStats(client);

  return Plugin_Handled;
}

void PrintGameStats(int client) {
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

  PrintToConsole(client, "Score: %d, %d", ct_score, t_score);
  PrintToConsole(client, "----");
}

bool IsPluginConfigured() {
  return !StrEqual(pluginPassword, "");
}

bool IsPasswordCorrect(char[] password) {
  return StrEqual(password, pluginPassword);
}