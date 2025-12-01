param(
    [string]$SourceFile,
    [string]$TargetDirectory,
    [string]$DestinationDirectory,
    [string]$ActionType = "move"
)

# ==========================================
# Core Logic Functions
# ==========================================

function Get-PartsCount {
    param([string]$directory)
    if (-not (Test-Path $directory)) { return 0 }
    $partFiles = Get-ChildItem -Path $directory -Include "*.mkv", "*.mp4", "*.avi", "*.m4v" -Recurse -ErrorAction SilentlyContinue | 
    Where-Object { $_.Name -match "PART[0-9]" }
    return @($partFiles).Count
}

function Get-MediaType {
    param(
        [string]$filename,
        [int]$partsInDirectory = 0
    )
    if ($filename -match "S\d{2}\s*E\d{2}" -or 
        $filename -match "[\.\s]E\d{2}" -or
        $filename -match "Episode[\.\s]\d+" -or
        ($filename -match "PART[0-9]" -and $partsInDirectory -gt 1) -or
        ($filename -match "PART\s*[0-9]" -and $partsInDirectory -gt 1) -or
        $filename -match "\s-\s\d+\s\[") {
        return "tv"
    }
    return "movie"
}

function Parse-TVShow {
    param([string]$filename)
    if ($filename -match "(.+?)\s*S(\d{2})\s*E(\d{2})") {
        return @{ Name = ($matches[1] -replace "[\.\s]+", " ").Trim(); Season = [int]$matches[2]; Episode = [int]$matches[3]; Type = "tv" }
    }
    if ($filename -match "(.+?)\.S(\d{2})E(\d{2})") {
        return @{ Name = ($matches[1] -replace "\.", " ").Trim(); Season = [int]$matches[2]; Episode = [int]$matches[3]; Type = "tv" }
    }
    if ($filename -match "(.+?)[\.\s]PART\s*(\d+)[\.\s\(]") {
        return @{ Name = ($matches[1] -replace "[\.\s]+", " ").Trim(); Season = 1; Episode = [int]$matches[2]; Type = "tv" }
    }
    if ($filename -match "^\[.*?\]\s*(.+?)\s+-\s+(\d+)\s+\[") {
        return @{ Name = ($matches[1] -replace "[\.\s]+", " ").Trim(); Season = 1; Episode = [int]$matches[2]; Type = "tv" }
    }
    return $null
}

function Parse-Movie {
    param([string]$filename)
    if ($filename -match "(.+?)\.(\d{4})") {
        return @{ Name = ($matches[1] -replace "\.", " ").Trim(); Year = $matches[2]; Type = "movie" }
    }
    if ($filename -match "(.+?)\.(FRENCH|MULTI|VOSTFR|SUBFRENCH)") {
        return @{ Name = ($matches[1] -replace "\.", " ").Trim(); Year = "NO_YEAR"; Type = "movie" }
    }
    return $null
}

