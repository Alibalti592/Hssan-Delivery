import { useRef, useState, type ChangeEvent, type FormEvent } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { billProvidersApi, type BillProviderPayload } from '../../api/resources';
import { API_URL } from '../../api/client';
import { PageHeader, Loading, ErrorBanner, EmptyState } from '../../components/ui';
import type { BillProvider, BillProviderKind } from '../../api/types';

// Mirrors PhotoUploader::MAX_SIZE_BYTES on the backend.
const MAX_UPLOAD_BYTES = 5 * 1024 * 1024;

const KIND_LABEL: Record<BillProviderKind, string> = {
  BILL: 'Bill payment',
  TRANSFER: 'Mandat (money transfer)',
};

const EMPTY_FORM: BillProviderPayload = { name: '', kind: 'BILL', position: 0 };

/**
 * The companies clients can pick on the app's Factures screen: pay a bill
 * (STEG, SONEDE...) or send a mandat (IZI, Wafa Cash). The app shows them
 * in `position` order, grouped by kind; a hidden one disappears from the app
 * but stays on the orders that used it.
 */
export default function BillProvidersPage() {
  const queryClient = useQueryClient();
  const [creating, setCreating] = useState(false);
  const [newProvider, setNewProvider] = useState<BillProviderPayload>(EMPTY_FORM);
  const [editingId, setEditingId] = useState<number | null>(null);
  const [editing, setEditing] = useState<BillProviderPayload>(EMPTY_FORM);

  const providers = useQuery({ queryKey: ['bill-providers'], queryFn: billProvidersApi.list });
  const refresh = () => queryClient.invalidateQueries({ queryKey: ['bill-providers'] });

  const create = useMutation({
    mutationFn: () => billProvidersApi.create({ ...newProvider, name: newProvider.name.trim() }),
    onSuccess: () => {
      setNewProvider(EMPTY_FORM);
      setCreating(false);
      refresh();
    },
  });

  const update = useMutation({
    mutationFn: ({ id, data }: { id: number; data: BillProviderPayload }) =>
      billProvidersApi.update(id, data),
    onSuccess: () => {
      setEditingId(null);
      refresh();
    },
  });

  const setActive = useMutation({
    mutationFn: ({ id, isActive }: { id: number; isActive: boolean }) =>
      billProvidersApi.setActive(id, isActive),
    onSuccess: refresh,
  });

  function openCreate() {
    const last = providers.data?.reduce((max, p) => Math.max(max, p.position), 0) ?? 0;
    setNewProvider({ ...EMPTY_FORM, position: last + 1 });
    setCreating((c) => !c);
  }

  function handleCreate(e: FormEvent) {
    e.preventDefault();
    create.mutate();
  }

  function startEdit(provider: BillProvider) {
    setEditingId(provider.id);
    setEditing({ name: provider.name, kind: provider.kind, position: provider.position });
  }

  function handleUpdate(e: FormEvent, id: number) {
    e.preventDefault();
    update.mutate({ id, data: { ...editing, name: editing.name.trim() } });
  }

  const visibleCount = providers.data?.filter((p) => p.isActive).length ?? 0;

  return (
    <>
      <PageHeader
        title="Bill Providers"
        subtitle={`${visibleCount} shown in the app's Factures screen`}
        actions={
          <button type="button" className="btn" onClick={openCreate}>
            {creating ? 'Cancel' : '+ New provider'}
          </button>
        }
      />
      <div className="content">
        {creating && (
          <div className="form-card" style={{ marginBottom: 20 }}>
            <ErrorBanner error={create.error} />
            <form onSubmit={handleCreate} style={{ display: 'flex', gap: 10, alignItems: 'flex-end' }}>
              <ProviderFields value={newProvider} onChange={setNewProvider} idPrefix="new" />
              <button type="submit" className="btn" disabled={create.isPending}>
                Add
              </button>
            </form>
            <p className="rmeta" style={{ marginTop: 10 }}>
              Upload its logo from the list once it's added.
            </p>
          </div>
        )}

        <ErrorBanner error={providers.error || update.error || setActive.error} />

        {providers.isLoading ? (
          <Loading />
        ) : !providers.data || providers.data.length === 0 ? (
          <EmptyState>No bill providers yet.</EmptyState>
        ) : (
          <div className="card">
            <table>
              <thead>
                <tr>
                  <th>Logo</th>
                  <th>Provider</th>
                  <th>Type</th>
                  <th>Order</th>
                  <th>Status</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {providers.data.map((p) => (
                  <tr key={p.id}>
                    <td>
                      <LogoCell provider={p} onChanged={refresh} />
                    </td>
                    {editingId === p.id ? (
                      <td colSpan={5}>
                        <form
                          onSubmit={(e) => handleUpdate(e, p.id)}
                          style={{ display: 'flex', gap: 8, alignItems: 'flex-end' }}
                        >
                          <ProviderFields value={editing} onChange={setEditing} idPrefix={`edit-${p.id}`} />
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
                        <td className="rname">{p.name}</td>
                        <td>{KIND_LABEL[p.kind]}</td>
                        <td>{p.position}</td>
                        <td>
                          {p.isActive ? (
                            <span className="badge">Visible</span>
                          ) : (
                            <span className="badge muted">Hidden</span>
                          )}
                        </td>
                        <td style={{ whiteSpace: 'nowrap' }}>
                          <button type="button" className="btn ghost sm" onClick={() => startEdit(p)}>
                            Edit
                          </button>{' '}
                          <button
                            type="button"
                            className="btn ghost sm"
                            disabled={setActive.isPending}
                            onClick={() => setActive.mutate({ id: p.id, isActive: !p.isActive })}
                          >
                            {p.isActive ? 'Hide from app' : 'Show in app'}
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

function ProviderFields({
  value,
  onChange,
  idPrefix,
}: {
  value: BillProviderPayload;
  onChange: (value: BillProviderPayload) => void;
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
          placeholder="e.g. Ooredoo"
          maxLength={100}
          required
        />
      </div>
      <div className="field-group" style={{ width: 210, marginBottom: 0 }}>
        <label className="field-label" htmlFor={`${idPrefix}-kind`}>
          Type
        </label>
        <select
          id={`${idPrefix}-kind`}
          className="field-input"
          value={value.kind}
          onChange={(e) => onChange({ ...value, kind: e.target.value as BillProviderKind })}
        >
          <option value="BILL">{KIND_LABEL.BILL}</option>
          <option value="TRANSFER">{KIND_LABEL.TRANSFER}</option>
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

/** The provider's logo, with its own upload/replace/remove buttons. */
function LogoCell({ provider, onChanged }: { provider: BillProvider; onChanged: () => void }) {
  const inputRef = useRef<HTMLInputElement>(null);
  const [sizeError, setSizeError] = useState<string | null>(null);

  const upload = useMutation({
    mutationFn: (file: File) => billProvidersApi.uploadLogo(provider.id, file),
    onSuccess: onChanged,
  });
  const remove = useMutation({
    mutationFn: () => billProvidersApi.removeLogo(provider.id),
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
        {provider.logoUrl ? (
          <img src={`${API_URL}${provider.logoUrl}`} alt={`${provider.name} logo`} />
        ) : (
          <span className="placeholder">No logo</span>
        )}
      </div>
      <div style={{ display: 'flex', flexDirection: 'column', gap: 4 }}>
        <input
          ref={inputRef}
          type="file"
          accept="image/jpeg,image/png,image/webp"
          aria-label={`Logo for ${provider.name}`}
          style={{ display: 'none' }}
          onChange={handleFile}
        />
        <button
          type="button"
          className="btn ghost sm"
          disabled={upload.isPending}
          onClick={() => inputRef.current?.click()}
        >
          {upload.isPending ? 'Uploading…' : provider.logoUrl ? 'Replace' : 'Upload logo'}
        </button>
        {provider.logoUrl && (
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
