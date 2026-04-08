import { defineConfig } from 'astro/config'
import vue from '@astrojs/vue'
import tailwind from '@astrojs/tailwind'

export default defineConfig({
  site: 'https://sujankakumanu.com',
  base: '/musa-8010-nycedc',
  integrations: [vue(), tailwind()],
})
