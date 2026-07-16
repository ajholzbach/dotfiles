if (-not $env:XDG_CONFIG_HOME) {
    $env:XDG_CONFIG_HOME = Join-Path $HOME '.config'
}

foreach ($userBin in @(
    (Join-Path $HOME 'bin'),
    (Join-Path $HOME '.local/bin')
)) {
    if ((Test-Path -LiteralPath $userBin) -and
        (($env:PATH -split [IO.Path]::PathSeparator) -notcontains $userBin)) {
        $env:PATH = $userBin + [IO.Path]::PathSeparator + $env:PATH
    }
}

if (-not $env:STARSHIP_CONFIG) {
    $env:STARSHIP_CONFIG = Join-Path (Join-Path $HOME '.config') 'starship.toml'
}

if (-not $env:BAT_CONFIG_DIR) {
    $env:BAT_CONFIG_DIR = Join-Path (Join-Path $HOME '.config') 'bat'
}

$localEnv = Join-Path $env:XDG_CONFIG_HOME 'local-env.ps1'
if (Test-Path -LiteralPath $localEnv) {
    . $localEnv
}

if (Get-Command mise -ErrorAction SilentlyContinue) {
    (& mise activate pwsh) | Out-String | Invoke-Expression
}

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    (& zoxide init powershell) | Out-String | Invoke-Expression
}

if (Get-Command chezmoi -ErrorAction SilentlyContinue) {
    (& chezmoi completion powershell) | Out-String | Invoke-Expression
}

if (Get-Command starship -ErrorAction SilentlyContinue) {
    (& starship init powershell) | Out-String | Invoke-Expression
}
