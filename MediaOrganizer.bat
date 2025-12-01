@echo off
powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0MediaOrganizer.ps1" -SourceFile "%~1" -DestinationDirectory "%~2" -ActionType "%~3" -MediaType "%~4"