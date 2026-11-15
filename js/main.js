// GCode Supply - Main JavaScript

// Mobile Navigation Toggle
document.addEventListener('DOMContentLoaded', function() {
    const navToggle = document.querySelector('.nav-toggle');
    const navMenu = document.querySelector('.nav-menu');
    
    if (navToggle) {
        navToggle.addEventListener('click', function() {
            navMenu.classList.toggle('active');
            navToggle.classList.toggle('active');
        });
    }
    
    // Close mobile menu when clicking outside
    document.addEventListener('click', function(event) {
        if (!event.target.closest('.navbar')) {
            navMenu?.classList.remove('active');
            navToggle?.classList.remove('active');
        }
    });
    
    // Close mobile menu when clicking a link
    const navLinks = document.querySelectorAll('.nav-menu a');
    navLinks.forEach(link => {
        link.addEventListener('click', function() {
            navMenu?.classList.remove('active');
            navToggle?.classList.remove('active');
        });
    });
});

// Smooth scroll for anchor links
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
    anchor.addEventListener('click', function (e) {
        const href = this.getAttribute('href');
        if (href !== '#' && href.length > 1) {
            e.preventDefault();
            const target = document.querySelector(href);
            if (target) {
                target.scrollIntoView({
                    behavior: 'smooth',
                    block: 'start'
                });
            }
        }
    });
});

// Form submission handling (optional - for additional client-side validation)
const contactForm = document.querySelector('.contact-form');
if (contactForm) {
    contactForm.addEventListener('submit', function(e) {
        // Formspree will handle the actual submission
        // This is just for any additional client-side logic you might want
    });
}

// Scroll reveal fallback. Browsers with scroll-driven animations use the CSS reveal in css/style.css.
if (!CSS.supports('animation-timeline', 'view()')) {
    const observerOptions = {
        threshold: 0.1,
        rootMargin: '0px 0px -50px 0px'
    };

    const observer = new IntersectionObserver(function(entries) {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                entry.target.classList.add('fade-in');
            }
        });
    }, observerOptions);

    document.querySelectorAll('.service-card, .video-card, .faq-item, .portfolio-item').forEach(el => {
        observer.observe(el);
    });

    const style = document.createElement('style');
    style.textContent = `
        .service-card, .video-card, .faq-item, .portfolio-item {
            opacity: 0;
            transform: translateY(20px);
            transition: opacity 0.6s ease, transform 0.6s ease;
        }

        .fade-in {
            opacity: 1 !important;
            transform: translateY(0) !important;
        }
    `;
    document.head.appendChild(style);
}

// YouTube gallery titles are baked into gallery.html at build time by
// scripts/update-gallery.js (public oEmbed lookup, no API key). Nothing secret
// is shipped to the browser. If a card still shows the placeholder text, swap in
// neutral wording so visitors never see "Loading...".
document.querySelectorAll('[data-video-id]').forEach(function(card) {
    const titleEl = card.querySelector('.video-title');
    const descEl = card.querySelector('.video-description');
    if (titleEl && titleEl.textContent.trim() === 'Loading...') {
        titleEl.textContent = 'Project Video';
    }
    if (descEl && descEl.textContent.trim() === 'Loading video details...') {
        descEl.textContent = 'Watch this 3D printing project time lapse';
    }
});
