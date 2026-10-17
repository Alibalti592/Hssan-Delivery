import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { statsApi } from '../api/resources';
import { PageHeader, ErrorBanner, money } from '../components/ui';
import { DispatchQueue, OnTheirWay, useActiveDeliveries, useCourierLocations } from '../components/DispatchQueue';
import { useWaitingDeliveries } from '../components/dispatch';

/** One live figure at the top; the whole tile links to where it's handled. */
function Kpi({
  label,
  value,
  sub,
  to,
  tone,
}: {
  label: string;
  value: string | number;
  sub?: string;
  to: string;
  tone?: 'alert' | 'good';
}) {
  return (
    <Link to={to} className={`kpi${tone ? ` kpi-${tone}` : ''}`}>
      <div className="kpi-value">{value}</div>
      <div className="kpi-label">{label}</div>
      {sub && <div className="kpi-sub">{sub}</div>}
    </Link>
  );
}

export default function DashboardPage() {
  const stats = useQuery({ queryKey: ['stats'], queryFn: statsApi.summary, refetchInterval: 60_000 });
  const waiting = useWaitingDeliveries();
  const active = useActiveDeliveries();
  const locations = useCourierLocations();

  const waitingCount = waiting.data?.length ?? 0;
  const expressWaiting = waiting.data?.filter((d) => d.order?.deliverySpeed === 'EXPRESS').length ?? 0;
  const activeCount = active.data?.length ?? 0;
  const couriers = locations.data ?? [];
  const free = couriers.filter((c) => c.status === 'ONLINE').length;
  const busy = couriers.filter((c) => c.status === 'ON_DELIVERY').length;
  const s = stats.data;
  const updated = waiting.dataUpdatedAt
    ? new Date(waiting.dataUpdatedAt).toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    : null;

  return (
    <>
      <PageHeader
        title="Dashboard"
        subtitle={updated ? `Live · updated ${updated}` : 'Live'}
      />
      <div className="content">
        <div className="kpis">
          <Kpi
            label="Waiting for a courier"
            value={waitingCount}
            sub={expressWaiting > 0 ? `${expressWaiting} express` : waitingCount === 0 ? 'All assigned' : undefined}
            to="/deliveries"
            tone={waitingCount > 0 ? 'alert' : 'good'}
          />
          <Kpi label="On their way" value={activeCount} to="/deliveries" />
          <Kpi
            label="Couriers working"
            value={free + busy}
            sub={`${free} free · ${busy} busy · ${couriers.length} in all`}
            to="/courier-map"
          />
          <Kpi
            label="Orders today"
            value={s?.todayOrders ?? '—'}
            sub={s?.todayCompleted !== undefined ? `${s.todayCompleted} delivered` : undefined}
            to="/orders"
          />
          <Kpi label="Sales today" value={s?.todaySales !== undefined ? money(s.todaySales) : '—'} to="/orders" />
        </div>

        <DispatchQueue />
        <OnTheirWay />

        <ErrorBanner error={stats.error} />
        {s && (
          <div className="dash-footer">
            {s.restaurants} restaurants · {s.deliveryZones} delivery zones · {s.couriers} couriers ·{' '}
            {s.totalOrders} orders in all · {s.activeOrders} in progress
          </div>
        )}
      </div>
    </>
  );
}
