Remove-Item 'C:\Users\Public\Automation\Downloads\NVCleanstall.exe' -Force -ErrorAction SilentlyContinue
Remove-Item 'C:\Users\Public\Automation\Downloads\EdgeBlocker*' -Recurse -Force -ErrorAction SilentlyContinue
$s='C:\Users\Public\Automation\state.json'
if (Test-Path $s) {
    $j = Get-Content $s | ConvertFrom-Json -AsHashtable
    $klist = 'nvclean,edge-blocker' -split ','
    foreach ($k in $klist) {
        if ($j.ContainsKey($k)) { $j.Remove($k) | Out-Null }
    }
    $j | ConvertTo-Json | Set-Content $s
}
Write-Host 'Cleanup and state update done'