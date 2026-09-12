import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { deliveriesApi, couriersApi } from '../../api/resources';
import {
  PageHeader,
  Loading,
  ErrorBanner,
  EmptyState,
  StatusBadge,
  Pagination,
  formatDate,
} from '../../components/ui';

export default function DeliveriesListPage() {
  const [page, setPage] = useState(1);
  const deliveries = useQuery({
    queryKey: ['deliveries', page],
    queryFn: () => deliveriesApi.list({ page }),
  });
  // Used only to resolve courier names for display, not as its own list —
  // fetched at the max page size since the admin-managed courier roster is
  // realistically bounded, unlike deliveries/orders which grow unbounded.
  const couriers = useQuery({ queryKey: ['couriers', 'all'], queryFn: () => couriersApi.list({ limit: 100 }) });

  const courierName = (courierId: number | null) =>
    courierId ? couriers.data?.items.find((c) => c.id === courierId)?.name ?? `#${courierId}` : '—';

  return (
    <>
      <PageHeader title="Deliveries" subtitle={`${deliveries.data?.meta.total ?? 0} deliveries`} />
      <div className="content">
        <ErrorBanner error={deliveries.error} />
        {deliveries.isLoading ? (
          <Loading />
        ) : !deliveries.data || deliveries.data.items.length === 0 ? (
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
                {deliveries.data.items.map((d) => (
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
            <Pagination
              page={deliveries.data.meta.page}
              pages={deliveries.data.meta.pages}
              total={deliveries.data.meta.total}
              onPageChange={setPage}
            />
          </div>
        )}
      </div>
    </>
  );
}