function Invoke-MediaOrganization {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileSystemInfo[]]$SourceItems,
        
        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,
        
        [string]$Action = "move"
    )

    $processedCount = 0
    $skippedCount = 0

    foreach ($item in $SourceItems) {
        # If item is a directory, process all video files inside
        $filesToProcess = @()
        if ($item.PSIsContainer) {
            $filesToProcess = Get-ChildItem -LiteralPath $item.FullName -Include "*.mkv", "*.mp4", "*.avi", "*.m4v" -Recurse -ErrorAction SilentlyContinue
        }
        else {
            $filesToProcess = @($item)
        }

        # Calculate parts count based on the parent directory of the first file (approximation for single file selection)
        $partsCount = 0
        if ($filesToProcess.Count -gt 0) {
            $partsCount = Get-PartsCount -directory $filesToProcess[0].DirectoryName
        }

        foreach ($file in $filesToProcess) {
            $mediaType = Get-MediaType -filename $file.Name -partsInDirectory $partsCount
            $info = $null
            
            if ($mediaType -eq "tv") {
                $info = Parse-TVShow -filename $file.BaseName
                if ($info) {
                    $destDir = Join-Path $DestinationPath "Series\$($info.Name)\Season $($info.Season.ToString('00'))"
                    $destFile = "$($info.Name) - S$($info.Season.ToString('00'))E$($info.Episode.ToString('00'))$($file.Extension)"
                }
            }
            else {
                $info = Parse-Movie -filename $file.BaseName
                if ($info) {
                    $destDir = if ($info.Year -eq "NO_YEAR") { Join-Path $DestinationPath "Movies\$($info.Name)" } else { Join-Path $DestinationPath "Movies\$($info.Name) ($($info.Year))" }
                    $destFile = if ($info.Year -eq "NO_YEAR") { "$($info.Name)$($file.Extension)" } else { "$($info.Name) ($($info.Year))$($file.Extension)" }
                }
            }
            
            if ($info) {
                Write-Host "Processing: $($file.Name) -> $destFile" -ForegroundColor Green
                if (!(Test-Path $destDir)) { New-Item -ItemType Directory -Path $destDir -Force | Out-Null }
                $destPath = Join-Path $destDir $destFile
                
                if ($Action -eq "move") {
                    Move-Item -LiteralPath $file.FullName -Destination $destPath -Force
                    Write-Host "Moved successfully!" -ForegroundColor Green
                }
                else {
                    Copy-Item -LiteralPath $file.FullName -Destination $destPath -Force
                    Write-Host "Copied successfully!" -ForegroundColor Yellow
                }
                $processedCount++
            }
            else {
                Write-Host "Skipping: $($file.Name) (could not parse)" -ForegroundColor Yellow
                $skippedCount++
            }
        }
        
        # Cleanup empty source folders if it was a move action and the item was a folder
        if ($Action -eq "move" -and $item.PSIsContainer -and (Test-Path $item.FullName)) {
            $remaining = Get-ChildItem -LiteralPath $item.FullName -Recurse -Force -ErrorAction SilentlyContinue
            if (-not $remaining) {
                Remove-Item -LiteralPath $item.FullName -Force -Recurse -ErrorAction SilentlyContinue
                Write-Host "Removed empty source folder: $($item.Name)" -ForegroundColor DarkGray
            }
        }
    }
    
    Write-Host "`nSummary: Processed $processedCount, Skipped $skippedCount" -ForegroundColor Cyan
}

# ==========================================
# TUI Implementation
# ==========================================

