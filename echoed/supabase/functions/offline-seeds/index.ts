// Supabase Edge Function — offline-seeds
// Premium only: returns the next 7 daily seeds as a signed payload
// for offline use. Validates premium entitlement via RevenueCat.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return new Response('Unauthorized', { status: 401 });
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_ANON_KEY')!,
    { global: { headers: { Authorization: authHeader } } }
  );

  // Verify user is authenticated
  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) {
    return new Response('Unauthorized', { status: 401 });
  }

  // Verify premium status
  const { data: userData } = await supabase
    .from('users')
    .select('is_premium, premium_until')
    .eq('id', user.id)
    .single();

  const isPremium = userData?.is_premium &&
    (!userData?.premium_until || new Date(userData.premium_until) > new Date());

  if (!isPremium) {
    return new Response(JSON.stringify({ error: 'Premium required' }), { status: 403 });
  }

  // Fetch next 7 daily seeds
  const today = new Date();
  const dates: string[] = [];
  for (let i = 0; i < 7; i++) {
    const d = new Date(today);
    d.setUTCDate(d.getUTCDate() + i);
    dates.push(d.toISOString().split('T')[0]);
  }

  // Use service role for reading daily_challenges
  const adminSupabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  const { data: seedRows } = await adminSupabase
    .from('daily_challenges')
    .select('challenge_date, seed')
    .in('challenge_date', dates)
    .order('challenge_date');

  // Sign the payload (HMAC-SHA256) with a server secret
  // Clients verify this before trusting the offline seeds.
  const payload = JSON.stringify({ user_id: user.id, seeds: seedRows ?? [] });
  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(Deno.env.get('OFFLINE_SEEDS_SECRET') ?? 'dev-secret'),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );
  const sig = await crypto.subtle.sign('HMAC', key, encoder.encode(payload));
  const sigHex = Array.from(new Uint8Array(sig)).map(b => b.toString(16).padStart(2, '0')).join('');

  return new Response(JSON.stringify({
    seeds: seedRows ?? [],
    signature: sigHex,
  }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
