<?php

namespace App\Enum;

/**
 * Which of the client home screen's four services an order belongs to (see
 * mobile HomeScreen). Only RESTAURANT is backed by a real ordering flow
 * today — OrderService::createOrder always sets it explicitly — the other
 * three exist so the column doesn't need another migration once Factures/
 * Courses/Colis get their own backend.
 */
enum DeliveryType: string
{
    case RESTAURANT = 'RESTAURANT';
    case BILL = 'BILL';
    case GROCERY = 'GROCERY';
    case PARCEL = 'PARCEL';
}