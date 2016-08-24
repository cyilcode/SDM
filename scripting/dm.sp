#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <emitsoundany>
public Plugin:myinfo = {
	name = "SDM",
	author = "15ecbd799a412a672f8e06a0df3bcda0",
	description = "Deathmatch script for CS:GO",
	url = ""
}
#define WEAPONID_M4A1S 									60				/*WEAPON ID's*/
#define WEAPONID_USPS									61
#define WEAPONID_CZ75A									63
#define WEAPONID_CT_KNIFE								42
#define WEAPONID_T_KNIFE								59
#define g_ChatHeader			 						"[\x04SDM\x01]" // Starting g_ChatHeader of every print. Basically the mod name.
#define g_HealReward									25   			// default hp reward
#define g_minArmorReward								5 				// minimum kevlar reward
#define g_minHealReward									5 				// minimum hp reward
#define g_rewardThreshold								100 			// HP Threshold
#define g_rewardMax										125 			// Max reward for both kevlar and hp
#define COLLISION_GROUP_DEBRIS							2 				// "Collides with nothing but world and static stuff"
#define EFFECT_CS_BLOOD									31 				// csblood effectid. We'll use this to block blood effects
new g_WeaponType[MAXPLAYERS+1] = 						0;				// Store weapon slots. Exp: CS_SLOT_PRIMARY
new g_offsCollisionGroup = 								0;				// We'll get this to change players collision group
new bool:g_onlyHeadshot = 								false; 			// Only headshot trigger
new bool:g_pOnlyHeadshot[MAXPLAYERS+1] =				false; 			// Personal only headshot trigger
new String:filepath[PLATFORM_MAX_PATH];									// File path to weapon.txt files
new String:g_Weapon[MAXPLAYERS+1][64];									// Stores weapon name.

public OnPluginStart()
{
	RegConsoleCmd("sm_onlyhs", c_ponlyhs);
	HookEvent("player_death", playerDeath);
	HookEvent("player_spawn", OnPlayerSpawn);
	AddTempEntHook("EffectDispatch", TE_OnEffectDispatch);
	AddTempEntHook("World Decal", TE_OnWorldDecal);
}

new const String:FULL_SOUND_PATH_ONLYHS[]			= "sound/weirdm/onlyhs.mp3";
new const String:RELATIVE_SOUND_PATH_ONLYHS[]		= "*/weirdm/onlyhs.mp3";
new const String:FULL_SOUND_PATH_RANKUP[]			= "sound/weirdm/rankup.mp3";
new const String:RELATIVE_SOUND_PATH_RANKUP[]		= "*/weirdm/rankup.mp3";
new const String:FULL_SOUND_PATH_RANKDOWN[]			= "sound/weirdm/rankdown.mp3";
new const String:RELATIVE_SOUND_PATH_RANKDOWN[]		= "*/weirdm/rankdown.mp3";

public OnMapStart()
{
	AddFileToDownloadsTable(FULL_SOUND_PATH_ONLYHS);
	FakePrecacheSound(RELATIVE_SOUND_PATH_ONLYHS);
	AddFileToDownloadsTable(FULL_SOUND_PATH_RANKUP);
	FakePrecacheSound(RELATIVE_SOUND_PATH_RANKUP);
	AddFileToDownloadsTable(FULL_SOUND_PATH_RANKDOWN);
	FakePrecacheSound(RELATIVE_SOUND_PATH_RANKDOWN);
}
 
stock FakePrecacheSound(const String:szPath[])
{
	AddToStringTable(FindStringTable("soundprecache"), szPath);
}

public OnClientConnected(client)
{
	if(!IsClientInGame(client))
	return;
}

public OnClientDisconnect(client)
{
	g_pOnlyHeadshot[client] = false;
}

public OnClientPutInServer(client) SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);

