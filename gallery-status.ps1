# Shows the state of the gcode.supply gallery without opening github.com.
# Double-click gallery-status.cmd. Read-only: it changes nothing and pushes nothing.
#
#   gallery-status.cmd            -> check and open a status page in the browser
#   gallery-status.cmd -NoOpen    -> print to the window only
#
# Sources: youtube-videos.txt in this folder, gallery.html on main, the live
# https://gcode.supply/gallery.html, and the public GitHub Actions API.
[CmdletBinding()]
param(
    [switch]$NoOpen,
    [switch]$NoPause
)

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$repo    = $PSScriptRoot
$listFile = Join-Path $repo 'youtube-videos.txt'
$apiRepo = 'kurtm83/Gcode-Supply'
$rawBase = 'https://raw.githubusercontent.com/kurtm83/Gcode-Supply/main'
$siteUrl = 'https://gcode.supply/gallery.html'
$outFile = Join-Path $repo 'gallery-status.html'

$headers = @{ 'User-Agent' = 'gcode-gallery-status'; 'Accept' = 'application/vnd.github+json' }
$notes = New-Object System.Collections.ArrayList

function Say($text, $colour = 'Gray') { Write-Host $text -ForegroundColor $colour }
function Add-Note($text) { [void]$notes.Add($text) }

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

function Get-LinkIds([string]$text) {
    $ids = New-Object System.Collections.ArrayList
    foreach ($line in ($text -split "`r?`n")) {
        $t = $line.Trim()
        if (-not $t -or $t.StartsWith('#')) { continue }
        $id = Get-VideoId $t
        if ($id -and -not $ids.Contains($id)) { [void]$ids.Add($id) }
    }
    return ,$ids
}

# Cards look like: <div class="video-card" data-video-id="ID"> ... <h4 class="video-title">TITLE</h4>
function Get-Cards([string]$html) {
    $cards = New-Object System.Collections.ArrayList
    if (-not $html) { return ,$cards }
    $parts = $html -split '<div class="video-card" data-video-id="'
    for ($i = 1; $i -lt $parts.Count; $i++) {
        $chunk = $parts[$i]
        $idMatch = [regex]::Match($chunk, '^([A-Za-z0-9_-]+)"')
        if (-not $idMatch.Success) { continue }
        $titleMatch = [regex]::Match($chunk, 'class="video-title">([^<]*)<')
        $title = ''
        if ($titleMatch.Success) { $title = [System.Net.WebUtility]::HtmlDecode($titleMatch.Groups[1].Value.Trim()) }
        $id = $idMatch.Groups[1].Value
        $existing = $cards | Where-Object { $_.Id -eq $id } | Select-Object -First 1
        if ($existing) {
            if (-not $existing.Title -and $title) { $existing.Title = $title }
            continue
        }
        [void]$cards.Add([pscustomobject]@{ Id = $id; Title = $title })
    }
    return ,$cards
}

function Get-FileText([string]$url) {
    $cb = [guid]::NewGuid().ToString('N')
    return (Invoke-WebRequest -UseBasicParsing -Uri "$url`?cb=$cb" -TimeoutSec 30).Content
}

Say ''
Say '  gcode.supply - gallery status' 'Cyan'
Say '  -----------------------------' 'Cyan'
Say ''

# ---- 1. the list ---------------------------------------------------------
$localIds = New-Object System.Collections.ArrayList
if (Test-Path $listFile) { $localIds = Get-LinkIds ([IO.File]::ReadAllText($listFile)) }
else { Add-Note 'youtube-videos.txt is missing from this folder - open the GCODE.SUPPLY clone.' }

$listedIds = $localIds
$listedFromRemote = $false
try {
    $remoteIds = Get-LinkIds (Get-FileText "$rawBase/youtube-videos.txt")
    $listedIds = $remoteIds
    $listedFromRemote = $true
    if ($localIds.Count -gt 0 -and (($localIds -join ',') -ne ($remoteIds -join ','))) {
        Add-Note 'youtube-videos.txt in this folder differs from the one on GitHub - a link may not be pushed yet.'
    }
} catch {
    Add-Note "Could not read youtube-videos.txt from GitHub: $($_.Exception.Message)"
}

