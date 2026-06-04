import { invokeTauri } from '../tauri';

export interface CategoryDto {
  id: string;
  name: string;
  categoryType: 'income' | 'expense';
  icon: string;
  color: string;
  parentId: string | null;
  isSystem: boolean;
  sortOrder: number;
}

export interface CreateCategoryDto {
  name: string;
  categoryType: 'income' | 'expense';
  icon: string;
  color: string;
  parentId?: string | null;
}

export interface UpdateCategoryDto {
  name?: string;
  icon?: string;
  color?: string;
  parentId?: string | null;
  sortOrder?: number;
}

export const listCategories = (type?: 'income' | 'expense') =>
  invokeTauri<CategoryDto[]>('list_categories', { categoryType: type });

export const createCategory = (dto: CreateCategoryDto) =>
  invokeTauri<CategoryDto>('create_category', { dto });

export const updateCategory = (id: string, dto: UpdateCategoryDto) =>
  invokeTauri<CategoryDto>('update_category', { id, dto });

export const deleteCategory = (id: string) =>
  invokeTauri<void>('delete_category', { id });