public Action OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype)
{
	if(!g_onlyHeadshot && !g_pOnlyHeadshot[attacker]) return Plugin_Continue;
	if(g_pOnlyHeadshot[attacker])
	{
		if(!(damagetype & CS_DMG_HEADSHOT))
		{
			damage = float(0);
			return Plugin_Changed;
		}
	}
	if(!(damagetype & CS_DMG_HEADSHOT))
	{
		damage = float(0);
		return Plugin_Changed;
	}
	return Plugin_Continue;
}

public Action TE_OnEffectDispatch(const char[] te_name, const Players[], int numClients, float delay)
{
	if(!g_onlyHeadshot) return Plugin_Continue;
	new effectId = TE_ReadNum("m_iEffectName");
	if(effectId == EFFECT_CS_BLOOD)
		return Plugin_Handled;
	return Plugin_Continue;
}

public Action TE_OnWorldDecal(const char[] te_name, const Players[], int numClients, float delay)
{
	if(g_onlyHeadshot)
		return Plugin_Handled;
	return Plugin_Continue;
}

public Action c_ponlyhs(client, args)
{
	if(!g_pOnlyHeadshot[client])
	{
		new String:chName[32];
		new String:tag[64];
		CS_GetClientClanTag(client, tag, sizeof(tag));
		Format(tag, sizeof(tag), "*%s", tag);
		GetClientName(client,chName,sizeof(chName));
		g_pOnlyHeadshot[client] = true;
		// TODO: Spam check.
		PrintToChat(client, "%s Only HS \x05Activated.", g_ChatHeader, g_pOnlyHeadshot[client]);
		PrintHintTextToAll("<font color='#ff0000'>%s</font>\nhas enabled OnlyHS Mode", chName);
		EmitSoundToAll(RELATIVE_SOUND_PATH_ONLYHS);
		CS_SetClientClanTag(client, tag);
	}
	else
	{
		new String:tag[64];
		CS_GetClientClanTag(client, tag, sizeof(tag));
		ReplaceString(tag, sizeof(tag), "*", "");
		CS_SetClientClanTag(client, tag);
		PrintToChat(client, "%s Only HS \x07Deactivated.", g_ChatHeader, g_pOnlyHeadshot[client]);
		g_pOnlyHeadshot[client] = false;
	}
	return Plugin_Handled;
}



public Action:OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	g_offsCollisionGroup = FindSendPropOffs("CBaseEntity", "m_CollisionGroup");
	SetEntData(client, g_offsCollisionGroup, COLLISION_GROUP_DEBRIS, 4, true);
	
}

public Action:playerDeath(Handle:event, const String:name[], bool:dontBroadcast) 
{
	new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if(!attacker) // Do we have an attacker ?
		return;
 	new client = GetClientOfUserId(GetEventInt(event, "userid"));
 	if(attacker == client) // Is it suicide ? 
 		return;
 	new weapon = GetEntPropEnt(attacker, Prop_Data, "m_hActiveWeapon");
 	new String:wpname[32];
 	GetEntPropString(weapon, Prop_Data, "m_iClassname", wpname, sizeof(wpname));
 	new wpindex = GetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex");
 	switch (wpindex)
	{
    case WEAPONID_M4A1S: strcopy(wpname, sizeof(wpname), "weapon_m4a1_silencer");
    case WEAPONID_USPS: strcopy(wpname, sizeof(wpname), "weapon_usp_silencer");
    case WEAPONID_CZ75A: strcopy(wpname, sizeof(wpname), "weapon_cz75a");
	}
 	g_Weapon[attacker] = wpname;
 	setHp(attacker, client);
 	if(wpindex == WEAPONID_CT_KNIFE || wpindex == WEAPONID_T_KNIFE)
 	 return;
 	refillAmmo(attacker);
}