# ---- 2. what is committed ----------------------------------------------
$committed = New-Object System.Collections.ArrayList
try { $committed = Get-Cards (Get-FileText "$rawBase/gallery.html") }
catch { Add-Note "Could not read gallery.html from GitHub: $($_.Exception.Message)" }

# ---- 3. what the live site actually serves -----------------------------
$live = New-Object System.Collections.ArrayList
$liveOk = $false
try {
    $live = Get-Cards (Get-FileText $siteUrl)
    $liveOk = $true
} catch {
    Add-Note "Could not load https://gcode.supply/gallery.html: $($_.Exception.Message)"
}

$liveIds = @($live | ForEach-Object { $_.Id })
$committedIds = @($committed | ForEach-Object { $_.Id })
$pending = @($listedIds | Where-Object { $liveIds -notcontains $_ })
$missingBuild = @($listedIds | Where-Object { $committedIds -notcontains $_ })

if ($pending.Count -eq 1) { Add-Note "1 video is in the list but not on the live page: $($pending[0])" }
elseif ($pending.Count -gt 1) { Add-Note "$($pending.Count) videos are in the list but not on the live page: $($pending -join ', ')" }
if ($missingBuild.Count -gt 0) {
    Add-Note "$($missingBuild.Count) listed video(s) are missing from gallery.html on GitHub - the rebuild may have failed: $($missingBuild -join ', ')"
}

# ---- 4. the GitHub runs -------------------------------------------------
$buildRun = $null
$deployRun = $null
try {
    $runs = Invoke-RestMethod -Uri "https://api.github.com/repos/$apiRepo/actions/runs?per_page=20" -Headers $headers -TimeoutSec 30
    $buildRun  = $runs.workflow_runs | Where-Object { $_.name -eq 'Update gallery from YouTube' } | Select-Object -First 1
    $deployRun = $runs.workflow_runs | Where-Object { $_.name -eq 'pages build and deployment' } | Select-Object -First 1
} catch {
    Add-Note "Could not read the GitHub run history: $($_.Exception.Message)"
}

if ($buildRun -and $buildRun.conclusion -and $buildRun.conclusion -ne 'success') {
    Add-Note "The last gallery rebuild finished as '$($buildRun.conclusion)'. Open the Actions tab or ask OpenWork to look."
}
if (-not $buildRun) { Add-Note 'No gallery rebuild has run yet - the workflow may not be on GitHub.' }

function Format-When($value) {
    if (-not $value) { return '-' }
    try {
        $d = [datetime]::Parse($value).ToLocalTime()
        $mins = [int]((Get-Date) - $d).TotalMinutes
        if ($mins -lt 2) { return 'just now' }
        if ($mins -lt 60) { return "$mins min ago" }
        if ($mins -lt 60 * 36) { return "$([int]($mins / 60)) h ago" }
        return $d.ToString('yyyy-MM-dd HH:mm')
    } catch { return $value }
}

function Get-Badge($state) {
    switch ($state) {
        'live'      { return @{ Text = 'LIVE'; Class = 'ok' } }
        'committed' { return @{ Text = 'BUILT, NOT LIVE'; Class = 'warn' } }
        'listed'    { return @{ Text = 'LISTED ONLY'; Class = 'bad' } }
        default     { return @{ Text = 'UNKNOWN'; Class = 'bad' } }
    }
}

# ---- 5. console summary -------------------------------------------------
Say "  Listed in youtube-videos.txt : $($listedIds.Count)"
Say "  Cards in gallery.html        : $($committedIds.Count)"
if ($liveOk) { Say "  Cards on the live site       : $($liveIds.Count)" } else { Say '  Cards on the live site       : (site unreachable)' 'Yellow' }
Say ''
if ($buildRun) {
    $colour = if ($buildRun.conclusion -eq 'success') { 'Green' } elseif ($buildRun.conclusion) { 'Red' } else { 'Yellow' }
    Say "  Last rebuild : $($buildRun.status) / $($buildRun.conclusion)  $(Format-When $buildRun.updated_at)  $($buildRun.event)" $colour
}
if ($deployRun) {
    $colour = if ($deployRun.conclusion -eq 'success') { 'Green' } elseif ($deployRun.conclusion) { 'Red' } else { 'Yellow' }
    Say "  Last deploy  : $($deployRun.status) / $($deployRun.conclusion)  $(Format-When $deployRun.updated_at)" $colour
}
Say ''

