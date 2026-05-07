import { invoke } from '@tauri-apps/api/core';

export type TauriArgs = Record<string, unknown> | undefined;

// Check if running in Tauri environment
export function isTauri(): boolean {
  // Check multiple indicators that we're in Tauri
  if (typeof window === 'undefined') return false;
  
  // Check for __TAURI__ global
  if ('__TAURI__' in window) return true;
  
  // Check for __TAURI_INTERNALS__ (Tauri v2)
  if ('__TAURI_INTERNALS__' in window) return true;
  
  // Check if we can access Tauri APIs
  try {
    // In Tauri, window.__TAURI_INTERNALS__ should exist
    return !!(window as any).__TAURI_INTERNALS__;
  } catch {
    return false;
  }
}

export function invokeTauri<TResult>(command: string, args?: TauriArgs): Promise<TResult> {
  // Always try to invoke - let Tauri handle the error if not available
  try {
    return invoke<TResult>(command, args);
  } catch (error) {
    console.error(`Failed to invoke Tauri command "${command}":`, error);
    return Promise.reject(error);
  }
}
