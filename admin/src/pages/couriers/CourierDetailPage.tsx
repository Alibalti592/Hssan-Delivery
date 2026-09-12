import { useState, type FormEvent } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useParams } from 'react-router-dom';
import { couriersApi } from '../../api/resources';
import { PageHeader, Loading, ErrorBanner, Breadcrumb, ActiveBadge, formatDate } from '../../components/ui';

export default function CourierDetailPage() {
  const { id } = useParams();
  const courierId = Number(id);
  const queryClient = useQueryClient();
  const [resetting, setResetting] = useState(false);
  const [newPassword, setNewPassword] = useState('');

  const { data, isLoading, error } = useQuery({
    queryKey: ['couriers', courierId],
    queryFn: () => couriersApi.get(courierId),
  });

  const toggleActive = useMutation({
    mutationFn: (isActive: boolean) => couriersApi.setActive(courierId, isActive),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['couriers', courierId] });
      queryClient.invalidateQueries({ queryKey: ['couriers'] });
    },
  });

  const resetPassword = useMutation({
    mutationFn: () => couriersApi.resetPassword(courierId, newPassword),
    onSuccess: () => {
      setNewPassword('');
      setResetting(false);
    },
  });

  function handleResetPassword(e: FormEvent) {
    e.preventDefault();
    resetPassword.mutate();
  }

  return (
    <>
      <PageHeader title={data?.name ?? 'Courier'} subtitle={data ? `Courier #${data.id}` : undefined} />
      <div className="content">
        <Breadcrumb items={[{ label: 'Couriers', to: '/couriers' }, { label: data?.name ?? '…' }]} />
        <ErrorBanner error={error || toggleActive.error || resetPassword.error} />
        {isLoading ? (
          <Loading />
        ) : data ? (
          <div className="form-card">
            <div className="detail-grid">
              <div className="detail-item">
                <div className="field-label">Phone</div>
                <div className="value">{data.phone}</div>
              </div>
              <div className="detail-item">
                <div className="field-label">Status</div>
                <div className="value">
                  <ActiveBadge isActive={data.isActive} />
                </div>
              </div>
              <div className="detail-item">
                <div className="field-label">Roles</div>
                <div className="value">{data.roles.join(', ')}</div>
              </div>
              <div className="detail-item">
                <div className="field-label">Created</div>
                <div className="value">{formatDate(data.createdAt)}</div>
              </div>
            </div>
            <div style={{ display: 'flex', gap: 8 }}>
              <button
                type="button"
                className={`btn ${data.isActive ? 'danger' : 'green'}`}
                disabled={toggleActive.isPending}
                onClick={() => toggleActive.mutate(!data.isActive)}
              >
                {data.isActive ? 'Deactivate courier' : 'Reactivate courier'}
              </button>
              <button type="button" className="btn ghost" onClick={() => setResetting((r) => !r)}>
                {resetting ? 'Cancel' : 'Reset password'}
              </button>
            </div>
            {resetting && (
              <form onSubmit={handleResetPassword} style={{ marginTop: 16 }}>
                <div className="field-group">
                  <label className="field-label">New password</label>
                  <input
                    className="field-input"
                    type="password"
                    value={newPassword}
                    onChange={(e) => setNewPassword(e.target.value)}
                    minLength={8}
                    required
                  />
                </div>
                <p style={{ fontSize: 13, opacity: 0.8 }}>
                  The courier isn't notified automatically — relay this password to them yourself (phone
                  call, in person, etc.), the same way their initial password was handed over.
                </p>
                <button type="submit" className="btn" disabled={resetPassword.isPending}>
                  {resetPassword.isPending ? 'Resetting…' : 'Set new password'}
                </button>
              </form>
            )}
          </div>
        ) : null}
      </div>
    </>
  );
}
