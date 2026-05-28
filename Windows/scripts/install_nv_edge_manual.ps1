$Downloads = 'C:\Users\Public\Automation\Downloads'
New-Item -ItemType Directory -Force -Path $Downloads | Out-Null

# NVCleanstall
$nvUrl = 'https://sourceforge.net/projects/nvcleanstall/files/latest/download'
$nvPath = Join-Path $Downloads 'NVCleanstall.exe'
try {
    Invoke-WebRequest -Uri $nvUrl -OutFile $nvPath -UseBasicParsing -TimeoutSec 120
    Start-Process -FilePath $nvPath -WorkingDirectory $Downloads -Verb RunAs
    Write-Host 'NVCleanstall downloaded and launched'
} catch {
    Write-Host "NVCleanstall download/launch failed: $_"
}

# Edge Blocker
$ebUrl = 'https://www.sordum.org/wp-content/uploads/2017/01/EdgeBlocker.zip'
$ebZip = Join-Path $Downloads 'EdgeBlocker.zip'
$ebDir = Join-Path $Downloads 'EdgeBlocker'
try {
    Invoke-WebRequest -Uri $ebUrl -OutFile $ebZip -UseBasicParsing -TimeoutSec 60
    if (Test-Path $ebDir) { Remove-Item $ebDir -Recurse -Force -ErrorAction SilentlyContinue }
    Expand-Archive $ebZip $ebDir -Force
    $exe = Get-ChildItem $ebDir -Recurse -Filter '*EdgeBlocker*.exe' | Select-Object -First 1
    if ($exe) {
        Start-Process -FilePath $exe.FullName -WorkingDirectory $ebDir -Verb RunAs
        Write-Host 'EdgeBlocker launched'
    } else {
        Write-Host 'EdgeBlocker executable not found after extraction'
    }
} catch {
    Write-Host "EdgeBlocker download/launch failed: $_"
}
