import { useState, type FormEvent } from 'react';
import { Circle, MapContainer, Marker, TileLayer, Tooltip, useMapEvents } from 'react-leaflet';
import L from 'leaflet';
import 'leaflet/dist/leaflet.css';
import type { DeliveryZoneInput } from '../../api/resources';
import type { DeliveryZoneAdmin } from '../../api/types';
import { MONEY_PATTERN, MONEY_TITLE } from '../../components/ui';

// Bizerte: where the zones are, until one is placed.
const DEFAULT_CENTER: [number, number] = [37.2744, 9.8739];
const DEFAULT_RADIUS_KM = 1.5;

const centerIcon = L.divIcon({
  className: 'zone-center',
  html: '<span style="display:block;width:16px;height:16px;border-radius:50%;background:#000;border:3px solid #fff;box-shadow:0 0 0 1px rgba(0,0,0,0.35)"></span>',
  iconSize: [16, 16],
  iconAnchor: [8, 8],
});

function ClickToPlace({ onPlace }: { onPlace: (lat: number, lng: number) => void }) {
  useMapEvents({ click: (e) => onPlace(e.latlng.lat, e.latlng.lng) });
  return null;
}

/**
 * Name, fee, and where the zone is: click the map to set its center, then
 * adjust the radius. An address pin inside the circle gets this zone in the
 * app automatically. Other placed zones are drawn faintly for reference.
 */
export default function ZoneEditor({
  zone,
  others,
  busy,
  submitLabel,
  onSubmit,
  onCancel,
}: {
  zone?: DeliveryZoneAdmin;
  others: DeliveryZoneAdmin[];
  busy: boolean;
  submitLabel: string;
  onSubmit: (data: DeliveryZoneInput) => void;
  onCancel: () => void;
}) {
  const [name, setName] = useState(zone?.name ?? '');
  const [fee, setFee] = useState(zone?.fee ?? '');
  const [center, setCenter] = useState<[number, number] | null>(
    zone?.latitude != null && zone.longitude != null ? [zone.latitude, zone.longitude] : null,
  );
  const [radius, setRadius] = useState(String(zone?.radiusKm ?? DEFAULT_RADIUS_KM));

  const radiusKm = Number(radius);
  const radiusValid = Number.isFinite(radiusKm) && radiusKm >= 0.1 && radiusKm <= 50;
  const placedOthers = others.filter(
    (o) => o.id !== zone?.id && o.latitude != null && o.longitude != null && o.radiusKm != null,
  );
  const mapCenter: [number, number] =
    center ??
    (placedOthers.length > 0 ? [placedOthers[0].latitude!, placedOthers[0].longitude!] : DEFAULT_CENTER);

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    onSubmit({
      name: name.trim(),
      fee: fee.trim(),
      latitude: center ? center[0] : null,
      longitude: center ? center[1] : null,
      radiusKm: center ? radiusKm : null,
    });
  }

  return (
    <form onSubmit={handleSubmit} className="zone-editor">
      <div style={{ display: 'flex', gap: 10, alignItems: 'flex-end', flexWrap: 'wrap' }}>
        <div className="field-group" style={{ flex: 1, minWidth: 180, marginBottom: 0 }}>
          <label className="field-label" htmlFor="zone-name">Zone name</label>
          <input
            id="zone-name"
            className="field-input"
            value={name}
            onChange={(e) => setName(e.target.value)}
            placeholder="e.g. Jarzouna"
            required
          />
        </div>
        <div className="field-group" style={{ width: 120, marginBottom: 0 }}>
          <label className="field-label" htmlFor="zone-fee">Fee (DT)</label>
          <input
            id="zone-fee"
            className="field-input"
            value={fee}
            onChange={(e) => setFee(e.target.value)}
            placeholder="5.000"
            inputMode="decimal"
            pattern={MONEY_PATTERN}
            title={MONEY_TITLE}
            required
          />
        </div>
        <div className="field-group" style={{ width: 120, marginBottom: 0 }}>
          <label className="field-label" htmlFor="zone-radius">Radius (km)</label>
          <input
            id="zone-radius"
            className="field-input"
            type="number"
            min={0.1}
            max={50}
            step={0.1}
            value={radius}
            onChange={(e) => setRadius(e.target.value)}
            disabled={!center}
            required={center != null}
          />
        </div>
      </div>

      <p className="zone-hint">
        {center
          ? 'Click the map to move the center. Addresses inside the circle get this zone automatically in the app.'
          : 'Click the map to place this zone. Clients never choose a zone: the app gives each address the zone its pin falls in, so a zone that is not placed is never used.'}
      </p>

      <div className="zone-map">
        <MapContainer center={mapCenter} zoom={13} style={{ height: '100%', width: '100%' }}>
          <TileLayer
            attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>'
            url="https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png"
          />
          <ClickToPlace onPlace={(lat, lng) => setCenter([lat, lng])} />
          {placedOthers.map((o) => (
            <Circle
              key={o.id}
              center={[o.latitude!, o.longitude!]}
              radius={o.radiusKm! * 1000}
              pathOptions={{ color: '#8b93a0', weight: 1, fillOpacity: 0.06, dashArray: '4 4' }}
            >
              <Tooltip>{o.name}</Tooltip>
            </Circle>
          ))}
          {center && (
            <>
              {radiusValid && (
                <Circle
                  center={center}
                  radius={radiusKm * 1000}
                  pathOptions={{ color: '#000', weight: 2, fillOpacity: 0.12 }}
                />
              )}
              <Marker position={center} icon={centerIcon} />
            </>
          )}
        </MapContainer>
      </div>

      <div style={{ display: 'flex', gap: 8, marginTop: 12 }}>
        <button type="submit" className="btn" disabled={busy || (center != null && !radiusValid)}>
          {submitLabel}
        </button>
        {center && (
          <button type="button" className="btn ghost" onClick={() => setCenter(null)}>
            Remove from map
          </button>
        )}
        <button type="button" className="btn ghost" onClick={onCancel}>
          Cancel
        </button>
      </div>
    </form>
  );
}
