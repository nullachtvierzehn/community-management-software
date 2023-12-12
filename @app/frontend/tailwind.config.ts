import tailwindTypography from '@tailwindcss/typography'
import type { Config } from 'tailwindcss'

export default {
  content: ['./**/*.{html,js,jsx,ts,tsx,vue,css}'],
  theme: {
    extend: {},
  },
  plugins: [tailwindTypography],
} satisfies Config
