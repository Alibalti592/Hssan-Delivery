<?php

namespace App\Enum;

/**
 * What a courier does at a BillProvider's counter: pay a bill the client
 * hands over (STEG, SONEDE...), or send money on the client's behalf (a
 * mandat through IZI or Wafa Cash) — which decides the fields a Factures
 * order needs (a bill reference vs. who receives the money).
 */
enum BillProviderKind: string
{
    case BILL = 'BILL';
    case TRANSFER = 'TRANSFER';
}
