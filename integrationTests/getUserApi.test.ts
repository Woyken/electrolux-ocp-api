import { expect, test } from "vitest";
import { createApiClient } from "../tsp-output/@typespec/openapi3/openapi.yaml.client";
import HmacSHA1 from "crypto-js/hmac-sha1";
import * as CryptoJS from "crypto-js";
import * as z from "zod";

test("is valid user response", async () => {
  const apiClient = createApiClient(import.meta.env.VITE_ELECTROLUX_HOSTNAME);
  const clientCredentialsTokenResponse = await apiClient.TokenApi_tokenEndpoint(
    {
      clientId: "AEGOneApp",
      clientSecret: import.meta.env.VITE_CLIENT_SECRET,
      grantType: "client_credentials",
      scope: "",
    },
    {
      headers: {
        "Content-Type": "application/json",
        "User-Agent": "PostmanRuntime/7.39.0",
      },
    }
  );
  const identityProviders = await apiClient.CurrentUserApi_getIdentityProviders(
    {
      queries: { brand: "aeg", email: import.meta.env.VITE_USER1_USERNAME },
      headers: {
        Authorization: `Bearer ${clientCredentialsTokenResponse.accessToken}`,
        "x-api-key": import.meta.env.VITE_X_API_KEY,
      },
    }
  );
  const identityProvider = identityProviders[0];
  if (!identityProvider)
    throw new Error("No identity providers returned, panic!");

  let formData = new FormData();
  formData.append("apiKey", identityProvider.apiKey);
  formData.append("format", "json");
  formData.append("httpStatusCodes", "true");
  formData.append("nonce", "1687789908080_1540298564");
  formData.append("sdk", "Android_6.2.1");
  formData.append("targetEnv", "mobile");
  // TODO all others
  // TODO use response variables for the url...
  const gigyaSocializeGetIdsResponse = await fetch(
    "https://socialize.eu1.gigya.com/socialize.getIDs",
    {
      method: "post",
      body: formData,
    }
  ).then((x) => x.json());

  const idsRespSchema = z.object({
    gmid: z.string(),
    gcid: z.string(),
    ucid: z.string(),
  });

  const gigyaIds = idsRespSchema.parse(gigyaSocializeGetIdsResponse);

  const gigayaAccountsLoginSchema = z.object({
    sessionInfo: z.object({
      sessionToken: z.string(),
      sessionSecret: z.string(),
    }),
  });

  let nonce = `${Date.now()}_${Math.random() * 1000000000}`;
  formData = new FormData();
  formData.append("apiKey", identityProvider.apiKey);
  formData.append("format", "json");
  formData.append("httpStatusCodes", "true");
  formData.append("nonce", nonce);
  formData.append("sdk", "Android_6.2.1");
  formData.append("targetEnv", "mobile");
  formData.append("gmid", gigyaIds.gmid);
  formData.append("ucid", gigyaIds.ucid);
  formData.append("loginID", import.meta.env.VITE_USER1_USERNAME);
  formData.append("password", import.meta.env.VITE_USER1_PASSWORD);

  const gigayaAccountsLogin = await fetch(
    "https://accounts.eu1.gigya.com/accounts.login",
    {
      method: "post",
      body: formData,
    }
  )
    .then((x) => x.json())
    .then(gigayaAccountsLoginSchema.parse);

  const strictEncode = (str: string) =>
    encodeURIComponent(str).replace(
      /[!'()*]/g,
      (x) => `%${x.charCodeAt(0).toString(16).toUpperCase()}`
    );

  nonce = `${Date.now()}_${Math.floor(Math.random() * 1000000000)}`;
  const timestampSeconds = Math.floor(Date.now() / 1000);

  // Must be sorted alphabetically, easy way is to convert to object and back
  const body = {
    apiKey: identityProvider.apiKey,
    fields: "country",
    format: "json",
    gmid: gigyaIds.gmid,
    httpStatusCodes: "true",
    nonce: nonce,
    oauth_token: gigayaAccountsLogin.sessionInfo.sessionToken,
    sdk: "Android_6.2.1",
    targetEnv: "mobile",
    timestamp: timestampSeconds,
    ucid: gigyaIds.ucid,
  };
  formData = Object.entries(body).reduce(
    (d, e) => (d.append(...e), d),
    new FormData()
  );
  const formDataAsQuery = new URLSearchParams(formData as any).toString();
  const sig = HmacSHA1(
    `POST&${strictEncode("https://accounts.eu1.gigya.com/accounts.getJWT")}&${strictEncode(formDataAsQuery)}`,
    CryptoJS.enc.Base64.parse(gigayaAccountsLogin.sessionInfo.sessionSecret)
  ).toString(CryptoJS.enc.Base64);

  const bodyWithSig = {
    ...body,
    sig: sig,
  };
  formData = Object.entries(bodyWithSig).reduce(
    (d, e) => (d.append(...e), d),
    new FormData()
  );

  const gigayaAccountsGetJwtSchema = z.object({
    id_token: z.string(),
  });

  const gigayaAccountsGetJwt = await fetch(
    "https://accounts.eu1.gigya.com/accounts.getJWT",
    {
      method: "post",
      body: formData,
    }
  )
    .then((x) => x.json())
    .then(gigayaAccountsGetJwtSchema.parse);

  const regionalApiClient = createApiClient(
    identityProvider.httpRegionalBaseUrl
  );

  const userToken = await regionalApiClient.TokenApi_tokenEndpoint({
    grantType: "urn:ietf:params:oauth:grant-type:token-exchange",
    clientId: "AEGOneApp",
    idToken: gigayaAccountsGetJwt.id_token,
    scope: "",
  });

  await expect(
    regionalApiClient.CurrentUserApi_getUser({
      headers: {
        Authorization: `Bearer ${userToken.accessToken}`,
        "x-api-key": import.meta.env.VITE_X_API_KEY,
      },
    })
  ).resolves.toBeTruthy();
});
