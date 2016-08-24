#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
public Plugin:myinfo = {
	name = "",
	author = "15ecbd799a412a672f8e06a0df3bcda0",
	description = "",
	url = ""
}
#define g_ChatHeader			 					"[\x04SDM\x01]"
#define RANK_BEGINNER								"[Beginner]-[Beginner]"
#define RANK_AMATEUR								"[\x08Amateur\x01]\x08-[Amateur]"
#define RANK_PROBIE								"[\x06Probie\x01]\x06-[Probie]"
#define	RANK_ROOKIE								"[\x05Rookie\x01]\x05-[Rookie]"
#define RANK_SHARPSHOOTER							"[\x04Sharpshooter\x01]\x04-[Sharpshooter]"
#define RANK_RELENTLESS								"[\x07Relentless\x01]\x07-[Relentless]"
#define RANK_BLOODTHIRSTY							"[\x02Bloodthirsty\x01]\x02-[Bloodthirsty]"
#define RANK_MASTER								"[\x09Master\x01]\x09-[Master]"
#define RANK_EXCEPTIONAL							"[\11Exceptional\x01]\11-[Exceptional]"
#define RANK_DECIMATOR								"[\12Decimator\x01]\12-[Decimator]"
#define RANK_ADMIN								"[\x03Admin\x01]-[Admin]"
#define POINTS_BEGINNER								0
#define POINTS_AMATEUR  							8000
#define POINTS_PROBIE	  							18000
#define POINTS_ROOKIE								27000
#define POINTS_SHARPSHOOTER							34000
#define POINTS_RELENTLESS							41000
#define POINTS_BLOODTHIRSTY							51000
#define POINTS_MASTER	 							60000
#define POINTS_EXCEPTIONAL 							70000
#define POINTS_DECIMATOR  							79000
#define KILL_REWARD								3
#define	DEATH_PENALTY								5
#define STARTING_POINTS								1000
#define HITGROUP_HEAD           						1
new g_playerPoints[MAXPLAYERS + 1]				  		= 0;
new Handle:db									= INVALID_HANDLE;
new Handle:dbTimer								= INVALID_HANDLE;
new bool:g_victimLastHitGroup[MAXPLAYERS + 1]     				= false;
new bool:g_isPlayerVIP[MAXPLAYERS + 1]            				= false;
new String:g_playerSteamID[MAXPLAYERS+1][32];
new String:g_playerRank[MAXPLAYERS + 1][64];
new String:Error[128];
new String:query[256];
new const String:RELATIVE_SOUND_PATH_RANKDOWN[]   				= "*/weirdm/rankdown.mp3";
new const String:RELATIVE_SOUND_PATH_RANKUP[] 	  				= "*/weirdm/rankup.mp3";
public OnPluginStart()
{
	db = SQL_Connect("weirdm", true, Error, sizeof(Error));
	if(db == INVALID_HANDLE)
		PrintToServer("[SDM] MySQL connection error. %s", Error);
	HookEvent("player_death", onPlayerDeath);
	HookEvent("player_team", onPlayerTeam);
	HookEvent("player_hurt", onPlayerHurt);
}
public OnClientAuthorized(client)
{
	if(!IsFakeClient(client))
		announcePlayer(client);
}

public Action onPlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new String:tag[64];
	CS_GetClientClanTag(client, tag, sizeof(tag));
	if(isOnlyHS(client))
		return Plugin_Handled;
	if(g_playerPoints[client] > POINTS_EXCEPTIONAL)
		rankToTag(client, tag);
	else
		rankToTag(client, tag);
    	CS_SetClientClanTag(client, tag);
    	return Plugin_Handled;
}

public onPlayerHurt(Handle:event, const String:name[], bool:dontBroadcast)
{
	new victim = GetClientOfUserId(GetEventInt(event, "userid"));
	new hitgroup = GetEventInt(event, "hitgroup");
	if(hitgroup == HITGROUP_HEAD)
		g_victimLastHitGroup[victim] = true;
	else
		g_victimLastHitGroup[victim] = false;
}

