import { useQuery } from '@tanstack/react-query';
import { statsApi } from '../api/resources';
import { PageHeader, Loading, ErrorBanner } from '../components/ui';

export default function DashboardPage() {
  const stats = useQuery({ queryKey: ['stats'], queryFn: statsApi.summary });

  return (
    <>
      <PageHeader title="Dashboard" subtitle="Overview" />
      <div className="content">
        <ErrorBanner error={stats.error} />
        {stats.isLoading ? (
          <Loading />
        ) : (
          <div className="stats">
            <div className="stcard">
              <div className="stval">{stats.data?.restaurants ?? 0}</div>
              <div className="stlabel">Restaurants</div>
            </div>
            <div className="stcard">
              <div className="stval">{stats.data?.deliveryZones ?? 0}</div>
              <div className="stlabel">Delivery Zones</div>
            </div>
            <div className="stcard">
              <div className="stval">{stats.data?.couriers ?? 0}</div>
              <div className="stlabel">Couriers</div>
            </div>
            <div className="stcard">
              <div className="stval">{stats.data?.totalOrders ?? 0}</div>
              <div className="stlabel">Total Orders</div>
            </div>
            <div className="stcard">
              <div className="stval">{stats.data?.activeOrders ?? 0}</div>
              <div className="stlabel">Active Orders</div>
            </div>
          </div>
        )}
      </div>
    </>
  );
}
