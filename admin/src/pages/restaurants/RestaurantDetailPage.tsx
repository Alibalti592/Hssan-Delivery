import { useEffect, useState, type FormEvent } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { restaurantsApi } from '../../api/resources';
import { PageHeader, Loading, ErrorBanner, Breadcrumb } from '../../components/ui';
import { PhotoUploader } from '../../components/PhotoUploader';

export default function RestaurantDetailPage() {
  const { id } = useParams();
  const restaurantId = Number(id);
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  const { data, isLoading, error } = useQuery({
    queryKey: ['restaurants', restaurantId],
    queryFn: () => restaurantsApi.get(restaurantId),
  });

  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [isAvailable, setIsAvailable] = useState(true);

  useEffect(() => {
    if (data) {
      setName(data.name);
      setDescription(data.description ?? '');
      setIsAvailable(data.isAvailable);
    }
  }, [data]);

  const update = useMutation({
    mutationFn: () =>
      restaurantsApi.update(restaurantId, {
        name,
        description: description || null,
        isAvailable,
      }),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['restaurants'] });
    },
  });

  const uploadPhoto = useMutation({
    mutationFn: (file: File) => restaurantsApi.uploadPhoto(restaurantId, file),
    onSuccess: (restaurant) => {
      queryClient.setQueryData(['restaurants', restaurantId], restaurant);
      queryClient.invalidateQueries({ queryKey: ['restaurants'] });
    },
  });

  const removePhoto = useMutation({
    mutationFn: () => restaurantsApi.removePhoto(restaurantId),
    onSuccess: (restaurant) => {
      queryClient.setQueryData(['restaurants', restaurantId], restaurant);
      queryClient.invalidateQueries({ queryKey: ['restaurants'] });
    },
  });

  const deleteRestaurant = useMutation({
    mutationFn: () => restaurantsApi.delete(restaurantId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['restaurants'] });
      navigate('/restaurants');
    },
  });

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    update.mutate();
  }

  function handleDelete() {
    if (
      window.confirm(
        `Delete "${data?.name}"? This also deletes its categories and products, and cannot be undone.`,
      )
    ) {
      deleteRestaurant.mutate();
    }
  }

  if (isLoading) {
    return (
      <>
        <PageHeader title="Restaurant" />
        <div className="content">
          <Loading />
        </div>
      </>
    );
  }

  if (error || !data) {
    return (
      <>
        <PageHeader title="Restaurant" />
        <div className="content">
          <ErrorBanner error={error ?? new Error('Restaurant not found.')} />
          <button type="button" className="btn ghost" onClick={() => navigate('/restaurants')}>
            Back to restaurants
          </button>
        </div>
      </>
    );
  }

  return (
    <>
      <PageHeader title={data.name} subtitle={`Restaurant #${data.id}`} />
      <div className="content">
        <Breadcrumb items={[{ label: 'Restaurants', to: '/restaurants' }, { label: data.name }]} />

        <div style={{ display: 'flex', gap: 10, marginBottom: 18 }}>
          <Link to={`/restaurants/${restaurantId}/categories`} className="btn ghost sm">
            Manage categories
          </Link>
          <Link to={`/restaurants/${restaurantId}/products`} className="btn ghost sm">
            Manage products
          </Link>
        </div>

        <div className="form-card">
          <ErrorBanner error={update.error ?? uploadPhoto.error ?? removePhoto.error ?? deleteRestaurant.error} />

          <PhotoUploader
            photoUrl={data.photoUrl}
            uploading={uploadPhoto.isPending}
            removing={removePhoto.isPending}
            onUpload={(file) => uploadPhoto.mutate(file)}
            onRemove={() => removePhoto.mutate()}
          />

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
              <label className="field-checkbox">
                <input
                  type="checkbox"
                  checked={isAvailable}
                  onChange={(e) => setIsAvailable(e.target.checked)}
                />
                Open — accepting orders
              </label>
            </div>
            <div style={{ display: 'flex', gap: 10 }}>
              <button type="submit" className="btn" disabled={update.isPending}>
                {update.isPending ? 'Saving…' : 'Save changes'}
              </button>
              <button
                type="button"
                className="btn danger"
                disabled={deleteRestaurant.isPending}
                onClick={handleDelete}
              >
                {deleteRestaurant.isPending ? 'Deleting…' : 'Delete restaurant'}
              </button>
            </div>
          </form>
        </div>
      </div>
    </>
  );
}
