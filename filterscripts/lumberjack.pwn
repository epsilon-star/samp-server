#define 	FILTERSCRIPT
#include 	<a_samp>
#include    <evf>           // by Emmet_ - http://forum.sa-mp.com/showthread.php?t=486060
#include 	<evi>
#include    <izcmd>         // by Yashas - http://forum.sa-mp.com/showthread.php?t=576114
#include    <progress2>     // by [HLF]Southclaw - http://forum.sa-mp.com/showthread.php?t=537468
#include    <sqlitei>       // by Slice - http://forum.sa-mp.com/showthread.php?t=303682
#include    <sscanf2>       // by Y_Less - http://forum.sa-mp.com/showthread.php?t=602923
#include    <streamer>      // by Incognito - http://forum.sa-mp.com/showthread.php?t=102865
#include    <YSI_Data\y_iterate> // by Y_Less - http://forum.sa-mp.com/showthread.php?t=570884

#define     MAX_TREES       (100)   // tree limit
#define     MAX_LOGS        (300)   // dropped log limit
#define     MAX_BUYERS      (20)    // log buyer limit

#define     CUTTING_TIME    (8)		// required seconds to cut a tree down (Default: 8)
#define     LOG_LIMIT     	(10)    // how many logs a player can load to a bobcat (if you change this, don't forget to modify LogAttachOffsets array) (Default: 10)
#define     ATTACH_INDEX    (7)     // for setplayerattachedobject (Default: 7)
#define     TREE_RESPAWN    (300)   // required seconds to respawn a tree (Default: 300)
#define     LOG_LIFETIME	(120)   // life time of a dropped log, in seconds (Default: 120)
#define     LOG_PRICE       (50)    // price of a log (Default: 50)
#define     CSAW_PRICE      (500)  	// price of a chainsaw (Default: 500)

#pragma warning disable 219

enum    E_TREE
{
	// loaded from db
	Float: treeX,
	Float: treeY,
	Float: treeZ,
	Float: treeRX,
	Float: treeRY,
	Float: treeRZ,
	// temp
	treeLogs,
	treeSeconds,
	bool: treeGettingCut,
	treeObjID,
	Text3D: treeLabel,
	treeTimer
}

enum    E_LOG
{
	// temp
	logDroppedBy[MAX_PLAYER_NAME],
	logSeconds,
	logObjID,
	logTimer,
	Text3D: logLabel
}

enum    E_BUYER
{
	// loaded from db
	buyerSkin,
	Float: buyerX,
	Float: buyerY,
	Float: buyerZ,
	Float: buyerA,
	// temp
	buyerActorID,
	Text3D: buyerLabel
}

new
	TreeData[MAX_TREES][E_TREE],
	LogData[MAX_LOGS][E_LOG],
	BuyerData[MAX_BUYERS][E_BUYER];
	
new
	Iterator: Trees<MAX_TREES>,
	Iterator: Logs<MAX_LOGS>,
	Iterator: Buyers<MAX_BUYERS>;

new
	LogObjects[MAX_VEHICLES][LOG_LIMIT];
	
new
	CuttingTreeID[MAX_PLAYERS] = {-1, ...},
	CuttingTimer[MAX_PLAYERS] = {-1, ...},
	PlayerBar: CuttingBar[MAX_PLAYERS] = {INVALID_PLAYER_BAR_ID, ...},
	bool: CarryingLog[MAX_PLAYERS],
	EditingTreeID[MAX_PLAYERS] = {-1, ...};

new
	Float: LogAttachOffsets[LOG_LIMIT][4] = {
	    {-0.223, -1.089, -0.230, -90.399},
		{-0.056, -1.091, -0.230, 90.399},
		{0.116, -1.092, -0.230, -90.399},
		{0.293, -1.088, -0.230, 90.399},
		{-0.123, -1.089, -0.099, -90.399},
		{0.043, -1.090, -0.099, 90.399},
		{0.216, -1.092, -0.099, -90.399},
		{-0.033, -1.090, 0.029, -90.399},
		{0.153, -1.089, 0.029, 90.399},
		{0.066, -1.091, 0.150, -90.399}
	};

new
	DB: ScriptDBHandle;

new
	DBStatement: LoadTrees,
	DBStatement: AddTree,
	DBStatement: UpdateTree,
	DBStatement: RemoveTree;
	
new
	DBStatement: LoadBuyers,
	DBStatement: AddBuyer,
	DBStatement: UpdateBuyer,
	DBStatement: RemoveBuyer;

SetPlayerLookAt(playerid, Float:x, Float:y)
{
	// somewhere on samp forums, couldn't find the source
	new Float:Px, Float:Py, Float: Pa;
	GetPlayerPos(playerid, Px, Py, Pa);
	Pa = floatabs(atan((y-Py)/(x-Px)));
	if (x <= Px && y >= Py) Pa = floatsub(180, Pa);
	else if (x < Px && y < Py) Pa = floatadd(Pa, 180);
	else if (x >= Px && y <= Py) Pa = floatsub(360.0, Pa);
	Pa = floatsub(Pa, 90.0);
	if (Pa >= 360.0) Pa = floatsub(Pa, 360.0);
	SetPlayerFacingAngle(playerid, Pa);
}

stock GetNearestVehicle(playerid)
{
	new Float: xpos[3];
	new tidx = -1;
	foreach(new ix : Vehicle)
	{
		if(ix == INVALID_VEHICLE_ID) continue;
		GetVehiclePos(ix,xpos[0],xpos[1],xpos[2]);
		if(IsPlayerInRangeOfPoint(playerid,2.0,xpos[0],xpos[1],xpos[2]))
		{
			tidx = ix; break;
		}
	}
	return tidx;
}

ConvertToMinutes(time)
{
    // http://forum.sa-mp.com/showpost.php?p=3223897&postcount=11
    new string[15];//-2000000000:00 could happen, so make the string 15 chars to avoid any errors
    format(string, sizeof(string), "%02d:%02d", time / 60, time % 60);
    return string;
}

GetClosestTree(playerid, Float: range = 2.0)
{
	new tidx = -1, Float: dist = range, Float: tempdist;
	foreach(new ix : Trees)
	{
	    tempdist = GetPlayerDistanceFromPoint(playerid, TreeData[ix][treeX], TreeData[ix][treeY], TreeData[ix][treeZ]);

	    if(tempdist > range) continue;
		if(tempdist <= dist)
		{
			dist = tempdist;
			tidx = ix;
		}
	}

	return tidx;
}

