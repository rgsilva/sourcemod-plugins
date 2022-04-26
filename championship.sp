#include <sourcemod>
#include <sdktools>
#include <cstrike>

#define PLUGIN_AUTHOR  "rgsilva"
#define PLUGIN_VERSION "1.0"
#pragma semicolon 1

#define MAX_ARG_LENGTH 4
#define NOTIFY_CVAR_CHANGES true
#define MAXROUNDS 100
#define TIMELIMIT 180
#define RESTARGAME_TIME 3

public Plugin:myinfo =
{
    name = "Championship",
    author = PLUGIN_AUTHOR,
    description = "Custom championship mode",
    version = PLUGIN_VERSION,
    url = "https://github.com/rgsilva/sourcemod-plugins"
};

bool championshipRunning;
int normalRounds;
int overtimeRounds;
float normalMoney;
float overtimeMoney;

Handle cvarWinLimit;
Handle cvarMaxRounds;
Handle cvarTimeLimit;

int originalWinLimit;
int originalMaxRounds;
int originalTimeLimit;

public OnPluginStart()
{
    championshipRunning = false;

    RegConsoleCmd("start_championship", CmdStartChampionship);
    RegConsoleCmd("end_championship", CmdEndChampionship);

    cvarWinLimit = FindConVar("mp_winlimit");
    cvarMaxRounds = FindConVar("mp_maxrounds");
    cvarTimeLimit = FindConVar("mp_timelimit");

    HookEvent("round_end", OnRoundEnd);
}

public OnMapStart() {
    EndChampionship(true);
}

public Action CmdStartChampionship(int client, int args) {
    if (args != 4) {
        ReplyToCommand(client, "[SM] Usage: start_championship <normal rounds> <overtime rounds> <normal money amount> <overtime money amount>");
        return Plugin_Handled;
    }

    if (championshipRunning) {
        ReplyToCommand(client, "[SM] Cannot start championship: another one is running. Please end it first.");
        return Plugin_Handled;
    }

    new String:temp[MAX_ARG_LENGTH];
    GetCmdArg(1, temp, sizeof(temp));
    int _normalRounds = StringToInt(temp);
    GetCmdArg(2, temp, sizeof(temp));
    int _overtimeRounds = StringToInt(temp);
    GetCmdArg(3, temp, sizeof(temp));
    float _normalMoney = StringToFloat(temp);
    GetCmdArg(4, temp, sizeof(temp));
    float _overtimeMoney = StringToFloat(temp);

    if (_normalRounds <= 0 || _overtimeRounds <= 0 || _normalRounds % 2 != 0 || _overtimeRounds % 2 != 0) {
        ReplyToCommand(client, "[SM] Cannot start championship: number of rounds must be a multiple of 2 and bigger than zero!");
        return Plugin_Handled;
    }

    if (_normalMoney <= 0 || _overtimeMoney <= 0) {
        ReplyToCommand(client, "[SM] Cannot start championship: money cannot be zero!");
        return Plugin_Handled;
    }

    ReplyToCommand(client, "[SM] Starting championship with %d normal rounds (start money: %.2f) and %d overtime ones (start money: %.2f). Have fun and good luck!",
        _normalRounds, _overtimeRounds, _normalMoney, _overtimeMoney);
    StartChampionship(_normalRounds, _overtimeRounds, _normalMoney, _overtimeMoney);

    return Plugin_Handled;
}

public Action CmdEndChampionship(int client, int args) {
    if (!championshipRunning) {
        ReplyToCommand(client, "[SM] Cannot end championship: there isn't one running. Please start it first.");
        return Plugin_Handled;
    }

    EndChampionship(false);

    return Plugin_Handled;
}

void StartChampionship(int _normalRounds, int _overtimeRounds, float _normalMoney, float _overtimeMoney) {
    originalWinLimit = GetConVarInt(cvarWinLimit);
    originalMaxRounds = GetConVarInt(cvarMaxRounds);
    originalTimeLimit = GetConVarInt(cvarTimeLimit);

    SetConVarInt(cvarMaxRounds, MAXROUNDS, false, NOTIFY_CVAR_CHANGES);
    SetConVarInt(cvarTimeLimit, TIMELIMIT, false, NOTIFY_CVAR_CHANGES);

    UpdateWinLimit(16);

    championshipRunning = true;
    normalRounds = _normalRounds;
    overtimeRounds = _overtimeRounds;
    normalMoney = _normalMoney;
    overtimeMoney = _overtimeMoney;

    PrintToChatAll("\x03[Championship] A new championship is starting! Have fun everyone, and good luck!");
    ServerCommand("mp_restartgame %d", RESTARGAME_TIME);
}

