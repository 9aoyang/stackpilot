'use client';

import { useState } from 'react';
import { signIn } from 'next-auth/react';

export default function SignInPage() {
  const [email, setEmail] = useState('');
  const [sent, setSent] = useState(false);

  async function handleEmail(e: React.FormEvent) {
    e.preventDefault();
    await signIn('email', { email, redirect: false });
    setSent(true);
  }

  return (
    <main className="signin">
      <h1>Sign in to Lumen</h1>

      {sent ? (
        <p>Check your inbox for a magic link.</p>
      ) : (
        <form onSubmit={handleEmail} className="signin-form">
          <label>
            Email
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              required
            />
          </label>
          <button type="submit">Send magic link</button>
        </form>
      )}

      <hr />

      <button
        type="button"
        className="google-btn"
        onClick={() => signIn('google', { callbackUrl: '/dashboard' })}
      >
        Continue with Google
      </button>
    </main>
  );
}
