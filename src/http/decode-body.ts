import { brotliDecompressSync, gunzipSync, inflateRawSync, inflateSync } from "node:zlib";

export function decodeBody(buf: Buffer, enc?: string): string {
  if (!buf.length) return "";
  const e = (enc || "").toLowerCase();
  try {
    if (e === "gzip" || e === "x-gzip") return gunzipSync(buf).toString("utf8");
    if (e === "br") return brotliDecompressSync(buf).toString("utf8");
    if (e === "deflate") {
      try {
        return inflateSync(buf).toString("utf8");
      } catch {
        return inflateRawSync(buf).toString("utf8");
      }
    }
  } catch { /* raw */ }
  return buf.toString("utf8");
}

export function firstHeader(v: string | string[] | undefined): string | undefined {
  return Array.isArray(v) ? v[0] : v;
}
