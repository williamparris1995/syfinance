const LAST_SYNC_TIME_KEY = 'lastSyncTime';

/**
 * Get the last sync time from localStorage
 * @returns Date object if sync time exists, null otherwise
 */
export function getLastSyncTime(): Date | null {
  const timestamp = localStorage.getItem(LAST_SYNC_TIME_KEY);
  if (!timestamp) return null;
  
  const date = new Date(timestamp);
  return isNaN(date.getTime()) ? null : date;
}

/**
 * Set the last sync time in localStorage
 * @param date - Date to store as last sync time
 */
export function setLastSyncTime(date: Date): void {
  localStorage.setItem(LAST_SYNC_TIME_KEY, date.toISOString());
}

/**
 * Format sync time as relative time string
 * @param date - Date to format
 * @returns Formatted string like "just now", "5 minutes ago", "2 hours ago"
 */
export function formatSyncTime(date: Date): string {
  const now = new Date();
  const diffMs = now.getTime() - date.getTime();
  const diffSeconds = Math.floor(diffMs / 1000);
  const diffMinutes = Math.floor(diffSeconds / 60);
  const diffHours = Math.floor(diffMinutes / 60);
  const diffDays = Math.floor(diffHours / 24);

  if (diffSeconds < 10) {
    return 'just now';
  } else if (diffSeconds < 60) {
    return `${diffSeconds} seconds ago`;
  } else if (diffMinutes === 1) {
    return '1 minute ago';
  } else if (diffMinutes < 60) {
    return `${diffMinutes} minutes ago`;
  } else if (diffHours === 1) {
    return '1 hour ago';
  } else if (diffHours < 24) {
    return `${diffHours} hours ago`;
  } else if (diffDays === 1) {
    return '1 day ago';
  } else {
    return `${diffDays} days ago`;
  }
}

/**
 * Trigger a manual sync operation
 * Mock implementation that simulates network delay
 * @returns Promise that resolves when sync completes
 * @throws Error if sync fails
 */
export async function triggerSync(): Promise<void> {
  // Simulate network delay
  await new Promise((resolve) => setTimeout(resolve, 2000));
  
  // Mock success - in real implementation, this would call the sync API
  // Example: await invokeTauri('sync_push', { changes: [] });
  // or: await fetch('/api/sync/push', { method: 'POST', body: JSON.stringify({ changes: [] }) });
  
  // Simulate occasional failure (10% chance) for testing error handling
  if (Math.random() < 0.1) {
    throw new Error('Network error: Unable to reach sync server');
  }
  
  // On success, update last sync time
  setLastSyncTime(new Date());
}
