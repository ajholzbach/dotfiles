param(
    [switch]$DryRun,
    [switch]$Yes,
    [switch]$KeepChezmoi
)

$ErrorActionPreference = 'Stop'

$stateBase = if ($env:XDG_STATE_HOME) {
    $env:XDG_STATE_HOME
} else {
    Join-Path $HOME '.local\state'
}
$stateRoot = Join-Path $stateBase 'dotfiles'
$currentBackup = Join-Path $stateRoot 'current-backup'

if (-not (Test-Path -LiteralPath $currentBackup -PathType Leaf)) {
    throw "No dotfiles restore point was found at $currentBackup. Nothing was changed."
}

$backupId = [IO.File]::ReadAllText($currentBackup).Trim()
if ([string]::IsNullOrWhiteSpace($backupId) -or $backupId.Contains('..') -or
    $backupId.Contains('/') -or $backupId.Contains('\')) {
    throw "Invalid restore-point identifier: $backupId"
}

$backupDir = Join-Path (Join-Path $stateRoot 'backups') $backupId
$managedManifest = Join-Path $backupDir 'managed-files.txt'
$existingManifest = Join-Path $backupDir 'existing-files.txt'
$profilesManifest = Join-Path $backupDir 'powershell-profiles.json'

if (-not (Test-Path -LiteralPath $managedManifest -PathType Leaf) -or
    -not (Test-Path -LiteralPath $existingManifest -PathType Leaf) -or
    -not (Test-Path -LiteralPath $profilesManifest -PathType Leaf)) {
    throw "Restore point $backupId is incomplete; refusing to remove managed files."
}

function Test-SafeRelativePath {
    param([string]$Path)

    return -not [string]::IsNullOrWhiteSpace($Path) -and
        -not [IO.Path]::IsPathRooted($Path) -and
        -not (($Path -split '[\\/]') -contains '..')
}

function Test-RealDirectory {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        return $false
    }

    $item = Get-Item -LiteralPath $Path -Force
    return $item.PSIsContainer -and [string]::IsNullOrWhiteSpace([string]$item.LinkType)
}

function Copy-PathPreservingLink {
    param(
        [string]$Source,
        [string]$Destination
    )

    $item = Get-Item -LiteralPath $Source -Force
    if ($item.LinkType -in @('SymbolicLink', 'Junction')) {
        $linkTarget = @($item.Target)[0]
        New-Item -ItemType $item.LinkType -Path $Destination -Target $linkTarget -Force | Out-Null
    } else {
        Copy-Item -LiteralPath $Source -Destination $Destination -Force
    }
}

$managed = @([IO.File]::ReadAllLines($managedManifest))
$managedSet = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($path in $managed) {
    if (-not (Test-SafeRelativePath -Path $path)) {
        throw "Unsafe path in restore manifest: $path"
    }
    if (-not $managedSet.Add($path)) {
        throw "Duplicate path in restore manifest: $path"
    }
}

$existing = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
foreach ($path in [IO.File]::ReadAllLines($existingManifest)) {
    if (-not (Test-SafeRelativePath -Path $path) -or -not $managedSet.Contains($path)) {
        throw "Unsafe or unmanaged path in existing-files manifest: $path"
    }
    if (-not $existing.Add($path)) {
        throw "Duplicate path in existing-files manifest: $path"
    }
}

try {
    $profileRecords = @((Get-Content -LiteralPath $profilesManifest -Raw | ConvertFrom-Json))
} catch {
    throw "Invalid PowerShell profile restore manifest: $($_.Exception.Message)"
}

$documents = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
if ([string]::IsNullOrWhiteSpace($documents)) {
    $documents = Join-Path $HOME 'Documents'
}
$expectedProfilePaths = @(
    (Join-Path $documents 'PowerShell\Profile.ps1'),
    (Join-Path $documents 'WindowsPowerShell\Profile.ps1')
)

if ($profileRecords.Count -ne $expectedProfilePaths.Count) {
    throw "PowerShell profile restore manifest has an unexpected record count: $($profileRecords.Count)"
}
for ($index = 0; $index -lt $profileRecords.Count; $index++) {
    $record = $profileRecords[$index]
    $expectedBackup = "profiles/$index"
    if (-not [StringComparer]::OrdinalIgnoreCase.Equals([string]$record.Path, $expectedProfilePaths[$index]) -or
        -not [StringComparer]::Ordinal.Equals([string]$record.Backup, $expectedBackup) -or
        $record.Existed -isnot [bool]) {
        throw "Unsafe or malformed PowerShell profile record at index $index."
    }
    if ($record.Existed) {
        $profileBackup = Join-Path $backupDir $record.Backup
        if (-not (Test-Path -LiteralPath $profileBackup) -or (Test-RealDirectory -Path $profileBackup)) {
            throw "Missing or invalid original PowerShell profile in restore point: $profileBackup"
        }
    }
}

