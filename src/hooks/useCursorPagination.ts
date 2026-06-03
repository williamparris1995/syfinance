import { useState, useCallback } from 'react';
import { useQuery } from '@tanstack/react-query';

interface PageInfo {
  has_next_page: boolean;
  has_prev_page: boolean;
  next_cursor: string | null;
  prev_cursor: string | null;
}

interface PaginatedResult<T> {
  items: T[];
  page_info: PageInfo;
}

type FetcherFn<T> = (cursor: string | undefined) => Promise<PaginatedResult<T>>;

interface CursorPageState<T> {
  pages: T[][];
  pageInfos: (PageInfo | undefined)[];
  currentPage: number;
}

export function useCursorPagination<T>(
  queryKey: unknown[],
  fetcher: FetcherFn<T>,
  options?: { enabled?: boolean; pageSize?: number },
) {
  const [state, setState] = useState<CursorPageState<T>>({
    pages: [],
    pageInfos: [],
    currentPage: 0,
  });

  const enabled = options?.enabled !== false;

  // Determine cursor for current page
  const currentCursor =
    state.currentPage === 0
      ? undefined
      : state.pageInfos[state.currentPage - 1]?.next_cursor ?? undefined;

  const { isLoading, isFetching } = useQuery({
    queryKey: [...queryKey, state.currentPage, currentCursor],
    queryFn: async () => {
      // Return cached page if already loaded
      if (state.pages[state.currentPage] && state.pageInfos[state.currentPage]) {
        return {
          items: state.pages[state.currentPage],
          page_info: state.pageInfos[state.currentPage]!,
        };
      }
      const result = await fetcher(currentCursor);
      setState((prev) => {
        const newPages = [...prev.pages];
        const newPageInfos = [...prev.pageInfos];
        newPages[state.currentPage] = result.items;
        newPageInfos[state.currentPage] = result.page_info;
        return { ...prev, pages: newPages, pageInfos: newPageInfos };
      });
      return result;
    },
    enabled,
    staleTime: 5 * 60 * 1000,
  });

  const currentItems = state.pages[state.currentPage] ?? [];
  const currentPageInfo = state.pageInfos[state.currentPage];

  const goNext = useCallback(() => {
    if (currentPageInfo?.has_next_page) {
      setState((prev) => ({ ...prev, currentPage: prev.currentPage + 1 }));
    }
  }, [currentPageInfo?.has_next_page]);

  const goPrev = useCallback(() => {
    setState((prev) => ({ ...prev, currentPage: Math.max(0, prev.currentPage - 1) }));
  }, []);

  const goToPage = useCallback((page: number) => {
    setState((prev) => {
      if (page >= 0 && page < prev.pages.length) {
        return { ...prev, currentPage: page };
      }
      return prev;
    });
  }, []);

  const reset = useCallback(() => {
    setState({ pages: [], pageInfos: [], currentPage: 0 });
  }, []);

  return {
    items: currentItems,
    isLoading: isLoading || isFetching,
    currentPage: state.currentPage,
    totalPages: state.pages.length || 1,
    hasNextPage: currentPageInfo?.has_next_page ?? false,
    hasPrevPage: state.currentPage > 0,
    goNext,
    goPrev,
    goToPage,
    reset,
  };
}
