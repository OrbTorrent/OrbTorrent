// Structured data (schema.org JSON-LD), so search engines know what
// OrbTorrent is: a free Mac app, who makes it, and how the pages relate.

import { site } from "./site";

const id = (name: string) => `${site.url}/#${name}`;

export const organization = {
  "@type": "Organization",
  "@id": id("organization"),
  name: site.name,
  url: site.url,
  logo: { "@type": "ImageObject", url: `${site.url}/icon-512.png`, width: 512, height: 512 },
  email: site.email,
  sameAs: [site.repo],
};

export const website = {
  "@type": "WebSite",
  "@id": id("website"),
  url: site.url,
  name: site.name,
  description: site.description,
  inLanguage: "en-GB",
  publisher: { "@id": id("organization") },
};

export const application = {
  "@type": "SoftwareApplication",
  "@id": id("app"),
  name: site.name,
  description: site.description,
  url: site.url,
  applicationCategory: "UtilitiesApplication",
  applicationSubCategory: "BitTorrent client",
  operatingSystem: "macOS 26 or later",
  processorRequirements: "Apple silicon or Intel",
  softwareRequirements: "macOS 26 (Tahoe) or later",
  // The disk image itself, by way of the newest release; the page has the steps.
  downloadUrl: `${site.url}${site.download}`,
  installUrl: `${site.url}/download`,
  isAccessibleForFree: true,
  license: "https://www.gnu.org/licenses/gpl-3.0.html",
  offers: { "@type": "Offer", price: "0", priceCurrency: "USD", availability: "https://schema.org/InStock" },
  image: `${site.url}/icon-512.png`,
  screenshot: { "@type": "ImageObject", url: `${site.url}/press/orbtorrent-overview-plain.jpg`, width: 2400, height: 1695 },
  featureList: [
    "Lives in the menu bar",
    "Download only through a VPN, with automatic port forwarding",
    "Holds fake downloads before they arrive",
    "Imports downloads and settings from Transmission and qBittorrent",
    "qBittorrent's engine: µTP, DHT, peer exchange, encryption",
    "Extensions written in TypeScript",
    "Signed automatic updates",
  ],
  author: { "@type": "Person", name: site.author },
  publisher: { "@id": id("organization") },
  // Its source code, on GitHub.
  sameAs: [site.repo],
};

export function breadcrumbs(trail: { name: string; path: string }[]) {
  return {
    "@type": "BreadcrumbList",
    itemListElement: [{ name: "Home", path: "/" }, ...trail].map((crumb, index) => ({
      "@type": "ListItem",
      position: index + 1,
      name: crumb.name,
      item: `${site.url}${crumb.path === "/" ? "" : crumb.path}`,
    })),
  };
}

/** A long read, such as how OrbTorrent is built, by its developer, about the app. */
export function article({ path, title, description, published, modified = published }: {
  path: string;
  title: string;
  description: string;
  /** As YYYY-MM-DD. */
  published: string;
  modified?: string;
}) {
  const url = `${site.url}${path}`;
  return {
    "@type": "TechArticle",
    "@id": `${url}#article`,
    headline: title,
    description,
    url,
    mainEntityOfPage: url,
    image: `${site.url}/og${path}.png`,
    datePublished: published,
    dateModified: modified,
    inLanguage: "en-GB",
    author: { "@type": "Person", name: site.author, url: site.authorUrl },
    publisher: { "@id": id("organization") },
    about: { "@id": id("app") },
  };
}

/** The launch film, with the picture its player shows first. */
export function film(thumbnail: string) {
  return {
    "@type": "VideoObject",
    "@id": id("film"),
    name: "OrbTorrent, the film",
    description: site.film.description,
    thumbnailUrl: `${site.url}${thumbnail}`,
    contentUrl: `${site.url}${site.film.src}`,
    uploadDate: `${site.film.made}T00:00:00+08:00`,
    duration: `PT${site.film.seconds}S`,
    inLanguage: "en-GB",
    publisher: { "@id": id("organization") },
    about: { "@id": id("app") },
  };
}

export function faqPage(items: { question: string; answer: string }[]) {
  return {
    "@type": "FAQPage",
    mainEntity: items.map((item) => ({
      "@type": "Question",
      name: item.question,
      acceptedAnswer: { "@type": "Answer", text: item.answer },
    })),
  };
}

export function graph(...nodes: object[]) {
  return { "@context": "https://schema.org", "@graph": nodes };
}
