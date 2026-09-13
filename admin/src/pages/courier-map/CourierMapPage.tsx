import { useMemo } from 'react';
import { useQuery } from '@tanstack/react-query';
import { MapContainer, Marker, Popup, TileLayer } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import { Link } from 'react-router-dom';
import { courierLocationsApi } from '../../api/resources';
import type { CourierLocationEntry, CourierMapStatus } from '../../api/types';
import { PageHeader, Loading, ErrorBanner, NoteBanner } from '../../components/ui';

// Tunis — a reasonable default center when no courier has ever reported a
// location yet.
const DEFAULT_CENTER: [number, number] = [36.8065, 10.1815];

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

export default function CourierMapPage() {
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

  const center = useMemo<[number, number]>(() => {
    if (located.length === 0) return DEFAULT_CENTER;
    return [located[0].latitude as number, located[0].longitude as number];
  }, [located]);

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
          This shows each courier's last reported position, not live continuous tracking. A
          courier's app reports its location periodically while active — see "Last updated" per
          marker for how fresh that is.
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
              <MapContainer
                center={center}
                zoom={located.length > 0 ? 12 : 11}
                style={{ height: 480, width: '100%' }}
              >
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
          </>
        )}
      </div>
    </>
  );
}
