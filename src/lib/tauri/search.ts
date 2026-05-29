import { invokeTauri } from '../tauri';

export interface SearchResultDto {
  result_type: string;
  id: string;
  title: string;
  subtitle: string;
}

export const globalSearch = (query: string) =>
  invokeTauri<SearchResultDto[]>('global_search', { query });
