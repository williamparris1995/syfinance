import { invokeTauri } from '../tauri';

export interface SearchResultDto {
  result_type: string;
  id: string;
  title: string;
  subtitle: string;
  rank: number;
}

export const globalSearch = (query: string) =>
  invokeTauri<SearchResultDto[]>('global_search', { query });

export const rebuildSearchIndex = () =>
  invokeTauri<void>('rebuild_search_index');
