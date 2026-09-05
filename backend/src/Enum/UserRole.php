<?php

namespace App\Enum;

enum UserRole: string
{
    case CLIENT = 'ROLE_CLIENT';
    case LIVREUR = 'ROLE_LIVREUR';
    case ADMIN = 'ROLE_ADMIN';
}