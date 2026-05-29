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
├── fonts/                  # Web fonts (used by article.css)
├── favicon.ico
└── images/                 # Not in Git — deployed separately (see below)
```

## Images

Image files are too large for GitHub and are **not** versioned here (`images/` is in `.gitignore`). Deploy them separately to `images/` on the server (rsync, scp, or your existing process).

For local development, copy images from your backup or production into `images/`.

## Production deployment

1. Deploy the `ost_landing_page` repository to the web root.
2. Clone or pull this repository into `news_articles/`:

   ```bash
   cd /path/to/web/root
   git clone <ost_news-repo-url> news_articles
   # or, to update:
   git -C news_articles pull
   ```

3. Sync `images/` to `news_articles/images/` on the server.

The landing page loads `news_articles/articles.json` for the home-page news banner and links to `news_articles/index.html` for the full archive.

## Adding an article

1. Copy `article_template.html` to a new file (e.g. `my_event_2026.html`).
2. Add an entry to `articles.json` with `filename`, `image_path` (under `images/`), `title`, `subtitle`, and `publication_date` (`YYYY-MM-DD`).
3. Place images in `images/` and deploy them to the server.
4. Commit and deploy HTML/JSON/CSS as usual; deploy images separately.
