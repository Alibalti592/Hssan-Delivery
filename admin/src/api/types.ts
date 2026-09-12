export interface Restaurant {
  id: number;
  name: string;
  description: string | null;
  isAvailable: boolean;
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

export interface Product {
  id: number;
  name: string;
  description: string | null;
  price: string;
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
  quantity: number;
  unitPrice: string;
}

export interface AdminOrder {
  id: number;
  userId: number;
  userName: string;
  userPhone: string;
  restaurantId: number;
  restaurantName: string;
  items: OrderItem[];
  note: string | null;
  deliveryAddress: string;
  deliveryZoneId: number;
  deliveryZoneName: string;
  deliveryFee: string;
  totalAmount: string;
  status: OrderStatus;
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
