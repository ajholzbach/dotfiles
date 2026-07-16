$ErrorActionPreference = 'Stop'

$script:Passed = 0
$script:Failed = 0
$repoRoot = if ($env:DOTFILES_TEST_ROOT) { $env:DOTFILES_TEST_ROOT } else { '/dotfiles' }
$renderRoot = Join-Path ([IO.Path]::GetTempPath()) "dotfiles-powershell-render-$PID"
New-Item -ItemType Directory -Path $renderRoot -Force | Out-Null

function Pass {
    param([string]$Message)
    Write-Host "  + $Message"
    $script:Passed++
}

function Fail {
    param([string]$Message)
    Write-Host "  ! $Message" -ForegroundColor Red
    $script:Failed++
}

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message
    )
    if ($Condition) { Pass $Message } else { Fail $Message }
}

function Assert-Equal {
    param(
        $Expected,
        $Actual,
        [string]$Message
    )
    if ($Expected -ceq $Actual) {
        Pass $Message
    } else {
        Fail "$Message (expected '$Expected', got '$Actual')"
    }
}

function Get-Sha256 {
    param([string]$Path)
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash
}

function Invoke-NativeChecked {
    param(
        [string]$Description,
        [scriptblock]$Command
    )

    $output = @(& $Command 2>&1)
    $exitCode = $LASTEXITCODE
    if ($exitCode -ne 0) {
        $output | ForEach-Object { Write-Host $_ }
        throw "$Description failed with exit code $exitCode."
    }
}

