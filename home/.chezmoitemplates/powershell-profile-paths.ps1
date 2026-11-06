# uninstall.ps1 keeps a copy of these paths because it runs after chezmoi purge
$documents = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
if ([string]::IsNullOrWhiteSpace($documents)) {
    $documents = Join-Path $HOME 'Documents'
}
$profilePaths = @(
    (Join-Path $documents 'PowerShell\Profile.ps1'),
    (Join-Path $documents 'WindowsPowerShell\Profile.ps1')
)