void EndChampionship(bool silent) {
    if (!silent) {
        PrintToChatAll("\x03[Championship] The championship has ended!");
    }

    championshipRunning = false;

    SetConVarInt(cvarMaxRounds, originalMaxRounds, false, NOTIFY_CVAR_CHANGES);
    SetConVarInt(cvarTimeLimit, originalTimeLimit, false, NOTIFY_CVAR_CHANGES);
    SetConVarInt(cvarWinLimit, originalWinLimit, false, NOTIFY_CVAR_CHANGES);
}

void EndWithWinner(int winnerTeam) {
    PrintToChatAll("\x03[Championship] And the winner is... the %s!", (winnerTeam == CS_TEAM_CT ? "Counter-Terrorists" : "Terrorists"));

    EndChampionship(false);
}

public Action OnRoundEnd(Event event, const char[] name, bool dontBroadcast) {
    int ctScore = GetTeamScore(CS_TEAM_CT);
    int tScore = GetTeamScore(CS_TEAM_T);

    if (ctScore + tScore < normalRounds) {
        // We are normal.
        
        // Keep win limit set to NR/2 + 1.
        UpdateWinLimit(normalRounds/2 + 1);

        // If any team is over NR/2points, it's a winner.
        if (ctScore > normalRounds/2) {
            // CT wins
            EndWithWinner(CS_TEAM_CT);
        } else if (tScore > normalRounds/2) {
            // TR wins
            EndWithWinner(CS_TEAM_T);
        } else {
            // Switch sides!
            UpdatePlayers(normalMoney, true);
        }
    } else if (ctScore + tScore == normalRounds) {
        // We are starting overtime!

        UpdateWinLimit(normalRounds/2 + overtimeRounds/2 + 1);
        UpdatePlayers(overtimeMoney, false);
    } else {
        // We are in overtime!

        int currentOvertimeIndex = ((ctScore + tScore - normalRounds) / 6) + 1;

        UpdateWinLimit(normalRounds/2 + (overtimeRounds/2 * currentOvertimeIndex) + 1);

        int totalOvertimePoints = (ctScore + tScore - normalRounds) % 6;
        int ctOvertimeScore = (ctScore - normalRounds/2) % 6;
        int tOvertimeScore = (tScore - normalRounds/2) % 6;

        if (totalOvertimePoints == overtimeRounds/2) {
            UpdatePlayers(overtimeMoney, true);
        } else if (ctOvertimeScore >= (overtimeRounds/2) + 1) {
            EndWithWinner(CS_TEAM_CT);
        } else if (tOvertimeScore >= (overtimeRounds/2) + 1) {
            EndWithWinner(CS_TEAM_T);
        }
    }

    return Plugin_Handled;
}

void UpdateWinLimit(int winLimit) {
    SetConVarInt(cvarWinLimit, winLimit, false, NOTIFY_CVAR_CHANGES);
}

void UpdatePlayers(float startmoney, bool switchTeams) {
    if (switchTeams) {
        PrintToChatAll("\x03[Championship] Switching sides!");
    }

    for (int client = 1; client <= MaxClients; client++)
    {
        if (IsClientInGame(client) && GetClientTeam(client) > 1)
        {
            for (int weapon, i = 0; i < 5; i++)
            {
                while ((weapon = GetPlayerWeaponSlot(client, i)) != -1)
                {
                    if (i == 4)
                        CS_DropWeapon(client, weapon, false, true);
                    else
                        RemovePlayerItem(client, weapon);
                }
            }
            
            SetEntProp(client, Prop_Send, "m_ArmorValue", 0);
            SetEntProp(client, Prop_Send, "m_bHasHelmet", 0);
            SetEntProp(client, Prop_Send, "m_bHasDefuser", 0);
            SetEntProp(client, Prop_Send, "m_iAccount", startmoney);
            
            if (switchTeams) {
                CS_SwitchTeam(client, (GetClientTeam(client) == 2) ? 3 : 2);
            }
            CS_RespawnPlayer(client);
        }
    }

    if (switchTeams) {
        int tmp = CS_GetTeamScore(2);
        CS_SetTeamScore(2, CS_GetTeamScore(3));
        CS_SetTeamScore(3, tmp);

        SetTeamScore(2, CS_GetTeamScore(2));
        SetTeamScore(3, CS_GetTeamScore(3));
    }
}