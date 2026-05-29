import { Store } from '@tauri-apps/plugin-store';

const STORE_FILE = 'onboarding.json';

export interface OnboardingState {
  currentStep: number;
  completed: boolean;
  defaultCurrency?: string;
  hasCreatedFirstAccount?: boolean;
  hasSeenFeatureTour?: boolean;
}

const DEFAULT_STATE: OnboardingState = {
  currentStep: 0,
  completed: false,
};

let store: Store | null = null;

async function getStore(): Promise<Store> {
  if (!store) {
    try {
      store = await Store.load(STORE_FILE);
    } catch (error) {
      const msg = `Failed to load onboarding store: ${error}`;
      throw new Error(msg); // eslint-disable-line preserve-caught-error -- Error serializes via toString() by default
    }
  }
  return store;
}

export async function getOnboardingState(): Promise<OnboardingState> {
  try {
    const s = await getStore();
    const currentStep = await s.get<number>('currentStep');
    const completed = await s.get<boolean>('completed');
    const defaultCurrency = await s.get<string>('defaultCurrency');
    const hasCreatedFirstAccount = await s.get<boolean>('hasCreatedFirstAccount');
    const hasSeenFeatureTour = await s.get<boolean>('hasSeenFeatureTour');

    return {
      currentStep: currentStep ?? DEFAULT_STATE.currentStep,
      completed: completed ?? DEFAULT_STATE.completed,
      defaultCurrency: defaultCurrency ?? undefined,
      hasCreatedFirstAccount: hasCreatedFirstAccount ?? undefined,
      hasSeenFeatureTour: hasSeenFeatureTour ?? undefined,
    };
  } catch (error) {
    console.error('Failed to get onboarding state:', error);
    return DEFAULT_STATE;
  }
}

export async function setOnboardingStep(step: number): Promise<void> {
  try {
    const s = await getStore();
    await s.set('currentStep', step);
    await s.save();
  } catch (error) {
    console.error('Failed to set onboarding step:', error);
    throw error;
  }
}

export async function setDefaultCurrency(currency: string): Promise<void> {
  try {
    const s = await getStore();
    await s.set('defaultCurrency', currency);
    await s.save();
  } catch (error) {
    console.error('Failed to set default currency:', error);
    throw error;
  }
}

export async function markFirstAccountCreated(): Promise<void> {
  try {
    const s = await getStore();
    await s.set('hasCreatedFirstAccount', true);
    await s.save();
  } catch (error) {
    console.error('Failed to mark first account created:', error);
    throw error;
  }
}

export async function markFeatureTourSeen(): Promise<void> {
  try {
    const s = await getStore();
    await s.set('hasSeenFeatureTour', true);
    await s.save();
  } catch (error) {
    console.error('Failed to mark feature tour seen:', error);
    throw error;
  }
}

export async function markOnboardingComplete(): Promise<void> {
  try {
    const s = await getStore();
    await s.set('completed', true);
    await s.save();
  } catch (error) {
    console.error('Failed to mark onboarding complete:', error);
    throw error;
  }
}

export async function resetOnboarding(): Promise<void> {
  try {
    const s = await getStore();
    await s.set('currentStep', DEFAULT_STATE.currentStep);
    await s.set('completed', DEFAULT_STATE.completed);
    await s.delete('defaultCurrency');
    await s.delete('hasCreatedFirstAccount');
    await s.delete('hasSeenFeatureTour');
    await s.save();
  } catch (error) {
    console.error('Failed to reset onboarding:', error);
    throw error;
  }
}
