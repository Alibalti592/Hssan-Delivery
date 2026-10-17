import { useEffect, useRef, useState, type FormEvent } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { API_URL } from '../api/client';
import { productsApi } from '../api/resources';
import type { Category, Product, ProductOption } from '../api/types';
import { ErrorBanner, MONEY_PATTERN, MONEY_TITLE } from './ui';

// Mirrors PhotoUploader::MAX_SIZE_BYTES on the backend.
const MAX_UPLOAD_BYTES = 5 * 1024 * 1024;

/**
 * A product's form in a side panel over the menu, so the admin never leaves
 * the restaurant's page. A photo can be picked before the product exists:
 * it's uploaded right after it's created. "Save & add another" keeps the
 * panel open, on the same category, for entering a menu quickly.
 */
export function ProductEditor({
  restaurantId,
  categories,
  product,
  defaultCategoryId,
  onClose,
  onSaved,
}: {
  restaurantId: number;
  categories: Category[];
  /** Absent: a new product. */
  product?: Product;
  defaultCategoryId?: number;
  onClose: () => void;
  onSaved: (message: string) => void;
}) {
  const queryClient = useQueryClient();
  const isEdit = product !== undefined;
  const nameRef = useRef<HTMLInputElement>(null);
  const fileRef = useRef<HTMLInputElement>(null);

  const [name, setName] = useState(product?.name ?? '');
  const [price, setPrice] = useState(product?.price ?? '');
  const [options, setOptions] = useState<ProductOption[]>(product?.options ?? []);
  const [categoryId, setCategoryId] = useState<number | ''>(
    product?.categoryId ?? defaultCategoryId ?? categories[0]?.id ?? '',
  );
  const [isAvailable, setIsAvailable] = useState(product?.isAvailable ?? true);
  // The photo: the saved one, or a file picked here (uploaded on save).
  const [photoUrl, setPhotoUrl] = useState(product?.photoUrl ?? null);
  const [pendingFile, setPendingFile] = useState<File | null>(null);
  const [preview, setPreview] = useState<string | null>(null);
  const [fileError, setFileError] = useState<string | null>(null);
  const [addedNote, setAddedNote] = useState<string | null>(null);

  useEffect(() => {
    nameRef.current?.focus();
  }, []);

  useEffect(() => {
    const onKey = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', onKey);
    return () => window.removeEventListener('keydown', onKey);
  }, [onClose]);

  // Frees the picked file's preview when it's replaced or the panel closes.
  useEffect(() => {
    if (!preview) return;
    return () => URL.revokeObjectURL(preview);
  }, [preview]);

  function refresh() {
    queryClient.invalidateQueries({ queryKey: ['products', restaurantId] });
  }

  const save = useMutation({
    mutationFn: async (_addAnother: boolean) => {
      const payload = {
        name: name.trim(),
        description: null,
        price: options.length > 0 ? null : price,
        options: options.map((o) => ({ name: o.name.trim(), price: o.price })),
        categoryId: Number(categoryId),
        isAvailable,
      };
      const saved = isEdit
        ? await productsApi.update(product.id, payload)
        : await productsApi.create(restaurantId, payload);
      if (pendingFile) {
        return productsApi.uploadPhoto(saved.id, pendingFile);
      }
      return saved;
    },
    onSuccess: (saved, addAnother) => {
      refresh();
      if (addAnother) {
        // Same category, blank form: ready for the next dish.
        setAddedNote(`“${saved.name}” added.`);
        setName('');
        setPrice('');
        setOptions([]);
        setPendingFile(null);
        setPreview(null);
        setPhotoUrl(null);
        nameRef.current?.focus();
        return;
      }
      onSaved(isEdit ? `“${saved.name}” saved.` : `“${saved.name}” added.`);
    },
  });

  const uploadNow = useMutation({
    mutationFn: (file: File) => productsApi.uploadPhoto(product!.id, file),
    onSuccess: (saved) => {
      setPhotoUrl(saved.photoUrl);
      refresh();
    },
  });

  const removePhoto = useMutation({
    mutationFn: () => productsApi.removePhoto(product!.id),
    onSuccess: () => {
      setPhotoUrl(null);
      refresh();
    },
  });

  const remove = useMutation({
    mutationFn: () => productsApi.delete(product!.id),
    onSuccess: () => {
      refresh();
      onSaved(`“${product!.name}” deleted.`);
    },
  });

  function pickFile(file: File | undefined) {
    if (!file) return;
    if (file.size > MAX_UPLOAD_BYTES) {
      setFileError('Image must be smaller than 5 MB.');
      return;
    }
    setFileError(null);
    // An existing product gets it at once; a new one on save.
    if (isEdit) {
      uploadNow.mutate(file);
    } else {
      setPendingFile(file);
      setPreview(URL.createObjectURL(file));
    }
  }

  function updateOption(index: number, change: Partial<ProductOption>) {
    setOptions((current) => current.map((o, i) => (i === index ? { ...o, ...change } : o)));
  }

  function submit(e: FormEvent, addAnother = false) {
    e.preventDefault();
    const form = (e.target as HTMLElement).closest('form');
    if (form && !form.reportValidity()) return;
    setAddedNote(null);
    save.mutate(addAnother);
  }

  const shownPhoto = preview ?? (photoUrl ? `${API_URL}${photoUrl}` : null);
  const busy = save.isPending || remove.isPending;

  return (
    <div className="drawer-root" role="dialog" aria-modal="true" aria-label={isEdit ? 'Edit product' : 'New product'}>
      <div className="drawer-backdrop" onClick={onClose} aria-hidden="true" />
      <form className="drawer" onSubmit={(e) => submit(e)} noValidate>
        <div className="drawer-head">
          <h2>{isEdit ? 'Edit product' : 'New product'}</h2>
          <button type="button" className="drawer-close" aria-label="Close" onClick={onClose}>
            ✕
          </button>
        </div>

        <div className="drawer-body">
          {addedNote && (
            <div className="dispatch-flash" role="status">
              ✓ {addedNote} Add the next one.
            </div>
          )}
          <ErrorBanner error={save.error ?? uploadNow.error ?? removePhoto.error ?? remove.error} />

          <div className="photo-row">
            <button
              type="button"
              className="photo-box photo-pick"
              onClick={() => fileRef.current?.click()}
              aria-label={shownPhoto ? 'Replace photo' : 'Add a photo'}
            >
              {shownPhoto ? <img src={shownPhoto} alt="" /> : <span className="placeholder">+ Photo</span>}
            </button>
            <div className="photo-actions">
              <input
                ref={fileRef}
                type="file"
                accept="image/jpeg,image/png,image/webp"
                style={{ display: 'none' }}
                onChange={(e) => {
                  pickFile(e.target.files?.[0]);
                  e.target.value = '';
                }}
              />
              <button type="button" className="btn ghost sm" disabled={uploadNow.isPending} onClick={() => fileRef.current?.click()}>
                {uploadNow.isPending ? 'Uploading…' : shownPhoto ? 'Replace photo' : 'Add a photo'}
              </button>
              {(pendingFile || photoUrl) && (
                <button
                  type="button"
                  className="btn ghost sm"
                  disabled={removePhoto.isPending}
                  onClick={() => {
                    if (pendingFile) {
                      setPendingFile(null);
                      setPreview(null);
                    } else {
                      removePhoto.mutate();
                    }
                  }}
                >
                  Remove photo
                </button>
              )}
              <span className="rmeta">JPG, PNG or WebP, up to 5 MB. Optional.</span>
              {fileError && <p className="field-error">{fileError}</p>}
            </div>
          </div>

          <div className="field-group">
            <label className="field-label" htmlFor="product-name">
              Name
            </label>
            <input
              id="product-name"
              ref={nameRef}
              className="field-input"
              value={name}
              onChange={(e) => setName(e.target.value)}
              placeholder="e.g. Pizza Margherita"
              required
            />
          </div>

          <div className="field-row">
            <div className="field-group" style={{ flex: 1 }}>
              <label className="field-label" htmlFor="product-category">
                Category
              </label>
              <select
                id="product-category"
                className="field-select"
                value={categoryId}
                onChange={(e) => setCategoryId(Number(e.target.value))}
                required
              >
                {categories.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </select>
            </div>
            {options.length === 0 && (
              <div className="field-group" style={{ width: 140 }}>
                <label className="field-label" htmlFor="product-price">
                  Price (DT)
                </label>
                <input
                  id="product-price"
                  className="field-input"
                  value={price}
                  onChange={(e) => setPrice(e.target.value)}
                  placeholder="18.500"
                  inputMode="decimal"
                  pattern={MONEY_PATTERN}
                  title={MONEY_TITLE}
                  required
                />
              </div>
            )}
          </div>

          <div className="field-group">
            <span className="field-label">
              Sizes <span className="optional">optional</span>
            </span>
            {options.length === 0 && (
              <span className="rmeta" style={{ marginTop: 0 }}>
                For a pizza: M, L, Familiale. Each size has its own price; the client picks one.
              </span>
            )}
            {options.map((option, index) => (
              <div key={index} className="option-row">
                <input
                  className="field-input"
                  aria-label={`Option ${index + 1} name`}
                  value={option.name}
                  onChange={(e) => updateOption(index, { name: e.target.value })}
                  placeholder="Familiale"
                  maxLength={50}
                  required
                />
                <input
                  className="field-input"
                  aria-label={`Option ${index + 1} price`}
                  value={option.price}
                  onChange={(e) => updateOption(index, { price: e.target.value })}
                  placeholder="22.000"
                  inputMode="decimal"
                  pattern={MONEY_PATTERN}
                  title={MONEY_TITLE}
                  required
                />
                <button
                  type="button"
                  className="btn ghost sm"
                  aria-label={`Remove option ${index + 1}`}
                  onClick={() => setOptions((current) => current.filter((_, i) => i !== index))}
                >
                  ✕
                </button>
              </div>
            ))}
            {options.length < 10 && (
              <div>
                <button
                  type="button"
                  className="btn ghost sm"
                  onClick={() =>
                    setOptions((current) =>
                      // The single price becomes the first size's price.
                      current.length === 0 && price ? [{ name: '', price }] : [...current, { name: '', price: '' }],
                    )
                  }
                >
                  + Add a size
                </button>
              </div>
            )}
          </div>

          <label className="field-checkbox">
            <input type="checkbox" checked={isAvailable} onChange={(e) => setIsAvailable(e.target.checked)} />
            Available to order
          </label>
        </div>

        <div className="drawer-foot">
          <button type="submit" className="btn" disabled={busy || !categoryId}>
            {save.isPending ? 'Saving…' : isEdit ? 'Save changes' : 'Add product'}
          </button>
          {!isEdit && (
            <button type="button" className="btn ghost" disabled={busy || !categoryId} onClick={(e) => submit(e, true)}>
              Add &amp; add another
            </button>
          )}
          {isEdit && (
            <button
              type="button"
              className="btn ghost danger-text"
              disabled={busy}
              onClick={() => {
                if (window.confirm(`Delete “${product.name}”? This cannot be undone.`)) remove.mutate();
              }}
            >
              {remove.isPending ? 'Deleting…' : 'Delete'}
            </button>
          )}
        </div>
      </form>
    </div>
  );
}
