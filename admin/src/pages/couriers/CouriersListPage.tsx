import { useState, type FormEvent } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { couriersApi } from '../../api/resources';
import { PageHeader, Loading, ErrorBanner, EmptyState, ActiveBadge, formatDate } from '../../components/ui';

export default function CouriersListPage() {
  const queryClient = useQueryClient();
  const [creating, setCreating] = useState(false);
  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');

  const couriers = useQuery({ queryKey: ['couriers'], queryFn: couriersApi.list });

  const create = useMutation({
    mutationFn: () => couriersApi.create({ name, phone, password }),
    onSuccess: () => {
      setName('');
      setPhone('');
      setPassword('');
      setCreating(false);
      queryClient.invalidateQueries({ queryKey: ['couriers'] });
    },
  });

  const toggleActive = useMutation({
    mutationFn: ({ id, isActive }: { id: number; isActive: boolean }) =>
      couriersApi.setActive(id, isActive),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['couriers'] }),
  });

  function handleCreate(e: FormEvent) {
    e.preventDefault();
    create.mutate();
  }

  return (
    <>
      <PageHeader
        title="Couriers"
        subtitle={`${couriers.data?.length ?? 0} couriers`}
        actions={
          <button type="button" className="btn" onClick={() => setCreating((c) => !c)}>
            {creating ? 'Cancel' : '+ New courier'}
          </button>
        }
      />
      <div className="content">
        {creating && (
          <div className="form-card" style={{ marginBottom: 20 }}>
            <ErrorBanner error={create.error} />
            <form onSubmit={handleCreate}>
              <div className="field-group">
                <label className="field-label">Full name</label>
                <input className="field-input" value={name} onChange={(e) => setName(e.target.value)} required />
              </div>
              <div className="field-group">
                <label className="field-label">Phone</label>
                <input
                  className="field-input"
                  value={phone}
                  onChange={(e) => setPhone(e.target.value)}
                  placeholder="+216 22 000 000"
                  required
                />
              </div>
              <div className="field-group">
                <label className="field-label">Temporary password</label>
                <input
                  className="field-input"
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  required
                />
              </div>
              <button type="submit" className="btn" disabled={create.isPending}>
                {create.isPending ? 'Creating…' : 'Create courier account'}
              </button>
            </form>
          </div>
        )}

        <ErrorBanner error={couriers.error} />

        {couriers.isLoading ? (
          <Loading />
        ) : !couriers.data || couriers.data.length === 0 ? (
          <EmptyState>No couriers yet.</EmptyState>
        ) : (
          <div className="card">
            <table>
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Phone</th>
                  <th>Status</th>
                  <th>Created</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {couriers.data.map((c) => (
                  <tr key={c.id}>
                    <td className="rname">{c.name}</td>
                    <td>{c.phone}</td>
                    <td>
                      <ActiveBadge isActive={c.isActive} />
                    </td>
                    <td>{formatDate(c.createdAt)}</td>
                    <td style={{ display: 'flex', gap: 8 }}>
                      <button
                        type="button"
                        className="btn ghost sm"
                        disabled={toggleActive.isPending}
                        onClick={() => toggleActive.mutate({ id: c.id, isActive: !c.isActive })}
                      >
                        {c.isActive ? 'Deactivate' : 'Reactivate'}
                      </button>
                      <Link to={`/couriers/${c.id}`} className="btn sm">
                        View
                      </Link>
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