function Invoke-WindowsTemplate {
    param(
        [string]$RelativePath,
        [switch]$ExpectFailure
    )

    $templatePath = Join-Path $repoRoot $RelativePath
    $renderedPath = Join-Path $renderRoot (([Guid]::NewGuid().ToString('N')) + '.ps1')
    & chezmoi execute-template `
        --override-data '{"chezmoi":{"os":"windows"}}' `
        --output $renderedPath `
        --file $templatePath
    if ($LASTEXITCODE -ne 0) {
        throw "Could not render Windows template: $RelativePath"
    }

    $output = @(& pwsh -NoLogo -NoProfile -File $renderedPath 2>&1)
    $exitCode = $LASTEXITCODE
    if ($ExpectFailure) {
        if ($exitCode -ne 0) {
            Pass "$RelativePath rejects the invalid fixture"
        } else {
            Fail "$RelativePath unexpectedly accepted the invalid fixture"
        }
    } elseif ($exitCode -eq 0) {
        Pass "$RelativePath executed successfully"
    } else {
        $output | ForEach-Object { Write-Host $_ }
        Fail "$RelativePath failed with exit code $exitCode"
    }
    return $exitCode
}

function Write-UnixExecutable {
    param(
        [string]$Path,
        [string]$Content
    )
    [IO.File]::WriteAllText($Path, $Content, [Text.UTF8Encoding]::new($false))
    & chmod 0755 $Path
    if ($LASTEXITCODE -ne 0) {
        throw "Could not make mock executable: $Path"
    }
}

try {
    Write-Host '==> Preparing isolated Windows-template fixtures'
    $env:XDG_STATE_HOME = Join-Path $HOME '.dotfiles-test-state'
    $env:XDG_CONFIG_HOME = Join-Path $HOME '.xdg-config-override'
    Remove-Item Env:STARSHIP_CONFIG -ErrorAction SilentlyContinue
    Remove-Item Env:BAT_CONFIG_DIR -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $env:XDG_STATE_HOME -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath (Join-Path $HOME '.local/share/chezmoi') -Recurse -Force -ErrorAction SilentlyContinue

    $bashrc = Join-Path $HOME '.bashrc'
    $originalBashrc = "# original Windows-side bashrc`nexport ORIGINAL_WINDOWS_BASHRC=1`n"
    [IO.File]::WriteAllText($bashrc, $originalBashrc, [Text.UTF8Encoding]::new($false))
    $originalBashrcHash = Get-Sha256 $bashrc
    $zprofile = Join-Path $HOME '.zprofile'
    Remove-Item -LiteralPath $zprofile -Force -ErrorAction SilentlyContinue
    New-Item -ItemType SymbolicLink -Path $zprofile -Target '.bashrc' | Out-Null

    $documents = [Environment]::GetFolderPath([Environment+SpecialFolder]::MyDocuments)
    if ([string]::IsNullOrWhiteSpace($documents)) {
        $documents = Join-Path $HOME 'Documents'
    }
    $modernProfile = Join-Path $documents 'PowerShell\Profile.ps1'
    $legacyProfile = Join-Path $documents 'WindowsPowerShell\Profile.ps1'
    New-Item -ItemType Directory -Path (Split-Path -Parent $modernProfile) -Force | Out-Null
    Remove-Item -LiteralPath $legacyProfile -Force -ErrorAction SilentlyContinue
    $originalModernText = "# original modern profile Ω`r`n`$env:ORIGINAL_PROFILE = 'yes'`r`n"
    [IO.File]::WriteAllText(
        $modernProfile,
        $originalModernText,
        [Text.UnicodeEncoding]::new($false, $true)
    )
    $originalModernHash = Get-Sha256 $modernProfile

    Invoke-NativeChecked 'chezmoi init' {
        & chezmoi --use-builtin-git=true init "file://$repoRoot"
    }

    $restoreTemplate = 'home/.chezmoiscripts/run_before_00-create-restore-point-windows.ps1.tmpl'
    $starshipTemplate = 'home/.chezmoiscripts/run_before_12-install-starship-windows.ps1.tmpl'
    $shimTemplate = 'home/.chezmoiscripts/run_after_25-install-powershell-profile-shims.ps1.tmpl'

    [void](Invoke-WindowsTemplate $restoreTemplate)
    $stateRoot = Join-Path $env:XDG_STATE_HOME 'dotfiles'
    $currentBackup = Join-Path $stateRoot 'current-backup'
    Assert-True (Test-Path -LiteralPath $currentBackup -PathType Leaf) 'A pre-install restore point was recorded'
    $backupId = [IO.File]::ReadAllText($currentBackup).Trim()
    $backupDir = Join-Path (Join-Path $stateRoot 'backups') $backupId
    $managedManifest = Join-Path $backupDir 'managed-files.txt'
    $existingManifest = Join-Path $backupDir 'existing-files.txt'
    $profilesManifest = Join-Path $backupDir 'powershell-profiles.json'

    $existingPaths = @([IO.File]::ReadAllLines($existingManifest))
    Assert-True ($existingPaths -contains '.bashrc') 'Restore manifest includes the pre-existing .bashrc'
    Assert-Equal $originalBashrcHash (Get-Sha256 (Join-Path (Join-Path $backupDir 'files') '.bashrc')) 'Restore point preserves .bashrc bytes'
    $savedZprofile = Get-Item -LiteralPath (Join-Path (Join-Path $backupDir 'files') '.zprofile') -Force
    Assert-Equal 'SymbolicLink' $savedZprofile.LinkType 'Restore point preserves a pre-existing symbolic link'
    Assert-Equal '.bashrc' (@($savedZprofile.Target)[0]) 'Restore point preserves a relative symbolic-link target'

    $profileRecords = @((Get-Content -LiteralPath $profilesManifest -Raw | ConvertFrom-Json))
    Assert-True ([bool]$profileRecords[0].Existed) 'Restore point records the modern PowerShell profile'
    Assert-True (-not [bool]$profileRecords[1].Existed) 'Restore point records the legacy profile as absent'
    Assert-Equal $originalModernHash (Get-Sha256 (Join-Path $backupDir 'profiles/0')) 'Restore point preserves UTF-16 profile bytes'

    [void](Invoke-WindowsTemplate $restoreTemplate)
    Assert-Equal $backupId ([IO.File]::ReadAllText($currentBackup).Trim()) 'A repeated pre-apply keeps the original restore point'
    Assert-Equal 1 (@(Get-ChildItem -LiteralPath (Join-Path $stateRoot 'backups') -Directory).Count) 'A repeated pre-apply does not create another backup'

    Invoke-NativeChecked 'chezmoi apply without scripts' {
        & chezmoi apply --exclude=scripts
    }
    $sharedPowerShellProfile = Join-Path $HOME '.config/powershell/profile.ps1'
    Assert-True (Test-Path -LiteralPath $sharedPowerShellProfile -PathType Leaf) 'Shared PowerShell profile is managed on every platform'

    # A run_before restore script must add future source targets to the same
    # original restore point before chezmoi can overwrite them.
    $lateTarget = Join-Path $HOME '.late-managed-fixture'
    $lateOriginal = "late target before it became managed`n"
    [IO.File]::WriteAllText($lateTarget, $lateOriginal, [Text.UTF8Encoding]::new($false))
    $lateOriginalHash = Get-Sha256 $lateTarget
    Invoke-NativeChecked 'chezmoi add of late target' {
        & chezmoi add $lateTarget
    }
    [void](Invoke-WindowsTemplate $restoreTemplate)
    Assert-True (([IO.File]::ReadAllLines($managedManifest)) -contains '.late-managed-fixture') 'Restore manifest reconciles a newly managed target'
    Assert-True (([IO.File]::ReadAllLines($existingManifest)) -contains '.late-managed-fixture') 'Restore manifest records the newly managed target as pre-existing'
    Assert-Equal $lateOriginalHash (Get-Sha256 (Join-Path (Join-Path $backupDir 'files') '.late-managed-fixture')) 'Reconciliation preserves the late target bytes'
    [void](Invoke-WindowsTemplate $restoreTemplate)
    Assert-Equal 1 (@([IO.File]::ReadAllLines($managedManifest) | Where-Object { $_ -eq '.late-managed-fixture' }).Count) 'Reconciliation is idempotent'

    $lateSource = @(& chezmoi source-path $lateTarget)
    if ($LASTEXITCODE -ne 0 -or $lateSource.Count -ne 1) {
        throw 'Could not locate the source path for the late managed fixture.'
    }
    [IO.File]::WriteAllText($lateSource[0], "managed replacement`n", [Text.UTF8Encoding]::new($false))
    Invoke-NativeChecked 'chezmoi apply after reconciliation' {
        & chezmoi apply --exclude=scripts
    }

    Write-Host '==> Testing fixed managed-config paths in the shared profile'
    . $sharedPowerShellProfile
    Assert-Equal (Join-Path (Join-Path $HOME '.config') 'starship.toml') $env:STARSHIP_CONFIG 'STARSHIP_CONFIG defaults to the managed ~/.config path'
    Assert-Equal (Join-Path (Join-Path $HOME '.config') 'bat') $env:BAT_CONFIG_DIR 'BAT_CONFIG_DIR defaults to the managed ~/.config path'
    $env:STARSHIP_CONFIG = 'explicit-starship-config'
    $env:BAT_CONFIG_DIR = 'explicit-bat-config'
    . $sharedPowerShellProfile
    Assert-Equal 'explicit-starship-config' $env:STARSHIP_CONFIG 'An explicit STARSHIP_CONFIG is preserved'
    Assert-Equal 'explicit-bat-config' $env:BAT_CONFIG_DIR 'An explicit BAT_CONFIG_DIR is preserved'

    Write-Host '==> Testing mocked Starship package-manager paths'
    $mockBin = Join-Path $HOME 'mock-package-bin'
    $mockLog = Join-Path $HOME 'mock-package-manager.log'
    New-Item -ItemType Directory -Path $mockBin -Force | Out-Null
    Remove-Item -LiteralPath $mockLog -Force -ErrorAction SilentlyContinue
    $env:MOCK_BIN = $mockBin
    $env:MOCK_PACKAGE_LOG = $mockLog
    $env:PATH = $mockBin + [IO.Path]::PathSeparator + $env:PATH

    $starshipMock = @'
#!/usr/bin/env bash
set -eu
if [ "${1:-}" = "--version" ]; then
    printf '%s\n' 'starship 2.34.5'
fi
exit 0
'@
    $wingetMock = @'
#!/usr/bin/env bash
set -eu
printf 'winget %s\n' "$*" >> "$MOCK_PACKAGE_LOG"
case "${1:-}" in
    install)
        printf '%s' "$MOCK_STARSHIP_CONTENT" > "$MOCK_BIN/starship"
        chmod 0755 "$MOCK_BIN/starship"
        ;;
    uninstall)
        rm -f "$MOCK_BIN/starship"
        ;;
