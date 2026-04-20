// Session helper. In the real app this reads the NextAuth session cookie
// and resolves it to the Stripe customer id stored on the user record.
// For the sandbox we return a fixed test customer.
export async function getCurrentUserId(): Promise<string | null> {
  return 'cus_test123';
}
