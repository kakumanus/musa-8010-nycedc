/** @type {import('tailwindcss').Config} */
export default {
  content: ['./src/**/*.{astro,html,js,jsx,ts,tsx,vue}'],
  theme: {
    extend: {
      colors: {
        ferry: {
          'dark-blue': '#001D41',
          'light-blue': '#00A1DF',
          'cool-gray': '#53565A',
          'light-gray': '#D9E1E2',

          
        },
      },
      fontFamily: {
        sans: ['Lato', 'sans-serif'],
        heading: ['Oswald', 'sans-serif'],
      },
    },
  },
  plugins: [],
}
