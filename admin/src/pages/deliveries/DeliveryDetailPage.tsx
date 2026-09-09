import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link, useParams } from 'react-router-dom';
import { couriersApi, deliveriesApi } from '../../api/resources';
import { PageHeader, Loading, ErrorBanner, Breadcrumb, StatusBadge, formatDate } from '../../components/ui';

const CANCELLABLE = ['PENDING', 'ASSIGNED'];

export default function DeliveryDetailPage() {
  const { id } = useParams();
  const deliveryId = Number(id);
  const queryClient = useQueryClient();
  const [courierId, setCourierId] = useState<number | ''>('');

  const delivery = useQuery({
    queryKey: ['deliveries', deliveryId],
    queryFn: () => deliveriesApi.get(deliveryId),
  });

  const couriers = useQuery({ queryKey: ['couriers'], queryFn: couriersApi.list });
  const activeCouriers = couriers.data?.filter((c) => c.isActive) ?? [];

  const assign = useMutation({
    mutationFn: () => deliveriesApi.assign(deliveryId, Number(courierId)),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['deliveries', deliveryId] });
      queryClient.invalidateQueries({ queryKey: ['deliveries'] });
    },
  });

  const cancel = useMutation({
    mutationFn: () => deliveriesApi.cancel(deliveryId),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['deliveries', deliveryId] });
      queryClient.invalidateQueries({ queryKey: ['deliveries'] });
    },
  });

  const courierName = (id: number | null) =>
    id ? couriers.data?.find((c) => c.id === id)?.name ?? `#${id}` : '—';

  return (
    <>
      <PageHeader title={delivery.data ? `Delivery #${delivery.data.id}` : 'Delivery'} />
      <div className="content">
        <Breadcrumb
          items={[{ label: 'Deliveries', to: '/deliveries' }, { label: delivery.data ? `#${delivery.data.id}` : '…' }]}
        />
        <ErrorBanner error={delivery.error || assign.error || cancel.error} />
        {delivery.isLoading ? (
          <Loading />
        ) : delivery.data ? (
          <>
            <div className="form-card" style={{ marginBottom: 20 }}>
              <div className="detail-grid">
                <div className="detail-item">
                  <div className="field-label">Status</div>
                  <div className="value">
                    <StatusBadge status={delivery.data.status} />
                  </div>
                </div>
                <div className="detail-item">
                  <div className="field-label">Order</div>
                  <div className="value">
                    <Link to={`/orders/${delivery.data.orderId}`}>#{delivery.data.orderId}</Link>
                  </div>
                </div>
                <div className="detail-item">
                  <div className="field-label">Courier</div>
                  <div className="value">{courierName(delivery.data.courierId)}</div>
                </div>
                <div className="detail-item">
                  <div className="field-label">Created</div>
                  <div className="value">{formatDate(delivery.data.createdAt)}</div>
                </div>
                {delivery.data.assignedAt && (
                  <div className="detail-item">
                    <div className="field-label">Assigned</div>
                    <div className="value">{formatDate(delivery.data.assignedAt)}</div>
                  </div>
                )}
                {delivery.data.acceptedAt && (
                  <div className="detail-item">
                    <div className="field-label">Accepted</div>
                    <div className="value">{formatDate(delivery.data.acceptedAt)}</div>
                  </div>
                )}
                {delivery.data.pickedUpAt && (
                  <div className="detail-item">
                    <div className="field-label">Picked up</div>
                    <div className="value">{formatDate(delivery.data.pickedUpAt)}</div>
                  </div>
                )}
                {delivery.data.deliveredAt && (
                  <div className="detail-item">
                    <div className="field-label">Delivered</div>
                    <div className="value">{formatDate(delivery.data.deliveredAt)}</div>
                  </div>
                )}
              </div>

              {delivery.data.status === 'PENDING' && (
                <div style={{ display: 'flex', gap: 10, alignItems: 'flex-end', marginBottom: 14 }}>
                  <div className="field-group" style={{ flex: 1, marginBottom: 0 }}>
                    <label className="field-label">Assign to courier</label>
                    <select
                      className="field-select"
                      value={courierId}
                      onChange={(e) => setCourierId(Number(e.target.value))}
                    >
                      <option value="">Select a courier…</option>
                      {activeCouriers.map((c) => (
                        <option key={c.id} value={c.id}>
                          {c.name} ({c.phone})
                        </option>
                      ))}
                    </select>
                  </div>
                  <button
                    type="button"
                    className="btn"
                    disabled={!courierId || assign.isPending}
                    onClick={() => assign.mutate()}
                  >
                    {assign.isPending ? 'Assigning…' : 'Assign'}
                  </button>
                </div>
              )}

              {CANCELLABLE.includes(delivery.data.status) && (
                <button
                  type="button"
                  className="btn danger"
                  disabled={cancel.isPending}
                  onClick={() => cancel.mutate()}
                >
                  {cancel.isPending ? 'Cancelling…' : 'Cancel delivery'}
                </button>
              )}
            </div>
          </>
        ) : null}
      </div>
    </>
  );
}
