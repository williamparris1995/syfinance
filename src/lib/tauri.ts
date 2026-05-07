import { invoke } from '@tauri-apps/api/core';

export type TauriArgs = Record<string, unknown> | undefined;

// Check if running in Tauri environment
export function isTauri(): boolean {
  return typeof window !== 'undefined' && '__TAURI__' in window;
}

export function invokeTauri<TResult>(command: string, args?: TauriArgs): Promise<TResult> {
  if (!isTauri()) {
    console.warn(`Tauri command "${command}" called outside Tauri environment`);
    // Return mock data for development in browser
    return Promise.reject(new Error('Not running in Tauri environment. Please use "pnpm tauri dev" instead of "pnpm dev".'));
  }
  return invoke<TResult>(command, args);
}
