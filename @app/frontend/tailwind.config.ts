import tailwindTypography from '@tailwindcss/typography'
import type { Config } from 'tailwindcss'

export default {
  content: ['./**/*.{html,js,jsx,ts,tsx,vue,css}'],
  theme: {
    extend: {
      fontFamily: {
        sans: [
          'Merriweather Sans Variable',
          'ui-sans-serif',
          'system-ui',
          'sans',
        ],
        serif: ['Merriweather', 'ui-serif', 'Georgia', 'serif'],
      },
    },
  },
  plugins: [tailwindTypography],
} satisfies Config
