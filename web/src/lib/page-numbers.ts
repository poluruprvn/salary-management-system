// First, last, and the current page's neighbours, with 'gap' where pages are skipped.
// A gap of exactly one page shows that page instead.
export function pageNumbers(current: number, total: number): (number | 'gap')[] {
  const pages = [...new Set([1, current - 1, current, current + 1, total])]
    .filter((page) => page >= 1 && page <= total)
    .sort((a, b) => a - b)

  return pages.flatMap((page, index) => {
    const before = pages[index - 1]
    if (before === undefined || page - before === 1) return [page]

    return page - before === 2 ? [page - 1, page] : ['gap' as const, page]
  })
}
