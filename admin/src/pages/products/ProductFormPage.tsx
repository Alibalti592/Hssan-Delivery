import { useEffect, useState, type FormEvent } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useNavigate, useParams } from 'react-router-dom';
import { categoriesApi, productsApi, restaurantsApi } from '../../api/resources';
import { PageHeader, Loading, ErrorBanner, Breadcrumb } from '../../components/ui';
import { PhotoUploader } from '../../components/PhotoUploader';

export default function ProductFormPage() {
  const { id, productId } = useParams();
  const restaurantId = Number(id);
  const isEdit = productId !== undefined;
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  const restaurant = useQuery({
    queryKey: ['restaurants', restaurantId],
    queryFn: () => restaurantsApi.get(restaurantId),
  });

  const categories = useQuery({
    queryKey: ['categories', restaurantId],
    queryFn: () => categoriesApi.listForRestaurant(restaurantId),
  });

  const existing = useQuery({
    queryKey: ['products', 'detail', productId],
    queryFn: () => productsApi.get(Number(productId)),
    enabled: isEdit,
  });

  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [price, setPrice] = useState('');
  const [categoryId, setCategoryId] = useState<number | ''>('');
  const [isAvailable, setIsAvailable] = useState(true);

  useEffect(() => {
    if (existing.data) {
      setName(existing.data.name);
      setDescription(existing.data.description ?? '');
      setPrice(existing.data.price);
      setCategoryId(existing.data.categoryId);
      setIsAvailable(existing.data.isAvailable);
    }
  }, [existing.data]);

  useEffect(() => {
    if (!isEdit && categories.data && categories.data.length > 0 && categoryId === '') {
      setCategoryId(categories.data[0].id);
    }
  }, [isEdit, categories.data, categoryId]);

  const save = useMutation({
    mutationFn: () => {
      const payload = {
        name,
        description: description || null,
        price,
        categoryId: Number(categoryId),
        isAvailable,
      };

      return isEdit
        ? productsApi.update(Number(productId), payload)
        : productsApi.create(restaurantId, payload);
    },
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['products', restaurantId] });
      navigate(`/restaurants/${restaurantId}/products`);
    },
  });

  const uploadPhoto = useMutation({
    mutationFn: (file: File) => productsApi.uploadPhoto(Number(productId), file),
    onSuccess: (product) => {
      queryClient.setQueryData(['products', 'detail', productId], product);
      queryClient.invalidateQueries({ queryKey: ['products', restaurantId] });
    },
  });

  const removePhoto = useMutation({
    mutationFn: () => productsApi.removePhoto(Number(productId)),
    onSuccess: (product) => {
      queryClient.setQueryData(['products', 'detail', productId], product);
      queryClient.invalidateQueries({ queryKey: ['products', restaurantId] });
    },
  });

  const deleteProduct = useMutation({
    mutationFn: () => productsApi.delete(Number(productId)),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['products', restaurantId] });
      navigate(`/restaurants/${restaurantId}/products`);
    },
  });

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    save.mutate();
  }

  function handleDelete() {
    if (window.confirm(`Delete "${existing.data?.name}"? This cannot be undone.`)) {
      deleteProduct.mutate();
    }
  }

  if (isEdit && existing.isLoading) {
    return (
      <>
        <PageHeader title="Product" />
        <div className="content">
          <Loading />
        </div>
      </>
    );
  }

  return (
    <>
      <PageHeader title={isEdit ? 'Edit product' : 'New product'} />
      <div className="content">
        <Breadcrumb
          items={[
            { label: 'Restaurants', to: '/restaurants' },
            { label: restaurant.data?.name ?? '…', to: `/restaurants/${restaurantId}` },
            { label: 'Products', to: `/restaurants/${restaurantId}/products` },
            { label: isEdit ? 'Edit' : 'New' },
          ]}
        />
        <div className="form-card">
          <ErrorBanner
            error={save.error ?? existing.error ?? uploadPhoto.error ?? removePhoto.error ?? deleteProduct.error}
          />

          {isEdit && existing.data && (
            <PhotoUploader
              photoUrl={existing.data.photoUrl}
              uploading={uploadPhoto.isPending}
              removing={removePhoto.isPending}
              onUpload={(file) => uploadPhoto.mutate(file)}
              onRemove={() => removePhoto.mutate()}
            />
          )}

          <form onSubmit={handleSubmit}>
            <div className="field-group">
              <label className="field-label" htmlFor="name">
                Name
              </label>
              <input
                id="name"
                className="field-input"
                value={name}
                onChange={(e) => setName(e.target.value)}
                required
              />
            </div>
            <div className="field-group">
              <label className="field-label" htmlFor="description">
                Description
              </label>
              <textarea
                id="description"
                className="field-textarea"
                rows={3}
                value={description}
                onChange={(e) => setDescription(e.target.value)}
              />
            </div>
            <div className="field-group">
              <label className="field-label" htmlFor="price">
                Price (DT)
              </label>
              <input
                id="price"
                className="field-input"
                value={price}
                onChange={(e) => setPrice(e.target.value)}
                placeholder="18.500"
                required
              />
            </div>
            <div className="field-group">
              <label className="field-label" htmlFor="categoryId">
                Category
              </label>
              <select
                id="categoryId"
                className="field-select"
                value={categoryId}
                onChange={(e) => setCategoryId(Number(e.target.value))}
                required
              >
                {categories.data?.length === 0 && <option value="">No categories yet</option>}
                {categories.data?.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </select>
            </div>
            <div className="field-group">
              <label className="field-checkbox">
                <input
                  type="checkbox"
                  checked={isAvailable}
                  onChange={(e) => setIsAvailable(e.target.checked)}
                />
                Available to order
              </label>
            </div>
            <div style={{ display: 'flex', gap: 10 }}>
              <button
                type="submit"
                className="btn"
                disabled={save.isPending || !categoryId}
              >
                {save.isPending ? 'Saving…' : isEdit ? 'Save changes' : 'Create product'}
              </button>
              {isEdit && (
                <button
                  type="button"
                  className="btn danger"
                  disabled={deleteProduct.isPending}
                  onClick={handleDelete}
                >
                  {deleteProduct.isPending ? 'Deleting…' : 'Delete product'}
                </button>
              )}
            </div>
          </form>
        </div>
      </div>
    </>
  );
}
