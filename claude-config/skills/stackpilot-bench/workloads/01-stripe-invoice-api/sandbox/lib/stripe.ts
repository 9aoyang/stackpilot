import Stripe from 'stripe';

// Singleton Stripe client. Import this from anywhere that needs to talk to
// Stripe — do NOT instantiate `new Stripe(...)` again elsewhere in the app.
export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY!);
