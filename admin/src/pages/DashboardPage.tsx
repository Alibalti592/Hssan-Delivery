import { useQuery } from '@tanstack/react-query';
import { restaurantsApi, deliveryZonesApi, couriersApi, ordersApi } from '../api/resources';
import { PageHeader, Loading, ErrorBanner } from '../components/ui';

export default function DashboardPage() {
  const restaurants = useQuery({ queryKey: ['restaurants'], queryFn: restaurantsApi.list });
  const zones = useQuery({ queryKey: ['delivery-zones'], queryFn: deliveryZonesApi.list });
  const couriers = useQuery({ queryKey: ['couriers'], queryFn: couriersApi.list });
  const orders = useQuery({ queryKey: ['orders'], queryFn: ordersApi.list });

  const isLoading =
    restaurants.isLoading || zones.isLoading || couriers.isLoading || orders.isLoading;
  const error = restaurants.error || zones.error || couriers.error || orders.error;

  const pendingOrders =
    orders.data?.filter((o) => !['COMPLETED', 'CANCELLED'].includes(o.status)).length ?? 0;

  return (
    <>
      <PageHeader title="Dashboard" subtitle="Overview" />
      <div className="content">
        <ErrorBanner error={error} />
        {isLoading ? (
          <Loading />
        ) : (
          <div className="stats">
            <div className="stcard">
              <div className="stval">{restaurants.data?.length ?? 0}</div>
              <div className="stlabel">Restaurants</div>
            </div>
            <div className="stcard">
              <div className="stval">{zones.data?.length ?? 0}</div>
              <div className="stlabel">Delivery Zones</div>
            </div>
            <div className="stcard">
              <div className="stval">{couriers.data?.length ?? 0}</div>
              <div className="stlabel">Couriers</div>
            </div>
            <div className="stcard">
              <div className="stval">{orders.data?.length ?? 0}</div>
              <div className="stlabel">Total Orders</div>
            </div>
            <div className="stcard">
              <div className="stval">{pendingOrders}</div>
              <div className="stlabel">Active Orders</div>
            </div>
          </div>
        )}
      </div>
    </>
  );
}
