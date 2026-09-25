/** @type {import('@astrojs/starlight/types').StarlightUserConfig['sidebar']} */
export const sidebar = [
  {
    label: "KeepData",
    items: [
      { label: "Getting started", slug: "docs/intro" },
      { label: "API reference", slug: "docs/api-reference" },
      {
        label: "Guides",
        items: [
          { label: "Project structure", slug: "docs/guides/project-structure" },
          { label: "Typed paths", slug: "docs/guides/paths" },
          { label: "Stores and platform", slug: "docs/guides/stores-and-platform" },
          { label: "Example — leaderboard", slug: "docs/guides/leaderboard-system" },
          { label: "Example — inventory", slug: "docs/guides/inventory-system" },
          { label: "Transient overlay", slug: "docs/guides/transient" },
          { label: "Ordered lists", slug: "docs/guides/ordered-lists" },
        ],
      },
    ],
  },
];
