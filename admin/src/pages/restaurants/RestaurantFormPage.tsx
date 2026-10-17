import { useEffect, useRef, useState, type FormEvent } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { restaurantsApi } from '../../api/resources';
import type { RestaurantType } from '../../api/types';
import { PageHeader, ErrorBanner, Breadcrumb } from '../../components/ui';

// Mirrors PhotoUploader::MAX_SIZE_BYTES on the backend.
const MAX_UPLOAD_BYTES = 5 * 1024 * 1024;

/**
 * A new restaurant: the basics and, if at hand, its photo. It starts closed
 * — clients would otherwise see an empty menu — and opens on its page once
 * the menu is in.
 */
export default function RestaurantFormPage() {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const fileRef = useRef<HTMLInputElement>(null);
  const [name, setName] = useState('');
  const [type, setType] = useState<RestaurantType>('RESTAURANT');
  const [file, setFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [fileError, setFileError] = useState<string | null>(null);

  // Frees the preview when it's replaced or the page closes.
  useEffect(() => {
    if (!preview) return;
    return () => URL.revokeObjectURL(preview);
  }, [preview]);

  const create = useMutation({
    mutationFn: async () => {
      const restaurant = await restaurantsApi.create({
        name: name.trim(),
        description: null,
        isAvailable: false,
        type,
      });
      return file ? restaurantsApi.uploadPhoto(restaurant.id, file) : restaurant;
    },
    onSuccess: (restaurant) => {
      queryClient.invalidateQueries({ queryKey: ['restaurants'] });
      navigate(`/restaurants/${restaurant.id}`, { state: { justCreated: true } });
    },
  });

  function pick(picked: File | undefined) {
    if (!picked) return;
    if (picked.size > MAX_UPLOAD_BYTES) {
      setFileError('Image must be smaller than 5 MB.');
      return;
    }
    setFileError(null);
    setFile(picked);
    setPreview(URL.createObjectURL(picked));
  }

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    create.mutate();
  }

  return (
    <>
      <PageHeader title="New restaurant" subtitle="Step 1 of 2: the basics. Next: its menu." />
      <div className="content">
        <Breadcrumb items={[{ label: 'Restaurants', to: '/restaurants' }, { label: 'New' }]} />
        <div className="form-card">
          <ErrorBanner error={create.error} />
          <form onSubmit={handleSubmit}>
            <div className="photo-row">
              <button
                type="button"
                className="photo-box photo-pick"
                onClick={() => fileRef.current?.click()}
                aria-label={preview ? 'Replace photo' : 'Add a photo'}
              >
                {preview ? <img src={preview} alt="" /> : <span className="placeholder">+ Photo</span>}
              </button>
              <div className="photo-actions">
                <input
                  ref={fileRef}
                  type="file"
                  accept="image/jpeg,image/png,image/webp"
                  style={{ display: 'none' }}
                  onChange={(e) => {
                    pick(e.target.files?.[0]);
                    e.target.value = '';
                  }}
                />
                <button type="button" className="btn ghost sm" onClick={() => fileRef.current?.click()}>
                  {preview ? 'Replace photo' : 'Add a photo'}
                </button>
                <span className="rmeta">Shown on the client's home screen. You can add it later.</span>
                {fileError && <p className="field-error">{fileError}</p>}
              </div>
            </div>
            <div className="field-group">
              <label className="field-label" htmlFor="name">
                Name
              </label>
              <input
                id="name"
                className="field-input"
                value={name}
                onChange={(e) => setName(e.target.value)}
                placeholder="e.g. Pizzeria Roma"
                autoFocus
                required
              />
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
            <p className="rmeta" style={{ margin: '0 0 14px' }}>
              It stays closed to clients until you open it, once its menu is in.
            </p>
            <button type="submit" className="btn" disabled={create.isPending}>
              {create.isPending ? 'Creating…' : 'Create and add the menu →'}
            </button>
          </form>
        </div>
      </div>
    </>
  );
}
