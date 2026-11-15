# Gallery Video Setup Guide

## How It Works

Video titles are written into `gallery.html` as plain HTML by the build script,
`scripts/update-gallery.js`. The script looks each title up through YouTube's
public oEmbed endpoint, so **no API key is needed** and nothing secret is
shipped to the browser.

## Adding New Videos

1. Edit `youtube-videos.txt` and add your YouTube links (one per line).
2. Run the update script:

   ```bash
   node scripts/update-gallery.js
   ```

3. The script rewrites `gallery.html` with a card for each video, including its
   real YouTube title, and updates the video playlist on `services.html`.
   It also refreshes the "Recent Work" block from `featured-project.txt`.

If a title cannot be fetched (private or removed video, or you are offline), the
card falls back to "Project Video" instead of a stuck "Loading..." label. Run the
script again once you are online to fill in the real title.

## Checking Titles

```bash
node scripts/check-video.js
```

Prints the ID, title, and channel for every video listed in
`youtube-videos.txt`. No key required.

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

## Why there is no API key

The site is served as static files from a public repository (GitHub Pages), so
any key placed in HTML or JavaScript is public the moment it is deployed. Even a
"restricted" key can be copied and used from another site that matches the
referrer rules, and an unrestricted one can be used by anyone.

The YouTube Data API also charges quota per request: a key in the page meant one
API call per visitor per page load. Baking titles at build time removes both the
exposure and the quota cost.

## Troubleshooting

**A card says "Project Video" instead of a real title**
- Run `node scripts/update-gallery.js` while online and commit the result.
- `node scripts/check-video.js` will show which IDs YouTube cannot resolve.

**A video no longer plays**
- The video may be private or deleted. `check-video.js` reports the HTTP status.
