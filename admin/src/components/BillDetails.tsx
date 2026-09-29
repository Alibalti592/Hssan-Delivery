import { useEffect, useState } from 'react';
import { API_URL, api } from '../api/client';
import type { AdminOrder, OrderBill } from '../api/types';
import { money } from './ui';

/**
 * The Factures part of an order: whose bill (or which mandat service), the
 * reference or who receives the money, the amount the courier pays at the
 * counter, and the client's photo of the bill.
 */
export function BillDetails({ order, bill }: { order: AdminOrder; bill: OrderBill }) {
  const isTransfer = bill.providerKind === 'TRANSFER';

  return (
    <div className="form-card" style={{ marginBottom: 20 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 16 }}>
        <div className="logo-box">
          {bill.providerLogoUrl ? (
            <img src={`${API_URL}${bill.providerLogoUrl}`} alt={`${bill.providerName} logo`} />
          ) : (
            <span className="placeholder">{bill.providerName}</span>
          )}
        </div>
        <div>
          <div className="rmeta">{isTransfer ? 'Mandat (money transfer)' : 'Bill payment'}</div>
          <div className="rname" style={{ fontSize: 16 }}>
            {bill.providerName}
          </div>
        </div>
      </div>
      <div className="detail-grid">
        {isTransfer ? (
          <div className="detail-item">
            <div className="field-label">Money goes to</div>
            <div className="value">
              {order.recipientName}
              {order.recipientPhone ? <> &middot; {order.recipientPhone}</> : null}
            </div>
          </div>
        ) : (
          <div className="detail-item">
            <div className="field-label">Bill reference</div>
            <div className="value">{bill.reference}</div>
          </div>
        )}
        <div className="detail-item">
          <div className="field-label">{isTransfer ? 'Amount to send' : 'Bill amount'}</div>
          <div className="value">{money(bill.amount)}</div>
        </div>
        <div className="detail-item">
          <div className="field-label">Cash the courier collects</div>
          <div className="value">{money(order.totalAmount)}</div>
        </div>
        {bill.photoUrl && (
          <div className="detail-item" style={{ gridColumn: '1 / -1' }}>
            <div className="field-label">Photo of the bill</div>
            <BillPhoto path={bill.photoUrl} />
          </div>
        )}
      </div>
    </div>
  );
}

/** The bill photo isn't public: fetch it with the admin's session. */
function BillPhoto({ path }: { path: string }) {
  const [url, setUrl] = useState<string | null>(null);
  const [failed, setFailed] = useState(false);

  useEffect(() => {
    let objectUrl: string | null = null;
    let cancelled = false;

    api
      .blobUrl(path)
      .then((u) => {
        objectUrl = u;
        if (cancelled) URL.revokeObjectURL(u);
        else setUrl(u);
      })
      .catch(() => {
        if (!cancelled) setFailed(true);
      });

    return () => {
      cancelled = true;
      if (objectUrl) URL.revokeObjectURL(objectUrl);
    };
  }, [path]);

  if (failed) return <div className="rmeta">The photo couldn't be loaded.</div>;
  if (!url) return <div className="rmeta">Loading photo…</div>;

  return (
    <a href={url} target="_blank" rel="noreferrer" title="Open full size">
      <img className="bill-photo" src={url} alt="Photo of the bill" />
    </a>
  );
}
