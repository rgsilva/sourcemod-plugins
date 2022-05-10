#include <sourcemod>
#include <sdktools>
#include <cstrike>

#define PLUGIN_AUTHOR  "rgsilva"
#define PLUGIN_VERSION "1.6"
#pragma semicolon 1

#define MAX_ARG_LENGTH 64
#define MAX_BACKUP_SIZE (MAXPLAYERS * 2)

#define MAXROUNDS 0
#define TIMELIMIT 0
#define RESTARTGAME_TIME "3"
#define RESETGAME_TIME "2"

public Plugin:myinfo =
{
    name = "Championship",
    author = PLUGIN_AUTHOR,
    description = "Custom championship mode",
    version = PLUGIN_VERSION,
    url = "https://github.com/rgsilva/sourcemod-plugins"
};


bool championshipRunning;
bool nextRoundRestartGame;
bool nextRoundSwitchTeams;

int overtimeIndex;

int normalRounds;
int overtimeRounds;
int normalMoney;
int overtimeMoney;

Handle cvarWinLimit;
Handle cvarMaxRounds;
Handle cvarTimeLimit;
Handle cvarRestartGame;
Handle cvarStartMoney;

Handle cvarVerbose;
Handle cvarDebug;

int originalMaxRounds;
int originalTimeLimit;
int originalStartMoney;

bool backupAvailable;
int backupClientFrags[MAX_BACKUP_SIZE];
int backupClientDeaths[MAX_BACKUP_SIZE];
int backupCtScore;
int backupTrScore;

bool pluginVerbose;
bool pluginDebug;

public OnPluginStart()
{
    pluginVerbose = true;
    pluginDebug = false;

    SanityCheck();

    championshipRunning = false;
    overtimeIndex = 0;
    nextRoundRestartGame = false;
    nextRoundSwitchTeams = false;
    backupAvailable = false;

    RegConsoleCmd("start_championship", CmdStartChampionship);
    RegConsoleCmd("end_championship", CmdEndChampionship);

    cvarWinLimit = FindConVar("mp_winlimit");
    cvarMaxRounds = FindConVar("mp_maxrounds");
    cvarTimeLimit = FindConVar("mp_timelimit");
    cvarRestartGame = FindConVar("mp_restartgame");
    cvarStartMoney = FindConVar("mp_startmoney");

    cvarVerbose = CreateConVar("championship_verbose", "1", "Show verbose messages", _, true, 0.0, true, 1.0);
    HookConVarChange(cvarVerbose, OnConVarChanged);
    cvarDebug = CreateConVar("championship_debug", "0", "Show debug messages", _, true, 0.0, true, 1.0);
    HookConVarChange(cvarDebug, OnConVarChanged);

    HookEvent("round_start", OnRoundStart);
    HookEvent("round_end", OnRoundEnd);
}

void SanityCheck() {
    if (MAX_BACKUP_SIZE <= MaxClients || MAX_BACKUP_SIZE <= MAXPLAYERS) {
        ThrowError("WARNING: MAX_BACKUP_SIZE will be reached! This will cause a buffer overflow! MAX_BACKUP_SIZE = %d, MaxClients = %d, MAXPLAYERS = %d!", MAX_BACKUP_SIZE, MaxClients, MAXPLAYERS);
    }
}

public OnConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[]) {
    if (convar == cvarVerbose) {
        pluginVerbose = GetConVarBool(cvarVerbose);
    } else if (convar == cvarDebug) {
        pluginDebug = GetConVarBool(cvarDebug);
    }
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

    originalMaxRounds = GetConVarInt(cvarMaxRounds);
    originalTimeLimit = GetConVarInt(cvarTimeLimit);
    originalStartMoney = GetConVarInt(cvarStartMoney);

    SetConVarInt(cvarMaxRounds, MAXROUNDS, false, pluginDebug);
    SetConVarInt(cvarTimeLimit, TIMELIMIT, false, pluginDebug);

    UpdateWinLimit(16);

    championshipRunning = true;
    normalRounds = _normalRounds;
    overtimeRounds = _overtimeRounds;
    normalMoney = _normalMoney;
    overtimeMoney = _overtimeMoney;

    PrintToChatAll("\x03[Championship] A new championship is starting! Have fun everyone, and good luck!");
    SetConVarString(cvarRestartGame, RESTARTGAME_TIME, false, pluginDebug);
}

