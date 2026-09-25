/** @type {import('@astrojs/starlight/types').StarlightUserConfig['sidebar']} */
export const sidebar = [
  {
    label: "Guide",
    items: [
      { label: "Getting started", slug: "docs/intro" },
      { label: "API reference", slug: "docs/api-reference" },
      {
        label: "Topics",
        items: [
          { label: "Typed paths", slug: "docs/guides/paths" },
          { label: "Project structure", slug: "docs/guides/project-structure" },
          { label: "Transient overlay", slug: "docs/guides/transient" },
          { label: "Ordered lists", slug: "docs/guides/ordered-lists" },
        ],
      },
    ],
  },
];
