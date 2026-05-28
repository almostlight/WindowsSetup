$s='C:\Users\Public\Automation\state.json'
if (-not (Test-Path $s)) { Write-Host 'No state.json'; exit }
$json = Get-Content $s | ConvertFrom-Json
$exclude = @('edge-blocker','nvclean')
$hashtable = @{}
foreach ($p in $json.psobject.properties) {
    if ($exclude -notcontains $p.Name) { $hashtable[$p.Name] = $p.Value }
}
$hashtable | ConvertTo-Json | Set-Content $s
Write-Host 'Removed keys and updated state.json'