void EndChampionship(bool silent) {
    if (!silent) {
        PrintToChatAll("\x03[Championship] The championship has ended!");
    }

    championshipRunning = false;
    overtimeIndex = 0;
    nextRoundRestartGame = false;
    nextRoundSwitchTeams = false;
    backupAvailable = false;

    SetConVarInt(cvarMaxRounds, originalMaxRounds, false, pluginDebug);
    SetConVarInt(cvarTimeLimit, originalTimeLimit, false, pluginDebug);
    SetConVarInt(cvarStartMoney, originalStartMoney, false, pluginDebug);
}

void EndWithWinner(int winnerTeam) {
    PrintToChatAll("\x03[Championship] And the winner is... the %s!", (winnerTeam == CS_TEAM_CT ? "Counter-Terrorists" : "Terrorists"));

    EndChampionship(false);
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast) {
    if (!championshipRunning) {
        return Plugin_Handled;
    }

    // Should we switch teams?
    if (nextRoundSwitchTeams) {
        if (pluginDebug) { PrintToChatAll("\x05[Championship] [DEBUG] nextRoundSwitchTeams is true!"); }

        nextRoundSwitchTeams = false;

        if (pluginDebug) { PrintToChatAll("\x05[Championship] [DEBUG] Switching team scores"); }

        // Switch the team scores as well.
        int tmp = CS_GetTeamScore(CS_TEAM_T);
        CS_SetTeamScore(CS_TEAM_T, CS_GetTeamScore(CS_TEAM_CT));
        CS_SetTeamScore(CS_TEAM_CT, tmp);

        SetTeamScore(CS_TEAM_T, CS_GetTeamScore(CS_TEAM_T));
        SetTeamScore(CS_TEAM_CT, CS_GetTeamScore(CS_TEAM_CT));

        // Switch every client's team.
        if (pluginDebug) { PrintToChatAll("\x05[Championship] [DEBUG] Switching player teams"); }
        for (int client = 1; client <= MaxClients; client++) {
            if (IsClientInGame(client) && GetClientTeam(client) > 1) {
               CS_SwitchTeam(client, (GetClientTeam(client) == CS_TEAM_T) ? CS_TEAM_CT : CS_TEAM_T);
            }
        }

        if (pluginDebug) { PrintToChatAll("\x05[Championship] [DEBUG] Switch completed!"); }
    }

    // Should we restart the game?
    if (nextRoundSwitchTeams || nextRoundRestartGame) {
        if (pluginDebug) { PrintToChatAll("\x05[Championship] [DEBUG] nextRoundSwitchTeams (%d) or nextRoundRestartGame (%d) is true!", nextRoundSwitchTeams, nextRoundRestartGame); }

        nextRoundRestartGame = false;

        // Backup everyone's scores.
        if (pluginDebug) { PrintToChatAll("\x05[Championship] [DEBUG] Triggering score backup"); }
        BackupScores();

        if (pluginDebug) { PrintToChatAll("\x05[Championship] [DEBUG] Triggering game restart"); }
        SetConVarString(cvarRestartGame, RESETGAME_TIME, false, pluginDebug);

        if (pluginDebug) { PrintToChatAll("\x05[Championship] [DEBUG] Exiting OnRoundStart"); }

        return Plugin_Handled;
    }

    // Restore a backup if available.
    if (backupAvailable) {
        RestoreScores();
    }

    // Standard round stuff!
    int ctScore = GetTeamScore(CS_TEAM_CT);
    int tScore = GetTeamScore(CS_TEAM_T);

    if (ctScore + tScore >= normalRounds) {
        overtimeIndex = ((ctScore + tScore - normalRounds) / overtimeRounds) + 1;
        if (pluginVerbose) { PrintToChatAll("\x03[Championship] Overtime (%d) round started.", overtimeIndex); }
    } else {
        if (pluginVerbose) { PrintToChatAll("\x03[Championship] Normal round started.", overtimeIndex); }
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
        if (pluginVerbose) { PrintToChatAll("\x03[Championship] Normal round finished. CT score: %d, TR score: %d", ctScore, tScore); }
        
        HandleNormalRoundEnd(ctScore, tScore);
    } else {
        // We are in overtime! We must calculate the correct score for these rounds.
        int ctOvertimeScore = ctScore - normalRounds/2 - (overtimeRounds/2 * (overtimeIndex - 1));
        int tOvertimeScore = tScore - normalRounds/2 - (overtimeRounds/2 * (overtimeIndex - 1));

        if (pluginVerbose) { PrintToChatAll("\x03[Championship] Overtime (%d) round finished. CT score: %d, TR score: %d", overtimeIndex, ctOvertimeScore, tOvertimeScore); }

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
        if (pluginDebug) { PrintToChatAll("\x05[Championship] [DEBUG] CT wins!"); }

        EndWithWinner(CS_TEAM_CT);
    } else if (tScore > normalRounds/2) {
        // TR wins
        if (pluginDebug) { PrintToChatAll("\x05[Championship] [DEBUG] TR wins!"); }

        EndWithWinner(CS_TEAM_T);
    } else if (ctScore + tScore == normalRounds/2) {
        // NR/2 reached, let's switch sides!
        if (pluginDebug) { PrintToChatAll("\x05[Championship] [DEBUG] NR/2 reached"); }

        SetNextRoundMoney(normalMoney);
        RestartGame(true);
    } else if (ctScore + tScore == normalRounds && ctScore == tScore) {
        // NR reached and it's a tie - let's start overtime!
        if (pluginDebug) { PrintToChatAll("\x05[Championship] [DEBUG] NR reached, starting overtime"); }

        UpdateWinLimit(normalRounds/2 + overtimeRounds/2 + 1);

        SetNextRoundMoney(overtimeMoney);
        RestartGame(false);

        PrintToChatAll("\x03[Championship] It's a tie! Let's see who wins in the overtime!");
    }
}