GetClosestLog(playerid, Float: range = 2.0)
{
	new tidx = -1, Float: dist = range, Float: tempdist, Float: pos[3];
	foreach(new ix : Logs)
	{
		GetDynamicObjectPos(LogData[ix][logObjID], pos[0], pos[1], pos[2]);
	    tempdist = GetPlayerDistanceFromPoint(playerid, pos[0], pos[1], pos[2]);

	    if(tempdist > range) continue;
		if(tempdist <= dist)
		{
			dist = tempdist;
			tidx = ix;
		}
	}

	return tidx;
}

IsPlayerNearALogBuyer(playerid)
{
	foreach(new i : Buyers)
	{
	    if(IsPlayerInRangeOfPoint(playerid, 2.0, BuyerData[i][buyerX], BuyerData[i][buyerY], BuyerData[i][buyerZ])) return 1;
	}
	
	return 0;
}

Player_Init(playerid)
{
    CuttingTreeID[playerid] = -1;
    CuttingTimer[playerid] = -1;
	CarryingLog[playerid] = false;
    EditingTreeID[playerid] = -1;
    
    CuttingBar[playerid] = CreatePlayerProgressBar(playerid, 498.0, 104.0, 113.0, 6.2, 0x61381BFF, CUTTING_TIME, BAR_DIRECTION_RIGHT);
    ApplyAnimation(playerid, "CHAINSAW", "null", 0.0, 0, 0, 0, 0, 0, 0);
    ApplyAnimation(playerid, "CARRY", "null", 0.0, 0, 0, 0, 0, 0, 0);
	return 1;
}

Player_ResetCutting(playerid)
{
	if(!IsPlayerConnected(playerid) || CuttingTreeID[playerid] == -1) return 0;
	new tidx = CuttingTreeID[playerid];
	TreeData[tidx][treeGettingCut] = false;
	if(TreeData[tidx][treeSeconds] < 1) Streamer_SetIntData(STREAMER_TYPE_3D_TEXT_LABEL, TreeData[tidx][treeLabel], E_STREAMER_COLOR, 0x2ECC71FF);
	
	ClearAnimations(playerid);
    TogglePlayerControllable(playerid, 1);
    CuttingTreeID[playerid] = -1;
    
    if(CuttingTimer[playerid] != -1)
	{
	    KillTimer(CuttingTimer[playerid]);
		CuttingTimer[playerid] = -1;
	}
	
	SetPlayerProgressBarValue(playerid, CuttingBar[playerid], 0.0);
	HidePlayerProgressBar(playerid, CuttingBar[playerid]);
	return 1;
}

Player_GiveLog(playerid)
{
    if(!IsPlayerConnected(playerid)) return 0;
	CarryingLog[playerid] = true;
	SetPlayerSpecialAction(playerid, SPECIAL_ACTION_CARRY);
	SetPlayerAttachedObject(playerid, ATTACH_INDEX, 19793, 6, 0.077999, 0.043999, -0.170999, -13.799953, 79.70, 0.0);
	
	SendClientMessage(playerid, 0x3498DBFF, "LUMBERJACK: {FFFFFF}You can press {F1C40F}~k~~CONVERSATION_NO~ {FFFFFF}to drop your log.");
	return 1;
}

Player_DropLog(playerid, death_drop = 0)
{
    if(!IsPlayerConnected(playerid) || !CarryingLog[playerid]) return 0;
    new tidx = Iter_Free(Logs);
    if(tidx != -1)
    {
        new Float: x, Float: y, Float: z, Float: a, label[128];
        GetPlayerPos(playerid, x, y, z);
        GetPlayerFacingAngle(playerid, a);
        GetPlayerName(playerid, LogData[tidx][logDroppedBy], MAX_PLAYER_NAME);

		if(!death_drop)
		{
		    x += (1.0 * floatsin(-a, degrees));
			y += (1.0 * floatcos(-a, degrees));
			
			ApplyAnimation(playerid, "CARRY", "putdwn05", 4.1, 0, 1, 1, 0, 0, 1);
		}

		LogData[tidx][logSeconds] = LOG_LIFETIME;
		LogData[tidx][logObjID] = CreateDynamicObject(19793, x, y, z - 0.9, 0.0, 0.0, a);
		
		format(label, sizeof(label), "Log (%d)\n\n{FFFFFF}Dropped By {F1C40F}%s\n{FFFFFF}%s\nUse {F1C40F}/log take {FFFFFF}to take it.", tidx, LogData[tidx][logDroppedBy], ConvertToMinutes(LOG_LIFETIME));
		LogData[tidx][logLabel] = CreateDynamic3DTextLabel(label, 0xF1C40FFF, x, y, z - 0.7, 5.0, .testlos = 1);
		
		LogData[tidx][logTimer] = SetTimerEx("RemoveLog", 1000, true, "i", tidx);
		Iter_Add(Logs, tidx);
    }
    
    Player_RemoveLog(playerid);
	return 1;
}

Player_RemoveLog(playerid)
{
	if(!IsPlayerConnected(playerid) || !CarryingLog[playerid]) return 0;
	RemovePlayerAttachedObject(playerid, ATTACH_INDEX);
	SetPlayerSpecialAction(playerid, SPECIAL_ACTION_NONE);
	CarryingLog[playerid] = false;
	return 1;
}

Vehicle_LogCount(vehicleid)
{
	if(GetVehicleModel(vehicleid) == 0) return 0;
	new count;
	for(new i; i < LOG_LIMIT; i++) if(IsValidDynamicObject(LogObjects[vehicleid][i])) count++;
	return count;
}

Vehicle_RemoveLogs(vehicleid)
{
    if(GetVehicleModel(vehicleid) == 0) return 0;
    for(new i; i < LOG_LIMIT; i++)
	{
	    if(IsValidDynamicObject(LogObjects[vehicleid][i]))
	    {
	        DestroyDynamicObject(LogObjects[vehicleid][i]);
	        LogObjects[vehicleid][i] = -1;
	    }
	}
	
	return 1;
}

Tree_BeingEdited(tidx)
{
	if(!Iter_Contains(Trees, tidx)) return 0;
	foreach(new i : Player) if(EditingTreeID[i] == tidx) return 1;
	return 0;
}

