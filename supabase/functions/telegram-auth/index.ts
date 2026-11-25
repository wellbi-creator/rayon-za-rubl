import { validateTelegramInitData } from "./telegram_init_data.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

Deno.serve(async (request: Request) => {
  if (request.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (request.method !== "POST") return jsonResponse({ error: "Method not allowed" }, 405);

  const botToken = Deno.env.get("TELEGRAM_BOT_TOKEN");
  if (!botToken) return jsonResponse({ error: "Authentication service is not configured" }, 503);

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return jsonResponse({ error: "Invalid JSON body" }, 400);
  }
  if (!body || typeof body !== "object" || !("initData" in body) ||
      typeof (body as { initData: unknown }).initData !== "string") {
    return jsonResponse({ error: "initData is required" }, 400);
  }

  try {
    const user = await validateTelegramInitData(
      (body as { initData: string }).initData,
      { botToken },
    );
    // This endpoint verifies identity only. Supabase user sessions are added in T3.
    return jsonResponse({ authenticated: true, telegramUserId: String(user.id) });
  } catch (error) {
    const message = error instanceof Error ? error.message : "Invalid Telegram initData";
    return jsonResponse({ error: message }, 401);
  }
});
