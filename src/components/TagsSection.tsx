import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { Pencil, Trash2, Plus, Check, X } from 'lucide-react';
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from './ui/card';
import { Button } from './ui/button';
import { Input } from './ui/input';
import {
  useTags,
  useCreateTag,
  useUpdateTag,
  useSoftDeleteTag,
} from '@/hooks/useTag';

const PRESET_COLORS = [
  '#EF4444', '#F97316', '#F59E0B', '#84CC16', '#22C55E',
  '#14B8A6', '#06B6D4', '#3B82F6', '#6366F1', '#8B5CF6',
  '#A855F7', '#EC4899', '#6B7280', '#78716C', '#1E293B',
];

export function TagsSection() {
  const { t } = useTranslation();
  const { data: tags = [], isLoading } = useTags();
  const createTagMutation = useCreateTag();
  const updateTagMutation = useUpdateTag();
  const softDeleteMutation = useSoftDeleteTag();

  const [newTagName, setNewTagName] = useState('');
  const [newTagColor, setNewTagColor] = useState('#6B7280');
  const [editingId, setEditingId] = useState<string | null>(null);
  const [editName, setEditName] = useState('');
  const [editColor, setEditColor] = useState('');
  const [deleteConfirmId, setDeleteConfirmId] = useState<string | null>(null);

  const handleCreate = () => {
    if (!newTagName.trim()) return;
    createTagMutation.mutate(
      { name: newTagName.trim(), color: newTagColor },
      {
        onSuccess: () => {
          setNewTagName('');
          setNewTagColor('#6B7280');
        },
      },
    );
  };

  const handleStartEdit = (tag: { id: string; name: string; color: string }) => {
    setEditingId(tag.id);
    setEditName(tag.name);
    setEditColor(tag.color);
    setDeleteConfirmId(null);
  };

  const handleSaveEdit = () => {
    if (!editingId || !editName.trim()) return;
    updateTagMutation.mutate(
      { id: editingId, name: editName.trim(), color: editColor },
      { onSuccess: () => setEditingId(null) },
    );
  };

  const handleCancelEdit = () => {
    setEditingId(null);
    setEditName('');
    setEditColor('');
  };

  const handleDelete = (id: string) => {
    softDeleteMutation.mutate(id, { onSuccess: () => setDeleteConfirmId(null) });
  };

  return (
    <Card className="mb-6">
      <CardHeader>
        <CardTitle>{t('tags.title')}</CardTitle>
        <CardDescription>{t('tags.managementDesc')}</CardDescription>
      </CardHeader>
      <CardContent className="space-y-4">
        {isLoading ? (
          <div className="flex items-center justify-center py-8">
            <span className="text-muted-foreground">{t('common.loading')}</span>
          </div>
        ) : tags.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-8 text-center">
            <p className="text-muted-foreground mb-2">{t('tags.noTags')}</p>
            <p className="text-sm text-muted-foreground">{t('tags.createFirstTag')}</p>
          </div>
        ) : (
          <div className="space-y-2">
            {tags.map((tag) => (
              <div key={tag.id} className="flex items-center gap-3 p-2 rounded-lg border">
                {editingId === tag.id ? (
                  <>
                    <div className="flex gap-1 flex-shrink-0">
                      {PRESET_COLORS.map((c) => (
                        <button
                          key={c}
                          type="button"
                          className="w-4 h-4 rounded-full border-2 flex-shrink-0"
                          style={{
                            backgroundColor: c,
                            borderColor: editColor === c ? 'var(--foreground)' : 'transparent',
                          }}
                          onClick={() => setEditColor(c)}
                        />
                      ))}
                    </div>
                    <Input
                      value={editName}
                      onChange={(e) => setEditName(e.target.value)}
                      className="h-8 text-sm"
                      onKeyDown={(e) => {
                        if (e.key === 'Enter') handleSaveEdit();
                        if (e.key === 'Escape') handleCancelEdit();
                      }}
                      autoFocus
                    />
                    <Button variant="ghost" size="icon" className="h-8 w-8 flex-shrink-0" onClick={handleSaveEdit}>
                      <Check className="h-4 w-4 text-green-600" />
                    </Button>
                    <Button variant="ghost" size="icon" className="h-8 w-8 flex-shrink-0" onClick={handleCancelEdit}>
                      <X className="h-4 w-4" />
                    </Button>
                  </>
                ) : (
                  <>
                    <span
                      className="w-5 h-5 rounded-full flex-shrink-0 border"
                      style={{ backgroundColor: tag.color }}
                    />
                    <span className="flex-1 text-sm font-medium">{tag.name}</span>
                    <Button
                      variant="ghost"
                      size="icon"
                      className="h-8 w-8 flex-shrink-0"
                      onClick={() => handleStartEdit(tag)}
                    >
                      <Pencil className="h-4 w-4" />
                    </Button>
                    {deleteConfirmId === tag.id ? (
                      <div className="flex gap-1 flex-shrink-0">
                        <Button
                          variant="destructive"
                          size="sm"
                          className="h-8 text-xs"
                          onClick={() => handleDelete(tag.id)}
                          disabled={softDeleteMutation.isPending}
                        >
                          {t('common.confirm')}
                        </Button>
                        <Button
                          variant="outline"
                          size="sm"
                          className="h-8 text-xs"
                          onClick={() => setDeleteConfirmId(null)}
                        >
                          {t('common.cancel')}
                        </Button>
                      </div>
                    ) : (
                      <Button
                        variant="ghost"
                        size="icon"
                        className="h-8 w-8 flex-shrink-0"
                        onClick={() => setDeleteConfirmId(tag.id)}
                      >
                        <Trash2 className="h-4 w-4 text-destructive" />
                      </Button>
                    )}
                  </>
                )}
              </div>
            ))}
          </div>
        )}

        {/* Create new tag form */}
        <div className="pt-4 border-t">
          <p className="text-sm font-medium mb-2">{t('tags.createTag')}</p>
          <div className="flex items-center gap-3">
            <div className="flex gap-1 flex-shrink-0">
              {PRESET_COLORS.map((c) => (
                <button
                  key={c}
                  type="button"
                  className="w-4 h-4 rounded-full border-2 flex-shrink-0"
                  style={{
                    backgroundColor: c,
                    borderColor: newTagColor === c ? 'var(--foreground)' : 'transparent',
                  }}
                  onClick={() => setNewTagColor(c)}
                />
              ))}
            </div>
            <Input
              value={newTagName}
              onChange={(e) => setNewTagName(e.target.value)}
              placeholder={t('tags.tagNamePlaceholder')}
              className="h-8 text-sm"
              onKeyDown={(e) => {
                if (e.key === 'Enter') handleCreate();
              }}
            />
            <Button
              size="sm"
              className="h-8 gap-1 flex-shrink-0"
              onClick={handleCreate}
              disabled={!newTagName.trim() || createTagMutation.isPending}
            >
              <Plus className="h-4 w-4" />
              {t('common.create')}
            </Button>
          </div>
        </div>
      </CardContent>
    </Card>
  );
}
