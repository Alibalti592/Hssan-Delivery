import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { Link, useParams } from 'react-router-dom';
import { categoriesApi, productsApi, restaurantsApi } from '../../api/resources';
import { PageHeader, Loading, ErrorBanner, EmptyState, AvailabilityBadge, Breadcrumb, money } from '../../components/ui';

export default function ProductsListPage() {
  const { id } = useParams();
  const restaurantId = Number(id);
  const queryClient = useQueryClient();

  const restaurant = useQuery({
    queryKey: ['restaurants', restaurantId],
    queryFn: () => restaurantsApi.get(restaurantId),
  });

  const products = useQuery({
    queryKey: ['products', restaurantId],
    queryFn: () => productsApi.listForRestaurant(restaurantId),
  });

  const categories = useQuery({
    queryKey: ['categories', restaurantId],
    queryFn: () => categoriesApi.listForRestaurant(restaurantId),
  });

  const toggleAvailability = useMutation({
    mutationFn: ({ pid, isAvailable }: { pid: number; isAvailable: boolean }) =>
      productsApi.setAvailability(pid, isAvailable),
    onSuccess: () => queryClient.invalidateQueries({ queryKey: ['products', restaurantId] }),
  });

  const categoryName = (categoryId: number) =>
    categories.data?.find((c) => c.id === categoryId)?.name ?? `#${categoryId}`;

  return (
    <>
      <PageHeader
        title="Products"
        subtitle={restaurant.data ? `Restaurant: ${restaurant.data.name}` : undefined}
        actions={
          <Link to={`/restaurants/${restaurantId}/products/new`} className="btn">
            + New product
          </Link>
        }
      />
      <div className="content">
        <Breadcrumb
          items={[
            { label: 'Restaurants', to: '/restaurants' },
            { label: restaurant.data?.name ?? '…', to: `/restaurants/${restaurantId}` },
            { label: 'Products' },
          ]}
        />

        <ErrorBanner error={products.error} />

        {products.isLoading || categories.isLoading ? (
          <Loading />
        ) : !products.data || products.data.length === 0 ? (
          <EmptyState>
            No products yet. You'll need at least one category before adding a product.
          </EmptyState>
        ) : (
          <div className="card">
            <table>
              <thead>
                <tr>
                  <th>Name</th>
                  <th>Category</th>
                  <th>Price</th>
                  <th>Status</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {products.data.map((p) => (
                  <tr key={p.id}>
                    <td className="rname">{p.name}</td>
                    <td>{categoryName(p.categoryId)}</td>
                    <td>{money(p.price)}</td>
                    <td>
                      <AvailabilityBadge isAvailable={p.isAvailable} />
                    </td>
                    <td style={{ display: 'flex', gap: 8 }}>
                      <button
                        type="button"
                        className="btn ghost sm"
                        disabled={toggleAvailability.isPending}
                        onClick={() =>
                          toggleAvailability.mutate({ pid: p.id, isAvailable: !p.isAvailable })
                        }
                      >
                        {p.isAvailable ? 'Mark unavailable' : 'Mark available'}
                      </button>
                      <Link
                        to={`/restaurants/${restaurantId}/products/${p.id}/edit`}
                        className="btn sm"
                      >
                        Edit
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
