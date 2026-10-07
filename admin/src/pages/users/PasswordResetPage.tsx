import { useState, type FormEvent } from 'react';
import { useMutation } from '@tanstack/react-query';
import { usersApi, type PasswordResetResult } from '../../api/resources';
import { PageHeader, ErrorBanner, NoteBanner } from '../../components/ui';

// PATCH /api/admin/users/password needs at least 8 characters, like
// sign-up (ResetUserPasswordRequest on the backend).
const MIN_LENGTH = 8;

// No 0/O, 1/l/I: the password is read off a phone and typed back in.
const READABLE = 'abcdefghjkmnpqrstuvwxyz23456789';

function readablePassword(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(MIN_LENGTH));
  return Array.from(bytes, (b) => READABLE[b % READABLE.length]).join('');
}

/** The message the admin sends back on WhatsApp, in the app's French. */
function whatsappLink(result: PasswordResetResult, password: string): string {
  const text =
    `Bonjour ${result.name}, votre nouveau mot de passe Delivery Hassen est : ${password}\n` +
    'Connectez-vous avec, puis changez-le dans Profil › Mot de passe.';
  return `https://wa.me/216${result.phone}?text=${encodeURIComponent(text)}`;
}

export default function PasswordResetPage() {
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState(readablePassword);
  const [sent, setSent] = useState<{ result: PasswordResetResult; password: string } | null>(null);
  const [copied, setCopied] = useState(false);

  const reset = useMutation({
    mutationFn: () => usersApi.resetPassword(phone, password),
    onSuccess: (result) => {
      setSent({ result, password });
      setPhone('');
      setPassword(readablePassword());
      setCopied(false);
    },
  });

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setSent(null);
    reset.mutate();
  }

  async function copy() {
    if (!sent) return;
    try {
      await navigator.clipboard.writeText(sent.password);
      setCopied(true);
    } catch {
      // Clipboard blocked (http, permissions): the password is on screen.
    }
  }

  return (
    <>
      <PageHeader title="Password reset" subtitle="For a client or courier who forgot theirs" />
      <div className="content">
        <NoteBanner>
          Clients who forget their password tap « Mot de passe oublié ? » in the app, which opens WhatsApp to support
          with their number. Set a new password for that number here, then send it back to them on WhatsApp.
        </NoteBanner>
        <div className="form-card">
          <ErrorBanner error={reset.error} />
          {sent && (
            <div className="reset-done" role="status">
              <div>
                <b>{sent.result.name}</b> ({sent.result.role === 'COURIER' ? 'courier' : 'client'},{' '}
                {sent.result.phone}) can now sign in with:
              </div>
              <div className="reset-password">{sent.password}</div>
              <div className="reset-actions">
                <a className="btn green" href={whatsappLink(sent.result, sent.password)} target="_blank" rel="noreferrer">
                  Send on WhatsApp
                </a>
                <button type="button" className="btn ghost" onClick={copy}>
                  {copied ? 'Copied' : 'Copy password'}
                </button>
              </div>
              <span className="rmeta">They were signed out of every device that used the old password.</span>
            </div>
          )}
          <form onSubmit={handleSubmit}>
            <div className="field-group">
              <label className="field-label" htmlFor="phone">
                Their phone number
              </label>
              <input
                id="phone"
                type="tel"
                className="field-input"
                placeholder="22 000 000"
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                required
              />
            </div>
            <div className="field-group">
              <label className="field-label" htmlFor="password">
                New password
              </label>
              <div style={{ display: 'flex', gap: 8 }}>
                <input
                  id="password"
                  type="text"
                  className="field-input"
                  style={{ flex: 1, fontFamily: 'monospace' }}
                  autoComplete="off"
                  minLength={MIN_LENGTH}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                />
                <button type="button" className="btn ghost" onClick={() => setPassword(readablePassword())}>
                  New one
                </button>
              </div>
              <span className="rmeta">At least {MIN_LENGTH} characters. A readable one is suggested.</span>
            </div>
            <button type="submit" className="btn" disabled={reset.isPending}>
              {reset.isPending ? 'Saving…' : 'Set new password'}
            </button>
          </form>
        </div>
      </div>
    </>
  );
}
