//========---- INCLUDE ----========//
#include 				<a_samp>
#include 				<a_mysql>
// #include 			<sqlitei>
#include 				<Pawn.CMD>
#include				<sscanf2>
// YSI
#include 				<YSI_Coding/y_va>
//==========-------------==========//


//========---- DEFINES ----========//
// MAX PLAYERS
#if defined MAX_PLAYERS
#undef MAX_PLAYERS
#endif
#define MAX_PLAYERS			200
#define MAX_DIALOGS 		12000
#define MAX_LOGIN_ATTEMPTS 	5
#define MAX_COMMANDS 		2000
// defination of function
#define function%0(%1) forward %0(%1);public %0(%1)
// mysql var
#define SQL_HOST 			"localhost"
#define SQL_USER 			"root"
#define SQL_PASS 			""
#define SQL_DATA 			"shadowteam"
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
	DIALOG_ADMIN_CHANGECODE
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

	{DIALOG_STYLE_PASSWORD,	"[ShadowTeam] Admin (Login)","Please Enter Your Admin Code To Verify That You're And Authurized Admin By Owner !","Login","Cnacel"},
	{DIALOG_STYLE_INPUT,	"[ShadowTeam] Admin (ChangeCode)","Please Enter Your New Code","Change","Cancel"}
};

new MySQL:mysql;

enum cmdInfo {
	cmdID,
	cmdText[20],
	cmdArgs[50],
	cmdParams[20],
	cmdDesc[256],
	cmdLock,
	cmdOOnly,
	cmdAdmin,
	cmdAuth
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
	pAdminLogin,
	pGender,
	pAge,
	pBan,
	pBanip[50],
	pIp[50],
	pReferral[50],

	// In-Game (cache)
	bool:pLogged,
	bool:pSpawned,
	pFName[50],
	pLoginAttempts,
	pALoginAttemtps
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
	SetTimerEx("Kick",1000,false,"i",playerid);
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
	PlayerInfo[playerid][pAdminLogin] = 0;
	PlayerInfo[playerid][pAdminCode] = 0;
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

	return 1;
}
stock SavePlayerDatas(playerid) {
	SavePlayerData(playerid,"ip","%s",GetIP(playerid));
	return 1;
}

new adminlevel_names[][] = {
	"NON-ADMIN",
	"Admin (1)",
	"Admin (2)",
	"Admin (3)",
	"Admin (4)",
	"Admin (Head)",
	"Host (1)",
	"Host (2)",
	"MGMT (Supervisor)",
	"MGMT (Manager)",
	"MGMT (Founder)",
	"DEV (Configer)",
	"DEV (Scripter)",
	"Owner (EPSILON)"
}

stock GetAdminName(level) {
	if(level >= 0 && level < sizeof(adminlevel_names)) return adminlevel_names[level];
	else return 0;
}
//==========-------------==========//


//========---- CMD CONFIG ----========//
stock GetCommandIndex(cmdtext[]) {
	output = 0;founded = 0;
	for(new x;x<MAX_COMMANDS;x++) {
		if(strlen(Commands[x][cmdText]) == strlen(cmdtext) && strcmp(cmdtext,Commands[x][cmdText],true) == 0) {
			founded = 1;output = x;break;
		}
	}
	if(founded == 1) return output;
	else return -1;
}
public OnPlayerCommandReceived(playerid, cmd[], params[], flags) {
	new tmpidx = GetCommandIndex(cmd),tmpfound = (tmpidx != 1) ? 1:0;
	// for(new x=0;x<MAX_COMMANDS;x++) {
	// 	if(strlen(Commands[x][cmdText]) == strlen(cmd) && strcmp(cmd,Commands[x][cmdText],true) == 0) {
	// 		tmpfound = 1;tmpidx = x;break;
	// 	}
	// }
	if(tmpfound == 1) {
		if(Commands[tmpidx][cmdLock] == 1) return SFM(playerid,msgError,"This Command Is Locked By Server Developer");
		else if(Commands[tmpidx][cmdOOnly] == 1) return SFM(playerid,msgError,"This Command Is Flagged As (OwnerOnly)");
		else if(Commands[tmpidx][cmdAdmin] > 0) {
			if(Commands[tmpidx][cmdAuth] == 1 && PlayerInfo[playerid][pAdminLogin] != 1) return SFM(playerid,msgError,"To Use This Command You Must Auth Your AdminLevel First Using /adminlogin [code]");
			else if(PlayerInfo[playerid][pAdminLevel] < 0) return SFM(playerid,msgError,"You're Not An Admin Of Server !");
			else if(PlayerInfo[playerid][pAdminLevel] < Commands[tmpidx][cmdAdmin]) return SFM(playerid,msgError,"You're Not Authorized To Use This Command!");
		}
	} else return SFM(playerid,msgError,"Command [%s] Is Not Founded Or Its Not-Registered Yet !",cmd);
	return 1;
}
public OnPlayerCommandPerformed(playerid, cmd[], params[], result, flags) {
	if(!result) return SFM(playerid,msgError,"Command Does Not Work, Please Consider Using Right Arguments In Call Time");
	return 1;
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


	// cmds
	tmpcache = mysql_query(mysql,"select * from cmds order by id asc");
	cache_get_row_count(idxs);
	printf("[ShadowTeam] Total Server Commands [-%d-]",idxs);
	
	// delete the cache
	cache_delete(tmpcache);
	printf("\\============================/");
	return 1;
}

