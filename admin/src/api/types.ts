export type RestaurantType = 'RESTAURANT' | 'GROCERY';

export interface Restaurant {
  id: number;
  name: string;
  description: string | null;
  isAvailable: boolean;
  type: RestaurantType;
  photoUrl: string | null;
  createdAt: string;
  updatedAt: string;
}

export interface Category {
  id: number;
  name: string;
  restaurantId: number;
  createdAt: string;
  updatedAt: string;
}

// A size/portion of a product ("M", "Familiale", "12 pièces"...) with its
// own price. When a product has options, `price` is the cheapest one.
export interface ProductOption {
  name: string;
  price: string;
}

export interface Product {
  id: number;
  name: string;
  description: string | null;
  price: string;
  options: ProductOption[];
  isAvailable: boolean;
  photoUrl: string | null;
  restaurantId: number;
  categoryId: number;
  createdAt: string;
  updatedAt: string;
}

export interface DeliveryZone {
  id: number;
  name: string;
  fee: string;
}

export interface DeliveryZoneArea {
  /** Center of the zone on the map, and the radius it covers. Null until placed. */
  latitude: number | null;
  longitude: number | null;
  radiusKm: number | null;
}

export interface DeliveryZoneAdmin extends DeliveryZone, DeliveryZoneArea {
  createdAt: string;
  updatedAt: string;
}

export interface Courier {
  id: number;
  name: string;
  phone: string;
  roles: string[];
  verified: boolean;
  isActive: boolean;
  createdAt: string;
  updatedAt: string;
}

export interface OrderItem {
  id: number;
  productId: number;
  productName: string;
  option: string | null;
  quantity: number;
  unitPrice: string;
}

export type DeliveryType = 'RESTAURANT' | 'BILL' | 'GROCERY' | 'PARCEL';

/** BILL: the courier pays a bill; TRANSFER: sends a mandat (IZI, Wafa Cash). */
export type BillProviderKind = 'BILL' | 'TRANSFER';

/** A company on the app's Factures screen (see backend BillProvider). */
export interface BillProvider {
  id: number;
  name: string;
  kind: BillProviderKind;
  logoUrl: string | null;
  /** Hidden providers stay on past orders but aren't offered in the app. */
  isActive: boolean;
  position: number;
}

/** The Factures part of an order (backend BillSummary). A mandat's receiver
 * is the order's recipientName/recipientPhone. */
export interface OrderBill {
  providerId: number;
  providerName: string;
  providerKind: BillProviderKind;
  providerLogoUrl: string | null;
  /** The bill's reference; null for a mandat. */
  reference: string | null;
  amount: string;
  /** Private: load it with api.blobUrl, never as a plain <img src>. */
  photoUrl: string | null;
}

export interface AdminOrder {
  id: number;
  userId: number;
  userName: string;
  userPhone: string;
  restaurantId: number | null;
  restaurantName: string | null;
  items: OrderItem[];
  note: string | null;
  /** Colis (parcel) orders only — where the courier collects the package. */
  pickupAddress: string | null;
  deliveryAddress: string;
  /** Colis (parcel) orders only — who receives it at deliveryAddress. */
  recipientName: string | null;
  recipientPhone: string | null;
  deliveryZoneId: number;
  deliveryZoneName: string;
  deliveryFee: string;
  totalAmount: string;
  /** Taken off the items by a promotion ("0.000" without). */
  discountAmount: string;
  /** The promotion's title and code as they were when the order was placed. */
  promotionTitle: string | null;
  promoCode: string | null;
  status: OrderStatus;
  deliveryType: DeliveryType;
  deliveryId: number | null;
  /** Factures orders only. */
  bill: OrderBill | null;
  /** The pins the client placed on the map; null when only typed. */
  pickupLatitude: number | null;
  pickupLongitude: number | null;
  deliveryLatitude: number | null;
  deliveryLongitude: number | null;
  createdAt: string;
  updatedAt: string;
}

export type OrderStatus =
  | 'PENDING'
  | 'CONFIRMED'
  | 'PREPARING'
  | 'READY_FOR_PICKUP'
  | 'COMPLETED'
  | 'CANCELLED';

export type DeliveryStatus =
  | 'PENDING'
  | 'ASSIGNED'
  | 'ACCEPTED'
  | 'PICKED_UP'
  | 'ON_THE_WAY'
  | 'DELIVERED'
  | 'CANCELLED'
  | 'FAILED';

/** What a delivery carries about its order (backend DeliveryResponse). */
export interface DeliveryOrderSummary {
  id: number;
  status: OrderStatus;
  deliveryType: DeliveryType;
  restaurantName: string | null;
  customerName: string | null;
  customerPhone: string | null;
  pickupAddress: string | null;
  deliveryAddress: string;
  totalAmount: string;
  bill: OrderBill | null;
}

/** An order waiting for the admin to give it to a courier. */
export interface WaitingDelivery extends AdminDelivery {
  order: DeliveryOrderSummary | null;
}

export interface AdminDelivery {
  id: number;
  orderId: number;
  status: DeliveryStatus;
  courierId: number | null;
  assignedAt: string | null;
  acceptedAt: string | null;
  pickedUpAt: string | null;
  deliveredAt: string | null;
  createdAt: string;
}

// FIXED_PRICE is a bundle sold at a set price ("2 sandwiches + frites —
// 11 DT"): discountValue is that price, and the backend orders it through a
// product it manages (productId).
export type DiscountType = 'PERCENTAGE' | 'FIXED_AMOUNT' | 'FIXED_PRICE';

export interface Promotion {
  id: number;
  title: string;
  description: string | null;
  photoUrl: string | null;
  discountType: DiscountType;
  discountValue: string;
  promoCode: string | null;
  startAt: string;
  /** null = no end date: shown until the admin hides it. */
  endAt: string | null;
  isActive: boolean;
  restaurantId: number | null;
  restaurantName: string | null;
  /** FIXED_PRICE only: what the offer includes, one line per item. */
  items: string[];
  productId: number | null;
  createdAt: string;
  updatedAt: string;
}

export type CourierMapStatus = 'ONLINE' | 'ON_DELIVERY' | 'OFFLINE';

export interface CourierLocationEntry {
  courierId: number;
  name: string;
  status: CourierMapStatus;
  latitude: number | null;
  longitude: number | null;
  updatedAt: string | null;
  currentDeliveryId: number | null;
}

export interface CurrentUser {
  id: number;
  name: string;
  phone: string;
  roles: string[];
  isVerified: boolean;
}

export interface ApiErrorBody {
  message?: string;
  error?: string;
  errors?: { field: string; message: string }[];
}

export interface PaginationMeta {
  page: number;
  limit: number;
  total: number;
  pages: number;
}

export interface Paginated<T> {
  items: T[];
  meta: PaginationMeta;
}