Write-Host "Restore point: $backupDir"
if ($DryRun) {
    Write-Host 'Dry run: the following managed targets would be removed or restored:'
    foreach ($relativePath in $managed) {
        Write-Host "  ~\$relativePath"
    }
    foreach ($record in $profileRecords) {
        Write-Host "  $($record.Path)"
    }
    if (Test-Path -LiteralPath (Join-Path $stateRoot 'starship-installed-by-dotfiles')) {
        Write-Host '  Starship installed by these dotfiles would be uninstalled'
    }
    if (-not $KeepChezmoi) {
        Write-Host '  chezmoi configuration and source would be purged'
    }
    exit 0
}

if (-not $Yes) {
    $answer = Read-Host 'Restore the pre-install files and remove these dotfiles? [y/N]'
    if ($answer -notmatch '^(?i:y|yes)$') {
        Write-Host 'Cancelled.'
        exit 0
    }
}

# Validate every source and destination before changing any user files.
foreach ($relativePath in $managed) {
    $target = Join-Path $HOME $relativePath
    if (Test-RealDirectory -Path $target) {
        throw "Refusing to replace directory where a managed file was expected: $target"
    }

    if ($existing.Contains($relativePath)) {
        $original = Join-Path (Join-Path $backupDir 'files') $relativePath
        if (-not (Test-Path -LiteralPath $original) -or (Test-RealDirectory -Path $original)) {
            throw "Missing or invalid original file in restore point: $original"
        }
    }
}

$snapshotId = '{0}-{1}' -f [DateTime]::UtcNow.ToString('yyyyMMddTHHmmssZ'), $PID
$snapshotDir = Join-Path (Join-Path $stateRoot 'uninstall-snapshots') $snapshotId
New-Item -ItemType Directory -Path (Join-Path $snapshotDir 'files') -Force | Out-Null
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$snapshotRestoreMetadata = Join-Path $snapshotDir 'restore-point'
New-Item -ItemType Directory -Path $snapshotRestoreMetadata -Force | Out-Null
Copy-Item -LiteralPath $managedManifest -Destination (Join-Path $snapshotRestoreMetadata 'managed-files.txt')
Copy-Item -LiteralPath $existingManifest -Destination (Join-Path $snapshotRestoreMetadata 'existing-files.txt')
Copy-Item -LiteralPath $profilesManifest -Destination (Join-Path $snapshotRestoreMetadata 'powershell-profiles.json')

$snapshotFiles = [System.Collections.Generic.List[string]]::new()
foreach ($relativePath in $managed) {
    $target = Join-Path $HOME $relativePath
    if (Test-Path -LiteralPath $target) {
        $snapshotTarget = Join-Path (Join-Path $snapshotDir 'files') $relativePath
        New-Item -ItemType Directory -Path (Split-Path -Parent $snapshotTarget) -Force | Out-Null
        Copy-PathPreservingLink -Source $target -Destination $snapshotTarget
        $snapshotFiles.Add($relativePath)
    }
}
[IO.File]::WriteAllLines((Join-Path $snapshotDir 'captured-managed-files.txt'), $snapshotFiles, $utf8NoBom)

$snapshotProfileRecords = @()
foreach ($record in $profileRecords) {
    $profileExists = Test-Path -LiteralPath $record.Path
    if ($profileExists) {
        $profileSnapshot = Join-Path $snapshotDir $record.Backup
        New-Item -ItemType Directory -Path (Split-Path -Parent $profileSnapshot) -Force | Out-Null
        Copy-PathPreservingLink -Source $record.Path -Destination $profileSnapshot
    }
    $snapshotProfileRecords += [PSCustomObject]@{
        Path = $record.Path
        Existed = $profileExists
        Backup = $record.Backup
    }
}
[IO.File]::WriteAllText(
    (Join-Path $snapshotDir 'captured-powershell-profiles.json'),
    (($snapshotProfileRecords | ConvertTo-Json -Depth 3) + [Environment]::NewLine),
    $utf8NoBom
)

foreach ($relativePath in $managed) {
    $target = Join-Path $HOME $relativePath
    if (Test-Path -LiteralPath $target) {
        Remove-Item -LiteralPath $target -Force
    }

    if ($existing.Contains($relativePath)) {
        $original = Join-Path (Join-Path $backupDir 'files') $relativePath
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Copy-PathPreservingLink -Source $original -Destination $target
        Write-Host "Restored ~\$relativePath"
    } else {
        Write-Host "Removed ~\$relativePath"
    }
}

foreach ($record in $profileRecords) {
    if (Test-Path -LiteralPath $record.Path) {
        Remove-Item -LiteralPath $record.Path -Force
    }
    if ($record.Existed) {
        $profileBackup = Join-Path $backupDir $record.Backup
        New-Item -ItemType Directory -Path (Split-Path -Parent $record.Path) -Force | Out-Null
        Copy-PathPreservingLink -Source $profileBackup -Destination $record.Path
        Write-Host "Restored $($record.Path)"
    }
}

