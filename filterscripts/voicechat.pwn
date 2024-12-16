#include <a_samp>
#include <sampvoice>
#include <sscanf2>
#include <zcmd>

#define VOICE_LOCAL_CHANNEL 0x42
#define VOICE_GLOBAL_CHANNEL 0x5A
#define VOICE_RADIO_CHANNEL 0x58

new SV_GSTREAM:gstream = SV_NULL;
new SV_GSTREAM:rstream[50] = { SV_NULL, ... };
new SV_LSTREAM:lstream[MAX_PLAYERS] = { SV_NULL, ... };

new radioToggle[MAX_PLAYERS] = { 0,... };
new radioChannel[MAX_PLAYERS] = { 0,... };

stock GetEmptyRadioChannel()
{
	new idx = -1;
	for(new x;x<sizeof(rstream);x++)
	{
		if(!rstream[x]) {
			idx=x;
			break;
		}
	}
	return idx;
}
stock IsRadioChannelActive(chid)
{
	new idx = false;
	for(new x;x<sizeof(rstream);x++)
	{
		if(!rstream[x]) {
			idx=true;
			break;
		}
	}
	return idx;
}

public SV_VOID:OnPlayerActivationKeyPress(SV_UINT:playerid, SV_UINT:keyid) 
{
    // Attach player to local stream as speaker if 'B' key is pressed
    if (keyid == VOICE_LOCAL_CHANNEL && lstream[playerid]) SvAttachSpeakerToStream(lstream[playerid], playerid);
    // Attach the player to the global stream as a speaker if the 'Z' key is pressed
    if (keyid == VOICE_GLOBAL_CHANNEL && gstream) SvAttachSpeakerToStream(gstream, playerid);

	if (keyid == VOICE_RADIO_CHANNEL && rstream[radioChannel[playerid]] && radioToggle[playerid]) SvAttachSpeakerToStream(rstream[radioChannel[playerid]], playerid);
}

public SV_VOID:OnPlayerActivationKeyRelease(SV_UINT:playerid, SV_UINT:keyid)
{
    // Detach the player from the local stream if the 'B' key is released
    if (keyid == VOICE_LOCAL_CHANNEL && lstream[playerid]) SvDetachSpeakerFromStream(lstream[playerid], playerid);
    // Detach the player from the global stream if the 'Z' key is released
    if (keyid == VOICE_GLOBAL_CHANNEL && gstream) SvDetachSpeakerFromStream(gstream, playerid);

    if (keyid == VOICE_RADIO_CHANNEL && rstream[radioChannel[playerid]] && radioToggle[playerid]) SvDetachSpeakerFromStream(rstream[radioChannel[playerid]], playerid);
}

public OnPlayerConnect(playerid)
{
    // Checking for plugin availability
	lstream[playerid] = SvCreateDLStreamAtPlayer(40.0, SV_INFINITY, playerid, 0xff8400ff, "Local");
    if (SvGetVersion(playerid) == SV_NULL)
    {
        SendClientMessage(playerid, -1, "Could not find plugin sampvoice.");
    }
    // Checking for a microphone
    else if (SvHasMicro(playerid) == SV_FALSE)
    {
        SendClientMessage(playerid, -1, "The microphone could not be found.");
    }
    // Create a local stream with an audibility distance of 40.0, an unlimited number of listeners
    // and the name 'Local' (the name 'Local' will be displayed in red in the players' speakerlist)
    else if (lstream[playerid])
    {
        SendClientMessage(playerid, -1, "Press Z to talk to global chat and B to talk to local chat.");
		SendClientMessage(playerid, -1, "use /tradio for toggling radio stream");

        // Attach the player to the global stream as a listener
        if (gstream) SvAttachListenerToStream(gstream, playerid);

        // Assign microphone activation keys to the player
        SvAddKey(playerid, VOICE_LOCAL_CHANNEL);
        SvAddKey(playerid, VOICE_GLOBAL_CHANNEL);
        SvAddKey(playerid, VOICE_RADIO_CHANNEL);
    }
}

public OnPlayerDisconnect(playerid, reason)
{
	SvRemoveAllKeys(playerid);
    // Removing the player's local stream after disconnecting
    if (lstream[playerid])
    {
        SvDeleteStream(lstream[playerid]);
        lstream[playerid] = SV_NULL;
    }
}

public OnFilterScriptInit()
{
    // Uncomment the line to enable debug mode
    //SvDebug(SV_TRUE);

    gstream = SvCreateGStream(0x000000, "Global");
	for(new x;x<sizeof(rstream);x++)
	{
		new tmpstr[50];format(tmpstr,sizeof tmpstr,"Radio Channel %03d",x);
		rstream[x] = SvCreateGStream(0x52a40000, tmpstr);
	}
}

public OnFilterScriptExit()
{
    if (gstream) SvDeleteStream(gstream);
	for(new x;x<sizeof(rstream);x++)
	{
		if (rstream[x]) SvDeleteStream(rstream[x]);
	}
}

CMD:tradio(playerid,params[])
{
	radioToggle[playerid] = !radioToggle[playerid];
	if(radioToggle[playerid]) SendClientMessage(playerid,0x34fa00ff,"Radio Toggle ON{ffffff}, Now You Can Use Radio Channels");
	else SendClientMessage(playerid,0xfa003eff,"Radio Toggle OFF{ffffff}, Now You Can Use Radio Channels");

	if(radioToggle[playerid] && radioChannel[playerid]) SvAttachListenerToStream(rstream[radioChannel[playerid]], playerid);
	else if(!radioToggle[playerid] && radioChannel[playerid]) SvDetachListenerFromStream(rstream[radioChannel[playerid]], playerid);
	return 1;
}
CMD:cradio(playerid,params[])
{
	new rch;
	if(sscanf(params,"i",rch)) return SendClientMessage(playerid,-1,"/cradio [rch]");
	else if(rch >= sizeof(rstream)) return SendClientMessage(playerid,-1,"Invalid Radio Channel, Must Be 0-50");
	else {
		SvDetachListenerFromStream(rstream[rch],playerid);
		if (rstream[rch]) {
			SvAttachListenerToStream(rstream[rch], playerid);
			radioToggle[playerid] = true;
			radioChannel[playerid] = rch;
			new tmpstr[128];
			format(tmpstr,sizeof tmpstr,"Radio Channel Sets %d",rch);
			SendClientMessage(playerid,-1,tmpstr);
		}
		else SendClientMessage(playerid,-1,"Invalid Radio Channel");
	}
	return 1;
}
CMD:aradio(playerid,params[])
{
	new tmpstr[128];
	SendClientMessage(playerid,-1,"_________________");
	SendClientMessage(playerid,-1,"Searching For Online Radio Channels:\n");
	for(new x;x<sizeof(rstream);x++)
	{
		if(rstream[x]) {
			format(tmpstr,sizeof tmpstr,"Radio Channel Found %d",x);
			SendClientMessage(playerid,-1,tmpstr);
		}
	}
	SendClientMessage(playerid,-1,"_________________");
	return 1;
}