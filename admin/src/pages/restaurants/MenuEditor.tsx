import { forwardRef, useEffect, useImperativeHandle, useRef, useState, type FormEvent } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { API_URL } from '../../api/client';
import { categoriesApi, productsApi } from '../../api/resources';
import type { Category, Product } from '../../api/types';
import { ErrorBanner, Loading, money } from '../../components/ui';
import { ProductEditor } from '../../components/ProductEditor';

export type MenuEditorHandle = { focusNewCategory: () => void };

/**
 * The whole menu on one screen, as the client sees it: each category with
 * its products under it. Categories are added and renamed in place;
 * products open in a side panel, already in the right category.
 */
export const MenuEditor = forwardRef<MenuEditorHandle, { restaurantId: number }>(function MenuEditor(
  { restaurantId },
  ref,
) {
  const queryClient = useQueryClient();
  const newCategoryRef = useRef<HTMLInputElement>(null);
  const [newCategory, setNewCategory] = useState('');
  const [renaming, setRenaming] = useState<{ id: number; name: string } | null>(null);
  const [search, setSearch] = useState('');
  const [editor, setEditor] = useState<{ product?: Product; categoryId?: number } | null>(null);
  const [flash, setFlash] = useState<string | null>(null);

  useImperativeHandle(ref, () => ({ focusNewCategory: () => newCategoryRef.current?.focus() }));

  useEffect(() => {
    if (!flash) return;
    const timer = setTimeout(() => setFlash(null), 5000);
    return () => clearTimeout(timer);
  }, [flash]);

  const categories = useQuery({
    queryKey: ['categories', restaurantId],
    queryFn: () => categoriesApi.listForRestaurant(restaurantId),
  });
  const products = useQuery({
    queryKey: ['products', restaurantId, 'all'],
    queryFn: () => productsApi.listAll(restaurantId),
  });

  const refreshCategories = () => queryClient.invalidateQueries({ queryKey: ['categories', restaurantId] });
  const refreshProducts = () => queryClient.invalidateQueries({ queryKey: ['products', restaurantId] });

  const addCategory = useMutation({
    mutationFn: (name: string) => categoriesApi.create(restaurantId, { name }),
    onSuccess: (category) => {
      setNewCategory('');
      setFlash(`Category “${category.name}” added.`);
      refreshCategories();
      newCategoryRef.current?.focus();
    },
  });

  const renameCategory = useMutation({
    mutationFn: ({ id, name }: { id: number; name: string }) => categoriesApi.update(id, { name }),
    onSuccess: () => {
      setRenaming(null);
      refreshCategories();
    },
  });

  const deleteCategory = useMutation({
    mutationFn: (category: Category) => categoriesApi.delete(category.id),
    onSuccess: (_, category) => {
      setFlash(`Category “${category.name}” deleted.`);
      refreshCategories();
    },
  });

  const toggleProduct = useMutation({
    mutationFn: (product: Product) => productsApi.setAvailability(product.id, !product.isAvailable),
    // Flip it on screen at once; the refetch confirms it.
    onMutate: (product) => {
      queryClient.setQueryData<Product[]>(['products', restaurantId, 'all'], (list) =>
        list?.map((p) => (p.id === product.id ? { ...p, isAvailable: !p.isAvailable } : p)),
      );
    },
    onSettled: refreshProducts,
  });

  function submitCategory(e: FormEvent) {
    e.preventDefault();
    const name = newCategory.trim();
    if (name) addCategory.mutate(name);
  }

  function submitRename(e: FormEvent) {
    e.preventDefault();
    if (renaming && renaming.name.trim()) renameCategory.mutate({ id: renaming.id, name: renaming.name.trim() });
  }

  const allCategories = categories.data ?? [];
  const allProducts = products.data ?? [];
  const query = search.trim().toLowerCase();
  const shown = query
    ? allProducts.filter((p) => `${p.name} ${p.description ?? ''}`.toLowerCase().includes(query))
    : allProducts;
  const unavailable = allProducts.filter((p) => !p.isAvailable).length;

  return (
    <section className="menu">
      <div className="menu-head">
        <div>
          <h2>Menu</h2>
          <div className="rmeta">
            {allCategories.length} categor{allCategories.length === 1 ? 'y' : 'ies'} · {allProducts.length} product
            {allProducts.length === 1 ? '' : 's'}
            {unavailable > 0 && ` · ${unavailable} unavailable`}
          </div>
        </div>
        <div className="menu-head-actions">
          {allProducts.length > 6 && (
            <input
              className="field-input menu-search"
              type="search"
              placeholder="Search the menu…"
              aria-label="Search the menu"
              value={search}
              onChange={(e) => setSearch(e.target.value)}
            />
          )}
          {allCategories.length > 0 && (
            <button type="button" className="btn" onClick={() => setEditor({ categoryId: allCategories[0].id })}>
              + Add product
            </button>
          )}
        </div>
      </div>

      {flash && (
        <div className="dispatch-flash" role="status">
          ✓ {flash}
        </div>
      )}
      <ErrorBanner
        error={
          categories.error ??
          products.error ??
          addCategory.error ??
          renameCategory.error ??
          deleteCategory.error ??
          toggleProduct.error
        }
      />

      <form className="menu-add-category" onSubmit={submitCategory}>
        <input
          ref={newCategoryRef}
          className="field-input"
          aria-label="New category"
          placeholder={allCategories.length === 0 ? 'First category, e.g. Pizzas' : 'New category, e.g. Desserts'}
          value={newCategory}
          onChange={(e) => setNewCategory(e.target.value)}
        />
        <button type="submit" className="btn ghost" disabled={addCategory.isPending || !newCategory.trim()}>
          {addCategory.isPending ? 'Adding…' : '+ Add category'}
        </button>
      </form>

      {categories.isLoading || products.isLoading ? (
        <Loading />
      ) : allCategories.length === 0 ? (
        <div className="menu-empty">
          <strong>Start with a category.</strong> Group the menu the way the client will see it: Pizzas, Burgers,
          Drinks… Then add products to each one.
        </div>
      ) : (
        allCategories.map((category) => {
          const items = shown.filter((p) => p.categoryId === category.id);
          const total = allProducts.filter((p) => p.categoryId === category.id).length;
          if (query && items.length === 0) return null;
          return (
            <div key={category.id} className="menu-category card">
              <div className="menu-category-head">
                {renaming?.id === category.id ? (
                  <form className="menu-rename" onSubmit={submitRename}>
                    <input
                      className="field-input"
                      aria-label="Category name"
                      value={renaming.name}
                      onChange={(e) => setRenaming({ id: category.id, name: e.target.value })}
                      onKeyDown={(e) => e.key === 'Escape' && setRenaming(null)}
                      autoFocus
                    />
                    <button type="submit" className="btn sm" disabled={renameCategory.isPending}>
                      Save
                    </button>
                    <button type="button" className="btn ghost sm" onClick={() => setRenaming(null)}>
                      Cancel
                    </button>
                  </form>
                ) : (
                  <>
                    <h3>
                      {category.name} <span className="badge muted">{total}</span>
                    </h3>
                    <div className="menu-category-actions">
                      <button
                        type="button"
                        className="btn ghost sm"
                        onClick={() => setRenaming({ id: category.id, name: category.name })}
                      >
                        Rename
                      </button>
                      {total === 0 && (
                        <button
                          type="button"
                          className="btn ghost sm danger-text"
                          disabled={deleteCategory.isPending}
                          onClick={() => {
                            if (window.confirm(`Delete the empty category “${category.name}”?`)) {
                              deleteCategory.mutate(category);
                            }
                          }}
                        >
                          Delete
                        </button>
                      )}
                      <button
                        type="button"
                        className="btn sm"
                        onClick={() => setEditor({ categoryId: category.id })}
                      >
                        + Add product
                      </button>
                    </div>
                  </>
                )}
              </div>

              {items.length === 0 ? (
                <button type="button" className="menu-category-empty" onClick={() => setEditor({ categoryId: category.id })}>
                  No products in {category.name} yet. <strong>Add the first one</strong>
                </button>
              ) : (
                <ul className="menu-products">
                  {items.map((p) => (
                    <li key={p.id} className={p.isAvailable ? undefined : 'off'}>
                      <button type="button" className="menu-product" onClick={() => setEditor({ product: p })}>
                        <span className="menu-thumb">
                          {p.photoUrl ? <img src={`${API_URL}${p.photoUrl}`} alt="" /> : <span>🍽</span>}
                        </span>
                        <span className="menu-product-text">
                          <span className="rname">{p.name}</span>
                          {p.description && <span className="rmeta menu-desc">{p.description}</span>}
                          {p.options?.length > 0 && (
                            <span className="rmeta">{p.options.map((o) => `${o.name} ${o.price}`).join(' · ')}</span>
                          )}
                        </span>
                        <span className="menu-price">
                          {p.options?.length ? `from ${money(p.price)}` : money(p.price)}
                        </span>
                      </button>
                      <label className="switch" title={p.isAvailable ? 'Available' : 'Unavailable'}>
                        <input
                          type="checkbox"
                          checked={p.isAvailable}
                          aria-label={`${p.name} available`}
                          onChange={() => toggleProduct.mutate(p)}
                        />
                        <span />
                      </label>
                    </li>
                  ))}
                </ul>
              )}
            </div>
          );
        })
      )}

      {editor && allCategories.length > 0 && (
        <ProductEditor
          restaurantId={restaurantId}
          categories={allCategories}
          product={editor.product}
          defaultCategoryId={editor.categoryId}
          onClose={() => setEditor(null)}
          onSaved={(message) => {
            setEditor(null);
            setFlash(message);
          }}
        />
      )}
    </section>
  );
});
