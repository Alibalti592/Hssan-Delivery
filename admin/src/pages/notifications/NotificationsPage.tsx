import { useMemo, useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { notificationsApi, promotionsApi } from '../../api/resources';
import type { Promotion } from '../../api/types';
import { ErrorBanner, Loading, PageHeader, formatDate } from '../../components/ui';
import monogramUrl from '../../assets/monogram.svg';

const TITLE_MAX = 65;
const BODY_MAX = 240;

/** "-35%", "-5 DT", or an offer's price. */
function discountLabel(p: Promotion): string {
  const value = p.discountValue.includes('.') ? p.discountValue.replace(/\.?0+$/, '') : p.discountValue;
  switch (p.discountType) {
    case 'PERCENTAGE':
      return `-${value}%`;
    case 'FIXED_PRICE':
      return `${p.discountValue} DT`;
    default:
      return `-${p.discountValue} DT`;
  }
}

/**
 * Ready-made texts in the style customers know from delivery apps, filled
 * in from the promotion (its discount, its code). The admin edits them
 * freely before sending.
 */
const TEMPLATES: { name: string; build: (p: Promotion | null) => { title: string; body: string } }[] = [
  {
    name: 'Flash',
    build: (p) => ({
      title: p ? `⚡ FLASH HOUR : ${discountLabel(p)} ! 🔥` : '⚡ FLASH HOUR ! 🔥',
      body: [
        p?.promoCode ? `🎟️ Code promo : ${p.promoCode}` : p ? `🎟️ ${p.title}` : null,
        '⏳ Offre limitée dans le temps… ne ratez pas cette occasion !',
        '📲 Commandez vite sur Delivery Hassen ! 🚀',
      ]
        .filter(Boolean)
        .join('\n'),
    }),
  },
  {
    name: 'Combo',
    build: (p) => ({
      title: p ? `🍔 ${p.title} à ${discountLabel(p)} !` : '🍔 Le combo du jour !',
      body: [
        p?.restaurantName ? `Chez ${p.restaurantName}.` : null,
        p?.items.length ? p.items.join(' + ') : null,
        '📲 Disponible maintenant sur Delivery Hassen.',
      ]
        .filter(Boolean)
        .join('\n'),
    }),
  },
  {
    name: 'Weekend',
    build: (p) => ({
      title: '🌙 Le week-end commence ici !',
      body: [
        p?.promoCode ? `${discountLabel(p)} avec le code ${p.promoCode} 🎟️` : null,
        'Vos restaurants préférés livrés chez vous à Bizerte. 🛵',
      ]
        .filter(Boolean)
        .join('\n'),
    }),
  },
];

/**
 * A notification to every customer's phone, like the ones big delivery apps
 * send ("⚡ FLASH HOUR : -35% ! Code promo : RB35"). The code is shared
 * here only: the app itself never shows it (backend
 * PromotionResponse::forClient), so it rewards the customers who get it.
 */
export default function NotificationsPage() {
  const queryClient = useQueryClient();
  const [title, setTitle] = useState('');
  const [body, setBody] = useState('');
  const [promotionId, setPromotionId] = useState<number | null>(null);
  const [sentMessage, setSentMessage] = useState<string | null>(null);

  const overview = useQuery({ queryKey: ['notifications'], queryFn: notificationsApi.overview });
  const promotions = useQuery({
    queryKey: ['promotions', 'for-notifications'],
    queryFn: () => promotionsApi.list({ page: 1, limit: 100 }),
  });

  // Only what customers can use right now is worth announcing (as of when
  // the list was fetched).
  const fetchedAt = promotions.dataUpdatedAt;
  const live = useMemo(() => {
    const now = fetchedAt;
    return (promotions.data?.items ?? []).filter(
      (p) =>
        p.isActive &&
        new Date(p.startAt).getTime() <= now &&
        (p.endAt === null || new Date(p.endAt).getTime() >= now),
    );
  }, [promotions.data, fetchedAt]);
  const promotion = live.find((p) => p.id === promotionId) ?? null;

  const send = useMutation({
    mutationFn: () => notificationsApi.send({ title: title.trim(), body: body.trim(), promotionId }),
    onSuccess: (campaign) => {
      setSentMessage(
        campaign.delivered === null
          ? 'Saved, but push notifications are off on the server (no Firebase key): nothing was sent.'
          : `Sent: ${campaign.delivered} of ${campaign.recipients} phones received it.`,
      );
      setTitle('');
      setBody('');
      setPromotionId(null);
      queryClient.invalidateQueries({ queryKey: ['notifications'] });
    },
  });

  const reachable = overview.data?.reachableDevices ?? 0;
  const canSend =
    title.trim() !== '' && body.trim() !== '' && title.length <= TITLE_MAX && body.length <= BODY_MAX && reachable > 0;

  function handleSend(e: React.FormEvent) {
    e.preventDefault();
    setSentMessage(null);
    if (!canSend) return;
    if (window.confirm(`Send this notification to ${reachable} customer phone${reachable === 1 ? '' : 's'}?`)) {
      send.mutate();
    }
  }

  return (
    <>
      <PageHeader
        title="Notifications"
        subtitle={
          overview.data
            ? `${reachable} customer phone${reachable === 1 ? '' : 's'} signed in to the app`
            : undefined
        }
      />
      <div className="content">
        <ErrorBanner error={overview.error ?? promotions.error ?? send.error} />
        {sentMessage && <div className="note-banner">{sentMessage}</div>}

        <div className="notif-layout">
          <form className="form-card" onSubmit={handleSend}>
            <div className="field-group">
              <label className="field-label" htmlFor="promotion">
                Promotion (optional)
              </label>
              <select
                id="promotion"
                className="field-select"
                value={promotionId ?? ''}
                onChange={(e) => setPromotionId(e.target.value ? Number(e.target.value) : null)}
              >
                <option value="">None: a tap just opens the app</option>
                {live.map((p) => (
                  <option key={p.id} value={p.id}>
                    {p.title} · {discountLabel(p)}
                    {p.promoCode ? ` · code ${p.promoCode}` : ''}
                    {p.restaurantName ? ` · ${p.restaurantName}` : ''}
                  </option>
                ))}
              </select>
              <p className="rmeta">
                A tap on the notification opens this promotion. Its code is only shared through the
                notification: the app never shows it.
              </p>
            </div>

            <div className="field-group">
              <span className="field-label">Start from a template</span>
              <div className="notif-templates">
                {TEMPLATES.map((t) => (
                  <button
                    key={t.name}
                    type="button"
                    className="btn ghost sm"
                    onClick={() => {
                      const filled = t.build(promotion);
                      setTitle(filled.title);
                      setBody(filled.body);
                    }}
                  >
                    {t.name}
                  </button>
                ))}
              </div>
            </div>

            <div className="field-group">
              <label className="field-label" htmlFor="notif-title">
                Title <span className="rmeta">{title.length}/{TITLE_MAX}</span>
              </label>
              <input
                id="notif-title"
                className="field-input"
                value={title}
                maxLength={TITLE_MAX}
                placeholder="⚡ FLASH HOUR : -35% ! 🔥"
                onChange={(e) => setTitle(e.target.value)}
              />
            </div>

            <div className="field-group">
              <label className="field-label" htmlFor="notif-body">
                Message <span className="rmeta">{body.length}/{BODY_MAX}</span>
              </label>
              <textarea
                id="notif-body"
                className="field-textarea"
                rows={5}
                value={body}
                maxLength={BODY_MAX}
                placeholder={'🎟️ Code promo : RB35\n⏳ Offre limitée dans le temps…\n📲 Commandez vite sur Delivery Hassen ! 🚀'}
                onChange={(e) => setBody(e.target.value)}
              />
            </div>

            <button className="btn" type="submit" disabled={!canSend || send.isPending}>
              {send.isPending ? 'Sending…' : `Send to ${reachable} phone${reachable === 1 ? '' : 's'}`}
            </button>
            {overview.data && reachable === 0 && (
              <p className="rmeta">No customer has signed in to the app yet.</p>
            )}
            <p className="rmeta">
              Customers who refused notifications (or switched them off in the phone's settings) only
              see it if the app is open when it's sent.
            </p>
          </form>

          <div>
            <span className="field-label">Preview</span>
            <div className="notif-phone" aria-label="Notification preview">
              <div className="notif-card">
                <img src={monogramUrl} alt="" className="notif-icon" />
                <div className="notif-text">
                  <div className="notif-app">
                    Delivery Hassen <span>· maintenant</span>
                  </div>
                  <div className="notif-title">{title || 'Le titre de votre notification'}</div>
                  <div className="notif-body">{body || 'Votre message, sur quelques lignes.'}</div>
                </div>
              </div>
            </div>
          </div>
        </div>

        <h2 className="section-title">Sent</h2>
        {overview.isLoading ? (
          <Loading />
        ) : !overview.data || overview.data.campaigns.length === 0 ? (
          <p className="rmeta">Nothing sent yet.</p>
        ) : (
          <div className="card">
            <table>
              <thead>
                <tr>
                  <th>Sent</th>
                  <th>Notification</th>
                  <th>Promotion</th>
                  <th>Phones</th>
                </tr>
              </thead>
              <tbody>
                {overview.data.campaigns.map((c) => (
                  <tr key={c.id}>
                    <td>
                      {formatDate(c.sentAt)}
                      {c.sentBy && <div className="rmeta">{c.sentBy}</div>}
                    </td>
                    <td>
                      <strong>{c.title}</strong>
                      <div className="rmeta notif-history-body">{c.body}</div>
                    </td>
                    <td>{c.promotionTitle ?? '—'}</td>
                    <td>
                      {c.delivered === null ? (
                        <span className="badge warn">Push off</span>
                      ) : (
                        `${c.delivered} / ${c.recipients}`
                      )}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        )}
      </div>
    </>
  );
}
