import { useRef, useState, type ChangeEvent, type FormEvent } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { restaurantCategoriesApi, type RestaurantCategoryPayload } from '../../api/resources';
import { API_URL } from '../../api/client';
import { PageHeader, Loading, ErrorBanner, EmptyState } from '../../components/ui';
import {
  RESTAURANT_CATEGORY_ICONS,
  type RestaurantCategory,
  type RestaurantCategoryIcon,
} from '../../api/types';

// Mirrors PhotoUploader::MAX_SIZE_BYTES on the backend.
const MAX_UPLOAD_BYTES = 5 * 1024 * 1024;

/** What each icon draws in the app, for the picker. */
const ICON_LABEL: Record<RestaurantCategoryIcon, string> = {
  restaurant: 'Fork and knife',
  fast_food: 'Burger and drink',
  burger: 'Burger',
  pizza: 'Pizza slice',
  kebab: 'Kebab skewer',
  grill: 'Grill',
  bowl: 'Bowl',
  soup: 'Soup pot',
  pasta: 'Noodles',
  fish: 'Fish plate',
  tapas: 'Snacks',
  croissant: 'Croissant',
  breakfast: 'Toast',
  leaf: 'Leaf',
  cake: 'Cake',
  ice_cream: 'Ice cream',
  coffee: 'Coffee cup',
  drink: 'Glass',
  basket: 'Shopping basket',
};

const EMPTY_FORM: RestaurantCategoryPayload = { name: '', icon: 'restaurant', position: 0 };

/**
 * What restaurants are browsed by in the app: the row of categories under
 * the search bar ("Pizza", "Sucré", "Cuisine Tunisienne"...), in `position`
 * order. A category shows there once an open restaurant has it; which
 * restaurant has which is set on the restaurant's own page.
 */
