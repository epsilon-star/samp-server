#include <file>
#include <dini>


#define USER_DIR "users/"


stock CreateUser(username[],password[])
{
    new tmpdir[50];format(tmpdir,sizeof tmpdir,"%s%s",USER_DIR,username);
    if(dini_Exists(tmpdir)) return 1;
    else
    {
        dini_Create(tmpdir);
        dini_Set(tmpdir,"password",password);
    }
    return 1;
}

stock GetUserData(username[])
{
    new tmpdir[50];format(tmpdir,sizeof tmpdir,"%s%s",USER_DIR,username);
    new tmpbuff[512];
    if(dini_Exists(tmpdir))
    {
        format(tmpbuff,sizeof tmpbuff,dini_Get(tmpdir,"password"));
    }
    return tmpbuff;
}