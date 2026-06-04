import { useState, useMemo } from 'react';
import { useTranslation } from 'react-i18next';
import { toast } from 'sonner';
import {
  Plus,
  Pencil,
  Trash2,
  Tag,
  TrendingUp,
  TrendingDown,
} from 'lucide-react';
import { Button } from '../components/ui/button';
import {
  Sheet,
  SheetContent,
  SheetHeader,
  SheetTitle,
  SheetDescription,
} from '../components/ui/sheet';
import {
  Table,
  TableBody,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from '../components/ui/table';
import { Input } from '../components/ui/input';
import { Label } from '../components/ui/label';
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from '../components/ui/select';
import { getUserFriendlyError } from '../lib/error-handler';
import {
  useCategories,
  useCreateCategory,
  useUpdateCategory,
  useDeleteCategory,
} from '../hooks/useCategory';
import type { CategoryDto, CreateCategoryDto, UpdateCategoryDto } from '../lib/tauri/category';

type FilterTab = 'all' | 'income' | 'expense';

export function CategoriesPage() {
  const { t } = useTranslation();

  const [showSheet, setShowSheet] = useState(false);
  const [editingCategory, setEditingCategory] = useState<CategoryDto | null>(null);
  const [filterTab, setFilterTab] = useState<FilterTab>('all');
  const [deleteConfirmId, setDeleteConfirmId] = useState<string | null>(null);

  // Form state
  const [formName, setFormName] = useState('');
  const [formType, setFormType] = useState<'income' | 'expense'>('expense');
  const [formIcon, setFormIcon] = useState('💰');
  const [formColor, setFormColor] = useState('#10B981');

  const { data: categories = [], isLoading } = useCategories();

  const createMutation = useCreateCategory();
  const updateMutation = useUpdateCategory();
  const deleteMutation = useDeleteCategory();

  const incomeCategories = useMemo(
    () => categories.filter((c) => c.categoryType === 'income'),
    [categories],
  );
  const expenseCategories = useMemo(
    () => categories.filter((c) => c.categoryType === 'expense'),
    [categories],
  );

  const filteredCategories = useMemo(() => {
    switch (filterTab) {
      case 'income':
        return incomeCategories;
      case 'expense':
        return expenseCategories;
      default:
        return categories;
    }
  }, [filterTab, incomeCategories, expenseCategories, categories]);

  function resetForm() {
    setFormName('');
    setFormType('expense');
    setFormIcon('💰');
    setFormColor('#10B981');
  }

  function handleNew() {
    resetForm();
    setEditingCategory(null);
    setShowSheet(true);
  }

  function handleEdit(category: CategoryDto) {
    setEditingCategory(category);
    setFormName(category.name);
    setFormType(category.categoryType);
    setFormIcon(category.icon);
    setFormColor(category.color);
    setShowSheet(true);
  }

  function handleFormSubmit() {
    if (!formName.trim()) {
      toast.error(t('category.nameRequired'));
      return;
    }

    if (editingCategory) {
      const dto: UpdateCategoryDto = {
        name: formName.trim(),
        icon: formIcon,
        color: formColor,
      };
      updateMutation.mutate(
        { id: editingCategory.id, dto },
        {
          onSuccess: () => {
            setShowSheet(false);
            setEditingCategory(null);
            resetForm();
            toast.success(t('category.editCategory'));
          },
          onError: (error) => toast.error(getUserFriendlyError(error)),
        },
      );
    } else {
      const dto: CreateCategoryDto = {
        name: formName.trim(),
        categoryType: formType,
        icon: formIcon,
        color: formColor,
      };
      createMutation.mutate(dto, {
        onSuccess: () => {
          setShowSheet(false);
          resetForm();
          toast.success(t('category.addCategory'));
        },
        onError: (error) => toast.error(getUserFriendlyError(error)),
      });
    }
  }

  if (isLoading) {
    return (
      <div className="p-6 text-center text-muted-foreground">
        {t('common.loading')}
      </div>
    );
  }

  return (
    <div className="p-4 sm:p-6">
      {/* Header */}
      <div className="flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between mb-4 sm:mb-6">
        <h1 className="text-2xl font-bold sm:text-3xl">{t('category.title')}</h1>
        <Button variant="default-gradient" onClick={handleNew}>
          <Plus className="h-4 w-4 mr-1" />
          {t('category.addCategory')}
        </Button>
      </div>

      {categories.length === 0 ? (
        <div className="flex flex-col items-center justify-center py-12 text-center">
          <Tag className="h-12 w-12 text-muted-foreground/40 mb-4" />
          <p className="text-neutral-500 mb-4">{t('category.noCategories')}</p>
          <Button onClick={handleNew}>{t('category.addCategory')}</Button>
        </div>
      ) : (
        <>
          {/* Summary cards */}
          <div className="grid grid-cols-2 gap-4 mb-6">
            <div className="rounded-lg border p-4">
              <div className="flex items-center gap-2 text-xs text-muted-foreground">
                <TrendingUp className="h-3.5 w-3.5" />
                {t('category.incomeCategories')}
              </div>
              <div className="text-xl font-bold text-emerald-600">{incomeCategories.length}</div>
            </div>
            <div className="rounded-lg border p-4">
              <div className="flex items-center gap-2 text-xs text-muted-foreground">
                <TrendingDown className="h-3.5 w-3.5" />
                {t('category.expenseCategories')}
              </div>
              <div className="text-xl font-bold text-orange-600">{expenseCategories.length}</div>
            </div>
          </div>

          {/* Filter tabs */}
          <div className="flex items-center gap-1 mb-4">
            <Button
              variant={filterTab === 'all' ? 'default' : 'outline'}
              size="sm"
              className="h-7 text-xs"
              onClick={() => setFilterTab('all')}
            >
              {t('common.all')}
            </Button>
            <Button
              variant={filterTab === 'income' ? 'default' : 'outline'}
              size="sm"
              className="h-7 text-xs"
              onClick={() => setFilterTab('income')}
            >
              {t('category.income')}
            </Button>
            <Button
              variant={filterTab === 'expense' ? 'default' : 'outline'}
              size="sm"
              className="h-7 text-xs"
              onClick={() => setFilterTab('expense')}
            >
              {t('category.expense')}
            </Button>
          </div>

          {/* Table */}
          <div className="border rounded-lg">
            <Table>
              <TableHeader>
                <TableRow>
                  <TableHead>{t('category.name')}</TableHead>
                  <TableHead>{t('category.type')}</TableHead>
                  <TableHead>{t('category.icon')}</TableHead>
                  <TableHead>{t('category.color')}</TableHead>
                  <TableHead className="text-right">{t('common.actions')}</TableHead>
                </TableRow>
              </TableHeader>
              <TableBody>
                {filteredCategories.length === 0 ? (
                  <TableRow>
                    <TableCell
                      colSpan={5}
                      className="text-center py-8 text-muted-foreground text-xs"
                    >
                      {t('common.noResults')}
                    </TableCell>
                  </TableRow>
                ) : (
                  filteredCategories.map((category) => (
                    <TableRow key={category.id}>
                      <TableCell className="font-medium">{category.name}</TableCell>
                      <TableCell>
                        <span
                          className={`inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${
                            category.categoryType === 'income'
                              ? 'bg-emerald-100 text-emerald-700'
                              : 'bg-orange-100 text-orange-700'
                          }`}
                        >
                          {category.categoryType === 'income'
                            ? t('category.income')
                            : t('category.expense')}
                        </span>
                      </TableCell>
                      <TableCell>
                        <span className="text-lg">{category.icon}</span>
                      </TableCell>
                      <TableCell>
                        <div className="flex items-center gap-2">
                          <div
                            className="w-4 h-4 rounded-full border"
                            style={{ backgroundColor: category.color }}
                          />
                          <span className="text-xs text-muted-foreground">{category.color}</span>
                        </div>
                      </TableCell>
                      <TableCell className="text-right">
                        {deleteConfirmId === category.id ? (
                          <div className="flex justify-end items-center gap-1">
                            <span className="text-xs text-red-600 mr-1">
                              {t('common.confirmDelete')}
                            </span>
                            <Button
                              variant="ghost"
                              size="sm"
                              className="h-6 text-xs text-red-600"
                              onClick={() =>
                                deleteMutation.mutate(category.id, {
                                  onSuccess: () => {
                                    setDeleteConfirmId(null);
                                    toast.success(t('category.deleteCategory'));
                                  },
                                  onError: (error) => toast.error(getUserFriendlyError(error)),
                                })
                              }
                              disabled={deleteMutation.isPending}
                            >
                              {t('common.confirm')}
                            </Button>
                            <Button
                              variant="ghost"
                              size="sm"
                              className="h-6 text-xs"
                              onClick={() => setDeleteConfirmId(null)}
                            >
                              {t('common.cancel')}
                            </Button>
                          </div>
                        ) : (
                          <div className="flex justify-end gap-1">
                            {!category.isSystem && (
                              <>
                                <Button
                                  variant="ghost"
                                  size="sm"
                                  className="h-7 text-xs"
                                  onClick={() => handleEdit(category)}
                                >
                                  <Pencil className="h-3 w-3 mr-1" />
                                  {t('common.edit')}
                                </Button>
                                <Button
                                  variant="ghost"
                                  size="sm"
                                  className="h-7 text-xs text-red-600 hover:text-red-700 hover:bg-red-50"
                                  onClick={() => setDeleteConfirmId(category.id)}
                                >
                                  <Trash2 className="h-3 w-3 mr-1" />
                                  {t('common.delete')}
                                </Button>
                              </>
                            )}
                          </div>
                        )}
                      </TableCell>
                    </TableRow>
                  ))
                )}
              </TableBody>
            </Table>
          </div>
        </>
      )}

      {/* Create/Edit Sheet */}
      <Sheet open={showSheet} onOpenChange={setShowSheet}>
        <SheetContent side="right" className="w-full sm:max-w-lg">
          <SheetHeader>
            <SheetTitle>
              {editingCategory ? t('category.editCategory') : t('category.addCategory')}
            </SheetTitle>
            <SheetDescription>
              {editingCategory ? t('category.editCategory') : t('category.addCategory')}
            </SheetDescription>
          </SheetHeader>
          <div className="flex-1 overflow-y-auto -mx-4 px-4 py-4 space-y-4">
            {/* Name */}
            <div className="space-y-2">
              <Label>{t('category.name')}</Label>
              <Input
                value={formName}
                onChange={(e) => setFormName(e.target.value)}
                placeholder={t('category.name')}
              />
            </div>

            {/* Type (only when creating) */}
            {!editingCategory && (
              <div className="space-y-2">
                <Label>{t('category.type')}</Label>
                <Select
                  value={formType}
                  onValueChange={(v) => setFormType(v as 'income' | 'expense')}
                >
                  <SelectTrigger>
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent>
                    <SelectItem value="income">{t('category.income')}</SelectItem>
                    <SelectItem value="expense">{t('category.expense')}</SelectItem>
                  </SelectContent>
                </Select>
              </div>
            )}

            {/* Icon */}
            <div className="space-y-2">
              <Label>{t('category.icon')}</Label>
              <Input
                value={formIcon}
                onChange={(e) => setFormIcon(e.target.value)}
                placeholder="💰"
              />
            </div>

            {/* Color */}
            <div className="space-y-2">
              <Label>{t('category.color')}</Label>
              <div className="flex items-center gap-2">
                <input
                  type="color"
                  value={formColor}
                  onChange={(e) => setFormColor(e.target.value)}
                  className="h-9 w-9 rounded cursor-pointer"
                />
                <Input
                  value={formColor}
                  onChange={(e) => setFormColor(e.target.value)}
                  placeholder="#10B981"
                  className="flex-1"
                />
              </div>
            </div>

            {/* Actions */}
            <div className="flex gap-2 pt-4">
              <Button
                className="flex-1"
                onClick={handleFormSubmit}
                disabled={createMutation.isPending || updateMutation.isPending}
              >
                {createMutation.isPending || updateMutation.isPending
                  ? t('common.saving')
                  : editingCategory
                    ? t('common.save')
                    : t('common.create')}
              </Button>
              <Button
                variant="outline"
                onClick={() => {
                  setShowSheet(false);
                  setEditingCategory(null);
                  resetForm();
                }}
              >
                {t('common.cancel')}
              </Button>
            </div>
          </div>
        </SheetContent>
      </Sheet>
    </div>
  );
}
