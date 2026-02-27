# ============================================================
#  stream-watcher.ps1
#  Automatically downloads YouTube live streams using yt-dlp
#  Downloads video and live chat simultaneously
#
#  REQUIREMENTS:
#    - yt-dlp:  winget install yt-dlp
#    - ffmpeg:  winget install ffmpeg
#
#  FIRST TIME SETUP:
#    1. Install yt-dlp and ffmpeg (commands above)
#    2. Open PowerShell and run:
#       Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
#    3. Edit the CONFIGURATION section below
#    4. Right-click this file > "Run with PowerShell"
# ============================================================

# ============================================================
#  CONFIGURATION --- Edit these values before running
# ============================================================

# Channels to watch. Add one URL per line inside the @( )
# Format: "https://www.youtube.com/@ChannelName"
$Channels = @(
    "https://www.youtube.com/@ChannelNameHere"
    # "https://www.youtube.com/@AnotherChannel"
    # "https://www.youtube.com/@YetAnotherChannel"
)

# Where to save downloaded streams
# Examples:
#   "$env:USERPROFILE\StreamBackups"   <- saves to your user folder
#   "D:\StreamBackups"                 <- saves to D drive
#   "E:\YouTube\Archives"              <- saves to external drive
$OutputDir = "$env:USERPROFILE\StreamBackups"

# How often to check if a channel is live (in seconds)
# 60 = once per minute. Do not go below 30.
$CheckInterval = 60

# Show a Windows pop-up notification when a stream is detected?
$EnableNotifications = $true

# Save thumbnail, description, and metadata alongside the video?
$SaveMetadata = $true

# Minimum free disk space required before starting a download (in GB)
# Script will warn you and skip the download if space is below this
$MinFreeDiskGB = 20

# Automatically update yt-dlp each time the script starts?
# Recommended - keeps it working when YouTube makes changes
$AutoUpdate = $true

# ============================================================
#  SCRIPT --- No need to edit below this line
# ============================================================

$LogFile = "$OutputDir\watcher.log"

function Write-Log($message, $color = "White") {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] $message"
    Write-Host $line -ForegroundColor $color
    if (Test-Path $OutputDir) {
        Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue
    }
}

function Show-Notification($title, $message) {
    if (-not $EnableNotifications) { return }
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $notify = New-Object System.Windows.Forms.NotifyIcon
        $notify.Icon = [System.Drawing.SystemIcons]::Information
        $notify.BalloonTipTitle = $title
        $notify.BalloonTipText = $message
        $notify.Visible = $true
        $notify.ShowBalloonTip(8000)
        Start-Sleep -Seconds 1
        $notify.Dispose()
    } catch {}
}

function Check-Dependencies {
    $missing = @()
    if (-not (Get-Command yt-dlp -ErrorAction SilentlyContinue)) { $missing += "yt-dlp" }
    if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) { $missing += "ffmpeg" }
    if ($missing.Count -gt 0) {
        Write-Log "ERROR: Missing required tools: $($missing -join ', ')" "Red"
        Write-Log "Install with: winget install $($missing -join ' ; winget install ')" "Yellow"
        Write-Log "Then restart this script." "Yellow"
        Read-Host "Press Enter to exit"
        exit 1
    }
    Write-Log "yt-dlp and ffmpeg found. All good!" "Green"
}

function Update-YtDlp {
    if (-not $AutoUpdate) { return }
    Write-Log "Checking for yt-dlp updates..." "Gray"
    try {
        $result = & yt-dlp -U 2>&1
        if ($result -match "up-to-date") {
            Write-Log "yt-dlp is already up to date." "Gray"
        } else {
            Write-Log "yt-dlp updated successfully." "Green"
        }
    } catch {
        Write-Log "Could not update yt-dlp (continuing with current version): $_" "Yellow"
    }
}

function Get-FreeDiskGB($path) {
    try {
        $drive = Split-Path -Qualifier $path
        $disk  = Get-PSDrive -Name $drive.TrimEnd(':') -ErrorAction SilentlyContinue
        if ($disk) { return [math]::Round($disk.Free / 1GB, 1) }
        $wmi = Get-WmiObject Win32_LogicalDisk | Where-Object { $path -like "$($_.DeviceID)*" }
        if ($wmi) { return [math]::Round($wmi.FreeSpace / 1GB, 1) }
    } catch {}
    return $null
}

function Test-DiskSpace($path) {
    $freeGB = Get-FreeDiskGB $path
    if ($null -eq $freeGB) {
        Write-Log "Could not determine free disk space - proceeding anyway." "Yellow"
        return $true
    }
    if ($freeGB -lt $MinFreeDiskGB) {
        Write-Log "LOW DISK SPACE: Only ${freeGB}GB free (minimum ${MinFreeDiskGB}GB). Skipping download!" "Red"
        Show-Notification "Stream Watcher - Low Disk!" "Only ${freeGB}GB free. Download skipped. Free up space!"
        return $false
    }
    Write-Log "Disk space OK: ${freeGB}GB free." "Gray"
    return $true
}

