// Static pricing card. Rendered on the marketing home page.
// The CTA button is intentionally inert here — wiring it to a real checkout
// flow is part of the billing sprint (see README.md).

type PricingCardProps = {
  name: string;
  priceLabel: string;
  blurb: string;
  bullets: string[];
  ctaLabel: string;
  ctaDisabled?: boolean;
  highlight?: boolean;
};

export function PricingCard(props: PricingCardProps) {
  const {
    name,
    priceLabel,
    blurb,
    bullets,
    ctaLabel,
    ctaDisabled,
    highlight,
  } = props;

  return (
    <article className={`pricing-card${highlight ? ' is-highlight' : ''}`}>
      <header>
        <h3>{name}</h3>
        <p className="price">{priceLabel}</p>
        <p className="blurb">{blurb}</p>
      </header>
      <ul>
        {bullets.map((b) => (
          <li key={b}>{b}</li>
        ))}
      </ul>
      <button type="button" disabled={ctaDisabled} className="pricing-cta">
        {ctaLabel}
      </button>
    </article>
  );
}
