import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { restaurantsApi } from '../../api/resources';
import { PageHeader, Loading, ErrorBanner, EmptyState, AvailabilityBadge, formatDate } from '../../components/ui';

export default function RestaurantsListPage() {
  const queryClient = useQueryClient();

  const { data, isLoading, error } = useQuery({
    queryKey: ['restaurants'],
    queryFn: restaurantsApi.list,
  });

  const toggleAvailability = useMutation({
    mutationFn: ({ id, isAvailable }: { id: number; isAvailable: boolean }) =>
      restaurantsApi.setAvailability(id, isAvailable),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['restaurants'] }),
  });

  return (
    <>
      <PageHeader
        title="Restaurants"
        subtitle={`${data?.length ?? 0} restaurants`}
        actions={
          <Link to="/restaurants/new" className="btn">
            + New restaurant
          </Link>
        }
      />
      <div className="content">
        <ErrorBanner error={error} />
        {isLoading ? (
          <Loading />
        ) : !data || data.length === 0 ? (
          <EmptyState>No restaurants yet.</EmptyState>
        ) : (
          <div className="card">
            <table>
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Description</th>
                  <th>Status</th>
                  <th>Created</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {data.map((r) => (
                  <tr key={r.id}>
                    <td className="rname">{r.name}</td>
                    <td>{r.description ?? '—'}</td>
                    <td>
                      <AvailabilityBadge isAvailable={r.isAvailable} />
                    </td>
                    <td>{formatDate(r.createdAt)}</td>
                    <td style={{ display: 'flex', gap: 8 }}>
                      <button
                        type="button"
                        className="btn ghost sm"
                        disabled={toggleAvailability.isPending}
                        onClick={() =>
                          toggleAvailability.mutate({ id: r.id, isAvailable: !r.isAvailable })
                        }
                      >
                        {r.isAvailable ? 'Close' : 'Open'}
                      </button>
                      <Link to={`/restaurants/${r.id}`} className="btn sm">
                        Manage
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
