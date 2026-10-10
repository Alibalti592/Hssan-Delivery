import { useEffect, useState } from 'react';
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

/** The time now, ticking every 30 s so waiting times keep counting up. */
function useNow(): number {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), 30_000);
    return () => clearInterval(timer);
  }, []);
  return now;
}

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

/** Distance in km between two points (haversine). */
function distanceKm(a: [number, number], b: [number, number]): number {
  const rad = Math.PI / 180;
  const dLat = (b[0] - a[0]) * rad;
  const dLng = (b[1] - a[1]) * rad;
  const h =
    Math.sin(dLat / 2) ** 2 + Math.cos(a[0] * rad) * Math.cos(b[0] * rad) * Math.sin(dLng / 2) ** 2;
  return 2 * 6371 * Math.asin(Math.sqrt(h));
}

function formatKm(km: number): string {
  return km < 1 ? `${Math.max(50, Math.round(km * 20) * 50)} m` : `${km.toFixed(1)} km`;
}

/** Where the courier goes first: the pickup pin, else the drop-off pin. */
function firstStop(delivery: WaitingDelivery): [number, number] | null {
  const o = delivery.order;
  if (!o) return null;
  if (o.pickupLatitude != null && o.pickupLongitude != null) return [o.pickupLatitude, o.pickupLongitude];
  if (o.deliveryLatitude != null && o.deliveryLongitude != null) return [o.deliveryLatitude, o.deliveryLongitude];
  return null;
}

type Candidate = {
  courier: Courier;
  status: CourierMapStatus;
  position: [number, number] | null;
};

type Option = Candidate & { km: number | null };

/**
 * The couriers for one order, best first: online (free) before busy before
 * offline, and nearest first among the online ones when both positions are
 * known. The first online one is the suggestion.
 */
function rank(candidates: Candidate[], stop: [number, number] | null): Option[] {
  return candidates
    .map((c) => ({ ...c, km: stop && c.position ? distanceKm(c.position, stop) : null }))
    .sort((a, b) => {
      const byStatus = STATUS_ORDER.indexOf(a.status) - STATUS_ORDER.indexOf(b.status);
      if (byStatus !== 0) return byStatus;
      if (a.km !== null && b.km !== null) return a.km - b.km;
      if (a.km !== null) return -1;
      if (b.km !== null) return 1;
      return a.courier.name.localeCompare(b.courier.name);
    });
}

/**
 * Orders no courier has yet, oldest first, each with the nearest available
 * courier already chosen: one click on "Assign" gives it to them. Another
 * courier can be picked from the list first.
 */
export function DispatchQueue() {
  const waiting = useWaitingDeliveries();
  const queue = waiting.data ?? [];
  // The courier picker only matters while something is waiting.
  const hasWaiting = queue.length > 0;
  const couriers = useQuery({
    queryKey: ['couriers', 'all'],
    queryFn: () => couriersApi.list({ limit: 100 }),
    enabled: hasWaiting,
  });
  const locations = useQuery({
    queryKey: ['courier-locations'],
    queryFn: courierLocationsApi.list,
    refetchInterval: 15_000,
    enabled: hasWaiting,
  });

  const locationById = new Map(locations.data?.map((l) => [l.courierId, l]) ?? []);
  const candidates: Candidate[] = (couriers.data?.items ?? [])
    .filter((c) => c.isActive && c.verified)
    .map((c) => {
      const l = locationById.get(c.id);
      return {
        courier: c,
        status: l?.status ?? ('OFFLINE' as CourierMapStatus),
        position: l && l.latitude !== null && l.longitude !== null ? [l.latitude, l.longitude] : null,
      };
    });
  const onlineCount = candidates.filter((c) => c.status === 'ONLINE').length;

  const now = useNow();

  return (
    <section className="dispatch">
      <div className="dispatch-head">
        <h2>
          Waiting for a courier{' '}
          {queue.length > 0 && <span className="badge warn">{queue.length}</span>}
          {hasWaiting && couriers.data && (
            <span className="dispatch-online">
              {onlineCount === 0 ? 'No courier online' : `${onlineCount} courier${onlineCount === 1 ? '' : 's'} online`}
            </span>
          )}
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
                  options={rank(candidates, firstStop(delivery))}
                />
              ))}
            </tbody>
          </table>
        )}
      </div>
    </section>
  );
}

