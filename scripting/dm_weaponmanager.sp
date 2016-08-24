#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <cstrike>
public Plugin:myinfo = {
	name = "Weapon Manager",
	author = "15ecbd799a412a672f8e06a0df3bcda0",
	description = "Weapon Manager for SDM Plugin",
	url = ""
}
enum
{
	MENU_PAGE1,
	MENU_PAGE2,
	MENU_PAGE3
}
enum
{
	PRIMARY_AK47,
	PRIMARY_M4A1S,
	PRIMARY_M4A4,
	PRIMARY_GALIL,
	PRIMARY_FAMAS,
	PRIMARY_SG553,
	PRIMARY_AUG,
	PRIMARY_AWP,
	PRIMARY_WEAPONS_COUNT
}
enum
{
	SECONDARY_GLOCK,
	SECONDARY_USPS,
	SECONDARY_P2K,
	SECONDARY_P250,
	SECONDARY_FIVESEVEN,
	SECONDARY_ELITES,
	SECONDARY_DEAGLE,
	SECONDARY_TEC9,
	SECONDARY_CZ75A,
	SECONDARY_WEAPONS_COUNT
}
new const String:g_szPrimaryWeapons[][32] =		
{
	"weapon_ak47",
	"weapon_m4a1_silencer",
	"weapon_m4a1",
	"weapon_galilar",
	"weapon_famas",
	"weapon_sg556",
	"weapon_sg556",
	"weapon_aug",
	"weapon_awp"
};
new const String:g_szSecondaryWeapons[][32] =		
{
	"weapon_glock",
	"weapon_usp_silencer",
	"weapon_hkp2000",
	"weapon_p250",
	"weapon_fiveseven",
	"weapon_elite",
	"weapon_deagle",
	"weapon_tec9",
	"weapon_cz75a"
};
#define g_ChatHeader			 							  "[\x04SDM\x01]"
#define LOADOUT_SAVE										  0
new g_pMenuPage[MAXPLAYERS + 1]								= 0;
new String:g_szPlayerPrimary[MAXPLAYERS + 1][64];
new String:g_szPlayerSecondary[MAXPLAYERS + 1][64];
new bool:g_playerSaveLoadout[MAXPLAYERS + 1]				= true;
new bool:g_playerGotMenu[MAXPLAYERS + 1]					= false;

public OnPluginStart()
{
	RegConsoleCmd("sm_guns",c_Guns);
	HookEvent("player_spawn", onPlayerSpawn);
	HookEvent("item_pickup", item_pickup);
}

public OnClientPutInServer(client) SDKHook(client, SDKHook_WeaponDrop, onWeaponDrop );

public Action:onWeaponDrop(client, weapon)
{
    if(IsValidEdict(weapon))
    	AcceptEntityInput(weapon, "Kill");
    return Plugin_Continue;
}

public OnClientDisconnect(client)
{
	if(!IsClientConnected(client))
		return;
	stripPlayer(client, CS_SLOT_PRIMARY);
	stripPlayer(client, CS_SLOT_SECONDARY);
}

public item_pickup(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsClientConnected(client) || !IsClientInGame(client))
		return;
	new wep = GetPlayerWeaponSlot(client, 4);
	if(wep != -1)
	{
		new String:c4Player[32];
		GetClientName(client, c4Player, sizeof(c4Player));
		PrintToChatAll("C4 has found on %s.Removing..", c4Player);
		RemovePlayerItem(client, wep);
		PrintToChatAll("C4 has removed.");
	}
}

public onPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!g_playerSaveLoadout[client])
		{drawPrimaries(client); return;}
	stripPlayer(client, CS_SLOT_PRIMARY);
	stripPlayer(client, CS_SLOT_SECONDARY);
	GivePlayerItem(client, g_szPlayerPrimary[client]);
	GivePlayerItem(client, g_szPlayerSecondary[client]);
	g_playerGotMenu[client] = false;
}

public Action c_Guns(client, args)
{
	if(!g_playerGotMenu[client])
	{
		drawPrimaries(client); 
		g_playerGotMenu[client] = true;
	}
	PrintToChat(client, "%s Gun menu will be shown when you respawn.", g_ChatHeader);
	return Plugin_Handled;
}

public PanelSelected(Menu menu, MenuAction action, client, rtdata)
{
	if (action == MenuAction_Select)
	{
		if(g_pMenuPage[client] == MENU_PAGE1)
		{
			stripPlayer(client, CS_SLOT_PRIMARY);
			GivePlayerItem(client, g_szPrimaryWeapons[rtdata]);
			g_szPlayerPrimary[client] = g_szPrimaryWeapons[rtdata];
			drawSecondaries(client);
		}
		else if(g_pMenuPage[client] == MENU_PAGE2)
		{
			stripPlayer(client, CS_SLOT_SECONDARY);
			GivePlayerItem(client, g_szSecondaryWeapons[rtdata]);
			g_szPlayerSecondary[client] = g_szSecondaryWeapons[rtdata];
			drawSaveOption(client);
		}
		else if(g_pMenuPage[client] == MENU_PAGE3)
		{
			if(rtdata != LOADOUT_SAVE)
			{
				g_szPlayerPrimary[client]   = "";
				g_szPlayerSecondary[client] = "";
				g_playerSaveLoadout[client] = false;
			}
			else
				g_playerSaveLoadout[client] = true;
		}
		g_playerGotMenu[client] = true;
	}
}

public drawPrimaries(client)
{
	Menu menu = new Menu(PanelSelected);
	menu.SetTitle("Select your primary weapon");
	menu.AddItem("0", "AK-47");
	menu.AddItem("1", "M4A1-S");
	menu.AddItem("2", "M4A4");
	menu.AddItem("3", "Galil");
	menu.AddItem("4", "Famas");
	menu.AddItem("5", "SG553");
	menu.AddItem("6", "AUG");
	menu.AddItem("7", "AWP");
	menu.ExitButton = true;
	g_pMenuPage[client] = MENU_PAGE1;
	menu.Display(client, 20);
}

public drawSecondaries(client)
{
	Menu menu = new Menu(PanelSelected);
	menu.SetTitle("Select your secondary weapon");
	menu.AddItem("0", "Glock");
	menu.AddItem("1", "USP-S");
	menu.AddItem("2", "P2000");
	menu.AddItem("3", "P250");
	menu.AddItem("4", "FiveSeven");
	menu.AddItem("5", "Dual Barettas");
	menu.AddItem("6", "Deagle");
	menu.AddItem("7", "TEC-9");
	menu.AddItem("8", "CZ75-A");
	menu.ExitButton = true;
	g_pMenuPage[client] = MENU_PAGE2;
	menu.Display(client, 20);
}

public drawSaveOption(client)
{
	Menu menu = new Menu(PanelSelected);
	menu.SetTitle("Save Loadout ?");
	menu.AddItem("0", "Yes");
	menu.AddItem("1", "No");
	menu.ExitButton = true;
	g_pMenuPage[client] = MENU_PAGE3;
	menu.Display(client, 20);
}

public stripPlayer(client, slot)
{
	if(!IsClientConnected(client) || !IsClientInGame(client))
		return;
	new w_Slot = GetPlayerWeaponSlot(client, slot);
	if(w_Slot != -1)
		RemovePlayerItem(client, w_Slot);
}