//========---- INCLUDE ----========//
#include 				<a_samp>
#include 				<a_mysql>
#include 				<sscanf2>
#include 				<pawn.cmd>
// #include 			<sqlitei>
// YSI
#include 				<YSI_Coding/y_va>
//==========-------------==========//


//========---- DEFINES ----========//
// MAX PLAYERS
#if defined MAX_PLAYERS
#undef MAX_PLAYERS
#endif
#define MAX_PLAYERS				200
#define MAX_DIALOGS 			12000
#define MAX_COMMANDS 			1000
#define MAX_LOGIN_ATTEMPTS 		5
#define MAX_ADMIN_ATTEMPTS 		5
// defination of function
#define function%0(%1) forward %0(%1);public %0(%1)
// mysql var
#define SQL_HOST 				"localhost"
#define SQL_USER 				"root"
#define SQL_PASS 				""
#define SQL_DATA 				"shadowdb"
// Script
#define SFM SendFormatMessage
//==========-------------==========//


//========---- VARIABLES ----========//
enum dialogids {
	DIALOG_USERNAME,
	DIALOG_LOGIN,
	DIALOG_REGISTER,
	DIALOG_REGISTER_RE,
	DIALOG_REGISTER_NAME,
	DIALOG_REGISTER_AGE,
	DIALOG_REGISTER_GENDER,
	DIALOG_REGISTER_EMAIL,
	DIALOG_REGISTER_REFERRAL,

	DIALOG_ADMIN_LOGIN,
};

enum diTable {
	diStyle,
	diTitle[64],
	diCaption[1024],
	diBtn1[50],
	diBtn2[50]
};
new DialogTable[][diTable] = {
	{DIALOG_STYLE_INPUT,	"[ShadowTeam] Username","Please Enter Your Username Here","Check","Exit"},
	{DIALOG_STYLE_PASSWORD,	"[ShadowTeam] Login","Please Enter Your Password Here","Login","Back"},
	{DIALOG_STYLE_INPUT,	"[ShadowTeam] Register (Password)","Please Chose a Password And Enter It","Next","Prevoius"},
	{DIALOG_STYLE_PASSWORD,	"[ShadowTeam] Register (Re-Password)","Please Confirm The Given Password","Next","Prevoius"},
	{DIALOG_STYLE_INPUT,	"[ShadowTeam] Register (Name)","Please Enter A Game Name\nPlease Enter Your Acutal Name Like 'Mobin Baratian'","Next","Prevoius"},
	{DIALOG_STYLE_INPUT,	"[ShadowTeam] Register (Age)","Please Enter Your Age Here","Next","Prevoius"},
	{DIALOG_STYLE_LIST,		"[ShadowTeam] Register (Gender)","Male\nFemale","Next","Prevoius"},
	{DIALOG_STYLE_INPUT,	"[ShadowTeam] Register (Email)","Please Enter Your Email Here Or Simply Type 'skip' For Skiping This Stage","Next","Prevoius"},
	{DIALOG_STYLE_INPUT,	"[ShadowTeam] Register (Refferal)","Please Enter Your Refferal Here","Verify","Skip"},

	{DIALOG_STYLE_INPUT,	"[ShadowTeam] Admin (Login)","Please Enter Your Admin-Code Here","Login","Cancel"}
};

new MySQL:mysql;

enum cmdInfo {
	cmdName[50],
	cmdSyntax[50],
	cmdFormat[50],
	cmdILogin,
	cmdAdmin,
	cmdLock,
	cmdOOnly
};
new Commands[MAX_COMMANDS][cmdInfo];

enum pInfo {

	// SQL save
	pID,
	pUsername[50],
	pPassword[100],
	pEmail[100],
	pName[50],
	pRegistered,
	pRegisterLevel,

	pAdminLevel,
	pAdminCode,
	pAdminBPoints,

	pGender,
	pAge,
	pBan,
	pBanip[50],
	pIp[50],
	pReferral[50],

	// In-Game (cache)
	bool:pLogged,
	bool:pAdminLogin,
	bool:pSpawned,
	pFName[50],
	pLoginAttempts,
	pAdminAttempts,
};
new PlayerInfo[MAX_PLAYERS][pInfo];
//==========-------------==========//


//========---- FUNCTIONS ----========//
stock GenerateSerial_Number(length=4) {
	new tidx = length;
	new tmpbuffers[50];
	for(new x=0;x<tidx;x++) {
		format(tmpbuffers,sizeof tmpbuffers,"%s%d",tmpbuffers,random(100));
	}
	return tmpbuffers;
}
stock GetName(playerid) {
	new tmpname[MAX_PLAYER_NAME+1];
	GetPlayerName(playerid,tmpname,sizeof tmpname);
	return tmpname;
}
stock GetNameEx(playerid) {
	if(strlen(PlayerInfo[playerid][pName])) return PlayerInfo[playerid][pName];
	else return 0;
}
stock GetCommandID(const tmpcmdname[]) {
	// result = -1;
	for(new x=0;x<MAX_COMMANDS;x++) {
		if(strlen(Commands[x][cmdName]) && strcmp(tmpcmdname,Commands[x][cmdName],true) == 0) {
			return x;
		}
	}
	return -1;
}

enum msgType {
	msgError,
	msgInfo,
	msgWarning,
	msgAdmin
};

new msgColors[][] = {
	"ff003c",
	"0088ff",
	"ff6f00",
	"b7ff00"
};
new msgTText[][] = {
	"Error",
	"Info",
	"Warning",
	"Admin"
};

stock SendFormatMessage(playerid,tmptype,const message[],GLOBAL_TAG_TYPES:...) {
	new tmpmessage[512];
	format(tmpmessage,sizeof tmpmessage,"{%s}%s -|{ffffff} %s.",msgColors[tmptype],msgTText[tmptype],va_return(message,___(3)));
	return SendClientMessage(playerid,-1,tmpmessage);
}

stock KickPlayerEx(playerid,const reason[],GLOBAL_TAG_TYPES:...) {
	SFM(playerid,msgError,va_return(reason,___(2)));
	return SetTimerEx("Kick",1000,false,"i",playerid);
}

