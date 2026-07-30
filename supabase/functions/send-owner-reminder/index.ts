import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY") ?? "";

interface ReminderPayload {
  tenant_id: string;
}

serve(async (req) => {
  const { tenant_id } = await req.json() as ReminderPayload;

  // Fetch tenant profile + unpaid payments
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

  const profileRes = await fetch(
    `${supabaseUrl}/rest/v1/profiles?id=eq.${tenant_id}&select=name,email`,
    { headers: { apikey: supabaseKey, Authorization: `Bearer ${supabaseKey}` } }
  );
  const [profile] = await profileRes.json();

  const paymentsRes = await fetch(
    `${supabaseUrl}/rest/v1/payments?tenant_id=eq.${tenant_id}&status=neq.paid&select=amount,month_year`,
    { headers: { apikey: supabaseKey, Authorization: `Bearer ${supabaseKey}` } }
  );
  const payments = await paymentsRes.json();
  const totalOwed = payments.reduce((sum: number, p: { amount: number }) => sum + p.amount, 0);

  if (!profile) {
    return new Response(JSON.stringify({ error: "Tenant not found" }), { status: 404 });
  }

  // Send email via Resend
  await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      Authorization: `Bearer ${RESEND_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: "Soham PG <onboarding@resend.dev>",
      to: [profile.email],
      subject: "Rent Reminder from Owner — Soham PG",
      html: `
        <div style="font-family:sans-serif;max-width:480px;margin:auto;">
          <div style="background:#1E3A5F;padding:24px;border-radius:12px 12px 0 0;text-align:center;">
            <h1 style="color:white;margin:0;">Soham PG</h1>
            <p style="color:rgba(255,255,255,0.7);margin:4px 0 0;">Rent Reminder</p>
          </div>
          <div style="background:#fff;padding:24px;border-radius:0 0 12px 12px;border:1px solid #E5E7EB;">
            <p>Hi <strong>${profile.name}</strong>,</p>
            <p>Your owner has sent you a rent reminder.</p>
            <p>Total amount due: <strong style="color:#D32F2F;font-size:20px;">₹${totalOwed.toLocaleString()}</strong></p>
            <p>Please make the payment through the Soham app as soon as possible.</p>
            <p style="color:#6B7280;font-size:12px;margin-top:32px;">— Soham PG Management</p>
          </div>
        </div>
      `,
    }),
  });

  // Also log in notifications table
  await fetch(`${supabaseUrl}/rest/v1/notifications`, {
    method: "POST",
    headers: {
      apikey: supabaseKey,
      Authorization: `Bearer ${supabaseKey}`,
      "Content-Type": "application/json",
      Prefer: "return=minimal",
    },
    body: JSON.stringify({
      tenant_id,
      title: "Reminder from owner",
      body: `Your owner sent you a rent reminder. Amount due: ₹${totalOwed}`,
      type: "reminder",
    }),
  });

  return new Response(JSON.stringify({ success: true }), { status: 200 });
});