public announcePlayer(client)
{
	new String:pName[128];
	new String:pSteamID[15];
	GetClientName(client, pName, sizeof(pName));
	GetClientAuthId(client, AuthId_Steam2, pSteamID, sizeof(pSteamID));
	g_playerSteamID[client] = pSteamID;
	Format(query, sizeof(query), "select * from rankings where steamid = '%s'", pSteamID);
	new Handle:queryH = SQL_Query(db, query);
	if(queryH == INVALID_HANDLE)
	{
		SQL_GetError(db, Error, sizeof(Error));
		PrintToServer("[SDM] An error occured while trying to fetch the rankings table. Error: %s", Error);
		return;
	}
	if(SQL_FetchRow(queryH))
	{
		new points = SQL_FetchInt(queryH, 1);
		g_playerPoints[client] = points;
		calculateRank(client);
	}
	else
	{
		Format(query, sizeof(query), "INSERT INTO rankings (steamid, points) VALUES ('%s', %i)", pSteamID, STARTING_POINTS);
		new Handle:queryX = SQL_Query(db, query);
		if(queryX == INVALID_HANDLE)
			PrintToServer("[SDM] An error occured while inserting new player");
		else
		{
			g_playerPoints[client] = STARTING_POINTS;
			g_playerRank[client] = RANK_BEGINNER;
		}
	}
	if(dbTimer == INVALID_HANDLE)
		dbTimer = CreateTimer(60.0, dbTimerCallback, _, TIMER_REPEAT);
}

public Action onPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new reward  = KILL_REWARD;
	new penalty = DEATH_PENALTY;
	new victim  = GetClientOfUserId(GetEventInt(event, "userid"));
	new killer  = GetClientOfUserId(GetEventInt(event, "attacker"));
	new String:pLastKiller[32]; 	
	new String:pLastVictim[32];
	new String:pMessage[64];
	strcopy(pLastKiller, sizeof(pLastKiller), g_playerRank[killer]);
	strcopy(pLastVictim, sizeof(pLastVictim), g_playerRank[victim]);
	if(!killer)
		return;
	if(killer == victim)
		return;
	if(!g_isPlayerVIP[killer])
	{
		reward = KILL_REWARD;
		if(g_victimLastHitGroup[victim] && !isOnlyHS(killer))
		{
			reward = KILL_REWARD + 1; 
			pMessage = "%s \x03You've got [\x04%i + 1 RP\x03]";
		}
		else if(isOnlyHS(killer))
		{
			reward = KILL_REWARD + 2;
			pMessage = "%s \x03You've got [\x04%i + 2 RP\x03]";
		}
		else
			pMessage = "%s \x03You've got [\x04%i RP\x03]";
		g_playerPoints[killer] += reward;
		g_playerPoints[victim] -= penalty;
		calculateRank(killer);
		calculateRank(victim);
		announceNewRank(killer, victim, pLastKiller, pLastVictim);
		PrintToChat(killer, pMessage, g_ChatHeader, KILL_REWARD);
		PrintToChat(victim, "%s \x03You lost [\x02%i RP\x03]",g_ChatHeader, penalty);
	}
	// TODO: VIP Rewards
}

public announceNewRank(killer, victim, String:pLastKiller[], const String:pLastVictim[])
{
	if(IsFakeClient(killer) && IsFakeClient(victim)) return;
	new String:exploded[2][32];
	new String:tag[64];
	if(!StrEqual(pLastKiller, g_playerRank[killer]))
	{
		EmitSoundToAll(RELATIVE_SOUND_PATH_RANKUP);
		ExplodeString(g_playerRank[killer], "-",exploded,sizeof(exploded),sizeof(exploded[]));
		new String:szPlayer[32];
		GetClientName(killer, szPlayer, sizeof(szPlayer));
		PrintHintTextToAll("<font color='#00FF00'>%s</font>\nhas ranked up to %s", szPlayer, exploded[1]);
		rankToTag(killer, tag);
		if(isOnlyHS(killer))
			Format(tag, sizeof(tag), "*%s", tag);
		CS_SetClientClanTag(killer, tag);
	}
	if(IsFakeClient(victim)) return;
	if(!StrEqual(pLastVictim, g_playerRank[victim]))
	{
		EmitSoundToAll(RELATIVE_SOUND_PATH_RANKDOWN);
		ExplodeString(g_playerRank[victim], "-",exploded,sizeof(exploded),sizeof(exploded[]));
		new String:szPlayer[32];
		GetClientName(victim, szPlayer, sizeof(szPlayer));
		PrintHintTextToAll("<font color='#00FF00'>%s</font>\nhas ranked down to %s", szPlayer, exploded[1]);
	}
	
}

