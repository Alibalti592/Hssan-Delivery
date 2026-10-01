import { useState } from 'react';
import { Link } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { courierLocationsApi, couriersApi, deliveriesApi } from '../api/resources';
import type { Courier, CourierMapStatus, WaitingDelivery } from '../api/types';
import { ErrorBanner, deliveryTypeLabel, money } from './ui';
import { useWaitingDeliveries } from './dispatch';

const STATUS_LABEL: Record<CourierMapStatus, string> = {
  ONLINE: 'online',
  ON_DELIVERY: 'on a delivery',
  OFFLINE: 'offline',
};

const STATUS_ORDER: CourierMapStatus[] = ['ONLINE', 'ON_DELIVERY', 'OFFLINE'];

/** "4 min", "1 h 05". */
function waitingFor(createdAt: string | null, now: number): string {
  if (!createdAt) return '—';
  const minutes = Math.max(0, Math.floor((now - new Date(createdAt).getTime()) / 60_000));
  if (minutes < 60) return `${minutes} min`;
  return `${Math.floor(minutes / 60)} h ${String(minutes % 60).padStart(2, '0')}`;
}

/** What the order is: the restaurant, "Facture STEG", "Colis". */
function describe(delivery: WaitingDelivery): string {
  const order = delivery.order;
  if (!order) return `Delivery #${delivery.id}`;
  if (order.bill) return `${order.bill.providerKind === 'TRANSFER' ? 'Mandat' : 'Facture'} ${order.bill.providerName}`;
  return order.restaurantName ?? deliveryTypeLabel(order.deliveryType);
}

/**
 * Orders no courier has yet, oldest first, each assignable right here:
 * couriers who are online come first in the list.
 */
export function DispatchQueue() {
  const waiting = useWaitingDeliveries();
  const couriers = useQuery({ queryKey: ['couriers', 'all'], queryFn: () => couriersApi.list({ limit: 100 }) });
  const locations = useQuery({ queryKey: ['courier-locations'], queryFn: courierLocationsApi.list, refetchInterval: 30_000 });

  const statusById = new Map(locations.data?.map((l) => [l.courierId, l.status]) ?? []);
  const assignable = (couriers.data?.items ?? [])
    .filter((c) => c.isActive && c.verified)
    .map((c) => ({ courier: c, status: statusById.get(c.id) ?? ('OFFLINE' as CourierMapStatus) }))
    .sort((a, b) => STATUS_ORDER.indexOf(a.status) - STATUS_ORDER.indexOf(b.status));

  const queue = waiting.data ?? [];
  const now = Date.now();

  return (
    <section className="dispatch">
      <div className="dispatch-head">
        <h2>
          Waiting for a courier{' '}
          {queue.length > 0 && <span className="badge warn">{queue.length}</span>}
        </h2>
        <Link to="/deliveries" className="btn ghost sm">
          All deliveries
        </Link>
      </div>
      <ErrorBanner error={waiting.error} />
      <div className="card">
        {queue.length === 0 ? (
          <div className="dispatch-empty">
            {waiting.isLoading ? 'Loading…' : 'No order is waiting: every order has a courier.'}
          </div>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Order</th>
                <th>Deliver to</th>
                <th>Total</th>
                <th>Waiting</th>
                <th>Courier</th>
              </tr>
            </thead>
            <tbody>
              {queue.map((delivery) => (
                <QueueRow
                  key={delivery.id}
                  delivery={delivery}
                  now={now}
                  couriers={assignable}
                />
              ))}
            </tbody>
          </table>
        )}
      </div>
    </section>
  );
}

function QueueRow({
  delivery,
  now,
  couriers,
}: {
  delivery: WaitingDelivery;
  now: number;
  couriers: { courier: Courier; status: CourierMapStatus }[];
}) {
  const queryClient = useQueryClient();
  const [courierId, setCourierId] = useState('');
  const assign = useMutation({
    mutationFn: () => deliveriesApi.assign(delivery.id, Number(courierId)),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['deliveries'] });
      queryClient.invalidateQueries({ queryKey: ['orders'] });
      queryClient.invalidateQueries({ queryKey: ['courier-locations'] });
    },
  });
  const minutes = delivery.createdAt ? (now - new Date(delivery.createdAt).getTime()) / 60_000 : 0;

  return (
    <tr>
      <td>
        <Link to={`/deliveries/${delivery.id}`} className="rname">
          {describe(delivery)}
        </Link>
        <div className="rmeta">
          #{delivery.orderId} · {delivery.order?.customerName ?? ''}
        </div>
      </td>
      <td>{delivery.order?.deliveryAddress ?? '—'}</td>
      <td>{delivery.order ? money(delivery.order.totalAmount) : '—'}</td>
      <td>
        <span className={`badge${minutes >= 10 ? ' closed' : minutes >= 5 ? ' warn' : ' muted'}`}>
          {waitingFor(delivery.createdAt, now)}
        </span>
      </td>
      <td>
        <div className="dispatch-assign">
          <select
            className="field-select"
            aria-label={`Courier for delivery ${delivery.id}`}
            value={courierId}
            onChange={(e) => setCourierId(e.target.value)}
            disabled={assign.isPending}
          >
            <option value="">Choose a courier…</option>
            {couriers.map(({ courier, status }) => (
              <option key={courier.id} value={courier.id}>
                {courier.name} ({STATUS_LABEL[status]})
              </option>
            ))}
          </select>
          <button
            type="button"
            className="btn sm"
            disabled={!courierId || assign.isPending}
            onClick={() => assign.mutate()}
          >
            {assign.isPending ? 'Assigning…' : 'Assign'}
          </button>
        </div>
        {assign.error && <div className="rmeta" style={{ color: '#9b2c2c' }}>{(assign.error as Error).message}</div>}
      </td>
    </tr>
  );
}
