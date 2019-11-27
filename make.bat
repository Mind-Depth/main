cls
cd %~dp0

set ore=%~dp0ORE\
set output=%~dp0build\
set tmp=build-tmp\
set venv=.venv\

call :find_unity_install
if %errorlevel% neq 0 goto :eof

call :init_directories
call :build_middleware
call :build_launcher
call :build_ore
call :build_apk
call :build_unity
call :create_entry_point

:: ------------------------- END OF MAIN -------------------------
goto :eof

:: ------------------------- INIT DIRECTORIES -------------------------
:init_directories
mkdir %ore%
mkdir %output%
mkdir %output%Logs
call :clone acquisition rush
call :clone generation reboot
call :clone environnement build
python -m venv %venv%
%venv%Scripts\pip.exe install pyinstaller pyqt5ac ^
	-r generation\requirements.txt ^
	-r acquisition\MiddleV2\requirements.txt ^
	-r acquisition\ORengine\requirements.txt
exit /b 0

:: ------------------------- FIND UNITY INSTALL -------------------------
:find_unity_install
set vbs=script.vbs
set unity_match=Unity 2018.3.*
for /f "tokens=*" %%i in (
	'dir /s /b "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\%unity_match%"'
) do if exist "%%i\Unity.lnk" set unity="%%i\Unity.lnk"
if %unity%=="" exit /b 1
echo set WshShell = WScript.CreateObject("WScript.Shell")>%vbs%
echo set Lnk = WshShell.CreateShortcut(WScript.Arguments.Unnamed(0))>>%vbs%
echo wscript.Echo Lnk.TargetPath>>%vbs%
for /f "tokens=*" %%i in ( 'cscript //nologo %vbs% %unity%' ) do set unity="%%i"
del %vbs%
exit /b 0

:: ------------------------- LAUNCHER -------------------------
:build_launcher
set entry=Launcher
set input=generation\
set ui="tmp.yml"
(
echo ioPaths:
echo -
echo ^ - "%input%\qt\\*.qrc"
echo ^ - "%input%\src\\%%%%FILENAME%%%%_rc.py"
)>"%ui%"
%venv%Scripts\pyqt5ac.exe --config %ui%
del %ui%
%venv%Scripts\pyinstaller.exe --windowed -y --distpath %output% --workpath %tmp% %input%src\%entry%.py
if %errorlevel% neq 0 exit /b %errorlevel%
del %entry%.spec
rmdir /Q /s %tmp%
xcopy /I /Y %input%config %output%config
exit /b 0

:: ------------------------- UNITY -------------------------
:build_unity
echo UNITY BUILD CAN TAKE A WHILE -- DO NOT KILL THE PROCESS
%unity% -quit -batchmode -projectPath environnement -buildWindows64Player %output%Unity\Environment.exe
exit /b %errorlevel%

:: ------------------------- APK -------------------------
:build_apk
set polar=acquisition\PolarConnectApp\
call %polar%gradlew.bat -p %polar% -P buildDir=%output%\PolarConnect assembleRelease
if %errorlevel% neq 0 exit /b %errorlevel%
copy /Y %output%\PolarConnect\outputs\apk\release\app-release.apk %output%\PolarConnect.apk
rmdir /Q /s %output%\PolarConnect
exit /b 0

:: ------------------------- MIDDLEWARE -------------------------
:build_middleware
set entry=Middleware
%venv%Scripts\pyinstaller.exe --windowed -y --distpath %output% --workpath %tmp% acquisition\MiddleV2\%entry%.py
if %errorlevel% neq 0 exit /b %errorlevel%
del %entry%.spec
rmdir /Q /s %tmp%
exit /b 0

:: ------------------------- ORE -------------------------
:build_ore
set entry=OnionRingEngineHTTPServer
%venv%Scripts\pyinstaller.exe -y ^
	--distpath %ore% ^
	--workpath %tmp% ^
	--add-data acquisition\ORengine\TrainingDataset*;TrainingDataset ^
	--add-data %venv%xgboost*;xgboost ^
	--add-data %venv%Lib\site-packages\xgboost\VERSION;xgboost ^
	--paths %venv%Lib\site-packages\scipy\.libs ^
	--hidden-import sklearn.base.BaseEstimator ^
	--hidden-import sklearn.base.RegressorMixin ^
	--hidden-import sklearn.base.ClassifierMixin ^
	--hidden-import sklearn.preprocessing.LabelEncoder ^
	--hidden-import sklearn.model_selection.KFold ^
	--hidden-import sklearn.model_selection.StratifiedKFold ^
	--hidden-import sklearn.utils._cython_blas ^
	acquisition\ORengine\%entry%.py
if %errorlevel% neq 0 exit /b %errorlevel%
del %entry%.spec
rmdir /Q /s %tmp%
echo %%~dp0%entry%\%entry%.exe > %ore%start.bat
exit /b 0

:: ------------------------- GIT -------------------------
:clone
git clone --single-branch --branch %2 https://github.com/Mind-Depth/%1.git
exit /b 0

:: ------------------------- CREATE ENTRY POINT -------------------------
:create_entry_point
set e=Environment
set m=Middleware
set l=Launcher
echo taskkill /im %e%.exe /im %m%.exe /im %l%.exe /f 2^> NUL^

set PYQTGRAPH_QT_LIB=PyQt5^

set PATH=%%PATH%%;%%~dp0%l%\^

start %%~dp0%l%\%l%.exe^

start %%~dp0%m%\%m%.exe^

pushd %%~dp0Unity^

start %e%.exe> %output%start.bat
exit /b 0