function Get-FileSizeReadable($path) {
    try {
        $file = Get-ChildItem $path -Filter "*.mp4" -ErrorAction SilentlyContinue |
                Sort-Object LastWriteTime -Descending |
                Select-Object -First 1
        if ($file) {
            $sizeGB = [math]::Round($file.Length / 1GB, 2)
            $sizeMB = [math]::Round($file.Length / 1MB, 0)
            if ($sizeGB -ge 1) { return "$sizeGB GB - $($file.Name)" }
            else                { return "$sizeMB MB - $($file.Name)" }
        }
    } catch {}
    return "unknown size"
}

function Test-AlreadyDownloading($channelFolder) {
    $partFiles = Get-ChildItem $channelFolder -Filter "*.part" -ErrorAction SilentlyContinue
    $ytdlFiles = Get-ChildItem $channelFolder -Filter "*.ytdl" -ErrorAction SilentlyContinue
    return ($partFiles.Count -gt 0 -or $ytdlFiles.Count -gt 0)
}

function Watch-Channel($channelUrl) {
    $channelName = ($channelUrl -split "@")[-1].Split("/")[0]
    $liveUrl     = "$channelUrl/live"
    $channelDir  = "$OutputDir\$channelName"

    while ($true) {
        try {
            Write-Log "[$channelName] Checking for live stream..." "Gray"

            $liveCheck = & yt-dlp --get-url --no-warnings -q $liveUrl 2>$null

            if ($liveCheck) {

                # Guard: already downloading?
                New-Item -ItemType Directory -Force -Path $channelDir | Out-Null
                if (Test-AlreadyDownloading $channelDir) {
                    Write-Log "[$channelName] Download already in progress - skipping duplicate." "Yellow"
                    Start-Sleep -Seconds $CheckInterval
                    continue
                }

                # Guard: enough disk space?
                if (-not (Test-DiskSpace $OutputDir)) {
                    Start-Sleep -Seconds 300
                    continue
                }

                Write-Log "[$channelName] LIVE STREAM DETECTED! Starting download..." "Red"
                Show-Notification "Stream Watcher" "$channelName just went live! Downloading now..."

                $outputTemplate = "$channelDir\%(upload_date)s_%(title)s.%(ext)s"

                # VIDEO download (no chat flags - runs as separate process)
                $ytArgsVideo = @(
                    "--output",              $outputTemplate,
                    "--merge-output-format", "mp4",
                    "--live-from-start",
                    "--no-part",
                    "--retries",             "10",
                    "--fragment-retries",    "10",
                    "--retry-sleep",         "5",
                    "--no-update"
                )
                if ($SaveMetadata) {
                    $ytArgsVideo += "--write-thumbnail"
                    $ytArgsVideo += "--write-description"
                    $ytArgsVideo += "--write-info-json"
                }
                $ytArgsVideo += $liveUrl

                # CHAT download (separate process, skips video)
                $ytArgsChat = @(
                    "--output",        $outputTemplate,
                    "--skip-download",
                    "--write-subs",
                    "--sub-langs",     "live_chat",
                    "--live-from-start",
                    "--no-update",
                    $liveUrl
                )

                # Start both simultaneously
                Write-Log "[$channelName] Starting video download..." "Gray"
                $videoJob = Start-Job -ScriptBlock {
                    param($ytArgs) & yt-dlp @ytArgs
                } -ArgumentList (,$ytArgsVideo)

                Write-Log "[$channelName] Starting chat download..." "Gray"
                $chatJob = Start-Job -ScriptBlock {
                    param($ytArgs) & yt-dlp @ytArgs
                } -ArgumentList (,$ytArgsChat)

                # Wait for both to finish, relay output
                while ($videoJob.State -eq "Running" -or $chatJob.State -eq "Running") {
                    $vOut = Receive-Job $videoJob -ErrorAction SilentlyContinue
                    $cOut = Receive-Job $chatJob  -ErrorAction SilentlyContinue
                    if ($vOut) { $vOut | ForEach-Object { Write-Log "[$channelName][video] $_" "Gray" } }
                    if ($cOut) { $cOut | ForEach-Object { Write-Log "[$channelName][chat]  $_" "Gray" } }
                    Start-Sleep -Seconds 5
                }

                # Drain remaining output and clean up
                Receive-Job $videoJob -ErrorAction SilentlyContinue | ForEach-Object { Write-Log "[$channelName][video] $_" "Gray" }
                Receive-Job $chatJob  -ErrorAction SilentlyContinue | ForEach-Object { Write-Log "[$channelName][chat]  $_" "Gray" }
                Remove-Job $videoJob, $chatJob -Force

                # Report saved file size
                $savedFile = Get-FileSizeReadable $channelDir
                Write-Log "[$channelName] Stream saved! $savedFile" "Green"
                Show-Notification "Stream Watcher" "$channelName stream ended. Saved: $savedFile"

                Write-Log "[$channelName] Waiting 30s before resuming watch..." "Gray"
                Start-Sleep -Seconds 30

            } else {
                Write-Log "[$channelName] Not live. Checking again in ${CheckInterval}s..." "Gray"
                Start-Sleep -Seconds $CheckInterval
            }

        } catch {
            Write-Log "[$channelName] Error occurred: $_" "Yellow"
            Start-Sleep -Seconds $CheckInterval
        }
    }
}

