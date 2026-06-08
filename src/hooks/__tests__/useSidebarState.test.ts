import { describe, it, expect, beforeEach } from 'vitest';
import { renderHook, act } from '@testing-library/react';
import { useSidebarState, type GroupId } from '../useSidebarState';

const STORAGE_KEY = 'sidebar-group-state';
const ALL_GROUP_IDS: GroupId[] = [
  'overview',
  'investment',
  'finance',
  'borrowing',
  'tools',
];

beforeEach(() => {
  localStorage.clear();
});

describe('useSidebarState', () => {
  it('all groups open by default', () => {
    const { result } = renderHook(() => useSidebarState());

    for (const groupId of ALL_GROUP_IDS) {
      expect(result.current.isGroupOpen(groupId)).toBe(true);
    }
  });

  it('toggling a group closes it', () => {
    const { result } = renderHook(() => useSidebarState());

    act(() => {
      result.current.toggleGroup('overview');
    });

    expect(result.current.isGroupOpen('overview')).toBe(false);
    expect(result.current.isGroupOpen('finance')).toBe(true);
  });

  it('toggling a closed group opens it', () => {
    const { result } = renderHook(() => useSidebarState());

    act(() => {
      result.current.toggleGroup('overview');
    });
    expect(result.current.isGroupOpen('overview')).toBe(false);

    act(() => {
      result.current.toggleGroup('overview');
    });
    expect(result.current.isGroupOpen('overview')).toBe(true);
  });

  it('state persists to localStorage', () => {
    const { result } = renderHook(() => useSidebarState());

    act(() => {
      result.current.toggleGroup('overview');
    });

    const stored = JSON.parse(localStorage.getItem(STORAGE_KEY) ?? '{}');
    expect(stored.overview).toBe(false);
    expect(stored.finance).toBe(true);
  });

  it('state reads from localStorage on mount', () => {
    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({
        overview: false,
        investment: true,
        finance: false,
        borrowing: true,
        tools: true,
      })
    );

    const { result } = renderHook(() => useSidebarState());

    expect(result.current.isGroupOpen('overview')).toBe(false);
    expect(result.current.isGroupOpen('finance')).toBe(false);
    expect(result.current.isGroupOpen('investment')).toBe(true);
  });

  it('corrupted localStorage falls back gracefully', () => {
    localStorage.setItem(STORAGE_KEY, 'not-json');

    const { result } = renderHook(() => useSidebarState());

    for (const groupId of ALL_GROUP_IDS) {
      expect(result.current.isGroupOpen(groupId)).toBe(true);
    }
  });

  it('active group is forced open even if localStorage says it is closed', () => {
    localStorage.setItem(
      STORAGE_KEY,
      JSON.stringify({
        overview: false,
        investment: true,
        finance: true,
        borrowing: true,
        tools: true,
      })
    );

    const { result } = renderHook(() => useSidebarState('overview'));

    expect(result.current.isGroupOpen('overview')).toBe(true);
  });

  it('cannot toggle the active group', () => {
    const { result } = renderHook(() => useSidebarState('overview'));

    act(() => {
      result.current.toggleGroup('overview');
    });

    expect(result.current.isGroupOpen('overview')).toBe(true);
  });

  it('active group is forced open when activeGroupId changes', () => {
    const { result, rerender } = renderHook(
      ({ activeGroupId }: { activeGroupId?: GroupId }) =>
        useSidebarState(activeGroupId),
      { initialProps: { activeGroupId: undefined as GroupId | undefined } }
    );

    // Close overview while no active group
    act(() => {
      result.current.toggleGroup('overview');
    });
    expect(result.current.isGroupOpen('overview')).toBe(false);

    // Set overview as active — it should be forced open
    rerender({ activeGroupId: 'overview' });
    expect(result.current.isGroupOpen('overview')).toBe(true);
  });

  it('non-active groups can still be toggled when there is an active group', () => {
    const { result } = renderHook(() => useSidebarState('overview'));

    act(() => {
      result.current.toggleGroup('finance');
    });

    expect(result.current.isGroupOpen('finance')).toBe(false);
    expect(result.current.isGroupOpen('overview')).toBe(true);
  });
});