foreach ($card in $committed) {
    $state = if ($liveIds -contains $card.Id) { 'live' } else { 'committed' }
    $badge = Get-Badge $state
    $colour = if ($state -eq 'live') { 'Green' } else { 'Yellow' }
    $label = if ($card.Title) { $card.Title } else { $card.Id }
    Say ("  [{0,-16}] {1}" -f $badge.Text, $label) $colour
}
foreach ($id in $pending) {
    if ($committedIds -contains $id) { continue }
    $badge = Get-Badge 'listed'
    Say ("  [{0,-16}] {1}" -f $badge.Text, $id) 'Red'
}

Say ''
if ($notes.Count -gt 0) {
    Say '  Needs attention:' 'Yellow'
    $notes | ForEach-Object { Say "   - $_" 'Yellow' }
    Say ''
} else {
    Say '  Everything listed is built and live.' 'Green'
    Say ''
}

# ---- 6. the status page -------------------------------------------------
$rows = New-Object System.Collections.ArrayList
foreach ($card in $committed) {
    $state = if ($liveIds -contains $card.Id) { 'live' } else { 'committed' }
    [void]$rows.Add([pscustomobject]@{ Id = $card.Id; Title = $card.Title; State = $state })
}
foreach ($id in $pending) {
    if ($committedIds -contains $id) { continue }
    [void]$rows.Add([pscustomobject]@{ Id = $id; Title = ''; State = 'listed' })
}

$rowHtml = New-Object System.Text.StringBuilder
foreach ($row in $rows) {
    $badge = Get-Badge $row.State
    $title = if ($row.Title) { [System.Net.WebUtility]::HtmlEncode($row.Title) } else { '<span class="muted">(title not built yet)</span>' }
    [void]$rowHtml.AppendLine("      <tr><td><span class=""badge $($badge.Class)"">$($badge.Text)</span></td><td class=""title"">$title</td><td class=""id""><a href=""https://youtu.be/$($row.Id)"" target=""_blank"" rel=""noopener"">$($row.Id)</a></td></tr>")
}

$noteHtml = New-Object System.Text.StringBuilder
if ($notes.Count -eq 0) {
    [void]$noteHtml.AppendLine('      <p class="allgood">Everything listed is built and live.</p>')
} else {
    [void]$noteHtml.AppendLine('      <ul class="notes">')
    foreach ($n in $notes) { [void]$noteHtml.AppendLine("        <li>$([System.Net.WebUtility]::HtmlEncode($n))</li>") }
    [void]$noteHtml.AppendLine('      </ul>')
}

function Format-Run($run, $label) {
    if (-not $run) { return "<div class=""run""><span class=""muted"">$label</span> <span class=""muted"">no run found</span></div>" }
    $state = if ($run.conclusion -eq 'success') { 'ok' } elseif ($run.conclusion) { 'bad' } else { 'warn' }
    $word = if ($run.conclusion) { $run.conclusion } else { $run.status }
    $sha = ''
    if ($run.head_sha) { $sha = [string]$run.head_sha; if ($sha.Length -gt 7) { $sha = $sha.Substring(0, 7) } }
    return "<div class=""run""><span class=""muted"">$label</span> <span class=""badge $state"">$word</span> <span class=""muted"">$(Format-When $run.updated_at) &middot; $sha &middot; $($run.event)</span></div>"
}

$checkedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
$liveCount = if ($liveOk) { $liveIds.Count } else { '?' }
$tiles = @"
      <div class="tiles">
        <div class="tile"><div class="num">$($listedIds.Count)</div><div class="lbl">links in the list</div></div>
        <div class="tile"><div class="num">$($committedIds.Count)</div><div class="lbl">cards built on GitHub</div></div>
        <div class="tile"><div class="num">$liveCount</div><div class="lbl">cards on the live site</div></div>
        <div class="tile"><div class="num">$($pending.Count)</div><div class="lbl">waiting to go live</div></div>
      </div>
