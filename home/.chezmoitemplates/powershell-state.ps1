$stateBase = if ($env:XDG_STATE_HOME) { $env:XDG_STATE_HOME } else { Join-Path $HOME '.local\state' }
$stateRoot = Join-Path $stateBase 'dotfiles'

# Write-StateFile PATH LINES: replace PATH through a temporary file so an
# interrupted write never leaves a truncated state file.
function Write-StateFile {
    param([string]$Path, [string[]]$Lines)

    New-Item -ItemType Directory -Path (Split-Path -Parent $Path) -Force | Out-Null
    $temporary = "$Path.$PID.tmp"
    try {
        [IO.File]::WriteAllLines($temporary, $Lines, [Text.UTF8Encoding]::new($false))
        Move-Item -LiteralPath $temporary -Destination $Path -Force
    } finally {
        if (Test-Path -LiteralPath $temporary) {
            Remove-Item -LiteralPath $temporary -Force
        }
    }
}
