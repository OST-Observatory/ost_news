# HTTP cache headers (examples)

These snippets are **examples only** — configure them on the web server. Do not commit production `.htaccess` files to the landing-page repository.

## Apache

```apache
# Long cache for static assets
<IfModule mod_expires.c>
  ExpiresActive On
  ExpiresByType text/css "access plus 1 year"
  ExpiresByType application/javascript "access plus 1 year"
  ExpiresByType font/woff2 "access plus 1 year"
  ExpiresByType image/jpeg "access plus 1 year"
  ExpiresByType image/png "access plus 1 year"
  ExpiresByType image/webp "access plus 1 year"
  ExpiresByType video/mp4 "access plus 1 year"
</IfModule>

# Short cache for article metadata (banner + archive)
<Files "articles.json">
  Header set Cache-Control "public, max-age=300, must-revalidate"
</Files>
```

## nginx

```nginx
location ~* ^/news_articles/(css|js|fonts)/ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}

location ~* ^/news_articles/images/ {
    expires 1y;
    add_header Cache-Control "public";
}

location = /news_articles/articles.json {
    expires 5m;
    add_header Cache-Control "public, must-revalidate";
}
```

## Notes

- Use versioned filenames or cache-busting when replacing images in place.
- `articles.json` should stay fresh enough for new articles to appear on the landing-page banner within minutes.
- Enable gzip/brotli compression for CSS, JS, JSON, and SVG at the server level.
