import { useState, type FormEvent } from 'react';
import { useMutation } from '@tanstack/react-query';
import { authApi } from '../../api/resources';
import { PageHeader, ErrorBanner, Breadcrumb } from '../../components/ui';

// POST /api/auth/change-password checks the current password and needs a
// new one of at least 8 characters (ChangePasswordRequest on the backend).
const MIN_LENGTH = 8;

export default function ChangePasswordPage() {
  const [currentPassword, setCurrentPassword] = useState('');
  const [newPassword, setNewPassword] = useState('');
  const [confirmation, setConfirmation] = useState('');
  const [clientError, setClientError] = useState<Error | null>(null);

  const change = useMutation({
    mutationFn: () => authApi.changePassword(currentPassword, newPassword),
    onSuccess: () => {
      setCurrentPassword('');
      setNewPassword('');
      setConfirmation('');
    },
  });

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setClientError(null);
    change.reset();

    if (newPassword.length < MIN_LENGTH) {
      setClientError(new Error(`The new password must be at least ${MIN_LENGTH} characters.`));
      return;
    }

    if (newPassword !== confirmation) {
      setClientError(new Error('The two new passwords do not match.'));
      return;
    }

    if (newPassword === currentPassword) {
      setClientError(new Error('The new password must be different from the current one.'));
      return;
    }

    change.mutate();
  }

  return (
    <>
      <PageHeader title="Change password" />
      <div className="content">
        <Breadcrumb items={[{ label: 'Account' }, { label: 'Change password' }]} />
        <div className="form-card">
          <ErrorBanner error={clientError ?? change.error} />
          {change.isSuccess && (
            <p
              role="status"
              style={{
                margin: '0 0 16px',
                padding: '10px 12px',
                borderRadius: 8,
                background: '#e8f3ec',
                color: '#276749',
                fontSize: 13,
              }}
            >
              Password changed. Use the new one next time you sign in.
            </p>
          )}
          <form onSubmit={handleSubmit}>
            <div className="field-group">
              <label className="field-label" htmlFor="currentPassword">
                Current password
              </label>
              <input
                id="currentPassword"
                type="password"
                className="field-input"
                autoComplete="current-password"
                value={currentPassword}
                onChange={(e) => setCurrentPassword(e.target.value)}
                required
              />
            </div>
            <div className="field-group">
              <label className="field-label" htmlFor="newPassword">
                New password
              </label>
              <input
                id="newPassword"
                type="password"
                className="field-input"
                autoComplete="new-password"
                minLength={MIN_LENGTH}
                value={newPassword}
                onChange={(e) => setNewPassword(e.target.value)}
                required
              />
              <span className="rmeta">At least {MIN_LENGTH} characters.</span>
            </div>
            <div className="field-group">
              <label className="field-label" htmlFor="confirmation">
                Repeat the new password
              </label>
              <input
                id="confirmation"
                type="password"
                className="field-input"
                autoComplete="new-password"
                value={confirmation}
                onChange={(e) => setConfirmation(e.target.value)}
                required
              />
            </div>
            <button type="submit" className="btn" disabled={change.isPending}>
              {change.isPending ? 'Saving…' : 'Change password'}
            </button>
          </form>
        </div>
      </div>
    </>
  );
}
