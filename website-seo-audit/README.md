# Website SEO audit: 88 to Lighthouse 100

My consulting business runs a hand-written static site (HTML, a little PHP) on a web server I host myself, plus four demo websites, one for each website package I sell. I audited it for search engines, fixed everything the audit found, and checked the results with outside tools rather than taking the audit's word for it.

## Starting point

- An SEO audit (run with an AI SEO plugin against the source and the live site) scored it **88/100**, with nothing critical.
- Real problems: images on the home page with empty alt text, one page description over the 160-character limit, a render-blocking script, thin search and share tags on 40 demo-site pages, two service pages with no structured data, demo sub-pages missing from the sitemap, and one shared social image for every page.
- Some findings were wrong. The audit counted `&amp;` as five characters, so seven titles looked too long when they weren't. It also said one page had no `<h1>`, but the heading is drawn by JavaScript (which Google runs). I checked every finding in the source and on the live site before changing anything.

## What I changed

| Area | Change |
|---|---|
| Demo sites (31 pages) | Descriptions 120-160 characters, each naming its package level so none are duplicates; Open Graph and Twitter tags; `WebPage` + `BreadcrumbList` JSON-LD; `noindex` on the demo cart, checkout and account pages (transactional pages stay out of search); a placeholder `<h1>` on the product page that the script replaces |
| Sitemap | The build script now lists every indexable demo sub-page and skips `noindex` ones: 14 to 38 URLs |
| Service pages | `Service` JSON-LD with an `OfferCatalog`, using only prices printed on the page (no invented facts, prices or ratings) |
| Speed | The page-effects script is loaded with `defer`, so it no longer blocks the first paint |
| Share images | A small Python (Pillow) script draws a 1200x630 card for each main page from that page's own heading, in the style of the original card. It runs locally, so there is no image-API cost |

## Fix the generator, not the output

The demo sites are generated, so hand-editing 31 HTML files would be undone by the next rebuild. Instead I wrote one Python script that applies every rule, and the generator runs it as its last step:

- **Idempotent:** a second run changes nothing (`--check` mode proves it, and exits non-zero if any page breaks a rule).
- **Self-checking:** it fails on descriptions outside 120-160 characters, titles over 60 (measured with entities decoded), anything other than one `<h1>`, and duplicate descriptions.
- **Facts only:** structured data is built from what is on the page, never from assumptions.

## The mistake

To stop a possible flicker from the deferred script, I added a one-line inline `<script>`. The site's Content-Security-Policy (`script-src 'self'`, no `unsafe-inline`) blocked it, so every page logged a console error for about a minute, and the line did nothing anyway because the external script already sets the same class. I removed it rather than loosening the CSP. Lesson: on a site with a strict CSP, check the headers before adding any inline script, and read the browser console after every deploy.

## How it was shipped

- Each commit holds only the files it changed (the repo is shared with other work, so `git commit -- <paths>`, never `git add -A`).
- Deploys go through a script that takes a dated backup of the live web root first, so any deploy can be rolled back by copying one folder.
- After each deploy I diffed the backup against the live root, to confirm that only my files changed.

## Results (checked with outside tools)

| Check | Result |
|---|---|
| Google PageSpeed Insights (Lighthouse, mobile, home page) | **SEO 100, Accessibility 100, Best Practices 100, Performance 97** |
| Schema.org validator on three changed pages | 0 errors, 0 warnings |
| Re-audit, same rubric | 96/100 (was 88). The remaining points are for checks it couldn't run itself, which the PageSpeed run covers |
| Live checks, run twice | Sitemap at 38 URLs, every share image returns 200, structured data and `defer` present, `noindex` where intended |

## Skills shown

Technical SEO (meta tags, canonical URLs, sitemaps, robots, structured data), web performance, Content-Security-Policy, Python build tooling, change control with backups and rollback, and checking results against outside tools.
