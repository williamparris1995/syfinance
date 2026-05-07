import { Store } from '@tauri-apps/plugin-store';

const STORE_FILE = 'auth.json';
const ACCOUNT_ID_KEY = 'account_id';
const DEVICE_ID_KEY = 'device_id';

let store: Store | null = null;

async function getStore(): Promise<Store> {
  if (!store) {
    store = await Store.load(STORE_FILE);
  }
  return store;
}

export interface RegisterResponse {
  account_id: string;
  device_id: string;
}

export async function getAccountId(): Promise<string | null> {
  const s = await getStore();
  const accountId = await s.get<string>(ACCOUNT_ID_KEY);
  return accountId ?? null;
}

export async function getDeviceId(): Promise<string | null> {
  const s = await getStore();
  const deviceId = await s.get<string>(DEVICE_ID_KEY);
  return deviceId ?? null;
}

export async function isRegistered(): Promise<boolean> {
  const accountId = await getAccountId();
  return accountId !== null;
}

export async function registerDevice(): Promise<RegisterResponse> {
  const response = await fetch('http://127.0.0.1:3000/api/register', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    throw new Error(`Registration failed: ${response.statusText}`);
  }

  const data: RegisterResponse = await response.json();

  // Store credentials securely
  const s = await getStore();
  await s.set(ACCOUNT_ID_KEY, data.account_id);
  await s.set(DEVICE_ID_KEY, data.device_id);
  await s.save();

  return data;
}

export async function linkDevice(accountId: string): Promise<void> {
  if (!accountId || accountId.trim() === '') {
    throw new Error('Account ID is required');
  }

  // Generate new device_id for this device
  const response = await fetch('http://127.0.0.1:3000/api/register', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
  });

  if (!response.ok) {
    throw new Error(`Device linking failed: ${response.statusText}`);
  }

  const data: RegisterResponse = await response.json();

  // Store the provided account_id and new device_id
  const s = await getStore();
  await s.set(ACCOUNT_ID_KEY, accountId.trim());
  await s.set(DEVICE_ID_KEY, data.device_id);
  await s.save();
}

export async function clearAuth(): Promise<void> {
  const s = await getStore();
  await s.delete(ACCOUNT_ID_KEY);
  await s.delete(DEVICE_ID_KEY);
  await s.save();
}