Tree_UpdateLogLabel(tidx)
{
    if(!Iter_Contains(Trees, tidx)) return 0;
    new label[96];
    
    if(TreeData[tidx][treeLogs] > 0) {
	    format(label, sizeof(label), "Tree (%d)\n\n{FFFFFF}Logs: {F1C40F}%d\n{FFFFFF}Use {F1C40F}/log takefromtree {FFFFFF}to take a log.", tidx, TreeData[tidx][treeLogs]);
		UpdateDynamic3DTextLabelText(TreeData[tidx][treeLabel], 0xE74C3CFF, label);
	}else{
	    TreeData[tidx][treeTimer] = SetTimerEx("RespawnTree", 1000, true, "i", tidx);
	    
	    format(label, sizeof(label), "Tree (%d)\n\n{FFFFFF}%s", tidx, ConvertToMinutes(TreeData[tidx][treeSeconds]));
		UpdateDynamic3DTextLabelText(TreeData[tidx][treeLabel], 0xE74C3CFF, label);
	}
	
	return 1;
}

public OnFilterScriptInit()
{
    print("  [Lumberjack] Initializing...");
    
    // assign default values to variables
	for(new i; i < MAX_TREES; i++)
	{
		TreeData[i][treeObjID] = TreeData[i][treeTimer] = -1;
		TreeData[i][treeLabel] = Text3D: -1;
	}
	
	for(new i; i < MAX_LOGS; i++)
	{
	    LogData[i][logObjID] = LogData[i][logTimer] = -1;
	    LogData[i][logLabel] = Text3D: -1;
	}
	
	for(new i; i < MAX_BUYERS; i++)
	{
	    BuyerData[i][buyerActorID] = -1;
	    BuyerData[i][buyerLabel] = Text3D: -1;
	}
	
	for(new i; i < MAX_VEHICLES; i++) for(new x; x < LOG_LIMIT; x++) LogObjects[i][x] = -1;
	
	foreach(new i : Player) Player_Init(i);
	
	// open database & create tables
	ScriptDBHandle = db_open("lumberjack.db");
	db_query(ScriptDBHandle, "CREATE TABLE IF NOT EXISTS trees (tidx INTEGER, PosX FLOAT, PosY FLOAT, PosZ FLOAT, RotX FLOAT, RotY FLOAT, RotZ FLOAT)");
	db_query(ScriptDBHandle, "CREATE TABLE IF NOT EXISTS buyers (tidx INTEGER, Skin INTEGER, PosX FLOAT, PosY FLOAT, PosZ FLOAT, PosA FLOAT)");
	
	// prepare tree queries
	LoadTrees = db_prepare(ScriptDBHandle, "SELECT * FROM trees");
	AddTree = db_prepare(ScriptDBHandle, "INSERT INTO trees (tidx, PosX, PosY, PosZ, RotX, RotY, RotZ) VALUES (?, ?, ?, ?, ?, ?, ?)");
    UpdateTree = db_prepare(ScriptDBHandle, "UPDATE trees SET PosX=?, PosY=?, PosZ=?, RotX=?, RotY=?, RotZ=? WHERE tidx=?");
	RemoveTree = db_prepare(ScriptDBHandle, "DELETE FROM trees WHERE tidx=?");
	
	// prepare buyer queries
	LoadBuyers = db_prepare(ScriptDBHandle, "SELECT * FROM buyers");
	AddBuyer = db_prepare(ScriptDBHandle, "INSERT INTO buyers (tidx, Skin, PosX, PosY, PosZ, PosA) VALUES (?, ?, ?, ?, ?, ?)");
    UpdateBuyer = db_prepare(ScriptDBHandle, "UPDATE buyers SET Skin=?, PosX=?, PosY=?, PosZ=?, PosA=? WHERE tidx=?");
	RemoveBuyer = db_prepare(ScriptDBHandle, "DELETE FROM buyers WHERE tidx=?");
	
	// load trees
	new tidx, Float: pos[3], Float: rot[3];
	stmt_bind_result_field(LoadTrees, 0, DB::TYPE_INTEGER, tidx);
	stmt_bind_result_field(LoadTrees, 1, DB::TYPE_FLOAT, pos[0]);
	stmt_bind_result_field(LoadTrees, 2, DB::TYPE_FLOAT, pos[1]);
	stmt_bind_result_field(LoadTrees, 3, DB::TYPE_FLOAT, pos[2]);
	stmt_bind_result_field(LoadTrees, 4, DB::TYPE_FLOAT, rot[0]);
	stmt_bind_result_field(LoadTrees, 5, DB::TYPE_FLOAT, rot[1]);
	stmt_bind_result_field(LoadTrees, 6, DB::TYPE_FLOAT, rot[2]);

	if(stmt_execute(LoadTrees))
	{
	    print("  [Lumberjack] Loading trees...");

	    new label[96];
	    while(stmt_fetch_row(LoadTrees))
	    {
            TreeData[tidx][treeX] = pos[0];
		 	TreeData[tidx][treeY] = pos[1];
		  	TreeData[tidx][treeZ] = pos[2];
	        TreeData[tidx][treeRX] = rot[0];
		 	TreeData[tidx][treeRY] = rot[1];
		  	TreeData[tidx][treeRZ] = rot[2];

		    TreeData[tidx][treeObjID] = CreateDynamicObject(657, TreeData[tidx][treeX], TreeData[tidx][treeY], TreeData[tidx][treeZ], TreeData[tidx][treeRX], TreeData[tidx][treeRY], TreeData[tidx][treeRZ]);
			
			format(label, sizeof(label), "Tree (%d)\n\n{FFFFFF}Press {F1C40F}~k~~CONVERSATION_NO~ {FFFFFF}to cut down.", tidx);
			TreeData[tidx][treeLabel] = CreateDynamic3DTextLabel(label, 0x2ECC71FF, TreeData[tidx][treeX], TreeData[tidx][treeY], TreeData[tidx][treeZ] + 1.5, 5.0);

			Iter_Add(Trees, tidx);
		}

		printf("  [Lumberjack] Loaded %d trees.", Iter_Count(Trees));
	}
	
	// load buyers
	new skin, Float: bpos[4];
	stmt_bind_result_field(LoadBuyers, 0, DB::TYPE_INTEGER, tidx);
	stmt_bind_result_field(LoadBuyers, 1, DB::TYPE_INTEGER, skin);
	stmt_bind_result_field(LoadBuyers, 2, DB::TYPE_FLOAT, bpos[0]);
	stmt_bind_result_field(LoadBuyers, 3, DB::TYPE_FLOAT, bpos[1]);
	stmt_bind_result_field(LoadBuyers, 4, DB::TYPE_FLOAT, bpos[2]);
	stmt_bind_result_field(LoadBuyers, 5, DB::TYPE_FLOAT, bpos[3]);

	if(stmt_execute(LoadBuyers))
	{
	    print("  [Lumberjack] Loading buyers...");

	    new label[172];
	    while(stmt_fetch_row(LoadBuyers))
	    {
            BuyerData[tidx][buyerSkin] = skin;
		 	BuyerData[tidx][buyerX] = bpos[0];
		  	BuyerData[tidx][buyerY] = bpos[1];
	        BuyerData[tidx][buyerZ] = bpos[2];
		 	BuyerData[tidx][buyerA] = bpos[3];

		    BuyerData[tidx][buyerActorID] = CreateActor(BuyerData[tidx][buyerSkin], BuyerData[tidx][buyerX], BuyerData[tidx][buyerY], BuyerData[tidx][buyerZ], BuyerData[tidx][buyerA]);
            SetActorInvulnerable(BuyerData[tidx][buyerActorID], 1);

			format(label, sizeof(label), "Log Buyer (%d)\n\n{FFFFFF}Use {F1C40F}/chainsaw {FFFFFF}to buy a chainsaw for {2ECC71}$%d.\n{FFFFFF}Use {F1C40F}/log sell {FFFFFF}to sell a log for {2ECC71}$%d.", tidx, CSAW_PRICE, LOG_PRICE);
			BuyerData[tidx][buyerLabel] = CreateDynamic3DTextLabel(label, 0xF1C40FFF, BuyerData[tidx][buyerX], BuyerData[tidx][buyerY], BuyerData[tidx][buyerZ] + 0.25, 5.0, .testlos = 1);

			Iter_Add(Buyers, tidx);
		}

		printf("  [Lumberjack] Loaded %d buyers.", Iter_Count(Buyers));
	}
	
	return 1;
}

