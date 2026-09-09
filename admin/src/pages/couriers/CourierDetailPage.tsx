import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useParams } from 'react-router-dom';
import { couriersApi } from '../../api/resources';
import { PageHeader, Loading, ErrorBanner, Breadcrumb, ActiveBadge, formatDate } from '../../components/ui';

export default function CourierDetailPage() {
  const { id } = useParams();
  const courierId = Number(id);
  const queryClient = useQueryClient();

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

  return (
    <>
      <PageHeader title={data?.name ?? 'Courier'} subtitle={data ? `Courier #${data.id}` : undefined} />
      <div className="content">
        <Breadcrumb items={[{ label: 'Couriers', to: '/couriers' }, { label: data?.name ?? '…' }]} />
        <ErrorBanner error={error || toggleActive.error} />
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
            <button
              type="button"
              className={`btn ${data.isActive ? 'danger' : 'green'}`}
              disabled={toggleActive.isPending}
              onClick={() => toggleActive.mutate(!data.isActive)}
            >
              {data.isActive ? 'Deactivate courier' : 'Reactivate courier'}
            </button>
          </div>
        ) : null}
      </div>
    </>
  );
}
