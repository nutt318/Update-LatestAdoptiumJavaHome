# Update-LatestAdoptiumJavaHome.ps1
# WARNING: Auto-follows newest folder even across major Java versions!
# Run as Administrator!

$BaseDir = "C:\Program Files\Eclipse Adoptium"
$VstsServicePattern = "vstsagent.tfs*"

# Find ALL jre-* or jdk-* folders
$candidates = Get-ChildItem -Path $BaseDir -Directory | Where-Object {
    $_.Name -match '^(jre|jdk)-[\d\.\+]+-hotspot$'
}

if ($candidates.Count -eq 0) {
    Write-Warning "No jre-* or jdk-* folders found in $BaseDir"
    exit
}

# Sort by LastWriteTime descending → newest folder first
$latestFolder = $candidates | Sort-Object LastWriteTime -Descending | Select-Object -First 1

$newJavaHome = $latestFolder.FullName
Write-Host "Latest detected folder: $newJavaHome" -ForegroundColor Cyan
Write-Host "Major version: $($latestFolder.Name -replace '^(jre|jdk)-(\d+).*', '$2')"

# Get current system-wide values
$currentJavaHome = [Environment]::GetEnvironmentVariable("JAVA_HOME", "Machine")
$currentJavaVar  = [Environment]::GetEnvironmentVariable("java", "Machine")

$updated = $false

# Update JAVA_HOME if changed
if ($currentJavaHome -ne $newJavaHome) {
    Write-Host "Updating JAVA_HOME: '$currentJavaHome' → '$newJavaHome'" -ForegroundColor Yellow
    [Environment]::SetEnvironmentVariable("JAVA_HOME", $newJavaHome, "Machine")
    $updated = $true
} else {
    Write-Host "JAVA_HOME is already pointing to the latest folder." -ForegroundColor Green
}

# Update the custom 'java' variable if it exists and is outdated
if ($currentJavaVar -and $currentJavaVar -ne $newJavaHome) {
    Write-Host "Updating 'java' variable: '$currentJavaVar' → '$newJavaHome'" -ForegroundColor Yellow
    [Environment]::SetEnvironmentVariable("java", $newJavaHome, "Machine")
    $updated = $true
} elseif (-not $currentJavaVar) {
    Write-Host "Note: No system-wide 'java' variable exists → skipping." -ForegroundColor DarkGray
}

# Optional: Refresh PATH
if ($updated) {
    $path = [Environment]::GetEnvironmentVariable("Path", "Machine")
    $cleanPath = ($path -split ';' | Where-Object {
        $_ -notmatch 'Eclipse Adoptium\\(jre|jdk)-.*\\bin' -and $_ -notlike ""
    }) -join ';'

    $newBin = "$newJavaHome\bin"
    if ($cleanPath -notlike "*$newBin*") {
        $cleanPath += ";$newBin"
        Write-Host "PATH updated with new bin: $newBin" -ForegroundColor Yellow
    }

    [Environment]::SetEnvironmentVariable("Path", $cleanPath, "Machine")
}

if ($updated) {
    Write-Host "`nEnvironment updated successfully!" -ForegroundColor Green
    
    # === RESTART VSTS AGENT SERVICES ===
    Write-Host "`n--- Checking for VSTS Agent services matching '$VstsServicePattern' ---" -ForegroundColor Magenta
    
    $vstsServices = Get-Service -Name $VstsServicePattern -ErrorAction SilentlyContinue
    
    if ($vstsServices) {
        foreach ($service in $vstsServices) {
            Write-Host "Restarting service: $($service.Name) (Status: $($service.Status))" -ForegroundColor Yellow
            
            if ($service.Status -eq 'Running') {
                Restart-Service -Name $service.Name -Force
                Write-Host "  [OK] Restarted successfully" -ForegroundColor Green
            } elseif ($service.Status -eq 'Stopped') {
                Start-Service -Name $service.Name
                Write-Host "  [OK] Started successfully" -ForegroundColor Green
            } else {
                Write-Warning "  [BAD] Unexpected status '$($service.Status)' - manual check needed"
            }
            
            Start-Sleep -Seconds 2
        }
        Write-Host "All VSTS Agent services restarted!" -ForegroundColor Green
    } else {
        Write-Host "No services matching '$VstsServicePattern' found → skipping service restart" -ForegroundColor Cyan
    }
    
    Write-Host "`nFinal status check:" -ForegroundColor White
    $vstsServices | ForEach-Object { Write-Host "  $($_.Name): $($_.Status)" }
    
    Write-Host "`n*** IMPORTANT: New processes will now use the updated Java path! ***" -ForegroundColor Green
} else {
    Write-Host "No environment changes needed - already on the latest folder." -ForegroundColor Green
}
