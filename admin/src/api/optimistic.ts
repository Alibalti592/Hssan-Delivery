import type { QueryClient, QueryKey } from '@tanstack/react-query';

/**
 * [data] with the item [id] changed by [patch], whatever the shape cached
 * under a key: a page (`{ items, meta }`), a plain list, or the item alone.
 */
export function patchById(data: unknown, id: number, patch: Record<string, unknown>): unknown {
  const one = (item: unknown) =>
    item !== null && typeof item === 'object' && (item as { id?: unknown }).id === id ? { ...item, ...patch } : item;

  if (Array.isArray(data)) return data.map(one);
  if (data !== null && typeof data === 'object' && Array.isArray((data as { items?: unknown }).items)) {
    return { ...data, items: (data as { items: unknown[] }).items.map(one) };
  }
  return one(data);
}

type Snapshot = { previous: Array<[QueryKey, unknown]> };

/**
 * The handlers for a toggle shown at once (available, active...): every
 * list and page cached under [queryKey] shows the new value before the
 * server answers; a refusal puts back what was there (and the caller shows
 * the error); either way the server's state is fetched again to settle it.
 * Callers keep the control disabled while it's pending, so a double click
 * can't send two opposite requests.
 *
 * Only for reversible, harmless changes: never an order, a deletion or a
 * send, which wait for the server's answer.
 */
export function optimisticToggle<TVariables>(
  queryClient: QueryClient,
  queryKey: QueryKey,
  toPatch: (variables: TVariables) => {
    id: number;
    patch: Record<string, unknown>;
  },
) {
  return {
    onMutate: async (variables: TVariables): Promise<Snapshot> => {
      // A reload already on its way would overwrite the change with the
      // old value.
      await queryClient.cancelQueries({ queryKey });
      const previous = queryClient.getQueriesData({ queryKey });
      const { id, patch } = toPatch(variables);
      for (const [key, data] of previous) {
        if (data !== undefined) queryClient.setQueryData(key, patchById(data, id, patch));
      }
      return { previous };
    },
    onError: (_error: unknown, _variables: TVariables, snapshot: Snapshot | undefined) => {
      for (const [key, data] of snapshot?.previous ?? []) queryClient.setQueryData(key, data);
    },
    onSettled: () => queryClient.invalidateQueries({ queryKey }),
  };
}
