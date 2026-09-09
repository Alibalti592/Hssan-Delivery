import { useState, type FormEvent } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useParams } from 'react-router-dom';
import { categoriesApi, restaurantsApi } from '../../api/resources';
import { PageHeader, Loading, ErrorBanner, EmptyState, Breadcrumb } from '../../components/ui';
import type { Category } from '../../api/types';

export default function CategoriesPage() {
  const { id } = useParams();
  const restaurantId = Number(id);
  const queryClient = useQueryClient();
  const [newName, setNewName] = useState('');
  const [editingId, setEditingId] = useState<number | null>(null);
  const [editingName, setEditingName] = useState('');

  const restaurant = useQuery({
    queryKey: ['restaurants', restaurantId],
    queryFn: () => restaurantsApi.get(restaurantId),
  });

  const categories = useQuery({
    queryKey: ['categories', restaurantId],
    queryFn: () => categoriesApi.listForRestaurant(restaurantId),
  });

  const create = useMutation({
    mutationFn: (name: string) => categoriesApi.create(restaurantId, { name }),
    onSuccess: () => {
      setNewName('');
      queryClient.invalidateQueries({ queryKey: ['categories', restaurantId] });
    },
  });

  const update = useMutation({
    mutationFn: ({ categoryId, name }: { categoryId: number; name: string }) =>
      categoriesApi.update(categoryId, { name }),
    onSuccess: () => {
      setEditingId(null);
      queryClient.invalidateQueries({ queryKey: ['categories', restaurantId] });
    },
  });

  function handleCreate(e: FormEvent) {
    e.preventDefault();
    if (newName.trim()) create.mutate(newName.trim());
  }

  function startEdit(category: Category) {
    setEditingId(category.id);
    setEditingName(category.name);
  }

  function handleUpdate(e: FormEvent, categoryId: number) {
    e.preventDefault();
    if (editingName.trim()) update.mutate({ categoryId, name: editingName.trim() });
  }

  return (
    <>
      <PageHeader
        title="Categories"
        subtitle={restaurant.data ? `Restaurant: ${restaurant.data.name}` : undefined}
      />
      <div className="content">
        <Breadcrumb
          items={[
            { label: 'Restaurants', to: '/restaurants' },
            { label: restaurant.data?.name ?? '…', to: `/restaurants/${restaurantId}` },
            { label: 'Categories' },
          ]}
        />

        <div className="form-card" style={{ marginBottom: 20 }}>
          <form onSubmit={handleCreate} style={{ display: 'flex', gap: 10, alignItems: 'flex-end' }}>
            <div className="field-group" style={{ flex: 1, marginBottom: 0 }}>
              <label className="field-label" htmlFor="newCategoryName">
                New category
              </label>
              <input
                id="newCategoryName"
                className="field-input"
                value={newName}
                onChange={(e) => setNewName(e.target.value)}
                placeholder="e.g. Plats"
              />
            </div>
            <button type="submit" className="btn" disabled={create.isPending}>
              Add
            </button>
          </form>
        </div>

        <ErrorBanner error={categories.error || create.error || update.error} />

        {categories.isLoading ? (
          <Loading />
        ) : !categories.data || categories.data.length === 0 ? (
          <EmptyState>No categories yet.</EmptyState>
        ) : (
          <div className="card">
            <table>
              <thead>
                <tr>
                  <th>Name</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {categories.data.map((c) => (
                  <tr key={c.id}>
                    <td>
                      {editingId === c.id ? (
                        <form
                          onSubmit={(e) => handleUpdate(e, c.id)}
                          style={{ display: 'flex', gap: 8 }}
                        >
                          <input
                            className="field-input"
                            value={editingName}
                            onChange={(e) => setEditingName(e.target.value)}
                            autoFocus
                          />
                          <button type="submit" className="btn sm" disabled={update.isPending}>
                            Save
                          </button>
                          <button
                            type="button"
                            className="btn ghost sm"
                            onClick={() => setEditingId(null)}
                          >
                            Cancel
                          </button>
                        </form>
                      ) : (
                        <span className="rname">{c.name}</span>
                      )}
                    </td>
                    <td>
                      {editingId !== c.id && (
                        <button type="button" className="btn ghost sm" onClick={() => startEdit(c)}>
                          Rename
                        </button>
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </>
  );
}
