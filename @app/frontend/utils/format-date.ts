import 'dayjs/locale/de'

import dayjs from 'dayjs'
import relativeTimePlugin from 'dayjs/plugin/relativeTime'

dayjs.extend(relativeTimePlugin)

import {
  type DateLike,
  formatDate as formatDateFromVueuse,
  normalizeDate,
  type UseDateFormatOptions,
} from '@vueuse/shared'
import { update } from 'lodash'

/**
Formats a date string using the given format string.
@param date - The date to format. Might be a string or a Date.
@param formatString - The format string to use for formatting, e.g. YYYY-MM-DD HH:mm:ss.SSS.
@param options - Optional options for formatting the date.
@returns The formatted date string.
 */
export function formatDate(
  date: DateLike,
  formatString: string,
  options?: UseDateFormatOptions
): string {
  return formatDateFromVueuse(normalizeDate(date), formatString, options)
}

export interface FormatDateFromNowOptions {
  locale?: string
  withoutSuffix?: boolean
}

export const now = ref(new Date())

export function updateNow() {
  now.value = new Date()
  window.requestAnimationFrame(updateNow)
}

if (import.meta.browser) {
  updateNow()
}

export function formatDateFromNow(
  date: DateLike,
  options?: FormatDateFromNowOptions
) {
  const app = useNuxtApp()
  return dayjs(date)
    .locale(options?.locale ?? app.$i18n.locale.value)
    .from(toValue(now), options?.withoutSuffix)
}
