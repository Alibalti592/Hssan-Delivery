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

/** Where every courier is and how busy, refreshed every 15 s. */
export function useCourierLocations() {
  return useQuery({
    queryKey: ['courier-locations'],
    queryFn: courierLocationsApi.list,
    refetchInterval: 15_000,
  });
}

/** Orders a courier has but hasn't delivered yet, refreshed every 20 s. */
export function useActiveDeliveries() {
  return useQuery({
    queryKey: ['deliveries', 'active'],
    queryFn: deliveriesApi.active,
    refetchInterval: 20_000,
  });
}

function minutesSince(iso: string | null, now: number): number {
  return iso ? Math.max(0, (now - new Date(iso).getTime()) / 60_000) : 0;
}

/** Waiting too long for a courier: 5 min for express, 10 for standard. */
function isLateToAssign(delivery: WaitingDelivery, now: number): boolean {
  return minutesSince(delivery.createdAt, now) >= (isExpress(delivery) ? 5 : 10);
}

/** Past the time promised to the client: 20 min express, 40 standard. */
function isLateToDeliver(delivery: WaitingDelivery, now: number): boolean {
  return minutesSince(delivery.createdAt, now) > (isExpress(delivery) ? 20 : 40);
}

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

function isExpress(delivery: WaitingDelivery): boolean {
  return delivery.order?.deliverySpeed === 'EXPRESS';
}

/** "Express" next to the order, so it's picked first. */
function ExpressTag() {
  return <span className="badge warn express-tag">⚡ Express · 15–20 min</span>;
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
  /** Orders they already carry. */
  load: number;
};

type Option = Candidate & { km: number | null };

/**
 * The couriers for one order, best first: free before busy (fewest orders
 * first) before offline, then nearest when both positions are known.
 */
function rank(candidates: Candidate[], stop: [number, number] | null): Option[] {
  return candidates
    .map((c) => ({ ...c, km: stop && c.position ? distanceKm(c.position, stop) : null }))
    .sort((a, b) => {
      const byStatus = STATUS_ORDER.indexOf(a.status) - STATUS_ORDER.indexOf(b.status);
      if (byStatus !== 0) return byStatus;
      if (a.load !== b.load) return a.load - b.load;
      if (a.km !== null && b.km !== null) return a.km - b.km;
      if (a.km !== null) return -1;
      if (b.km !== null) return 1;
      return a.courier.name.localeCompare(b.courier.name);
    });
}

/** A free courier first, else the least busy one (couriers can carry several orders). */
function suggest(options: Option[]): Option | null {
  return options.find((o) => o.status === 'ONLINE') ?? options.find((o) => o.status === 'ON_DELIVERY') ?? null;
}

/**
 * Who gets what if every waiting order goes to its nearest courier at once:
 * each pick counts toward that courier's load, so the orders spread out
 * instead of all landing on the same person.
 */
function planAll(queue: WaitingDelivery[], candidates: Candidate[]): { delivery: WaitingDelivery; option: Option }[] {
  const pool = candidates.map((c) => ({ ...c }));
  const plan: { delivery: WaitingDelivery; option: Option }[] = [];
  for (const delivery of queue) {
    const option = suggest(rank(pool, firstStop(delivery)));
    if (!option) continue;
    plan.push({ delivery, option });
    const picked = pool.find((c) => c.courier.id === option.courier.id)!;
    picked.status = 'ON_DELIVERY';
    picked.load += 1;
  }
  return plan;
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
  const locations = useCourierLocations();
  const queryClient = useQueryClient();
  // "Order #7 → Karim": what was just assigned, shown for a few seconds.
  const [flash, setFlash] = useState<string | null>(null);
  useEffect(() => {
    if (!flash) return;
    const timer = setTimeout(() => setFlash(null), 6000);
    return () => clearTimeout(timer);
  }, [flash]);

  const locationById = new Map(locations.data?.map((l) => [l.courierId, l]) ?? []);
  const candidates: Candidate[] = (couriers.data?.items ?? [])
    .filter((c) => c.isActive && c.verified)
    .map((c) => {
      const l = locationById.get(c.id);
      return {
        courier: c,
        status: l?.status ?? ('OFFLINE' as CourierMapStatus),
        position: l && l.latitude !== null && l.longitude !== null ? [l.latitude, l.longitude] : null,
        load: l?.activeDeliveries ?? (l?.currentDeliveryId ? 1 : 0),
      };
    });
  const onlineCount = candidates.filter((c) => c.status === 'ONLINE').length;

  const now = useNow();
  const plan = planAll(queue, candidates);

  const assignAll = useMutation({
    mutationFn: async () => {
      const done: string[] = [];
      for (const { delivery, option } of plan) {
        await deliveriesApi.assign(delivery.id, option.courier.id);
        done.push(`#${delivery.orderId} → ${option.courier.name.split(' ')[0]}`);
      }
      return done;
    },
    onSuccess: (done) => setFlash(`Assigned ${done.join(', ')}`),
    onSettled: () => {
      queryClient.invalidateQueries({ queryKey: ['deliveries'] });
      queryClient.invalidateQueries({ queryKey: ['orders'] });
      queryClient.invalidateQueries({ queryKey: ['courier-locations'] });
    },
  });

  function confirmAssignAll() {
    const lines = plan.map(({ delivery, option }) => `#${delivery.orderId} ${describe(delivery)} → ${option.courier.name}`);
    if (window.confirm(`Assign ${plan.length} order${plan.length === 1 ? '' : 's'}?\n\n${lines.join('\n')}`)) {
      assignAll.mutate();
    }
  }

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
        <div className="dispatch-actions">
          {plan.length > 1 && (
            <button type="button" className="btn sm" onClick={confirmAssignAll} disabled={assignAll.isPending}>
              {assignAll.isPending ? 'Assigning…' : `Assign all ${plan.length} to nearest`}
            </button>
          )}
          <Link to="/deliveries" className="btn ghost sm">
            All deliveries
          </Link>
        </div>
      </div>
      {flash && (
        <div className="dispatch-flash" role="status">
          ✓ {flash}
        </div>
      )}
      <ErrorBanner error={waiting.error || assignAll.error} />
      <div className="card">
        {queue.length === 0 ? (
          <div className="dispatch-empty">
            {waiting.isLoading ? (
              'Loading…'
            ) : (
              <>
                <span className="dispatch-empty-icon" aria-hidden="true">✓</span>
                No order is waiting: every order has a courier.
              </>
            )}
          </div>
        ) : (
          <table className="stack">
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
                  onAssigned={(name) => setFlash(`Order #${delivery.orderId} assigned to ${name}`)}
                />
              ))}
            </tbody>
          </table>
        )}
      </div>
    </section>
  );
}

