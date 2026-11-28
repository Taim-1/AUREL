import { getApp, getApps, initializeApp } from "firebase-admin/app";
import { getAuth } from "firebase-admin/auth";
import { defineSecret } from "firebase-functions/params";
import { onRequest } from "firebase-functions/v2/https";
import { importPKCS8, SignJWT } from "jose";

const spotifyClientId = defineSecret("SPOTIFY_CLIENT_ID");
const spotifyClientSecret = defineSecret("SPOTIFY_CLIENT_SECRET");

const soundCloudClientId = defineSecret("SOUNDCLOUD_CLIENT_ID");
const soundCloudClientSecret = defineSecret("SOUNDCLOUD_CLIENT_SECRET");

const appleTeamId = defineSecret("APPLE_TEAM_ID");
const appleKeyId = defineSecret("APPLE_KEY_ID");
const applePrivateKey = defineSecret("APPLE_PRIVATE_KEY");
const openverseClientId = defineSecret("OPENVERSE_CLIENT_ID");
const openverseClientSecret = defineSecret("OPENVERSE_CLIENT_SECRET");

type Provider = "spotify" | "soundcloud" | "apple_music" | "openverse";

type TokenResult = {
  token: string;
  expiresAt: string;
};

const tokenCache = new Map<Provider, TokenResult>();
const tokenRequests = new Map<Provider, Promise<TokenResult>>();
const requestWindows = new Map<string, { start: number; count: number }>();

type JsonErrorResponse = {
  status(code: number): {
    json(body: { error: string; message: string }): unknown;
  };
};

function jsonError(
  response: JsonErrorResponse,
  status: number,
  message: string,
): void {
  response.status(status).json({
    error: status >= 500 ? "provider_not_configured" : "request_failed",
    message,
  });
}

function currentProjectAuth() {
  if (getApps().length === 0) initializeApp();
  return getAuth(getApp());
}

function enforceUserRateLimit(uid: string): boolean {
  const now = Date.now();
  const windowMs = 60_000;
  const limit = 30;
  const previous = requestWindows.get(uid);

  if (!previous || now - previous.start >= windowMs) {
    // Keep the per-instance rate-limit table bounded during long-lived
    // function instances that serve many distinct AUREL accounts.
    if (requestWindows.size >= 10_000) {
      for (const [key, window] of requestWindows) {
        if (now - window.start >= windowMs) requestWindows.delete(key);
      }
      if (requestWindows.size >= 10_000) return false;
    }
    requestWindows.set(uid, { start: now, count: 1 });
    return true;
  }

  if (previous.count >= limit) return false;
  previous.count += 1;
  return true;
}

function encodeBasic(value: string): string {
  return Buffer.from(value, "utf8").toString("base64");
}

async function fetchFormToken(
  url: string,
  clientId: string,
  clientSecret: string,
): Promise<TokenResult> {
  const response = await fetch(url, {
    method: "POST",
    headers: {
      Authorization: `Basic ${encodeBasic(`${clientId}:${clientSecret}`)}`,
      "Content-Type": "application/x-www-form-urlencoded",
      Accept: "application/json",
    },
    body: new URLSearchParams({ grant_type: "client_credentials" }),
    signal: AbortSignal.timeout(15_000),
  });

  if (!response.ok) {
    console.error("Provider token exchange failed", {
      status: response.status,
    });
    throw new Error("The provider rejected AUREL's server credentials.");
  }

  const payload = (await response.json()) as {
    access_token?: string;
    expires_in?: number;
  };
  const token = payload.access_token?.trim();
  if (!token) throw new Error("The provider returned no access token.");

  const lifetime = Math.max(60, (payload.expires_in ?? 1800) - 90);
  return {
    token,
    expiresAt: new Date(Date.now() + lifetime * 1000).toISOString(),
  };
}

async function spotifyToken(): Promise<TokenResult> {
  const clientId = spotifyClientId.value();
  const secret = spotifyClientSecret.value();
  if (!clientId || !secret) {
    throw new Error(
      "Spotify catalog access is not configured. Add the Spotify developer app credentials to Firebase Secret Manager.",
    );
  }
  return fetchFormToken(
    "https://accounts.spotify.com/api/token",
    clientId,
    secret,
  );
}

async function soundCloudToken(): Promise<TokenResult> {
  const clientId = soundCloudClientId.value();
  const secret = soundCloudClientSecret.value();
  if (!clientId || !secret) {
    throw new Error(
      "SoundCloud is not configured. Register an approved app and add its credentials to Firebase Secret Manager.",
    );
  }
  return fetchFormToken(
    "https://secure.soundcloud.com/oauth/token",
    clientId,
    secret,
  );
}

