@echo off
setlocal EnableDelayedExpansion

echo.
echo === Folder Scanner and Media Organizer ===
echo.

REM ========== CONFIG ==========
set "organizerScript=RunMediaOrganizer.cmd"
REM ============================

REM === 1. Récupération des arguments ===
set "scanPath=%~1"
set "destPath=%~2"
set "action=%~3"

REM Si dossier source absent → demander
if "%scanPath%"=="" (
    set /p scanPath="Chemin du dossier à scanner : "
)

if not exist "%scanPath%" (
    echo Erreur : le dossier "%scanPath%" n'existe pas.
    pause
    exit /b 1
)

REM Si destination absente → demander
if "%destPath%"=="" (
    set /p destPath="Chemin de destination : "
)

if not exist "%destPath%" (
    echo Erreur : le dossier de destination "%destPath%" n'existe pas.
    pause
    exit /b 1
)

REM Si action absente → demander
if "%action%"=="" (
    set /p action="Action (move/copy, defaut = move) : "
)

if "%action%"=="" set "action=move"

echo.
echo Source : %scanPath%
echo Destination : %destPath%
echo Action : %action%
echo.

REM === 2. Listage des sous-dossiers ===
echo Dossiers trouvés :
echo.

set /a index=0
for /d %%A in ("%scanPath%\*") do (
    set "folder[!index!]=%%A"
    echo !index! - %%~nxA
    set /a index+=1
)

echo.
set /p choice="Choisir un dossier (numéro) : "
echo.

if "!folder[%choice%]!"=="" (
    echo Erreur : index invalide.
    pause
    exit /b 1
)

set "selectedFolder=!folder[%choice%]!"
echo Vous avez choisi : %selectedFolder%
echo.

echo.
echo Exécution :
echo %organizerScript% "%selectedFolder%" "%destPath%" %action%
echo.

call "%organizerScript%" "%selectedFolder%" "%destPath%" %action%

echo.
echo Terminé ! Appuyez sur une touche pour fermer.
pause >nul
exit /b 0
