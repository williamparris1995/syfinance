import { useCallback, useEffect, useState } from 'react';

export type GroupId =
  | 'overview'
  | 'assetManagement'
  | 'transactions'
  | 'planning'
  | 'analysis'
  | 'system';

const STORAGE_KEY = 'sidebar-group-state';

const ALL_GROUP_IDS: GroupId[] = [
  'overview',
  'assetManagement',
  'transactions',
  'planning',
  'analysis',
  'system',
];

function getDefaultState(): Record<GroupId, boolean> {
  const state = {} as Record<GroupId, boolean>;
  for (const id of ALL_GROUP_IDS) {
    state[id] = true;
  }
  return state;
}

function loadStateFromStorage(): Record<GroupId, boolean> {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    if (!raw) return getDefaultState();

    const parsed = JSON.parse(raw);
    if (typeof parsed !== 'object' || parsed === null) return getDefaultState();

    const state = {} as Record<GroupId, boolean>;
    for (const id of ALL_GROUP_IDS) {
      state[id] = typeof parsed[id] === 'boolean' ? parsed[id] : true;
    }
    return state;
  } catch {
    return getDefaultState();
  }
}

function saveStateToStorage(state: Record<GroupId, boolean>): void {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  } catch {
    // Ignore localStorage errors (e.g., quota exceeded, private mode)
  }
}

export function useSidebarState(activeGroupId?: GroupId) {
  const [groupState, setGroupState] = useState<Record<GroupId, boolean>>(
    () => loadStateFromStorage()
  );

  // Persist to localStorage whenever groupState changes
  useEffect(() => {
    saveStateToStorage(groupState);
  }, [groupState]);

  // Force active group open when activeGroupId changes
  useEffect(() => {
    if (!activeGroupId) return;
    setGroupState((prev) => {
      if (prev[activeGroupId] === true) return prev;
      return { ...prev, [activeGroupId]: true };
    });
  }, [activeGroupId]);

  const isGroupOpen = useCallback(
    (groupId: GroupId): boolean => {
      if (groupId === activeGroupId) return true;
      return groupState[groupId];
    },
    [groupState, activeGroupId]
  );

  const toggleGroup = useCallback(
    (groupId: GroupId): void => {
      if (groupId === activeGroupId) return;
      setGroupState((prev) => ({
        ...prev,
        [groupId]: !prev[groupId],
      }));
    },
    [activeGroupId]
  );

  return { isGroupOpen, toggleGroup };
}
