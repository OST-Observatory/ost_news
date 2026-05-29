# OST News Articles

News articles and archive for the [OST website](https://polaris.astro.physik.uni-potsdam.de).

This repository is deployed into the landing page’s `news_articles/` directory on the server (same URL paths as before).

## Repository layout

```
├── index.html              # Article archive
├── articles.json           # Metadata for archive and landing-page banner
├── *.html                  # Individual articles
├── article_template.html   # Template for new articles
├── css/                    # Article and archive styles
├── js/                     # Archive page script
├── fonts/                  # Web fonts (woff2): Open Sans/Lato (articles), Arimo (archive)
├── scripts/                # Local helper scripts (not run on server)
├── docs/                   # Examples and deployment notes
├── favicon.ico
└── images/                 # Not in Git — deployed separately (see below)
    └── thumbs/             # Archive/banner thumbnails (generated locally)
```

## Images

Image files are too large for GitHub and are **not** versioned here (`images/` is in `.gitignore`). Deploy them separately to `images/` on the server (rsync, scp, or your existing process).

For local development, copy images from your backup or production into `images/`.

### Thumbnails (archive & banner)

The landing-page banner and archive grid use `thumbnail_path` from `articles.json` (fallback: `image_path`). Generate thumbnails **locally**:

```bash
./scripts/generate-thumbnails.sh
```

Then deploy `images/thumbs/` together with other image assets.

**Security:** Run image tools only on your developer machine or in CI — **never** on the production web server. The script prefers `ffmpeg`; ImageMagick is optional and only used locally if installed.

### Image guidelines

| Use | Target size |
|-----|-------------|
| Header / hero | ≤ 400 KB |
| Inline photos | ≤ 500 KB each |
| Archive thumbnails | auto-generated (~800 px wide) |
| Animations | prefer MP4/WebM over large GIFs |

## Production deployment

1. Deploy the `ost_landing_page` repository to the web root.
2. Clone or pull this repository into `news_articles/`:

   ```bash
   cd /path/to/web/root
   git clone <ost_news-repo-url> news_articles
   # or, to update:
   git -C news_articles pull
   ```

3. Sync `images/` and `images/thumbs/` to `news_articles/images/` on the server.

The landing page loads `news_articles/articles.json` for the home-page news banner and links to `news_articles/index.html` for the full archive.

See [docs/deploy-cache.md](docs/deploy-cache.md) for recommended HTTP cache headers.

## Adding an article

1. Copy `article_template.html` to a new file (e.g. `my_event_2026.html`).
2. Add an entry to `articles.json` with:
   - `filename`, `image_path`, `thumbnail_path` (under `images/thumbs/`)
   - `title`, `subtitle`, `publication_date` (`YYYY-MM-DD`)
3. Run `./scripts/generate-thumbnails.sh` after adding the source image.
4. Place images in `images/` and deploy them to the server.
5. Commit and deploy HTML/JSON/CSS; deploy images separately.

See [docs/example_article.html](docs/example_article.html) for layout examples (not published to production).

Future improvements: [TODO.md](TODO.md).