public OnFilterScriptExit()
{
	foreach(new i : Player)
	{
	    Player_ResetCutting(i);
		Player_RemoveLog(i);
		
		DestroyPlayerProgressBar(i, CuttingBar[i]);
	}
	
	foreach(new i : Buyers) DestroyActor(BuyerData[i][buyerActorID]);
	
	db_close(ScriptDBHandle);
	print("  [Lumberjack] Unloaded.");
	return 1;
}

public OnPlayerConnect(playerid)
{
	Player_Init(playerid);
	return 1;
}

public OnPlayerDisconnect(playerid, reason)
{
	Player_ResetCutting(playerid);
	Player_RemoveLog(playerid);
	
	EditingTreeID[playerid] = -1;
	return 1;
}

public OnVehicleSpawn(vehicleid)
{
	Vehicle_RemoveLogs(vehicleid);
	return 1;
}

public OnVehicleDeath(vehicleid, killerid)
{
	Vehicle_RemoveLogs(vehicleid);
	return 1;
}

public OnPlayerDeath(playerid, killerid, reason)
{
    Player_ResetCutting(playerid);
    Player_DropLog(playerid, 1);
	return 1;
}

public OnPlayerStateChange(playerid, newstate, oldstate)
{
	if(newstate != PLAYER_STATE_WASTED)
	{
	    Player_ResetCutting(playerid);
	    Player_RemoveLog(playerid);
	}
	
	return 1;
}

public OnPlayerKeyStateChange(playerid, newkeys, oldkeys)
{
	if(GetPlayerState(playerid) == PLAYER_STATE_ONFOOT && (newkeys & KEY_NO))
	{
	    if(CarryingLog[playerid]) return Player_DropLog(playerid);
	    
	    if(GetPlayerWeapon(playerid) == WEAPON_CHAINSAW && CuttingTreeID[playerid] == -1 && !CarryingLog[playerid])
	    {
		    new tidx = GetClosestTree(playerid);

		    if(tidx != -1)
		    {
		        if(!Tree_BeingEdited(tidx) && !TreeData[tidx][treeGettingCut] && TreeData[tidx][treeSeconds] < 1)
				{
		            SetPlayerLookAt(playerid, TreeData[tidx][treeX], TreeData[tidx][treeY]);

		            Streamer_SetIntData(STREAMER_TYPE_3D_TEXT_LABEL, TreeData[tidx][treeLabel], E_STREAMER_COLOR, 0xE74C3CFF);
		            CuttingTimer[playerid] = SetTimerEx("CutTree", 1000, true, "i", playerid);
					CuttingTreeID[playerid] = tidx;
					SetPlayerProgressBarValue(playerid, CuttingBar[playerid], 0.0);
					ShowPlayerProgressBar(playerid, CuttingBar[playerid]);
					TogglePlayerControllable(playerid, 0);
					SetPlayerArmedWeapon(playerid, WEAPON_CHAINSAW);
					ApplyAnimation(playerid, "CHAINSAW", "WEAPON_csaw", 4.1, 1, 0, 0, 1, 0, 1);

					TreeData[tidx][treeGettingCut] = true;
		        }
		    }
	    }
	}

	return 1;
}

