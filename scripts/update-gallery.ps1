# PowerShell script to update gallery.html from youtube-videos.txt
# Usage: .\scripts\update-gallery.ps1

$videoLinksFile = Join-Path $PSScriptRoot "..\youtube-videos.txt"
$galleryFile = Join-Path $PSScriptRoot "..\gallery.html"
$servicesFile = Join-Path $PSScriptRoot "..\services.html"

function Extract-VideoId {
    param([string]$url)
    
    # Handle different YouTube URL formats
    if ($url -match 'youtu\.be/([a-zA-Z0-9_-]+)') {
        return $matches[1]
    }
    if ($url -match 'youtube\.com/watch\?v=([a-zA-Z0-9_-]+)') {
        return $matches[1]
    }
    if ($url -match 'youtube\.com/embed/([a-zA-Z0-9_-]+)') {
        return $matches[1]
    }
    
    return $null
}

function Get-VideoTitle {
    param([string]$videoId)

    # Public oEmbed lookup - no API key needed.
    try {
        $url = "https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=$videoId&format=json"
        $response = Invoke-RestMethod -Uri $url -TimeoutSec 10
        if ($response.title) { return $response.title.Trim() }
    } catch {
        Write-Host "  (could not fetch title for $videoId)" -ForegroundColor Yellow
    }
    return $null
}

function ConvertTo-HtmlText {
    param([string]$value)
    if (-not $value) { return '' }
    return ($value -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;')
}

function Generate-VideoCard {
    param(
        [string]$videoId,
        [int]$index,
        [string]$title
    )

    $heading = if ($title) { ConvertTo-HtmlText $title } else { 'Project Video' }
    $description = if ($title) { ConvertTo-HtmlText "Print time lapse - $title" } else { 'Watch this 3D printing project time lapse' }

    return @"
                <!-- Video $($index + 1) -->
                <div class="video-card" data-video-id="$videoId">
                    <div class="video-wrapper">
                        <iframe 
                            src="https://www.youtube.com/embed/$videoId?rel=0&loop=1&playlist=$videoId" 
                            title="$heading (YouTube video)"
                            loading="lazy"
                            frameborder="0" 
                            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" 
                            allowfullscreen>
                        </iframe>
                    </div>
                    <h4 class="video-title">$heading</h4>
                    <p class="video-description">$description</p>
                </div>
"@
}

try {
    # Read video links
    if (!(Test-Path $videoLinksFile)) {
        Write-Host "❌ youtube-videos.txt not found" -ForegroundColor Red
        exit 1
    }
    
    $lines = Get-Content $videoLinksFile | Where-Object { 
        $_.Trim() -and !$_.Trim().StartsWith('#') 
    }
    
    $videoIds = @()
    foreach ($line in $lines) {
        $id = Extract-VideoId $line
        if ($id) {
            $videoIds += $id
        }
    }
    
    if ($videoIds.Count -eq 0) {
        Write-Host "❌ No valid YouTube URLs found in youtube-videos.txt" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "✓ Found $($videoIds.Count) video(s)" -ForegroundColor Green
    
    # Generate video cards HTML
    $videoCardsHtml = @()
    for ($i = 0; $i -lt $videoIds.Count; $i++) {
        $videoCardsHtml += Generate-VideoCard $videoIds[$i] $i (Get-VideoTitle $videoIds[$i])
    }
    $videoCardsHtmlString = $videoCardsHtml -join "`n`n"
    
    # Read gallery.html
    if (!(Test-Path $galleryFile)) {
        Write-Host "❌ gallery.html not found" -ForegroundColor Red
        exit 1
    }
    
    $galleryHtml = Get-Content $galleryFile -Raw
    
    # Find and replace the video-grid section
    $pattern = '(?s)(<div class="video-grid">).*?(</div>\s+</div>\s+</section>\s+<!-- CTA -->)'
    
    if ($galleryHtml -match $pattern) {
        $closingTags = '</div>' + "`n        " + '</div>' + "`n    " + '</section>' + "`n`n    " + '<!-- CTA -->'
        $newContent = '$1' + "`n$videoCardsHtmlString`n            $closingTags"
        $galleryHtml = $galleryHtml -replace $pattern, $newContent
        
        # Write updated gallery.html
        $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
        $galleryHtml = $galleryHtml -replace "(?<!`r)`n", "`r`n"
        [IO.File]::WriteAllText($galleryFile, $galleryHtml, $utf8NoBom)
        
        Write-Host "✓ Gallery updated successfully!" -ForegroundColor Green
        Write-Host "✓ Added $($videoIds.Count) video(s) to gallery.html" -ForegroundColor Green
        
        # Update services.html with playlist of all videos
        $playlist = $videoIds -join ','
        $firstVideoId = $videoIds[0]
        
        if (Test-Path $servicesFile) {
            $servicesHtml = Get-Content $servicesFile -Raw
            
            # Find and replace the iframe src in services.html
            $iframePattern = '<iframe\s+src="https://www\.youtube\.com/embed/[\w-]+"'
            $newIframeSrc = '<iframe src="https://www.youtube.com/embed/' + $firstVideoId + '?autoplay=1' + '&' + 'mute=1' + '&' + 'loop=1' + '&' + 'playlist=' + $playlist + '&' + 'rel=0' + '&' + 'modestbranding=1"'
            
            if ($servicesHtml -match $iframePattern) {
                $servicesHtml = $servicesHtml -replace $iframePattern, $newIframeSrc
                $servicesHtml = $servicesHtml -replace "(?<!`r)`n", "`r`n"
                [IO.File]::WriteAllText($servicesFile, $servicesHtml, $utf8NoBom)
                Write-Host "✓ Services page playlist updated!" -ForegroundColor Green
            } else {
                Write-Host "⚠ Could not find video iframe in services.html (skipping)" -ForegroundColor Yellow
            }
        }
        
        Write-Host "`nVideo IDs:" -ForegroundColor Cyan
        for ($i = 0; $i -lt $videoIds.Count; $i++) {
            Write-Host "  $($i + 1). $($videoIds[$i])" -ForegroundColor White
        }
    } else {
        Write-Host "❌ Could not find video-grid section in gallery.html" -ForegroundColor Red
        exit 1
    }
    
} catch {
    Write-Host "❌ Error: $_" -ForegroundColor Red
    exit 1
}
