import { useState } from 'react';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { API_URL } from '../../api/client';
import { promotionsApi } from '../../api/resources';
import {
  PageHeader,
  Loading,
  ErrorBanner,
  EmptyState,
  ActiveBadge,
  Pagination,
  formatDate,
} from '../../components/ui';

export default function PromotionsListPage() {
  const queryClient = useQueryClient();
  const [page, setPage] = useState(1);

  const { data, isLoading, error } = useQuery({
    queryKey: ['promotions', page],
    queryFn: () => promotionsApi.list({ page }),
  });

  const toggleActive = useMutation({
    mutationFn: ({ id, isActive }: { id: number; isActive: boolean }) =>
      promotionsApi.setActive(id, isActive),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['promotions'] }),
  });

  return (
    <>
      <PageHeader
        title="Promotions"
        subtitle={`${data?.meta.total ?? 0} promotions`}
        actions={
          <Link to="/promotions/new" className="btn">
            + New promotion
          </Link>
        }
      />
      <div className="content">
        <ErrorBanner error={error ?? toggleActive.error} />
        {isLoading ? (
          <Loading />
        ) : !data || data.items.length === 0 ? (
          <EmptyState>No promotions yet.</EmptyState>
        ) : (
          <div className="card">
            <table>
              <thead>
                <tr>
                  <th></th>
                  <th>Title</th>
                  <th>Discount</th>
                  <th>Restaurant</th>
                  <th>Valid until</th>
                  <th>Status</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {data.items.map((p) => (
                  <tr key={p.id}>
                    <td>
                      <div className="photo-box" style={{ width: 36, height: 36 }}>
                        {p.photoUrl ? (
                          <img src={`${API_URL}${p.photoUrl}`} alt="" />
                        ) : (
                          <span className="placeholder" style={{ fontSize: 8 }}>
                            No photo
                          </span>
                        )}
                      </div>
                    </td>
                    <td className="rname">{p.title}</td>
                    <td>
                      {p.discountType === 'PERCENTAGE'
                        ? `${p.discountValue}%`
                        : `${p.discountValue} DT`}
                      {p.promoCode && ` · ${p.promoCode}`}
                    </td>
                    <td>{p.restaurantName ?? 'All restaurants'}</td>
                    <td>{formatDate(p.endAt)}</td>
                    <td>
                      <ActiveBadge isActive={p.isActive} />
                    </td>
                    <td style={{ display: 'flex', gap: 8 }}>
                      <button
                        type="button"
                        className="btn ghost sm"
                        disabled={toggleActive.isPending}
                        onClick={() =>
                          toggleActive.mutate({ id: p.id, isActive: !p.isActive })
                        }
                      >
                        {p.isActive ? 'Deactivate' : 'Activate'}
                      </button>
                      <Link to={`/promotions/${p.id}/edit`} className="btn sm">
                        Edit
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
