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

export interface DeliveryZoneAdmin extends DeliveryZone {
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
  status: OrderStatus;
  deliveryType: DeliveryType;
  deliveryId: number | null;
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
