param([string]$Url)
try {
    $resp = Invoke-WebRequest -Uri $Url -Method Head -MaximumRedirection 0 -ErrorAction Stop
    Write-Host 'StatusCode:' $resp.StatusCode
    Write-Host 'Headers:'
    $resp.Headers | Format-List
} catch {
    if ($_.Exception.Response) {
        $r = $_.Exception.Response
        try { $h = $r.Headers; Write-Host 'Response.Headers:'; $h | Format-List } catch {}
        try { Write-Host 'StatusCode:' $r.StatusCode } catch {}
    } else { Write-Host 'No response: ' $_ }
}
