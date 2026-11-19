import { test, expect, type Route } from "@playwright/test";
import { loginAsAdmin, mockStats } from "./mockApi";

function json(route: Route, body: unknown, status = 200) {
  return route.fulfill({
    status,
    contentType: "application/json",
    body: JSON.stringify(body),
  });
}

function order(status: string) {
  return {
    id: 7,
    userId: 3,
    userName: "Sami Client",
    userPhone: "22000001",
    restaurantId: 1,
    restaurantName: "Le Bon Burger",
    items: [
      {
        id: 1,
        productId: 3,
        productName: "Classic Smash",
        option: null,
        quantity: 2,
        unitPrice: "12.000",
      },
    ],
    note: null,
    pickupAddress: null,
    deliveryAddress: "Rue de Marseille",
    recipientName: null,
    recipientPhone: null,
    deliveryZoneId: 1,
    deliveryZoneName: "Bizerte centre",
    deliveryFee: "4.000",
    totalAmount: "28.000",
    discountAmount: null,
    promotionTitle: null,
    promoCode: null,
    status,
    deliveryType: "RESTAURANT",
    deliveryId: 12,
    bill: null,
    createdAt: "2026-10-01T10:00:00+00:00",
    updatedAt: "2026-10-01T10:00:00+00:00",
  };
}

test("a cancelled order is deleted after confirming, back to the list", async ({
  page,
}) => {
  let deleted = false;
  await mockStats(page);
  await page.route("**/api/admin/orders?**", (route) =>
    json(route, {
      items: [],
      meta: { page: 1, limit: 20, total: 0, pages: 0 },
    }),
  );
  await page.route("**/api/admin/orders/7", (route) => {
    if (route.request().method() === "DELETE") {
      deleted = true;
      return route.fulfill({ status: 204 });
    }
    return json(route, order("CANCELLED"));
  });

  await loginAsAdmin(page);
  await page.goto("/orders/7");

  // Over: nothing left to cancel, only to delete.
  await expect(page.getByRole("button", { name: "Cancel order" })).toHaveCount(
    0,
  );
  page.once("dialog", (dialog) => {
    expect(dialog.message()).toContain("Delete order #7 for good?");
    dialog.accept();
  });
  await page.getByRole("button", { name: "Delete order" }).click();

  await expect(page).toHaveURL(/\/orders$/);
  expect(deleted).toBe(true);
});

test("an order on its way can only be cancelled, not deleted", async ({
  page,
}) => {
  await mockStats(page);
  await page.route("**/api/admin/orders/7", (route) =>
    json(route, order("PREPARING")),
  );

  await loginAsAdmin(page);
  await page.goto("/orders/7");

  await expect(
    page.getByRole("button", { name: "Cancel order" }),
  ).toBeVisible();
  await expect(page.getByRole("button", { name: "Delete order" })).toHaveCount(
    0,
  );
});
