# Adds one YouTube video to the gcode.supply gallery, then waits until it is
# actually live. No terminal knowledge needed: double-click gallery-add.cmd.
#
#   gallery-add.cmd                  -> uses the link on your clipboard
#   gallery-add.cmd https://youtu.be/ID
#   gallery-add.cmd -DryRun          -> show what would happen, change nothing
#
# It only commits youtube-videos.txt; the GitHub Action builds the HTML.
[CmdletBinding()]
param(
    [Parameter(Position = 0)][string]$Url,
    [switch]$DryRun,
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repo   = $PSScriptRoot
$listFile = Join-Path $repo 'youtube-videos.txt'
$apiRepo  = 'kurtm83/Gcode-Supply'
$siteUrl  = 'https://gcode.supply/gallery.html'

function Say($text, $colour = 'Gray') { Write-Host $text -ForegroundColor $colour }
function Fail($text) { Say "  $text" 'Red'; exit 1 }

function Get-ClipboardText {
    try { return (Get-Clipboard -Raw) } catch { return '' }
}

function Get-VideoId([string]$text) {
    if (-not $text) { return $null }
    foreach ($p in @(
        'youtu\.be/([A-Za-z0-9_-]{6,})',
        'youtube\.com/watch\?(?:.*&)?v=([A-Za-z0-9_-]{6,})',
        'youtube\.com/embed/([A-Za-z0-9_-]{6,})',
        'youtube\.com/shorts/([A-Za-z0-9_-]{6,})'
    )) {
        $m = [regex]::Match($text, $p)
        if ($m.Success) { return $m.Groups[1].Value }
    }
    return $null
}

Say ''
Say '  gcode.supply - add a video to the gallery' 'Cyan'
Say '  -----------------------------------------' 'Cyan'
Say ''

Set-Location $repo

# ---- 1. figure out which video -------------------------------------------
if (-not $Url) {
    $clip = Get-ClipboardText
    $clipId = Get-VideoId $clip
    if ($clipId) {
        Say "  Found a link on the clipboard: $($clip.Trim())"
        $Url = $clip.Trim()
    } else {
        Say '  Paste the YouTube link and press Enter (blank to cancel).' 'Yellow'
        $Url = (Read-Host '  Link').Trim()
    }
}

$videoId = Get-VideoId $Url
if (-not $videoId) {
    Fail "That does not look like a YouTube link: '$Url'"
}

if (-not (Test-Path $listFile)) { Fail "Missing $listFile" }

$lines = [IO.File]::ReadAllText($listFile) -split "`r?`n"
if ($lines -match [regex]::Escape($videoId)) {
    Say "  $videoId is already in the gallery list - nothing to do." 'Green'
    if (-not $NoPause) { Say ''; Read-Host '  Press Enter to close' | Out-Null }
    exit 0
}

$canonical = "https://youtu.be/$videoId"
Say "  New video: $videoId"

# ---- 2. sanity check the repo -------------------------------------------
if (-not (Test-Path (Join-Path $repo '.git'))) { Fail "Not a git repo: $repo" }
& git fetch origin --quiet
if ($LASTEXITCODE -ne 0) { Fail 'Could not reach GitHub (git fetch failed). Check your connection.' }

$behind = [int](& git rev-list --count 'HEAD..origin/main')
if ($behind -gt 0) {
    Say "  Pulling $behind commit(s) from GitHub first..."
    & git pull --ff-only --quiet
    if ($LASTEXITCODE -ne 0) { Fail 'git pull failed - the repo has local changes. Open the folder and sort it out first.' }
}

# Untracked files (??) are ignored: they cannot end up in the commit anyway.
$dirty = @(& git status --porcelain | Where-Object { $_ -and $_ -notmatch '^\?\?' -and $_ -notmatch 'youtube-videos\.txt$' })
if ($dirty.Count -gt 0) {
    Say '  Other files in this folder have uncommitted changes:'
    $dirty | ForEach-Object { Say "    $_" 'Yellow' }
    Fail 'Refusing to commit on top of those. Commit or discard them, then run this again.'
}

if ($DryRun) {
    Say ''
    Say "  DRY RUN - would append: $canonical" 'Yellow'
    Say '  and commit/push youtube-videos.txt, then wait for the rebuild.' 'Yellow'
    if (-not $NoPause) { Say ''; Read-Host '  Press Enter to close' | Out-Null }
    exit 0
}

# ---- 3. append, commit, push --------------------------------------------
$text = [IO.File]::ReadAllText($listFile)
if ($text.Length -gt 0 -and -not $text.EndsWith("`n")) { $text += "`r`n" }
$text += "$canonical`r`n"
[IO.File]::WriteAllText($listFile, $text, (New-Object System.Text.UTF8Encoding($false)))
Say '  Added to youtube-videos.txt'

& git add -- youtube-videos.txt
& git commit --quiet -m "chore: add $videoId to the gallery"
if ($LASTEXITCODE -ne 0) { Fail 'git commit failed.' }
$sha = (& git rev-parse --short HEAD).Trim()

& git push --quiet origin main 2>$null
if ($LASTEXITCODE -ne 0) { Fail 'git push failed. The link is committed locally; push it from GitHub Desktop or ask OpenWork.' }
Say "  Pushed $sha" 'Green'

# ---- 4. wait for the GitHub Action --------------------------------------
Say ''
Say '  Waiting for GitHub to rebuild the gallery (usually 30-90 seconds)...'
$headers = @{ 'User-Agent' = 'gcode-gallery-add'; 'Accept' = 'application/vnd.github+json' }
$fullSha = (& git rev-parse HEAD).Trim()
$run = $null
$deadline = (Get-Date).AddMinutes(6)

while ((Get-Date) -lt $deadline) {
    try {
        $runs = Invoke-RestMethod -Uri "https://api.github.com/repos/$apiRepo/actions/runs?head_sha=$fullSha&per_page=10" -Headers $headers -TimeoutSec 20
        $run = $runs.workflow_runs | Where-Object { $_.name -eq 'Update gallery from YouTube' } | Select-Object -First 1
    } catch { $run = $null }

    if ($run) {
        if ($run.status -eq 'completed') { break }
        Write-Host '.' -NoNewline
    } else {
        Write-Host '.' -NoNewline
    }
    Start-Sleep -Seconds 6
}
Say ''

if (-not $run) {
    Say '  The GitHub run never appeared.' 'Yellow'
    Say '  The link IS committed and pushed. Check https://github.com/kurtm83/Gcode-Supply/actions' 'Yellow'
    if (-not $NoPause) { Say ''; Read-Host '  Press Enter to close' | Out-Null }
    exit 1
}

if ($run.conclusion -ne 'success') {
    Say "  The rebuild finished as '$($run.conclusion)'." 'Red'
    Say "  Open the log: $($run.html_url)" 'Red'
    if (-not $NoPause) { Say ''; Read-Host '  Press Enter to close' | Out-Null }
    exit 1
}
Say "  Rebuild succeeded: $($run.html_url)" 'Green'

# ---- 5. confirm it is really on the live site ---------------------------
Say ''
Say '  Checking the live site (this can take another minute)...'
$title = $null
$deadline = (Get-Date).AddMinutes(4)
while ((Get-Date) -lt $deadline) {
    try {
        $cb = [guid]::NewGuid().ToString('N')
        $page = (Invoke-WebRequest -UseBasicParsing -Uri "$siteUrl`?cb=$cb" -TimeoutSec 25).Content
        $i = $page.IndexOf($videoId)
        if ($i -ge 0) {
            $m = [regex]::Match($page.Substring($i, [Math]::Min(4000, $page.Length - $i)), 'class="video-title">([^<]+)<')
            if ($m.Success) { $title = $m.Groups[1].Value.Trim() } else { $title = '(title not found)' }
            break
        }
    } catch { }
    Write-Host '.' -NoNewline
    Start-Sleep -Seconds 10
}
Say ''

if ($title) {
    Say "  LIVE: $title" 'Green'
    Say "  https://gcode.supply/gallery.html" 'Green'
    Say '  (Hard-refresh with Ctrl+Shift+R if your browser still shows the old page.)'
} else {
    Say '  Committed and deployed, but the card is not visible yet.' 'Yellow'
    Say '  GitHub Pages can lag a few minutes; reload the gallery in a bit.' 'Yellow'
}

if (-not $NoPause) { Say ''; Read-Host '  Press Enter to close' | Out-Null }
