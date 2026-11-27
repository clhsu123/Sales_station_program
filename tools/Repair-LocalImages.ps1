[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$PrivateRoot,
    [Parameter(Mandatory)][string]$OldProgram,
    [switch]$Apply
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path -LiteralPath $PrivateRoot).Path
$gitRoot = git -C $root rev-parse --show-toplevel
if ($LASTEXITCODE -ne 0 -or [IO.Path]::GetFullPath($gitRoot) -ne $root) {
    throw 'PrivateRoot must be the root of the local-only Git repository.'
}
$remotes = git -C $root remote
if ($LASTEXITCODE -ne 0 -or $remotes) {
    throw 'PrivateRoot must have no Git remotes.'
}
$regionNames = @('andes-data-korea', 'andes-data-japan')
foreach ($region in $regionNames) {
    $workspace = Get-Item -LiteralPath (Join-Path $root $region)
    if (-not $workspace.PSIsContainer -or ($workspace.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        throw "Expected a normal private data folder for $region."
    }
}
$html = [IO.File]::ReadAllText((Resolve-Path -LiteralPath $OldProgram).Path)
$assetList = [regex]::Match($html, 'window\.ANDES_ASSETS\s*=\s*(\{[^\r\n]*\})\s*;')
if (-not $assetList.Success) { throw 'The original HTML asset registry was not found.' }
$legacy = $assetList.Groups[1].Value | ConvertFrom-Json
function Get-ImageId($node) {
    if ($node -is [string]) {
        if ($node -cmatch '^[au]:(.+)$') { $Matches[1] }
    } elseif ($node -is [array]) {
        foreach ($item in $node) { Get-ImageId $item }
    } elseif ($node -is [pscustomobject]) {
        foreach ($property in $node.PSObject.Properties) { Get-ImageId $property.Value }
    }
}
function Test-ImageData($value) {
    return ($value -is [string] -and $value -match '^data:image/[a-z0-9.+-]+;base64,[a-z0-9+/=]+$')
}
foreach ($region in $regionNames) {
    $workspace = Join-Path $root $region
    $deckImages = Join-Path $workspace 'decks\_images'
    $storyImages = Join-Path $workspace 'stories\assets'
    $references = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $available = [System.Collections.Generic.Dictionary[string,string]]::new([StringComparer]::Ordinal)
    $collisions = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($section in @('decks','kb','stories')) {
        $path = Join-Path $workspace $section
        if (-not (Test-Path -LiteralPath $path -PathType Container)) { continue }
        foreach ($file in Get-ChildItem -LiteralPath $path -Filter '*.json' -File) {
            if ($file.Name.StartsWith('_')) { continue }
            $record = [IO.File]::ReadAllText($file.FullName) | ConvertFrom-Json
            foreach ($id in Get-ImageId $record) { [void]$references.Add($id) }
        }
    }
    foreach ($id in @('andes-logo','andes-logo-rev','riscv-logo','riscv-logo-rev','corner-chip')) {
        [void]$references.Add($id)
    }
    foreach ($directory in @($deckImages,$storyImages)) {
        if (-not (Test-Path -LiteralPath $directory -PathType Container)) { continue }
        foreach ($file in Get-ChildItem -LiteralPath $directory -Filter '*.json' -File) {
            if ($file.Name.StartsWith('_')) { continue }
            $asset = [IO.File]::ReadAllText($file.FullName) | ConvertFrom-Json
            if (-not (Test-ImageData $asset.data)) { continue }
            $id = if ($asset.id) { [string]$asset.id } else { $file.BaseName }
            if ($available.ContainsKey($id)) {
                if ($available[$id] -cne $asset.data) { [void]$collisions.Add($id) }
            } else { $available[$id] = $asset.data }
        }
    }
    $added = 0
    $recoverable = 0
    $missing = [System.Collections.Generic.List[string]]::new()
    foreach ($id in ($references | Sort-Object)) {
        if ($available.ContainsKey($id)) { continue }
        $asset = $legacy.PSObject.Properties[$id]
        if ($id -notmatch '^[A-Za-z0-9_-][A-Za-z0-9_.-]*$' -or -not $asset -or -not (Test-ImageData $asset.Value)) {
            $missing.Add($id)
            continue
        }
        $target = Join-Path $deckImages "$id.json"
        if (Test-Path -LiteralPath $target) {
            $missing.Add($id)
            continue
        }
        $recoverable++
        if ($Apply) {
            New-Item -ItemType Directory -Path $deckImages -Force | Out-Null
            $directory = Get-Item -LiteralPath $deckImages
            $parent = Get-Item -LiteralPath (Split-Path -Parent $deckImages)
            if (($directory.Attributes -bor $parent.Attributes) -band [IO.FileAttributes]::ReparsePoint) {
                throw 'Refusing to write into a linked asset directory.'
            }
            $json = @{id=$id; name=$id; data=$asset.Value} | ConvertTo-Json -Compress
            $stream = [IO.File]::Open($target, [IO.FileMode]::CreateNew)
            try {
                $bytes = [Text.UTF8Encoding]::new($false).GetBytes($json)
                $stream.Write($bytes, 0, $bytes.Length)
            } finally { $stream.Dispose() }
            $added++
        }
    }
    [pscustomobject]@{
        Region = $region
        References = $references.Count
        RecoverableFromOldHtml = $recoverable
        Added = $added
        MissingOriginalOrBlocked = $missing.Count
        MissingIds = ($missing -join ', ')
        ConflictingIds = (($collisions | Sort-Object) -join ', ')
    }
}