"@

$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>gcode.supply gallery status</title>
<style>
  :root { color-scheme: dark; }
  * { box-sizing: border-box; }
  body { margin: 0; padding: 32px 20px 60px; background: #0d1117; color: #e6edf3;
         font: 15px/1.5 "Segoe UI", system-ui, sans-serif; }
  .wrap { max-width: 860px; margin: 0 auto; }
  h1 { font-size: 20px; font-weight: 600; margin: 0 0 4px; }
  .sub { color: #8b949e; font-size: 13px; margin-bottom: 24px; }
  .sub a { color: #58a6ff; }
  .tiles { display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 12px; margin-bottom: 22px; }
  .tile { background: #161b22; border: 1px solid #30363d; border-radius: 10px; padding: 14px 16px; }
  .tile .num { font-size: 26px; font-weight: 600; line-height: 1.1; }
  .tile .lbl { color: #8b949e; font-size: 12px; margin-top: 4px; }
  .panel { background: #161b22; border: 1px solid #30363d; border-radius: 10px; padding: 16px 18px; margin-bottom: 18px; }
  h2 { font-size: 13px; text-transform: uppercase; letter-spacing: .08em; color: #8b949e;
       font-weight: 600; margin: 0 0 12px; }
  .run { font-size: 13px; padding: 4px 0; }
  .muted { color: #8b949e; }
  table { width: 100%; border-collapse: collapse; font-size: 14px; }
  th { text-align: left; font-size: 11px; text-transform: uppercase; letter-spacing: .08em;
       color: #8b949e; font-weight: 600; padding: 0 10px 8px 0; }
  td { padding: 9px 10px 9px 0; border-top: 1px solid #21262d; vertical-align: middle; }
  td.title { font-weight: 500; }
  td.id a { color: #58a6ff; text-decoration: none; font-family: ui-monospace, Consolas, monospace; font-size: 12px; }
  td.id a:hover { text-decoration: underline; }
  .badge { display: inline-block; font-size: 10px; font-weight: 700; letter-spacing: .06em;
           padding: 3px 7px; border-radius: 20px; white-space: nowrap; }
  .badge.ok { background: #12261e; color: #3fb950; border: 1px solid #238636; }
  .badge.warn { background: #2b2411; color: #d29922; border: 1px solid #9e6a03; }
  .badge.bad { background: #2d1418; color: #f85149; border: 1px solid #da3633; }
  .notes { margin: 0; padding-left: 20px; color: #d29922; font-size: 14px; }
  .notes li { margin: 4px 0; }
  .allgood { margin: 0; color: #3fb950; }
  .foot { color: #6e7681; font-size: 12px; margin-top: 26px; }
</style>
</head>
<body>
<div class="wrap">
  <h1>gcode.supply gallery status</h1>
  <div class="sub">Checked $checkedAt &middot; <a href="https://gcode.supply/gallery.html" target="_blank" rel="noopener">open the gallery</a></div>

$tiles

  <div class="panel">
    <h2>Latest runs</h2>
$(Format-Run $buildRun 'Gallery rebuild:')
$(Format-Run $deployRun 'Site deploy:')
  </div>

  <div class="panel">
    <h2>Needs attention</h2>
$noteHtml  </div>

  <div class="panel">
    <h2>Videos</h2>
    <table>
      <tr><th>State</th><th>Title</th><th>Video</th></tr>
$rowHtml    </table>
  </div>

  <div class="foot">Read-only snapshot. Double-click gallery-status.cmd again to refresh;
  gallery-add.cmd adds a video. Titles come from the built page, so a brand-new link shows its
  video ID until the rebuild finishes.</div>
</div>
</body>
</html>
"@

try {
    [IO.File]::WriteAllText($outFile, $html, (New-Object System.Text.UTF8Encoding($false)))
    Say "  Status page: $outFile"
    if (-not $NoOpen) { Start-Process $outFile | Out-Null }
} catch {
    Say "  Could not write the status page: $($_.Exception.Message)" 'Yellow'
}

if (-not $NoPause) { Say ''; Read-Host '  Press Enter to close' | Out-Null }