async function openverseToken(): Promise<TokenResult> {
  const clientId = openverseClientId.value().trim();
  const secret = openverseClientSecret.value().trim();
  if (!clientId || !secret) {
    throw new Error(
      "Additional open-catalogue authentication is not configured.",
    );
  }

  const response = await fetch(
    "https://api.openverse.org/v1/auth_tokens/token/",
    {
      method: "POST",
      headers: {
        "Content-Type": "application/x-www-form-urlencoded",
        Accept: "application/json",
      },
      body: new URLSearchParams({
        client_id: clientId,
        client_secret: secret,
        grant_type: "client_credentials",
      }),
      signal: AbortSignal.timeout(15_000),
    },
  );

  if (!response.ok) {
    console.error("AUREL open-catalogue token exchange failed", {
      status: response.status,
    });
    throw new Error("Additional catalogue authentication was rejected.");
  }

  const payload = (await response.json()) as {
    access_token?: string;
    expires_in?: number;
  };
  const token = payload.access_token?.trim();
  if (!token) throw new Error("Additional catalogue authentication returned no token.");
  const lifetime = Math.max(60, (payload.expires_in ?? 3600) - 90);
  return {
    token,
    expiresAt: new Date(Date.now() + lifetime * 1000).toISOString(),
  };
}
async function appleMusicToken(): Promise<TokenResult> {
  const teamId = appleTeamId.value().trim();
  const keyId = appleKeyId.value().trim();
  const privatePem = applePrivateKey.value().replace(/\\n/g, "\n").trim();

  if (!teamId || !keyId || !privatePem) {
    throw new Error(
      "Apple Music catalog access is not configured. Add the Apple developer team ID, key ID and private key to Firebase Secret Manager.",
    );
  }

  const privateKey = await importPKCS8(privatePem, "ES256");
  const token = await new SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: keyId, typ: "JWT" })
    .setIssuer(teamId)
    .setIssuedAt()
    .setExpirationTime("30m")
    .sign(privateKey);

  return {
    token,
    expiresAt: new Date(Date.now() + 25 * 60 * 1000).toISOString(),
  };
}

async function providerToken(provider: Provider): Promise<TokenResult> {
  const cached = tokenCache.get(provider);
  if (
    cached &&
    new Date(cached.expiresAt).getTime() > Date.now() + 60_000
  ) {
    return cached;
  }

  // Several federated catalogue requests can ask for the same provider token
  // at once. Share one exchange per provider instead of creating a burst of
  // duplicate OAuth requests.
  const inFlight = tokenRequests.get(provider);
  if (inFlight) return inFlight;

  const request = (async (): Promise<TokenResult> => {
    switch (provider) {
      case "spotify":
        return spotifyToken();
      case "soundcloud":
        return soundCloudToken();
      case "apple_music":
        return appleMusicToken();
      case "openverse":
        return openverseToken();
    }
  })();

  tokenRequests.set(provider, request);
  try {
    const result = await request;
    tokenCache.set(provider, result);
    return result;
  } finally {
    if (tokenRequests.get(provider) === request) {
      tokenRequests.delete(provider);
    }
  }
}

export const catalogTokens = onRequest(
  {
    region: "us-central1",
    timeoutSeconds: 30,
    memory: "256MiB",
    maxInstances: 5,
    secrets: [
      spotifyClientId,
      spotifyClientSecret,
      soundCloudClientId,
      soundCloudClientSecret,
      appleTeamId,
      appleKeyId,
      applePrivateKey,
      openverseClientId,
      openverseClientSecret,
    ],
  },
  async (request, response) => {
    response.set("Cache-Control", "no-store");
    response.set("X-Content-Type-Options", "nosniff");

    if (request.method !== "GET") {
      jsonError(response, 405, "Only GET is supported.");
      return;
    }

    const authorization = request.header("authorization") ?? "";
    const match = /^Bearer\s+(.+)$/i.exec(authorization);
    if (!match) {
      jsonError(response, 401, "Sign in to AUREL before requesting a provider token.");
      return;
    }

    let uid: string;
    try {
      const claims = await currentProjectAuth().verifyIdToken(match[1], true);
      uid = claims.uid;
    } catch {
      jsonError(response, 401, "Your AUREL session has expired. Sign in again.");
      return;
    }

    if (!enforceUserRateLimit(uid)) {
      jsonError(response, 429, "AUREL provider token requests are temporarily rate-limited.");
      return;
    }

    const rawProvider = String(request.query.provider ?? "").toLowerCase();
    if (
      rawProvider !== "spotify" &&
      rawProvider !== "soundcloud" &&
      rawProvider !== "apple_music" &&
      rawProvider !== "openverse"
    ) {
      jsonError(response, 400, "Choose a supported catalog provider.");
      return;
    }

    try {
      const result = await providerToken(rawProvider);
      response.status(200).json(result);
    } catch (error) {
      const message =
        error instanceof Error
          ? error.message
          : "The provider token could not be issued.";
      console.warn("AUREL provider is unavailable", {
        provider: rawProvider,
        message,
      });
      response.status(503).json({
        error: "provider_not_configured",
        message,
      });
    }
  },
);
