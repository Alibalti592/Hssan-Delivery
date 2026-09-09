import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { deliveriesApi, couriersApi } from '../../api/resources';
import { PageHeader, Loading, ErrorBanner, EmptyState, StatusBadge, formatDate } from '../../components/ui';

export default function DeliveriesListPage() {
  const deliveries = useQuery({ queryKey: ['deliveries'], queryFn: deliveriesApi.list });
  const couriers = useQuery({ queryKey: ['couriers'], queryFn: couriersApi.list });

  const courierName = (courierId: number | null) =>
    courierId ? couriers.data?.find((c) => c.id === courierId)?.name ?? `#${courierId}` : '—';

  return (
    <>
      <PageHeader title="Deliveries" subtitle={`${deliveries.data?.length ?? 0} deliveries`} />
      <div className="content">
        <ErrorBanner error={deliveries.error} />
        {deliveries.isLoading ? (
          <Loading />
        ) : !deliveries.data || deliveries.data.length === 0 ? (
          <EmptyState>No deliveries yet.</EmptyState>
        ) : (
          <div className="card">
            <table>
              <thead>
                <tr>
                  <th>Delivery</th>
                  <th>Order</th>
                  <th>Courier</th>
                  <th>Status</th>
                  <th>Created</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {deliveries.data.map((d) => (
                  <tr key={d.id}>
                    <td className="rname">#{d.id}</td>
                    <td>
                      <Link to={`/orders/${d.orderId}`}>#{d.orderId}</Link>
                    </td>
                    <td>{courierName(d.courierId)}</td>
                    <td>
                      <StatusBadge status={d.status} />
                    </td>
                    <td>{formatDate(d.createdAt)}</td>
                    <td>
                      <Link to={`/deliveries/${d.id}`} className="btn ghost sm">
                        Manage
                      </Link>
                    </td>
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
