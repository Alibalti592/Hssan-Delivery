import { useState, type FormEvent } from 'react';
import { useMutation, useQueryClient } from '@tanstack/react-query';
import { useNavigate } from 'react-router-dom';
import { restaurantsApi } from '../../api/resources';
import { PageHeader, ErrorBanner, Breadcrumb } from '../../components/ui';

export default function RestaurantFormPage() {
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [name, setName] = useState('');
  const [description, setDescription] = useState('');
  const [isAvailable, setIsAvailable] = useState(true);

  const create = useMutation({
    mutationFn: () =>
      restaurantsApi.create({ name, description: description || null, isAvailable }),
    onSuccess: (restaurant) => {
      queryClient.invalidateQueries({ queryKey: ['restaurants'] });
      navigate(`/restaurants/${restaurant.id}`);
    },
  });

  function handleSubmit(e: FormEvent) {
    e.preventDefault();
    create.mutate();
  }

  return (
    <>
      <PageHeader title="New restaurant" />
      <div className="content">
        <Breadcrumb items={[{ label: 'Restaurants', to: '/restaurants' }, { label: 'New' }]} />
        <div className="form-card">
          <ErrorBanner error={create.error} />
          <form onSubmit={handleSubmit}>
            <div className="field-group">
              <label className="field-label" htmlFor="name">
                Name
              </label>
              <input
                id="name"
                className="field-input"
                value={name}
                onChange={(e) => setName(e.target.value)}
                required
              />
            </div>
            <div className="field-group">
              <label className="field-label" htmlFor="description">
                Description
              </label>
              <textarea
                id="description"
                className="field-textarea"
                rows={3}
                value={description}
                onChange={(e) => setDescription(e.target.value)}
              />
            </div>
            <div className="field-group">
              <label className="field-checkbox">
                <input
                  type="checkbox"
                  checked={isAvailable}
                  onChange={(e) => setIsAvailable(e.target.checked)}
                />
                Open — accepting orders
              </label>
            </div>
            <button type="submit" className="btn" disabled={create.isPending}>
              {create.isPending ? 'Creating…' : 'Create restaurant'}
            </button>
          </form>
        </div>
      </div>
    </>
  );
}
