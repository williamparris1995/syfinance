import { QueryClientProvider } from '@tanstack/react-query';
import { RouterProvider } from '@tanstack/react-router';
import { Toaster } from 'sonner';
import { ErrorBoundary } from './components/ErrorBoundary';
import { queryClient } from './lib/queryClient';
import { isTauri } from './lib/tauri';
import { router } from './router';

export default function App() {
  // Check if running in Tauri environment
  if (!isTauri()) {
    return (
      <div style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        height: '100vh',
        padding: '2rem',
        textAlign: 'center',
        fontFamily: 'system-ui, -apple-system, sans-serif',
      }}>
        <h1 style={{ fontSize: '2rem', marginBottom: '1rem', color: '#ef4444' }}>
          ⚠️ Not Running in Tauri
        </h1>
        <p style={{ fontSize: '1.2rem', marginBottom: '2rem', maxWidth: '600px' }}>
          This application must be run through Tauri, not directly in the browser.
        </p>
        <div style={{
          background: '#f3f4f6',
          padding: '1.5rem',
          borderRadius: '8px',
          maxWidth: '600px',
        }}>
          <p style={{ fontWeight: 'bold', marginBottom: '1rem' }}>To run the application:</p>
          <code style={{
            display: 'block',
            background: '#1f2937',
            color: '#10b981',
            padding: '1rem',
            borderRadius: '4px',
            fontSize: '1.1rem',
          }}>
            pnpm tauri dev
          </code>
          <p style={{ marginTop: '1rem', fontSize: '0.9rem', color: '#6b7280' }}>
            Do NOT use "pnpm dev" - use "pnpm tauri dev" instead
          </p>
        </div>
      </div>
    );
  }

  return (
    <ErrorBoundary>
      <QueryClientProvider client={queryClient}>
        <RouterProvider router={router} />
        <Toaster position="top-right" richColors closeButton />
      </QueryClientProvider>
    </ErrorBoundary>
  );
}
