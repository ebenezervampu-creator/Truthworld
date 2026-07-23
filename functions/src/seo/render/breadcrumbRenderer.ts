import { DOMAIN, escapeHtml } from "../schema/schemaConfig";

export interface BreadcrumbItem {
  name: string;
  url: string;
}

export function generateBreadcrumbData(items: BreadcrumbItem[]) {
  const fullItems: BreadcrumbItem[] = [
    { name: "Home", url: DOMAIN },
    ...items
  ];

  // 1. JSON-LD BreadcrumbList Schema
  const jsonLd = {
    "@context": "https://schema.org",
    "@type": "BreadcrumbList",
    itemListElement: fullItems.map((item, index) => ({
      "@type": "ListItem",
      position: index + 1,
      name: item.name,
      item: item.url
    }))
  };

  // 2. Visible HTML Breadcrumbs Markup
  let html = `<nav aria-label="breadcrumb" class="tw-breadcrumbs" style="padding: 12px 16px; font-size: 14px; color: #a1a1aa; font-family: Roboto, sans-serif;">\n`;
  html += `  <ol style="display: flex; flex-wrap: wrap; list-style: none; margin: 0; padding: 0; align-items: center;">\n`;
  
  fullItems.forEach((item, index) => {
    const isLast = index === fullItems.length - 1;
    if (isLast) {
      html += `    <li style="color: #e4e4e7; font-weight: 500;" aria-current="page">${escapeHtml(item.name)}</li>\n`;
    } else {
      html += `    <li><a href="${escapeHtml(item.url)}" style="color: #9B30FF; text-decoration: none; hover: underline;">${escapeHtml(item.name)}</a></li>\n`;
      html += `    <li style="margin: 0 8px; color: #71717a;" aria-hidden="true">&rsaquo;</li>\n`;
    }
  });

  html += `  </ol>\n</nav>`;

  return { jsonLd, html };
}
