import { createHmac } from "node:crypto";

export function hmacSha256(secret: string, payload: string): string {
  return createHmac("sha256", secret).update(payload).digest("hex");
}

export function binanceSign(secret: string, query: string): string {
  return hmacSha256(secret, query);
}

export function bybitSign(secret: string, payload: string): string {
  return hmacSha256(secret, payload);
}
