import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { deliveryZonesApi, type DeliveryZoneInput } from '../../api/resources';
import { PageHeader, Loading, ErrorBanner, EmptyState, money } from '../../components/ui';
import ZoneEditor from './ZoneEditor';

export default function DeliveryZonesListPage() {
  const queryClient = useQueryClient();
  const [creating, setCreating] = useState(false);
  const [editingId, setEditingId] = useState<number | null>(null);

  const zones = useQuery({ queryKey: ['delivery-zones'], queryFn: deliveryZonesApi.list });

  const create = useMutation({
    mutationFn: (data: DeliveryZoneInput) => deliveryZonesApi.create(data),
    onSuccess: () => {
      setCreating(false);
      queryClient.invalidateQueries({ queryKey: ['delivery-zones'] });
    },
  });

  const update = useMutation({
    mutationFn: ({ zoneId, data }: { zoneId: number; data: DeliveryZoneInput }) =>
      deliveryZonesApi.update(zoneId, data),
    onSuccess: () => {
      setEditingId(null);
      queryClient.invalidateQueries({ queryKey: ['delivery-zones'] });
    },
  });

  const all = zones.data ?? [];
  const placed = all.filter((z) => z.radiusKm != null).length;

  return (
    <>
      <PageHeader
        title="Delivery Zones"
        subtitle={`${all.length} zones · ${placed} on the map`}
        actions={
          <button
            type="button"
            className="btn"
            onClick={() => {
              setCreating((c) => !c);
              setEditingId(null);
            }}
          >
            {creating ? 'Cancel' : '+ New zone'}
          </button>
        }
      />
      <div className="content">
        {creating && (
          <div className="form-card" style={{ marginBottom: 20 }}>
            <ErrorBanner error={create.error} />
            <ZoneEditor
              others={all}
              busy={create.isPending}
              submitLabel="Add zone"
              onSubmit={(data) => create.mutate(data)}
              onCancel={() => setCreating(false)}
            />
          </div>
        )}

        <ErrorBanner error={zones.error || update.error} />

        {zones.isLoading ? (
          <Loading />
        ) : all.length === 0 ? (
          <EmptyState>No delivery zones yet.</EmptyState>
        ) : (
          <div className="card">
            <table>
              <thead>
                <tr>
                  <th>Zone</th>
                  <th>Fee</th>
                  <th>Map</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {all.map((z) =>
                  editingId === z.id ? (
                    <tr key={z.id}>
                      <td colSpan={4}>
                        <ZoneEditor
                          zone={z}
                          others={all}
                          busy={update.isPending}
                          submitLabel="Save"
                          onSubmit={(data) => update.mutate({ zoneId: z.id, data })}
                          onCancel={() => setEditingId(null)}
                        />
                      </td>
                    </tr>
                  ) : (
                    <tr key={z.id}>
                      <td className="rname">{z.name}</td>
                      <td>{money(z.fee)}</td>
                      <td>
                        {z.radiusKm != null ? (
                          <span className="badge">On the map · {z.radiusKm} km</span>
                        ) : (
                          <span className="badge warn">Not placed</span>
                        )}
                      </td>
                      <td>
                        <button
                          type="button"
                          className="btn ghost sm"
                          onClick={() => {
                            setEditingId(z.id);
                            setCreating(false);
                          }}
                        >
                          Edit
                        </button>
                      </td>
                    </tr>
                  ),
                )}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </>
  );
}
