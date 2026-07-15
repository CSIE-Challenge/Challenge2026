<#
.SYNOPSIS
    Automates the CSIE-Challenge 2026 multiplayer demo testing setup.

.DESCRIPTION
    This script cleans up the Docker matchmaker environment to prevent port-binding / "connection failed" errors,
    and then automatically opens three separate Godot client instances:
    1. Player 1 client
    2. Player 2 client
    3. Demo Spectator client (--demo)

.PARAMETER GodotPath
    The absolute path to the Godot console executable. Defaults to:
    "C:\Users\10211\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe"

.PARAMETER Fast
    If set, uses `docker compose restart` instead of recreating the container. Much faster, but slightly less thorough.

.PARAMETER SkipDocker
    If set, skips restarting the Docker containers entirely (useful if the server is already clean).

.EXAMPLE
    .\test-demo.ps1
    Runs the full cleanup (down/up) and opens all three clients.

.EXAMPLE
    .\test-demo.ps1 -Fast
    Restarts the container quickly and opens all three clients.

.EXAMPLE
    .\test-demo.ps1 -SkipDocker
    Launches only the three client windows.
#>

param (
    [string]$GodotPath = "C:\Users\10211\Downloads\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64_console.exe",
    [switch]$Fast,
    [switch]$SkipDocker
)

# Set console output encoding to UTF-8 to display Chinese characters properly
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# Get project root (the directory where this script is located)
$ProjectPath = $PSScriptRoot
if ([string]::IsNullOrEmpty($ProjectPath)) {
    $ProjectPath = Get-Location
}

Write-Host "==========================================================" -ForegroundColor Green
Write-Host "      CSIE-Challenge 2026 Demo Automatic Test Runner" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "Project path: $ProjectPath" -ForegroundColor Gray
Write-Host "Godot path:   $GodotPath" -ForegroundColor Gray

# 1. Validate Godot executable path
if (-not (Test-Path $GodotPath)) {
    Write-Host "[ERROR] Godot executable not found at: $GodotPath" -ForegroundColor Red
    Write-Host "Please specify the correct path using: .\test-demo.ps1 -GodotPath <path_to_godot_console.exe>" -ForegroundColor Yellow
    exit 1
}

# 2. Reset Docker if not skipped
if (-not $SkipDocker) {
    if ($Fast) {
        Write-Host "`n[Docker] Restarting matchmaker service quickly..." -ForegroundColor Cyan
        docker compose restart matchmaker
    } else {
        Write-Host "`n[Docker] Cleaning and restarting matchmaker container (clean mode)..." -ForegroundColor Cyan
        Write-Host "         This will clear any orphaned Godot processes and release port bindings." -ForegroundColor Gray
        docker compose down
        docker compose up -d
    }

    # Wait for the HTTP server to spin up and bind ports
    Write-Host "[Docker] Waiting 3 seconds for Matchmaker HTTP server to start..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
} else {
    Write-Host "`n[Docker] Skipping Docker restart." -ForegroundColor Yellow
}

# 3. Launch clients
Write-Host "`n[Clients] Launching Player 1 Client..." -ForegroundColor Green
Start-Process -FilePath $GodotPath -ArgumentList "--path `"$ProjectPath`" -- --connect 127.0.0.1"

# Small delay to prevent resource contention
Start-Sleep -Milliseconds 500

Write-Host "[Clients] Launching Player 2 Client..." -ForegroundColor Green
Start-Process -FilePath $GodotPath -ArgumentList "--path `"$ProjectPath`" -- --connect 127.0.0.1"

# Small delay
Start-Sleep -Milliseconds 500

Write-Host "[Clients] Launching Demo Spectator Client..." -ForegroundColor Green
Start-Process -FilePath $GodotPath -ArgumentList "--path `"$ProjectPath`" -- --demo --connect 127.0.0.1"

Write-Host "`n[SUCCESS] All clients have been launched successfully!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
Write-Host "How to start the match in the game screens:" -ForegroundColor Gray
Write-Host "1. On Player 1 window, click 'Double Player' -> 'Create Room'." -ForegroundColor Yellow
Write-Host "2. Note the 6-character Room Code." -ForegroundColor Yellow
Write-Host "3. On Player 2 window, click 'Double Player' -> 'Join Room' and enter the code." -ForegroundColor Yellow
Write-Host "4. Select agents and click Ready on both windows to begin." -ForegroundColor Yellow
Write-Host "5. The Demo Spectator window will automatically display the gameplay." -ForegroundColor Yellow
Write-Host "==========================================================" -ForegroundColor Green
