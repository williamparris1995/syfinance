import { useState, useEffect, useRef, useCallback } from 'react';
import { Search, Wallet, CreditCard, Target, X } from 'lucide-react';
import { useNavigate } from '@tanstack/react-router';
import { cn } from '@/lib/utils';
import { useTranslation } from 'react-i18next';
import { globalSearch, SearchResultDto } from '@/lib/tauri/search';

interface GlobalSearchProps {
  className?: string;
}

const resultTypeIcons: Record<string, React.ReactNode> = {
  account: <Wallet className="h-4 w-4 text-blue-500" />,
  transaction: <CreditCard className="h-4 w-4 text-green-500" />,
  goal: <Target className="h-4 w-4 text-purple-500" />,
};

const resultTypeRoutes: Record<string, (id: string) => string> = {
  account: (id) => `/accounts/${id}`,
  transaction: () => '/transactions',
  goal: () => '/goals',
};

export function GlobalSearch({ className }: GlobalSearchProps) {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const [query, setQuery] = useState('');
  const [results, setResults] = useState<SearchResultDto[]>([]);
  const [isOpen, setIsOpen] = useState(false);
  const [isLoading, setIsLoading] = useState(false);
  const [selectedIndex, setSelectedIndex] = useState(0);
  const inputRef = useRef<HTMLInputElement>(null);
  const containerRef = useRef<HTMLDivElement>(null);
  const debounceRef = useRef<ReturnType<typeof setTimeout>>(undefined);

  const performSearch = useCallback(async (searchQuery: string) => {
    if (searchQuery.trim().length < 2) {
      setResults([]);
      return;
    }
    setIsLoading(true);
    try {
      const data = await globalSearch(searchQuery);
      setResults(data);
      setSelectedIndex(0);
    } catch (err) {
      console.error('Search failed:', err);
      setResults([]);
    } finally {
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    if (debounceRef.current) {
      clearTimeout(debounceRef.current);
    }
    debounceRef.current = setTimeout(() => {
      performSearch(query);
    }, 300);
    return () => {
      if (debounceRef.current) {
        clearTimeout(debounceRef.current);
      }
    };
  }, [query, performSearch]);

  // Keyboard shortcut: Cmd+K / Ctrl+K
  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if ((e.metaKey || e.ctrlKey) && e.key === 'k') {
        e.preventDefault();
        setIsOpen(true);
        setTimeout(() => inputRef.current?.focus(), 50);
      }
      if (e.key === 'Escape') {
        setIsOpen(false);
        setQuery('');
        setResults([]);
      }
    };
    document.addEventListener('keydown', handleKeyDown);
    return () => document.removeEventListener('keydown', handleKeyDown);
  }, []);

  // Click outside to close
  useEffect(() => {
    const handleClickOutside = (e: MouseEvent) => {
      if (containerRef.current && !containerRef.current.contains(e.target as Node)) {
        setIsOpen(false);
      }
    };
    if (isOpen) {
      document.addEventListener('mousedown', handleClickOutside);
    }
    return () => document.removeEventListener('mousedown', handleClickOutside);
  }, [isOpen]);

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'ArrowDown') {
      e.preventDefault();
      setSelectedIndex((prev) => Math.min(prev + 1, results.length - 1));
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      setSelectedIndex((prev) => Math.max(prev - 1, 0));
    } else if (e.key === 'Enter' && results.length > 0) {
      e.preventDefault();
      handleSelect(results[selectedIndex]);
    }
  };

  const handleSelect = (result: SearchResultDto) => {
    const routeBuilder = resultTypeRoutes[result.result_type];
    if (routeBuilder) {
      navigate({ to: routeBuilder(result.id) });
    }
    setIsOpen(false);
    setQuery('');
    setResults([]);
  };

  return (
    <div ref={containerRef} className={cn('relative', className)}>
      {/* Search trigger */}
      <button
        onClick={() => {
          setIsOpen(true);
          setTimeout(() => inputRef.current?.focus(), 50);
        }}
        className="flex h-9 w-64 items-center gap-2 rounded-md border border-input bg-background px-3 text-sm text-muted-foreground hover:bg-accent/50 transition-colors"
      >
        <Search className="h-4 w-4" />
        <span className="flex-1 text-left">{t('common.search')}</span>
        <kbd className="pointer-events-none hidden h-5 select-none items-center gap-1 rounded border bg-muted px-1.5 font-mono text-[10px] font-medium sm:flex">
          <span className="text-xs">{'⌘'}</span>{'K'}
        </kbd>
      </button>

      {/* Search dropdown */}
      {isOpen && (
        <div className="absolute top-full left-0 z-50 mt-1 w-full min-w-[400px] rounded-lg border bg-popover shadow-lg">
          {/* Input */}
          <div className="flex items-center border-b px-3">
            <Search className="h-4 w-4 shrink-0 text-muted-foreground" />
            <input
              ref={inputRef}
              type="text"
              value={query}
              onChange={(e) => setQuery(e.target.value)}
              onKeyDown={handleKeyDown}
              placeholder={t('common.search') + '...'}
              className="flex h-11 w-full rounded-md bg-transparent py-3 pl-2 pr-8 text-sm outline-none placeholder:text-muted-foreground"
              autoFocus
            />
            {query && (
              <button
                onClick={() => {
                  setQuery('');
                  setResults([]);
                  inputRef.current?.focus();
                }}
                className="shrink-0 text-muted-foreground hover:text-foreground"
              >
                <X className="h-4 w-4" />
              </button>
            )}
          </div>

          {/* Results */}
          <div className="max-h-[300px] overflow-y-auto p-1">
            {isLoading && (
              <div className="px-3 py-6 text-center text-sm text-muted-foreground">
                {t('common.loading')}
              </div>
            )}

            {!isLoading && query.trim().length >= 2 && results.length === 0 && (
              <div className="px-3 py-6 text-center text-sm text-muted-foreground">
                {t('common.search')} - {t('common.noResults', 'No results')}
              </div>
            )}

            {!isLoading && results.length > 0 && (
              <div className="space-y-0.5">
                {results.map((result, index) => (
                  <button
                    key={`${result.result_type}-${result.id}`}
                    onClick={() => handleSelect(result)}
                    onMouseEnter={() => setSelectedIndex(index)}
                    className={cn(
                      'flex w-full items-center gap-3 rounded-md px-3 py-2 text-left text-sm transition-colors',
                      index === selectedIndex
                        ? 'bg-accent text-accent-foreground'
                        : 'hover:bg-accent/50'
                    )}
                  >
                    <span className="shrink-0">
                      {resultTypeIcons[result.result_type] || (
                        <Search className="h-4 w-4 text-muted-foreground" />
                      )}
                    </span>
                    <div className="flex-1 min-w-0">
                      <div className="truncate font-medium">{result.title}</div>
                      <div className="truncate text-xs text-muted-foreground">
                        {result.subtitle}
                      </div>
                    </div>
                    <span className="shrink-0 text-xs text-muted-foreground capitalize">
                      {result.result_type}
                    </span>
                  </button>
                ))}
              </div>
            )}

            {!isLoading && query.trim().length < 2 && (
              <div className="px-3 py-6 text-center text-sm text-muted-foreground">
                {t('common.search')}
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
