// FlowState AI Proxy - Cloudflare Worker
// Proxies requests to the Anthropic Claude API with Sign in with Apple auth
// Secrets: ANTHROPIC_API_KEY, JWT_SECRET

const ANTHROPIC_API_URL = "https://api.anthropic.com/v1/messages";
const ANTHROPIC_VERSION = "2023-06-01";
const APPLE_JWKS_URL = "https://appleid.apple.com/auth/keys";
const APPLE_ISSUER = "https://appleid.apple.com";
const APPLE_AUDIENCE = "alnotha.FlowSate";
const JWT_EXPIRY_SECONDS = 7 * 24 * 60 * 60; // 7 days
const RATE_LIMIT_PER_MINUTE = 60;

// Fix #1: Whitelist allowed models and allowed body fields
const ALLOWED_MODELS = new Set([
  "claude-haiku-4-5-20251001",
  "claude-sonnet-4-5-20250929",
  "claude-3-5-haiku-20241022",
  "claude-3-5-sonnet-20241022",
]);
const MAX_TOKENS_CAP = 1024;
const MAX_REQUEST_BODY_SIZE = 10 * 1024; // 10KB for AI proxy
const ALLOWED_BODY_FIELDS = new Set(["model", "max_tokens", "messages", "system", "stream", "temperature"]);

// Fix #7: General request size limit for POST handlers
const MAX_POST_BODY_SIZE = 50 * 1024; // 50KB

// Fix #2: Cache Apple JWKS with 1-hour TTL
let cachedJWKS = { data: null, fetchedAt: 0 };
const JWKS_CACHE_TTL = 60 * 60 * 1000; // 1 hour in milliseconds

const rateLimitMap = new Map();

// Fix #3: Separate rate limit map for auth endpoints
const authRateLimitMap = new Map();

function isRateLimited(key) {
  const now = Date.now();
  const windowStart = now - 60000;
  const timestamps = (rateLimitMap.get(key) || []).filter((t) => t > windowStart);
  if (timestamps.length >= RATE_LIMIT_PER_MINUTE) return true;
  timestamps.push(now);
  rateLimitMap.set(key, timestamps);
  return false;
}

// Fix #3: IP-based rate limiting for auth endpoints
function isAuthRateLimited(ip, maxPerMinute) {
  const now = Date.now();
  const windowStart = now - 60000;
  const key = `${ip}`;
  const timestamps = (authRateLimitMap.get(key) || []).filter((t) => t > windowStart);
  if (timestamps.length >= maxPerMinute) return true;
  timestamps.push(now);
  authRateLimitMap.set(key, timestamps);
  return false;
}

// Fix #5: Remove CORS headers entirely from non-OPTIONS responses.
// iOS native apps don't need CORS. Only provide minimal headers for OPTIONS preflight.
function optionsCorsHeaders() {
  return {
    "Access-Control-Allow-Origin": "null",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, X-App-Bundle, Authorization",
    "Access-Control-Max-Age": "86400",
  };
}

function jsonResponse(body, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...extraHeaders },
  });
}

// Fix #7: Check Content-Length before parsing request body
function checkContentLength(request, maxSize) {
  const contentLength = request.headers.get("Content-Length");
  if (contentLength && parseInt(contentLength, 10) > maxSize) {
    return jsonResponse({ error: "Request body too large" }, 413);
  }
  return null;
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // Fix #5: CORS preflight with minimal headers
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: optionsCorsHeaders() });
    }

    // Route handling
    if (url.pathname === "/auth/nonce" && request.method === "POST") {
      return handleNonceGeneration(request, env);
    }

    if (url.pathname === "/auth/apple" && request.method === "POST") {
      return handleAppleAuth(request, env);
    }

    if (url.pathname === "/auth/refresh" && request.method === "POST") {
      return handleTokenRefresh(request, env);
    }

    // Fix #8: Only route POST to `/` or `/v1/messages` to the AI proxy
    if ((url.pathname === "/" || url.pathname === "/v1/messages") && request.method === "POST") {
      return handleAIProxy(request, env);
    }

    // Fix #8: Explicit 404 for all other paths
    return jsonResponse({ error: "Not found" }, 404);
  },
};

// MARK: - Apple Auth Endpoint