esac
'@
    $scoopMock = @'
#!/usr/bin/env bash
set -eu
printf 'scoop %s\n' "$*" >> "$MOCK_PACKAGE_LOG"
case "${1:-}" in
    install)
        printf '%s' "$MOCK_STARSHIP_CONTENT" > "$MOCK_BIN/starship"
        chmod 0755 "$MOCK_BIN/starship"
        ;;
    uninstall)
        rm -f "$MOCK_BIN/starship"
        ;;
esac
'@
    $env:MOCK_STARSHIP_CONTENT = $starshipMock
    Write-UnixExecutable (Join-Path $mockBin 'winget') $wingetMock

    Write-UnixExecutable (Join-Path $mockBin 'starship') "#!/usr/bin/env bash`nexit 9`n"
    [void](Invoke-WindowsTemplate $starshipTemplate -ExpectFailure)
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $stateRoot 'starship-installed-by-dotfiles'))) 'An invalid pre-existing Starship command is not claimed'
    Remove-Item -LiteralPath (Join-Path $mockBin 'starship') -Force

    Write-UnixExecutable (Join-Path $mockBin 'starship') "#!/usr/bin/env bash`nprintf '%s\n' 'starship 9.9.9'`n"
    [void](Invoke-WindowsTemplate $starshipTemplate)
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $stateRoot 'starship-installed-by-dotfiles'))) 'A valid user-installed Starship is not claimed'
    Assert-True (-not (Test-Path -LiteralPath $mockLog)) 'A valid user-installed Starship skips package installation'
    Remove-Item -LiteralPath (Join-Path $mockBin 'starship') -Force

    # Exercise the Scoop fallback in an isolated state directory, then use
    # winget for the end-to-end install/uninstall ownership path.
    $mainStateHome = $env:XDG_STATE_HOME
    $scoopStateHome = Join-Path $HOME '.dotfiles-test-scoop-state'
    $wingetPath = Join-Path $mockBin 'winget'
    $wingetDisabled = Join-Path $mockBin 'winget.disabled'
    Move-Item -LiteralPath $wingetPath -Destination $wingetDisabled
    Write-UnixExecutable (Join-Path $mockBin 'scoop') $scoopMock
    $env:XDG_STATE_HOME = $scoopStateHome
    [void](Invoke-WindowsTemplate $starshipTemplate)
    $scoopMarker = [IO.File]::ReadAllText((Join-Path $scoopStateHome 'dotfiles/starship-installed-by-dotfiles')) | ConvertFrom-Json
    Assert-Equal 'scoop' $scoopMarker.Manager 'Scoop fallback records its ownership manager'
    Assert-Equal '2.34.5' $scoopMarker.Version 'Scoop fallback records the version reported by the installed binary'
    $scoopInstallLine = @([IO.File]::ReadAllLines($mockLog) | Where-Object { $_ -match '^scoop install ' })[-1]
    Assert-Equal 'scoop install starship' $scoopInstallLine 'Scoop fallback requests the latest available Starship package'
    Remove-Item -LiteralPath (Join-Path $mockBin 'starship') -Force
    Remove-Item -LiteralPath (Join-Path $mockBin 'scoop') -Force
    Move-Item -LiteralPath $wingetDisabled -Destination $wingetPath
    $env:XDG_STATE_HOME = $mainStateHome

    [void](Invoke-WindowsTemplate $starshipTemplate)
    $starshipMarker = Join-Path $stateRoot 'starship-installed-by-dotfiles'
    $wingetMarker = [IO.File]::ReadAllText($starshipMarker) | ConvertFrom-Json
    Assert-Equal 'winget' $wingetMarker.Manager 'winget installation records its ownership manager'
    Assert-Equal '2.34.5' $wingetMarker.Version 'winget installation records the version reported by the installed binary'
    $wingetInstallLine = @([IO.File]::ReadAllLines($mockLog) | Where-Object { $_ -match '^winget install ' })[-1]
    Assert-True ($wingetInstallLine -notmatch '(?:^|\s)--version(?:\s|$)') 'winget installation leaves version selection to the package manager'
    $wingetInstallCount = @([IO.File]::ReadAllLines($mockLog) | Where-Object { $_ -match '^winget install ' }).Count
    [void](Invoke-WindowsTemplate $starshipTemplate)
    Assert-Equal $wingetInstallCount (@([IO.File]::ReadAllLines($mockLog) | Where-Object { $_ -match '^winget install ' }).Count) 'Starship installation is idempotent'

    Write-Host '==> Testing PowerShell profile shim reconciliation'
    [void](Invoke-WindowsTemplate $shimTemplate)
    $modernBytes = [IO.File]::ReadAllBytes($modernProfile)
    Assert-True ($modernBytes[0] -eq 0xFF -and $modernBytes[1] -eq 0xFE) 'Profile shim preserves a UTF-16LE BOM'
    $modernManagedText = [IO.File]::ReadAllText($modernProfile)
    Assert-True ($modernManagedText.Contains($originalModernText)) 'Profile shim preserves surrounding user content'
    Assert-Equal 1 ([regex]::Matches($modernManagedText, [regex]::Escape('# >>> dotfiles managed PowerShell profile >>>')).Count) 'Modern profile receives one shim block'
    Assert-True (Test-Path -LiteralPath $legacyProfile -PathType Leaf) 'Missing legacy profile is created'

    $modernShimHash = Get-Sha256 $modernProfile
    $legacyShimHash = Get-Sha256 $legacyProfile
    [void](Invoke-WindowsTemplate $shimTemplate)
    Assert-Equal $modernShimHash (Get-Sha256 $modernProfile) 'Modern profile shim is byte-idempotent'
    Assert-Equal $legacyShimHash (Get-Sha256 $legacyProfile) 'Legacy profile shim is byte-idempotent'

    $duplicateBlock = @(
        '# >>> dotfiles managed PowerShell profile >>>',
        '. (Join-Path (Join-Path $HOME ''.config'') ''powershell\profile.ps1'')',
        '# <<< dotfiles managed PowerShell profile <<<'
    ) -join "`r`n"
    [IO.File]::WriteAllText(
        $modernProfile,
        $modernManagedText + $duplicateBlock + "`r`n",
        [Text.UnicodeEncoding]::new($false, $true)
    )
    [void](Invoke-WindowsTemplate $shimTemplate)
    Assert-Equal 1 ([regex]::Matches([IO.File]::ReadAllText($modernProfile), [regex]::Escape('# >>> dotfiles managed PowerShell profile >>>')).Count) 'Duplicate complete shim blocks collapse to one'

    $modernBeforeMalformedHash = Get-Sha256 $modernProfile
    $malformedText = "# user legacy content`n# >>> dotfiles managed PowerShell profile >>>`n"
    [IO.File]::WriteAllText($legacyProfile, $malformedText, [Text.UTF8Encoding]::new($false))
    [void](Invoke-WindowsTemplate $shimTemplate -ExpectFailure)
    Assert-Equal $modernBeforeMalformedHash (Get-Sha256 $modernProfile) 'Malformed markers are rejected before either profile is modified'
    Assert-Equal $malformedText ([IO.File]::ReadAllText($legacyProfile)) 'Malformed profile content remains untouched'

    Write-Host '==> Testing uninstall dry-run and restoration'
    $managedBashrcHash = Get-Sha256 $bashrc
    $managedModernHash = Get-Sha256 $modernProfile
    Invoke-NativeChecked 'PowerShell uninstall dry run' {
        & pwsh -NoLogo -NoProfile -File (Join-Path $repoRoot 'uninstall.ps1') -DryRun -Yes -KeepChezmoi
    }
    Assert-Equal $managedBashrcHash (Get-Sha256 $bashrc) 'Uninstall dry-run leaves managed files unchanged'
    Assert-Equal $managedModernHash (Get-Sha256 $modernProfile) 'Uninstall dry-run leaves profile shims unchanged'
    Assert-True (Test-Path -LiteralPath (Join-Path $mockBin 'starship')) 'Uninstall dry-run leaves Starship installed'

    $wingetUninstallCount = @([IO.File]::ReadAllLines($mockLog) | Where-Object { $_ -match '^winget uninstall ' }).Count
    Write-UnixExecutable (Join-Path $mockBin 'starship') "#!/usr/bin/env bash`nprintf '%s\n' 'starship 9.9.9'`n"
    Invoke-NativeChecked 'PowerShell uninstall with changed Starship' {
        & pwsh -NoLogo -NoProfile -File (Join-Path $repoRoot 'uninstall.ps1') -Yes -KeepChezmoi
    }
    Assert-True (Test-Path -LiteralPath (Join-Path $mockBin 'starship') -PathType Leaf) 'Uninstall preserves a replaced or upgraded Starship command'
    Assert-True (-not (Test-Path -LiteralPath $starshipMarker)) 'A changed Starship releases the stale dotfiles ownership marker'
    Assert-True (-not (Test-Path -LiteralPath $currentBackup)) 'Conservative Starship preservation still retires the used restore point'
    Assert-Equal $wingetUninstallCount (@([IO.File]::ReadAllLines($mockLog) | Where-Object { $_ -match '^winget uninstall ' }).Count) 'A changed Starship is not passed to winget uninstall'
    Assert-Equal $originalBashrcHash (Get-Sha256 $bashrc) 'Conservative uninstall restores the original .bashrc byte-for-byte'
    Assert-Equal $originalModernHash (Get-Sha256 $modernProfile) 'Conservative uninstall restores the original PowerShell profile'
    Assert-Equal 'SymbolicLink' ((Get-Item -LiteralPath $zprofile -Force).LinkType) 'Conservative uninstall restores the original symbolic-link type'

    # Start a fresh install cycle to exercise successful package-manager
    # removal independently from the conservative changed-version path.
    Remove-Item -LiteralPath (Join-Path $mockBin 'starship') -Force
    [void](Invoke-WindowsTemplate $restoreTemplate)
    $retryBackupId = [IO.File]::ReadAllText($currentBackup).Trim()
    Assert-True ($retryBackupId -ne $backupId) 'A reinstall captures a fresh restore-point identifier'
    Invoke-NativeChecked 'second chezmoi apply without scripts' {
        & chezmoi apply --force --no-tty --exclude=scripts
    }
    [void](Invoke-WindowsTemplate $starshipTemplate)
    [void](Invoke-WindowsTemplate $shimTemplate)

    Invoke-NativeChecked 'PowerShell uninstall restore' {
        & pwsh -NoLogo -NoProfile -File (Join-Path $repoRoot 'uninstall.ps1') -Yes -KeepChezmoi
    }
    Assert-Equal $originalBashrcHash (Get-Sha256 $bashrc) 'Uninstall restores the original .bashrc byte-for-byte'
    Assert-Equal $originalModernHash (Get-Sha256 $modernProfile) 'Uninstall restores the UTF-16 profile byte-for-byte'
    Assert-Equal '.bashrc' (@((Get-Item -LiteralPath $zprofile -Force).Target)[0]) 'Uninstall restores the relative symbolic-link target'
    Assert-True (-not (Test-Path -LiteralPath $legacyProfile)) 'Uninstall removes a profile that did not exist before installation'
    Assert-Equal $lateOriginalHash (Get-Sha256 $lateTarget) 'Uninstall restores a target added after the initial install'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $mockBin 'starship'))) 'Uninstall removes installer-owned Starship'
    Assert-True (-not (Test-Path -LiteralPath $starshipMarker)) 'Successful Starship removal clears its ownership marker'
    Assert-True (([IO.File]::ReadAllText($mockLog)) -match 'winget uninstall ') 'Uninstall invokes the recorded package manager'
    Assert-True (-not (Test-Path -LiteralPath $currentBackup)) 'A used restore point is retired for a future reinstall'
    Assert-Equal $retryBackupId ([IO.File]::ReadAllText((Join-Path $stateRoot 'last-restored-backup')).Trim()) 'The retired restore point remains discoverable'
    $lastSnapshotId = [IO.File]::ReadAllText((Join-Path $stateRoot 'last-uninstall-snapshot')).Trim()
    $lastSnapshot = Join-Path (Join-Path $stateRoot 'uninstall-snapshots') $lastSnapshotId
    Assert-True (Test-Path -LiteralPath $lastSnapshot -PathType Container) 'A pre-uninstall recovery snapshot is recorded'
    Assert-True (Test-Path -LiteralPath (Join-Path $lastSnapshot 'captured-managed-files.txt') -PathType Leaf) 'Recovery snapshot includes a managed-file manifest'
    Assert-True (Test-Path -LiteralPath (Join-Path $lastSnapshot 'captured-powershell-profiles.json') -PathType Leaf) 'Recovery snapshot includes a PowerShell-profile manifest'
    Assert-True (Test-Path -LiteralPath (Join-Path $HOME '.local/share/chezmoi') -PathType Container) '-KeepChezmoi preserves chezmoi source metadata'
} finally {
    Remove-Item -LiteralPath $renderRoot -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "`n==> Summary: $script:Passed passed, $script:Failed failed"
if ($script:Failed -gt 0) {
    exit 1
}
Write-Host '==> All PowerShell tests passed!'
