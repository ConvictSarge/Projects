# Per-business website concept images for cold outreach

A small Python service that looks at a local business's current website and renders a watermarked "here is what your new site could look like" image for a cold email. Each image is built for that business: its own logo and colours, services it actually offers, and a look picked so that a month of emails does not look like one template with the colours swapped.

Redacted: no hostnames, addresses, credentials or business names. The design and the lessons are real.

## Pipeline

```
lead row (name, website, phone, city, state)
   -> fetch the home page (through a VPN proxy, honest bot user agent, robots.txt respected)
   -> parked-domain / bot-wall / redirect checks
   -> headless Chromium render only when the static HTML has too little text
   -> extract: visible text, headings, nav, phone, address, logo candidates, CSS colours
   -> local LLM (Ollama, 7B) writes headline, intro and services from that text
   -> grounding check: anything not supported by words on the site is dropped
   -> brand palette from the logo / theme-color / CSS, contrast-checked
   -> Jinja2 page -> Playwright screenshots (desktop crop, phone, three section crops)
   -> composite showcase image with watermarks -> JPEG embedded in the email
```

The service sits behind an n8n workflow that posts the lead row and gets back the image path. The sender attaches the file at send time, so rebuilding an image in place updates every queued email without touching the queue.

## Things that made it honest

- **Parked domains.** A parked domain returned a tiny JavaScript redirect and the old version treated it as a real site with no text, so the LLM invented a business (a horse stable became a restaurant). Now: parked pages are detected (JS redirect to a lander, meta refresh, parking phrases, redirect to a parking network carrying the original domain), and a site counts as "read" only with at least 200 characters of visible text. Unread sites get neutral copy that describes what the new site would show instead of guessing.
- **Grounding.** Every LLM phrase must share enough of its 4+ letter words with the site text, or it is replaced. Services that are not named on the site are never shown.
- **Logos.** Only images from the business's own host or a site-builder CDN are accepted. A blocklist covers booking widgets, payment and security badges, review sites and social icons. Two misses taught two rules: a hosting platform's parent domain is not the business (it picked up the platform's logo), and brokerage branding can live in the image's folder path rather than its file name. Photo-like images are rejected by counting colours in a 64x64 sample.
- **Phone numbers.** The number from the lead listing beats one scraped from the page, because a hosted storefront showed the platform's toll-free line.
- **Bot walls and robots.txt are respected.** Blocked sites get the neutral version, never a workaround.

## Variety

The first version gave every business the same composition with a different palette. At about 1,200 emails a month that reads as a template. Each concept now gets a seeded combination, chosen per business type so it still fits (rooftops for contractors and realtors, mosaics for salons):

| Choice | Options |
|---|---|
| Hero layout | split, centred, card |
| Hero picture (generated SVG) | rooftops, building blocks, diagonal stripes, tile grid, triangle mosaic, landscape |
| Font pair | five pairs; open-licence fonts embedded as data URIs so the render never fetches anything |
| Hero edge | curve, angle, tilt, straight (CSS clip-path) |
| Corners | pill, soft, square |
| Hero tone | dark or light |
| Showcase | dark or light stage, phone on the left or right |

The seed comes from a hash of the lead id, so a rebuild is reproducible, and each choice uses its own random stream so the combinations spread out. Watermarks switch to a dark version on light backgrounds so they are never lost.

## Rendering details

- Fixed 1040 px desktop crop. Any heading or card the crop would cut is hidden for that one screenshot, then restored (a heading was being cut mid-word).
- Palette: brand hue darkened for backgrounds, accent lightened until it reaches 4.0:1 contrast, text colour on the accent picked by contrast.
- Everything is local: no external fonts, images or scripts in the rendered page.

## How it was changed

- Back up every file before editing; test on a separate copy of the builder that writes to its own output folder.
- Test on real leads, including the known-bad cases (parked domains, bot walls, hosted storefronts), and check every image by eye on contact sheets.
- Deploy by copying the tested files, restart the service, compare checksums, then rebuild the queued images in place and check them again.

## Stack

Python, BeautifulSoup, Jinja2, Playwright (Chromium), Pillow, Ollama (local 7B model), n8n, systemd.
