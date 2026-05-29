import { invokeTauri } from '../tauri';

export interface TagDto {
  id: string;
  name: string;
  color: string;
}

export interface CreateTagDto {
  name: string;
  color: string;
}

export const listTags = () => invokeTauri<TagDto[]>('list_tags');
export const createTag = (dto: CreateTagDto) => invokeTauri<TagDto>('create_tag', { dto });
export const deleteTag = (id: string) => invokeTauri<void>('delete_tag', { id });
export const addTagToTransaction = (transactionId: string, tagId: string) =>
  invokeTauri<void>('add_tag_to_transaction', { transactionId, tagId });
export const removeTagFromTransaction = (transactionId: string, tagId: string) =>
  invokeTauri<void>('remove_tag_from_transaction', { transactionId, tagId });
export const getTransactionTags = (transactionId: string) =>
  invokeTauri<TagDto[]>('get_transaction_tags', { transactionId });