async function handleAppleAuth(request, env) {
  try {
    // Fix #7: Check request body size
    const sizeError = checkContentLength(request, MAX_POST_BODY_SIZE);
    if (sizeError) return sizeError;

    // Fix #3: Rate limit auth endpoint - 5 requests per minute per IP
    const clientIP = request.headers.get("CF-Connecting-IP") || "unknown";
    if (isAuthRateLimited(clientIP, 5)) {
      return jsonResponse({ error: "Rate limited" }, 429, { "Retry-After": "60" });
    }

    const body = await request.json();
    const { identityToken, userIdentifier, nonce: clientNonce, nonceSignature, nonceExpiresAt } = body;

    if (!identityToken || !userIdentifier) {
      return jsonResponse({ error: "Missing identityToken or userIdentifier" }, 400);
    }

    // Fix #9: Pass expected audience into verifyAppleToken
    const applePayload = await verifyAppleToken(identityToken, APPLE_AUDIENCE);
    if (!applePayload) {
      return jsonResponse({ error: "Invalid Apple identity token" }, 401);
    }

    // Require nonce for replay protection
    if (!clientNonce || !nonceSignature || !nonceExpiresAt) {
      return jsonResponse({ error: "Missing nonce parameters" }, 400);
    }

    if (Date.now() > nonceExpiresAt) {
      return jsonResponse({ error: "Nonce expired" }, 400);
    }

    const hmacKey = await crypto.subtle.importKey(
      "raw",
      new TextEncoder().encode(env.JWT_SECRET),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["verify"]
    );
    const expectedPayload = `${clientNonce}:${nonceExpiresAt}`;
    const expectedSig = base64UrlDecode(nonceSignature);
    const nonceValid = await crypto.subtle.verify(
      "HMAC", hmacKey, expectedSig, new TextEncoder().encode(expectedPayload)
    );
    if (!nonceValid) {
      return jsonResponse({ error: "Invalid nonce" }, 400);
    }

    // Verify the Apple token contains the SHA256 hash of our nonce
    const nonceHash = await sha256Hex(clientNonce);
    if (applePayload.nonce !== nonceHash) {
      return jsonResponse({ error: "Nonce mismatch" }, 401);
    }

    // Verify the subject matches
    if (applePayload.sub !== userIdentifier) {
      return jsonResponse({ error: "User identifier mismatch" }, 401);
    }

    // Fix #12: Use canonical `sub` from Apple token as the user identifier
    const canonicalUserID = applePayload.sub;

    // Issue our own JWT using the canonical Apple sub
    const jwt = await createJWT(
      { sub: canonicalUserID, aud: APPLE_AUDIENCE },
      env.JWT_SECRET,
      JWT_EXPIRY_SECONDS
    );

    return jsonResponse({
      token: jwt,
      expiresIn: JWT_EXPIRY_SECONDS,
      userID: canonicalUserID,
    });
  } catch (error) {
    // Fix #6: Sanitize error messages - don't expose internal details
    return jsonResponse({ error: "Authentication failed" }, 500);
  }
}

// MARK: - Nonce Generation

async function handleNonceGeneration(request, env) {
  const clientIP = request.headers.get("CF-Connecting-IP") || "unknown";
  if (isAuthRateLimited(clientIP, 10)) {
    return jsonResponse({ error: "Rate limited" }, 429, { "Retry-After": "60" });
  }

  const nonceBytes = crypto.getRandomValues(new Uint8Array(32));
  const nonce = base64UrlEncode(String.fromCharCode(...nonceBytes));
  const expiresAt = Date.now() + 5 * 60 * 1000; // 5 minutes

  // HMAC-sign the nonce so we can verify it later without storage
  const hmacKey = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(env.JWT_SECRET),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const payload = `${nonce}:${expiresAt}`;
  const sig = await crypto.subtle.sign("HMAC", hmacKey, new TextEncoder().encode(payload));
  const signature = base64UrlEncode(String.fromCharCode(...new Uint8Array(sig)));

  return jsonResponse({ nonce, expiresAt, signature });
}

// MARK: - Token Refresh

