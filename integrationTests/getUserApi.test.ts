import { expect, test } from "vitest";
import { createApiClient } from "../tsp-output/@typespec/openapi3/openapi.yaml.client";
import HmacSHA1 from "crypto-js/hmac-sha1";
import * as CryptoJS from "crypto-js";

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
  const clientCredToken = clientCredentialsTokenResponse.accessToken;
  const identityProviders = await apiClient.CurrentUserApi_getIdentityProviders(
    {
      queries: { brand: "aeg", email: import.meta.env.VITE_USER1_USERNAME },
    }
  );
  const identityProvider = identityProviders[0];

  const formData = new FormData();
  formData.append("apiKey", identityProvider.apiKey)
  formData.append("format", "json")
  // TODO all others
  // TODO use response variables for the url...
  const idsResp: { gmid: string; gcid: string; ucid: string } = await fetch(
    "https://socialize.eu1.gigya.com/socialize.getIDs",
    {
      method: "post",
      // TODO form data...
    }
  ).then((x) => x.json());

  const loginResp: {
    sessionInfo: {
      sessionToken: string;
      sessionSecret: string;
    };
  } = await fetch("https://accounts.eu1.gigya.com/accounts.login", {
    method: "post",
    // TODO form data...
  }).then((x) => x.json());

  const strictEncode = (str) =>
    encodeURIComponent(str).replace(
      /[!'()*]/g,
      (x) => `%${x.charCodeAt(0).toString(16).toUpperCase()}`
    );

  const nonce = `${Date.now()}_${Math.floor(Math.random() * 1000000000)}`;
  const timestampSeconds = Math.floor(Date.now() / 1000);

  const sig = HmacSHA1(
    `POST&${strictEncode("https://accounts.eu1.gigya.com/accounts.getJWT")}&${strictEncode(`apiKey=${identityProvider.apiKey}&fields=country&format=json&gmid=${idsResp.gmid}&httpStatusCodes=false&nonce=${nonce}&oauth_token=${loginResp.sessionInfo.sessionToken}&sdk=Android_6.2.1&targetEnv=mobile&timestamp=${timestampSeconds}&ucid=${idsResp.ucid}`)}`,
    CryptoJS.enc.Base64.parse(loginResp.sessionInfo.sessionSecret)
  ).toString(CryptoJS.enc.Base64);

  const getJwtResp: { idToken: string } = await fetch(
    "https://accounts.eu1.gigya.com/accounts.getJWT",
    {
      method: "post",
      // TODO form data...
    }
  ).then((x) => x.json());

  // POST https://api.eu.ocp.electrolux.one/one-account-authorization/api/v1/token
  // {
  //     "grantType": "urn:ietf:params:oauth:grant-type:token-exchange",
  //     "clientId": "AEGOneApp",
  //     "idToken": "{{idToken}}",
  //     "scope": ""
  // }

  const regionalApiClient = createApiClient(
    identityProvider.httpRegionalBaseUrl
  );

  const userToken = await regionalApiClient.TokenApi_tokenEndpoint({
    grantType: "urn:ietf:params:oauth:grant-type:token-exchange",
    clientId: "AEGOneApp",
    idToken: getJwtResp.idToken,
    scope: "",
  });

  await expect(
    apiClient.CurrentUserApi_getUser({
      headers: { Authorization: userToken.accessToken },
    })
  ).resolves.toBeTruthy();
  //   const user = await getUserPromise;
  //   // api.expect(import.meta.env.VITE_ELECTROLUX_HOSTNAME).toBeTruthy();
  //   expect(user).toBeTruthy();
});