stock CreateDialog(playerid,dialogids:dialogid,const addon_title[] = "",const addon_caption[] = "") {
	new tmpTITLE[64],tmpCAPTION[1024];

	format(tmpTITLE,sizeof tmpTITLE,"%s%s",DialogTable[dialogid][diTitle],addon_title);
	format(tmpCAPTION,sizeof tmpCAPTION,"%s%s",DialogTable[dialogid][diCaption],addon_caption);

	return ShowPlayerDialog(playerid,dialogid,DialogTable[dialogid][diStyle],tmpTITLE,tmpCAPTION, \
		DialogTable[dialogid][diBtn1],DialogTable[dialogid][diBtn2]);
}

stock ResetPlayerData(playerid) {
	PlayerInfo[playerid][pID] = 0;
	PlayerInfo[playerid][pUsername] = 0;
	PlayerInfo[playerid][pPassword] = 0;
	PlayerInfo[playerid][pEmail] = 0;
	PlayerInfo[playerid][pName] = 0;
	PlayerInfo[playerid][pRegistered] = 0;
	PlayerInfo[playerid][pRegisterLevel] = 0;

	PlayerInfo[playerid][pAdminLevel] = 0;
	PlayerInfo[playerid][pAdminCode] = 0;
	PlayerInfo[playerid][pAdminBPoints] = 0;

	PlayerInfo[playerid][pGender] = 0;
	PlayerInfo[playerid][pAge] = 0;
	PlayerInfo[playerid][pBan] = 0;
	PlayerInfo[playerid][pBanip] = 0;
	PlayerInfo[playerid][pIp] = 0;
	PlayerInfo[playerid][pReferral] = 0;
	PlayerInfo[playerid][pLogged] = false;
	PlayerInfo[playerid][pSpawned] = false;
	PlayerInfo[playerid][pFName] = 0;
	PlayerInfo[playerid][pLoginAttempts] = 0;

	PlayerInfo[playerid][pAdminLogin] = false;
	PlayerInfo[playerid][pAdminAttempts] = 0;

	return 1;
}
stock SavePlayerDatas(playerid) {
	SavePlayerData(playerid,"ip","%s",GetIP(playerid));
	return 1;
}

new adminlevel_names[][] = {
	"NON-ADMIN", 			// 0
	"Admin (1)", 			// 1
	"Admin (2)", 			// 2
	"Admin (3)", 			// 3
	"Admin (4)", 			// 4
	"Admin (Head)", 		// 5
	"Host (1)",				// 6
	"Host (2)",				// 7
	"Host (3)", 			// 8
	"MGMT (Supervisor)",	// 9
	"MGMT (Manager)", 		// 10
	"MGMT (Founder)", 		// 11
	"DEV (Contriver)", 		// 12
	"DEV (Scripter)",		// 13
	"Owner (EPSILON)"		// 14
};

stock GetAdminName(level) {
	new tmpname[50];
	if(0 <= level < sizeof(adminlevel_names)) format(tmpname,sizeof tmpname,adminlevel_names[level]);
	else if(level > sizeof(adminlevel_names)) format(tmpname,sizeof tmpname,adminlevel_names[sizeof(adminlevel_names)-1]);
	return tmpname;
}
//==========-------------==========//


//========---- FUNCTIONS ----========//
function LoadDatabase() {
	printf("/============================\\");
	printf("- Loading server Database\n");
	new Cache:tmpcache,idxs;

	//users
	tmpcache = mysql_query(mysql,"select * from users order by id asc");
	cache_get_row_count(idxs);
	printf("[ShadowTeam] Total User Count [-%d-]",idxs);

	// bans
	tmpcache = mysql_query(mysql,"select * from bans order by username asc");
	cache_get_row_count(idxs);
	printf("[ShadowTeam] Total Banned Users [-%d-]",idxs);

	// banip
	tmpcache = mysql_query(mysql,"select * from banips order by ip asc");
	cache_get_row_count(idxs);
	printf("[ShadowTeam] Total Banned IPs [-%d-]",idxs);

	// admins
	tmpcache = mysql_query(mysql,"select * from admins order by username asc");
	cache_get_row_count(idxs);
	printf("[ShadowTeam] Total Server Admins [-%d-]",idxs);

	// commands
	tmpcache = mysql_query(mysql,"select * from commands order by cmd asc");
	cache_get_row_count(idxs);
	printf("[ShadowTeam] Total Server Defined Commands [-%d-]",idxs);
	
	// delete the cache
	cache_delete(tmpcache);
	printf("\\============================/");
	return 1;
}

function LoadCommands() {
	new idx,tmpstr[128];
	mysql_format(mysql,tmpstr,sizeof tmpstr,"select * from commands order by cmd asc");
	new Cache: tmpcache = mysql_query(mysql,tmpstr);
	cache_get_row_count(idx);
	if(idx) {
		for(new i=0;i<idx;i++) {
			cache_get_value(i,		"cmd",Commands[i][cmdName],50);
			cache_get_value(i,		"syntax",Commands[i][cmdSyntax],50);
			cache_get_value(i,		"sscanf",Commands[i][cmdFormat],50);
			cache_get_value_int(i,	"ilogin",Commands[i][cmdILogin]);
			cache_get_value_int(i,	"admin",Commands[i][cmdAdmin]);
			cache_get_value_int(i,	"cmdlock",Commands[i][cmdLock]);
			cache_get_value_int(i,	"owneronly",Commands[i][cmdOOnly]);
		}
	}
	cache_delete(tmpcache);
	return 1;
}