async function handleTokenRefresh(request, env) {
  try {
    // Fix #7: Check request body size (even though refresh uses headers, enforce limit)
    const sizeError = checkContentLength(request, MAX_POST_BODY_SIZE);
    if (sizeError) return sizeError;

    // Fix #3: Rate limit refresh endpoint - 3 requests per minute per IP
    const clientIP = request.headers.get("CF-Connecting-IP") || "unknown";
    if (isAuthRateLimited(clientIP, 3)) {
      return jsonResponse({ error: "Rate limited" }, 429, { "Retry-After": "60" });
    }

    const authHeader = request.headers.get("Authorization");
    if (!authHeader?.startsWith("Bearer ")) {
      return jsonResponse({ error: "Missing authorization" }, 401);
    }

    const token = authHeader.slice(7);
    const payload = await verifyJWT(token, env.JWT_SECRET);
    if (!payload) {
      return jsonResponse({ error: "Invalid or expired token" }, 401);
    }

    // Issue a fresh token
    const newJWT = await createJWT(
      { sub: payload.sub, aud: payload.aud },
      env.JWT_SECRET,
      JWT_EXPIRY_SECONDS
    );

    return jsonResponse({
      token: newJWT,
      expiresIn: JWT_EXPIRY_SECONDS,
      userID: payload.sub,
    });
  } catch (error) {
    // Fix #6: Sanitize error messages
    return jsonResponse({ error: "Token refresh failed" }, 500);
  }
}

// MARK: - AI Proxy (existing behavior + JWT validation)

async function handleAIProxy(request, env) {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

  // Fix #7: Check request body size
  const sizeError = checkContentLength(request, MAX_POST_BODY_SIZE);
  if (sizeError) return sizeError;

  // Verify app bundle header
  const appBundle = request.headers.get("X-App-Bundle");
  if (appBundle !== "alnotha.FlowSate") {
    return jsonResponse({ error: "Unauthorized" }, 401);
  }

  // Verify JWT
  const authHeader = request.headers.get("Authorization");
  if (!authHeader?.startsWith("Bearer ")) {
    return jsonResponse({ error: "Authentication required" }, 401);
  }

  const token = authHeader.slice(7);
  const payload = await verifyJWT(token, env.JWT_SECRET);
  if (!payload) {
    return jsonResponse({ error: "Invalid or expired token" }, 401);
  }

  // Rate limiting per user
  const rateLimitKey = payload.sub || request.headers.get("CF-Connecting-IP") || "unknown";
  if (isRateLimited(rateLimitKey)) {
    return jsonResponse({ error: "Rate limited" }, 429, { "Retry-After": "60" });
  }

  try {
    // Fix #1: Check Content-Length for AI proxy body size (10KB limit)
    const contentLength = request.headers.get("Content-Length");
    if (contentLength && parseInt(contentLength, 10) > MAX_REQUEST_BODY_SIZE) {
      return jsonResponse({ error: "Request body too large" }, 413);
    }

    const body = await request.json();

    // Fix #1: Validate model is in the whitelist
    if (body.model && !ALLOWED_MODELS.has(body.model)) {
      return jsonResponse({ error: "Model not allowed" }, 400);
    }

    // Fix #1: Cap max_tokens
    if (body.max_tokens !== undefined) {
      body.max_tokens = Math.min(body.max_tokens, MAX_TOKENS_CAP);
    }

    // Fix #1: Strip unknown fields - only allow whitelisted fields
    const sanitizedBody = {};
    for (const field of ALLOWED_BODY_FIELDS) {
      if (body[field] !== undefined) {
        sanitizedBody[field] = body[field];
      }
    }

    const anthropicRequest = {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": env.ANTHROPIC_API_KEY,
        "anthropic-version": ANTHROPIC_VERSION,
      },
      body: JSON.stringify(sanitizedBody),
    };

    const isStreaming = sanitizedBody.stream === true;
    const response = await fetch(ANTHROPIC_API_URL, anthropicRequest);

    if (isStreaming) {
      return new Response(response.body, {
        status: response.status,
        headers: {
          "Content-Type": "text/event-stream",
          "Cache-Control": "no-cache",
        },
      });
    }

    const data = await response.json();
    return new Response(JSON.stringify(data), {
      status: response.status,
      headers: { "Content-Type": "application/json" },
    });
  } catch (error) {
    // Fix #6: Sanitize error messages
    return jsonResponse({ error: "Proxy error" }, 502);
  }
}

// MARK: - Apple Token Verification