function optionLabel({ courier, status, km }: Option): string {
  return [courier.name, STATUS_LABEL[status], km !== null ? `${formatKm(km)} away` : null]
    .filter(Boolean)
    .join(' · ');
}

function QueueRow({
  delivery,
  now,
  options,
}: {
  delivery: WaitingDelivery;
  now: number;
  options: Option[];
}) {
  const queryClient = useQueryClient();
  // Null: follow the suggestion, which moves as couriers come online.
  const [picked, setPicked] = useState<string | null>(null);
  const suggestion = options.find((o) => o.status === 'ONLINE') ?? null;
  const courierId = picked ?? (suggestion ? String(suggestion.courier.id) : '');
  const chosen = options.find((o) => String(o.courier.id) === courierId) ?? null;
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
            onChange={(e) => setPicked(e.target.value)}
            disabled={assign.isPending}
          >
            <option value="">Choose a courier…</option>
            {options.map((o) => (
              <option key={o.courier.id} value={o.courier.id}>
                {optionLabel(o)}
                {suggestion?.courier.id === o.courier.id ? ' (nearest)' : ''}
              </option>
            ))}
          </select>
          <button
            type="button"
            className="btn sm"
            disabled={!courierId || assign.isPending}
            onClick={() => assign.mutate()}
          >
            {assign.isPending ? 'Assigning…' : chosen ? `Assign ${chosen.courier.name.split(' ')[0]}` : 'Assign'}
          </button>
        </div>
        {assign.error && <div className="rmeta" style={{ color: '#9b2c2c' }}>{(assign.error as Error).message}</div>}
      </td>
    </tr>
  );
}

const STEP_LABEL: Partial<Record<WaitingDelivery['status'], string>> = {
  ASSIGNED: 'Not accepted yet',
  ACCEPTED: 'Going to pick up',
  PICKED_UP: 'Picked up',
  ON_THE_WAY: 'On the way',
};

/** Orders a courier has, until delivered: who has it and how far along. */
export function OnTheirWay() {
  const active = useQuery({
    queryKey: ['deliveries', 'active'],
    queryFn: deliveriesApi.active,
    refetchInterval: 20_000,
  });
  const now = useNow();
  const list = active.data ?? [];

  return (
    <section className="dispatch">
      <div className="dispatch-head">
        <h2>
          On their way {list.length > 0 && <span className="badge muted">{list.length}</span>}
        </h2>
        <Link to="/courier-map" className="btn ghost sm">
          Courier map
        </Link>
      </div>
      <ErrorBanner error={active.error} />
      <div className="card">
        {list.length === 0 ? (
          <div className="dispatch-empty">
            {active.isLoading ? 'Loading…' : active.error ? 'Could not load these orders.' : 'No order is out for delivery right now.'}
          </div>
        ) : (
          <table>
            <thead>
              <tr>
                <th>Order</th>
                <th>Deliver to</th>
                <th>Courier</th>
                <th>Step</th>
                <th>Since</th>
              </tr>
            </thead>
            <tbody>
              {list.map((delivery) => (
                <tr key={delivery.id}>
                  <td>
                    <Link to={`/deliveries/${delivery.id}`} className="rname">
                      {describe(delivery)}
                    </Link>
                    <div className="rmeta">
                      #{delivery.orderId} · {delivery.order?.customerName ?? ''}
                    </div>
                  </td>
                  <td>{delivery.order?.deliveryAddress ?? '—'}</td>
                  <td>{delivery.courierName ?? '—'}</td>
                  <td>
                    <span className={`badge${delivery.status === 'ASSIGNED' ? ' warn' : ''}`}>
                      {STEP_LABEL[delivery.status] ?? delivery.status}
                    </span>
                  </td>
                  <td>{waitingFor(delivery.createdAt, now)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </section>
  );
}
