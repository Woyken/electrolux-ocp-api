import { expect, test } from "vitest";
import { createApiClient } from "../tsp-output/@typespec/openapi3/openapi.yaml.client";

test("is valid token response", async () => {
  const apiClient = createApiClient(import.meta.env.VITE_ELECTROLUX_HOSTNAME);

  await expect(
    apiClient.TokenApi_tokenEndpoint({
      clientId: "AEGOneApp",
      clientSecret: import.meta.env.VITE_CLIENT_SECRET,
      grantType: "client_credentials",
      scope: "",
    })
  ).resolves.not.toThrowError();
});
