import Stripe from 'stripe';

// Singleton Stripe client. Import `stripe` from here — do NOT instantiate
// `new Stripe(...)` elsewhere in the app. Pin the API version explicitly so
// a Stripe SDK upgrade cannot silently change wire behaviour.
export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!, {
  apiVersion: '2024-04-10',
  typescript: true,
});
