import { useQuery } from '@tanstack/react-query';
import { Link } from 'react-router-dom';
import { restaurantCategoriesApi } from '../api/resources';

/**
 * The restaurant categories of one restaurant ("Pizza", "Sucré"...), as
 * toggles: the app's restaurant list is filtered by them, and they show on
 * the restaurant's card. Any number can be on.
 */
export function CategoryPicker({
  value,
  onChange,
}: {
  value: number[];
  onChange: (ids: number[]) => void;
}) {
  const { data, isLoading, error } = useQuery({
    queryKey: ['restaurant-categories'],
    queryFn: restaurantCategoriesApi.list,
  });

  function toggle(id: number) {
    onChange(value.includes(id) ? value.filter((v) => v !== id) : [...value, id]);
  }

  return (
    <div className="field-group">
      <span className="field-label" id="categories-label">
        Categories
      </span>
      {isLoading ? (
        <p className="rmeta">Loading…</p>
      ) : error ? (
        <p className="field-error">Could not load the categories.</p>
      ) : !data || data.length === 0 ? (
        <p className="rmeta">
          None yet. <Link to="/restaurant-categories">Create categories</Link> first.
        </p>
      ) : (
        <>
          <div className="chip-row" role="group" aria-labelledby="categories-label">
            {data.map((category) => {
              const on = value.includes(category.id);
              return (
                <button
                  key={category.id}
                  type="button"
                  className={`chip${on ? ' on' : ''}`}
                  aria-pressed={on}
                  onClick={() => toggle(category.id)}
                >
                  {category.name}
                </button>
              );
            })}
          </div>
          <p className="rmeta">Clients filter the restaurant list by these.</p>
        </>
      )}
    </div>
  );
}