function LoadServerCommands() {

	for(new x;x<MAX_COMMANDS;x++) {
		Commands[x][cmdID] = 0;
		Commands[x][cmdText] = 0;
		Commands[x][cmdArgs] = 0;
		Commands[x][cmdParams] = 0;
		Commands[x][cmdDesc] = 0;
		Commands[x][cmdLock] = 0;
		Commands[x][cmdOOnly] = 0;
		Commands[x][cmdAdmin] = 0;
		Commands[x][cmdAuth] = 0;
	}

	new tmpidx=0;
	new Cache:tmpcache = mysql_query(mysql,"select * from cmds order by id asc");
	cache_get_row_count(tmpidx);
	if(tmpidx) {
		for(new x=0;x<tmpidx;x++) {
			cache_get_value_int(x,"id",Commands[x][cmdID]);
			cache_get_value(x,"text",Commands[x][cmdText],20);
			cache_get_value(x,"args",Commands[x][cmdArgs],50);
			cache_get_value(x,"params",Commands[x][cmdParams],20);
			cache_get_value(x,"description",Commands[x][cmdDesc],150);
			cache_get_value_int(x,"ulock",Commands[x][cmdLock]);
			cache_get_value_int(x,"olock",Commands[x][cmdOOnly]);
			cache_get_value_int(x,"admin",Commands[x][cmdAdmin]);
			cache_get_value_int(x,"auth",Commands[x][cmdAuth]);
		}
	}
	cache_delete(tmpcache);
	return 1;
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
	format(query,sizeof query,"update users set %s='%e' where id='%d'",tmpcolumn,va_return(tmpvalue,___(3)),PlayerInfo[playerid][pID]);
	if (PlayerInfo[playerid][pLogged]) mysql_tquery(mysql,query,"","");
	return 1;
}

function CheckUsername(playerid,username[]) {
	new idx,tmpstr[128];
	mysql_format(mysql,tmpstr,sizeof tmpstr,"select * from users where username='%e'",username);
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
		cache_get_value_int(0,		"adminlevel",PlayerInfo[playerid][pAdminLevel]);
		cache_get_value_int(0,		"admincode",PlayerInfo[playerid][pAdminCode]);
		cache_get_value_int(0,		"gender",PlayerInfo[playerid][pGender]);
		cache_get_value_int(0,		"age",PlayerInfo[playerid][pAge]);
	} else {
		// invalid password
		if(PlayerInfo[playerid][pLoginAttempts] == MAX_LOGIN_ATTEMPTS) KickPlayerEx(playerid,"Login Attempt Reach its Limit, Please Join Other Times");
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
		if(PlayerInfo[playerid][pAdminLevel] > 0) SFM(playerid,msgAdmin,"You're An Admin Of Server Please Use /adminlogin [code] For Auth Your AdminLevel");

		SetPlayerName(playerid,PlayerInfo[playerid][pName]);
		SetSpawnInfo(playerid,0,0,103.3730,-221.5822,1.5840,229.8285,0,0,0,0,0,0);
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


	LoadServerCommands();
	LoadDatabase();
	
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
CMD:hello(playerid,params[]) {
	SFM(playerid,cmdAdmin,"Hello");
}
//==========-------------==========//


//========---- ADMIN COMMANDS ----========//
CMD:adminlogin(playerid,params[]) {
	new tmpidx = GetCommandIndex("adminlogin");new tmpcode;
	if(sscanf(params,Commands[tmpidx][cmdParams],tmpcode)) {
		return CreateDialog(playerid,DIALOG_ADMIN_LOGIN);
	} else if(tmpcode < 1000) return SFM(playerid,cmdError,"AdminCode Must Be In Range of 4 To 6 Digits, If Its Upper Or Lower, Please Contact Developers");
	else if(tmpcode != PlayerInfo[playerid][pAdminCode]) return SFM(playerid,msgError,"Giving Code Is Not Matching With Database, Incorrect Admin Login Code");
	else {
		PlayerInfo[playerid][pAdminLogin] = 1;
		SFM(playerid,msgAdmin,"Successfull, You're Level Authorized As [%s], Enjoy",GetAdminName(PlayerInfo[playerid][pAdminLevel]));
	}
	return 1;
}
CMD:adminlogout(playerid,params[]) {
	PlayerInfo[playerid][pAdminLogin] = 0;
	SFM(playerid,msgAdmin,"Successfully Logout From Admin-Auth");
	return 1;
}
CMD:ahelp(playerid,params[]) {
	return 1;
}
CMD:apanel(playerid,params[]) {
	return 1;
}
CMD:achcode(playerid,params[]) {
	return 1;
}
CMD:achlevel(playerid,params[]) {
	return 1;
}
CMD:amkadmin(playerid,params[]) {
	return 1;
}
CMD:armadmin(playerid,params[]) {
	return 1;
}
//==========-------------==========//