import { Navigate, Route, Routes } from 'react-router-dom';
import RequireAuth from './components/RequireAuth';
import Layout from './components/Layout';
import LoginPage from './pages/LoginPage';
import DashboardPage from './pages/DashboardPage';
import RestaurantsListPage from './pages/restaurants/RestaurantsListPage';
import RestaurantFormPage from './pages/restaurants/RestaurantFormPage';
import RestaurantDetailPage from './pages/restaurants/RestaurantDetailPage';
import CategoriesPage from './pages/categories/CategoriesPage';
import ProductsListPage from './pages/products/ProductsListPage';
import ProductFormPage from './pages/products/ProductFormPage';
import DeliveryZonesListPage from './pages/zones/DeliveryZonesListPage';
import CouriersListPage from './pages/couriers/CouriersListPage';
import CourierDetailPage from './pages/couriers/CourierDetailPage';
import OrdersListPage from './pages/orders/OrdersListPage';
import OrderDetailPage from './pages/orders/OrderDetailPage';
import DeliveriesListPage from './pages/deliveries/DeliveriesListPage';
import DeliveryDetailPage from './pages/deliveries/DeliveryDetailPage';

export default function App() {
  return (
    <Routes>
      <Route path="/login" element={<LoginPage />} />
      <Route
        path="/"
        element={
          <RequireAuth>
            <Layout />
          </RequireAuth>
        }
      >
        <Route index element={<DashboardPage />} />

        <Route path="restaurants" element={<RestaurantsListPage />} />
        <Route path="restaurants/new" element={<RestaurantFormPage />} />
        <Route path="restaurants/:id" element={<RestaurantDetailPage />} />
        <Route path="restaurants/:id/categories" element={<CategoriesPage />} />
        <Route path="restaurants/:id/products" element={<ProductsListPage />} />
        <Route path="restaurants/:id/products/new" element={<ProductFormPage />} />
        <Route path="restaurants/:id/products/:productId/edit" element={<ProductFormPage />} />

        <Route path="delivery-zones" element={<DeliveryZonesListPage />} />

        <Route path="couriers" element={<CouriersListPage />} />
        <Route path="couriers/:id" element={<CourierDetailPage />} />

        <Route path="orders" element={<OrdersListPage />} />
        <Route path="orders/:id" element={<OrderDetailPage />} />

        <Route path="deliveries" element={<DeliveriesListPage />} />
        <Route path="deliveries/:id" element={<DeliveryDetailPage />} />

        <Route path="*" element={<Navigate to="/" replace />} />
      </Route>
    </Routes>
  );
}
