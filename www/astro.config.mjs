import { defineConfig } from "astro/config";
import starlight from "@astrojs/starlight";
import { sidebar } from "./sidebar.js";

export default defineConfig({
  site: "https://kartzrbx.github.io",
  base: "/KeepData/",
  srcDir: "./src",
  integrations: [
    starlight({
      title: "KeepData",
      description:
        "Typed stores, paths, and sync for Roblox — ProfileStore persistence, leaderboards, and Luau type functions.",
      favicon: "/favicon.png",
      logo: {
        src: "./src/assets/keepdata-mark.png",
        alt: "",
        replacesTitle: true,
      },
      social: [
        {
          icon: "github",
          label: "GitHub",
          href: "https://github.com/KartzRbx/KeepData",
        },
      ],
      editLink: {
        baseUrl: "https://github.com/KartzRbx/KeepData/edit/master/",
      },
      customCss: ["./src/styles/custom.css"],
      components: {
        Head: "./src/components/Head.astro",
      },
      sidebar,
      head: [
        {
          tag: "meta",
          attrs: { name: "theme-color", content: "#1d4ed8" },
        },
      ],
    }),
  ],
});
