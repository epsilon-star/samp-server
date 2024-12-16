/*
ENGLISH (EN-US):
Very Welcome To Shadow Team Followers 

Yet Another Login System By EPSILON

Features:
- OTP System
- EMAIL Verification
- Completely Dynamic 
- Easy Changable Content


Note : There Are Some Points That Have Been Marked by text "EPSILON_TAG_FILL",
please consider editiing The Marked Places

EPISLON, Regards!

PERSIAN (FA-IR):
خوش آمد به تمام دنبال کنندگان تیم شدو

یک سیستم لاگین دیگر توسط EPSILON

ویژگی ها :
- سیستم اختصاصی OTP
- تایید ایمیل و یا رد برای مواقع دیگر
- کاملا داینامیک و استریم
- ساده ترین دسترسی تغییر محتوا

پینوشت : در این سیستم نقاطی با عنوان 
EPSILON_TAG_FILL
نمایش داده شده 
لطفا بجای این نوشته ، نوشته دلخواه خود را بنویسد

تشکر EPSILON

*/

#include <a_samp>
#include <a_mysql>
#include <sscanf2>
#include <zcmd>

#include <YSI_Coding\y_va>

new MySQL:mysql;

#define SFM SendFormatClientMessage
enum message_types 
{
    msg_error,
    msg_warning,
    msg_info
};
new MSG_COLORS[message_types] = {
    "f70029",
    "f78c00",
    "0094f7"
};
new MSG_TAGS[message_types] = {
    "$Error",
    "$Warning",
    "$Info"
};
stock SendFormatClientMessage(playerid,message_types:msg_type,const tmptext[],GLOBAL_TAG_TYPES:...)
{
    new tmpstr[512];
    format(tmpstr,sizeof tmpstr,"{%s}%s {FFFFFF}>- %s",MSG_COLORS[msg_type],MSG_TAGS[msg_type],va_return(tmptext,__(3)));
}

enum dialogids 
{
    dialog_username,
    dialog_login,
    dialog_regsiter,
    dialog_register_number,
    dialog_register_number_verify,
    dialog_register_email,
    dialog_register_email_verify, // consider
    dialog_register_age,
    dialog_register_gender,
    dialog_register_referral,
    dialog_register_spawn_point,
};
enum dialog_enum 
{
    dg_style,
    dg_title[50],
    dg_caption[512],
    dg_btnok[20],
    dg_btncan[20]
};
new DIALOG_DATA[dialogids][dialog_enum] = {
    {DIALOG_STYLE_INPUT,"$-USERNAME-$","Please Type Your Username\n\n- Username Cannot Have Any Spaces\n- Username Length Must Be 6Char At Least","Continue","Exit"},
    {DIALOG_STYLE_PASSWORD,"$-LOGIN-$","Please Enter Your Password","Next","Back"},
    {DIALOG_STYLE_INPUT,"$-REGISTER-$","Please Choose Your Password","Next","Back"},
    {DIALOG_STYLE_INPUT,"$-NUMBER-$","Please Enter Your Phone Number To Veify Your Indentify\nExample : 0991231234 -> 991231234","Next","Back"},
    {DIALOG_STYLE_INPUT,"$-NUMBER-VERIFY-$","Please Enter 6-Digits Code That Have Been Sent To Your Phone","Verify","Edit"},
    {DIALOG_STYLE_INPUT,"$-EMAIL-$","Please Enter Email As Second Auth Option or Simply Skip IT","Next","Back"},
    {DIALOG_STYLE_INPUT,"$-EMAIL-VERIFY-$","Please Enter 4-Digits Code That Is Sent To Your MAIL BOX","Verify","Edit"},
    {DIALOG_STYLE_INPUT,"$-AGE-$","Please Enter Your Age\n\nAllowed Age : 11 And Higher","Next","Back"},
    {DIALOG_STYLE_LIST,"$-GENDER-$","Male\nFeMale\nPrivate","Select","Back"},
    {DIALOG_STYLE_INPUT,"$-REFERRAL-$","Please Type Your Username","Continue","Back"},
    {DIALOG_STYLE_LIST,"$-FIRST-SPAWN-$","EPSILON_TAG_FILL","Select","Back"},
};
stock ShowDialog(playerid,dialogids:dialogid,const extra_text[] = "")
{
    new mixCaption[512];
    if(strlen(extra_text)) format(mixCaption,sizeof mixCaption,"%s\n%s",DIALOG_DATA[dialogid][dg_caption],extra_text);
    else strcat(mixCaption,DIALOG_DATA[dialogid][dg_caption]);
    return ShowPlayerDialog(playerid,dialogid,
        DIALOG_DATA[dialogid][dg_style],
        DIALOG_DATA[dialogid][dg_title],
        mixCaption,
        DIALOG_DATA[dialogid][dg_btnok],
        DIALOG_DATA[dialogid][dg_btncan]
    );
}

public OnFilterScriptInit()
{
    mysql = mysql_connect_file("mysql.ini");
    return 1;
}

public OnFilterScriptExit()
{
    if(mysql) mysql_close();
    return 1;
}