function OnPlayerCommandReceived(playerid, cmd[], params[], flags) {
	new registered = 0;
	new idxs = -1;
	for(new x=0;x<MAX_COMMANDS;x++) {
		if(strlen(Commands[x][cmdName]) && strcmp(cmd,Commands[x][cmdName],true) == 0) {
			registered = 1;idxs = x;
			break;
		}
	}
	if(registered) {
		if(Commands[idxs][cmdOOnly] && PlayerInfo[playerid][pAdminLevel] < 11) {
			SFM(playerid,msgError,"This Command Is Locked By MGMT-Team"); 
			return false;
		} else if(Commands[idxs][cmdAdmin] > 0) {
			if(PlayerInfo[playerid][pAdminLevel] < 1) {
				SFM(playerid,msgError,"You're Not An Admin Of This Server !");
				return false;
			} else if(PlayerInfo[playerid][pAdminLogin] == false) {
				if(Commands[idxs][cmdILogin] != 1) {
					SFM(playerid,msgError,"Your Admin Level Not Authorized Yet !");
					return false;
				}
			} else if(Commands[idxs][cmdAdmin] > PlayerInfo[playerid][pAdminLevel]) {
				SFM(playerid,msgError,"You Don't Have Enough Admin Level To Use This Command, Required Level [%d]",Commands[idxs][cmdAdmin]);
				return false;
			}
		} else if(Commands[idxs][cmdLock]) {
			if(PlayerInfo[playerid][pAdminLevel] < 1) {
				SFM(playerid,msgError,"This Command Is Locked By Administrators");
				return false;
			} else if(Commands[idxs][cmdAdmin] > PlayerInfo[playerid][pAdminLevel]) {
				SFM(playerid,msgError,"This Command Is Locked By Higher Admin Ranks");
				return false;
			}
		} else {
			return 1;
		}
	} else {
		SFM(playerid,msgError,"Command [%s] Not Registered, Please Correct Misspelling",cmd);
		return false;
	}
	return -1;
}

function OnPlayerCommandPerformed(playerid, cmd[], params[], result, flags) {
	// new idxs = -1;
	// for(new x=0;x<MAX_COMMANDS;x++) {
	// 	if(strcmp(cmd,Commands[x][cmdName],true) == 0) {
	// 		idxs = x;
	// 		break;
	// 	}
	// }
	// if (idxs != -1) {
		// if(sscanf(params,Commands[idxs][cmdFormat],result)) return SFM(playerid,msgError,"Command Ussage Incorrect, /%s %s",cmd,Commands[idxs][cmdSyntax]);
	if(!result) return SFM(playerid,msgError,"Command Result Failure [%s], Please Try Again !",cmd);
	else return 1;
	// }
	// return -1;
}

function CheckUsernameBanState(playerid,username[]) {
	// 1: normal
	// 2: permanent

	SFM(playerid,msgInfo,"Checking Ban Status For User %s",username);
	new idx,tmpstr[128];
	mysql_format(mysql,tmpstr,sizeof tmpstr,"select * from bans where username='%e'",username);
	new Cache: tmpcache = mysql_query(mysql,tmpstr);
	cache_get_row_count(idx);
	if(idx) {
		// banned
		new tmptime,tmptype,tmpreason[50],tmpdate[20];
		new tmptypes[50];
		cache_get_value_int(0,"time",tmptime);
		cache_get_value_int(0,"type",tmptype);
		cache_get_value(0,"reason",tmpreason,50);
		cache_get_value(0,"date",tmpdate,20);
		if(tmptype == 1) format(tmptypes,sizeof tmptypes,"{ff557a}Permanent{ffffff}");
		if(tmptype == 2) format(tmptypes,sizeof tmptypes,"{ff557a}%d{ffffff}",tmptime);
		SFM(playerid,msgError,"Username %s Banned For [%s] From [%d] Reason [%s]",username,tmptypes,tmpdate,tmpreason);
		CreateDialog(playerid,DIALOG_USERNAME);
	} else {
		SFM(playerid,msgInfo,"Username %s Is Not Banned From Server",username);
		return true;
	}
	cache_delete(tmpcache);
	return 0;
}
function CheckIPBanState(playerid,tmpip[]) {
	// 1: normal
	// 2: permanent

	SFM(playerid,msgInfo,"Checking Ban Status For IP %s",tmpip);
	new idx,tmpstr[128];
	mysql_format(mysql,tmpstr,sizeof tmpstr,"select * from banips where ip='%e'",tmpip);
	new Cache: tmpcache = mysql_query(mysql,tmpstr);
	cache_get_row_count(idx);
	if(idx) {
		// banned
		new tmptime,tmptype,tmpreason[50],tmpdate[20];
		new tmptypes[50];
		cache_get_value_int(0,"time",tmptime);
		cache_get_value_int(0,"type",tmptype);
		cache_get_value(0,"reason",tmpreason,50);
		cache_get_value(0,"date",tmpdate,20);
		if(tmptype == 1) format(tmptypes,sizeof tmptypes,"{ff557a}Permanent{ffffff}");
		if(tmptype == 2) format(tmptypes,sizeof tmptypes,"{ff557a}%d{ffffff}",tmptime);
		// SFM(playerid,msgError,"IP %s Banned For [%s] From [%d] Reason [%s]",tmpip,tmptypes,tmpdate,tmpreason);
		KickPlayerEx(playerid,"IP %s Banned For [%s] From [%d] Reason [%s]",tmpip,tmptypes,tmpdate,tmpreason);
	} else {
		SFM(playerid,msgInfo,"IP %s Is Not Banned From Server",tmpip);
		return true;
	}
	cache_delete(tmpcache);
	return 0;
}

function SavePlayerData(playerid,tmpcolumn[],const tmpvalue[],GLOBAL_TAG_TYPES:...) {
	new query[128];
	format(query,sizeof query,"update users set %s='%s' where id='%d'",tmpcolumn,va_return(tmpvalue,___(3)),PlayerInfo[playerid][pID]);
	if (PlayerInfo[playerid][pLogged]) mysql_tquery(mysql,query,"","");
	return 1;
}

function SavePlayerAData(playerid,tmpcolumn[],const tmpvalue[],GLOBAL_TAG_TYPES:...) {
	new query[128];
	format(query,sizeof query,"update admins set %s='%s' where username='%s'",tmpcolumn,va_return(tmpvalue,___(3)),PlayerInfo[playerid][pUsername]);
	if (PlayerInfo[playerid][pLogged]) mysql_tquery(mysql,query,"","");
	return 1;
}

