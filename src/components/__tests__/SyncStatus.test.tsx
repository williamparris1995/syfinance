import { describe, it, expect, vi, beforeEach } from 'vitest';
import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { SyncStatus } from '../SyncStatus';
import * as tauri from '@/lib/tauri';

vi.mock('@/lib/tauri', () => ({
  invokeTauri: vi.fn(),
}));

describe('SyncStatus', () => {
  let queryClient: QueryClient;

  beforeEach(() => {
    queryClient = new QueryClient({
      defaultOptions: {
        queries: { retry: false },
        mutations: { retry: false },
      },
    });
    localStorage.clear();
    vi.clearAllMocks();
  });

  const renderWithQuery = (component: React.ReactElement) => {
    return render(
      <QueryClientProvider client={queryClient}>{component}</QueryClientProvider>
    );
  };

  it('displays "Not synced" when no sync has occurred', async () => {
    vi.mocked(tauri.invokeTauri).mockResolvedValue({
      last_sync_at: null,
      is_syncing: false,
      error: null,
    });

    renderWithQuery(<SyncStatus />);

    await waitFor(() => {
      expect(screen.getByText('Not synced')).toBeInTheDocument();
    });
  });

  it('displays last sync time in relative format', async () => {
    const fiveMinutesAgo = new Date(Date.now() - 5 * 60 * 1000).toISOString();
    vi.mocked(tauri.invokeTauri).mockResolvedValue({
      last_sync_at: fiveMinutesAgo,
      is_syncing: false,
      error: null,
    });

    renderWithQuery(<SyncStatus />);

    await waitFor(() => {
      expect(screen.getByText('5 minutes ago')).toBeInTheDocument();
    });
  });

  it('displays "Syncing..." when sync is in progress', async () => {
    vi.mocked(tauri.invokeTauri).mockResolvedValue({
      last_sync_at: null,
      is_syncing: true,
      error: null,
    });

    renderWithQuery(<SyncStatus />);

    await waitFor(() => {
      expect(screen.getByText('Syncing...')).toBeInTheDocument();
    });
  });

  it('displays error message when sync fails', async () => {
    vi.mocked(tauri.invokeTauri).mockResolvedValue({
      last_sync_at: null,
      is_syncing: false,
      error: 'Sync failed: Unable to connect',
    });

    renderWithQuery(<SyncStatus />);

    await waitFor(() => {
      expect(screen.getByText('Failed')).toBeInTheDocument();
      expect(screen.getByText('Sync failed: Unable to connect')).toBeInTheDocument();
    });
  });

  it('triggers manual sync when "Sync Now" button is clicked', async () => {
    const user = userEvent.setup();
    const mockSyncResult = {
      last_sync_at: new Date().toISOString(),
      is_syncing: false,
      error: null,
    };

    vi.mocked(tauri.invokeTauri)
      .mockResolvedValueOnce({
        last_sync_at: null,
        is_syncing: false,
        error: null,
      })
      .mockResolvedValueOnce(mockSyncResult);

    renderWithQuery(<SyncStatus />);

    await waitFor(() => {
      expect(screen.getByText('Sync Now')).toBeInTheDocument();
    });

    const syncButton = screen.getByText('Sync Now');
    await user.click(syncButton);

    await waitFor(() => {
      expect(tauri.invokeTauri).toHaveBeenCalledWith('sync_to_server');
    });
  });

  it('disables sync button while syncing', async () => {
    vi.mocked(tauri.invokeTauri).mockResolvedValue({
      last_sync_at: null,
      is_syncing: true,
      error: null,
    });

    renderWithQuery(<SyncStatus />);

    await waitFor(() => {
      const syncButton = screen.getByText('Sync Now');
      expect(syncButton).toBeDisabled();
    });
  });

  it('stores last sync timestamp in localStorage', async () => {
    const timestamp = new Date().toISOString();
    vi.mocked(tauri.invokeTauri).mockResolvedValue({
      last_sync_at: timestamp,
      is_syncing: false,
      error: null,
    });

    renderWithQuery(<SyncStatus />);

    await waitFor(() => {
      expect(localStorage.getItem('finance_app_last_sync')).toBe(timestamp);
    });
  });
});
