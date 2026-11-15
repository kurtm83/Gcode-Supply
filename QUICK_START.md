# Quick Start: Adding YouTube Videos to Gallery

## Simple 3-Step Process

### Step 1: Nothing to set up

No YouTube API key is needed. Video titles are fetched from YouTube's public oEmbed endpoint by the update script and written into `gallery.html` as plain text.

### Step 2: Add Your Videos

Edit `youtube-videos.txt` and add your YouTube links (one per line):

```
https://youtu.be/HqKrmmI5z4Q
https://youtu.be/KS9b1L6CTFg
https://youtu.be/4UT1HEY-qXY
```

### Step 3: Update Gallery

**Option A - PowerShell (Windows, no installation needed):**
```powershell
.\scripts\update-gallery.ps1
```

**Option B - Node.js (if you have Node installed):**
```bash
node scripts/update-gallery.js
```

**Option C - Manual:**
See [GALLERY_SETUP.md](GALLERY_SETUP.md) for manual instructions

## That's It!

- Video titles and descriptions will automatically load from YouTube
- The gallery page displays all your videos
- The services page cycles through all videos automatically
- Just add new links to `youtube-videos.txt` and run the script again

## Need Help?

See [GALLERY_SETUP.md](GALLERY_SETUP.md) for detailed instructions and troubleshooting.
