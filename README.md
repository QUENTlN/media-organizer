# Media Organizer

A powerful PowerShell-based tool to organize your media library (Movies and TV Series). It automatically detects media types, renames files to a standard format, and moves or copies them to a structured destination.

## Features

-   **Smart Detection**: Automatically identifies Movies and TV Series based on filenames (supports patterns like `S01E01`, `Year`, `PART1`, etc.).
-   **Structured Organization**:
    -   **Series**: `Destination\Series\Show Name\Season XX\Show Name - SXXEXX.ext`
    -   **Movies**: `Destination\Films\Movie Name (Year)\Movie Name (Year).ext`
-   **Dual Modes**:
    -   **Interactive TUI**: A text-based user interface inspired by file managers like Midnight Commander.
    -   **Headless Mode**: Fully automated command-line execution (great for post-processing scripts).
-   **Flexible Actions**: Choose between **Move** or **Copy**.
-   **Manual Override**: Force "Movie" or "Serie" mode if auto-detection is ambiguous.
-   **Cleanup**: Automatically removes empty source folders after moving files.

## Prerequisites

-   Windows OS
-   PowerShell 5.1 or later

## Usage

### 1. Interactive TUI (Text User Interface)

Simply run the executable, the script, or the batch file without arguments to launch the interactive interface.

```powershell
".\Media Organizer.exe"
# OR
.\MediaOrganizer.ps1
# OR
.\MediaOrganizer.bat
```

**Controls:**
-   **TAB**: Switch focus between Left Panel (Source), Right Panel (Destination), and Bottom Panel (Options).
-   **UP/DOWN**: Navigate lists.
-   **SPACE**:
    -   *Left Panel*: Select/Deselect files or folders.
    -   *Bottom Panel*: Toggle options (Move/Copy or Media Type).
-   **ENTER**: Open directory.
-   **BACKSPACE**: Go to parent directory.
-   **Shortcuts**:
    -   `M`: Set action to **Move**.
    -   `C`: Set action to **Copy**.
    -   `T`: Cycle Media Type (**Auto** / **Movie** / **Serie**).
    -   `E`: **Execute** the selected operation.
    -   `Q`: **Quit**.

#### Creating a Shortcut with Default Paths

You can create a Windows Shortcut to open the TUI directly in specific folders.

1.  Right-click `Media Organizer.exe` > **Create shortcut**.
2.  Right-click the new shortcut > **Properties**.
3.  In the **Target** field, add the paths using named parameters after the quote:

    via exe

    ```text
    "...\Media Organizer.exe" "C:\Downloads" "D:\Media"
    ```
    via batch

    ```text
    "...\MediaOrganizer.bat" "C:\Downloads" "D:\Media"
    ```

    via powershell

    ```text
    "...\MediaOrganizer.ps1" -SourceFile "C:\Downloads" -DestinationDirectory "D:\Media"
    ```
    *Note: We use `-SourceFile` instead of the headless `-TargetDirectory` to ensure it stays in TUI mode.*

### 2. Headless / Command Line

You can run the organizer in headless mode for automation.

**Syntax:**
```cmd
RunMediaOrganizer.cmd <SourcePath> <DestinationPath> [move|copy] [Auto|Movie|Serie]
```

**Parameters:**
-   `SourcePath`: The directory or file to process.
-   `DestinationPath`: The root folder where `Films` and `Series` folders will be created.
-   `Action`: `move` (default) or `copy`.
-   `MediaType`: `Auto` (default), `Movie`, or `Serie`.

**Examples:**

*Organize a specific download folder:*
```cmd
RunMediaOrganizer.cmd "C:\Downloads\NewEpisode" "D:\Media" move Auto
```

*Force processing as a Movie:*
```cmd
RunMediaOrganizer.cmd "C:\Downloads\UnknownFile" "D:\Media" move Movie
```

### 3. Integration (e.g., qBittorrent)

You can use this script to automatically organize downloads upon completion.

**Run external program on torrent completion:**
```cmd
"C:\Path\To\RunMediaOrganizer.cmd" "%F" "D:\Media" move Auto
```
*Note: `%F` is the content path parameter in qBittorrent.*

## Project Structure

-   `Media Organizer.exe`: Compiled executable version for easy launching.
-   `MediaOrganizer.ps1`: The core PowerShell script containing logic and TUI.
-   `RunMediaOrganizer.cmd`: Wrapper for CMD/Batch usage (handles argument parsing).
-   `MediaOrganizer.bat`: Simple wrapper to launch the PS1 script.

## Customization

You can modify the `Parse-TVShow` and `Parse-Movie` functions in `MediaOrganizer.ps1` to adjust regex patterns for file detection if needed.