$starshipMarker = Join-Path $stateRoot 'starship-installed-by-dotfiles'
$starshipRemovalError = $null
$starshipOwnershipReleased = $false
if (Test-Path -LiteralPath $starshipMarker) {
    $markerText = [IO.File]::ReadAllText($starshipMarker).Trim()
    $manager = $null
    $expectedVersion = $null
    try {
        $markerRecord = $markerText | ConvertFrom-Json
        $manager = [string]$markerRecord.Manager
        $expectedVersion = [string]$markerRecord.Version
    } catch {
        # Backward compatibility for early restore points that stored only the
        # package-manager name on the first line.
        $manager = $markerText
    }

    if ($expectedVersion -and (Get-Command starship -ErrorAction SilentlyContinue)) {
        $LASTEXITCODE = $null
        $installedVersion = @(& starship --version 2>$null)
        $versionInvocationSucceeded = $?
        $versionExitCode = $LASTEXITCODE
        if (-not $versionInvocationSucceeded -or
            ($null -ne $versionExitCode -and $versionExitCode -ne 0) -or
            ($installedVersion -join "`n") -notmatch ('(?m)^starship ' + [regex]::Escape($expectedVersion) + '(?:\s|$)')) {
            Write-Warning "Starship no longer matches installer-owned version $expectedVersion. Preserving the current command and releasing dotfiles ownership."
            Remove-Item -LiteralPath $starshipMarker -Force
            $starshipOwnershipReleased = $true
        }
    }

    if (-not $starshipRemovalError -and -not $starshipOwnershipReleased) {
        $removeInvocationSucceeded = $false
        $removeExitCode = $null
        if ($manager -eq 'winget' -and (Get-Command winget -ErrorAction SilentlyContinue)) {
            $LASTEXITCODE = $null
            & winget uninstall --id Starship.Starship --exact --scope user --silent
            $removeInvocationSucceeded = $?
            $removeExitCode = $LASTEXITCODE
        } elseif ($manager -eq 'scoop' -and (Get-Command scoop -ErrorAction SilentlyContinue)) {
            $LASTEXITCODE = $null
            & scoop uninstall starship
            $removeInvocationSucceeded = $?
            $removeExitCode = $LASTEXITCODE
        } else {
            $starshipRemovalError = "Could not automatically remove Starship installed with '$manager'."
        }

        if (-not $starshipRemovalError) {
            if ($removeInvocationSucceeded -and ($null -eq $removeExitCode -or $removeExitCode -eq 0)) {
                Remove-Item -LiteralPath $starshipMarker -Force
            } else {
                $exitDescription = if ($null -eq $removeExitCode) { 'PowerShell command failure' } else { "exit $removeExitCode" }
                $starshipRemovalError = "$manager could not uninstall Starship ($exitDescription)."
            }
        }
    }
}

[IO.File]::WriteAllText(
    (Join-Path $stateRoot 'last-uninstall-snapshot'),
    $snapshotId + [Environment]::NewLine,
    $utf8NoBom
)
Write-Host "Pre-uninstall files were saved to $snapshotDir"

if ($starshipRemovalError) {
    throw "$starshipRemovalError The dotfiles were restored, but the Starship ownership marker and current restore point were kept so removal can be retried."
}

# Retire this restore point after using it. A later reinstall must capture the
# user's then-current files instead of silently reusing a stale baseline.
$lastRestoredBackup = Join-Path $stateRoot 'last-restored-backup'
$lastRestoredTemporary = "$lastRestoredBackup.$PID.tmp"
try {
    [IO.File]::WriteAllText(
        $lastRestoredTemporary,
        $backupId + [Environment]::NewLine,
        $utf8NoBom
    )
    Move-Item -LiteralPath $lastRestoredTemporary -Destination $lastRestoredBackup -Force
} finally {
    if (Test-Path -LiteralPath $lastRestoredTemporary) {
        Remove-Item -LiteralPath $lastRestoredTemporary -Force
    }
}
Remove-Item -LiteralPath $currentBackup -Force

if (-not $KeepChezmoi -and (Get-Command chezmoi -ErrorAction SilentlyContinue)) {
    $LASTEXITCODE = $null
    & chezmoi purge --force
    $purgeInvocationSucceeded = $?
    $purgeExitCode = $LASTEXITCODE
    if (-not $purgeInvocationSucceeded -or
        ($null -ne $purgeExitCode -and $purgeExitCode -ne 0)) {
        $exitDescription = if ($null -eq $purgeExitCode) { 'PowerShell command failure' } else { "exit $purgeExitCode" }
        throw "chezmoi purge failed ($exitDescription). The dotfiles themselves were already restored."
    }
    Write-Host 'Purged the chezmoi source, configuration, and state.'
} else {
    Write-Host "Kept chezmoi metadata; run 'chezmoi purge --force' when it is no longer needed."
}
