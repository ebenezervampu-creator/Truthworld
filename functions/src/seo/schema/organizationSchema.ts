import { DOMAIN } from "./schemaConfig";

export function generateOrganizationSchema() {
  return [
    {
      "@context": "https://schema.org",
      "@type": "WebSite",
      "name": "Truthworld",
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
      "url": DOMAIN,
      "logo": `${DOMAIN}/icons/Icon-192.png`,
      "sameAs": [
        "https://twitter.com/truthworld",
        "https://facebook.com/truthworld",
        "https://instagram.com/truthworld"
      ]
    }
  ];
}