function optionLabel({ courier, status, km, load }: Option): string {
  const state = status === 'ON_DELIVERY' && load > 0 ? `${load} order${load === 1 ? '' : 's'} on hand` : STATUS_LABEL[status];
  return [courier.name, state, km !== null ? `${formatKm(km)} away` : null]
    .filter(Boolean)
    .join(' · ');
}

function QueueRow({
  delivery,
  now,
  options,
  onAssigned,
}: {
  delivery: WaitingDelivery;
  now: number;
  options: Option[];
  onAssigned: (courierName: string) => void;
}) {
  const queryClient = useQueryClient();
  // Null: follow the suggestion, which moves as couriers come online.
  const [picked, setPicked] = useState<string | null>(null);
  const suggestion = suggest(options);
  const courierId = picked ?? (suggestion ? String(suggestion.courier.id) : '');
  const chosen = options.find((o) => String(o.courier.id) === courierId) ?? null;
  const assign = useMutation({
    mutationFn: () => deliveriesApi.assign(delivery.id, Number(courierId)),
    onSuccess: () => {
      if (chosen) onAssigned(chosen.courier.name);
      queryClient.invalidateQueries({ queryKey: ['deliveries'] });
      queryClient.invalidateQueries({ queryKey: ['orders'] });
      queryClient.invalidateQueries({ queryKey: ['courier-locations'] });
    },
  });
  const minutes = minutesSince(delivery.createdAt, now);
  const late = isLateToAssign(delivery, now);

  return (
    <tr className={late ? 'row-late' : undefined}>
      <td>
        <Link to={`/deliveries/${delivery.id}`} className="rname">
          {describe(delivery)}
        </Link>
        <div className="rmeta">
          #{delivery.orderId} · {delivery.order?.customerName ?? ''}
        </div>
        {isExpress(delivery) && <ExpressTag />}
      </td>
      <td data-label="Deliver to">{delivery.order?.deliveryAddress ?? '—'}</td>
      <td data-label="Total">{delivery.order ? money(delivery.order.totalAmount) : '—'}</td>
      <td data-label="Waiting">
        <span className={`badge${late ? ' closed' : minutes >= 5 ? ' warn' : ' muted'}`}>
          {waitingFor(delivery.createdAt, now)}
        </span>
      </td>
      <td data-label="Courier">
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

const STEPS: WaitingDelivery['status'][] = ['ASSIGNED', 'ACCEPTED', 'PICKED_UP', 'ON_THE_WAY'];

/** Four little bars, filled up to the step the courier is at. */
function StepBar({ status }: { status: WaitingDelivery['status'] }) {
  const reached = STEPS.indexOf(status);
  return (
    <span className="stepbar" aria-hidden="true">
      {STEPS.map((step, i) => (
        <span key={step} className={i <= reached ? 'on' : undefined} />
      ))}
    </span>
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
  const active = useActiveDeliveries();
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
          <table className="stack">
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
                <tr key={delivery.id} className={isLateToDeliver(delivery, now) ? 'row-late' : undefined}>
                  <td>
                    <Link to={`/deliveries/${delivery.id}`} className="rname">
                      {describe(delivery)}
                    </Link>
                    <div className="rmeta">
                      #{delivery.orderId} · {delivery.order?.customerName ?? ''}
                    </div>
                    {isExpress(delivery) && <ExpressTag />}
                  </td>
                  <td data-label="Deliver to">{delivery.order?.deliveryAddress ?? '—'}</td>
                  <td data-label="Courier">{delivery.courierName ?? '—'}</td>
                  <td data-label="Step">
                    <StepBar status={delivery.status} />
                    <span className={`badge${delivery.status === 'ASSIGNED' ? ' warn' : ''}`}>
                      {STEP_LABEL[delivery.status] ?? delivery.status}
                    </span>
                  </td>
                  <td data-label="Since">
                    {waitingFor(delivery.createdAt, now)}
                    {isLateToDeliver(delivery, now) && <span className="badge closed late-tag">Late</span>}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>
    </section>
  );
}
