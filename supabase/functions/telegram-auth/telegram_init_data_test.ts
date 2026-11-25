import { validateTelegramInitData } from "./telegram_init_data.ts";

const encoder = new TextEncoder();
async function sign(keyBytes: Uint8Array, message: string): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey("raw", keyBytes, { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return new Uint8Array(await crypto.subtle.sign("HMAC", key, encoder.encode(message)));
}
function hex(bytes: Uint8Array): string {
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}
async function makeInitData(botToken: string, fields: Record<string, string>): Promise<string> {
  const check = Object.entries(fields).sort(([a], [b]) => a.localeCompare(b))
    .map(([key, value]) => `${key}=${value}`).join("\n");
  const secret = await sign(encoder.encode(botToken), "WebAppData");
  const hash = hex(await sign(secret, check));
  const params = new URLSearchParams(fields);
  params.set("hash", hash);
  return params.toString();
}

Deno.test("accepts a valid signed Telegram initData payload", async () => {
  const botToken = "test-token";
  const now = 1_800_000_000;
  const raw = await makeInitData(botToken, {
    auth_date: String(now),
    user: JSON.stringify({ id: 123456789, first_name: "Test" }),
    query_id: "query-test",
  });
  const result = await validateTelegramInitData(raw, { botToken, nowSeconds: now });
  if (result.id !== 123456789) throw new Error("Unexpected Telegram user id");
});

Deno.test("rejects a modified payload", async () => {
  const botToken = "test-token";
  const now = 1_800_000_000;
  const raw = await makeInitData(botToken, {
    auth_date: String(now),
    user: JSON.stringify({ id: 123456789 }),
  });
  let rejected = false;
  try {
    await validateTelegramInitData(raw.replace("123456789", "987654321"), { botToken, nowSeconds: now });
  } catch { rejected = true; }
  if (!rejected) throw new Error("Modified payload was accepted");
});

Deno.test("rejects expired initData", async () => {
  const botToken = "test-token";
  const now = 1_800_000_000;
  const raw = await makeInitData(botToken, {
    auth_date: String(now - 86_401),
    user: JSON.stringify({ id: 123456789 }),
  });
  let rejected = false;
  try {
    await validateTelegramInitData(raw, { botToken, nowSeconds: now });
  } catch { rejected = true; }
  if (!rejected) throw new Error("Expired payload was accepted");
});

Deno.test("rejects duplicate fields", async () => {
  let rejected = false;
  try {
    await validateTelegramInitData("auth_date=1&auth_date=2&user=%7B%22id%22%3A1%7D&hash=" + "a".repeat(64), {
      botToken: "test-token",
      nowSeconds: 2,
    });
  } catch { rejected = true; }
  if (!rejected) throw new Error("Duplicate field was accepted");
});
