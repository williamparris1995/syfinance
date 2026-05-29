import { invokeTauri } from '../tauri';

export interface EncryptionStatus {
  enabled: boolean;
  unlocked: boolean;
}

export const getEncryptionStatus = () =>
  invokeTauri<EncryptionStatus>('get_encryption_status');

export const setupEncryption = (password: string) =>
  invokeTauri<void>('setup_encryption', { payload: { password } });

export const unlockEncryption = (password: string) =>
  invokeTauri<void>('unlock_encryption', { payload: { password } });

export const unlockEncryptionKeychain = () =>
  invokeTauri<void>('unlock_encryption_keychain');

export const lockEncryption = () =>
  invokeTauri<void>('lock_encryption');

export const disableEncryption = (password: string) =>
  invokeTauri<void>('disable_encryption', { payload: { password } });
