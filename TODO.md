# TODO — ost_news roadmap

## Eleventy migration (P3)

Goal: move from hand-written HTML to a static site generator while keeping the same deploy target (`news_articles/` on the server).

### Target structure

```
ost_news/
├── _data/
│   └── articles.json          # or generated from front matter
├── _includes/
│   ├── base.njk
│   ├── article.njk
│   └── archive.njk
├── src/
│   └── articles/
│       └── *.md               # or *.html with front matter
├── css/                       # unchanged or moved to src/
├── .eleventy.js
└── _site/                     # build output → deploy as news_articles/
```

### Migration steps

1. **Scaffold 11ty**
   - Add `package.json` with `@11ty/eleventy`.
   - Configure output directory to match current URL layout.
   - Add npm scripts: `build`, `serve` (local preview).

2. **Shared layouts**
   - Extract article chrome (head, CSS links, favicon) into `base.njk`.
   - Port `article.css` / `article_archive.css` without changes initially.

3. **Archive page**
   - Generate `index.html` from `archive.njk` + `articles.json`.
   - Replace client-side fetch with server-side collection (optional: keep JS for progressive enhancement).

4. **Pilot article**
   - Migrate one article (e.g. `lnda_2025`) to Markdown/HTML + front matter.
   - Verify output matches current HTML (fonts, lazy loading, figure classes).

5. **Remaining articles**
   - Convert remaining articles one by one.
   - Retire hand-maintained duplicates only after visual parity check.

6. **Landing-page banner**
   - Option A: keep fetching `articles.json` (simplest).
   - Option B: generate a trimmed `banner.json` at build time.

7. **Image pipeline in build**
   - Integrate `@11ty/eleventy-img` or a post-build step using `sharp`.
   - Auto-generate `images/thumbs/` and WebP variants.
   - Run in GitHub Actions (not on production server).

8. **CI checks**
   - JSON Schema validation for `articles.json`.
   - Broken link check for `image_path` / `thumbnail_path`.
   - Max file size warning for assets committed to the repo.

### Non-goals (for now)

- User uploads or server-side image processing.
- CMS / admin UI.
- Changing public URL paths.

### References

- [Eleventy docs](https://www.11ty.dev/docs/)
- Current template: [article_template.html](../article_template.html)
- Layout examples: [docs/example_article.html](example_article.html)
