$ids = @(
    'Microsoft.PowerShell',
    'Git.Git',
    'GitHub.cli',
    'REALiX.HWiNFO',
    'Brave.Brave',
    'Microsoft.VisualStudioCode',
    '9NBLGGH43VHV',
    '9P98T77876KZ',
    'vim.vim',
    '7zip.7zip'
)

foreach ($id in $ids) {
    Write-Host "Installing: $id"
    winget install -e --id $id --silent --accept-package-agreements --accept-source-agreements
}