public OnPlayerEditDynamicObject(playerid, STREAMER_TAG_OBJECT:objectid, response, Float:x, Float:y, Float:z, Float:rx, Float:ry, Float:rz)
{
	if(EditingTreeID[playerid] != -1 && Iter_Contains(Trees, EditingTreeID[playerid]))
	{
	    if(response == EDIT_RESPONSE_FINAL)
	    {
	        new tidx = EditingTreeID[playerid];
	        TreeData[tidx][treeX] = x;
	        TreeData[tidx][treeY] = y;
	        TreeData[tidx][treeZ] = z;
	        TreeData[tidx][treeRX] = rx;
	        TreeData[tidx][treeRY] = ry;
	        TreeData[tidx][treeRZ] = rz;

	        SetDynamicObjectPos(objectid, TreeData[tidx][treeX], TreeData[tidx][treeY], TreeData[tidx][treeZ]);
	        SetDynamicObjectRot(objectid, TreeData[tidx][treeRX], TreeData[tidx][treeRY], TreeData[tidx][treeRZ]);

			Streamer_SetFloatData(STREAMER_TYPE_3D_TEXT_LABEL, TreeData[tidx][treeLabel], E_STREAMER_X, TreeData[tidx][treeX]);
			Streamer_SetFloatData(STREAMER_TYPE_3D_TEXT_LABEL, TreeData[tidx][treeLabel], E_STREAMER_Y, TreeData[tidx][treeY]);
			Streamer_SetFloatData(STREAMER_TYPE_3D_TEXT_LABEL, TreeData[tidx][treeLabel], E_STREAMER_Z, TreeData[tidx][treeZ] + 1.5);

		    stmt_bind_value(UpdateTree, 0, DB::TYPE_FLOAT, TreeData[tidx][treeX]);
		    stmt_bind_value(UpdateTree, 1, DB::TYPE_FLOAT, TreeData[tidx][treeY]);
		    stmt_bind_value(UpdateTree, 2, DB::TYPE_FLOAT, TreeData[tidx][treeZ]);
		    stmt_bind_value(UpdateTree, 3, DB::TYPE_FLOAT, TreeData[tidx][treeRX]);
		    stmt_bind_value(UpdateTree, 4, DB::TYPE_FLOAT, TreeData[tidx][treeRY]);
		    stmt_bind_value(UpdateTree, 5, DB::TYPE_FLOAT, TreeData[tidx][treeRZ]);
		    stmt_bind_value(UpdateTree, 6, DB::TYPE_INTEGER, tidx);
			stmt_execute(UpdateTree);

	        EditingTreeID[playerid] = -1;
	    }

	    if(response == EDIT_RESPONSE_CANCEL)
	    {
	        new tidx = EditingTreeID[playerid];
	        SetDynamicObjectPos(objectid, TreeData[tidx][treeX], TreeData[tidx][treeY], TreeData[tidx][treeZ]);
	        SetDynamicObjectRot(objectid, TreeData[tidx][treeRX], TreeData[tidx][treeRY], TreeData[tidx][treeRZ]);
	        EditingTreeID[playerid] = -1;
	    }
	}

	return 1;
}

forward CutTree(playerid);
public CutTree(playerid)
{
    if(CuttingTreeID[playerid] != -1)
	{
	    new tidx = CuttingTreeID[playerid], Float: value = GetPlayerProgressBarValue(playerid, CuttingBar[playerid]) + 1.0;
	    
		if(value >= CUTTING_TIME) {
		    Player_ResetCutting(playerid);
			MoveDynamicObject(TreeData[tidx][treeObjID], TreeData[tidx][treeX], TreeData[tidx][treeY], TreeData[tidx][treeZ] + 0.03, 0.025, TreeData[tidx][treeRX], TreeData[tidx][treeRY] - 80.0, TreeData[tidx][treeRZ]);

			TreeData[tidx][treeLogs] = 5;
			TreeData[tidx][treeSeconds] = TREE_RESPAWN;
			Tree_UpdateLogLabel(tidx);
		}else{
		    SetPlayerProgressBarValue(playerid, CuttingBar[playerid], value);
		}
	}

	return 1;
}

forward RespawnTree(tidx);
public RespawnTree(tidx)
{
	new label[96];
	if(TreeData[tidx][treeSeconds] > 1) {
	    TreeData[tidx][treeSeconds]--;
	    
	    format(label, sizeof(label), "Tree (%d)\n\n{FFFFFF}%s", tidx, ConvertToMinutes(TreeData[tidx][treeSeconds]));
		UpdateDynamic3DTextLabelText(TreeData[tidx][treeLabel], 0xE74C3CFF, label);
	}else if(TreeData[tidx][treeSeconds] == 1) {
	    KillTimer(TreeData[tidx][treeTimer]);

	    TreeData[tidx][treeLogs] = 0;
	    TreeData[tidx][treeSeconds] = 0;
	    TreeData[tidx][treeTimer] = -1;
	    
	    SetDynamicObjectPos(TreeData[tidx][treeObjID], TreeData[tidx][treeX], TreeData[tidx][treeY], TreeData[tidx][treeZ]);
     	SetDynamicObjectRot(TreeData[tidx][treeObjID], TreeData[tidx][treeRX], TreeData[tidx][treeRY], TreeData[tidx][treeRZ]);
     	
     	format(label, sizeof(label), "Tree (%d)\n\n{FFFFFF}Press {F1C40F}~k~~CONVERSATION_NO~ {FFFFFF}to cut down.", tidx);
     	UpdateDynamic3DTextLabelText(TreeData[tidx][treeLabel], 0x2ECC71FF, label);
	}
	
	return 1;
}

forward RemoveLog(tidx);
public RemoveLog(tidx)
{
	if(!Iter_Count(Logs, tidx)) return 1;
	
	if(LogData[tidx][logSeconds] > 1) {
	    LogData[tidx][logSeconds]--;

        new label[128];
	    format(label, sizeof(label), "Log (%d)\n\n{FFFFFF}Dropped By {F1C40F}%s\n{FFFFFF}%s\nUse {F1C40F}/log take {FFFFFF}to take it.", tidx, LogData[tidx][logDroppedBy], ConvertToMinutes(LogData[tidx][logSeconds]));
		UpdateDynamic3DTextLabelText(LogData[tidx][logLabel], 0xF1C40FFF, label);
	}else if(LogData[tidx][logSeconds] == 1) {
	    KillTimer(LogData[tidx][logTimer]);
	    DestroyDynamicObject(LogData[tidx][logObjID]);
		DestroyDynamic3DTextLabel(LogData[tidx][logLabel]);
		
	    LogData[tidx][logTimer] = -1;
        LogData[tidx][logObjID] = -1;
        LogData[tidx][logLabel] = Text3D: -1;

		Iter_Remove(Logs, tidx);
	}
	
	return 1;
}

// Player Commands
CMD:chainsaw(playerid, params[])
{
    if(IsPlayerInAnyVehicle(playerid)) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}You can't use this command in a vehicle.");
    if(!IsPlayerNearALogBuyer(playerid)) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}You're not near a Log Buyer.");
	if(GetPlayerMoney(playerid) < CSAW_PRICE) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}You don't have enough money.");
    GivePlayerMoney(playerid, -CSAW_PRICE);
    GivePlayerWeapon(playerid, WEAPON_CHAINSAW, 1);
    
    new string[64];
    format(string, sizeof(string), "LUMBERJACK: {FFFFFF}Bought a chainsaw for {2ECC71}$%d.", CSAW_PRICE);
   	SendClientMessage(playerid, 0x3498DBFF, string);
	return 1;
}

