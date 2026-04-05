// Supabase Edge Function — revenuecat-webhook
// Handles RevenueCat webhook events to keep premium status in sync.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('Method not allowed', { status: 405 });
  }

  // Verify RevenueCat webhook secret
  const secret = req.headers.get('X-RevenueCat-Authorization');
  const expectedSecret = Deno.env.get('REVENUECAT_WEBHOOK_SECRET');
  if (secret !== expectedSecret) {
    return new Response('Unauthorized', { status: 401 });
  }

  const body = await req.json();
  const event = body.event;

  if (!event) {
    return new Response('Missing event', { status: 400 });
  }

  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  // Extract the Supabase user ID (stored as RevenueCat app_user_id)
  const appUserId: string = event.app_user_id;
  const eventType: string = event.type;

  // Determine premium status from event type
  const premiumEventTypes = ['INITIAL_PURCHASE', 'RENEWAL', 'PRODUCT_CHANGE', 'UNCANCELLATION', 'SUBSCRIPTION_PAUSED'];
  const cancelledEventTypes = ['CANCELLATION', 'EXPIRATION', 'BILLING_ISSUE'];

  let isPremium = false;
  let plan: string | null = null;
  let premiumUntil: string | null = null;

  if (premiumEventTypes.includes(eventType)) {
    isPremium = true;
    plan = event.period_type === 'ANNUAL' ? 'annual' : 'monthly';
    premiumUntil = event.expiration_at_ms
      ? new Date(event.expiration_at_ms).toISOString()
      : null;
  } else if (cancelledEventTypes.includes(eventType)) {
    isPremium = false;
    premiumUntil = event.expiration_at_ms
      ? new Date(event.expiration_at_ms).toISOString()
      : null;
  }

  // Update users table
  await supabase.from('users').update({
    is_premium: isPremium,
    premium_until: premiumUntil,
    revenuecat_id: appUserId,
  }).eq('id', appUserId);

  // Upsert subscriptions table
  if (isPremium || cancelledEventTypes.includes(eventType)) {
    await supabase.from('subscriptions').upsert({
      user_id: appUserId,
      plan: plan,
      status: isPremium ? (eventType === 'INITIAL_PURCHASE' ? 'trial' : 'active') : 'expired',
      current_period_end: premiumUntil,
      updated_at: new Date().toISOString(),
    });
  }

  return new Response(JSON.stringify({ received: true }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
