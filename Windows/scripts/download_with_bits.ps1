$Downloads = 'C:\Users\Public\Automation\Downloads'
New-Item -ItemType Directory -Force -Path $Downloads | Out-Null

function Download-Bits($url,$out) {
    try {
        if (Test-Path $out) { Remove-Item $out -Force -ErrorAction SilentlyContinue }
        Start-BitsTransfer -Source $url -Destination $out -DisplayName "Download $out" -ErrorAction Stop
        Write-Host "BITS download succeeded: $out"
        return $true
    } catch {
        Write-Host "BITS download failed: $_"
        return $false
    }
}

$nvUrl = 'https://sourceforge.net/projects/nvcleanstall/files/latest/download'
$nvPath = Join-Path $Downloads 'NVCleanstall.exe'
if (Download-Bits $nvUrl $nvPath) { Write-Host 'Downloaded NVCleanstall via BITS' } else { Write-Host 'Failed downloading NVCleanstall via BITS' }

$ebUrl = 'https://www.sordum.org/wp-content/uploads/2017/01/EdgeBlocker.zip'
$ebZip = Join-Path $Downloads 'EdgeBlocker.zip'
if (Download-Bits $ebUrl $ebZip) { Write-Host 'Downloaded EdgeBlocker via BITS' } else { Write-Host 'Failed downloading EdgeBlocker via BITS' }
