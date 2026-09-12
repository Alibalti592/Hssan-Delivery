import { api } from './client';
import type {
  AdminDelivery,
  AdminOrder,
  Category,
  Courier,
  CurrentUser,
  DeliveryZoneAdmin,
  Paginated,
  Product,
  Restaurant,
} from './types';

export interface PageParams {
  page?: number;
  limit?: number;
}

function toQuery(params?: PageParams): string {
  if (!params) return '';

  const qs = new URLSearchParams();
  if (params.page !== undefined) qs.set('page', String(params.page));
  if (params.limit !== undefined) qs.set('limit', String(params.limit));

  const s = qs.toString();
  return s ? `?${s}` : '';
}

// Auth
export const authApi = {
  login: (phone: string, password: string) =>
    api.post<{ token: string }>('/api/auth/login', { phone, password }),
  me: () => api.get<CurrentUser>('/api/auth/me'),
};

// Restaurants
export const restaurantsApi = {
  list: (params?: PageParams) =>
    api.get<Paginated<Restaurant>>(`/api/admin/restaurants${toQuery(params)}`),
  get: (id: number) => api.get<Restaurant>(`/api/admin/restaurants/${id}`),
  create: (data: { name: string; description: string | null; isAvailable: boolean }) =>
    api.post<Restaurant>('/api/admin/restaurants', data),
  update: (id: number, data: { name: string; description: string | null; isAvailable: boolean }) =>
    api.put<Restaurant>(`/api/admin/restaurants/${id}`, data),
  setAvailability: (id: number, isAvailable: boolean) =>
    api.patch<Restaurant>(`/api/admin/restaurants/${id}/availability`, { isAvailable }),
  delete: (id: number) => api.delete<void>(`/api/admin/restaurants/${id}`),
  uploadPhoto: (id: number, file: File) =>
    api.upload<Restaurant>(`/api/admin/restaurants/${id}/photo`, file),
  removePhoto: (id: number) => api.delete<Restaurant>(`/api/admin/restaurants/${id}/photo`),
};

// Categories
export const categoriesApi = {
  listForRestaurant: (restaurantId: number) =>
    api.get<Category[]>(`/api/admin/restaurants/${restaurantId}/categories`),
  get: (id: number) => api.get<Category>(`/api/admin/categories/${id}`),
  create: (restaurantId: number, data: { name: string }) =>
    api.post<Category>(`/api/admin/restaurants/${restaurantId}/categories`, data),
  update: (id: number, data: { name: string }) =>
    api.put<Category>(`/api/admin/categories/${id}`, data),
};

// Products
export const productsApi = {
  listForRestaurant: (restaurantId: number, params?: PageParams) =>
    api.get<Paginated<Product>>(`/api/admin/restaurants/${restaurantId}/products${toQuery(params)}`),
  get: (id: number) => api.get<Product>(`/api/admin/products/${id}`),
  create: (
    restaurantId: number,
    data: { name: string; description: string | null; price: string; categoryId: number; isAvailable: boolean },
  ) => api.post<Product>(`/api/admin/restaurants/${restaurantId}/products`, data),
  update: (
    id: number,
    data: { name: string; description: string | null; price: string; categoryId: number; isAvailable: boolean },
  ) => api.put<Product>(`/api/admin/products/${id}`, data),
  setAvailability: (id: number, isAvailable: boolean) =>
    api.patch<Product>(`/api/admin/products/${id}/availability`, { isAvailable }),
  delete: (id: number) => api.delete<void>(`/api/admin/products/${id}`),
  uploadPhoto: (id: number, file: File) =>
    api.upload<Product>(`/api/admin/products/${id}/photo`, file),
  removePhoto: (id: number) => api.delete<Product>(`/api/admin/products/${id}/photo`),
};

// Delivery zones
export const deliveryZonesApi = {
  list: () => api.get<DeliveryZoneAdmin[]>('/api/admin/delivery-zones'),
  get: (id: number) => api.get<DeliveryZoneAdmin>(`/api/admin/delivery-zones/${id}`),
  create: (data: { name: string; fee: string }) =>
    api.post<DeliveryZoneAdmin>('/api/admin/delivery-zones', data),
  update: (id: number, data: { name: string; fee: string }) =>
    api.put<DeliveryZoneAdmin>(`/api/admin/delivery-zones/${id}`, data),
};

// Couriers
export const couriersApi = {
  list: (params?: PageParams) => api.get<Paginated<Courier>>(`/api/admin/couriers${toQuery(params)}`),
  get: (id: number) => api.get<Courier>(`/api/admin/couriers/${id}`),
  create: (data: { name: string; phone: string; password: string }) =>
    api.post<Courier>('/api/admin/couriers', data),
  setActive: (id: number, isActive: boolean) =>
    api.patch<Courier>(`/api/admin/couriers/${id}/active`, { isActive }),
  resetPassword: (id: number, password: string) =>
    api.patch<Courier>(`/api/admin/couriers/${id}/password`, { password }),
};

// Dashboard summary
export interface AdminStats {
  restaurants: number;
  deliveryZones: number;
  couriers: number;
  totalOrders: number;
  activeOrders: number;
}

export const statsApi = {
  summary: () => api.get<AdminStats>('/api/admin/stats'),
};

// Orders (admin)
export const ordersApi = {
  list: (params?: PageParams) => api.get<Paginated<AdminOrder>>(`/api/admin/orders${toQuery(params)}`),
  get: (id: number) => api.get<AdminOrder>(`/api/admin/orders/${id}`),
};

// Deliveries (admin visibility + actions)
export const deliveriesApi = {
  list: (params?: PageParams) => api.get<Paginated<AdminDelivery>>(`/api/admin/deliveries${toQuery(params)}`),
  get: (id: number) => api.get<AdminDelivery>(`/api/admin/deliveries/${id}`),
  assign: (deliveryId: number, courierId: number) =>
    api.post<AdminDelivery>(`/api/deliveries/${deliveryId}/assign/${courierId}`),
  cancel: (deliveryId: number) =>
    api.post<AdminDelivery>(`/api/deliveries/${deliveryId}/cancel`),
};