function CheckUsername(playerid,username[]) {
	new idx,tmpstr[128];
	mysql_format(mysql,tmpstr,sizeof tmpstr,"select * from users where username='%s'",username);
	new Cache: tmpcache = mysql_query(mysql,tmpstr);
	cache_get_row_count(idx);
	if(idx) {
		// login
		if(CheckUsernameBanState(playerid,username)) {
			SFM(playerid,msgInfo,"Username %s Is Founded in Database",username);
			CreateDialog(playerid,DIALOG_LOGIN);
		}
	} else {
		// register
		SFM(playerid,msgError,"Username %s Is Not Founded in Database",username);
		CreateDialog(playerid,DIALOG_REGISTER);
	}
	cache_delete(tmpcache);
	return 1;
}

function OnPlayerLogin(playerid,username[],password[]) {
	new tmpquery[128],idxs;
	mysql_format(mysql,tmpquery,sizeof tmpquery,"select * from users where username='%e' and password='%e'",username,password);
	new Cache:tmpcache = mysql_query(mysql,tmpquery);
	cache_get_row_count(idxs);
	if(idxs) {
		SFM(playerid,msgInfo,"Login Successfull, Loading Datas From Database, Please Wait");
		PlayerInfo[playerid][pLogged] = true;
		cache_get_value_int(0,		"id",PlayerInfo[playerid][pID]);
		cache_get_value(0,			"email",PlayerInfo[playerid][pEmail],50);
		cache_get_value(0,			"name",PlayerInfo[playerid][pName],50);
		cache_get_value_int(0,		"registered",PlayerInfo[playerid][pRegistered]);
		cache_get_value_int(0,		"registerlevel",PlayerInfo[playerid][pRegisterLevel]);
		// cache_get_value_int(0,		"adminlevel",PlayerInfo[playerid][pAdminLevel]);
		cache_get_value_int(0,		"gender",PlayerInfo[playerid][pGender]);
		cache_get_value_int(0,		"age",PlayerInfo[playerid][pAge]);
	} else {
		// invalid password
		if(PlayerInfo[playerid][pLoginAttempts] == MAX_LOGIN_ATTEMPTS) return KickPlayerEx(playerid,"Login Attempt Reach its Limit, Please Join Other Times");
		PlayerInfo[playerid][pLoginAttempts] ++;
		new tmpstrs[50];format(tmpstrs,sizeof tmpstrs,"\n\n{ff557a}Invalid Password [%d/%d]",PlayerInfo[playerid][pLoginAttempts],MAX_LOGIN_ATTEMPTS);
		return CreateDialog(playerid,DIALOG_LOGIN,"",tmpstrs);
	}
	cache_delete(tmpcache);
	SFM(playerid,msgInfo,"Player Datas Loaded From Database");
	if(PlayerInfo[playerid][pRegistered] != 1) {
		SFM(playerid,msgWarning,"Your Account Have Incompleted Registeration, Please Complete Them");
		switch(PlayerInfo[playerid][pRegisterLevel]) {
			case 2: return CreateDialog(playerid,DIALOG_REGISTER_NAME);
			case 3: return CreateDialog(playerid,DIALOG_REGISTER_AGE);
			case 4: return CreateDialog(playerid,DIALOG_REGISTER_GENDER);
			case 5: return CreateDialog(playerid,DIALOG_REGISTER_EMAIL);
			default: return SFM(playerid,msgError,"Invalid Registeration Level, Operation Canceld With Code : 0x56773, Please Contact Admin Of Server");
			// case 5: CreateDialog(playerid,DIALOG_REGISTER_REFERRAL);
		}
	} else {
		mysql_format(mysql,tmpquery,sizeof tmpquery,"select * from admins where username='%e'",username);
		tmpcache = mysql_query(mysql,tmpquery);
		cache_get_row_count(idxs);
		if(idxs) {

			cache_get_value_int(0,		"level",PlayerInfo[playerid][pAdminLevel]);
			cache_get_value_int(0,		"code",PlayerInfo[playerid][pAdminCode]);
			cache_get_value_int(0,		"badpoints",PlayerInfo[playerid][pAdminBPoints]);


			if(PlayerInfo[playerid][pAdminLevel] > 0) {
				SFM(playerid,msgAdmin,"You Have Admin Level [%s], For Using Admin Commands Please Use /alogin First",GetAdminName(PlayerInfo[playerid][pAdminLevel]));
			} else {
				SFM(playerid,msgWarning,"Your Username Registered As Server Admin But Have No Level Right Now, Please Contact MGMT-Team");
			}
		}
		cache_delete(tmpcache);

		SetPlayerName(playerid,PlayerInfo[playerid][pName]);
		SetSpawnInfo(playerid,0,0,0.0,0.0,0.0,0.0,0,0,0,0,0,0);
		SpawnPlayer(playerid);
	}
	return 1;
}

function OnPlayerRegister(playerid,username[],password[]) {
	new tmpquery[128];
	mysql_format(mysql,tmpquery,sizeof tmpquery,"insert into users(username,password,registerlevel) values ('%e','%e','1')",username,password);
	new Cache:tmpcache = mysql_query(mysql,tmpquery);
	PlayerInfo[playerid][pID] = cache_insert_id();
	cache_delete(tmpcache);
	OnPlayerRegisterLevel(playerid,1,"");
	return 1;
}