void HandleOvertimeRoundEnd(int ctScore, int tScore) {
    UpdateWinLimit(normalRounds/2 + (overtimeRounds/2 * overtimeIndex) + 1);

    if (ctScore > overtimeRounds/2) {
        // CT wins
        if (pluginDebug) { PrintToChatAll("\x05[Championship] [DEBUG] CT wins!"); }

        EndWithWinner(CS_TEAM_CT);
    } else if (tScore > overtimeRounds/2) {
        // TR wins
        if (pluginDebug) { PrintToChatAll("\x05[Championship] [DEBUG] TR wins!"); }

        EndWithWinner(CS_TEAM_T);
    } else if (ctScore + tScore == overtimeRounds/2) {
        // OR/2 reached, let's switch sides!
        if (pluginDebug) { PrintToChatAll("\x05[Championship] [DEBUG] OR/2 reached, switching sides!"); }

        SetNextRoundMoney(overtimeMoney);
        RestartGame(true);
    } else if (ctScore + tScore == overtimeRounds && ctScore == tScore) {
        // OR reached and it's a tie - let's start a new overtime!
        if (pluginDebug) { PrintToChatAll("\x05[Championship] [DEBUG] OR reached, starting new overtime!"); }

        UpdateWinLimit(normalRounds/2 + (overtimeRounds/2 * (overtimeIndex+1)) + 1);

        SetNextRoundMoney(overtimeMoney);
        RestartGame(false);

        PrintToChatAll("\x03[Championship] It's a tie! Let's see who wins in the next overtime!");
    }
}

void UpdateWinLimit(int winLimit) {
    SetConVarInt(cvarWinLimit, winLimit, false, pluginDebug);
}

void SetNextRoundMoney(int money) {
    SetConVarInt(cvarStartMoney, money);
}

void RestartGame(bool switchTeams) {
    nextRoundRestartGame = true;
    nextRoundSwitchTeams = switchTeams;

    if (switchTeams) {
        PrintToChatAll("\x03[Championship] Switching sides in the next round!");
    }
}

void BackupScores() {
    if (pluginDebug) { PrintToChatAll("\x05[Championship] [DEBUG] Creating score backup"); }

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

    if (pluginDebug) { PrintToChatAll("\x05[Championship] [DEBUG] Scores backup created!"); }
}

void RestoreScores() {
    if (pluginDebug) { PrintToChatAll("\x05[Championship] [DEBUG] Restoring score backup"); }

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

    if (pluginDebug) { PrintToChatAll("\x05[Championship] [DEBUG] Scores backup restored!"); }
}
