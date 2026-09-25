import { useState } from 'react';
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { API_URL } from '../../api/client';
import { restaurantsApi } from '../../api/resources';
import type { RestaurantType } from '../../api/types';
import {
  PageHeader,
  Loading,
  ErrorBanner,
  EmptyState,
  AvailabilityBadge,
  Pagination,
  formatDate,
} from '../../components/ui';

const TYPE_LABEL: Record<RestaurantType, string> = {
  RESTAURANT: 'Restaurant',
  GROCERY: 'Grocery store',
};

type TypeFilter = RestaurantType | 'ALL';

export default function RestaurantsListPage() {
  const queryClient = useQueryClient();
  const [page, setPage] = useState(1);
  const [typeFilter, setTypeFilter] = useState<TypeFilter>('ALL');

  const { data, isLoading, error } = useQuery({
    queryKey: ['restaurants', page, typeFilter],
    queryFn: () =>
      restaurantsApi.list({ page, ...(typeFilter !== 'ALL' ? { type: typeFilter } : {}) }),
  });

  function handleTypeFilterChange(value: TypeFilter) {
    setTypeFilter(value);
    setPage(1);
  }

  const toggleAvailability = useMutation({
    mutationFn: ({ id, isAvailable }: { id: number; isAvailable: boolean }) =>
      restaurantsApi.setAvailability(id, isAvailable),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['restaurants'] }),
  });

  return (
    <>
      <PageHeader
        title="Restaurants"
        subtitle={`${data?.meta.total ?? 0} restaurants`}
        actions={
          <div style={{ display: 'flex', gap: 10, alignItems: 'center' }}>
            <select
              className="field-select"
              value={typeFilter}
              onChange={(e) => handleTypeFilterChange(e.target.value as TypeFilter)}
            >
              <option value="ALL">All types</option>
              <option value="RESTAURANT">Restaurants</option>
              <option value="GROCERY">Grocery stores</option>
            </select>
            <Link to="/restaurants/new" className="btn">
              + New restaurant
            </Link>
          </div>
        }
      />
      <div className="content">
        <ErrorBanner error={error ?? toggleAvailability.error} />
        {isLoading ? (
          <Loading />
        ) : !data || data.items.length === 0 ? (
          <EmptyState>
            {typeFilter === 'ALL'
              ? 'No restaurants yet.'
              : `No ${TYPE_LABEL[typeFilter].toLowerCase()}s yet.`}
          </EmptyState>
        ) : (
          <div className="card">
            <table>
              <thead>
                <tr>
                  <th></th>
                  <th>Name</th>
                  <th>Type</th>
                  <th>Description</th>
                  <th>Status</th>
                  <th>Created</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {data.items.map((r) => (
                  <tr key={r.id}>
                    <td>
                      <div className="photo-box" style={{ width: 36, height: 36 }}>
                        {r.photoUrl ? (
                          <img src={`${API_URL}${r.photoUrl}`} alt="" />
                        ) : (
                          <span className="placeholder" style={{ fontSize: 8 }}>
                            No photo
                          </span>
                        )}
                      </div>
                    </td>
                    <td className="rname">{r.name}</td>
                    <td>{TYPE_LABEL[r.type]}</td>
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
            <Pagination
              page={data.meta.page}
              pages={data.meta.pages}
              total={data.meta.total}
              onPageChange={setPage}
            />
          </div>
        )}
      </div>
    </>
  );
}
