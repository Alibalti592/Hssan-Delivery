import { useEffect, useRef, useState, type FormEvent } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useLocation, useNavigate, useParams } from 'react-router-dom';
import { categoriesApi, productsApi, restaurantsApi } from '../../api/resources';
import type { RestaurantType } from '../../api/types';
import { PageHeader, Loading, ErrorBanner, Breadcrumb } from '../../components/ui';
import { PhotoUploader } from '../../components/PhotoUploader';
import { MenuEditor, type MenuEditorHandle } from './MenuEditor';

const TYPE_LABEL: Record<RestaurantType, string> = {
  RESTAURANT: 'Restaurant',
  GROCERY: 'Grocery store',
};

/**
 * One page per restaurant: its details on the side, the whole menu next to
 * them, and — until it's ready for clients — what's left to set up.
 */
export default function RestaurantDetailPage() {
  const { id } = useParams();
  const restaurantId = Number(id);
  const navigate = useNavigate();
  const location = useLocation();
  const queryClient = useQueryClient();
  const menuRef = useRef<MenuEditorHandle>(null);
  const justCreated = (location.state as { justCreated?: boolean } | null)?.justCreated === true;

  const { data, isLoading, error } = useQuery({
    queryKey: ['restaurants', restaurantId],
    queryFn: () => restaurantsApi.get(restaurantId),
  });
  // Shared with the menu editor (same keys): for the setup checklist.
  const categories = useQuery({
    queryKey: ['categories', restaurantId],
    queryFn: () => categoriesApi.listForRestaurant(restaurantId),
  });
  const products = useQuery({
    queryKey: ['products', restaurantId, 'all'],
    queryFn: () => productsApi.listAll(restaurantId),
  });

  const [name, setName] = useState('');
  const [type, setType] = useState<RestaurantType>('RESTAURANT');
  const [saved, setSaved] = useState(false);

  useEffect(() => {
    if (data) {
      setName(data.name);
      setType(data.type);
    }
  }, [data]);

  // A restaurant just created: straight to its first category.
  useEffect(() => {
    if (justCreated && data) menuRef.current?.focusNewCategory();
  }, [justCreated, data]);

  const refresh = () => queryClient.invalidateQueries({ queryKey: ['restaurants'] });

  const update = useMutation({
    mutationFn: () =>
      restaurantsApi.update(restaurantId, {
        name,
        description: null,
        isAvailable: data!.isAvailable,
        type,
      }),
    onSuccess: () => {
      setSaved(true);
      setTimeout(() => setSaved(false), 2500);
      refresh();
    },
  });

  const setOpen = useMutation({
    mutationFn: (open: boolean) => restaurantsApi.setAvailability(restaurantId, open),
    onSuccess: (restaurant) => {
      queryClient.setQueryData(['restaurants', restaurantId], restaurant);
      refresh();
    },
  });

  const uploadPhoto = useMutation({
    mutationFn: (file: File) => restaurantsApi.uploadPhoto(restaurantId, file),
    onSuccess: (restaurant) => {
      queryClient.setQueryData(['restaurants', restaurantId], restaurant);
      refresh();
    },
  });

  const removePhoto = useMutation({
    mutationFn: () => restaurantsApi.removePhoto(restaurantId),
    onSuccess: (restaurant) => {
      queryClient.setQueryData(['restaurants', restaurantId], restaurant);
      refresh();
    },
  });

  const deleteRestaurant = useMutation({
    mutationFn: () => restaurantsApi.delete(restaurantId),
    onSuccess: () => {
      refresh();
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
        `Permanently delete "${data?.name}"?\n\n` +
          'This also deletes ALL its orders (with their deliveries), categories, products and promotions. ' +
          'This cannot be undone.\n\n' +
          'To only hide it from customers, close it instead.',
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

  const categoryCount = categories.data?.length ?? 0;
  const productCount = products.data?.length ?? 0;
  const steps = [
    { label: 'Add a photo', done: data.photoUrl !== null },
    { label: 'Add a category', done: categoryCount > 0 },
    { label: 'Add products', done: productCount > 0 },
    { label: 'Open it to clients', done: data.isAvailable },
  ];
  const remaining = steps.filter((s) => !s.done).length;
  const dirty = name !== data.name || type !== data.type;

  return (
    <>
      <PageHeader
        title={data.name}
        subtitle={`${TYPE_LABEL[data.type]} · #${data.id}`}
        actions={
          <button
            type="button"
            className={`open-toggle${data.isAvailable ? ' is-open' : ''}`}
            disabled={setOpen.isPending}
            onClick={() => setOpen.mutate(!data.isAvailable)}
            aria-pressed={data.isAvailable}
          >
            <span className="dot" />
            {data.isAvailable ? 'Open · taking orders' : 'Closed'}
            <span className="open-toggle-action">{data.isAvailable ? 'Close' : 'Open'}</span>
          </button>
        }
      />
      <div className="content">
        <Breadcrumb items={[{ label: 'Restaurants', to: '/restaurants' }, { label: data.name }]} />

        {(justCreated || remaining > 0) && (
          <div className="setup card">
            <div className="setup-title">
              {remaining === 0
                ? `${data.name} is ready: clients can order.`
                : justCreated
                  ? `${data.name} is created. ${remaining} step${remaining === 1 ? '' : 's'} before clients can order:`
                  : `${remaining} step${remaining === 1 ? '' : 's'} left before clients can order:`}
            </div>
            <ol className="setup-steps">
              {steps.map((step) => (
                <li key={step.label} className={step.done ? 'done' : undefined}>
                  <span className="setup-check">{step.done ? '✓' : ''}</span>
                  {step.label}
                </li>
              ))}
            </ol>
          </div>
        )}

        <ErrorBanner error={setOpen.error} />

        <div className="restaurant-layout">
          <aside className="form-card restaurant-details">
            <h2 className="side-title">Details</h2>
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
                <input id="name" className="field-input" value={name} onChange={(e) => setName(e.target.value)} required />
              </div>
              <div className="field-group">
                <label className="field-label" htmlFor="type">
                  Type
                </label>
                <select
                  id="type"
                  className="field-select"
                  value={type}
                  onChange={(e) => setType(e.target.value as RestaurantType)}
                >
                  <option value="RESTAURANT">Restaurant</option>
                  <option value="GROCERY">Grocery store</option>
                </select>
              </div>
              <div className="details-actions">
                <button type="submit" className="btn" disabled={update.isPending || !dirty}>
                  {update.isPending ? 'Saving…' : saved ? '✓ Saved' : 'Save changes'}
                </button>
                <button
                  type="button"
                  className="btn ghost sm danger-text"
                  disabled={deleteRestaurant.isPending}
                  onClick={handleDelete}
                >
                  {deleteRestaurant.isPending ? 'Deleting…' : 'Delete restaurant'}
                </button>
              </div>
            </form>
          </aside>

          <MenuEditor ref={menuRef} restaurantId={restaurantId} />
        </div>
      </div>
    </>
  );
}
