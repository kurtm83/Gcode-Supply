# Gallery Video Setup Guide

## Short version — you never need a terminal

1. Open <https://github.com/kurtm83/Gcode-Supply/blob/main/youtube-videos.txt>
2. Click the **pencil** icon (Edit this file).
3. Add your video link on its own line at the bottom, e.g. `https://youtu.be/HqKrmmI5z4Q`.
   On YouTube, the link is under **Share → Copy link**.
4. Click **Commit changes…**, then **Commit changes** (keep "Commit directly to the `main` branch").
5. Wait 1–2 minutes. The **Update gallery from YouTube** workflow regenerates
   `gallery.html` and `services.html` and pushes them back, then GitHub Pages redeploys.

That is the whole job. Nothing to install, no key, nothing to download.

## One click on this computer: `gallery-add.cmd`

Copy the video link on YouTube (**Share -> Copy link**), then double-click
`gallery-add.cmd` in this folder. It adds the link, commits it, pushes, waits
for the GitHub rebuild, and prints the video title once it is actually live.
Nothing to type; if the clipboard holds no link it asks you to paste one.

    gallery-add.cmd            uses the link on your clipboard
    gallery-add.cmd <link>     adds that link
    gallery-add.cmd -DryRun <link>   shows what it would do, changes nothing

It needs this folder on the machine and push access (the SSH key
`github-kurtm83`). If it reports other uncommitted files it stops without
pushing, so it cannot sweep unrelated work into its commit.

## Checking what is live without GitHub: `gallery-status.cmd`

Double-click `gallery-status.cmd` in this folder. It prints how many links are
listed, how many cards are built, how many the live site actually serves, which
videos are still waiting, and the last rebuild and deploy — then opens a small
status page (badges per video, links to each one). Read-only: it changes nothing
and pushes nothing.

    gallery-status.cmd            check, then open the status page
    gallery-status.cmd -NoOpen    print in the window only

It reads `youtube-videos.txt` from GitHub (and warns if your local copy differs),
`gallery.html` on `main`, <https://gcode.supply/gallery.html>, and the public
GitHub Actions API. The page it writes, `gallery-status.html`, is gitignored, so
it never shows up in a commit.

## How It Works

Video titles are written into `gallery.html` as plain HTML by the build script,
`scripts/update-gallery.js`. The script looks each title up through YouTube's
public oEmbed endpoint, so **no API key is needed** and nothing secret is
shipped to the browser.

The script runs on GitHub for you: `.github/workflows/update-gallery.yml` runs it

- whenever `youtube-videos.txt` or `featured-project.txt` changes on `main`,
- every Monday at 13:00 UTC (so titles you rename on YouTube get refreshed),
- or on demand from the repo's **Actions** tab → *Update gallery from YouTube* → **Run workflow**.

The workflow commits only `gallery.html` and `services.html`, and only when
their content actually changed.

## Adding New Videos (GitHub web UI)

1. Edit `youtube-videos.txt` on github.com (steps above). Comments start with `#`
   and blank lines are ignored.
2. Commit to `main`.
3. Watch it happen: **Actions** tab → the run named *Update gallery from YouTube*.
   A green check means it finished; a bot commit named
   `chore: refresh gallery from youtube-videos.txt` means titles were updated.
4. Reload <https://gcode.supply/gallery.html> (hard refresh: Ctrl+Shift+R).

If a title cannot be fetched (private or removed video, or YouTube was briefly
unreachable), the card falls back to "Project Video" instead of a stuck
"Loading..." label. Commit any tiny edit to `youtube-videos.txt` later, or run
the workflow manually, to fill in the real title.

## Checking Titles

Locally (optional, needs Node):

```bash
node scripts/check-video.js
```

Prints the ID, title, and channel for every video listed in
`youtube-videos.txt`. No key required.

## Running the update on your own machine (optional)

If you prefer to see the result before committing:

```bash
node scripts/update-gallery.js
git diff gallery.html services.html
```

Then commit and push the two files yourself. The workflow will find nothing to
change and stay quiet.

## Manual Method (No Script)

To add a video by hand, copy an existing card in `gallery.html` and change the
ID in both the `data-video-id` attribute and the iframe `src`:

```html
<div class="video-card" data-video-id="YOUR_VIDEO_ID">
    <div class="video-wrapper">
        <iframe
            src="https://www.youtube.com/embed/YOUR_VIDEO_ID?rel=0&loop=1&playlist=YOUR_VIDEO_ID"
            title="Your project title (YouTube video)"
            loading="lazy"
            frameborder="0"
            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
            allowfullscreen>
        </iframe>
    </div>
    <h4 class="video-title">Your project title</h4>
    <p class="video-description">One line describing the print</p>
</div>
```

- `https://youtu.be/HqKrmmI5z4Q` → ID is `HqKrmmI5z4Q`
- `https://www.youtube.com/watch?v=HqKrmmI5z4Q` → ID is `HqKrmmI5z4Q`

Remember to add the same link to `youtube-videos.txt` anyway, otherwise the next
workflow run will drop the hand-made card.

## Why there is no API key

The site is served as static files from a public repository (GitHub Pages), so
any key placed in HTML or JavaScript is public the moment it is deployed. Even a
"restricted" key can be copied and used from another site that matches the
referrer rules, and an unrestricted one can be used by anyone.

The YouTube Data API also charges quota per request: a key in the page meant one
API call per visitor per page load. Baking titles at build time removes both the
exposure and the quota cost.

The old key was deleted in the Google Cloud console on 2026-11-15.

## Troubleshooting

**A card says "Project Video" instead of a real title**
- Commit any edit to `youtube-videos.txt`, or run the workflow manually from the
  Actions tab, while online.
- Locally, `node scripts/check-video.js` shows which IDs YouTube cannot resolve.

**The card never appeared after a commit**
- Check the **Actions** tab: a red run means the script failed. Open the run log;
  the usual cause is a malformed link — only `youtu.be/ID`,
  `youtube.com/watch?v=ID` and `youtube.com/embed/ID` are recognised.

**A video no longer plays**
- The video may be private or deleted. `check-video.js` reports the HTTP status.
