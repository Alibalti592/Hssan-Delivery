import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { ordersApi } from '../../api/resources';
import { PageHeader, Loading, ErrorBanner, EmptyState, StatusBadge, money, formatDate } from '../../components/ui';

export default function OrdersListPage() {
  const { data, isLoading, error } = useQuery({ queryKey: ['orders'], queryFn: ordersApi.list });

  return (
    <>
      <PageHeader title="Orders" subtitle={`${data?.length ?? 0} orders`} />
      <div className="content">
        <ErrorBanner error={error} />
        {isLoading ? (
          <Loading />
        ) : !data || data.length === 0 ? (
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
                {data.map((o) => (
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
          </div>
        )}
      </div>
    </>
  );
}
