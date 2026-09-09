import { useQuery } from '@tanstack/react-query';
import { Link, useParams } from 'react-router-dom';
import { ordersApi } from '../../api/resources';
import { PageHeader, Loading, ErrorBanner, Breadcrumb, StatusBadge, money, formatDate } from '../../components/ui';

export default function OrderDetailPage() {
  const { id } = useParams();
  const orderId = Number(id);

  const { data, isLoading, error } = useQuery({
    queryKey: ['orders', orderId],
    queryFn: () => ordersApi.get(orderId),
  });

  return (
    <>
      <PageHeader title={data ? `Order #${data.id}` : 'Order'} />
      <div className="content">
        <Breadcrumb items={[{ label: 'Orders', to: '/orders' }, { label: data ? `#${data.id}` : '…' }]} />
        <ErrorBanner error={error} />
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
                  <div className="field-label">Restaurant</div>
                  <div className="value">{data.restaurantName}</div>
                </div>
                <div className="detail-item">
                  <div className="field-label">Delivery address</div>
                  <div className="value">{data.deliveryAddress}</div>
                </div>
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

              {data.deliveryId && (
                <Link to={`/deliveries/${data.deliveryId}`} className="btn ghost sm">
                  View delivery #{data.deliveryId}
                </Link>
              )}
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
