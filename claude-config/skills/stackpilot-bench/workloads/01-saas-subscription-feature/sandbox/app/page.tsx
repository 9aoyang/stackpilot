import Link from 'next/link';
import { PricingCard } from '@/components/PricingCard';

export default function MarketingHome() {
  return (
    <main className="marketing">
      <section className="hero">
        <h1>Notes that summarise themselves.</h1>
        <p>
          Lumen is your second brain. Write, and we keep the index, the
          timeline, and the thread.
        </p>
        <Link href="/signin" className="cta">
          Start free
        </Link>
      </section>

      <section className="pricing">
        <h2>Plans</h2>
        <div className="pricing-grid">
          <PricingCard
            name="Free"
            priceLabel="$0"
            blurb="All the basics, forever."
            bullets={['Up to 100 notes', 'AI summaries (10/mo)', 'Web app']}
            ctaLabel="You're on this plan"
            ctaDisabled
          />
          <PricingCard
            name="Personal"
            priceLabel="$8 / mo"
            blurb="For daily drivers."
            bullets={['Unlimited notes', 'AI summaries (unlimited)', 'Mobile apps', 'Priority email support']}
            ctaLabel="Upgrade"
            highlight
          />
          <PricingCard
            name="Team"
            priceLabel="Contact us"
            blurb="For small teams. (Coming soon.)"
            bullets={['Everything in Personal', 'Shared workspaces', 'SSO', 'SLA']}
            ctaLabel="Talk to sales"
            ctaDisabled
          />
        </div>
      </section>
    </main>
  );
}
