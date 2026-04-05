// Supabase Edge Function — generate-daily-seed
// Run via cron job at 00:01 UTC each day.
// Generates the next day's seed and stores it in the daily_challenges table.
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

// Mirrors ToneGenerator.dailySeedForDate in Dart exactly.
function dailySeedForDate(utcDate: Date): number {
  const midnight = Date.UTC(utcDate.getFullYear(), utcDate.getMonth(), utcDate.getDate());
  const ms = midnight;
  // Fold into 32-bit range
  return ((ms ^ (ms >> 16)) & 0xFFFFFFFF) >>> 0;
}

serve(async (req) => {
  // Allow manual trigger via POST (also used by cron)
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  );

  const today = new Date();
  const tomorrow = new Date(today);
  tomorrow.setUTCDate(tomorrow.getUTCDate() + 1);

  // Generate seeds for today and the next 7 days
  const seeds: Array<{ challenge_date: string; seed: number }> = [];
  for (let i = 0; i <= 7; i++) {
    const d = new Date(today);
    d.setUTCDate(d.getUTCDate() + i);
    const dateStr = d.toISOString().split('T')[0];
    seeds.push({ challenge_date: dateStr, seed: dailySeedForDate(d) });
  }

  const { error } = await supabase.from('daily_challenges').upsert(seeds, {
    onConflict: 'challenge_date',
    ignoreDuplicates: true,
  });

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  return new Response(JSON.stringify({ generated: seeds.length, seeds }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
