import type { ProductExtraGroup } from '../api/types';

/** What the backend takes: trimmed names, an empty price as free. */
export function cleanExtraGroups(groups: ProductExtraGroup[]): ProductExtraGroup[] {
  return groups.map((g) => ({
    ...g,
    name: g.name.trim(),
    choices: g.choices.map((c) => ({ name: c.name.trim(), price: c.price.trim() === '' ? '0' : c.price.trim() })),
  }));
}
