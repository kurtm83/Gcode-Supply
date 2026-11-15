const fs = require('fs');
const path = require('path');

// File paths
const videoLinksFile = path.join(__dirname, '..', 'youtube-videos.txt');
const featuredProjectFile = path.join(__dirname, '..', 'featured-project.txt');
const galleryFile = path.join(__dirname, '..', 'gallery.html');
const servicesFile = path.join(__dirname, '..', 'services.html');

function shuffleArray(array) {
    // Fisher-Yates shuffle algorithm
    const shuffled = [...array];
    for (let i = shuffled.length - 1; i > 0; i--) {
        const j = Math.floor(Math.random() * (i + 1));
        [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
    }
    return shuffled;
}

function extractVideoId(url) {
    // Handle different YouTube URL formats
    const patterns = [
        /youtu\.be\/([a-zA-Z0-9_-]+)/,           // youtu.be/VIDEO_ID
        /youtube\.com\/watch\?v=([a-zA-Z0-9_-]+)/, // youtube.com/watch?v=VIDEO_ID
        /youtube\.com\/embed\/([a-zA-Z0-9_-]+)/    // youtube.com/embed/VIDEO_ID
    ];
    
    for (const pattern of patterns) {
        const match = url.match(pattern);
        if (match) return match[1];
    }
    
    return null;
}

// Titles are read from YouTube's public oEmbed endpoint. No API key is needed,
// so nothing secret ends up in the published HTML or JavaScript.
async function fetchVideoTitle(videoId) {
    const url = `https://www.youtube.com/oembed?url=https://www.youtube.com/watch?v=${videoId}&format=json`;
    try {
        const response = await fetch(url, { signal: AbortSignal.timeout(10000) });
        if (!response.ok) throw new Error(`HTTP ${response.status}`);
        const data = await response.json();
        return (data.title || '').trim() || null;
    } catch (error) {
        console.warn(`⚠ Could not fetch title for ${videoId}: ${error.message}`);
        return null;
    }
}

function escapeHtml(value) {
    return String(value)
        .replace(/&/g, '&amp;')
        .replace(/</g, '&lt;')
        .replace(/>/g, '&gt;')
        .replace(/"/g, '&quot;');
}

function generateVideoCard(videoId, index, title) {
    const heading = escapeHtml(title || 'Project Video');
    const description = escapeHtml(title
        ? `Print time lapse - ${title}`
        : 'Watch this 3D printing project time lapse');

    return `                <!-- Video ${index + 1} -->
                <div class="video-card" data-video-id="${videoId}">
                    <div class="video-wrapper">
                        <iframe 
                            src="https://www.youtube.com/embed/${videoId}?rel=0&loop=1&playlist=${videoId}" 
                            title="${heading} (YouTube video)"
                            loading="lazy"
                            frameborder="0" 
                            allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" 
                            allowfullscreen>
                        </iframe>
                    </div>
                    <h4 class="video-title">${heading}</h4>
                    <p class="video-description">${description}</p>
                </div>`;
}

function parseFeaturedProject(filePath) {
    const content = fs.readFileSync(filePath, 'utf-8');
    const config = {};
    
    content.split('\n').forEach(line => {
        line = line.trim();
        if (line && !line.startsWith('#')) {
            const [key, ...valueParts] = line.split('=');
            if (key && valueParts.length > 0) {
                config[key.trim()] = valueParts.join('=').trim();
            }
        }
    });
    
    return config;
}

function generateFeaturedSection(config) {
    const images = [];
    for (let i = 1; i <= 3; i++) {
        const imgKey = `IMAGE_${i}`;
        const altKey = `IMAGE_${i}_ALT`;
        if (config[imgKey]) {
            images.push(`<img loading="lazy" decoding="async" src="images/${config[imgKey]}" alt="${config[altKey] || 'Project image'}">`);
        }
    }
    
    return `    <!-- Recent Work Section -->
    <section class="recent-work">
        <div class="container">
            <h2>Recent Work</h2>
            
            <!-- Featured Project -->
            <div class="featured-gallery-item">
                <div class="gallery-item-content">
                    <div class="gallery-item-media">
                        <div class="gallery-image-grid">
                            ${images.join('\n                            ')}
                        </div>
                        <!-- YouTube embed for time lapse -->
                        <div class="gallery-video" data-video-id="${config.VIDEO_ID}">
                            <iframe 
                                src="https://www.youtube.com/embed/${config.VIDEO_ID}?rel=0&loop=1&playlist=${config.VIDEO_ID}" 
                                title="${config.TITLE || 'Project video'} (YouTube video)"
                                loading="lazy"
                                frameborder="0" 
                                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture" 
                                allowfullscreen>
                            </iframe>
                        </div>
                    </div>
                    <div class="gallery-item-description">
                        <h3>${config.TITLE}</h3>
                        <p class="project-date">${config.DATE}</p>
                        <p>${config.DESCRIPTION}</p>
                        
                        <h4>Project Details</h4>
                        <ul class="project-specs">
                            <li><strong>Challenge:</strong> ${config.CHALLENGE}</li>
                            <li><strong>Solution:</strong> ${config.SOLUTION}</li>
                            <li><strong>Material:</strong> ${config.MATERIAL}</li>
                            <li><strong>Quantity:</strong> ${config.QUANTITY}</li>
                            <li><strong>Result:</strong> ${config.RESULT}</li>
                        </ul>
                        
                        <p class="project-highlight">${config.HIGHLIGHT}</p>
                    </div>
                </div>
            </div>
        </div>
    </section>`;
}

(async () => {
try {
    // Read video links
    const content = fs.readFileSync(videoLinksFile, 'utf-8');
    const lines = content.split('\n')
        .map(line => line.trim())
        .filter(line => line && !line.startsWith('#')); // Remove empty lines and comments
    
    const videoIds = lines.map(line => extractVideoId(line)).filter(id => id);
    
    if (videoIds.length === 0) {
        console.error('❌ No valid YouTube URLs found in youtube-videos.txt');
        process.exit(1);
    }
    
    console.log(`✓ Found ${videoIds.length} video(s)`);
    
    // Look up each video's public title (no API key needed)
    const titles = await Promise.all(videoIds.map(fetchVideoTitle));

    // Generate video cards HTML
    const videoCardsHtml = videoIds
        .map((id, index) => generateVideoCard(id, index, titles[index]))
        .join('\n\n');
    
    // Read gallery.html
    let galleryHtml = fs.readFileSync(galleryFile, 'utf-8');
    
    // Update featured section if featured-project.txt exists
    if (fs.existsSync(featuredProjectFile)) {
        const featuredConfig = parseFeaturedProject(featuredProjectFile);
        const featuredHtml = generateFeaturedSection(featuredConfig);
        
        // Find and replace the featured section
        const featuredPattern = /<!-- Recent Work Section -->[\s\S]*?<\/section>\s+<!-- Time Lapse Gallery -->/;
        
        if (galleryHtml.match(featuredPattern)) {
            galleryHtml = galleryHtml.replace(featuredPattern, featuredHtml + '\n\n    <!-- Time Lapse Gallery -->');
            console.log('✓ Featured project updated!');
        } else {
            console.log('⚠ Could not find featured section in gallery.html (skipping)');
        }
    }
    
    // Find the video-grid section and replace content using regex
    const gridPattern = /(<div class="video-grid">)[\s\S]*?(<\/div>\s+<\/div>\s+<\/section>\s+<!-- CTA -->)/;
    
    if (!galleryHtml.match(gridPattern)) {
        console.error('❌ Could not find video-grid section in gallery.html');
        process.exit(1);
    }
    
    // Replace the video grid content
    const newGalleryHtml = galleryHtml.replace(
        gridPattern, 
        `$1\n${videoCardsHtml}\n            </div>\n        </div>\n    </section>\n\n    <!-- CTA -->`
    );
    
    // Write updated gallery.html
    fs.writeFileSync(galleryFile, newGalleryHtml, 'utf-8');
    
    console.log('✓ Gallery updated successfully!');
    console.log(`✓ Added ${videoIds.length} video(s) to gallery.html`);
    
    // Update services.html with playlist of all videos (in order - shuffling happens client-side)
    const playlist = videoIds.join(',');
    const firstVideoId = videoIds[0];
    
    let servicesHtml = fs.readFileSync(servicesFile, 'utf-8');
    
    // Update the videoIds array in the script
    const videoIdsPattern = /const videoIds = \[['"][^'"]+['"](,\s*['"][^'"]+['"])*\];/;
    const videoIdsArray = videoIds.map(id => `'${id}'`).join(', ');
    const newVideoIdsLine = `const videoIds = [${videoIdsArray}];`;
    
    if (servicesHtml.match(videoIdsPattern)) {
        servicesHtml = servicesHtml.replace(videoIdsPattern, newVideoIdsLine);
    }
    
    // Find and replace the iframe id and src in services.html
    const iframePattern = /<iframe\s+id="services-video"\s+src="https:\/\/www\.youtube\.com\/embed\/[^"]+"/;
    const newIframeSrc = `<iframe id="services-video" src="https://www.youtube.com/embed/${firstVideoId}?autoplay=1&mute=1&loop=1&playlist=${playlist}&rel=0&modestbranding=1"`;
    
    if (servicesHtml.match(iframePattern)) {
        servicesHtml = servicesHtml.replace(iframePattern, newIframeSrc);
        fs.writeFileSync(servicesFile, servicesHtml, 'utf-8');
        console.log('✓ Services page playlist updated!');
        console.log('  (Client-side shuffling with 24-hour cache)');
    } else {
        console.log('⚠ Could not find video iframe in services.html (skipping)');
    }
    
    console.log('\nVideo IDs:');
    videoIds.forEach((id, index) => {
        console.log(`  ${index + 1}. ${id}`);
    });
    
} catch (error) {
    console.error('❌ Error:', error.message);
    process.exit(1);
}
})();