function OnPlayerRegisterLevel(playerid,level,tmpaddons[]) {
	if(level == 1) {
		PlayerInfo[playerid][pRegisterLevel] = 2;
		SavePlayerData(playerid,"registerlevel","%d",PlayerInfo[playerid][pRegisterLevel]);
		CreateDialog(playerid,DIALOG_REGISTER_NAME);
	} else if(level == 2) { // name
		PlayerInfo[playerid][pRegisterLevel] = 3;
		format(PlayerInfo[playerid][pName],50,tmpaddons);
		SavePlayerData(playerid,"name","%s",PlayerInfo[playerid][pName]);
		SavePlayerData(playerid,"registerlevel","%d",PlayerInfo[playerid][pRegisterLevel]);
		CreateDialog(playerid,DIALOG_REGISTER_AGE);
	} else if(level == 3) { // age 
		PlayerInfo[playerid][pRegisterLevel] = 4;
		PlayerInfo[playerid][pAge] = strval(tmpaddons);
		SavePlayerData(playerid,"age","%d",PlayerInfo[playerid][pAge]);
		SavePlayerData(playerid,"registerlevel","%d",PlayerInfo[playerid][pRegisterLevel]);
		CreateDialog(playerid,DIALOG_REGISTER_GENDER);
	} else if(level == 4) { // gender
		PlayerInfo[playerid][pRegisterLevel] = 5;
		PlayerInfo[playerid][pGender] = strval(tmpaddons);
		SavePlayerData(playerid,"gender","%d",PlayerInfo[playerid][pGender]);
		SavePlayerData(playerid,"registerlevel","%d",PlayerInfo[playerid][pRegisterLevel]);
		CreateDialog(playerid,DIALOG_REGISTER_EMAIL);
	} else if(level == 5) { // email
		PlayerInfo[playerid][pRegistered] = 1;
		PlayerInfo[playerid][pRegisterLevel] = 0;
		if(strlen(tmpaddons)) {
			format(PlayerInfo[playerid][pEmail],50,tmpaddons);
			SavePlayerData(playerid,"email",PlayerInfo[playerid][pEmail]);
		}
		SavePlayerData(playerid,"registered","%d",PlayerInfo[playerid][pRegistered]);
		SavePlayerData(playerid,"registerlevel","%d",PlayerInfo[playerid][pRegisterLevel]);
		// CreateDialog(playerid,DIALOG_REGISTER_REFERRAL);
		// PlayerInfo[playerid][pRegisterLevel] = 5;
	} else if(level == 6) { // referral
		// Your Training !!
	}

	if(PlayerInfo[playerid][pRegistered] == 1) {
		SFM(playerid,msgInfo,"Registeration Was Successfull, Spawning Player");
		SetPlayerName(playerid,PlayerInfo[playerid][pName]);
		SetSpawnInfo(playerid,0,0,0.0,0.0,0.0,0.0,0,0,0,0,0,0);
		SpawnPlayer(playerid);
	}

	return 1;
}
//==========-------------==========//


//========---- MAIN ----========//
main() {}
//==========-------------==========//


//========---- CALLBACKS ----========//
public OnGameModeInit()
{
	SetGameModeText("Blank Script");
	AddPlayerClass(0, 1958.3783, 1343.1572, 15.3746, 269.1425, 0, 0, 0, 0, 0, 0);

	mysql_log(ALL); // Activate Server Logging

	// mysql = mysql_connect(SQL_HOST,SQL_USER,SQL_PASS,SQL_DATA);
	mysql = mysql_connect_file();

	if(mysql_errno(mysql)) printf("[SQL-Error] MySQl Not Connected To Server !");
	else printf("[SQL-Info] MySQl Connected To Server !");


	LoadDatabase();
	LoadCommands();
	
	return 1;
}

public OnGameModeExit()
{
	if(mysql) mysql_close();
	return 1;
}

public OnPlayerRequestClass(playerid, classid)
{
	SetPlayerPos(playerid, 1958.3783, 1343.1572, 15.3746);
	SetPlayerCameraPos(playerid, 1958.3783, 1343.1572, 15.3746);
	SetPlayerCameraLookAt(playerid, 1958.3783, 1343.1572, 15.3746);

	CreateDialog(playerid,DIALOG_USERNAME);
	return 1;
}

public OnPlayerConnect(playerid)
{
	// change player name to serial
	ResetPlayerData(playerid);

	format(PlayerInfo[playerid][pFName],50,GetName(playerid));
	new tmpnames[50];
	format(tmpnames,sizeof tmpnames,"SHADOW-%",GenerateSerial_Number());
	SetPlayerName(playerid,tmpnames);
	new tmpips[50];GetPlayerIp(playerid,tmpips,sizeof tmpips);
	CheckIPBanState(playerid,tmpips);
	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
	SetPlayerName(playerid,PlayerInfo[playerid][pFName]);
	SavePlayerDatas(playerid);

	ResetPlayerData(playerid);
	return 1;
}

public OnPlayerSpawn(playerid)
{
	if(PlayerInfo[playerid][pLogged]) {
		PlayerInfo[playerid][pSpawned] = true;
		SetPlayerName(playerid,PlayerInfo[playerid][pName]);
		SFM(playerid,msgInfo,"Player Spawned, Enjoy Your Time In Server !");
	}
	return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
	return 1;
}

public OnVehicleSpawn(vehicleid)
{
	return 1;
}

public OnVehicleDeath(vehicleid, killerid)
{
	return 1;
}

public OnPlayerText(playerid, text[])
{
	return 1;
}

public OnPlayerCommandText(playerid, cmdtext[])
{
	return 0;
}

public OnPlayerEnterVehicle(playerid, vehicleid, ispassenger)
{
	return 1;
}

public OnPlayerExitVehicle(playerid, vehicleid)
{
	return 1;
}

public OnPlayerStateChange(playerid, newstate, oldstate)
{
	return 1;
}

public OnPlayerEnterCheckpoint(playerid)
{
	return 1;
}

public OnPlayerLeaveCheckpoint(playerid)
{
	return 1;
}

public OnPlayerEnterRaceCheckpoint(playerid)
{
	return 1;
}

public OnPlayerLeaveRaceCheckpoint(playerid)
{
	return 1;
}

public OnRconCommand(cmd[])
{
	return 1;
}

public OnPlayerRequestSpawn(playerid)
{
	return 1;
}

public OnObjectMoved(objectid)
{
	return 1;
}

public OnPlayerObjectMoved(playerid, objectid)
{
	return 1;
}

public OnPlayerPickUpPickup(playerid, pickupid)
{
	return 1;
}

public OnVehicleMod(playerid, vehicleid, componentid)
{
	return 1;
}

public OnVehiclePaintjob(playerid, vehicleid, paintjobid)
{
	return 1;
}

