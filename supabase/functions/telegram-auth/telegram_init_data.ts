const encoder = new TextEncoder();

export type VerifiedTelegramUser = {
  id: number;
};

export type InitDataValidationOptions = {
  botToken: string;
  nowSeconds?: number;
  maxAgeSeconds?: number;
  futureToleranceSeconds?: number;
};

function toHex(bytes: Uint8Array): string {
  return Array.from(bytes, (byte) => byte.toString(16).padStart(2, "0")).join("");
}

async function hmacSha256(keyBytes: Uint8Array, message: string): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey(
    "raw",
    keyBytes,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return new Uint8Array(await crypto.subtle.sign("HMAC", key, encoder.encode(message)));
}

function constantTimeHexEqual(left: string, right: string): boolean {
  if (!/^[0-9a-f]{64}$/i.test(left) || !/^[0-9a-f]{64}$/i.test(right)) return false;
  let difference = 0;
  for (let index = 0; index < 64; index++) {
    difference |= left.charCodeAt(index) ^ right.charCodeAt(index);
  }
  return difference === 0;
}

export async function validateTelegramInitData(
  rawInitData: string,
  options: InitDataValidationOptions,
): Promise<VerifiedTelegramUser> {
  if (!options.botToken) throw new Error("Telegram authentication is not configured");
  if (!rawInitData || rawInitData.length > 16_384) throw new Error("Invalid initData");

  const params = new URLSearchParams(rawInitData);
  const values = new Map<string, string>();
  for (const [key, value] of params.entries()) {
    if (values.has(key)) throw new Error("Duplicate initData field");
    values.set(key, value);
  }

  const suppliedHash = values.get("hash") ?? "";
  const authDateRaw = values.get("auth_date") ?? "";
  const userRaw = values.get("user") ?? "";
  if (!suppliedHash || !authDateRaw || !userRaw) throw new Error("Missing required initData fields");

  const authDate = Number(authDateRaw);
  if (!Number.isSafeInteger(authDate) || authDate <= 0) throw new Error("Invalid auth_date");
  const now = options.nowSeconds ?? Math.floor(Date.now() / 1000);
  const maxAge = options.maxAgeSeconds ?? 86_400;
  const futureTolerance = options.futureToleranceSeconds ?? 300;
  if (authDate > now + futureTolerance) throw new Error("initData auth_date is in the future");
  if (now - authDate > maxAge) throw new Error("initData has expired");

  values.delete("hash");
  values.delete("signature");
  const dataCheckString = Array.from(values.entries())
    .sort(([left], [right]) => left.localeCompare(right))
    .map(([key, value]) => `${key}=${value}`)
    .join("\n");

  const secretKey = await hmacSha256(encoder.encode(options.botToken), "WebAppData");
  const calculatedHash = toHex(await hmacSha256(secretKey, dataCheckString));
  if (!constantTimeHexEqual(suppliedHash, calculatedHash)) throw new Error("Invalid initData signature");

  let user: unknown;
  try {
    user = JSON.parse(userRaw);
  } catch {
    throw new Error("Invalid Telegram user payload");
  }
  if (!user || typeof user !== "object" || !("id" in user)) {
    throw new Error("Missing Telegram user id");
  }
  const userId = Number((user as { id: unknown }).id);
  if (!Number.isSafeInteger(userId) || userId <= 0) throw new Error("Invalid Telegram user id");

  return { id: userId };
}
