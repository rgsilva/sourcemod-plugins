#include <sourcemod>
#include <sdktools>
#include <cstrike>

#define PLUGIN_AUTHOR  "rgsilva"
#define PLUGIN_VERSION "1.4"
#pragma semicolon 1

#define MAX_ARG_LENGTH 32
#define MAXROUNDS 0
#define TIMELIMIT 0
#define RESTARTGAME_TIME 3
#define RESETGAME_TIME "2"

#define VERBOSE true

public Plugin:myinfo =
{
    name = "Championship",
    author = PLUGIN_AUTHOR,
    description = "Custom championship mode",
    version = PLUGIN_VERSION,
    url = "https://github.com/rgsilva/sourcemod-plugins"
};

bool championshipRunning;
int nextRoundMoney;
int overtimeIndex;

int normalRounds;
int overtimeRounds;
int normalMoney;
int overtimeMoney;

Handle cvarWinLimit;
Handle cvarMaxRounds;
Handle cvarTimeLimit;
Handle cvarRestartGame;

int originalWinLimit;
int originalMaxRounds;
int originalTimeLimit;

bool backupAvailable;
int backupClientFrags[MAXPLAYERS];
int backupClientDeaths[MAXPLAYERS];
int backupCtScore;
int backupTrScore;

public OnPluginStart()
{
    backupAvailable = false;

    championshipRunning = false;
    nextRoundMoney = 0;
    overtimeIndex = 0;

    RegConsoleCmd("start_championship", CmdStartChampionship);
    RegConsoleCmd("end_championship", CmdEndChampionship);

    cvarWinLimit = FindConVar("mp_winlimit");
    cvarMaxRounds = FindConVar("mp_maxrounds");
    cvarTimeLimit = FindConVar("mp_timelimit");
    cvarRestartGame = FindConVar("mp_restartgame");

    HookEvent("round_start", OnRoundStart);
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
    int _normalMoney = StringToInt(temp);

    GetCmdArg(4, temp, sizeof(temp));
    int _overtimeMoney = StringToInt(temp);

    if (_normalRounds <= 2 || _overtimeRounds <= 2 || _normalRounds % 2 != 0 || _overtimeRounds % 2 != 0) {
        ReplyToCommand(client, "[SM] Cannot start championship: number of rounds must be a multiple of 2 and bigger than 2!");
        return Plugin_Handled;
    }

    if (_normalMoney <= 0 || _overtimeMoney <= 0) {
        ReplyToCommand(client, "[SM] Cannot start championship: money must be bigger than zero!");
        return Plugin_Handled;
    }

    ReplyToCommand(client, "[SM] Starting championship with %d normal rounds (start money: %d) and %d overtime ones (start money: %d). Have fun and good luck!",
        _normalRounds, _normalMoney, _overtimeRounds, _overtimeMoney);
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

void StartChampionship(int _normalRounds, int _overtimeRounds, int _normalMoney, int _overtimeMoney) {
    overtimeIndex = 0;

    originalWinLimit = GetConVarInt(cvarWinLimit);
    originalMaxRounds = GetConVarInt(cvarMaxRounds);
    originalTimeLimit = GetConVarInt(cvarTimeLimit);

    SetConVarInt(cvarMaxRounds, MAXROUNDS, false, VERBOSE);
    SetConVarInt(cvarTimeLimit, TIMELIMIT, false, VERBOSE);

    UpdateWinLimit(16);

    championshipRunning = true;
    normalRounds = _normalRounds;
    overtimeRounds = _overtimeRounds;
    normalMoney = _normalMoney;
    overtimeMoney = _overtimeMoney;

    PrintToChatAll("\x03[Championship] A new championship is starting! Have fun everyone, and good luck!");
    ServerCommand("mp_restartgame %d", RESTARTGAME_TIME);
}

void EndChampionship(bool silent) {
    if (!silent) {
        PrintToChatAll("\x03[Championship] The championship has ended!");
    }

    championshipRunning = false;
    nextRoundMoney = 0;
    overtimeIndex = 0;

    SetConVarInt(cvarMaxRounds, originalMaxRounds, false, VERBOSE);
    SetConVarInt(cvarTimeLimit, originalTimeLimit, false, VERBOSE);
    SetConVarInt(cvarWinLimit, originalWinLimit, false, VERBOSE);
}

void EndWithWinner(int winnerTeam) {
    PrintToChatAll("\x03[Championship] And the winner is... the %s!", (winnerTeam == CS_TEAM_CT ? "Counter-Terrorists" : "Terrorists"));

    EndChampionship(false);
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast) {
    if (!championshipRunning) {
        return Plugin_Handled;
    }

    if (backupAvailable) {
        RestoreScores();
    }

    int ctScore = GetTeamScore(CS_TEAM_CT);
    int tScore = GetTeamScore(CS_TEAM_T);

    if (ctScore + tScore >= normalRounds) {
        overtimeIndex = ((ctScore + tScore - normalRounds) / overtimeRounds) + 1;
        if (VERBOSE) { PrintToChatAll("\x03[Championship] Overtime (%d) round started.", overtimeIndex); }
    }

    if (nextRoundMoney > 0) {
        UpdatePlayersMoney(nextRoundMoney);

        nextRoundMoney = 0;
    }

    return Plugin_Handled;
}

public Action OnRoundEnd(Event event, const char[] name, bool dontBroadcast) {
    if (!championshipRunning) {
        return Plugin_Handled;
    }

    int ctScore = GetTeamScore(CS_TEAM_CT);
    int tScore = GetTeamScore(CS_TEAM_T);

    if (ctScore + tScore <= normalRounds) {
        // We are normal time. We can use the direct score values.
        if (VERBOSE) { PrintToChatAll("\x03[Championship] Normal round finished. CT score = %d, TR score = %d", ctScore, tScore); }
        
        HandleNormalRoundEnd(ctScore, tScore);
    } else {
        // We are in overtime! We must calculate the correct score for these rounds.
        int ctOvertimeScore = ctScore - normalRounds/2 - (overtimeRounds/2 * (overtimeIndex - 1));
        int tOvertimeScore = tScore - normalRounds/2 - (overtimeRounds/2 * (overtimeIndex - 1));

        if (VERBOSE) { PrintToChatAll("\x03[Championship] Overtime (%d) round finished. CT score = %d, TR score = %d", overtimeIndex, ctOvertimeScore, tOvertimeScore); }

        HandleOvertimeRoundEnd(ctOvertimeScore, tOvertimeScore);
    }

    return Plugin_Handled;
}

void HandleNormalRoundEnd(int ctScore, int tScore) {
    // Keep win limit set to NR/2 + 1.
    UpdateWinLimit(normalRounds/2 + 1);

    // If any team is over NR/2 points, it's a winner.
    if (ctScore > normalRounds/2) {
        // CT wins
        if (VERBOSE) { PrintToChatAll("\x03[Championship] CT wins!"); }

        EndWithWinner(CS_TEAM_CT);
    } else if (tScore > normalRounds/2) {
        // TR wins
        if (VERBOSE) { PrintToChatAll("\x03[Championship] TR wins!"); }

        EndWithWinner(CS_TEAM_T);
    } else if (ctScore + tScore == normalRounds/2) {
        // NR/2 reached, let's switch sides!
        if (VERBOSE) { PrintToChatAll("\x03[Championship] NR/2 reached"); }

        RestartGame(true);
        SetNextRoundMoney(normalMoney);
    } else if (ctScore + tScore == normalRounds && ctScore == tScore) {
        // NR reached and it's a tie - let's start overtime!
        if (VERBOSE) { PrintToChatAll("\x03[Championship] Normal time tie! Starting overtime in next round!"); }

        UpdateWinLimit(normalRounds/2 + overtimeRounds/2 + 1);

        RestartGame(false);
        SetNextRoundMoney(overtimeMoney);

        PrintToChatAll("\x03[Championship] It's a tie! Let's see who wins in the overtime!");
    }
}

void HandleOvertimeRoundEnd(int ctScore, int tScore) {
    UpdateWinLimit(normalRounds/2 + (overtimeRounds/2 * overtimeIndex) + 1);

    if (ctScore > overtimeRounds/2) {
        // CT wins
        if (VERBOSE) { PrintToChatAll("\x03[Championship] CT wins!"); }

        EndWithWinner(CS_TEAM_CT);
    } else if (tScore > overtimeRounds/2) {
        // TR wins
        if (VERBOSE) { PrintToChatAll("\x03[Championship] TR wins!"); }

        EndWithWinner(CS_TEAM_T);
    } else if (ctScore + tScore == overtimeRounds/2) {
        // OR/2 reached, let's switch sides!
        if (VERBOSE) { PrintToChatAll("\x03[Championship] OR/2 reached, switching sides!"); }

        RestartGame(true);
        SetNextRoundMoney(overtimeMoney);
    } else if (ctScore + tScore == overtimeRounds && ctScore == tScore) {
        // OR reached and it's a tie - let's start a new overtime!
        if (VERBOSE) { PrintToChatAll("\x03[Championship] OR reached, starting new overtime!"); }

        UpdateWinLimit(normalRounds/2 + (overtimeRounds/2 * (overtimeIndex+1)) + 1);

        RestartGame(false);
        SetNextRoundMoney(overtimeMoney);
    }
}

void UpdateWinLimit(int winLimit) {
    SetConVarInt(cvarWinLimit, winLimit, false, VERBOSE);
}

void SetNextRoundMoney(int money) {
    nextRoundMoney = money;
}

void UpdatePlayersMoney(int money) {
    for (int client = 1; client <= MaxClients; client++) {
        if (IsClientInGame(client) && GetClientTeam(client) > 1) {
            SetEntProp(client, Prop_Send, "m_iAccount", money);
        }
    }
}

void RestartGame(bool switchTeams) {
    if (switchTeams) {
        PrintToChatAll("\x03[Championship] Switching sides!");

        // Switch every client's team.
        for (int client = 1; client <= MaxClients; client++) {
            if (IsClientInGame(client) && GetClientTeam(client) > 1) {
               CS_SwitchTeam(client, (GetClientTeam(client) == 2) ? 3 : 2);
            }
        }

        // Switch the team scores as well.
        int tmp = CS_GetTeamScore(CS_TEAM_T);
        CS_SetTeamScore(CS_TEAM_T, CS_GetTeamScore(CS_TEAM_CT));
        CS_SetTeamScore(CS_TEAM_CT, tmp);

        SetTeamScore(CS_TEAM_T, CS_GetTeamScore(CS_TEAM_T));
        SetTeamScore(CS_TEAM_CT, CS_GetTeamScore(CS_TEAM_CT));
    }

    // Backup everyone's scores.
    BackupScores();

    // Trigger a game restart.
    SetConVarString(cvarRestartGame, RESETGAME_TIME, false, VERBOSE);
}

void BackupScores() {
    backupCtScore = CS_GetTeamScore(CS_TEAM_CT);
    backupTrScore = CS_GetTeamScore(CS_TEAM_T);

    for (int client = 1; client <= MaxClients; client++) {
        if (IsClientInGame(client) && GetClientTeam(client) > 1) {
            backupClientFrags[client] = GetEntProp(client, Prop_Data, "m_iFrags");
            backupClientDeaths[client] = GetEntProp(client, Prop_Data, "m_iDeaths");
        } else {
            backupClientFrags[client] = 0;
            backupClientDeaths[client] = 0;
        }
    }

    backupAvailable = true;

    if (VERBOSE) { PrintToChatAll("\x03[Championship] Scores backup created!"); }
}

void RestoreScores() {
    CS_SetTeamScore(CS_TEAM_CT, backupCtScore);
    SetTeamScore(CS_TEAM_CT, backupCtScore);
    
    CS_SetTeamScore(CS_TEAM_T, backupTrScore);
    SetTeamScore(CS_TEAM_T, backupTrScore);
    
    for (int client = 1; client <= MaxClients; client++) {
        if (IsClientInGame(client) && GetClientTeam(client) > 1) {
            SetEntProp(client, Prop_Data, "m_iFrags", backupClientFrags[client]);
            SetEntProp(client, Prop_Data, "m_iDeaths", backupClientDeaths[client]);
        }
    }

    backupAvailable = false;

    if (VERBOSE) { PrintToChatAll("\x03[Championship] Scores backup restored!"); }
}
