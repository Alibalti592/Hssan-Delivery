import type { ReactNode } from 'react';
import { Link } from 'react-router-dom';
import { ApiError } from '../api/client';

export function PageHeader({
  title,
  subtitle,
  actions,
}: {
  title: string;
  subtitle?: string;
  actions?: ReactNode;
}) {
  return (
    <div className="topbar">
      <div>
        <div className="ttitle">{title}</div>
        {subtitle && <div className="tsub">{subtitle}</div>}
      </div>
      {actions}
    </div>
  );
}

export function Loading() {
  return <div className="loading">Loading…</div>;
}

export function EmptyState({ children }: { children: ReactNode }) {
  return <div className="empty">{children}</div>;
}

export function ErrorBanner({ error }: { error: unknown }) {
  if (!error) return null;

  const message =
    error instanceof ApiError
      ? error.message
      : error instanceof Error
        ? error.message
        : 'Something went wrong.';

  const fieldErrors = error instanceof ApiError ? error.fieldErrors : [];

  return (
    <div className="error-banner">
      {message}
      {fieldErrors.length > 0 && (
        <ul style={{ margin: '6px 0 0 18px' }}>
          {fieldErrors.map((fe, i) => (
            <li key={i}>
              {fe.field}: {fe.message}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}

export function NoteBanner({ children }: { children: ReactNode }) {
  return <div className="note-banner">{children}</div>;
}

export function AvailabilityBadge({ isAvailable }: { isAvailable: boolean }) {
  return (
    <span className={`badge${isAvailable ? '' : ' closed'}`}>
      {isAvailable ? 'Available' : 'Unavailable'}
    </span>
  );
}

export function ActiveBadge({ isActive }: { isActive: boolean }) {
  return (
    <span className={`badge${isActive ? '' : ' closed'}`}>
      {isActive ? 'Active' : 'Deactivated'}
    </span>
  );
}

const ORDER_STATUS_TONE: Record<string, 'default' | 'warn' | 'closed' | 'muted'> = {
  PENDING: 'muted',
  CONFIRMED: 'warn',
  PREPARING: 'warn',
  READY_FOR_PICKUP: 'warn',
  COMPLETED: 'default',
  CANCELLED: 'closed',
  ASSIGNED: 'warn',
  ACCEPTED: 'warn',
  PICKED_UP: 'warn',
  ON_THE_WAY: 'warn',
  DELIVERED: 'default',
  FAILED: 'closed',
};

export function StatusBadge({ status }: { status: string }) {
  const tone = ORDER_STATUS_TONE[status] ?? 'muted';
  const cls = tone === 'default' ? '' : ` ${tone}`;

  return <span className={`badge${cls}`}>{status.replaceAll('_', ' ')}</span>;
}

export function Breadcrumb({ items }: { items: { label: string; to?: string }[] }) {
  return (
    <div className="breadcrumb">
      {items.map((item, i) => (
        <span key={i}>
          {item.to ? <Link to={item.to}>{item.label}</Link> : item.label}
          {i < items.length - 1 && ' / '}
        </span>
      ))}
    </div>
  );
}

export function Pagination({
  page,
  pages,
  total,
  onPageChange,
}: {
  page: number;
  pages: number;
  total: number;
  onPageChange: (page: number) => void;
}) {
  if (pages <= 1) return null;

  return (
    <div className="pagination">
      <button
        type="button"
        className="btn ghost sm"
        disabled={page <= 1}
        onClick={() => onPageChange(page - 1)}
      >
        ← Prev
      </button>
      <span className="pagination-info">
        Page {page} of {pages} ({total} total)
      </span>
      <button
        type="button"
        className="btn ghost sm"
        disabled={page >= pages}
        onClick={() => onPageChange(page + 1)}
      >
        Next →
      </button>
    </div>
  );
}

export function money(amount: string): string {
  return `${amount} DT`;
}

export function formatDate(iso: string): string {
  return new Date(iso).toLocaleString();
}