public void setHp(attacker, client)
{
 	new currenthp = GetClientHealth(attacker); 	// We should get currenthp of our glorious killer and check a few stuff.
 	new givenhp = currenthp + g_HealReward; // We'll set the heal reward staticly for now. cVars will be created soon.
 	if((currenthp + g_HealReward) < g_rewardThreshold) // Check if attacker gets more than 100 hp when we give him 25 heal reward.
 	{
 	SetEntityHealth(attacker, givenhp); // if not heal him.
 	PrintToChat(attacker,"%s You've got \x0425\x01 hp for killing [\x07%N\x01]",g_ChatHeader,client);
 	}
 	else if(currenthp >= g_rewardThreshold) // if the attacker is already full. We'll reward him 5 kevlar.
 	{
 		//PrintToChat(attacker,"%s You've got \x040\x01 hp for killing [\x07%N\x01]",g_ChatHeader,client);
 		new curarmor = GetEntProp(attacker, Prop_Send, "m_ArmorValue", 4); // Get current kevlar.
 		if(curarmor >= g_rewardMax)
 		{
 			if(currenthp >= g_rewardMax && curarmor >= g_rewardMax)
 			{PrintToChat(attacker, "%s \x07You have reached max rewarded stats.",g_ChatHeader); return;}
 			givenhp = currenthp + g_minHealReward;
 			SetEntityHealth(attacker, givenhp);
 			PrintToChat(attacker, "%s You have max armor. Rewarded \x045 HP\x01 instead.", g_ChatHeader); 
 			return;
 		}
 		new giftarmor = curarmor + g_minArmorReward; // Increase it by 5.
 		SetEntProp(attacker, Prop_Send, "m_ArmorValue", giftarmor, 1); // Set the kevlar.
 		PrintToChat(attacker,"%s You've got \x045\x01 armor for getting kill on full hp.",g_ChatHeader,client);
 	}
 	else // If the attacker gets more than 100 hp when we heal him for 25 then we should get the exact amount to both not exceed 100 hp and tap him full.
 	{
 		new hpfill = g_rewardThreshold - currenthp;
 		givenhp = currenthp + hpfill;
 		SetEntityHealth(attacker, givenhp);
 		PrintToChat(attacker,"%s You've got \x04%i\x01 hp for killing [\x07%N\x01]",g_ChatHeader,hpfill,client);
 	}
}

public void refillAmmo(attacker) // Experimental. We may not use this at all.
{
	new String:c_sFile[PLATFORM_MAX_PATH];
	Format(c_sFile,sizeof(c_sFile),"data/sdm/%s.txt",g_Weapon[attacker]);
	BuildPath(Path_SM,filepath,sizeof(filepath),c_sFile);
	new a_Amount = getClipSize(attacker) + 1;
	new w_Slot = GetPlayerWeaponSlot(attacker, g_WeaponType[attacker]);
	SetEntProp(w_Slot, Prop_Send, "m_iClip1", a_Amount);
}

public int getClipSize(attacker)
{
	decl String:exploded[4][64];
	new result = 0;
	new Handle:file = OpenFile(filepath, "rt");
	if(file == INVALID_HANDLE)
	{
		PrintToChatAll("Unable to load %s",filepath);
		return 0;
	}
	new String:linetext[255];
	new Handle:textLines = CreateArray(256); 
	while(!IsEndOfFile(file))
	{
		ReadFileLine(file, linetext, sizeof(linetext));
		PushArrayString(textLines, linetext); 
	}
	CloseHandle(file);
	new arrlength = GetArraySize(textLines);
	for(new i = 0;i < arrlength; i++)
	{
		GetArrayString(textLines, i, linetext, sizeof(linetext));
		new pos = StrContains(linetext, "clip_size");
		if(pos == -1) continue;
		TrimString(linetext);
		if(StrContains(linetext,"\"") != -1) // Primaries
		{
		g_WeaponType[attacker] = CS_SLOT_PRIMARY;
		ExplodeString(linetext,"\"",exploded,sizeof(exploded), sizeof(exploded[]));
		result = StringToInt(exploded[3]);
		}
		else // Secondaries. It looks lame need to find a better way.
		{
			g_WeaponType[attacker] = CS_SLOT_SECONDARY;
			new ltLength = strlen(linetext);
			decl String:secondary[2];
			secondary[0] = linetext[ltLength-2];
			secondary[1] = linetext[ltLength-1];
			TrimString(secondary);
			result = StringToInt(secondary);
		}
		break;
	}
	CloseHandle(textLines);
	return result;
}