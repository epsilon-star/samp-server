if (GetPVarInt(playerid, "HousePickupCooldown") < gettime()) {
	if (IsPlayerInRangeOfPoint(playerid, 1.2, 887.7183, 1918.1659, -88.9744)) {
		SetPlayerVirtualWorld(playerid, 0);
		SetPlayerInterior(playerid, 0);
		if (InCamp[playerid] != -1) SetPlayerPos(playerid, CampData[InCamp[playerid]][aCampPos][0], CampData[InCamp[playerid]][aCampPos][1], CampData[InCamp[playerid]][aCampPos][2]);
		else SetPlayerPos(playerid, CampData[0][aCampPos][0], CampData[0][aCampPos][1], CampData[0][aCampPos][2]);
		InCamp[playerid] = -1;
		SetPVarInt(playerid, "HousePickupCooldown", gettime() + HOUSE_COOLDOWN);
		DisablePlayerCheckpoint(playerid);
		return 1;
	}

	if (InCamp[playerid] == -1) {
		foreach(new i : aCamp) {
			if (IsPlayerInRangeOfPoint(playerid, 1.2, CampData[i][aCampPos][0], CampData[i][aCampPos][1], CampData[i][aCampPos][2])) {
				if (strcmp(CampData[i][aCampOwner], "-")) {
					if (GetPlayerClanID(playerid) != CampData[i][aCampID]) return SendClientMessage(playerid, 0xF3A372FF, "You didn't member of this camp.");
					InCamp[playerid] = i;
					SetPlayerVirtualWorld(playerid, aCampWorlds[i]);
					SetPlayerPos(playerid, 886.4480, 1918.1488, -88.9907);
					SetPlayerFacingAngle(playerid, 90.7735);
					SetPVarInt(playerid, "HousePickupCooldown", gettime() + HOUSE_COOLDOWN);
					SetPlayerCheckpoint(playerid, 882.4947, 1895.4323, -93.8987 - 1.4, 1.7);
					break;
				} else {
					gCampID[playerid] = i;
					ShowPlayerDialog(playerid, DIALOG_CAMP_BUY, DIALOG_STYLE_MSGBOX, "{F9BD4F}Buy Camp", "{FFFFFF}Camp for sell.\n\n{F1C40F}Price:{FFFF00} 3,000 Gold", "Buy", "Cancel");
				}
			}
		}
	}
	if (InHouse[playerid] == INVALID_HOUSE_ID) {
		foreach(new i : Houses) {
			if (IsPlayerInRangeOfPoint(playerid, 1.2, HouseData[i][houseX], HouseData[i][houseY], HouseData[i][houseZ])) {
				SetPVarInt(playerid, "HousePickupCooldown", gettime() + HOUSE_COOLDOWN);
				SetPVarInt(playerid, "PickupHouseID", i);

				if (!strcmp(HouseData[i][Owner], "-")) {
					ShowPlayerDialog(playerid, DIALOG_BUY_HOUSE_MENU, DIALOG_STYLE_LIST, "{75EB72}House For Sale", "{79fc8f}Buy House\n{79fc8f}See House", "{75EB72}Select", "{75EB72}Close");
					//new string[64];
					//format(string, sizeof(string), "This house is for sale!\n\nPrice: {2ECC71}$%s", GetMoneyName(HouseData[i][Price]));
					//ShowPlayerDialog(playerid, DIALOG_BUY_HOUSE, DIALOG_STYLE_MSGBOX, "House For Sale", string, "Buy", "Close");
				} else {
					if (HouseData[i][SalePrice] > 0 && strcmp(HouseData[i][Owner], PlayerName(playerid), true)) {
						//new string[64];
						format(string, 64, "This House Is For Sale!\n\nPrice: {2ECC71}$%s", GetMoneyName(HouseData[i][SalePrice]));
						ShowPlayerDialog(playerid, DIALOG_BUY_HOUSE_FROM_OWNER, DIALOG_STYLE_MSGBOX, "House For Sale", string, "Buy", "Close");
						return 1;
					}
					if (!strcmp(HouseData[i][Owner], PlayerName(playerid), true) || xSpawnRent[playerid] == i || pIsJobCleaner[playerid]) return TeleportToHouse(playerid, i);
					switch (HouseData[i][LockMode]) {
						case LOCK_MODE_NOLOCK:
							TeleportToHouse(playerid, i);
						case LOCK_MODE_PASSWORD:
							ShowPlayerDialog(playerid, DIALOG_HOUSE_PASSWORD, DIALOG_STYLE_INPUT, "House Password", "This House Is Password Protected.\n\nEnter House Password:", "Enter", "Close");
						case LOCK_MODE_KEYS: {
							new gotkeys = Iter_Contains(HouseKeys[playerid], i);
							if (!gotkeys)
							if (!strcmp(HouseData[i][Owner], PlayerName(playerid), true)) gotkeys = 1;

							if (gotkeys) {
								TeleportToHouse(playerid, i);
							} else {
								SendClientMessage(playerid, 0xFF5555FF, "You Didn't Have This House Keys.");
							}
						}
						case LOCK_MODE_OWNER: {
							if (!strcmp(HouseData[i][Owner], PlayerName(playerid), true)) {
								SetPVarInt(playerid, "HousePickupCooldown", gettime() + HOUSE_COOLDOWN);
								TeleportToHouse(playerid, i);
							} else {
								SendClientMessage(playerid, 0xFF5555FF, "Only The House Owner Or Renters Can Enter This House.");
							}
						}
					}
				}
				return 1;
			}
		}
	} else {
		for (new i; i < sizeof(HouseInteriors); ++i) {
			if (IsPlayerInRangeOfPoint(playerid, 1.2, HouseInteriors[HouseData[InHouse[playerid]][Interior]][intX], HouseInteriors[HouseData[InHouse[playerid]][Interior]][intY], HouseInteriors[HouseData[InHouse[playerid]][Interior]][intZ])) {
				SetPVarInt(playerid, "HousePickupCooldown", gettime() + HOUSE_COOLDOWN);
				SetPlayerVirtualWorld(playerid, 0);
				SetPlayerInterior(playerid, HouseSavedInt[playerid]);
				SetPlayerPos(playerid, HouseData[InHouse[playerid]][houseX], HouseData[InHouse[playerid]][houseY], HouseData[InHouse[playerid]][houseZ]);
				InHouse[playerid] = INVALID_HOUSE_ID;
				if (HouseSaleTimer[playerid] != -1) KillTimer(HouseSaleTimer[playerid]), HouseSaleTimer[playerid] = -1;
				if (pIsJobCleaner[playerid]) {
					SetPlayerHealth(playerid, pIsJobCleanerHealth[playerid]);
					ResetPlayerWeapons(playerid);
					for(new slot; slot < 13; slot++)
					{	
						GivePlayerWeaponEx(playerid, PlayerWeapon[playerid][slot], PlayerAmmo[playerid][slot]);
					}
					if (pIsJobCleanerTime[playerid] >= 1) {
						pIsJobCleanerTime[playerid] = 0;
						SendClientMessage(playerid, COLOR_ERROR, "Nezafate Khane Namovafagh Anjam Shod.");
					}
				}
				return 1;
			}
		}
	}
}