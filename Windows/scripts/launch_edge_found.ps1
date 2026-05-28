$exe = Get-ChildItem 'C:\Users\Public\Automation\Downloads' -Recurse -Filter '*EdgeBlock*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($exe) {
    Write-Host "Found: $($exe.FullName)"
    Start-Process -FilePath $exe.FullName -WorkingDirectory $exe.DirectoryName -Verb RunAs
} else {
    Write-Host 'No EdgeBlock executable found'
}