document.addEventListener('DOMContentLoaded', function () {
  loadArticles();
});

async function loadArticles() {
  const articleGrid = document.getElementById('articleGrid');
  if (!articleGrid) {
    return;
  }

  try {
    const response = await fetch('articles.json');
    if (!response.ok) {
      throw new Error(`HTTP ${response.status}`);
    }
    const articles = await response.json();
    renderArticles(articles, articleGrid);
  } catch (error) {
    console.error('Error fetching articles:', error);
    showError(articleGrid);
  }
}

function showError(container) {
  container.replaceChildren();
  const message = document.createElement('p');
  message.className = 'archive-error';
  message.textContent = 'Articles could not be loaded.';
  container.appendChild(message);
}

function thumbnailPath(article) {
  return article.thumbnail_path || article.image_path;
}

function renderArticles(articles, articleGrid) {
  articleGrid.replaceChildren();

  articles.sort((a, b) => new Date(b.publication_date) - new Date(a.publication_date));

  articles.forEach(article => {
    const link = document.createElement('a');
    link.className = 'article';
    link.href = article.filename;

    const thumbnailElement = document.createElement('div');
    thumbnailElement.className = 'thumbnail';

    const img = document.createElement('img');
    img.src = thumbnailPath(article);
    img.alt = article.title;
    img.loading = 'lazy';
    img.decoding = 'async';
    thumbnailElement.appendChild(img);

    const contentElement = document.createElement('div');
    contentElement.className = 'content';

    const titleElement = document.createElement('div');
    titleElement.className = 'title';
    titleElement.textContent = article.title;

    const subtitleElement = document.createElement('div');
    subtitleElement.className = 'subtitle';
    subtitleElement.textContent = article.subtitle || '';

    const dateElement = document.createElement('div');
    dateElement.className = 'date';
    dateElement.textContent = 'Published on ' + formatDate(article.publication_date);

    contentElement.appendChild(titleElement);
    contentElement.appendChild(subtitleElement);
    contentElement.appendChild(dateElement);

    link.appendChild(thumbnailElement);
    link.appendChild(contentElement);
    articleGrid.appendChild(link);
  });
}

function formatDate(dateString) {
  const options = { year: 'numeric', month: 'long', day: 'numeric' };
  return new Date(dateString).toLocaleDateString('de-DE', options);
}
