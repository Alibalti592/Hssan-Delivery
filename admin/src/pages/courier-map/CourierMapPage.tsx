import { useEffect, useMemo, useRef, useState } from 'react';
import { useQuery } from '@tanstack/react-query';
import { MapContainer, Marker, Popup, TileLayer, useMap } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { Link } from 'react-router-dom';
import { courierLocationsApi } from '../../api/resources';
import type { CourierLocationEntry, CourierMapStatus } from '../../api/types';
import { PageHeader, Loading, ErrorBanner, NoteBanner } from '../../components/ui';

// Bizerte, where the service runs — until a courier reports a position.
const DEFAULT_CENTER: [number, number] = [37.2744, 9.8739];

const STATUS_COLOR: Record<CourierMapStatus, string> = {
  ONLINE: '#22c55e',
  ON_DELIVERY: '#3b82f6',
  OFFLINE: '#9ca3af',
};

const STATUS_LABEL: Record<CourierMapStatus, string> = {
  ONLINE: 'Online',
  ON_DELIVERY: 'On delivery',
  OFFLINE: 'Offline',
};

function markerIcon(status: CourierMapStatus): L.DivIcon {
  const color = STATUS_COLOR[status];

  return L.divIcon({
    className: 'courier-marker',
    html: `<span style="display:block;width:16px;height:16px;border-radius:50%;background:${color};border:2px solid #fff;box-shadow:0 0 0 1px rgba(0,0,0,0.25)"></span>`,
    iconSize: [16, 16],
    iconAnchor: [8, 8],
  });
}