public OnVehicleRespray(playerid, vehicleid, color1, color2)
{
	return 1;
}

public OnPlayerSelectedMenuRow(playerid, row)
{
	return 1;
}

public OnPlayerExitedMenu(playerid)
{
	return 1;
}

public OnPlayerInteriorChange(playerid, newinteriorid, oldinteriorid)
{
	return 1;
}

public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
	return 1;
}

public OnRconLoginAttempt(ip[], password[], success)
{
	return 1;
}

public OnPlayerUpdate(playerid)
{
	return 1;
}

public OnPlayerStreamIn(playerid, forplayerid)
{
	return 1;
}

public OnPlayerStreamOut(playerid, forplayerid)
{
	return 1;
}

public OnVehicleStreamIn(vehicleid, forplayerid)
{
	return 1;
}

public OnVehicleStreamOut(vehicleid, forplayerid)
{
	return 1;
}

public OnDialogResponse(playerid, dialogid, response, listitem, inputtext[])
{
	switch(dialogid) {
		case DIALOG_USERNAME: {
			if(response) {
				new tmpstrs[50];
				if(!strlen(inputtext)) format(tmpstrs,sizeof tmpstrs,"\n\nPlease Enter Your Username !");
				else if(strlen(inputtext) < 5) format(tmpstrs,sizeof tmpstrs,"\n\nUsername Must At Least Be 6 Characters !");
				else if(strlen(inputtext) > 20) format(tmpstrs,sizeof tmpstrs,"\n\nMaximum Length Is 20 Characters !");
				else if(strfind(inputtext," ") != -1) format(tmpstrs,sizeof tmpstrs,"\n\nPlease Don't Use Space In Username !");
				else if(strlen(inputtext)) {
					format(PlayerInfo[playerid][pUsername],50,inputtext);
					CheckUsername(playerid,PlayerInfo[playerid][pUsername]);
				}
				if(strlen(tmpstrs)) return CreateDialog(playerid,DIALOG_USERNAME,"{ff557a} (Error)",tmpstrs);
			} else SFM(playerid,msgInfo,"Exiting The Server, GoodBye !");
		}
		case DIALOG_LOGIN: {
			if(response) {
				new tmpstrs[50];
				if(!strlen(inputtext)) format(tmpstrs,sizeof tmpstrs,"\n\nPlease Enter Your Password !");
				else if(strlen(inputtext) < 5) format(tmpstrs,sizeof tmpstrs,"\n\nPassword Must At Least Be 6 Characters !");
				else if(strlen(inputtext) > 20) format(tmpstrs,sizeof tmpstrs,"\n\nMaximum Length Is 20 Characters !");
				else if(strfind(inputtext," ") != -1) format(tmpstrs,sizeof tmpstrs,"\n\nPlease Don't Use Space In Password !");
				else {
					format(PlayerInfo[playerid][pPassword],50,inputtext);
					OnPlayerLogin(playerid,PlayerInfo[playerid][pUsername],PlayerInfo[playerid][pPassword]);
				} 
				if(strlen(tmpstrs)) return CreateDialog(playerid,DIALOG_LOGIN,"{ff557a} (Error)",tmpstrs);
			} else {
				SFM(playerid,msgWarning,"Canceled Login Progress");
				CreateDialog(playerid,DIALOG_USERNAME);
			}
		}
		case DIALOG_REGISTER: {
			if(response) {
				new tmpstrs[50];
				if(!strlen(inputtext)) format(tmpstrs,sizeof tmpstrs,"\n\nPlease Enter Your Password !");
				else if(strlen(inputtext) < 5) format(tmpstrs,sizeof tmpstrs,"\n\nPassword Must At Least Be 6 Characters !");
				else if(strlen(inputtext) > 20) format(tmpstrs,sizeof tmpstrs,"\n\nMaximum Length Is 20 Characters !");
				else if(strfind(inputtext," ") != -1) format(tmpstrs,sizeof tmpstrs,"\n\nPlease Don't Use Space In Password !");
				else {
					format(PlayerInfo[playerid][pPassword],50,inputtext);
					SFM(playerid,msgInfo,"Password Saved, Please Re-Enter It To Confirm The Given Password");
					CreateDialog(playerid,DIALOG_REGISTER_RE);
				} 
				if(strlen(tmpstrs)) return CreateDialog(playerid,DIALOG_REGISTER,"{ff557a} (Error)",tmpstrs);
			} else {
				SFM(playerid,msgWarning,"Canceled Register Progress");
				CreateDialog(playerid,DIALOG_USERNAME);
			}
		}
		case DIALOG_REGISTER_RE: {
			if(response) {
				new tmpstrs[50];
				if(!strlen(inputtext)) format(tmpstrs,sizeof tmpstrs,"\n\nPlease Enter Your Password !");
				else if(strlen(inputtext) < 5) format(tmpstrs,sizeof tmpstrs,"\n\nPassword Must At Least Be 6 Characters !");
				else if(strlen(inputtext) > 20) format(tmpstrs,sizeof tmpstrs,"\n\nMaximum Length Is 20 Characters !");
				else if(strfind(inputtext," ") != -1) format(tmpstrs,sizeof tmpstrs,"\n\nPlease Don't Use Space In Password !");
				else if(strcmp(inputtext,PlayerInfo[playerid][pPassword],false,0) == -1) format(tmpstrs,sizeof tmpstrs,"\n\nInserted Password Mismatch With The First Password !");
				else {
					OnPlayerRegister(playerid,PlayerInfo[playerid][pUsername],PlayerInfo[playerid][pPassword]);
				} 
				if(strlen(tmpstrs)) return CreateDialog(playerid,DIALOG_REGISTER_RE,"{ff557a} (Error)",tmpstrs);
			} else {
				SFM(playerid,msgWarning,"Going To Prevoius Step (Register: First Password)");
				CreateDialog(playerid,DIALOG_REGISTER);
			}
		}
		case DIALOG_REGISTER_NAME: {
			if(response) {
				new tmpstrs[50];
				if(!strlen(inputtext)) format(tmpstrs,sizeof tmpstrs,"\n\nPlease Enter Your Name !");
				else if(strlen(inputtext) < 5) format(tmpstrs,sizeof tmpstrs,"\n\nYour Name Must At Least Be 6 Characters !");
				else if(strlen(inputtext) > 50) format(tmpstrs,sizeof tmpstrs,"\n\nMaximum Length Is 50 Characters !");
				else if(strfind(inputtext,"_") == -1) format(tmpstrs,sizeof tmpstrs,"\n\nPlease Use _ Between Your First And Last Name !");
				else {
					OnPlayerRegisterLevel(playerid,2,inputtext);
				} 
				if(strlen(tmpstrs)) return CreateDialog(playerid,DIALOG_REGISTER_NAME,"{ff557a} (Error)",tmpstrs);
			} else {
				SFM(playerid,msgWarning,"Going To Prevoius Step (Register: First Password)");
				CreateDialog(playerid,DIALOG_REGISTER);
			}
		}
		case DIALOG_REGISTER_AGE: {
			if(response) {
				new tmpstrs[50];
				if(!strlen(inputtext)) format(tmpstrs,sizeof tmpstrs,"\n\nPlease Enter Your Age !");
				else if(!strval(inputtext)) format(tmpstrs,sizeof tmpstrs,"\n\nPlease Enter Your Age A Number (INT) !");
				else if(strval(inputtext) < 12) format(tmpstrs,sizeof tmpstrs,"\n\nPlayers Under Age of 12 Have No Right To Play In This Server !");
				else {
					OnPlayerRegisterLevel(playerid,3,inputtext);
				} 
				if(strlen(tmpstrs)) return CreateDialog(playerid,DIALOG_REGISTER_AGE,"{ff557a} (Error)",tmpstrs);
			} else {
				SFM(playerid,msgWarning,"Going To Prevoius Step (Register: In-Game Name)");
				CreateDialog(playerid,DIALOG_REGISTER_NAME);
			}
		}
		case DIALOG_REGISTER_GENDER: {
			if(response) {
				if(listitem != -1) {
					OnPlayerRegisterLevel(playerid,4,inputtext);
				} else CreateDialog(playerid,DIALOG_REGISTER_GENDER,"{ff557a} (Error)"); 
			} else {
				SFM(playerid,msgWarning,"Going To Prevoius Step (Register: Verify Age)");
				CreateDialog(playerid,DIALOG_REGISTER_AGE);
			}
		}
		case DIALOG_REGISTER_EMAIL: {
			if(response) {
				new tmpstrs[50];
				if(!strlen(inputtext)) format(tmpstrs,sizeof tmpstrs,"\n\nPlease Enter Your Email Or For Skipping This Step Please Enter [skip] !");
				else if(strcmp(inputtext,"skip",true,0) != -1) return OnPlayerRegisterLevel(playerid,5,"");
				else if(strlen(inputtext) < 5) format(tmpstrs,sizeof tmpstrs,"\n\nYour Email Must At Least Be 6 Characters !");
				else if(strlen(inputtext) > 50) format(tmpstrs,sizeof tmpstrs,"\n\nMaximum Length Is 50 Characters !");
				else if(strfind(inputtext,"@") == -1) format(tmpstrs,sizeof tmpstrs,"\n\nInvalid Email Format, Email Must Have @ In It !\nExample: Support@shadow.com");
				else if(strfind(inputtext,".") == -1) format(tmpstrs,sizeof tmpstrs,"\n\nInvalid Email Format, Email Must Have . In It !\nExample: Support@shadow.com");
				else {
					OnPlayerRegisterLevel(playerid,5,inputtext);
				} 
				if(strlen(tmpstrs)) return CreateDialog(playerid,DIALOG_REGISTER_EMAIL,"{ff557a} (Error)",tmpstrs);
			} else {
				SFM(playerid,msgWarning,"Going To Prevoius Step (Register: Select Gender)");
				CreateDialog(playerid,DIALOG_REGISTER_GENDER);
			}
		}
		case DIALOG_REGISTER_REFERRAL: {
			if(response) {
				
			} else {
				SFM(playerid,msgWarning,"Going To Prevoius Step (Register: Enter Email)");
				CreateDialog(playerid,DIALOG_REGISTER_GENDER);
			}
		}
	}
	return 1;
}

