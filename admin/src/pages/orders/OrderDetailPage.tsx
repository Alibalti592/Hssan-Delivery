import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link, useParams } from 'react-router-dom';
import { deliveriesApi, ordersApi } from '../../api/resources';
import {
  PageHeader,
  Loading,
  ErrorBanner,
  Breadcrumb,
  StatusBadge,
  money,
  formatDate,
  deliveryTypeLabel,
} from '../../components/ui';

// Mirrors DeliveryDetailPage's CANCELLABLE: an order can be called off any
// time before it's actually completed or already cancelled. Cancelling goes
// through the order's 1:1 delivery (see DeliveryService::cancelDeliveryAsAdmin),
// which every order has from creation — including one still PENDING, before
// a courier has ever been assigned.
const ORDER_CANCELLABLE = ['PENDING', 'CONFIRMED', 'PREPARING', 'READY_FOR_PICKUP'];

export default function OrderDetailPage() {
  const { id } = useParams();
  const orderId = Number(id);
  const queryClient = useQueryClient();

  const { data, isLoading, error } = useQuery({
    queryKey: ['orders', orderId],
    queryFn: () => ordersApi.get(orderId),
  });

  const cancel = useMutation({
    mutationFn: () => deliveriesApi.cancel(data!.deliveryId!),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['orders', orderId] });
      queryClient.invalidateQueries({ queryKey: ['deliveries'] });
    },
  });

  const handleCancel = () => {
    if (window.confirm(`Cancel order #${orderId}? This cannot be undone.`)) {
      cancel.mutate();
    }
  };

  return (
    <>
      <PageHeader title={data ? `Order #${data.id}` : 'Order'} />
      <div className="content">
        <Breadcrumb items={[{ label: 'Orders', to: '/orders' }, { label: data ? `#${data.id}` : '…' }]} />
        <ErrorBanner error={error || cancel.error} />
        {isLoading ? (
          <Loading />
        ) : data ? (
          <>
            <div className="form-card" style={{ marginBottom: 20 }}>
              <div className="detail-grid">
                <div className="detail-item">
                  <div className="field-label">Status</div>
                  <div className="value">
                    <StatusBadge status={data.status} />
                  </div>
                </div>
                <div className="detail-item">
                  <div className="field-label">Placed</div>
                  <div className="value">{formatDate(data.createdAt)}</div>
                </div>
                <div className="detail-item">
                  <div className="field-label">Customer</div>
                  <div className="value">
                    {data.userName} &middot; {data.userPhone}
                  </div>
                </div>
                <div className="detail-item">
                  <div className="field-label">{data.restaurantName ? 'Restaurant' : 'Pickup address'}</div>
                  <div className="value">{data.restaurantName ?? data.pickupAddress}</div>
                </div>
                <div className="detail-item">
                  <div className="field-label">Service</div>
                  <div className="value">{deliveryTypeLabel(data.deliveryType)}</div>
                </div>
                <div className="detail-item">
                  <div className="field-label">Delivery address</div>
                  <div className="value">{data.deliveryAddress}</div>
                </div>
                {data.recipientName && (
                  <div className="detail-item">
                    <div className="field-label">Recipient</div>
                    <div className="value">
                      {data.recipientName}
                      {data.recipientPhone ? <> &middot; {data.recipientPhone}</> : null}
                    </div>
                  </div>
                )}
                <div className="detail-item">
                  <div className="field-label">Delivery zone</div>
                  <div className="value">
                    {data.deliveryZoneName} ({money(data.deliveryFee)})
                  </div>
                </div>
                {data.note && (
                  <div className="detail-item" style={{ gridColumn: '1 / -1' }}>
                    <div className="field-label">Note</div>
                    <div className="value">{data.note}</div>
                  </div>
                )}
              </div>

              <div style={{ display: 'flex', gap: 10 }}>
                {data.deliveryId && (
                  <Link to={`/deliveries/${data.deliveryId}`} className="btn ghost sm">
                    View delivery #{data.deliveryId}
                  </Link>
                )}
                {ORDER_CANCELLABLE.includes(data.status) && (
                  <button
                    type="button"
                    className="btn danger sm"
                    disabled={cancel.isPending || !data.deliveryId}
                    onClick={handleCancel}
                  >
                    {cancel.isPending ? 'Cancelling…' : 'Cancel order'}
                  </button>
                )}
              </div>
            </div>

            <div className="card">
              <table>
                <thead>
                  <tr>
                    <th>Item</th>
                    <th>Qty</th>
                    <th>Unit price</th>
                    <th>Line total</th>
                  </tr>
                </thead>
                <tbody>
                  {data.items.map((item) => (
                    <tr key={item.id}>
                      <td className="rname">{item.productName}</td>
                      <td>{item.quantity}</td>
                      <td>{money(item.unitPrice)}</td>
                      <td>
                        {money((Number(item.unitPrice) * item.quantity).toFixed(3))}
                      </td>
                    </tr>
                  ))}
                  <tr>
                    <td colSpan={3} style={{ textAlign: 'right', fontWeight: 700 }}>
                      Delivery fee
                    </td>
                    <td style={{ fontWeight: 700 }}>{money(data.deliveryFee)}</td>
                  </tr>
                  <tr>
                    <td colSpan={3} style={{ textAlign: 'right', fontWeight: 700 }}>
                      Total
                    </td>
                    <td style={{ fontWeight: 700 }}>{money(data.totalAmount)}</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </>
        ) : null}
      </div>
    </>
  );
}
