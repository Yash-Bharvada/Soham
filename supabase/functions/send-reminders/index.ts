import Anthropic from "@anthropic-ai/sdk";
import { createClient } from "@supabase/supabase-js";
import Expo from "expo-server-sdk";
import { Resend } from "resend";

// ---------------------------------------------------------------------------
// Deno Edge Function: send-reminders
// Triggered daily by pg_cron via pg_net
// ---------------------------------------------------------------------------

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
);

const expo = new Expo({ accessToken: Deno.env.get("EXPO_ACCESS_TOKEN") });
const resend = new Resend(Deno.env.get("RESEND_API_KEY")!);

Deno.serve(async (_req) => {
  try {
    const today = new Date().toISOString().split("T")[0];
    const twoDaysLater = new Date(Date.now() + 2 * 86400_000)
      .toISOString()
      .split("T")[0];

    // Fetch pending payments due today or in 2 days
    const { data: payments, error: paymentsError } = await supabase
      .from("payments")
      .select(
        `
        id,
        due_date,
        amount,
        tenant_id,
        tenants (
          id,
          room_id,
          rooms (
            room_number,
            owner_id,
            profiles!rooms_owner_id_fkey (
              full_name,
              upi_id
            )
          ),
          profiles!tenants_id_fkey (
            full_name,
            push_token
          )
        )
      `
      )
      .in("due_date", [today, twoDaysLater])
      .eq("status", "pending");

    if (paymentsError) throw paymentsError;
    if (!payments || payments.length === 0) {
      return new Response(
        JSON.stringify({ message: "No reminders to send." }),
        { status: 200 }
      );
    }

    const results = [];

    for (const payment of payments) {
      const tenantProfile = payment.tenants?.profiles as any;
      const ownerProfile = payment.tenants?.rooms?.profiles as any;
      const pushToken = tenantProfile?.push_token;
      const tenantName = tenantProfile?.full_name ?? "Tenant";
      const roomNumber = payment.tenants?.rooms?.room_number ?? "";
      const dueDate = payment.due_date;
      const amount = payment.amount;

      const isReminder2Day = dueDate === twoDaysLater;
      const subject = isReminder2Day
        ? `Rent Reminder: ₹${amount} due on ${dueDate}`
        : `Rent Due Today: ₹${amount}`;
      const body = isReminder2Day
        ? `Hi ${tenantName}, your rent of ₹${amount} for Room ${roomNumber} is due in 2 days (${dueDate}). Please pay on time.`
        : `Hi ${tenantName}, your rent of ₹${amount} for Room ${roomNumber} is due TODAY (${dueDate}). Please pay now.`;

      // ---- Push Notification ----
      const { data: pushLog } = await supabase
        .from("notification_log")
        .select("id")
        .eq("tenant_id", payment.tenant_id)
        .eq("payment_id", payment.id)
        .eq("type", "push")
        .maybeSingle();

      if (!pushLog && pushToken && Expo.isExpoPushToken(pushToken)) {
        const messages = [
          {
            to: pushToken,
            sound: "default" as const,
            title: subject,
            body,
            data: { paymentId: payment.id },
          },
        ];
        const chunks = expo.chunkPushNotifications(messages);
        for (const chunk of chunks) {
          await expo.sendPushNotificationsAsync(chunk);
        }
        await supabase.from("notification_log").insert({
          tenant_id: payment.tenant_id,
          payment_id: payment.id,
          type: "push",
        });
        results.push({ paymentId: payment.id, type: "push", status: "sent" });
      }

      // ---- Email (via Resend) ----
      const { data: emailLog } = await supabase
        .from("notification_log")
        .select("id")
        .eq("tenant_id", payment.tenant_id)
        .eq("payment_id", payment.id)
        .eq("type", "email")
        .maybeSingle();

      // Fetch tenant email from auth.users via service role
      const { data: userRecord } = await supabase.auth.admin.getUserById(
        payment.tenant_id
      );
      const tenantEmail = userRecord?.user?.email;

      if (!emailLog && tenantEmail) {
        await resend.emails.send({
          from: "PG Manager <noreply@yourdomain.com>",
          to: tenantEmail,
          subject,
          html: `<p>${body}</p>`,
        });
        await supabase.from("notification_log").insert({
          tenant_id: payment.tenant_id,
          payment_id: payment.id,
          type: "email",
        });
        results.push({
          paymentId: payment.id,
          type: "email",
          status: "sent",
        });
      }
    }

    return new Response(JSON.stringify({ results }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  } catch (err) {
    console.error("send-reminders error:", err);
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
    });
  }
});
