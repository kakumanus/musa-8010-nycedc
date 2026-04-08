# NYC Ferry Delay Prediction — Web App

Dashboard for NYC Ferry to input conditions and see predicted delay risk across the ferry network. Built as a deliverable for NYC EDC.

---

## What is Astro, and why use it here?

[Astro](https://astro.build) is a web framework built around the idea that most of a page doesn't need to run JavaScript. It renders the page structure (HTML, layout, navbar) as plain static files at build time, and only "hydrates" the parts that actually need to be interactive in the browser.

This project is a good fit because the outer shell — the navbar, footer, and page structure — is completely static. Only the map and sidebar need to react to user input. Astro lets us write those interactive parts in whatever way we see fit ([Vue](https://vuejs.org), React, etc.).

If you're new to HTML and CSS, [W3Schools](https://www.w3schools.com) is a good reference for looking up how elements and properties work.

---

## Project structure

```
src/
  pages/          — the actual pages of the site. index.astro is the only page.
  layouts/        — base HTML wrapper (fonts, body styles) shared across pages.
  constants.ts    — shared values: route colors, map center, stop coordinates.
  components/
    layout/       — static Astro components. Navbar and Footer live here. These
                    never change based on user interaction, so they don't need Vue.
    sections/     — large Vue components that make up a full panel or view.
                    SidebarInput (the input form) and SidebarResults (the prediction
                    output) live here. Each one represents a distinct state of
                    the sidebar.
    ui/           — small, reusable Vue components used inside sections or pages.
                    Things like individual stop markers, badges, or chart wrappers
                    would go here.
```

The map (`MapContainer.vue`) lives outside `ui/` at the top level of `components/` because it is a persistent, full-screen element — not a small reusable piece. It never disappears; only the sidebar content changes between views.

The sidebar view (input form vs. prediction output) is managed in `AppShell.vue`, which wraps the map and sidebar together and decides which sidebar to show (and the transition between them).

---

## Config files

**`astro.config.mjs`** — the main Astro configuration. Sets the deployment URL and base path for GitHub Pages, and registers integrations (Vue and Tailwind).

**`tailwind.config.mjs`** — configures [Tailwind CSS](https://tailwindcss.com), the utility class styling system used throughout the app. This is where the NYC Ferry brand colors and fonts are defined so they can be used as classes like `text-ferry-light-blue` anywhere in the project.

**`tsconfig.json`** — configures TypeScript, which is the version of JavaScript used here that adds type checking. This file tells TypeScript how strict to be and where to find files. You generally won't need to touch it.

---

## Commands

Run these from the `nyc_ferry_app/` directory.

```bash
npm install      # install dependencies — run this once after cloning, or any time
                 # package.json changes (i.e. a new library was added)
npm run dev      # start local dev server at localhost:4321
npm run build    # build for production
npm run preview  # preview the production build locally
```

`npm install` downloads all the libraries the project depends on into a `node_modules/` folder. That folder is not committed to git (it's in `.gitignore`) because it's large and can always be regenerated from `package.json`.
