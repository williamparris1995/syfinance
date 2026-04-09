import { invoke } from '@tauri-apps/api/core';

export type TauriArgs = Record<string, unknown> | undefined;

export function invokeTauri<TResult>(command: string, args?: TauriArgs) {
  return invoke<TResult>(command, args);
}
