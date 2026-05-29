import { QueryClientProvider } from '@tanstack/react-query';
import { RouterProvider } from '@tanstack/react-router';
import { Toaster } from 'sonner';
import { ErrorBoundary } from './components/ErrorBoundary';
import { ThemeProvider } from './components/theme/ThemeProvider';
import { queryClient } from './lib/queryClient';
import { router } from './router';
import './i18n';

export default function App() {
  return (
    <ThemeProvider>
      <ErrorBoundary>
        <QueryClientProvider client={queryClient}>
          <RouterProvider router={router} />
          <Toaster position="top-right" richColors closeButton />
        </QueryClientProvider>
      </ErrorBoundary>
    </ThemeProvider>
  );
}