export default function RestaurantCategoriesPage() {
  const queryClient = useQueryClient();
  const [creating, setCreating] = useState(false);
  const [newCategory, setNewCategory] = useState<RestaurantCategoryPayload>(EMPTY_FORM);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [editing, setEditing] = useState<RestaurantCategoryPayload>(EMPTY_FORM);

  const categories = useQuery({
    queryKey: ['restaurant-categories'],
    queryFn: restaurantCategoriesApi.list,
  });
  const refresh = () => {
    queryClient.invalidateQueries({ queryKey: ['restaurant-categories'] });
    // Restaurants carry their categories' names.
    queryClient.invalidateQueries({ queryKey: ['restaurants'] });
  };

  const create = useMutation({
    mutationFn: () => restaurantCategoriesApi.create({ ...newCategory, name: newCategory.name.trim() }),
    onSuccess: () => {
      setNewCategory(EMPTY_FORM);
      setCreating(false);
      refresh();
    },
  });

  const update = useMutation({
    mutationFn: ({ id, data }: { id: number; data: RestaurantCategoryPayload }) =>
      restaurantCategoriesApi.update(id, data),
    onSuccess: () => {
      setEditingId(null);
      refresh();
    },
  });

  const remove = useMutation({
    mutationFn: (id: number) => restaurantCategoriesApi.delete(id),
    onSuccess: refresh,
  });

  function openCreate() {
    const last = categories.data?.reduce((max, c) => Math.max(max, c.position), 0) ?? 0;
    setNewCategory({ ...EMPTY_FORM, position: last + 1 });
    setCreating((c) => !c);
  }

  function handleCreate(e: FormEvent) {
    e.preventDefault();
    create.mutate();
  }

  function startEdit(category: RestaurantCategory) {
    setEditingId(category.id);
    setEditing({ name: category.name, icon: category.icon, position: category.position });
  }

  function handleUpdate(e: FormEvent, id: number) {
    e.preventDefault();
    update.mutate({ id, data: { ...editing, name: editing.name.trim() } });
  }

  function handleDelete(category: RestaurantCategory) {
    const used = category.restaurantCount ?? 0;
    const warning =
      used > 0
        ? `\n\n${used} restaurant${used === 1 ? ' has' : 's have'} it: ${used === 1 ? 'it stays' : 'they stay'}, without this category.`
        : '';
    if (window.confirm(`Delete the category "${category.name}"?${warning}`)) {
      remove.mutate(category.id);
    }
  }

  const total = categories.data?.length ?? 0;

  return (
    <>
      <PageHeader
        title="Restaurant Categories"
        subtitle={`${total} ${total === 1 ? 'category' : 'categories'} to browse restaurants by in the app`}
        actions={
          <button type="button" className="btn" onClick={openCreate}>
            {creating ? 'Cancel' : '+ New category'}
          </button>
        }
      />
      <div className="content">
        {creating && (
          <div className="form-card" style={{ marginBottom: 20 }}>
            <ErrorBanner error={create.error} />
            <form onSubmit={handleCreate} style={{ display: 'flex', gap: 10, alignItems: 'flex-end' }}>
              <CategoryFields value={newCategory} onChange={setNewCategory} idPrefix="new" />
              <button type="submit" className="btn" disabled={create.isPending}>
                Add
              </button>
            </form>
            <p className="rmeta" style={{ marginTop: 10 }}>
              Then tick it on each restaurant's page. Upload an image from the list to replace the
              icon.
            </p>
          </div>
        )}

        <ErrorBanner error={categories.error || update.error || remove.error} />

        {categories.isLoading ? (
          <Loading />
        ) : !categories.data || categories.data.length === 0 ? (
          <EmptyState>No restaurant categories yet.</EmptyState>
        ) : (
          <div className="card">
            <table>
              <thead>
                <tr>
                  <th>Image</th>
                  <th>Category</th>
                  <th>Icon</th>
                  <th>Order</th>
                  <th>Restaurants</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {categories.data.map((c) => (
                  <tr key={c.id}>
                    <td>
                      <ImageCell category={c} onChanged={refresh} />
                    </td>
                    {editingId === c.id ? (
                      <td colSpan={5}>
                        <form
                          onSubmit={(e) => handleUpdate(e, c.id)}
                          style={{ display: 'flex', gap: 8, alignItems: 'flex-end' }}
                        >
                          <CategoryFields value={editing} onChange={setEditing} idPrefix={`edit-${c.id}`} />
                          <button type="submit" className="btn sm" disabled={update.isPending}>
                            Save
                          </button>
                          <button type="button" className="btn ghost sm" onClick={() => setEditingId(null)}>
                            Cancel
                          </button>
                        </form>
                      </td>
                    ) : (
                      <>
                        <td className="rname">{c.name}</td>
                        <td>{c.imageUrl ? <span className="rmeta">Replaced by the image</span> : ICON_LABEL[c.icon]}</td>
                        <td>{c.position}</td>
                        <td>
                          {(c.restaurantCount ?? 0) > 0 ? (
                            <span className="badge">{c.restaurantCount}</span>
                          ) : (
                            <span className="badge muted">None yet</span>
                          )}
                        </td>
                        <td style={{ whiteSpace: 'nowrap' }}>
                          <button type="button" className="btn ghost sm" onClick={() => startEdit(c)}>
                            Edit
                          </button>{' '}
                          <button
                            type="button"
                            className="btn ghost sm danger-text"
                            disabled={remove.isPending}
                            onClick={() => handleDelete(c)}
                          >
                            Delete
                          </button>
                        </td>
                      </>
                    )}
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

function CategoryFields({
  value,
  onChange,
  idPrefix,
}: {
  value: RestaurantCategoryPayload;
  onChange: (value: RestaurantCategoryPayload) => void;
  idPrefix: string;
}) {
  return (
    <>
      <div className="field-group" style={{ flex: 1, marginBottom: 0 }}>
        <label className="field-label" htmlFor={`${idPrefix}-name`}>
          Name
        </label>
        <input
          id={`${idPrefix}-name`}
          className="field-input"
          value={value.name}
          onChange={(e) => onChange({ ...value, name: e.target.value })}
          placeholder="e.g. Pizza"
          maxLength={100}
          required
        />
      </div>
      <div className="field-group" style={{ width: 190, marginBottom: 0 }}>
        <label className="field-label" htmlFor={`${idPrefix}-icon`}>
          Icon
        </label>
        <select
          id={`${idPrefix}-icon`}
          className="field-input"
          value={value.icon}
          onChange={(e) => onChange({ ...value, icon: e.target.value as RestaurantCategoryIcon })}
        >
          {RESTAURANT_CATEGORY_ICONS.map((icon) => (
            <option key={icon} value={icon}>
              {ICON_LABEL[icon]}
            </option>
          ))}
        </select>
      </div>
      <div className="field-group" style={{ width: 90, marginBottom: 0 }}>
        <label className="field-label" htmlFor={`${idPrefix}-position`}>
          Order
        </label>
        <input
          id={`${idPrefix}-position`}
          className="field-input"
          type="number"
          min={0}
          max={1000}
          value={value.position}
          onChange={(e) => onChange({ ...value, position: Number(e.target.value) })}
          required
        />
      </div>
    </>
  );
}

/** The category's image, with its own upload/replace/remove buttons. */
function ImageCell({ category, onChanged }: { category: RestaurantCategory; onChanged: () => void }) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [sizeError, setSizeError] = useState<string | null>(null);

  const upload = useMutation({
    mutationFn: (file: File) => restaurantCategoriesApi.uploadImage(category.id, file),
    onSuccess: onChanged,
  });
  const remove = useMutation({
    mutationFn: () => restaurantCategoriesApi.removeImage(category.id),
    onSuccess: onChanged,
  });

  function handleFile(e: ChangeEvent<HTMLInputElement>) {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file) return;
    if (file.size > MAX_UPLOAD_BYTES) {
      setSizeError('Image must be smaller than 5 MB.');
      return;
    }
    setSizeError(null);
    upload.mutate(file);
  }

  const error = sizeError ?? (upload.error ?? remove.error)?.message;

  return (
    <div style={{ display: 'flex', alignItems: 'center', gap: 10 }}>
      <div className="logo-box">
        {category.imageUrl ? (
          <img src={`${API_URL}${category.imageUrl}`} alt={`${category.name} image`} style={{ objectFit: 'cover', padding: 0 }} />
        ) : (
          <span className="placeholder">Icon</span>
        )}
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
        <input
          ref={inputRef}
          type="file"
          accept="image/jpeg,image/png,image/webp"
          aria-label={`Image for ${category.name}`}
          style={{ display: 'none' }}
          onChange={handleFile}
        />
        <button
          type="button"
          className="btn ghost sm"
          disabled={upload.isPending}
          onClick={() => inputRef.current?.click()}
        >
          {upload.isPending ? 'Uploading…' : category.imageUrl ? 'Replace' : 'Upload image'}
        </button>
        {category.imageUrl && (
          <button
            type="button"
            className="btn ghost sm"
            disabled={remove.isPending}
            onClick={() => remove.mutate()}
          >
            Remove
          </button>
        )}
        {error && <span className="field-error">{error}</span>}
      </div>
    </div>
  );
}
