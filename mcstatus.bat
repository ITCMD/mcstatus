@echo off
::MCS mcstatus minecraft status checker 2 by Lukaka / Setlucas with ITCMD
::https://github.com/ITCMD/mcstatus2
::The first version sucked really bad and I lost the files.
::Epstein didn't kill himself.
@mode con lines=30 cols=100
setlocal EnableDelayedExpansion
:reload
title MCStatus V2.3 ^| By Lukaka ^|
del /f /q "%temp%\mcs*.json"
if exist "Bin\jq-win64.exe" cd Bin
cls
echo [90m====================================================================================================[32m
type logo.ascii
echo.
echo [90m====================================================================================================[32m
echo.
echo [90mPress S to enter settings . . .[0m
choice /c qs /t 2 /d q /n >nul 2>nul
if %errorlevel%==2 goto settings
if not exist "settings.ini" (
	echo [0mInitial Setup Required . . .[32m
	goto settings
)
cls
for /f %%A in (settings.ini) do (
set %%~A
)
if "%wait%"=="" set wait=300
if "%wait%"=="300" (
	set waitmessage=5 minutes
) ELSE (
	set waitmessage=%wait% seconds
)
if "%hostname%"=="" (
	echo [0mHostname not set.[3m
	goto settings
)
if "%port%"=="" set port=25565
if "%port%"=="%hostname%" set port=25565
for /f "tokens=1,2 delims=[]" %%A in ('ping %hostname% -n 1^| find "Pinging"') do set ip=%%B
:: optionally you may override the hostname processing, simply replace the variables below with format serverip_port
set serverid=%ip%_%port%
set session=%random%%random%
curl https://launchermeta.mojang.com/mc/game/version_manifest.json -o "%appdata%\minecraft_version_manifest.json" >nul 2>nul
if "%errorlevel%"=="0" (
	set mojang_release=ok
) ELSE (
	echo An error occured when fetching mojang release. Check github for update.
	set mojang_release=fail
	timeout /t 5
)
cls
:scan
timeout /t 1 /nobreak >nul 2>nul
title MCStatus V2.3 ^| By Lukaka ^| *
::pings server directly
curl -m 2 -s %ip%:%port% >nul 2>nul && set lstatus=1|| set lstatus=0

::downloads minecraft-statistic.net data
curl https://minecraft-statistic.net/api/server/info/%serverid% -o "%temp%\mcs%session%.json" >nul 2>nul
if not "%errorlevel%"=="0" (
	echo an Error Occured Querying minecraft-statistic.net.
	ping -n 1 google.com >nul
	if not errorlevel 0 echo You are offline.
	pause
	exit /b
)
::checks that server is on mcs
for /f "tokens=*" %%A in ('jq-win64 -r .status_query "%temp%\mcs%session%.json"') do (
	if "%%~A"=="server not found" (
		echo Server was not on mcs. Adding . . .
		curl https://minecraft-statistic.net/api/server/add/?ip=%ip%^&port=%port% -o "%temp%\mcsaddserver%session%.json" >nul 2>nul
		goto add
	)
)
::checks that scan is enabled
if "%scancheckoff%"=="" for /f "tokens=*" %%A in ('jq-win64 -r .scan "%temp%\mcs%session%.json"') do (if not "%%~A"=="1" goto scan_off)
::title
title MCStatus V2.3 ^| By Lukaka ^| #
::extracts info json
jq-win64 -r .info "%temp%\mcs%session%.json" >"%temp%\mcs%session%-info.json"
::extracts counter json
jq-win64 -r .counter "%temp%\mcs%session%.json" >"%temp%\mcs%session%-counter.json"
::tests mcs online/offline
for /f "tokens=*" %%A in ('jq-win64 -r .status "%temp%\mcs%session%.json"') do (
	set status=%%~A
)
rem extracts minecraft and server versions
for /f "tokens=*" %%A in ('jq-win64 -r .version "%temp%\mcs%session%-info.json"') do (set server_version=%%~A)
jq-win64 -r .latest "%appdata%\minecraft_version_manifest.json" >"%appdata%\minecraft_latest_info.json"
for /f "tokens=*" %%A in ('jq-win64 -r .release "%appdata%\minecraft_latest_info.json"') do (set latest_version=%%~A)
rem misc info from info
for /f "tokens=*" %%A in ('jq-win64 -r .software "%temp%\mcs%session%-info.json"') do (set server_software=%%~A)
for /f "tokens=*" %%A in ('jq-win64 -r .map "%temp%\mcs%session%-info.json"') do (set map=%%~A)
for /f "tokens=*" %%A in ('jq-win64 -r .name "%temp%\mcs%session%-info.json"') do (set motd=%%~A)
for /f "tokens=*" %%A in ('jq-win64 -r .max_players "%temp%\mcs%session%-info.json"') do (set max=%%~A)
set server_uptime=%val:~0,5%
::removes grtr and lss chars from motd (if there)
set "motd=%motd:^>=#%"
set "motd=%motd:<=#%"
::compares statuses
if "%status%"=="%lstatus%" (
	if "%status%"=="0" goto offline
)

::checks total player count
if not "%players%"=="" set oldplayers=%players%
for /f "tokens=*" %%A in ('jq-win64 -r .players "%temp%\mcs%session%-info.json"') do (
	set players=%%~A
)
set /a lines=27+%players%
@mode con lines=%lines% cols=100
if "%players%"=="0" goto datadisplay
if not "%oldplayers%"=="" (
	if %players% LSS %oldplayers% start "" /wait /min player_leave.vbs
	if %players% GTR %oldplayers% start "" /wait /min player_join.vbs
)

::gets online list and extracts array into variables
set num=1
for /f "tokens=*" %%A in ('jq-win64 -r .players_list "%temp%\mcs%session%-info.json"') do (
	if not "%%~A"=="" (
		if not "%%~A"=="[" (
			if not "%%~A"=="]" (
				set player!num!=%%~A
				set /a num+=1
			)
		)
	)
)
::removes quotes and commas from player names
set playernum=1
:playerloop
set player%playernum%=!player%playernum%:,=!
set player%playernum%=!player%playernum%:"=!
if %playernum%==%players% goto endplayerloop
set /a playernum+=1
goto playerloop
:endplayerloop

:datadisplay
echo [90m====================================================================================================[32m
title MCStatus V2.3 ^| By Lukaka ^| 
cls
type logo.ascii
echo.
echo [90m====================================================================================================[0m
echo                             Server Hostname: [[96m%hostname%[0m] [90m%port%[0m
::handles if statuses disagree
if not "%status%"=="%lstatus%" (
	if "%status%"=="0" (
		echo       Minecraft Statistics suggested status: [[91mOffline[0m]
		echo               Manual Server verified status: [[92mOnline[0m]
	) ELSE (
		echo    minecraft-statistic.net suggested status: [[91mOffline[0m]
		echo               Manual Server verified status: [[92mOnline[0m]
	)
) ELSE ( 
	echo                               Server Status: [[92mOnline[0m]
)
::checks if version is latest official mc version
if "%server_version%"=="%latest_version%" (
		echo                          Running MC Version: [[92m%server_version%[0m]
) ELSE (
		echo                          Running MC Version: [[33m%server_version%[0m]
)
::checks server software
echo %server_software% | find /i "Paper" >nul 2>nul
if "%errorlevel%"=="0" (
	echo                                 On Software: [%server_software%]
) ELSE (
	echo %server_software% | find /i "Spigot" >nul 2>nul
		if "%errorlevel%"=="0" (
			echo                                 On Software: [[96m%server_software%[0m]
		) ELSE (
			echo %server_software% | find /i "BungeeCord" >nul 2>nul
			if "%errorlevel%"=="0" (
				echo                                 On Software: [[33m%server_software%[0m]
			) ELSE (	
				echo                                 On Software: [[95m%server_software%[0m]
			)
		)
	)
)
::checks server world map name
if /i not "%map%"=="World" echo     
::checks uptime                         World Map Name: [[96m%world%[0m]
for /f "tokens=*" %%A in ('jq-win64 -r .uptime "%temp%\mcs%session%.json"') do (set server_uptime=%%~A)
if %server_uptime% LSS 80 (
	if %server_uptime% LSS 50 (
		echo                       Server Average Uptime: [[91m%server_uptime%%%[0m]
	) ELSE (
		echo                       Server Average Uptime: [[93m%server_uptime%%%[0m]
	)
) ELSE (
	echo                       Server Average Uptime: [[92m%server_uptime%%%[0m]
)
echo                                 Server MOTD: [[36m%motd%[0m]
echo [90m====================================================================================================[0m
echo [44;97mPLAYER LIST     %players% / %max%[0m
if "%players%"=="0" goto noplayers
:listplayers
set num=1
:listloop
:: I know theres a better way to do this, but screw it.
:: adds zero to single diget values so it looks pretty
:: a better way to do this would be to check if the string is 1+ character and if not add a zero but meh
if %num% GTR 9 set displaynum=%num%
if %num%==1 set displaynum=01
if %num%==2 set displaynum=02
if %num%==3 set displaynum=03
if %num%==4 set displaynum=04
if %num%==5 set displaynum=05
if %num%==6 set displaynum=06
if %num%==7 set displaynum=07
if %num%==8 set displaynum=08
if %num%==9 set displaynum=09
::prints name
echo                                   Player !displaynum!: [[92m!player%num%![0m]
::checks if all variables have been read
::ends it all
if "%num%"=="%players%" goto wait
set /a num+=1
goto listloop

:add
::note: actual addition happens at reload chunk with curl
echo Server Addition Response Code:
type "%temp%\mcsaddserver%session%.json"
echo.
echo Scan may not have occured yet. Waiting at least 5 minutes after adding a server is recommended.
pause
goto reload

:settings
echo Enter hostname or static IP address of Minecraft Server:[0m
set /p hostname=">[96m"
echo [3mEnter Port (default is 25565):[0m
set /p port=">[96m"
(echo hostname=%hostname%)>settings.ini
(echo port=%port%)>>settings.ini
(echo wait=300)>>settings.ini
goto reload

:scan_off
echo Server was found on minecraft-statistics, however, scanning is dissabled.
echo.
echo This means that the data on the server will be severly outdated.
echo.
echo This happens when uptime is below 5%.
echo.
echo To enable scanning, press the green "On" button below "Excluded from monitoring"
echo on the mcs webpage.
echo.
echo Open this page now?
choice
if "%errorlevel%"=="1" (
	start https://minecraft-statistic.net/en/server/%ip%_%port%.html
) ELSE (
	echo Data will be outdated and may be years old.
	pause
	set scancheckoff=Shits given: 0
	goto :continuefromscanoff
)
echo Data will take up to 5 minutes to update.
pause
goto reload



:wait
echo.
echo [90m====================================================================================================[0m
echo [90mWaiting %waitmessage% before continuing . . .[0m
timeout /t %wait% /nobreak >nul
goto scan

:offline
title MCStatus V2.3 ^| By Lukaka ^| Offline
cls
echo [91mServer is Offline[0m
echo.
echo Server did not respond to ping request.
echo mcs database status shows an offline server.
echo.
echo Last Data:
::go to displaydata for a more in-depth description of this crap.
if "%mojang_release%"=="ok" (
	if "%server_version%"=="%latest_version%" (
			echo                          Running MC Version: [[92m%server_version%[0m]
	) ELSE (
			echo                          Running MC Version: [[33m%server_version%[0m]
	)
) ELSE (
	echo                          Running MC Version: [[92m%server_version%[0m]
)
echo %server_software% | find /i "Paper" >nul 2>nul
if "%errorlevel%"=="0" (
	echo                                 On Software: [[97m%server_software%[0m]
) ELSE (
	echo %server_software% | find /i "Spigot" >nul 2>nul
		if "%errorlevel%"=="0" (
			echo                                 On Software: [[96m%server_software%[0m]
		) ELSE (
			echo %server_software% | find /i "BungeeCord" >nul 2>nul
			if "%errorlevel%"=="0" (
				echo                                 On Software: [[33m%server_software%[0m]
			) ELSE (	
				echo                                 On Software: [[95m%server_software%[0m]
			)
		)
	)
)
if /i not "%map%"=="World" echo                              World Map Name: [[96m%world%[0m]
for /f "tokens=*" %%A in ('jq-win64 -r .uptime "%temp%\mcs%session%.json"') do (set server_uptime=%%~A)
if %server_uptime% LSS 80 (
	if %server_uptime% LSS 50 (
		echo                       Server Average Uptime: [[91m%server_uptime%%%[0m]
	) ELSE (
		echo                       Server Average Uptime: [[93m%server_uptime%%%[0m]
	)
) ELSE (
	echo                       Server Average Uptime: [[92m%server_uptime%%%[0m]
)
echo.
goto wait




:noplayers
echo           According to Minecraft Statistics: [[91mNO PLAYERS[0m]
goto wait