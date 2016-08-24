#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
public Plugin:myinfo = {
	name = "Respawn Manager",
	author = "15ecbd799a412a672f8e06a0df3bcda0",
	description = "Respawn Manager for SDM Plugin",
	url = ""
}

#define RESPAWN_DELAY							1.10 // Respawn time
#define MAX_SPAWNPOINT							23   // You need to re-set this after you change it
#define SPAWN_AREA_SCAN_RADIUS						475  // Maximum area cover radius(units).
#define DISABLE_RADAR	 						1 << 12
#define INVALID_PLAYER_INDEX						0
new Float:g_TimerVal[MAXPLAYERS+1]				      = 0.0;
new g_LastSpawnPoint						      = 0;
new Float:g_Location[3]						      = 0.0; 
new Float:g_Angles[3]						      = 0.0;
new Float:g_Velocity[3]						      = 0.0;
new String:lineText[128];
new Handle:textLines;
new String:filepath[PLATFORM_MAX_PATH];

public OnPluginStart()
{
	HookEvent("player_death", OnPlayerDeath);
	HookEvent("player_spawn", onPlayerSpawn);
	// Load respawn coordinates
	decl String:c_path[PLATFORM_MAX_PATH] = "data/sdm/spawnpoint.txt";
	BuildPath(Path_SM,filepath, sizeof(filepath), c_path);
	new Handle:file = OpenFile(filepath, "rt");
	if(file != INVALID_HANDLE)
	{
		textLines = CreateArray(256);
		while(!IsEndOfFile(file))
		{
			ReadFileLine(file,lineText, sizeof(lineText));
			PushArrayString(textLines, lineText);
		}
		CloseHandle(file);
	}
	else{PrintToServer("Couldn't load spawnpoint list");}
	HookEvent("player_team", Event_OnPlayerTeam, EventHookMode_Pre);
}

public Action:Event_OnPlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	CS_RespawnPlayer(client);
	return Plugin_Handled;
}

public Action:RemoveRadar(Handle:timer, any:userid) 
{
	new client = GetClientOfUserId(userid);
	if(client != INVALID_PLAYER_INDEX)
		SetEntProp(client, Prop_Send, "m_iHideHUD", DISABLE_RADAR);
}

public Action onPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	if(g_LastSpawnPoint >= MAX_SPAWNPOINT)
		g_LastSpawnPoint = 0;
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(0.1, RemoveRadar, GetEventInt(event, "userid"));
	new String:exploded[9][32];
	for(;g_LastSpawnPoint < MAX_SPAWNPOINT; g_LastSpawnPoint++)
	{
		GetArrayString(textLines, g_LastSpawnPoint, lineText, sizeof(lineText));
		ExplodeString(lineText, ":", exploded, sizeof(exploded), sizeof(exploded[]));
		g_Location[0] = StringToFloat(exploded[0]);
		g_Location[1] = StringToFloat(exploded[1]);
		if(!checkSpawnPoint(g_Location[0],g_Location[1]))
		 continue;
		g_Location[2] = StringToFloat(exploded[2]); 
		g_Angles[0]   = StringToFloat(exploded[3]);
		g_Angles[1]   = StringToFloat(exploded[4]);
		g_Angles[2]   = StringToFloat(exploded[5]);
		break;
	}
	TeleportEntity(client, g_Location, g_Angles, g_Velocity);
}

public Action OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	CreateTimer(0.1, timerCallback, client, TIMER_REPEAT);
	return Plugin_Handled;
}

public Action timerCallback(Handle timer, any client)
{
	if(!IsClientConnected(client))
		return Plugin_Stop;
	if(g_TimerVal[client] >= RESPAWN_DELAY)
	{
		CS_RespawnPlayer(client);
		g_TimerVal[client] = 0.0;
		return Plugin_Stop;
	}
	g_TimerVal[client] += 0.1;
	return Plugin_Continue;
}

/*
	The idea behind this function is pretty simple.
	Since people like to spawn camp a lot, we need to protect the spawned player by checking the surroundings of the selected spawn point.
	Basically, 
	* get X and Y coordinates of the selected spawn point(as function parameters)
	* iterate through all players, get X-Y coordinates of the alive players.
	* calculate the difference between XY1 and XY2
	* If any player returns a difference is greater than SPAWN_AREA_SCAN_RADIUS then skip that point and look for the next one.
	* TODO: Generic spawn points and player vision angle checks.
*/

public bool checkSpawnPoint(Float:locX, Float:locY)
{
	new Float:spawnedLocation[3]             = 0.0;
	new Float:absX				 = 0.0;
	new Float:absY				 = 0.0;

	for(new i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i) || !IsPlayerAlive(i))
			continue;
		GetClientAbsOrigin(i, spawnedLocation);
		if(spawnedLocation[0] > locX)
			absX = FloatAbs(spawnedLocation[0] - locX);
		else
			absX = FloatAbs(locX - spawnedLocation[0]);
		if(spawnedLocation[1] > locY)
			absY = FloatAbs(spawnedLocation[1] - locY);
		else
			absY = FloatAbs(locY - spawnedLocation[1]);
		if(!(absX > SPAWN_AREA_SCAN_RADIUS || absY > SPAWN_AREA_SCAN_RADIUS))
			return false;
	}
	return true;
}