function Start-TUI {
    param(
        [string]$InitialSourcePath,
        [string]$InitialDestPath
    )

    # Hide cursor to prevent flickering
    try { [Console]::CursorVisible = $false } catch {}

    # UI State
    $state = @{
        LeftPath      = if ($InitialSourcePath -and (Test-Path $InitialSourcePath)) { (Get-Item $InitialSourcePath).FullName } else { "DRIVES" }
        RightPath     = if ($InitialDestPath -and (Test-Path $InitialDestPath)) { (Get-Item $InitialDestPath).FullName } else { "DRIVES" }
        ActivePanel   = "Left" # Left, Right, Bottom
        LeftCursor    = 0
        RightCursor   = 0
        LeftSelection = @{} # Hashset of paths
        LeftItems     = @()
        RightItems    = @()
        Action        = "move" # move, copy
        Running       = $true
        Message       = ""
    }
    
    # If InitialSourcePath was a file, set path to its directory and select it
    if ($InitialSourcePath -and (Test-Path $InitialSourcePath -PathType Leaf)) {
        $item = Get-Item $InitialSourcePath
        $state.LeftPath = $item.DirectoryName
        $state.LeftSelection[$item.FullName] = $true
    }

    $ui = $Host.UI.RawUI
    $ui.WindowTitle = "Media Organizer TUI"
    
    function Get-DirItems($path) {
        $items = @()
        
        if ($path -eq "DRIVES") {
            $drives = Get-PSDrive -PSProvider FileSystem
            foreach ($d in $drives) {
                $items += [PSCustomObject]@{ 
                    Name     = "$($d.Name) ($($d.Root))"; 
                    Mode     = "DRIVE"; 
                    FullName = $d.Root; 
                    IsParent = $false 
                }
            }
            return $items
        }

        # Add ".." entry
        $parent = Split-Path $path -Parent
        if (-not $parent) {
            # We are at root, so parent is Drive List
            $items += [PSCustomObject]@{ Name = ".."; Mode = "DIR"; FullName = "DRIVES"; IsParent = $true }
        }
        else {
            $items += [PSCustomObject]@{ Name = ".."; Mode = "DIR"; FullName = $parent; IsParent = $true }
        }
        
        try {
            $dirItems = Get-ChildItem -Path $path -ErrorAction SilentlyContinue | Sort-Object { $_.PSIsContainer }, Name -Descending
            foreach ($i in $dirItems) {
                $items += [PSCustomObject]@{ 
                    Name     = $i.Name; 
                    Mode     = if ($i.PSIsContainer) { "DIR" }else { "FILE" }; 
                    FullName = $i.FullName; 
                    IsParent = $false 
                }
            }
        }
        catch {
            $items += [PSCustomObject]@{ Name = "ACCESS DENIED"; Mode = "ERR"; FullName = $null; IsParent = $false }
        }
        return $items
    }

    # Initial Cache Population
    $state.LeftItems = Get-DirItems $state.LeftPath
    $state.RightItems = Get-DirItems $state.RightPath

    function Draw-UI {
        Clear-Host
        $rawSize = $ui.WindowSize
        if ($rawSize -is [array]) { $rawSize = $rawSize[0] }
        
        $w = $rawSize.Width
        if ($w -is [array]) { $w = $w[0] }
        [int]$width = $w

        $h = $rawSize.Height
        if ($h -is [array]) { $h = $h[0] }
        [int]$height = $h
        
        [int]$panelWidth = [math]::Floor(($width - 4) / 2)
        [int]$listHeight = $height - 8

        # Helper to truncate text
        function Trunc($t, $w) { if ($t.Length -gt $w) { $t.Substring(0, $w - 3) + "..." }else { $t.PadRight($w) } }

        # Helper to safely set cursor position
        function Set-Cursor($x, $y) {
            try {
                $ui.CursorPosition = New-Object System.Management.Automation.Host.Coordinates($x, $y)
            }
            catch {
                # If cursor positioning is not supported, we just continue. 
                # The output might be messy but it won't crash.
            }
        }

        # Draw Panels
        $leftItems = $state.LeftItems
        $rightItems = $state.RightItems

        # Draw Headers
        Set-Cursor 0 0
        $bgLeft = if ($state.ActivePanel -eq "Left") { "DarkBlue" } else { "Black" }
        Write-Host (Trunc (" " + $state.LeftPath) $panelWidth) -NoNewline -BackgroundColor $bgLeft -ForegroundColor White
        Write-Host "    " -NoNewline
        $bgRight = if ($state.ActivePanel -eq "Right") { "DarkBlue" } else { "Black" }
        Write-Host (Trunc (" " + $state.RightPath) $panelWidth) -BackgroundColor $bgRight -ForegroundColor White

        # Draw Lists
        for ($i = 0; $i -lt $listHeight; $i++) {
            $y = $i + 2
            
            # Left Panel
            Set-Cursor 0 $y
            if ($i -lt $leftItems.Count) {
                $item = $leftItems[$i]
                $isSelected = $state.LeftSelection.ContainsKey($item.FullName)
                $isCursor = ($i -eq $state.LeftCursor)
                
                $bg = "Black"; $fg = "Gray"
                if ($item.IsParent) { $fg = "Cyan" }
                if ($item.Mode -eq "DRIVE") { $fg = "Magenta" }
                if ($isSelected) { $fg = "Yellow" }
                if ($isCursor -and $state.ActivePanel -eq "Left") { $bg = "DarkCyan"; $fg = "White" }
                
                $prefix = if ($isSelected) { "*" }else { " " }
                Write-Host "$prefix $(Trunc $item.Name ($panelWidth-2))" -NoNewline -BackgroundColor $bg -ForegroundColor $fg
            }

            # Right Panel
            Set-Cursor ($panelWidth + 4) $y
            if ($i -lt $rightItems.Count) {
                $item = $rightItems[$i]
                $isCursor = ($i -eq $state.RightCursor)
                
                $bg = "Black"; $fg = "Gray"
                if ($item.IsParent) { $fg = "Cyan" }
                if ($item.Mode -eq "DRIVE") { $fg = "Magenta" }
                if ($isCursor -and $state.ActivePanel -eq "Right") { $bg = "DarkCyan"; $fg = "White" }
                
                Write-Host "  $(Trunc $item.Name ($panelWidth-2))" -NoNewline -BackgroundColor $bg -ForegroundColor $fg
            }
        }

        # Draw Bottom Panel (Action)
        Set-Cursor 0 ($height - 5)
        Write-Host ("-" * ($width - 1)) -ForegroundColor DarkGray
        
        $actionStr = " Action: "
        if ($state.Action -eq "move") { $actionStr += "[*] Move  [ ] Copy" } else { $actionStr += "[ ] Move  [*] Copy" }
        
        $bg = if ($state.ActivePanel -eq "Bottom") { "DarkBlue" } else { "Black" }
        Write-Host $actionStr -BackgroundColor $bg -ForegroundColor White
        
        Write-Host " [EXECUTE] (Press E)" -ForegroundColor Green
        
        if ($state.Message) {
            Write-Host "`n MSG: $($state.Message)" -ForegroundColor Yellow
        }
        
        # Help
        Set-Cursor 0 ($height - 1)
        Write-Host "TAB: Switch Panel | SPACE: Select | ENTER: Open | BACKSPACE/..: Up | M: Move | C: Copy | E: Execute | Q: Quit" -ForegroundColor DarkGray -NoNewline
    }

    while ($state.Running) {
        Draw-UI
        $key = $ui.ReadKey("NoEcho,IncludeKeyDown")
        
        if ($key.VirtualKeyCode -eq 9) {
            # TAB
            if ($state.ActivePanel -eq "Left") { $state.ActivePanel = "Right" }
            else { $state.ActivePanel = "Left" }
        }
        elseif ($key.VirtualKeyCode -eq 81) {
            # Q
            $state.Running = $false
        }
        elseif ($key.VirtualKeyCode -eq 38) {
            # UP
            if ($state.ActivePanel -eq "Left" -and $state.LeftCursor -gt 0) { $state.LeftCursor-- }
            if ($state.ActivePanel -eq "Right" -and $state.RightCursor -gt 0) { $state.RightCursor-- }
        }
        elseif ($key.VirtualKeyCode -eq 40) {
            # DOWN
            if ($state.ActivePanel -eq "Left") { $state.LeftCursor++ } # Boundary check needed strictly but lazy for now
            if ($state.ActivePanel -eq "Right") { $state.RightCursor++ }
        }
        elseif ($key.VirtualKeyCode -eq 32) {
            # SPACE
            if ($state.ActivePanel -eq "Left") {
                $items = $state.LeftItems
                if ($state.LeftCursor -lt $items.Count) {
                    $item = $items[$state.LeftCursor]
                    if (-not $item.IsParent -and $item.Mode -ne "DRIVE") {
                        if ($state.LeftSelection.ContainsKey($item.FullName)) { $state.LeftSelection.Remove($item.FullName) }
                        else { $state.LeftSelection[$item.FullName] = $true }
                    }
                }
            }
            if ($state.ActivePanel -eq "Bottom") {
                if ($state.Action -eq "move") { $state.Action = "copy" } else { $state.Action = "move" }
            }
        }
        elseif ($key.VirtualKeyCode -eq 13) {
            # ENTER
            if ($state.ActivePanel -eq "Left") {
                $items = $state.LeftItems
                if ($state.LeftCursor -lt $items.Count) {
                    $item = $items[$state.LeftCursor]
                    if ($item.Mode -eq "DIR" -or $item.IsParent -or $item.Mode -eq "DRIVE") {
                        if ($item.FullName) {
                            $state.LeftPath = $item.FullName
                            $state.LeftCursor = 0
                            $state.LeftItems = Get-DirItems $state.LeftPath
                        }
                    }
                }
            }
            elseif ($state.ActivePanel -eq "Right") {
                $items = $state.RightItems
                if ($state.RightCursor -lt $items.Count) {
                    $item = $items[$state.RightCursor]
                    if ($item.Mode -eq "DIR" -or $item.IsParent -or $item.Mode -eq "DRIVE") {
                        if ($item.FullName) {
                            $state.RightPath = $item.FullName
                            $state.RightCursor = 0
                            $state.RightItems = Get-DirItems $state.RightPath
                        }
                    }
                }
            }
        }
        elseif ($key.VirtualKeyCode -eq 8) {
            # BACKSPACE
            if ($state.ActivePanel -eq "Left") {
                if ($state.LeftPath -eq "DRIVES") { continue }
                $parent = Split-Path $state.LeftPath -Parent
                if ($parent) { $state.LeftPath = $parent; $state.LeftCursor = 0 }
                else { $state.LeftPath = "DRIVES"; $state.LeftCursor = 0 }
                $state.LeftItems = Get-DirItems $state.LeftPath
            }
            if ($state.ActivePanel -eq "Right") {
                if ($state.RightPath -eq "DRIVES") { continue }
                $parent = Split-Path $state.RightPath -Parent
                if ($parent) { $state.RightPath = $parent; $state.RightCursor = 0 }
                else { $state.RightPath = "DRIVES"; $state.RightCursor = 0 }
                $state.RightItems = Get-DirItems $state.RightPath
            }
        }
        elseif ($key.Character -eq 'm') { $state.Action = "move" }
        elseif ($key.Character -eq 'c') { $state.Action = "copy" }
        elseif ($key.Character -eq 'e') {
            # EXECUTE
            if ($state.LeftSelection.Count -eq 0) {
                $state.Message = "No items selected!"
            }
            else {
                Clear-Host
                Write-Host "Executing $($state.Action)..." -ForegroundColor Cyan
                $itemsToProcess = @()
                foreach ($path in $state.LeftSelection.Keys) {
                    $itemsToProcess += Get-Item -LiteralPath $path
                }
        
                Invoke-MediaOrganization -SourceItems $itemsToProcess -DestinationPath $state.RightPath -Action $state.Action
        
                $state.LeftItems = Get-DirItems $state.LeftPath
                $state.RightItems = Get-DirItems $state.RightPath
        
                Write-Host "`nPress any key to return to TUI..."
                $ui.ReadKey("NoEcho,IncludeKeyDown") | Out-Null
                $state.LeftSelection.Clear()
                $state.Message = "Operation Completed."
            }
        }
    }
    Clear-Host
    try { [Console]::CursorVisible = $true } catch {}
}

# ==========================================
# Main Execution Entry Point
# ==========================================

# Check if we have enough arguments for Headless mode
if ($TargetDirectory -and $DestinationDirectory) {
    Write-Host "Running in Headless Mode" -ForegroundColor Cyan
    if (-not (Test-Path $TargetDirectory)) { Write-Error "Source path not found: $TargetDirectory"; exit 1 }
    if (-not (Test-Path $DestinationDirectory)) { Write-Error "Destination path not found: $DestinationDirectory"; exit 1 }
    
    $sourceItem = Get-Item $TargetDirectory
    Invoke-MediaOrganization -SourceItems @($sourceItem) -DestinationPath $DestinationDirectory -Action $ActionType
}
else {
    # TUI Mode
    Start-TUI -InitialSourcePath $SourceFile -InitialDestPath $DestinationDirectory
}