function timeAgo(iso: string | null): string {
  if (!iso) return 'never';

  const seconds = Math.max(0, Math.floor((Date.now() - new Date(iso).getTime()) / 1000));

  if (seconds < 60) return 'just now';
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes} minute${minutes === 1 ? '' : 's'} ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours} hour${hours === 1 ? '' : 's'} ago`;
  const days = Math.floor(hours / 24);
  return `${days} day${days === 1 ? '' : 's'} ago`;
}

/**
 * Frames every located courier — once at first, then again only when a
 * courier appears or leaves, so the 12 s refresh doesn't undo the admin's
 * own panning. [focus] flies to one courier picked from the list.
 */
function FrameCouriers({
  located,
  focus,
}: {
  located: CourierLocationEntry[];
  focus: CourierLocationEntry | null;
}) {
  const map = useMap();
  const framedIds = useRef<string | null>(null);

  useEffect(() => {
    const ids = located
      .map((c) => c.courierId)
      .sort((a, b) => a - b)
      .join(',');
    if (located.length === 0 || ids === framedIds.current) return;
    framedIds.current = ids;
    const points = located.map((c) => [c.latitude as number, c.longitude as number] as [number, number]);
    if (points.length === 1) {
      map.setView(points[0], 15);
    } else {
      map.fitBounds(L.latLngBounds(points), { padding: [40, 40], maxZoom: 15 });
    }
  }, [located, map]);

  useEffect(() => {
    if (focus?.latitude != null && focus.longitude != null) {
      map.flyTo([focus.latitude, focus.longitude], 16);
    }
  }, [focus, map]);

  return null;
}

export default function CourierMapPage() {
  const [focus, setFocus] = useState<CourierLocationEntry | null>(null);
  const { data, isLoading, error } = useQuery({
    queryKey: ['courier-locations'],
    queryFn: courierLocationsApi.list,
    // Best-effort "how's everyone doing right now" view, not real-time
    // tracking — see backend CourierLocationService. Polling instead of a
    // WebSocket, matching the project's current infra.
    refetchInterval: 12000,
  });

  const located = useMemo<CourierLocationEntry[]>(
    () => (data ?? []).filter((c) => c.latitude !== null && c.longitude !== null),
    [data],
  );

  // On delivery first, then online, then offline; by name within each.
  const listed = useMemo(() => {
    const rank: Record<CourierMapStatus, number> = { ON_DELIVERY: 0, ONLINE: 1, OFFLINE: 2 };
    return [...(data ?? [])].sort(
      (a, b) => rank[a.status] - rank[b.status] || a.name.localeCompare(b.name),
    );
  }, [data]);

  const counts = useMemo(() => {
    const list = data ?? [];
    return {
      total: list.length,
      online: list.filter((c) => c.status === 'ONLINE').length,
      onDelivery: list.filter((c) => c.status === 'ON_DELIVERY').length,
      offline: list.filter((c) => c.status === 'OFFLINE').length,
    };
  }, [data]);

  return (
    <>
      <PageHeader title="Courier Map" subtitle="Last known courier locations" />
      <div className="content">
        <ErrorBanner error={error} />
        <NoteBanner>
          A courier shows here while their app is open and they are available (or on a
          delivery): it reports their position every 20 seconds. Without a report for 5 minutes
          they show as offline, at their last known position.
        </NoteBanner>

        {isLoading ? (
          <Loading />
        ) : (
          <>
            <div className="stats">
              <div className="stcard">
                <div className="stval">{counts.total}</div>
                <div className="stlabel">Couriers</div>
              </div>
              <div className="stcard">
                <div className="stval">{counts.online}</div>
                <div className="stlabel">Online</div>
              </div>
              <div className="stcard">
                <div className="stval">{counts.onDelivery}</div>
                <div className="stlabel">On delivery</div>
              </div>
              <div className="stcard">
                <div className="stval">{counts.offline}</div>
                <div className="stlabel">Offline</div>
              </div>
            </div>

            <div className="card" style={{ padding: 0, overflow: 'hidden' }}>
              <MapContainer center={DEFAULT_CENTER} zoom={13} style={{ height: 480, width: '100%' }}>
                <FrameCouriers located={located} focus={focus} />
                <TileLayer
                  attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors'
                  url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
                />
                {located.map((courier) => (
                  <Marker
                    key={courier.courierId}
                    position={[courier.latitude as number, courier.longitude as number]}
                    icon={markerIcon(courier.status)}
                  >
                    <Popup>
                      <strong>{courier.name}</strong>
                      <br />
                      Status: {STATUS_LABEL[courier.status]}
                      <br />
                      Last updated: {timeAgo(courier.updatedAt)}
                      {courier.currentDeliveryId && (
                        <>
                          <br />
                          <Link to={`/deliveries/${courier.currentDeliveryId}`}>
                            View current delivery
                          </Link>
                        </>
                      )}
                    </Popup>
                  </Marker>
                ))}
              </MapContainer>
            </div>

            {listed.length > 0 && (
              <div className="card" style={{ marginTop: 16 }}>
                <table>
                  <thead>
                    <tr>
                      <th>Courier</th>
                      <th>Status</th>
                      <th>Last position</th>
                      <th></th>
                    </tr>
                  </thead>
                  <tbody>
                    {listed.map((courier) => {
                      const hasPosition = courier.latitude !== null && courier.longitude !== null;
                      return (
                        <tr key={courier.courierId}>
                          <td className="rname">
                            <span
                              className="courier-dot"
                              style={{ background: STATUS_COLOR[courier.status] }}
                            />
                            {courier.name}
                          </td>
                          <td>{STATUS_LABEL[courier.status]}</td>
                          <td>{hasPosition ? timeAgo(courier.updatedAt) : 'No position yet'}</td>
                          <td style={{ whiteSpace: 'nowrap', textAlign: 'right' }}>
                            {courier.currentDeliveryId && (
                              <Link to={`/deliveries/${courier.currentDeliveryId}`} className="btn ghost sm">
                                Delivery
                              </Link>
                            )}{' '}
                            <button
                              type="button"
                              className="btn ghost sm"
                              disabled={!hasPosition}
                              onClick={() => setFocus({ ...courier })}
                            >
                              Show on map
                            </button>
                          </td>
                        </tr>
                      );
                    })}
                  </tbody>
                </table>
              </div>
            )}
          </>
        )}
      </div>
    </>
  );
}
