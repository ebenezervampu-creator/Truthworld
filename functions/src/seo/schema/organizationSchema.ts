import { DOMAIN } from "./schemaConfig";

export function generateOrganizationSchema() {
  return [
    {
      "@context": "https://schema.org",
      "@type": "WebSite",
      "name": "Truthworld",
      "alternateName": ["Truth World", "Truthworld.in", "Truthworld Studio", "Truthworld Ads"],
      "url": DOMAIN,
      "potentialAction": {
        "@type": "SearchAction",
        "target": `${DOMAIN}/search?q={search_term_string}`,
        "query-input": "required name=search_term_string"
      }
    },
    {
      "@context": "https://schema.org",
      "@type": "Organization",
      "name": "Truthworld",
      "alternateName": ["Truth World", "Truthworld Platform"],
      "url": DOMAIN,
      "logo": `${DOMAIN}/icons/Icon-192.png`,
      "sameAs": [
        "https://twitter.com/truthworld",
        "https://facebook.com/truthworld",
        "https://instagram.com/truthworld"
      ]
    },
    {
      "@context": "https://schema.org",
      "@type": "Brand",
      "name": "Truthworld",
      "alternateName": ["Truth World", "Truthworld Studio"],
      "url": DOMAIN,
      "logo": `${DOMAIN}/icons/Icon-192.png`
    },
    {
      "@context": "https://schema.org",
      "@type": "ItemList",
      "name": "Truthworld Sitelinks",
      "itemListElement": [
        {
          "@type": "SiteNavigationElement",
          "position": 1,
          "name": "Truthworld Studio",
          "description": "Manage your creator channel, upload content, track performance analytics, and engage with viewers.",
          "url": `${DOMAIN}/studio`
        },
        {
          "@type": "SiteNavigationElement",
          "position": 2,
          "name": "Truthworld Advertisements",
          "description": "Create, manage, and scale high-impact video advertisement campaigns on Truthworld.",
          "url": `${DOMAIN}/advertisements`
        },
        {
          "@type": "SiteNavigationElement",
          "position": 3,
          "name": "Truthworld Channels",
          "description": "Explore creator channels, topics, and community content on Truthworld.",
          "url": `${DOMAIN}/browse`
        },
        {
          "@type": "SiteNavigationElement",
          "position": 4,
          "name": "Trending & Playlists",
          "description": "Discover trending video stories, curated playlists, and top discussions on Truthworld.",
          "url": `${DOMAIN}/trending`
        }
      ]
    }
  ];
}

