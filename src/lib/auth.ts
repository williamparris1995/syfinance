import { Store } from '@tauri-apps/plugin-store';

const STORE_FILE = 'auth.json';
const ACCOUNT_ID_KEY = 'account_id';
const DEVICE_ID_KEY = 'device_id';

let store: Store | null = null;

async function getStore(): Promise<Store> {
  if (!store) {
    try {
      store = await Store.load(STORE_FILE);
      console.log('Store loaded successfully');
    } catch (error) {
      console.error('Failed to load store:', error);
      // Create new store if loading fails
      store = new Store(STORE_FILE);
      console.log('Created new store');
    }
  }
  return store;
}

export interface RegisterResponse {
  account_id: string;
  device_id: string;
}

export async function getAccountId(): Promise<string | null> {
  try {
    const s = await getStore();
    const accountId = await s.get<string>(ACCOUNT_ID_KEY);
    return accountId ?? null;
  } catch (error) {
    console.error('Failed to get account ID:', error);
    return null;
  }
}

export async function getDeviceId(): Promise<string | null> {
  try {
    const s = await getStore();
    const deviceId = await s.get<string>(DEVICE_ID_KEY);
    return deviceId ?? null;
  } catch (error) {
    console.error('Failed to get device ID:', error);
    return null;
  }
}

export async function isRegistered(): Promise<boolean> {
  try {
    const accountId = await getAccountId();
    const result = accountId !== null;
    console.log('isRegistered:', result, 'accountId:', accountId);
    return result;
  } catch (error) {
    console.error('isRegistered error:', error);
    return false;
  }
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
