import { useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { ordersApi } from '../../api/resources';
import {
  PageHeader,
  Loading,
  ErrorBanner,
  EmptyState,
  StatusBadge,
  Pagination,
  money,
  formatDate,
} from '../../components/ui';

export default function OrdersListPage() {
  const [page, setPage] = useState(1);
  const { data, isLoading, error } = useQuery({
    queryKey: ['orders', page],
    queryFn: () => ordersApi.list({ page }),
  });

  return (
    <>
      <PageHeader title="Orders" subtitle={`${data?.meta.total ?? 0} orders`} />
      <div className="content">
        <ErrorBanner error={error} />
        {isLoading ? (
          <Loading />
        ) : !data || data.items.length === 0 ? (
          <EmptyState>No orders yet.</EmptyState>
        ) : (
          <div className="card">
            <table>
              <thead>
                <tr>
                  <th>Order</th>
                  <th>Customer</th>
                  <th>Restaurant</th>
                  <th>Total</th>
                  <th>Status</th>
                  <th>Placed</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {data.items.map((o) => (
                  <tr key={o.id}>
                    <td className="rname">#{o.id}</td>
                    <td>
                      {o.userName}
                      <div className="rmeta">{o.userPhone}</div>
                    </td>
                    <td>{o.restaurantName}</td>
                    <td>{money(o.totalAmount)}</td>
                    <td>
                      <StatusBadge status={o.status} />
                    </td>
                    <td>{formatDate(o.createdAt)}</td>
                    <td>
                      <Link to={`/orders/${o.id}`} className="btn ghost sm">
                        View
                      </Link>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
            <Pagination
              page={data.meta.page}
              pages={data.meta.pages}
              total={data.meta.total}
              onPageChange={setPage}
            />
          </div>
        )}
      </div>
    </>
  );
}