public Action dbTimerCallback(Handle:timer)
{
	for(new i = 1; i <= MaxClients; i++)
	{
		if(!IsClientConnected(i) || !IsClientInGame(i) || IsFakeClient(i))
			continue;
		writeRewardsToDb(i);
	}
}

public bool writeRewardsToDb(client)
{
	Format(query,sizeof(query), "update rankings set points = %i where steamid = '%s'", g_playerPoints[client], g_playerSteamID[client]);
	new Handle:queryH = SQL_Query(db, query);
	if(queryH != INVALID_HANDLE)
		return true;
	CloseHandle(queryH);
	return false;
}

public Action OnClientSayCommand(client, const String:command[], const String:sArgs[])
{
	new String:clientName[128];
	GetClientName(client, clientName, sizeof(clientName));
	cSay(client, clientName, sArgs);
	return Plugin_Handled;
}

public OnClientDisconnect(client)
{
	g_playerRank[client] = "";
}

public cSay(client,String:clientname[], const String:message[])
{
	new String:exploded[2][32];
	ExplodeString(g_playerRank[client], "-",exploded,sizeof(exploded),sizeof(exploded[]));
	PrintToChatAll("%s %s\x01: %s", exploded[0], clientname, message);
}

public rankToTag(client, String:newTag[])
{
	new String:exploded[2][32];
	ExplodeString(g_playerRank[client], "-",exploded,sizeof(exploded),sizeof(exploded[]));
	strcopy(newTag, strlen(exploded[1]) + 1, exploded[1]);
}

public isOnlyHS(client)
{
	new String:tag[64];
	if(IsFakeClient(client) || !IsClientConnected(client) || !IsClientInGame(client))
		return false;
	CS_GetClientClanTag(client, tag, sizeof(tag));
	if(tag[0] == '*')
		return true;
	else
		return false;
}

public calculateRank(client)
{
	new points = g_playerPoints[client];
	if(points >= POINTS_BEGINNER && points <= POINTS_AMATEUR)
		g_playerRank[client] = RANK_BEGINNER;
	else if(points >= POINTS_AMATEUR && points <= POINTS_PROBIE)
		g_playerRank[client] = RANK_AMATEUR;
	else if(points >= POINTS_PROBIE && points <= POINTS_ROOKIE)
		g_playerRank[client] = RANK_PROBIE;
	else if(points >= POINTS_SHARPSHOOTER && points <= POINTS_RELENTLESS)
		g_playerRank[client] = RANK_SHARPSHOOTER;
	else if(points >= POINTS_RELENTLESS && points <= POINTS_BLOODTHIRSTY)
		g_playerRank[client] = RANK_RELENTLESS;
	else if(points >= POINTS_BLOODTHIRSTY && points <= POINTS_MASTER)
		g_playerRank[client] = RANK_BLOODTHIRSTY;
	else if(points >= POINTS_MASTER && points <= POINTS_EXCEPTIONAL)
		g_playerRank[client] = RANK_MASTER;
	else if(points >= POINTS_EXCEPTIONAL && points <= POINTS_DECIMATOR)
		g_playerRank[client] = RANK_EXCEPTIONAL;
	else if(points >= POINTS_EXCEPTIONAL)
		g_playerRank[client] = RANK_DECIMATOR;
	g_playerPoints[client] = points;
}