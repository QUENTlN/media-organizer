@echo off
setlocal EnableDelayedExpansion

REM Si lancé depuis qBittorrent, utiliser les variables d'environnement
if not "%F=%"=="" (
    set "source=%F"
) else (
    set "source=%~1"
)

if not "%D=%"=="" (
    set "output=%D"
) else (
    set "output=%~2"
)

set "action=%~3"
set "mediatype=%~4"

if "!source!"=="" (
    echo Error: Source path is required
    goto :usage
)
if "!output!"=="" (
    echo Error: Output path is required
    goto :usage
)
if "!action!"=="" set "action=move"
if "!mediatype!"=="" set "mediatype=Auto"

powershell.exe -NoProfile -ExecutionPolicy Bypass -Command "& '%~dp0MediaOrganizer.ps1' -TargetDirectory '!source!' -DestinationDirectory '!output!' -ActionType '!action!' -MediaType '!mediatype!'"
exit /b 0

:usage
echo Usage: RunMediaOrganizer.cmd source_path output_path [move^|copy] [Auto^|Movie^|Serie]
echo Example: RunMediaOrganizer.cmd "C:\Downloads\Series" "D:\Media" move Auto
exit /b 1
