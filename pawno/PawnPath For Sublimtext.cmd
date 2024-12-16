@echo off
echo.
echo.        SSSSSSSS       GGGGGGGGG
echo.       SS      SS     GG       GG
echo.       SS             GG
echo.        SSSSSSSS      GG    GGGG
echo.               SS     GG       GG
echo.       SS      SS     GG       GG
echo.        SSSSSSSS       GGGGGGGGG
echo.
echo. ===========================================
echo. Sublime Text Pawn Configer By fairytales  
echo. Telegram : @shadow_gaming_original        
echo. Private : @fairytalesShadow               
echo. ===========================================
echo. Please Wait For Configuration			   
set emsLoc=%cd%
set cLoc=%cd:\=/%
set txt={"cmd":["pawncc.exe","-i include","$file","-;+"],"path":"%cLoc%"}
cd /d c:
cd "%appdata%"
if not exist "Sublime Text" (mkdir "Sublime Text")
cd "Sublime Text"
if not exist "Packages" (mkdir "Packages") 
cd "Packages"
if not exist "User" (mkdir "User") 
cd "User"
if not exist Pawn.sublime-build (fsutil file createnew Pawn.sublime-build 0)
echo %txt% > Pawn.sublime-build
echo. End Of The Configuration 				   
echo. ===========================================
pause