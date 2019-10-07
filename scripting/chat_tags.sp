#include <sourcemod>
#include <sdktools>
#include <chat-processor>
#include <colorvariables>

#pragma newdecls required

#define TAG_FLAGS ADMFLAG_CUSTOM6
#define SERVER_TAG "{lightgreen}Server"

#define MAXLENGTH_TAG 64
#define MAXLENGTH_TRUE_TAG 16

public Plugin myinfo =
{
    name = "Custom Chat Tags",
    author = "DS",
    description = "Adds colored tags to players.",
    version = "0.0.1a",
    url = "https://steamcommunity.com/id/TheDS1337/"
};

Database g_SQLDatabase = null;
char g_ClientTag[MAXPLAYERS + 1][MAXLENGTH_TAG];

public void OnPluginStart()
{
	RegAdminCmd("sm_tag", OnClientSetTagCmd, TAG_FLAGS);
	RegAdminCmd("sm_tagme", OnClientSetTagCmd, TAG_FLAGS);
	RegAdminCmd("sm_settag", OnClientSetTagCmd, TAG_FLAGS);

	g_SQLDatabase = SQL_Initiate();
}

public void OnPluginEnd()
{
	if( g_SQLDatabase )
	{
		delete g_SQLDatabase; g_SQLDatabase = null;
	}
}

public void OnClientPostAdminCheck(int client)
{
	g_ClientTag[client] = "";	

	// Load tags
	SQL_LoadTags(client);
}

public void OnClientDisconnect(int client)
{
	// Save tags
	SQL_SaveTags(client);
}

public Action OnClientSetTagCmd(int client, int args)
{
	if( !CanClientHaveTag(client) )
	{
		CPrintToChat(client, "[%s{default}]: You don't have access to this!", SERVER_TAG);		
		return Plugin_Handled;
	}

	if( args == 0 )
	{
		return Plugin_Handled;
	}	

	char actualTag[MAXLENGTH_TAG];
	int len = GetCmdArgString(actualTag, sizeof(actualTag));
	
	if( len > MAXLENGTH_TAG )
	{
		CPrintToChat(client, "[%s{default}]: The tag is too long.", SERVER_TAG);
		return Plugin_Handled;
	}

	CRemoveColors(actualTag, sizeof(actualTag));
	
	if( strlen(actualTag) > MAXLENGTH_TRUE_TAG )
	{
		CPrintToChat(client, "[%s{default}]: The tag is too long.", SERVER_TAG);
		return Plugin_Handled;
	}

	GetCmdArgString(g_ClientTag[client], sizeof(g_ClientTag[]));	
	CPrintToChat(client, "[%s{default}]: Your tag is set!", SERVER_TAG);

	return Plugin_Handled;
}

public Action CP_OnChatMessage(int& author, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool& processcolors, bool& removecolors)
{
	if( !CanClientHaveTag(author) )
	{
		return Plugin_Handled;
	}

	if( strlen(g_ClientTag[author]) > 0 )
	{
		Format(name, MAXLENGTH_NAME, "{default}[%s{default}]{teamcolor} %s", g_ClientTag[author], name);
		return Plugin_Changed;
	}

	return Plugin_Continue;
}

Database SQL_Initiate()
{
/*
	"chattags"
	{
		"driver"			"sqlite"
		"host"				"localhost"
		"database"			"chattags-sqlite"
		"user"				"root"
		"pass"				""
		//"timeout"			"0"
		//"port"			"0"
	}
*/
	Database db = null;

	char error[255];
	db = SQL_Connect("chattags", false, error, sizeof(error));
 
	if( !db )
	{
		SetFailState("Could not connect to sql database: %s", error);
		return null;
	} 
	
	SQL_LockDatabase(db);
	SQL_FastQuery(db, "CREATE TABLE IF NOT EXISTS chattags (steamid TEXT, tag TEXT);");
	SQL_UnlockDatabase(db);	

	return db;
}

void SQL_LoadTags(int client)
{
	if( !g_SQLDatabase )
	{
		return;
	}

	if( !CanClientHaveTag(client) )
	{
		return;
	}

	char steamId[96];
	GetClientAuthId(client, AuthId_SteamID64, steamId, sizeof(steamId));

	char buffer[256];
	Format(buffer, sizeof(buffer), "SELECT tag FROM chattags WHERE steamid = '%s'", steamId);

	SQL_TQuery(g_SQLDatabase, SQL_OnLoadQueryChecking, buffer, client);
}

void SQL_SaveTags(int client)
{
	if( !g_SQLDatabase )
	{
		return;
	}

	if( !CanClientHaveTag(client) )
	{
		return;
	}

	char steamId[96];
	GetClientAuthId(client, AuthId_SteamID64, steamId, sizeof(steamId));

	char buffer[256];
	Format(buffer, sizeof(buffer), "INSERT INTO chattags VALUES ('%s', '%s')", steamId, g_ClientTag[client]);

	SQL_TQuery(g_SQLDatabase, SQL_OnSaveQueryChecking, buffer);
}

public void SQL_OnLoadQueryChecking(Handle owner, Handle hndl, const char[] error, any data)
{
	int client = view_as<int> (data);

	if( !IsClientConnected(client) )
	{
		return;
	}

	if( strlen(error) > 0 )
	{
		PrintToServer("SQL Error: %s", error);
		return;
	}

	if( SQL_FetchRow(hndl) )
	{
		SQL_FetchString(hndl, 0, g_ClientTag[client], sizeof(g_ClientTag[]));
	}
}

public void SQL_OnSaveQueryChecking(Handle owner, Handle hndl, const char[] error, any data)
{
	if( strlen(error) > 0 )
	{
		PrintToServer("SQL Error: %s", error);
	}
}

bool CanClientHaveTag(int client)
{
	if( IsFakeClient(client) )
	{
		return false;
	}

	return CheckCommandAccess(client, "sm_tagme", TAG_FLAGS);
}