// Fix #9: Accept expectedAudience as a parameter
async function verifyAppleToken(tokenString, expectedAudience) {
  try {
    // Decode header to get key ID
    const [headerB64] = tokenString.split(".");
    const header = JSON.parse(atob(headerB64.replace(/-/g, "+").replace(/_/g, "/")));
    const kid = header.kid;

    // Fix #4: Validate algorithm is RS256 before proceeding
    if (header.alg !== "RS256") {
      throw new Error("Unsupported algorithm");
    }

    // Fix #2: Use cached JWKS if fresh, otherwise fetch and cache
    const now = Date.now();
    let jwks;
    if (cachedJWKS.data && (now - cachedJWKS.fetchedAt) < JWKS_CACHE_TTL) {
      jwks = cachedJWKS.data;
    } else {
      const jwksResponse = await fetch(APPLE_JWKS_URL);
      jwks = await jwksResponse.json();
      cachedJWKS = { data: jwks, fetchedAt: now };
    }

    const key = jwks.keys.find((k) => k.kid === kid);
    if (!key) return null;

    // Import the public key
    const cryptoKey = await crypto.subtle.importKey(
      "jwk",
      key,
      { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
      false,
      ["verify"]
    );

    // Verify signature
    const [headerPart, payloadPart, signaturePart] = tokenString.split(".");
    const signedInput = new TextEncoder().encode(`${headerPart}.${payloadPart}`);
    const signature = base64UrlDecode(signaturePart);

    const valid = await crypto.subtle.verify("RSASSA-PKCS1-v1_5", cryptoKey, signature, signedInput);
    if (!valid) return null;

    // Decode and validate payload
    const payload = JSON.parse(atob(payloadPart.replace(/-/g, "+").replace(/_/g, "/")));

    // Check issuer
    if (payload.iss !== APPLE_ISSUER) return null;

    // Check expiration
    const now = Math.floor(Date.now() / 1000);
    if (payload.exp < now) return null;

    // Reject tokens issued more than 10 minutes ago
    if (payload.iat && payload.iat < (now - 600)) return null;

    // Fix #9: Verify audience inside verifyAppleToken
    if (payload.aud !== expectedAudience) return null;

    return payload;
  } catch {
    return null;
  }
}

// MARK: - JWT Creation & Verification (Web Crypto API)

async function createJWT(payload, secret, expirySeconds) {
  const header = { alg: "HS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const fullPayload = { ...payload, iat: now, exp: now + expirySeconds };

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(fullPayload));
  const signingInput = `${encodedHeader}.${encodedPayload}`;

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(signingInput));

  const encodedSignature = base64UrlEncode(String.fromCharCode(...new Uint8Array(signature)));

  return `${encodedHeader}.${encodedPayload}.${encodedSignature}`;
}

async function verifyJWT(token, secret) {
  try {
    const [headerB64, payloadB64, signatureB64] = token.split(".");
    if (!headerB64 || !payloadB64 || !signatureB64) return null;

    // Fix #10: Validate alg claim in the header is HS256
    const header = JSON.parse(atob(headerB64.replace(/-/g, "+").replace(/_/g, "/")));
    if (header.alg !== "HS256") return null;

    const key = await crypto.subtle.importKey(
      "raw",
      new TextEncoder().encode(secret),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["verify"]
    );

    const signingInput = `${headerB64}.${payloadB64}`;
    const signature = base64UrlDecode(signatureB64);

    const valid = await crypto.subtle.verify(
      "HMAC",
      key,
      signature,
      new TextEncoder().encode(signingInput)
    );
    if (!valid) return null;

    const payload = JSON.parse(atob(payloadB64.replace(/-/g, "+").replace(/_/g, "/")));

    // Check expiration
    if (payload.exp < Math.floor(Date.now() / 1000)) return null;

    return payload;
  } catch {
    return null;
  }
}

// MARK: - Utilities

async function sha256Hex(str) {
  const data = new TextEncoder().encode(str);
  const hash = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hash)).map(b => b.toString(16).padStart(2, "0")).join("");
}

function base64UrlEncode(str) {
  return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64UrlDecode(str) {
  const base64 = str.replace(/-/g, "+").replace(/_/g, "/");
  const padding = "=".repeat((4 - (base64.length % 4)) % 4);
  const binary = atob(base64 + padding);
  return new Uint8Array([...binary].map((c) => c.charCodeAt(0)));
}
