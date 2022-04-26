#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <halflife>

#define PLUGIN_AUTHOR	"rgsilva"
#define PLUGIN_VERSION	"1.1"
#pragma semicolon 1

#define MAX_BUFFER_SIZE 1024

public Plugin:myinfo =
{
	name = "TeamMoney",
	author = PLUGIN_AUTHOR,
	description = "Provides a view of your team's money during freezetime",
	version = PLUGIN_VERSION,
	url = "https://github.com/rgsilva/sourcemod-plugins"
};

Handle updateTimer = INVALID_HANDLE;
new Handle:cvarPluginEnabled;
new bool:pluginEnabled;

public OnPluginStart()
{
    pluginEnabled = true;
    cvarPluginEnabled = CreateConVar("sm_teammoney", "1", "Show team's money during freezetime? 1 = true, 0 = false", _, true, 0.0, true, 1.0);
    HookConVarChange(cvarPluginEnabled, OnConVarChanged);

    HookEvent("round_start", OnRoundStart);
    HookEvent("round_freeze_end", OnFreezeEnd);
}

public OnConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[]) {
    if (convar == cvarPluginEnabled) {
        pluginEnabled = GetConVarBool(cvarPluginEnabled);
    }
}

public void OnRoundStart(Event event, const char[] name, bool dontBroadcast) {
    if (updateTimer != INVALID_HANDLE) {
        CloseHandle(updateTimer);
    }

    if (pluginEnabled) {
        updateTimer = CreateTimer(0.25, OnTimerTrigger, _, TIMER_REPEAT);
    }
}

public Action OnTimerTrigger(Handle timer) {
    SendTeamMoneyToClients();
    return Plugin_Continue;
}

public void OnFreezeEnd(Event event, const char[] name, bool dontBroadcast) {
    if (updateTimer != INVALID_HANDLE) {
        CloseHandle(updateTimer);
        updateTimer = INVALID_HANDLE;

        ClearTeamMoney();
    }
}

void SendTeamMoneyToClients() {
    new String:terroristMoney[MAX_BUFFER_SIZE];
    GetTeamMoneyString(CS_TEAM_T, terroristMoney, MAX_BUFFER_SIZE);

    new String:counterTerroristMoney[MAX_BUFFER_SIZE];
    GetTeamMoneyString(CS_TEAM_CT, counterTerroristMoney, MAX_BUFFER_SIZE);

    for (new i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !(IsClientSourceTV(i))) {
            int client_team = GetClientTeam(i);
            if (client_team == CS_TEAM_T) {
                SendMessage(i, terroristMoney);
            } else if (client_team == CS_TEAM_CT) {
                SendMessage(i, counterTerroristMoney);
            }
        }
    }
}

void ClearTeamMoney() {
    for (new i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !(IsClientSourceTV(i))) {
            SendMessage(i, "");
        }
    }
}

void GetTeamMoneyString(int team, char[] buffer, int maxBufferSize) {
    for (new i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i) && !(IsClientSourceTV(i))) {
            if (team == GetClientTeam(i)) {
                new String:name[MAX_NAME_LENGTH];
                GetClientName(i, name, sizeof(name));
                int money = GetEntProp(i, Prop_Send, "m_iAccount");

                Format(buffer, maxBufferSize, "%s\n%s: $ %d", buffer, name, money);
            }
        }
    }
}

void SendMessage(int client, const char[] message) {
    UserMsg g_umsgKeyHintText = GetUserMessageId("KeyHintText");
    if (g_umsgKeyHintText == INVALID_MESSAGE_ID) {
        PrintToChat(client, "Client does not support key hint text!");
        return;
    }

    int players[1];
    players[0] = client;

    Handle userMessage = StartMessageEx(g_umsgKeyHintText, players, 1, 0);
    BfWriteByte(userMessage, 1);
    BfWriteString(userMessage, message);
    EndMessage();
}