public OnPlayerClickPlayer(playerid, clickedplayerid, source)
{
	return 1;
}
//==========-------------==========//


//========---- COMMANDS ----========//
//==========-------------==========//


//========---- ADMIN COMMANDS ----========//
CMD:alogin(playerid,params[]) {
	new tmpcmdid = GetCommandID("alogin");
	if(tmpcmdid == -1) return SFM(playerid,msgError,"Command Not Found In Database, Please Contact Administrator");
	if(PlayerInfo[playerid][pAdminLogin] == true) return SFM(playerid,msgError,"You're Already Authorized !");

	new tmpcode[10];
	// if(sscanf(params,"s[10]",tmpcode)) return SFM(playerid,msgInfo,"U:/alogin [code]");
	if(sscanf(params,Commands[tmpcmdid][cmdFormat],tmpcode)) return SFM(playerid,msgError,"Command Ussage Incorrect, /%s %s",Commands[tmpcmdid][cmdName],Commands[tmpcmdid][cmdSyntax]);
	else if(strlen(tmpcode) < 6 || strlen(tmpcode) > 8) return SFM(playerid,msgError,"Admin-Code Must Have 6-Digits At Least Or 8-Digits At Last");
	else {
		if(PlayerInfo[playerid][pAdminAttempts] >= MAX_ADMIN_ATTEMPTS) return KickPlayerEx(playerid,"Username [%s] Have Tryied So Many Time For Admin-Login");
		else if(strval(tmpcode) != PlayerInfo[playerid][pAdminCode]) {
			PlayerInfo[playerid][pAdminAttempts] ++;
			return SFM(playerid,msgError,"Incorrect Admin-Code [Attempts %d/%d]",PlayerInfo[playerid][pAdminAttempts],MAX_ADMIN_ATTEMPTS);
		} else {
			PlayerInfo[playerid][pAdminLogin] = true;
			SFM(playerid,msgAdmin,"Your Rank Successfully Authenticated");
		}
	}
	return 1;
}
CMD:alogout(playerid,params[]) {
	if(PlayerInfo[playerid][pAdminLogin] == true) {
		PlayerInfo[playerid][pAdminLogin] = false;
		SFM(playerid,msgAdmin,"You're Logged Out From Admin-Auth");
	} else {
		SFM(playerid,msgError,"You're Not Logged IN !");
	}
	return 1;
}
CMD:amake(playerid,params[]) {
	// if(PlayerInfo[playerid][pAdminLevel] < 1) return SFM(playerid,msgAdmin,"You're not An Admin Of This Server");
	// else if(PlayerInfo[playerid][pAdminLevel] < 11) return SFM(playerid,msgAdmin,"You're not In MGMT-Admin Team Of This Server");
	new tmpcmdid = GetCommandID("amake");
	if(tmpcmdid == -1) return SFM(playerid,msgError,"Command Not Found In Database, Please Contact Administrator");


	new tmpid,tmplevel;
	// if(sscanf(params,"ri",tmpid,tmplevel)) return SFM(playerid,msgInfo,"U:/amake [Player Name/ID] [Level | 0:Demote]");
	if(sscanf(params,Commands[tmpcmdid][cmdFormat],tmpid,tmplevel)) return SFM(playerid,msgError,"Command Ussage Incorrect, /%s %s",Commands[tmpcmdid][cmdName],Commands[tmpcmdid][cmdSyntax]);
	else if(tmpid == INVALID_PLAYER_ID) return SFM(playerid,msgError,"Player Is Not Connected To The Server");
	else if(tmplevel == 0) {
		PlayerInfo[tmpid][pAdminLevel] = 0;
		PlayerInfo[tmpid][pAdminCode] = 0;
		PlayerInfo[tmpid][pAdminBPoints] = 0;
		PlayerInfo[tmpid][pAdminLogin] = false;
		new tmpquery[100];
		mysql_format(mysql,tmpquery,sizeof tmpquery,"delete from admins where username='%s'",PlayerInfo[tmpid][pUsername]);
		mysql_tquery(mysql,tmpquery,"","");
		SFM(playerid,msgAdmin,"You Make [%s] Demote Of Administrator !",GetName(tmpid));
		SFM(tmpid,msgAdmin,"Your Rank Have Been Demoted By Admin [%s]",GetName(playerid));
	} else if(tmplevel > 0) {
		PlayerInfo[tmpid][pAdminLevel] = tmplevel;
		PlayerInfo[tmpid][pAdminCode] = 123456;
		PlayerInfo[tmpid][pAdminBPoints] = 0;
		new tmpquery[100];
		mysql_format(mysql,tmpquery,sizeof tmpquery,"insert into admins (username,level,code) value ('%s','%d','123456')",PlayerInfo[tmpid][pUsername],tmplevel);
		mysql_tquery(mysql,tmpquery,"","");
		SFM(playerid,msgAdmin,"You Make [%s] Admin Of Server, Authorized With Level [%s]",GetName(tmpid),GetAdminName(tmplevel));
		SFM(tmpid,msgAdmin,"You're Now Admin Of Server By [%s], And Obtain Rank [%s]",GetName(playerid),GetAdminName(tmplevel));
		SFM(tmpid,msgAdmin,"Your Admin-Code Is Set To [123456] By Default, First Use /alogin And Then Use /achcode [123456] [New Code]");
	}
	return 1;
}
CMD:achcode(playerid,params[]) {
	// if(PlayerInfo[playerid][pAdminLevel] < 1) return SFM(playerid,msgAdmin,"You're not An Admin Of This Server");
	// else if(PlayerInfo[playerid][pAdminLogin] != true) return SFM(playerid,msgAdmin,"Your Admin Rank Is Not Authorized Yet");
	new tmpcmdid = GetCommandID("achcode");
	if(tmpcmdid == -1) return SFM(playerid,msgError,"Command Not Found In Database, Please Contact Administrator");

	new tmpcode1[10],tmpcode2[10];
	// if(sscanf(params,"s[10]s[10]",tmpcode1,tmpcode2)) return SFM(playerid,msgInfo,"U:/achcode [current code] [new code]");
	if(sscanf(params,Commands[tmpcmdid][cmdFormat],tmpcode1,tmpcode2)) return SFM(playerid,msgError,"Command Ussage Incorrect, /%s %s",Commands[tmpcmdid][cmdName],Commands[tmpcmdid][cmdSyntax]);
	else if(strlen(tmpcode1) < 6 || strlen(tmpcode1) > 8) return SFM(playerid,msgError,"Admin-Code Must Have 6-Digits At Least Or 8-Digits At Last");
	else if(strlen(tmpcode2) < 6 || strlen(tmpcode2) > 8) return SFM(playerid,msgError,"Admin-Code Must Have 6-Digits At Least Or 8-Digits At Last");
	else {
		if(PlayerInfo[playerid][pAdminAttempts] >= MAX_ADMIN_ATTEMPTS) return KickPlayerEx(playerid,"Username [%s] Have Tryied So Many Time For Admin-Login");
		else if(strval(tmpcode1) != PlayerInfo[playerid][pAdminCode]) {
			PlayerInfo[playerid][pAdminAttempts] ++;
			return SFM(playerid,msgError,"Incorrect Admin-Code [Attempts %d/%d]",PlayerInfo[playerid][pAdminAttempts],MAX_ADMIN_ATTEMPTS);
		} else {
			// PlayerInfo[playerid][pAdminLogin] = true;
			PlayerInfo[playerid][pAdminCode] = strval(tmpcode2);
			SavePlayerAData(playerid,"code","%d",strval(tmpcode2));
			SFM(playerid,msgAdmin,"Your Admin-Code Successfully Changed To [%d]",strval(tmpcode2));
		}
	}
	return 1;
}
cmd:asetoo(playerid,params[]) {
	return 1;
}
cmd:asetclock(playerid,params[]) {
	return 1;
}
//==========-------------==========//