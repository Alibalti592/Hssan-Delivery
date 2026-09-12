import { useState, type FormEvent } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { deliveryZonesApi } from '../../api/resources';
import { PageHeader, Loading, ErrorBanner, EmptyState, money } from '../../components/ui';
import type { DeliveryZoneAdmin } from '../../api/types';

export default function DeliveryZonesListPage() {
  const queryClient = useQueryClient();
  const [creating, setCreating] = useState(false);
  const [newName, setNewName] = useState('');
  const [newFee, setNewFee] = useState('');
  const [editingId, setEditingId] = useState<number | null>(null);
  const [editingName, setEditingName] = useState('');
  const [editingFee, setEditingFee] = useState('');

  const zones = useQuery({ queryKey: ['delivery-zones'], queryFn: deliveryZonesApi.list });

  const create = useMutation({
    mutationFn: () => deliveryZonesApi.create({ name: newName.trim(), fee: newFee.trim() }),
    onSuccess: () => {
      setNewName('');
      setNewFee('');
      setCreating(false);
      queryClient.invalidateQueries({ queryKey: ['delivery-zones'] });
    },
  });

  const update = useMutation({
    mutationFn: ({ zoneId, name, fee }: { zoneId: number; name: string; fee: string }) =>
      deliveryZonesApi.update(zoneId, { name, fee }),
    onSuccess: () => {
      setEditingId(null);
      queryClient.invalidateQueries({ queryKey: ['delivery-zones'] });
    },
  });

  function handleCreate(e: FormEvent) {
    e.preventDefault();
    create.mutate();
  }

  function startEdit(zone: DeliveryZoneAdmin) {
    setEditingId(zone.id);
    setEditingName(zone.name);
    setEditingFee(zone.fee);
  }

  function handleUpdate(e: FormEvent, zoneId: number) {
    e.preventDefault();
    update.mutate({ zoneId, name: editingName.trim(), fee: editingFee.trim() });
  }

  return (
    <>
      <PageHeader
        title="Delivery Zones"
        subtitle={`${zones.data?.length ?? 0} zones`}
        actions={
          <button type="button" className="btn" onClick={() => setCreating((c) => !c)}>
            {creating ? 'Cancel' : '+ New zone'}
          </button>
        }
      />
      <div className="content">
        {creating && (
          <div className="form-card" style={{ marginBottom: 20 }}>
            <ErrorBanner error={create.error} />
            <form onSubmit={handleCreate} style={{ display: 'flex', gap: 10, alignItems: 'flex-end' }}>
              <div className="field-group" style={{ flex: 1, marginBottom: 0 }}>
                <label className="field-label">Zone name</label>
                <input
                  className="field-input"
                  value={newName}
                  onChange={(e) => setNewName(e.target.value)}
                  placeholder="e.g. Jarzouna"
                  required
                />
              </div>
              <div className="field-group" style={{ width: 120, marginBottom: 0 }}>
                <label className="field-label">Fee (DT)</label>
                <input
                  className="field-input"
                  value={newFee}
                  onChange={(e) => setNewFee(e.target.value)}
                  placeholder="5.000"
                  required
                />
              </div>
              <button type="submit" className="btn" disabled={create.isPending}>
                Add
              </button>
            </form>
          </div>
        )}

        <ErrorBanner error={zones.error || update.error} />

        {zones.isLoading ? (
          <Loading />
        ) : !zones.data || zones.data.length === 0 ? (
          <EmptyState>No delivery zones yet.</EmptyState>
        ) : (
          <div className="card">
            <table>
              <thead>
                <tr>
                  <th>Zone</th>
                  <th>Fee</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {zones.data.map((z) => (
                  <tr key={z.id}>
                    {editingId === z.id ? (
                      <td colSpan={3}>
                        <form
                          onSubmit={(e) => handleUpdate(e, z.id)}
                          style={{ display: 'flex', gap: 8, alignItems: 'center' }}
                        >
                          <input
                            className="field-input"
                            style={{ flex: 1 }}
                            value={editingName}
                            onChange={(e) => setEditingName(e.target.value)}
                            autoFocus
                          />
                          <input
                            className="field-input"
                            style={{ width: 100 }}
                            value={editingFee}
                            onChange={(e) => setEditingFee(e.target.value)}
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
                      </td>
                    ) : (
                      <>
                        <td className="rname">{z.name}</td>
                        <td>{money(z.fee)}</td>
                        <td>
                          <button type="button" className="btn ghost sm" onClick={() => startEdit(z)}>
                            Edit
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