CMD:log(playerid, params[])
{
	if(IsPlayerInAnyVehicle(playerid)) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}You can't use this command in a vehicle.");
    if(isnull(params)) return SendClientMessage(playerid, 0xE88732FF, "SYNTAX: {FFFFFF}/log [load/take/takefromcar/takefromtree/sell]");
    
    if(!strcmp(params, "load", true)) {
        // loading to a bobcat
        if(!CarryingLog[playerid]) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}You're not carrying a log.");
		new tidx = GetNearestVehicle(playerid);
		if(GetVehicleModel(tidx) != 422) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}You're not near a Bobcat.");
		new Float: x, Float: y, Float: z;
    	//GetVehicleBoot(tidx, x, y, z);
    	GetVehiclePartPos(tidx,VEH_PART_TRUNK,x,y,z);
    	if(!IsPlayerInRangeOfPoint(playerid, 3.0, x, y, z)) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}You're not near a Bobcat's back.");
    	if(Vehicle_LogCount(tidx) >= LOG_LIMIT) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}You can't load any more logs to this vehicle.");
    	for(new i; i < LOG_LIMIT; i++)
    	{
    	    if(!IsValidDynamicObject(LogObjects[tidx][i]))
    	    {
    	        LogObjects[tidx][i] = CreateDynamicObject(19793, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
    			AttachDynamicObjectToVehicle(LogObjects[tidx][i], tidx, LogAttachOffsets[i][0], LogAttachOffsets[i][1], LogAttachOffsets[i][2], 0.0, 0.0, LogAttachOffsets[i][3]);
    			break;
    	    }
    	}
    	
    	Streamer_Update(playerid);
    	Player_RemoveLog(playerid);
    	SendClientMessage(playerid, 0x3498DBFF, "LUMBERJACK: {FFFFFF}Loaded a log.");
    	// done
    }else if(!strcmp(params, "take")) {
        // taking from ground
        if(CarryingLog[playerid]) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}You're already carrying a log.");
		new tidx = GetClosestLog(playerid);
		if(tidx == -1) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}You're not near a log.");
		LogData[tidx][logSeconds] = 1;
		RemoveLog(tidx);
		
		Player_GiveLog(playerid);
		SendClientMessage(playerid, 0x3498DBFF, "LUMBERJACK: {FFFFFF}You've taken a log from ground.");
		// done
    }else if(!strcmp(params, "takefromcar")) {
        // taking from a bobcat
        if(CarryingLog[playerid]) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}You're already carrying a log.");
        new tidx = GetNearestVehicle(playerid);
		if(GetVehicleModel(tidx) != 422) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}You're not near a Bobcat.");
		new Float: x, Float: y, Float: z;
    	//GetVehicleBoot(tidx, x, y, z);
    	GetVehiclePartPos(tidx,VEH_PART_TRUNK,x,y,z);
    	if(!IsPlayerInRangeOfPoint(playerid, 3.0, x, y, z)) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}You're not near a Bobcat's back.");
    	if(Vehicle_LogCount(tidx) < 1) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}This Bobcat doesn't have any logs.");
    	for(new i = (LOG_LIMIT - 1); i >= 0; i--)
    	{
    	    if(IsValidDynamicObject(LogObjects[tidx][i]))
    	    {
    	        DestroyDynamicObject(LogObjects[tidx][i]);
    	        LogObjects[tidx][i] = -1;
    			break;
    	    }
    	}

    	Streamer_Update(playerid);
    	Player_GiveLog(playerid);
        SendClientMessage(playerid, 0x3498DBFF, "LUMBERJACK: {FFFFFF}You've taken a log from the Bobcat.");
        // done
    }else if(!strcmp(params, "takefromtree")) {
		// taking from a cut tree
		if(CarryingLog[playerid]) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}You're already carrying a log.");
        new tidx = GetClosestTree(playerid);
        if(tidx == -1) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}You're not near a tree.");
        if(TreeData[tidx][treeSeconds] < 1) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}This tree isn't cut.");
        if(TreeData[tidx][treeLogs] < 1) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}This tree doesn't have any logs.");
        TreeData[tidx][treeLogs]--;
        Tree_UpdateLogLabel(tidx);
        
        Player_GiveLog(playerid);
        SendClientMessage(playerid, 0x3498DBFF, "LUMBERJACK: {FFFFFF}You've taken a log from the cut tree.");
        // done
    }else if(!strcmp(params, "sell")) {
        // selling a log
        if(!CarryingLog[playerid]) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}You're not carrying a log.");
		if(!IsPlayerNearALogBuyer(playerid)) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}You're not near a Log Buyer.");
		Player_RemoveLog(playerid);
		GivePlayerMoney(playerid, LOG_PRICE);
		
		new string[64];
		format(string, sizeof(string), "LUMBERJACK: {FFFFFF}Sold a log for {2ECC71}$%d.", LOG_PRICE);
    	SendClientMessage(playerid, 0x3498DBFF, string);
        // done
    }

	return 1;
}

