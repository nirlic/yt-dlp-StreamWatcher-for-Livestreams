# ============================================================
#  watchdog.ps1
#  Monitors stream-watcher.ps1 and restarts it if it crashes
#
#  SETUP:
#    1. Edit $ScriptPath below to point to your stream-watcher.ps1
#    2. Run this script instead of stream-watcher.ps1 directly
#    3. This script will launch and babysit stream-watcher.ps1
#
#  TO RUN IN BACKGROUND ON BOOT:
#    Use Task Scheduler to run watchdog.ps1 instead of
#    stream-watcher.ps1 directly. See README for Task Scheduler steps.
# ============================================================

# ============================================================
#  CONFIGURATION --- Edit this
# ============================================================

# Full path to your stream-watcher.ps1
$ScriptPath = "C:\StreamWatcher\stream-watcher.ps1"

# How many seconds to wait before restarting after a crash
$RestartDelay = 30

# Where to write the watchdog log
$WatchdogLog = "C:\StreamWatcher\StreamBackups\watchdog.log"

# ============================================================
#  WATCHDOG --- No need to edit below this line
# ============================================================

function Write-WatchdogLog($message) {
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$timestamp] [WATCHDOG] $message"
    Write-Host $line -ForegroundColor Magenta
    Add-Content -Path $WatchdogLog -Value $line -ErrorAction SilentlyContinue
}

# Make sure the log folder exists
$logDir = Split-Path $WatchdogLog
New-Item -ItemType Directory -Force -Path $logDir | Out-Null

Write-Host ""
Write-Host "  ================================" -ForegroundColor Magenta
Write-Host "   Stream Watcher - Watchdog" -ForegroundColor Magenta
Write-Host "   Watching: $ScriptPath" -ForegroundColor Magenta
Write-Host "   Restart delay: ${RestartDelay}s" -ForegroundColor Magenta
Write-Host "  ================================" -ForegroundColor Magenta
Write-Host ""

Write-WatchdogLog "Watchdog started."

$crashCount = 0

while ($true) {
    Write-WatchdogLog "Starting stream-watcher.ps1 (attempt #$($crashCount + 1))..."

    try {
        # Launch stream-watcher and wait for it to exit
        $process = Start-Process powershell `
            -ArgumentList "-ExecutionPolicy Bypass -File `"$ScriptPath`"" `
            -PassThru `
            -NoNewWindow

        # Wait for the process to finish
        $process.WaitForExit()

        $exitCode = $process.ExitCode
        $crashCount++

        Write-WatchdogLog "stream-watcher.ps1 exited with code $exitCode. (Total crashes: $crashCount)"

        if ($exitCode -eq 0) {
            Write-WatchdogLog "Clean exit detected. Restarting anyway in case it was unintentional..."
        } else {
            Write-WatchdogLog "Crash detected! Restarting in ${RestartDelay}s..."
        }

    } catch {
        $crashCount++
        Write-WatchdogLog "Failed to launch stream-watcher.ps1: $_. Retrying in ${RestartDelay}s..."
    }

    Start-Sleep -Seconds $RestartDelay
}

# SIG # Begin signature block
# MIIFWwYJKoZIhvcNAQcCoIIFTDCCBUgCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUDHqVnd1gMk6Ty++LKPPIbbLE
# TF2gggL8MIIC+DCCAeCgAwIBAgIQV7lfZEh404FHUXcDiKMZfDANBgkqhkiG9w0B
# AQsFADAUMRIwEAYDVQQDDAlNeVNjcmlwdHMwHhcNMjYwMjI3MTAwMDExWhcNMjcw
# MjI3MTAyMDExWjAUMRIwEAYDVQQDDAlNeVNjcmlwdHMwggEiMA0GCSqGSIb3DQEB
# AQUAA4IBDwAwggEKAoIBAQCn0h5Nv2CgYoA0enFsHmUQyG906Onm1l43lwvf2Jsh
# PO/G9mb2AiwtuCY6FdDYW9rLYptzZiliYFsR/ungroJnPwXxhgRW/WPsXyHc78zd
# 0Xu7u3GIkBspexs0K6XtEgKixbevAaijlSsTWHl9TcH9xWfw5Vkb9mgUaXX4iKb2
# hpPJTWtJlc9Gka6jpoifYvl/HTGKjuz0OKVxFjMxifGSj03j/7ubrcU7pYbhUuCO
# nWUzYvhjAjxF8S+LjB9UA+WBtASIkfY1kiN0SBqy+OGLNv9/DM+QgTBknPKjmH1d
# skGjBxRdV2/pW2TLk5HmHz9szE+NI29Oa+mek9gwdcCZAgMBAAGjRjBEMA4GA1Ud
# DwEB/wQEAwIHgDATBgNVHSUEDDAKBggrBgEFBQcDAzAdBgNVHQ4EFgQUpQFVtmCE
# RH7Oic7nPtBlT1PJQQswDQYJKoZIhvcNAQELBQADggEBABASkBKb8E8/7cai7602
# Uq0xB8ReOdsqdXeOeHUvbH1gHAGhK8gpltaL3mGhAq7i2h6SFHrZaXt27N6/Ex7o
# LtU/kcaT6ddbL1YKNnedxmLh8znLhdNydu8GQnnkbnOLixT73HbNdNz9pz3XyGQ5
# yTExvbT4QxNt2nCGookTVSoURCD/X+u+/xI1ASM6GEJrJIrgR8Ya7bu7pBUmyZ22
# 3r3kprx7ktHRyJvOIcmhsHHO6pJ/x5gHjOupMn+PeXd1X1ac4BhajYlqkDzzTL9T
# 5jUQS4KEFrYkSXdVRlJ9DfE6LN7q4dfneYi5EiDtEu2SwQQWZjZvw0u9z0o01QgK
# xzAxggHJMIIBxQIBATAoMBQxEjAQBgNVBAMMCU15U2NyaXB0cwIQV7lfZEh404FH
# UXcDiKMZfDAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZ
# BgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYB
# BAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQUeLvptgKo+lsUXl04HrRzfvbx5KUwDQYJ
# KoZIhvcNAQEBBQAEggEACa8cVHvbqbWi2zeBU5WtTlWxHGFQ+8IvlrI/07hyzW/H
# M4SzKbw5ZLFfh+iUk+PuErbWlYOVkw5JJ/G55gpoFowFDN/1UiJ7iD2ejI+7fTCG
# lOtlkBTqnC6GVWNpDyqzkpJH3Y3xaIANkzGqzFKt1ci4IfPY1JRnxnF7BuST+bGv
# JMxqoff6t057LzOudxSWqENXZdH2GzXeRXru+7c2RcAyjrp8NI/ynKxRch54kktz
# R+N6/+rBVV8Zrao5DDDdGp0G1hDISje4B4GKNxnZPrNJgz/INaqsN2fRXJxYwODc
# BTeIH/SLGFgNH5B97r12POnbOuKKXsreTs6cOmGv4A==
# SIG # End signature block
