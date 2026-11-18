import type { Product, ProductExtraGroup } from '../api/types';
import { MONEY_PATTERN, MONEY_TITLE } from './ui';

/** Ready-made groups, the ones nearly every snack has. */
const PRESETS: { label: string; group: ProductExtraGroup }[] = [
  { label: 'Sauces', group: { name: 'Sauces', required: false, multiple: true, choices: [] } },
  { label: 'Extras', group: { name: 'Suppléments', required: false, multiple: true, choices: [] } },
  { label: 'Drink', group: { name: 'Boisson', required: false, multiple: false, choices: [] } },
];

/**
 * What the customer can add to a product when ordering: sauces, extras, a
 * drink... Each group is one pick or several, optional or required; each
 * choice adds its price (0 for a free sauce). Another product's groups can
 * be copied in, since a restaurant's sandwiches usually share them.
 */
export function ExtrasEditor({
  value,
  onChange,
  otherProducts,
}: {
  value: ProductExtraGroup[];
  onChange: (groups: ProductExtraGroup[]) => void;
  /** The restaurant's other products, to copy their choices from. */
  otherProducts: Product[];
}) {
  const withExtras = otherProducts.filter((p) => (p.extraGroups ?? []).length > 0);

  function updateGroup(index: number, change: Partial<ProductExtraGroup>) {
    onChange(value.map((g, i) => (i === index ? { ...g, ...change } : g)));
  }

  function addGroup(group: ProductExtraGroup) {
    // A new group starts with one empty choice to fill.
    onChange([...value, { ...group, choices: [{ name: '', price: '' }] }]);
  }

  function copyFrom(productId: number) {
    const source = withExtras.find((p) => p.id === productId);
    if (!source) return;
    const taken = new Set(value.map((g) => g.name.trim().toLowerCase()));
    const copied = (source.extraGroups ?? [])
      .filter((g) => !taken.has(g.name.trim().toLowerCase()))
      .map((g) => ({ ...g, choices: g.choices.map((c) => ({ ...c })) }));
    onChange([...value, ...copied]);
  }

  const missingPresets = PRESETS.filter(
    (p) => !value.some((g) => g.name.trim().toLowerCase() === p.group.name.toLowerCase()),
  );

  return (
    <div className="field-group">
      <span className="field-label">
        Customer choices <span className="optional">optional</span>
      </span>
      {value.length === 0 && (
        <span className="rmeta" style={{ marginTop: 0 }}>
          Sauces, extras, a drink… The client ticks them when ordering; each adds its price (0 = free).
        </span>
      )}

      {value.map((group, index) => (
        <div key={index} className="extra-group">
          <div className="extra-group-head">
            <input
              className="field-input"
              aria-label={`Group ${index + 1} name`}
              value={group.name}
              onChange={(e) => updateGroup(index, { name: e.target.value })}
              placeholder="Sauces"
              maxLength={50}
              required
            />
            <select
              className="field-select"
              aria-label={`Group ${index + 1} picks`}
              value={group.multiple ? 'multiple' : 'one'}
              onChange={(e) => updateGroup(index, { multiple: e.target.value === 'multiple' })}
            >
              <option value="multiple">Several</option>
              <option value="one">One only</option>
            </select>
            <button
              type="button"
              className="btn ghost sm"
              aria-label={`Remove group ${index + 1}`}
              onClick={() => onChange(value.filter((_, i) => i !== index))}
            >
              ✕
            </button>
          </div>
          <label className="field-checkbox" style={{ margin: '6px 0 8px' }}>
            <input
              type="checkbox"
              checked={group.required}
              onChange={(e) => updateGroup(index, { required: e.target.checked })}
            />
            Required: the client must pick {group.multiple ? 'at least one' : 'one'}
          </label>

          {group.choices.map((choice, c) => (
            <div key={c} className="option-row">
              <input
                className="field-input"
                aria-label={`${group.name || `Group ${index + 1}`} choice ${c + 1} name`}
                value={choice.name}
                onChange={(e) =>
                  updateGroup(index, {
                    choices: group.choices.map((x, i) => (i === c ? { ...x, name: e.target.value } : x)),
                  })
                }
                placeholder={c === 0 ? 'Harissa' : ''}
                maxLength={50}
                required
              />
              <input
                className="field-input"
                aria-label={`${group.name || `Group ${index + 1}`} choice ${c + 1} price`}
                value={choice.price}
                onChange={(e) =>
                  updateGroup(index, {
                    choices: group.choices.map((x, i) => (i === c ? { ...x, price: e.target.value } : x)),
                  })
                }
                placeholder="0 = free"
                inputMode="decimal"
                pattern={MONEY_PATTERN}
                title={MONEY_TITLE}
              />
              <button
                type="button"
                className="btn ghost sm"
                aria-label={`Remove ${choice.name || `choice ${c + 1}`}`}
                disabled={group.choices.length === 1}
                onClick={() =>
                  updateGroup(index, { choices: group.choices.filter((_, i) => i !== c) })
                }
              >
                ✕
              </button>
            </div>
          ))}
          {group.choices.length < 30 && (
            <button
              type="button"
              className="btn ghost sm"
              onClick={() => updateGroup(index, { choices: [...group.choices, { name: '', price: '' }] })}
            >
              + Add a choice
            </button>
          )}
        </div>
      ))}

      {value.length < 10 && (
        <div className="extra-actions">
          {missingPresets.map((preset) => (
            <button key={preset.label} type="button" className="btn ghost sm" onClick={() => addGroup(preset.group)}>
              + {preset.label}
            </button>
          ))}
          <button
            type="button"
            className="btn ghost sm"
            onClick={() => addGroup({ name: '', required: false, multiple: true, choices: [] })}
          >
            + Other group
          </button>
          {withExtras.length > 0 && (
            <select
              className="field-select extra-copy"
              aria-label="Copy the choices of another product"
              value=""
              onChange={(e) => copyFrom(Number(e.target.value))}
            >
              <option value="">Copy from…</option>
              {withExtras.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.name}
                </option>
              ))}
            </select>
          )}
        </div>
      )}
    </div>
  );
}