// Admin Commands - Trees
CMD:createtree(playerid, params[])
{
	printf("this is createtree(%d)",playerid);
	if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}Only RCON admins can use this command.");
	new tidx = Iter_Free(Trees);
	if(tidx == -1) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}Can't add any more trees.");
 	new Float: x, Float: y, Float: z, Float: a;
 	GetPlayerPos(playerid, x, y, z);
 	GetPlayerFacingAngle(playerid, a);
 	x += (3.0 * floatsin(-a, degrees));
	y += (3.0 * floatcos(-a, degrees));
	z -= 1.0;
	
	TreeData[tidx][treeX] = x;
	TreeData[tidx][treeY] = y;
	TreeData[tidx][treeZ] = z;
	TreeData[tidx][treeRX] = TreeData[tidx][treeRY] = TreeData[tidx][treeRZ] = 0.0;
	
	TreeData[tidx][treeObjID] = CreateDynamicObject(657, TreeData[tidx][treeX], TreeData[tidx][treeY], TreeData[tidx][treeZ], TreeData[tidx][treeRX], TreeData[tidx][treeRY], TreeData[tidx][treeRZ]);

	new label[96];
	format(label, sizeof(label), "Tree (%d)\n\n{FFFFFF}Press {F1C40F}~k~~CONVERSATION_NO~ {FFFFFF}to cut down.", tidx);
	TreeData[tidx][treeLabel] = CreateDynamic3DTextLabel(label, 0x2ECC71FF, TreeData[tidx][treeX], TreeData[tidx][treeY], TreeData[tidx][treeZ] + 1.5, 5.0);
	Iter_Add(Trees, tidx);
	
	stmt_bind_value(AddTree, 0, DB::TYPE_INTEGER, tidx);
    stmt_bind_value(AddTree, 1, DB::TYPE_FLOAT, TreeData[tidx][treeX]);
    stmt_bind_value(AddTree, 2, DB::TYPE_FLOAT, TreeData[tidx][treeY]);
    stmt_bind_value(AddTree, 3, DB::TYPE_FLOAT, TreeData[tidx][treeZ]);
    stmt_bind_value(AddTree, 4, DB::TYPE_FLOAT, TreeData[tidx][treeRX]);
    stmt_bind_value(AddTree, 5, DB::TYPE_FLOAT, TreeData[tidx][treeRY]);
    stmt_bind_value(AddTree, 6, DB::TYPE_FLOAT, TreeData[tidx][treeRZ]);
    
    if(stmt_execute(AddTree))
    {
        EditingTreeID[playerid] = tidx;
        EditDynamicObject(playerid, TreeData[tidx][treeObjID]);
        
        SendClientMessage(playerid, 0x3498DBFF, "LUMBERJACK: {FFFFFF}Tree created.");
        SendClientMessage(playerid, 0x3498DBFF, "LUMBERJACK: {FFFFFF}You can edit it right now, or cancel editing and edit it some other time.");
	}
	
	return 1;
}

CMD:edittree(playerid, params[])
{
    if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}Only RCON admins can use this command.");
    if(EditingTreeID[playerid] != -1) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}You're already editing a tree.");
	new tidx;
	if(sscanf(params, "i", tidx)) return SendClientMessage(playerid, 0xE88732FF, "SYNTAX: {FFFFFF}/edittree [tree tidx]");
	if(!Iter_Contains(Trees, tidx)) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}Invalid tidx.");
	if(TreeData[tidx][treeGettingCut]) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}Can't edit specified tree because its getting cut down.");
	if(!IsPlayerInRangeOfPoint(playerid, 30.0, TreeData[tidx][treeX], TreeData[tidx][treeY], TreeData[tidx][treeZ])) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}You're not near the tree you want to edit.");
	EditingTreeID[playerid] = tidx;
	EditDynamicObject(playerid, TreeData[tidx][treeObjID]);
	return 1;
}

CMD:removetree(playerid, params[])
{
    if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}Only RCON admins can use this command.");
	new tidx;
	if(sscanf(params, "i", tidx)) return SendClientMessage(playerid, 0xE88732FF, "SYNTAX: {FFFFFF}/removetree [tree tidx]");
	if(!Iter_Contains(Trees, tidx)) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}Invalid tidx.");
	if(TreeData[tidx][treeGettingCut]) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}Can't remove specified tree because its getting cut down.");
	if(Tree_BeingEdited(tidx)) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}Can't remove specified tree because its being edited.");
	DestroyDynamicObject(TreeData[tidx][treeObjID]);
	DestroyDynamic3DTextLabel(TreeData[tidx][treeLabel]);
	if(TreeData[tidx][treeTimer] != -1) KillTimer(TreeData[tidx][treeTimer]);
	
	TreeData[tidx][treeLogs] = TreeData[tidx][treeSeconds] = 0;
	TreeData[tidx][treeObjID] = TreeData[tidx][treeTimer] = -1;
	TreeData[tidx][treeLabel] = Text3D: -1;
	Iter_Remove(Trees, tidx);
	
	stmt_bind_value(RemoveTree, 0, DB::TYPE_INTEGER, tidx);
	if(stmt_execute(RemoveTree)) SendClientMessage(playerid, 0x3498DBFF, "LUMBERJACK: {FFFFFF}Tree removed.");
	return 1;
}

// Admin Commands - Log Buyers
CMD:createbuyer(playerid, params[])
{
	if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}Only RCON admins can use this command.");
	new skin;
	if(sscanf(params, "i", skin)) return SendClientMessage(playerid, 0xE88732FF, "SYNTAX: {FFFFFF}/createbuyer [skin tidx]");
	if(!(0 <= skin <= 311)) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}Invalid skin tidx.");
	new tidx = Iter_Free(Buyers);
	if(tidx == -1) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}Can't add any more log buyers.");
	GetPlayerPos(playerid, BuyerData[tidx][buyerX], BuyerData[tidx][buyerY], BuyerData[tidx][buyerZ]);
	GetPlayerFacingAngle(playerid, BuyerData[tidx][buyerA]);

	BuyerData[tidx][buyerActorID] = CreateActor(skin, BuyerData[tidx][buyerX], BuyerData[tidx][buyerY], BuyerData[tidx][buyerZ], BuyerData[tidx][buyerA]);
	SetActorInvulnerable(BuyerData[tidx][buyerActorID], 1);
	
	new label[172];
	format(label, sizeof(label), "Log Buyer (%d)\n\n{FFFFFF}Use {F1C40F}/chainsaw {FFFFFF}to buy a chainsaw for {2ECC71}$%d.\n{FFFFFF}Use {F1C40F}/log sell {FFFFFF}to sell a log for {2ECC71}$%d.", tidx, CSAW_PRICE, LOG_PRICE);
	BuyerData[tidx][buyerLabel] = CreateDynamic3DTextLabel(label, 0xF1C40FFF, BuyerData[tidx][buyerX], BuyerData[tidx][buyerY], BuyerData[tidx][buyerZ] + 0.25, 5.0, .testlos = 1);
	Iter_Add(Buyers, tidx);
	
	stmt_bind_value(AddBuyer, 0, DB::TYPE_INTEGER, tidx);
	stmt_bind_value(AddBuyer, 1, DB::TYPE_INTEGER, skin);
    stmt_bind_value(AddBuyer, 2, DB::TYPE_FLOAT, BuyerData[tidx][buyerX]);
    stmt_bind_value(AddBuyer, 3, DB::TYPE_FLOAT, BuyerData[tidx][buyerY]);
    stmt_bind_value(AddBuyer, 4, DB::TYPE_FLOAT, BuyerData[tidx][buyerZ]);
    stmt_bind_value(AddBuyer, 5, DB::TYPE_FLOAT, BuyerData[tidx][buyerA]);

    if(stmt_execute(AddBuyer))
	{
		SendClientMessage(playerid, 0x3498DBFF, "LUMBERJACK: {FFFFFF}Buyer created.");
		SetPlayerPos(playerid, BuyerData[tidx][buyerX] + (1.5 * floatsin(-BuyerData[tidx][buyerA], degrees)), BuyerData[tidx][buyerY] + (1.5 * floatcos(-BuyerData[tidx][buyerA], degrees)), BuyerData[tidx][buyerZ]);
	}
	
	return 1;
}

