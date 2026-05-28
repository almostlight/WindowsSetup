$src = 'https://downloads.sourceforge.net/project/nvcleanstall/NVCleanstall_1.19.0.exe'
$dst = 'C:\Users\Public\Automation\Downloads\NVCleanstall_1.19.0.exe'
if (Test-Path $dst) { Remove-Item $dst -Force -ErrorAction SilentlyContinue }
try {
    Start-BitsTransfer -Source $src -Destination $dst -ErrorAction Stop
    if (Test-Path $dst) {
        Write-Host 'Downloaded'
        Get-FileHash -Algorithm SHA256 $dst | Select-Object -ExpandProperty Hash
    } else {
        Write-Host 'Download failed'
    }
} catch {
    Write-Host 'Error during BITS transfer:' $_
}
