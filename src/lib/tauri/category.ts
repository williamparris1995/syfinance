import { invokeTauri } from '../tauri';

export type CategoryType = 'Income' | 'Expense';

export interface CreateCategoryDto {
  name: string;
  icon: string;
  color: string;
  category_type: CategoryType;
  chart_code: string;
  parent_id?: string;
}

export interface UpdateCategoryDto {
  name?: string;
  icon?: string;
  color?: string;
  parent_id?: string;
}

export interface CategoryDto {
  id: string;
  name: string;
  icon: string;
  color: string;
  category_type: CategoryType;
  chart_code: string;
  parent_id?: string;
  created_at: string;
  updated_at: string;
  deleted_at?: string;
}

export const createCategory = (dto: CreateCategoryDto) =>
  invokeTauri<CategoryDto>('create_category', { dto });

export const updateCategory = (id: string, dto: UpdateCategoryDto) =>
  invokeTauri<CategoryDto>('update_category', { id, dto });

export const deleteCategory = (id: string) => invokeTauri<void>('delete_category', { id });

export const getCategory = (id: string) => invokeTauri<CategoryDto>('get_category', { id });

export const listCategories = () => invokeTauri<CategoryDto[]>('list_categories');

export const listCategoriesByType = (categoryType: CategoryType) =>
  invokeTauri<CategoryDto[]>('list_categories_by_type', { categoryType });