CMD:setbuyerskin(playerid, params[])
{
	if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}Only RCON admins can use this command.");
	new tidx, skin;
	if(sscanf(params, "ii", tidx, skin)) return SendClientMessage(playerid, 0xE88732FF, "SYNTAX: {FFFFFF}/setbuyerskin [buyer tidx] [skin tidx]");
	if(!Iter_Contains(Buyers, tidx)) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}Invalid tidx.");
	if(!(0 <= skin <= 311)) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}Invalid skin tidx.");
	BuyerData[tidx][buyerSkin] = skin;
	
	DestroyActor(BuyerData[tidx][buyerActorID]);
	BuyerData[tidx][buyerActorID] = CreateActor(skin, BuyerData[tidx][buyerX], BuyerData[tidx][buyerY], BuyerData[tidx][buyerZ], BuyerData[tidx][buyerA]);
	SetActorInvulnerable(BuyerData[tidx][buyerActorID], 1);
	
	stmt_bind_value(UpdateBuyer, 0, DB::TYPE_INTEGER, skin);
    stmt_bind_value(UpdateBuyer, 1, DB::TYPE_FLOAT, BuyerData[tidx][buyerX]);
    stmt_bind_value(UpdateBuyer, 2, DB::TYPE_FLOAT, BuyerData[tidx][buyerY]);
    stmt_bind_value(UpdateBuyer, 3, DB::TYPE_FLOAT, BuyerData[tidx][buyerZ]);
    stmt_bind_value(UpdateBuyer, 4, DB::TYPE_FLOAT, BuyerData[tidx][buyerA]);
    stmt_bind_value(UpdateBuyer, 5, DB::TYPE_INTEGER, tidx);

    if(stmt_execute(UpdateBuyer)) SendClientMessage(playerid, 0x3498DBFF, "LUMBERJACK: {FFFFFF}Buyer updated.");
	return 1;
}

CMD:setbuyerpos(playerid, params[])
{
	if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}Only RCON admins can use this command.");
	new tidx;
	if(sscanf(params, "i", tidx)) return SendClientMessage(playerid, 0xE88732FF, "SYNTAX: {FFFFFF}/setbuyerpos [buyer tidx]");
	if(!Iter_Contains(Buyers, tidx)) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}Invalid tidx.");
	GetPlayerPos(playerid, BuyerData[tidx][buyerX], BuyerData[tidx][buyerY], BuyerData[tidx][buyerZ]);
	GetPlayerFacingAngle(playerid, BuyerData[tidx][buyerA]);

	DestroyActor(BuyerData[tidx][buyerActorID]);
	BuyerData[tidx][buyerActorID] = CreateActor(BuyerData[tidx][buyerSkin], BuyerData[tidx][buyerX], BuyerData[tidx][buyerY], BuyerData[tidx][buyerZ], BuyerData[tidx][buyerA]);
	SetActorInvulnerable(BuyerData[tidx][buyerActorID], 1);

    Streamer_SetFloatData(STREAMER_TYPE_3D_TEXT_LABEL, BuyerData[tidx][buyerLabel], E_STREAMER_X, BuyerData[tidx][buyerX]);
	Streamer_SetFloatData(STREAMER_TYPE_3D_TEXT_LABEL, BuyerData[tidx][buyerLabel], E_STREAMER_Y, BuyerData[tidx][buyerY]);
	Streamer_SetFloatData(STREAMER_TYPE_3D_TEXT_LABEL, BuyerData[tidx][buyerLabel], E_STREAMER_Z, BuyerData[tidx][buyerZ] + 0.25);

	stmt_bind_value(UpdateBuyer, 0, DB::TYPE_INTEGER, BuyerData[tidx][buyerSkin]);
    stmt_bind_value(UpdateBuyer, 1, DB::TYPE_FLOAT, BuyerData[tidx][buyerX]);
    stmt_bind_value(UpdateBuyer, 2, DB::TYPE_FLOAT, BuyerData[tidx][buyerY]);
    stmt_bind_value(UpdateBuyer, 3, DB::TYPE_FLOAT, BuyerData[tidx][buyerZ]);
    stmt_bind_value(UpdateBuyer, 4, DB::TYPE_FLOAT, BuyerData[tidx][buyerA]);
    stmt_bind_value(UpdateBuyer, 5, DB::TYPE_INTEGER, tidx);

    if(stmt_execute(UpdateBuyer))
	{
		SendClientMessage(playerid, 0x3498DBFF, "LUMBERJACK: {FFFFFF}Buyer updated.");
        SetPlayerPos(playerid, BuyerData[tidx][buyerX] + (1.5 * floatsin(-BuyerData[tidx][buyerA], degrees)), BuyerData[tidx][buyerY] + (1.5 * floatcos(-BuyerData[tidx][buyerA], degrees)), BuyerData[tidx][buyerZ]);
	}
	
	return 1;
}

CMD:removebuyer(playerid, params[])
{
	if(!IsPlayerAdmin(playerid)) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}Only RCON admins can use this command.");
	new tidx;
	if(sscanf(params, "i", tidx)) return SendClientMessage(playerid, 0xE88732FF, "SYNTAX: {FFFFFF}/removebuyer [buyer tidx]");
	if(!Iter_Contains(Buyers, tidx)) return SendClientMessage(playerid, 0xE74C3CFF, "ERROR: {FFFFFF}Invalid tidx.");
	DestroyActor(BuyerData[tidx][buyerActorID]);
	DestroyDynamic3DTextLabel(BuyerData[tidx][buyerLabel]);
	
	BuyerData[tidx][buyerActorID] = -1;
	BuyerData[tidx][buyerLabel] = Text3D: -1;
	Iter_Remove(Buyers, tidx);
	
	stmt_bind_value(RemoveBuyer, 0, DB::TYPE_INTEGER, tidx);
    if(stmt_execute(RemoveBuyer)) SendClientMessage(playerid, 0x3498DBFF, "LUMBERJACK: {FFFFFF}Buyer removed.");
	return 1;
}
