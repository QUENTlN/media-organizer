param(
    [Parameter(Mandatory=$true)]
    [string]$SourcePath,
    
    [Parameter(Mandatory=$true)]
    [string]$OutputPath,
    
    [string]$Action = "move"
)

function Get-PartsCount {
    param([string]$directory)
    
    $partFiles = Get-ChildItem -Path $directory -Include "*.mkv","*.mp4","*.avi","*.m4v" -Recurse | 
                 Where-Object { $_.Name -match "PART[0-9]" }
    return $partFiles.Count
}

function Get-MediaType {
    param(
        [string]$filename,
        [int]$partsInDirectory = 0
    )
    # Si c'est clairement une série (contient SxxExx ou des espaces), retourne tv
    if ($filename -match "S\d{2}\s*E\d{2}" -or 
        $filename -match "[\.\s]E\d{2}" -or
        $filename -match "Episode[\.\s]\d+" -or
        ($filename -match "PART[0-9]" -and $partsInDirectory -gt 1) -or
        ($filename -match "PART\s*[0-9]" -and $partsInDirectory -gt 1)) {
        return "tv"
    }
    
    return "movie"
}

function Parse-TVShow {
    param([string]$filename)
    # Format avec espaces: "Show Name S01E01 Extra Info"
    if ($filename -match "(.+?)\s*S(\d{2})\s*E(\d{2})") {
        $showName = $matches[1] -replace "[\.\s]+", " "
        $season = [int]$matches[2]
        $episode = [int]$matches[3]
        return @{
            Name = $showName.Trim()
            Season = $season
            Episode = $episode
            Type = "tv"
        }
    }
    # Format avec points
    if ($filename -match "(.+?)\.S(\d{2})E(\d{2})") {
        $showName = $matches[1] -replace "\.", " "
        $season = [int]$matches[2]
        $episode = [int]$matches[3]
        return @{
            Name = $showName.Trim()
            Season = $season
            Episode = $episode
            Type = "tv"
        }
    }
    # Pattern PART inchangé
    if ($filename -match "(.+?)[\.\s]PART\s*(\d+)[\.\s\(]") {
        $showName = $matches[1] -replace "[\.\s]+", " "
        $partNumber = [int]$matches[2]
        return @{
            Name = $showName
            Season = 1
            Episode = $partNumber
            Type = "tv"
        }
    }
    return $null
}

function Parse-Movie {
    param([string]$filename)
    
    # Premier pattern : nom + année
    if ($filename -match "(.+?)\.(\d{4})") {
        $movieName = $matches[1] -replace "\.", " "
        $year = $matches[2]
        return @{
            Name = $movieName.Trim()
            Year = $year
            Type = "movie"
        }
    }
    
    # Deuxième pattern : nom + FRENCH/MULTI/etc.
    if ($filename -match "(.+?)\.(FRENCH|MULTI|VOSTFR|SUBFRENCH)") {
        $movieName = $matches[1] -replace "\.", " "
        return @{
            Name = $movieName.Trim()
            Year = "NO_YEAR"
            Type = "movie"
        }
    }
    
    return $null
}

# Main processing
$Host.UI.RawUI.WindowTitle = "Media Organizer"
Write-Host "Starting media organization..." -ForegroundColor Cyan

$partsCount = 0
if (Test-Path $SourcePath -PathType Container) {
    $partsCount = Get-PartsCount -directory $SourcePath
    $files = Get-ChildItem -Path $SourcePath -Include "*.mkv","*.mp4","*.avi","*.m4v" -Recurse
} else {
    $files = @(Get-Item $SourcePath)
}

$processedCount = 0
$skippedCount = 0

foreach ($file in $files) {
    $mediaType = Get-MediaType -filename $file.Name -partsInDirectory $partsCount
    $info = $null
    
    if ($mediaType -eq "tv") {
        $info = Parse-TVShow -filename $file.BaseName
        if ($info) {
            $destDir = Join-Path $OutputPath "Series\$($info.Name)\Season $($info.Season.ToString('00'))"
            $destFile = "$($info.Name) - S$($info.Season.ToString('00'))E$($info.Episode.ToString('00'))$($file.Extension)"
        }
    } else {
        $info = Parse-Movie -filename $file.BaseName
        if ($info) {
            $destDir = if ($info.Year -eq "NO_YEAR") {
                Join-Path $OutputPath "Films\$($info.Name)"
            } else {
                Join-Path $OutputPath "Films\$($info.Name) ($($info.Year))"
            }
            $destFile = if ($info.Year -eq "NO_YEAR") {
                "$($info.Name)$($file.Extension)"
            } else {
                "$($info.Name) ($($info.Year))$($file.Extension)"
            }
        }
    }
    
    if ($info) {
        Write-Host "Processing: $($file.Name) -> $destFile" -ForegroundColor Green
        
        if (!(Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir -Force | Out-Null
        }
        
        $destPath = Join-Path $destDir $destFile
        
        if ($Action -eq "move") {
            Move-Item -Path $file.FullName -Destination $destPath -Force
            Write-Host "Moved successfully!" -ForegroundColor Green
        } else {
            Copy-Item -Path $file.FullName -Destination $destPath -Force
            Write-Host "Copied successfully!" -ForegroundColor Yellow
        }
        $processedCount++
    } else {
        Write-Host "Skipping: $($file.Name) (could not parse)" -ForegroundColor Yellow
        $skippedCount++
    }
}

Write-Host "`nSummary:" -ForegroundColor Cyan
Write-Host "Processed: $processedCount files" -ForegroundColor Green
Write-Host "Skipped: $skippedCount files" -ForegroundColor Yellow

# Supprimer le dossier source si tous les fichiers ont été traités
if ($skippedCount -eq 0 -and $processedCount -gt 0 -and (Test-Path $SourcePath -PathType Container)) {
    try {
        Remove-Item -Path $SourcePath -Recurse -Force
        Write-Host "Source folder deleted successfully!" -ForegroundColor Green
    }
    catch {
        Write-Host "Warning: Could not delete source folder: $($_.Exception.Message)" -ForegroundColor Yellow
    }
}

Write-Host "Organization complete!" -ForegroundColor Cyan