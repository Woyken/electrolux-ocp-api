import { expect, test } from "vitest";

test("is valid environment", async () => {
  expect(import.meta.env.VITE_USER1_USERNAME).toBeTruthy();
  expect(import.meta.env.VITE_USER1_PASSWORD).toBeTruthy();
  expect(import.meta.env.VITE_ELECTROLUX_HOSTNAME).toBeTruthy();
  expect(import.meta.env.VITE_CLIENT_SECRET).toBeTruthy();
});
