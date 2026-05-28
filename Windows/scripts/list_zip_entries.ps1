param([string]$ZipPath)
if (-not (Test-Path $ZipPath)) { Write-Host 'Zip not found'; exit }
Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::OpenRead($ZipPath).Entries | ForEach-Object { Write-Host $_.FullName }
