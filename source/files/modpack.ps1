# Rotwood mod pack: install / uninstall / check.
# Windows PowerShell 5.1 or newer. Plain text on purpose: read it before you run it.
#
# What "install" changes on your PC (and nothing else):
#   1. <Rotwood game folder>\data_scripts.zip : one line is added to scripts/main.lua inside it
#      (the line in hook_line.txt). The file as it was is kept next to it as
#      data_scripts.before_modpack_change.zip.
#   2. %APPDATA%\Klei\Rotwood\steam-<id>\mods\ : the pack's mod folders, nativeloader.lua and
#      (only if you have none) nativeloader_settings.lua are copied in. Folders it replaces
#      are moved to %APPDATA%\Klei\Rotwood\steam-<id>\modpack_backup\<date>\ first.
#   3. Before the mods go in, your save folder (everything in steam-<id> except the mods) is
#      copied to %APPDATA%\Klei\Rotwood\steam-<id>\modpack_backup\saves_before_install_<date>\.
# "uninstall" takes the line out again and moves the pack's files to modpack_backup.
# "check" only looks and reports.
# No internet, no registry writes, no admin rights, nothing deleted.

param(
    [Parameter(Position = 0)][string]$Action = 'check',
    [string]$GameDir = '',
    [string]$SaveDir = '',
    [switch]$Force
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Latin1 = [System.Text.Encoding]::GetEncoding(28591)
$MainLua = 'scripts/main.lua'
$HookMark = 'kleiloadlua("MODS:nativeloader.lua")'
$Stamp = (Get-Date).ToString('yyyy-MM-dd_HHmmss')
$script:TmpZip = ''

function Say([string]$text) { Write-Host $text }

function Stop-Here([string]$text) { throw ('STOPPED: ' + $text) }

function Join2([string]$a, [string]$b) { return [System.IO.Path]::Combine($a, $b) }

function New-Folder([string]$path) { [System.IO.Directory]::CreateDirectory($path) | Out-Null }

function Read-KeyValues([string]$path) {
    $map = @{}
    if (Test-Path -LiteralPath $path) {
        foreach ($line in [System.IO.File]::ReadAllLines($path)) {
            $at = $line.IndexOf('=')
            if ($at -gt 0) { $map[$line.Substring(0, $at).Trim()] = $line.Substring($at + 1).Trim() }
        }
    }
    return $map
}

function Get-PackInfo {
    $info = Read-KeyValues (Join2 $Here 'pack_info.txt')
    foreach ($key in @('pack', 'version')) {
        if (-not $info.ContainsKey($key)) { Stop-Here ('the pack is not complete (pack_info.txt has no "' + $key + '"). Unpack the whole zip again.') }
    }
    return $info
}

function Get-HookLine {
    $path = Join2 $Here 'hook_line.txt'
    if (-not (Test-Path -LiteralPath $path)) { Stop-Here 'the pack is not complete (hook_line.txt is missing). Unpack the whole zip again.' }
    $hook = [System.IO.File]::ReadAllText($path).Trim()
    if (-not $hook.StartsWith('do local nl = ' + $HookMark) -or $hook.Contains("`n") -or -not $hook.Contains('-- Native Loader hook')) {
        Stop-Here 'hook_line.txt is not the line this installer expects. Unpack the whole zip again.'
    }
    return $hook
}

function Get-PackMods {
    $names = New-Object 'System.Collections.Generic.List[string]'
    $dir = Join2 $Here 'mods'
    if (Test-Path -LiteralPath $dir) {
        foreach ($d in @(Get-ChildItem -LiteralPath $dir -Directory | Sort-Object Name)) {
            if (Test-Path -LiteralPath (Join2 $d.FullName 'modinfo.lua')) { $names.Add($d.Name) }
        }
    }
    if ($names.Count -eq 0) { Stop-Here 'the pack is not complete (no mods in the files\mods folder). Unpack the whole zip again.' }
    if (-not (Test-Path -LiteralPath (Join2 $Here 'nativeloader.lua'))) { Stop-Here 'the pack is not complete (nativeloader.lua is missing). Unpack the whole zip again.' }
    return , $names
}

function Find-GameDirs {
    $found = New-Object 'System.Collections.Generic.List[string]'
    $roots = New-Object 'System.Collections.Generic.List[string]'
    foreach ($key in @('HKCU:\Software\Valve\Steam', 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam', 'HKLM:\SOFTWARE\Valve\Steam')) {
        foreach ($name in @('SteamPath', 'InstallPath')) {
            $value = $null
            try { $value = (Get-ItemProperty -LiteralPath $key -Name $name -ErrorAction Stop).$name } catch { $value = $null }
            if ($value) { $roots.Add(([string]$value).Replace('/', '\')) }
        }
    }
    $libs = New-Object 'System.Collections.Generic.List[string]'
    foreach ($root in $roots) {
        $libs.Add($root)
        $vdf = Join2 $root 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf) {
            foreach ($line in [System.IO.File]::ReadAllLines($vdf)) {
                if ($line -match '^\s*"path"\s+"(.+)"\s*$') { $libs.Add($Matches[1].Replace('\\', '\')) }
            }
        }
    }
    foreach ($lib in $libs) {
        $dir = Join2 $lib 'steamapps\common\Rotwood'
        if (Test-Path -LiteralPath (Join2 $dir 'data_scripts.zip')) {
            $full = [System.IO.Path]::GetFullPath($dir).TrimEnd('\')
            $known = $false
            foreach ($f in $found) { if ($f -ieq $full) { $known = $true } }
            if (-not $known) { $found.Add($full) }
        }
    }
    return , $found
}

function Resolve-GameDir {
    if ($GameDir) {
        $given = $GameDir.Trim().Trim('"').TrimEnd('\')
        if (-not (Test-Path -LiteralPath (Join2 $given 'data_scripts.zip'))) { Stop-Here ('no data_scripts.zip in ' + $given) }
        return $given
    }
    $found = Find-GameDirs
    if ($found.Count -ge 1) { return $found[0] }
    Say 'Rotwood was not found in your Steam libraries.'
    $typed = Read-Host 'Paste the Rotwood folder (the one with data_scripts.zip in it) and press Enter'
    $typed = ([string]$typed).Trim().Trim('"').TrimEnd('\')
    if ($typed -and (Test-Path -LiteralPath (Join2 $typed 'data_scripts.zip'))) { return $typed }
    Stop-Here 'there is no data_scripts.zip in that folder. Nothing was changed.'
}

function Resolve-SaveDirs {
    $list = New-Object 'System.Collections.Generic.List[string]'
    if ($SaveDir) {
        $given = $SaveDir.Trim().Trim('"').TrimEnd('\')
        if (-not (Test-Path -LiteralPath $given)) { Stop-Here ('this folder does not exist: ' + $given) }
        $list.Add($given)
        return , $list
    }
    $base = Join2 $env:APPDATA 'Klei\Rotwood'
    if (Test-Path -LiteralPath $base) {
        foreach ($d in @(Get-ChildItem -LiteralPath $base -Directory | Where-Object { $_.Name -like 'steam-*' } | Sort-Object Name)) { $list.Add($d.FullName) }
    }
    return , $list
}

function Get-RunningGame([string]$gameDir) {
    $prefix = $gameDir.TrimEnd('\') + '\'
    foreach ($p in @(Get-Process)) {
        $path = $null
        try { $path = $p.Path } catch { $path = $null }
        if ($path -and ([string]$path).StartsWith($prefix, [System.StringComparison]::OrdinalIgnoreCase)) { return [string]$p.ProcessName }
    }
    return ''
}

function Test-CanWrite([string]$path) {
    try {
        $fs = [System.IO.File]::Open($path, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
        $fs.Dispose()
        return $true
    } catch {
        return $false
    }
}

# The text of one file inside a zip (bytes kept one to one), or '' when the file is not in it.
function Read-ZipEntry([string]$zipPath, [string]$entryName) {
    $text = ''
    $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        $entry = $zip.GetEntry($entryName)
        if ($null -ne $entry) {
            $reader = $entry.Open()
            try {
                $ms = New-Object System.IO.MemoryStream
                $reader.CopyTo($ms)
                $text = $Latin1.GetString($ms.ToArray())
            } finally { $reader.Dispose() }
        }
    } finally { $zip.Dispose() }
    return $text
}

function Get-MainState([string]$text) {
    $state = @{ Hook = 0; OldPatch = $false; Anchor = -1; AnchorCount = 0 }
    $lines = $text.Split([char]10)
    for ($i = 0; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]
        if ($line.Contains($HookMark)) {
            $state.Hook = $state.Hook + 1
        } elseif (($line -cmatch '^\s*ModManager:LoadMods\(\)') -or ($line -cmatch '^\s*GAMEPLAY_MODS_ENABLED\s*=\s*true')) {
            $state.OldPatch = $true
        } elseif ($line -cmatch '^\s*--\s*ModManager:LoadMods\(\)\s*$') {
            $state.Anchor = $i
            $state.AnchorCount = $state.AnchorCount + 1
        }
    }
    return $state
}

function Get-StateText($state) {
    if ($state.OldPatch) { return 'another mod loader patch is in it (main.lua calls ModManager:LoadMods)' }
    if ($state.Hook -eq 1) { return 'the mod pack line is in it' }
    if ($state.Hook -gt 1) { return ('the mod pack line is in it ' + $state.Hook + ' times') }
    if ($state.AnchorCount -eq 1) { return 'unmodified (no mod pack line)' }
    return ('unmodified, but the place for the line was found ' + $state.AnchorCount + ' times instead of once')
}

function Add-Hook([string]$text, [string]$hook, [int]$at) {
    $lines = $text.Split([char]10)
    $anchor = $lines[$at]
    $indent = ''
    if ($anchor -cmatch '^([ \t]*)') { $indent = $Matches[1] }
    $tail = ''
    if ($anchor.EndsWith("`r")) { $tail = "`r" }
    $out = New-Object 'System.Collections.Generic.List[string]'
    for ($i = 0; $i -lt $lines.Length; $i++) {
        $out.Add($lines[$i])
        if ($i -eq $at) { $out.Add($indent + $hook + $tail) }
    }
    return [string]::Join("`n", $out.ToArray())
}

function Remove-Hook([string]$text) {
    $out = New-Object 'System.Collections.Generic.List[string]'
    foreach ($line in $text.Split([char]10)) {
        if (-not $line.Contains($HookMark)) { $out.Add($line) }
    }
    return [string]::Join("`n", $out.ToArray())
}

# Builds <zip>.modpack_new: a copy of the zip in which only scripts/main.lua has new text.
# Every other file in it stays as it is. Checks the result before returning its path.
function New-PatchedZip([string]$zipPath, [string]$newText) {
    $tmp = $zipPath + '.modpack_new'
    $script:TmpZip = $tmp
    if (Test-Path -LiteralPath $tmp) { Remove-Item -LiteralPath $tmp -Force }
    [System.IO.File]::Copy($zipPath, $tmp, $true)
    $bytes = $Latin1.GetBytes($newText)
    $zip = [System.IO.Compression.ZipFile]::Open($tmp, [System.IO.Compression.ZipArchiveMode]::Update)
    try {
        $entry = $zip.GetEntry($MainLua)
        $writer = $entry.Open()
        try {
            $writer.SetLength(0)
            $writer.Write($bytes, 0, $bytes.Length)
        } finally { $writer.Dispose() }
    } finally { $zip.Dispose() }

    $a = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        $b = [System.IO.Compression.ZipFile]::OpenRead($tmp)
        try {
            $count = $a.Entries.Count
            if ($count -ne $b.Entries.Count) { Stop-Here 'the new game file did not come out right (file count differs). Nothing was changed.' }
            for ($i = 0; $i -lt $count; $i++) {
                $x = $a.Entries[$i]
                $y = $b.Entries[$i]
                if ($x.FullName -cne $y.FullName) { Stop-Here ('the new game file did not come out right (' + $x.FullName + ' moved). Nothing was changed.') }
                if (($x.FullName -cne $MainLua) -and ($x.Length -ne $y.Length)) { Stop-Here ('the new game file did not come out right (' + $x.FullName + ' changed size). Nothing was changed.') }
            }
        } finally { $b.Dispose() }
    } finally { $a.Dispose() }
    if ((Read-ZipEntry $tmp $MainLua) -cne $newText) { Stop-Here 'the new game file did not come out right (main.lua differs). Nothing was changed.' }
    return $tmp
}

# Puts the new zip in place. The zip as it was is kept as data_scripts.before_modpack_change.zip
# and is put back if anything goes wrong.
function Switch-Zip([string]$zipPath, [string]$tmp, [string]$expectedText) {
    $backup = Join2 (Split-Path -Parent $zipPath) 'data_scripts.before_modpack_change.zip'
    [System.IO.File]::Copy($zipPath, $backup, $true)
    try {
        [System.IO.File]::Copy($tmp, $zipPath, $true)
        if ((Read-ZipEntry $zipPath $MainLua) -cne $expectedText) { throw 'the game file does not read back right' }
    } catch {
        [System.IO.File]::Copy($backup, $zipPath, $true)
        Stop-Here ('the game file could not be replaced (' + [string]$_.Exception.Message + '). The old one was put back.')
    }
    Remove-Item -LiteralPath $tmp -Force
    $script:TmpZip = ''
    return $backup
}

function Get-FolderStats([string]$dir) {
    $count = 0
    $bytes = [long]0
    foreach ($f in @(Get-ChildItem -LiteralPath $dir -Recurse -File -Force)) {
        $count = $count + 1
        $bytes = $bytes + $f.Length
    }
    return ('' + $count + ' files, ' + $bytes + ' bytes')
}

# A copy of the player's save folder: everything in steam-<id> except the mods and the backups.
function Backup-Saves([string]$saveDir) {
    $dest = Join2 (Join2 $saveDir 'modpack_backup') ('saves_before_install_' + $Stamp)
    $count = 0
    foreach ($item in @(Get-ChildItem -LiteralPath $saveDir -Force)) {
        if (($item.Name -ieq 'mods') -or ($item.Name -ieq 'modpack_backup')) { continue }
        try {
            New-Folder $dest
            if ($item.PSIsContainer) {
                Copy-Item -LiteralPath $item.FullName -Destination $dest -Recurse -Force
            } else {
                [System.IO.File]::Copy($item.FullName, (Join2 $dest $item.Name), $true)
            }
        } catch {
            Stop-Here ('your saves could not be copied (' + $item.Name + ': ' + [string]$_.Exception.Message + '). The game and the mods folder were not changed.')
        }
        if ($item.PSIsContainer -and ((Get-FolderStats $item.FullName) -ne (Get-FolderStats (Join2 $dest $item.Name)))) {
            Stop-Here ('the copy of your saves is not complete (' + $item.Name + '). The game and the mods folder were not changed.')
        }
        $count = $count + 1
    }
    if ($count -gt 0) {
        Say ('  saves: a copy of your save folder (everything except the mods) is in ' + $dest)
    } else {
        Say '  saves: nothing to back up yet'
    }
}

function Install-Mods([string]$saveDir, $packMods, $info) {
    $mods = Join2 $saveDir 'mods'
    $backup = Join2 (Join2 $saveDir 'modpack_backup') $Stamp
    New-Folder $mods
    $marker = Join2 $mods 'modpack_installed.txt'
    $have = Read-KeyValues $marker
    if ((-not $Force) -and $have.ContainsKey('pack') -and $have.ContainsKey('version') -and ($have['pack'] -eq $info['pack']) -and ($have['version'] -eq $info['version'])) {
        Say ('  mods: ' + $info['pack'] + ' ' + $info['version'] + ' is already in ' + $mods + ' (left as it is, your settings are kept)')
        return
    }
    Backup-Saves $saveDir
    if (Test-Path -LiteralPath $marker) { Remove-Item -LiteralPath $marker -Force }
    $moved = 0
    foreach ($name in $packMods) {
        $src = Join2 (Join2 $Here 'mods') $name
        $dst = Join2 $mods $name
        if (Test-Path -LiteralPath $dst) {
            New-Folder $backup
            Move-Item -LiteralPath $dst -Destination (Join2 $backup $name)
            $moved = $moved + 1
        }
        Copy-Item -LiteralPath $src -Destination $mods -Recurse
        if ((Get-FolderStats $src) -ne (Get-FolderStats $dst)) { Stop-Here ('the copy of ' + $name + ' is not complete. The game file was not changed. Run Install again.') }
    }
    $loaderDst = Join2 $mods 'nativeloader.lua'
    if (Test-Path -LiteralPath $loaderDst) {
        New-Folder $backup
        [System.IO.File]::Copy($loaderDst, (Join2 $backup 'nativeloader.lua'), $true)
    }
    [System.IO.File]::Copy((Join2 $Here 'nativeloader.lua'), $loaderDst, $true)
    $settingsDst = Join2 $mods 'nativeloader_settings.lua'
    if (-not (Test-Path -LiteralPath $settingsDst)) { [System.IO.File]::Copy((Join2 $Here 'nativeloader_settings.lua'), $settingsDst, $false) }
    $lines = @(('pack=' + $info['pack']), ('version=' + $info['version']), ('installed=' + $Stamp), ('mods=' + [string]::Join(',', $packMods.ToArray())))
    [System.IO.File]::WriteAllLines($marker, [string[]]$lines)
    Say ('  mods: ' + $packMods.Count + ' mods copied to ' + $mods)
    if ($moved -gt 0) { Say ('  ' + $moved + ' folders that were already there (with their settings) were moved to ' + $backup) }
    foreach ($d in @(Get-ChildItem -LiteralPath $mods -Directory | Sort-Object Name)) {
        if ((-not $packMods.Contains($d.Name)) -and (Test-Path -LiteralPath (Join2 $d.FullName 'modinfo.lua'))) {
            Say ('  note: ' + $d.Name + ' is in the mods folder too. It is not part of this pack and will be loaded as well.')
        }
    }
}

function Uninstall-Mods([string]$saveDir, $packMods) {
    $mods = Join2 $saveDir 'mods'
    if (-not (Test-Path -LiteralPath $mods)) { return }
    $backup = Join2 (Join2 $saveDir 'modpack_backup') ($Stamp + '_uninstalled')
    $names = New-Object 'System.Collections.Generic.List[string]'
    foreach ($name in $packMods) { $names.Add($name) }
    $have = Read-KeyValues (Join2 $mods 'modpack_installed.txt')
    if ($have.ContainsKey('mods')) {
        foreach ($name in $have['mods'].Split(',')) {
            $clean = $name.Trim()
            if ($clean -and ($clean -notmatch '[\\/:*?"<>|]') -and ($clean -ne '.') -and ($clean -ne '..') -and (-not $names.Contains($clean))) { $names.Add($clean) }
        }
    }
    foreach ($name in @('nativeloader.lua', 'nativeloader_settings.lua', 'modpack_installed.txt')) { $names.Add($name) }
    $moved = 0
    foreach ($name in $names) {
        $path = Join2 $mods $name
        if (Test-Path -LiteralPath $path) {
            New-Folder $backup
            Move-Item -LiteralPath $path -Destination (Join2 $backup $name)
            $moved = $moved + 1
        }
    }
    if ($moved -gt 0) {
        Say ('  ' + $moved + ' items moved out of ' + $mods)
        Say ('  they are now in ' + $backup + ' (delete that folder if you do not want them)')
    } else {
        Say ('  nothing of the pack was in ' + $mods)
    }
}

function Show-Found([string]$game, $saves, $state) {
    Say ('Game folder : ' + $game)
    Say ('Game file   : ' + (Join2 $game 'data_scripts.zip') + ' - ' + (Get-StateText $state))
    if ($saves.Count -eq 0) { Say 'Mods folder : none yet (no %APPDATA%\Klei\Rotwood\steam-... folder)' }
    foreach ($save in $saves) {
        $have = Read-KeyValues (Join2 (Join2 $save 'mods') 'modpack_installed.txt')
        $what = 'pack not installed here'
        if ($have.ContainsKey('pack') -and $have.ContainsKey('version')) { $what = $have['pack'] + ' ' + $have['version'] + ' installed here' }
        Say ('Mods folder : ' + (Join2 $save 'mods') + ' - ' + $what)
    }
}

function Assert-GameClosed([string]$game, [string]$zipPath) {
    $running = Get-RunningGame $game
    if ($running) { Stop-Here ('Rotwood is running (' + $running + '). Close the game and run this again. Nothing was changed.') }
    if (-not (Test-CanWrite $zipPath)) { Stop-Here ('data_scripts.zip cannot be written right now (the game or another program has it open, or this account may not change the game folder). Nothing was changed.') }
}

function Invoke-Check {
    $info = Get-PackInfo
    $packMods = Get-PackMods
    $hook = Get-HookLine
    $game = Resolve-GameDir
    $saves = Resolve-SaveDirs
    $text = Read-ZipEntry (Join2 $game 'data_scripts.zip') $MainLua
    if (-not $text) { Stop-Here 'scripts/main.lua was not found in data_scripts.zip.' }
    $state = Get-MainState $text
    Say ($info['pack'] + ' ' + $info['version'] + ' (' + $packMods.Count + ' mods in this download)')
    Show-Found $game $saves $state
    $running = Get-RunningGame $game
    if ($running) { Say ('Rotwood is running (' + $running + ').') } else { Say 'Rotwood is not running.' }
    Say ''
    Say 'Check only: nothing was changed.'
}

function Invoke-Install {
    $info = Get-PackInfo
    $packMods = Get-PackMods
    $hook = Get-HookLine
    Say ('Installing ' + $info['pack'] + ' ' + $info['version'] + ' (' + $packMods.Count + ' mods)')
    $game = Resolve-GameDir
    $zipPath = Join2 $game 'data_scripts.zip'
    $saves = Resolve-SaveDirs
    $text = Read-ZipEntry $zipPath $MainLua
    if (-not $text) { Stop-Here 'scripts/main.lua was not found in data_scripts.zip. Nothing was changed.' }
    $state = Get-MainState $text
    Show-Found $game $saves $state
    Say ''
    if ($saves.Count -eq 0) { Stop-Here 'no Rotwood save folder was found. Start Rotwood once, close it, and run this again. Nothing was changed.' }
    if ($state.OldPatch) { Stop-Here 'another mod loader is patched into this game file, and the two cannot be used together. In Steam: right-click Rotwood, Properties, Installed Files, "Verify integrity of game files". Then run this again. Nothing was changed.' }
    if ($state.Hook -gt 1) { Stop-Here 'the mod pack line is in the game file more than once. In Steam, use "Verify integrity of game files", then run this again. Nothing was changed.' }
    if (($state.Hook -eq 0) -and ($state.AnchorCount -ne 1)) { Stop-Here 'this version of the game is laid out differently from the one this pack was made for, so the installer will not touch it. Look for a newer version of the pack. Nothing was changed.' }
    Assert-GameClosed $game $zipPath

    $newText = ''
    $tmp = ''
    if ($state.Hook -eq 0) {
        Say 'Step 1 of 3: preparing the game file (a copy; the real one is not touched yet)'
        $newText = Add-Hook $text $hook $state.Anchor
        $check = Get-MainState $newText
        if (($check.Hook -ne 1) -or ((Remove-Hook $newText) -cne $text)) { Stop-Here 'the line could not be added cleanly. Nothing was changed.' }
        $tmp = New-PatchedZip $zipPath $newText
    } else {
        Say 'Step 1 of 3: the game file already has the mod pack line'
    }

    Say 'Step 2 of 3: backing up your saves and copying the mods'
    foreach ($save in $saves) { Install-Mods $save $packMods $info }

    if ($tmp) {
        Say 'Step 3 of 3: putting the game file in place'
        $backup = Switch-Zip $zipPath $tmp $newText
        Say ('  done. The file as it was: ' + $backup)
    } else {
        Say 'Step 3 of 3: nothing to do'
    }
    Say ''
    Say 'Installed. Start Rotwood.'
    Say 'To see that it worked: after starting the game, open client_log.txt in the folder above the mods folder'
    Say 'and look for a line starting with "[Native Loader]". It lists the mods that were loaded.'
    Say 'After a game update the mods go quiet (Steam puts the original game file back): run Install again.'
}

function Invoke-Uninstall {
    $packMods = Get-PackMods
    Say 'Uninstalling the mod pack'
    $game = Resolve-GameDir
    $zipPath = Join2 $game 'data_scripts.zip'
    $saves = Resolve-SaveDirs
    $text = Read-ZipEntry $zipPath $MainLua
    if (-not $text) { Stop-Here 'scripts/main.lua was not found in data_scripts.zip. Nothing was changed.' }
    $state = Get-MainState $text
    Show-Found $game $saves $state
    Say ''
    Assert-GameClosed $game $zipPath
    if ($state.Hook -gt 0) {
        Say 'Step 1 of 2: taking the line out of the game file'
        $newText = Remove-Hook $text
        $check = Get-MainState $newText
        if ($check.Hook -ne 0) { Stop-Here 'the line could not be taken out cleanly. Nothing was changed. In Steam, "Verify integrity of game files" restores the original file.' }
        $tmp = New-PatchedZip $zipPath $newText
        $backup = Switch-Zip $zipPath $tmp $newText
        Say ('  done. The file as it was: ' + $backup)
    } else {
        Say 'Step 1 of 2: the game file has no mod pack line'
    }
    Say 'Step 2 of 2: moving the mods out'
    foreach ($save in $saves) { Uninstall-Mods $save $packMods }
    Say ''
    Say 'Uninstalled. The game runs unmodified again.'
}

try {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $what = $Action.ToLowerInvariant()
    if ($what -eq 'check') { Invoke-Check }
    elseif ($what -eq 'install') { Invoke-Install }
    elseif ($what -eq 'uninstall') { Invoke-Uninstall }
    else { Stop-Here ('unknown action "' + $Action + '" (use check, install or uninstall)') }
    exit 0
} catch {
    $message = [string]$_.Exception.Message
    Write-Host ''
    Write-Host $message -ForegroundColor Yellow
    if (-not $message.StartsWith('STOPPED: ')) {
        Write-Host 'This is an error in the installer itself, not something you did. Details for a bug report:' -ForegroundColor Yellow
        Write-Host ([string]$_.InvocationInfo.PositionMessage)
    }
    if ($script:TmpZip -and (Test-Path -LiteralPath $script:TmpZip)) {
        try { Remove-Item -LiteralPath $script:TmpZip -Force } catch { }
    }
    exit 1
}
