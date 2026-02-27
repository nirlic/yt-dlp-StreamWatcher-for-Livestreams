# YouTube Stream Watcher
Automatically detects and downloads YouTube live streams the moment they start.
Downloads video and live chat simultaneously as separate files.

---

## What You Get Per Stream

Every time a stream is captured, these files are saved in a folder named after the channel:

```
StreamBackups/
  ChannelName/
    20260227_Stream Title.mp4           <- the full stream video
    20260227_Stream Title.live_chat.json3  <- live chat replay
    20260227_Stream Title.jpg           <- thumbnail
    20260227_Stream Title.description   <- stream description
    20260227_Stream Title.info.json     <- metadata
  watcher.log                           <- full activity log
```

---

## Requirements

- Windows 10 or 11
- yt-dlp
- ffmpeg

---

## Installation

### Step 1 - Install yt-dlp and ffmpeg
Open PowerShell and run:
```powershell
winget install yt-dlp
winget install ffmpeg
```

### Step 2 - Allow PowerShell scripts to run (one time only)
Open PowerShell and run:
```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```
Type `Y` and press Enter when prompted.

### Step 3 - Edit the script
Open `stream-watcher.ps1` in Notepad and edit the CONFIGURATION section at the top:

```powershell
$Channels = @(
    "https://www.youtube.com/@YourChannelHere"
    "https://www.youtube.com/@AnotherChannel"
)

$OutputDir = "D:\StreamBackups"   # change to wherever you want files saved
```

### Step 4 - Run it
Right-click `stream-watcher.ps1` and select **Run with PowerShell**.

---

## Verify It Is Working

Run these checks in PowerShell:

```powershell
# Confirm tools are installed
yt-dlp --version
ffmpeg --version

# Confirm yt-dlp can see your channel (blank = not live, URL = live)
yt-dlp --get-url --no-warnings -q "https://www.youtube.com/@ChannelName/live"

# Check the log file
Get-Content "$env:USERPROFILE\StreamBackups\watcher.log" -Tail 50
```

When running correctly the script prints:
```
[2026-02-27 10:00:00] yt-dlp and ffmpeg found. All good!
[2026-02-27 10:00:01] yt-dlp is already up to date.
[2026-02-27 10:00:02] Watching 1 channel(s)...
[2026-02-27 10:00:03] [ChannelName] Not live. Checking again in 60s...
```

---

## Running in the Background (So You Can Close the Window)

### Option A - Hide it right now
Paste this into PowerShell (update the path to match where your script is):
```powershell
Start-Process powershell -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"C:\StreamWatcher\stream-watcher.ps1`"" -WindowStyle Hidden
```

### Option B - Auto-start on boot via Task Scheduler
1. Open **Task Scheduler** (search in Start menu)
2. Click **Create Basic Task**
3. Name: `Stream Watcher`
4. Trigger: **When the computer starts**
5. Action: **Start a program**
   - Program: `powershell.exe`
   - Arguments: `-WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\StreamWatcher\stream-watcher.ps1"`
6. Click **Finish**

### To stop it
Open **Task Manager > Details tab**, find `powershell.exe`, right-click > End Task.

Or in PowerShell:
```powershell
Stop-Process -Name "yt-dlp" -Force
```

---

## Signing the Script (Optional but Recommended)

Signing prevents Windows from prompting you every time. Run these once:

### Step 1 - Create a certificate (Admin PowerShell)
```powershell
$cert = New-SelfSignedCertificate -Subject "CN=MyScripts" -CertStoreLocation "Cert:\CurrentUser\My" -KeyUsage DigitalSignature -Type CodeSigningCert
```

### Step 2 - Trust your own certificate (Admin PowerShell)
```powershell
$store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root","CurrentUser")
$store.Open("ReadWrite")
$store.Add($cert)
$store.Close()
```

### Step 3 - Sign the script
```powershell
$cert = Get-ChildItem Cert:\CurrentUser\My -CodeSigningCert
Set-AuthenticodeSignature -FilePath "C:\StreamWatcher\stream-watcher.ps1" -Certificate $cert
```

### Step 4 - Verify it worked
```powershell
Get-AuthenticodeSignature "C:\StreamWatcher\stream-watcher.ps1"
```
Look for `Status : Valid`.

> Note: Every time you edit the script you must re-run Step 3 to re-sign it.

---

## Updating yt-dlp Manually

If you see a version warning run this in regular PowerShell:
```powershell
yt-dlp -U
```
If it says permission denied run it in Admin PowerShell, or update via winget:
```powershell
winget upgrade yt-dlp
```

---

## Checking Which yt-dlp Is Being Used

```powershell
where.exe yt-dlp
```
Should point somewhere outside of `Program Files (x86)`. If it points to Parabolic's folder, install a separate copy via winget:
```powershell
winget install yt-dlp
```

---

## Stopping and Saving a Download Mid-Stream

Simply press **Ctrl+C** in the PowerShell window. yt-dlp saves everything downloaded so far as a complete playable file.

---

## Viewing the Chat File

The `.json3` chat file can be used in two ways:

**In the browser (no install needed):**
Upload it to https://chatreplay.stream alongside the video.

**Convert to plain text:**
```powershell
pip install chat-downloader
chat_downloader "path\to\file.json3" --output chat.txt
```

**Share with viewers using the Chat Viewer HTML tool:**
Include `chat-viewer.html` in your archive download alongside the `.json3` file.
Viewers open it in any browser, load the chat file, and sync it to the YouTube video timestamp.

---

## Configuration Options

| Setting | Default | Description |
|---|---|---|
| `$Channels` | empty | List of YouTube channel URLs to watch |
| `$OutputDir` | `~\StreamBackups` | Where to save files |
| `$CheckInterval` | `60` | Seconds between live checks |
| `$EnableNotifications` | `true` | Windows pop-up when stream detected |
| `$SaveMetadata` | `true` | Save thumbnail, description, info.json |
| `$MinFreeDiskGB` | `20` | Minimum free disk space before downloading |
| `$AutoUpdate` | `true` | Auto-update yt-dlp on script start |

---

## File Size Estimates

| Stream Length | Approx Size at 1080p60 |
|---|---|
| 1 hour | 3 - 6 GB |
| 2 hours | 6 - 12 GB |
| 4 hours | 12 - 20 GB |
| 8 hours | 20 - 40 GB |

Make sure your drive has enough space, or adjust `$MinFreeDiskGB` accordingly.
