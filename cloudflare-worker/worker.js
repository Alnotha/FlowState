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

const rateLimitMap = new Map();

function isRateLimited(key) {
  const now = Date.now();
  const windowStart = now - 60000;
  const timestamps = (rateLimitMap.get(key) || []).filter((t) => t > windowStart);
  if (timestamps.length >= RATE_LIMIT_PER_MINUTE) return true;
  timestamps.push(now);
  rateLimitMap.set(key, timestamps);
  return false;
}

function corsHeaders() {
  return {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type, X-App-Bundle, Authorization",
    "Access-Control-Max-Age": "86400",
  };
}

function jsonResponse(body, status = 200, extraHeaders = {}) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders(), ...extraHeaders },
  });
}

export default {
  async fetch(request, env) {
    const url = new URL(request.url);

    // CORS preflight
    if (request.method === "OPTIONS") {
      return new Response(null, { headers: corsHeaders() });
    }

    // Route handling
    if (url.pathname === "/auth/apple" && request.method === "POST") {
      return handleAppleAuth(request, env);
    }

    if (url.pathname === "/auth/refresh" && request.method === "POST") {
      return handleTokenRefresh(request, env);
    }

    // Default: AI proxy with JWT validation
    return handleAIProxy(request, env);
  },
};

// MARK: - Apple Auth Endpoint

async function handleAppleAuth(request, env) {
  try {
    const body = await request.json();
    const { identityToken, userIdentifier } = body;

    if (!identityToken || !userIdentifier) {
      return jsonResponse({ error: "Missing identityToken or userIdentifier" }, 400);
    }

    // Verify Apple identity token
    const applePayload = await verifyAppleToken(identityToken);
    if (!applePayload) {
      return jsonResponse({ error: "Invalid Apple identity token" }, 401);
    }

    // Verify the subject matches
    if (applePayload.sub !== userIdentifier) {
      return jsonResponse({ error: "User identifier mismatch" }, 401);
    }

    // Verify audience matches our bundle ID
    if (applePayload.aud !== APPLE_AUDIENCE) {
      return jsonResponse({ error: "Token audience mismatch" }, 401);
    }

    // Issue our own JWT
    const jwt = await createJWT(
      { sub: userIdentifier, aud: APPLE_AUDIENCE },
      env.JWT_SECRET,
      JWT_EXPIRY_SECONDS
    );

    return jsonResponse({
      token: jwt,
      expiresIn: JWT_EXPIRY_SECONDS,
      userID: userIdentifier,
    });
  } catch (error) {
    return jsonResponse({ error: "Auth error", message: error.message }, 500);
  }
}

// MARK: - Token Refresh

async function handleTokenRefresh(request, env) {
  try {
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
    return jsonResponse({ error: "Refresh error", message: error.message }, 500);
  }
}

// MARK: - AI Proxy (existing behavior + JWT validation)

async function handleAIProxy(request, env) {
  if (request.method !== "POST") {
    return jsonResponse({ error: "Method not allowed" }, 405);
  }

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
    const body = await request.json();

    const anthropicRequest = {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": env.ANTHROPIC_API_KEY,
        "anthropic-version": ANTHROPIC_VERSION,
      },
      body: JSON.stringify(body),
    };

    const isStreaming = body.stream === true;
    const response = await fetch(ANTHROPIC_API_URL, anthropicRequest);

    if (isStreaming) {
      return new Response(response.body, {
        status: response.status,
        headers: {
          "Content-Type": "text/event-stream",
          "Cache-Control": "no-cache",
          ...corsHeaders(),
        },
      });
    }

    const data = await response.json();
    return new Response(JSON.stringify(data), {
      status: response.status,
      headers: { "Content-Type": "application/json", ...corsHeaders() },
    });
  } catch (error) {
    return jsonResponse({ error: "Proxy error", message: error.message }, 502);
  }
}

// MARK: - Apple Token Verification

async function verifyAppleToken(tokenString) {
  try {
    // Decode header to get key ID
    const [headerB64] = tokenString.split(".");
    const header = JSON.parse(atob(headerB64.replace(/-/g, "+").replace(/_/g, "/")));
    const kid = header.kid;

    // Fetch Apple's public keys (JWKS)
    const jwksResponse = await fetch(APPLE_JWKS_URL);
    const jwks = await jwksResponse.json();
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
    if (payload.exp < Math.floor(Date.now() / 1000)) return null;

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

function base64UrlEncode(str) {
  return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function base64UrlDecode(str) {
  const base64 = str.replace(/-/g, "+").replace(/_/g, "/");
  const padding = "=".repeat((4 - (base64.length % 4)) % 4);
  const binary = atob(base64 + padding);
  return new Uint8Array([...binary].map((c) => c.charCodeAt(0)));
}