# ============================================================
#  MAIN
# ============================================================

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

Write-Host ""
Write-Host "  ================================" -ForegroundColor Cyan
Write-Host "   YouTube Stream Watcher" -ForegroundColor Cyan
Write-Host "   Saving to: $OutputDir" -ForegroundColor Cyan
Write-Host "   Log file:  $LogFile" -ForegroundColor Cyan
Write-Host "  ================================" -ForegroundColor Cyan
Write-Host ""

Write-Log "Script started." "Cyan"

Check-Dependencies
Update-YtDlp

Write-Log "Watching $($Channels.Count) channel(s)..." "Cyan"
Write-Log "Press Ctrl+C at any time to stop." "Cyan"
Write-Host ""

if ($Channels.Count -eq 1) {
    Watch-Channel $Channels[0]
} else {
    $jobs = @()
    foreach ($channel in $Channels) {
        $jobs += Start-Job -ScriptBlock {
            param($url, $outDir, $interval, $metadata, $minDiskGB)

            $channelName = ($url -split "@")[-1].Split("/")[0]
            $liveUrl     = "$url/live"
            $channelDir  = "$outDir\$channelName"
            $logFile     = "$outDir\watcher.log"

            function JobLog($msg) {
                $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                $line = "[$ts] [$channelName] $msg"
                Write-Host $line
                Add-Content -Path $logFile -Value $line -ErrorAction SilentlyContinue
            }

            while ($true) {
                $liveCheck = & yt-dlp --get-url --no-warnings -q $liveUrl 2>$null
                if ($liveCheck) {
                    New-Item -ItemType Directory -Force -Path $channelDir | Out-Null

                    # Disk space check
                    try {
                        $drive  = Split-Path -Qualifier $outDir
                        $disk   = Get-PSDrive -Name $drive.TrimEnd(':') -ErrorAction SilentlyContinue
                        $freeGB = if ($disk) { [math]::Round($disk.Free / 1GB, 1) } else { 999 }
                        if ($freeGB -lt $minDiskGB) {
                            JobLog "LOW DISK: Only ${freeGB}GB free. Skipping download!"
                            Start-Sleep -Seconds 300
                            continue
                        }
                    } catch {}

                    # Duplicate check
                    $parts = Get-ChildItem $channelDir -Filter "*.part" -ErrorAction SilentlyContinue
                    if ($parts.Count -gt 0) {
                        JobLog "Download already in progress - skipping duplicate."
                        Start-Sleep -Seconds $interval
                        continue
                    }

                    JobLog "LIVE! Starting download..."

                    $outputTemplate = "$channelDir\%(upload_date)s_%(title)s.%(ext)s"

                    $ytArgsVideo = @(
                        "--output",              $outputTemplate,
                        "--merge-output-format", "mp4",
                        "--live-from-start",
                        "--no-part",
                        "--retries",             "10",
                        "--fragment-retries",    "10",
                        "--retry-sleep",         "5",
                        "--no-update"
                    )
                    if ($metadata) {
                        $ytArgsVideo += "--write-thumbnail"
                        $ytArgsVideo += "--write-description"
                        $ytArgsVideo += "--write-info-json"
                    }
                    $ytArgsVideo += $liveUrl

                    $ytArgsChat = @(
                        "--output",        $outputTemplate,
                        "--skip-download",
                        "--write-subs",
                        "--sub-langs",     "live_chat",
                        "--live-from-start",
                        "--no-update",
                        $liveUrl
                    )

                    $vJob = Start-Job -ScriptBlock { param($a) & yt-dlp @a } -ArgumentList (,$ytArgsVideo)
                    $cJob = Start-Job -ScriptBlock { param($a) & yt-dlp @a } -ArgumentList (,$ytArgsChat)

                    while ($vJob.State -eq "Running" -or $cJob.State -eq "Running") {
                        Start-Sleep -Seconds 5
                    }
                    Remove-Job $vJob, $cJob -Force

                    $file = Get-ChildItem $channelDir -Filter "*.mp4" -ErrorAction SilentlyContinue |
                            Sort-Object LastWriteTime -Descending | Select-Object -First 1
                    $size = if ($file) { "$([math]::Round($file.Length/1GB,2)) GB" } else { "unknown size" }
                    JobLog "Stream saved! $size"

                    Start-Sleep -Seconds 30
                } else {
                    JobLog "Not live. Checking again in ${interval}s..."
                    Start-Sleep -Seconds $interval
                }
            }
        } -ArgumentList $channel, $OutputDir, $CheckInterval, $SaveMetadata, $MinFreeDiskGB
    }

    while ($true) {
        foreach ($job in $jobs) {
            $output = Receive-Job -Job $job
            if ($output) { Write-Host $output }
        }
        Start-Sleep -Seconds 5
    }
}
