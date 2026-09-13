import { useEffect, useState, type FormEvent } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useNavigate, useParams } from 'react-router-dom';
import { promotionsApi, restaurantsApi } from '../../api/resources';
import type { DiscountType } from '../../api/types';
import { PageHeader, Loading, ErrorBanner, Breadcrumb } from '../../components/ui';
import { PhotoUploader } from '../../components/PhotoUploader';

function toDatetimeLocal(iso: string): string {
  const d = new Date(iso);
  const pad = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

export default function PromotionFormPage() {
  const { promotionId } = useParams();
  const isEdit = promotionId !== undefined;
  const navigate = useNavigate();
  const queryClient = useQueryClient();

  const restaurants = useQuery({
    queryKey: ['restaurants', 'all'],
    queryFn: () => restaurantsApi.list({ limit: 100 }),
  });

  const existing = useQuery({
    queryKey: ['promotions', 'detail', promotionId],
    queryFn: () => promotionsApi.get(Number(promotionId)),
    enabled: isEdit,
  });

  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [discountType, setDiscountType] = useState<DiscountType>('PERCENTAGE');
  const [discountValue, setDiscountValue] = useState('');
  const [promoCode, setPromoCode] = useState('');
  const [startAt, setStartAt] = useState('');
  const [endAt, setEndAt] = useState('');
  const [isActive, setIsActive] = useState(true);
  const [restaurantId, setRestaurantId] = useState<number | ''>('');

  useEffect(() => {
    if (existing.data) {
      setTitle(existing.data.title);
      setDescription(existing.data.description ?? '');
      setDiscountType(existing.data.discountType);
      setDiscountValue(existing.data.discountValue);
      setPromoCode(existing.data.promoCode ?? '');
      setStartAt(toDatetimeLocal(existing.data.startAt));
      setEndAt(toDatetimeLocal(existing.data.endAt));
      setIsActive(existing.data.isActive);
      setRestaurantId(existing.data.restaurantId ?? '');
    }
  }, [existing.data]);

  const save = useMutation({
    mutationFn: () => {
      const payload = {
        title,
        description: description || null,
        discountType,
        discountValue,
        promoCode: promoCode || null,
        startAt: new Date(startAt).toISOString(),
        endAt: new Date(endAt).toISOString(),
        isActive,
        restaurantId: restaurantId === '' ? null : Number(restaurantId),
      };

      return isEdit
        ? promotionsApi.update(Number(promotionId), payload)
        : promotionsApi.create(payload);
    },
    onSuccess: (promotion) => {
      queryClient.invalidateQueries({ queryKey: ['promotions'] });
      navigate(isEdit ? '/promotions' : `/promotions/${promotion.id}/edit`);
    },
  });

  const uploadPhoto = useMutation({
    mutationFn: (file: File) => promotionsApi.uploadPhoto(Number(promotionId), file),
    onSuccess: (promotion) => {
      queryClient.setQueryData(['promotions', 'detail', promotionId], promotion);
      queryClient.invalidateQueries({ queryKey: ['promotions'] });
    },
  });

  const removePhoto = useMutation({
    mutationFn: () => promotionsApi.removePhoto(Number(promotionId)),
    onSuccess: (promotion) => {
      queryClient.setQueryData(['promotions', 'detail', promotionId], promotion);
      queryClient.invalidateQueries({ queryKey: ['promotions'] });
    },
  });

  const deletePromotion = useMutation({
    mutationFn: () => promotionsApi.delete(Number(promotionId)),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['promotions'] });
      navigate('/promotions');
    },
  });

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    save.mutate();
  }

  function handleDelete() {
    if (window.confirm(`Delete "${existing.data?.title}"? This cannot be undone.`)) {
      deletePromotion.mutate();
    }
  }

  if (isEdit && existing.isLoading) {
    return (
      <>
        <PageHeader title="Promotion" />
        <div className="content">
          <Loading />
        </div>
      </>
    );
  }

  return (
    <>
      <PageHeader title={isEdit ? 'Edit promotion' : 'New promotion'} />
      <div className="content">
        <Breadcrumb
          items={[
            { label: 'Promotions', to: '/promotions' },
            { label: isEdit ? 'Edit' : 'New' },
          ]}
        />
        <div className="form-card">
          <ErrorBanner
            error={
              save.error ?? existing.error ?? uploadPhoto.error ?? removePhoto.error ?? deletePromotion.error
            }
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
              <label className="field-label" htmlFor="title">
                Title
              </label>
              <input
                id="title"
                className="field-input"
                value={title}
                onChange={(e) => setTitle(e.target.value)}
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
              <label className="field-label" htmlFor="discountType">
                Discount type
              </label>
              <select
                id="discountType"
                className="field-select"
                value={discountType}
                onChange={(e) => setDiscountType(e.target.value as DiscountType)}
              >
                <option value="PERCENTAGE">Percentage</option>
                <option value="FIXED_AMOUNT">Fixed amount</option>
              </select>
            </div>
            <div className="field-group">
              <label className="field-label" htmlFor="discountValue">
                Discount value{discountType === 'PERCENTAGE' ? ' (%)' : ' (DT)'}
              </label>
              <input
                id="discountValue"
                className="field-input"
                value={discountValue}
                onChange={(e) => setDiscountValue(e.target.value)}
                placeholder={discountType === 'PERCENTAGE' ? '10' : '5.000'}
                required
              />
            </div>
            <div className="field-group">
              <label className="field-label" htmlFor="promoCode">
                Promo code (optional)
              </label>
              <input
                id="promoCode"
                className="field-input"
                value={promoCode}
                onChange={(e) => setPromoCode(e.target.value)}
                placeholder="SUMMER10"
              />
            </div>
            <div className="field-group">
              <label className="field-label" htmlFor="restaurantId">
                Restaurant (optional)
              </label>
              <select
                id="restaurantId"
                className="field-select"
                value={restaurantId}
                onChange={(e) => setRestaurantId(e.target.value === '' ? '' : Number(e.target.value))}
              >
                <option value="">All restaurants</option>
                {restaurants.data?.items.map((r) => (
                  <option key={r.id} value={r.id}>
                    {r.name}
                  </option>
                ))}
              </select>
            </div>
            <div className="field-group">
              <label className="field-label" htmlFor="startAt">
                Starts at
              </label>
              <input
                id="startAt"
                type="datetime-local"
                className="field-input"
                value={startAt}
                onChange={(e) => setStartAt(e.target.value)}
                required
              />
            </div>
            <div className="field-group">
              <label className="field-label" htmlFor="endAt">
                Ends at
              </label>
              <input
                id="endAt"
                type="datetime-local"
                className="field-input"
                value={endAt}
                onChange={(e) => setEndAt(e.target.value)}
                required
              />
            </div>
            <div className="field-group">
              <label className="field-checkbox">
                <input
                  type="checkbox"
                  checked={isActive}
                  onChange={(e) => setIsActive(e.target.checked)}
                />
                Active
              </label>
            </div>
            <div style={{ display: 'flex', gap: 10 }}>
              <button type="submit" className="btn" disabled={save.isPending}>
                {save.isPending ? 'Saving…' : isEdit ? 'Save changes' : 'Create promotion'}
              </button>
              {isEdit && (
                <button
                  type="button"
                  className="btn danger"
                  disabled={deletePromotion.isPending}
                  onClick={handleDelete}
                >
                  {deletePromotion.isPending ? 'Deleting…' : 'Delete promotion'}
                </button>
              )}
            </div>
          </form>
        </div>
      </div>
    </>
  );
}
