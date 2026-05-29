import { invokeTauri } from '../tauri';

export interface GoalDto {
  id: string;
  name: string;
  goal_type: string;
  target_amount: string;
  current_amount: string;
  progress_percentage: number;
  remaining_amount: string;
  currency_code: string;
  deadline: string | null;
  linked_account_id: string | null;
  notes: string | null;
  is_completed: boolean;
  is_overdue: boolean;
  completed_at: string | null;
}

export interface CreateGoalDto {
  name: string;
  goal_type: string;
  target_amount: string;
  currency_code: string;
  deadline?: string;
  linked_account_id?: string;
  notes?: string;
}

export interface UpdateGoalDto {
  name?: string;
  goal_type?: string;
  target_amount?: string;
  currency_code?: string;
  deadline?: string;
  linked_account_id?: string;
  notes?: string;
}

export const listGoals = () => invokeTauri<GoalDto[]>('list_goals');
export const getGoal = (id: string) =>
  invokeTauri<GoalDto | null>('get_goal', { id });
export const createGoal = (dto: CreateGoalDto) =>
  invokeTauri<GoalDto>('create_goal', { dto });
export const updateGoal = (id: string, dto: UpdateGoalDto) =>
  invokeTauri<GoalDto>('update_goal', { id, dto });
export const updateGoalProgress = (id: string, amount: string) =>
  invokeTauri<GoalDto>('update_goal_progress', { id, amount });
export const completeGoal = (id: string) =>
  invokeTauri<GoalDto>('complete_goal', { id });
export const deleteGoal = (id: string) =>
  invokeTauri<void>('delete_goal', { id });
