import { expect, test } from "vitest";
import { createApiClient } from "../tsp-output/@typespec/openapi3/openapi.yaml.client";

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

  // TODO use response variables for the url...
  const idsResp: { gmid: string; gcid: string; ucid: string } = await fetch(
    "https://socialize.eu1.gigya.com/socialize.getIDs", {
        method: "post",
        // TODO form data...
    }
  ).then((x) => x.json());

  const regionalApiClient = createApiClient(
    identityProvider.httpRegionalBaseUrl
  );
  //   regionalApiClient.
  //   const clientCredTokenResponse = await apiClient.TokenApi_tokenEndpoint({
  //     clientId: "AEGOneApp",
  //     clientSecret: import.meta.env.VITE_CLIENT_SECRET,
  //     grantType: "client_credentials",
  //     scope: "",
  //   });
  //   await expect(apiClient.CurrentUserApi_getUser()).resolves.toBeTruthy();
  //   const user = await getUserPromise;
  //   // api.expect(import.meta.env.VITE_ELECTROLUX_HOSTNAME).toBeTruthy();
  //   expect(user).toBeTruthy();
});
