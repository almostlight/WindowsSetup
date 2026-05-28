param([string]$Path)
if (-not (Test-Path $Path)) { Write-Host 'File not found'; exit }
$bytes = [System.IO.File]::ReadAllBytes($Path)
$len = [Math]::Min(500,$bytes.Length)
$s = [System.Text.Encoding]::ASCII.GetString($bytes,0,$len)
if ($s -match '<!DOCTYPE|<html') { Write-Host 'File appears to be HTML (likely redirect)'; } else { Write-Host 'Binary file (no HTML signature detected)'; }
Write-Host 'First 200 chars:'
Write-Host ($s.Substring(0,[Math]::Min(200,$s.Length)))
