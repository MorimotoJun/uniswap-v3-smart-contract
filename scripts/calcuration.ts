'use strict';

enum SlippageType {
    Lower, Higher
}

function getSqrtPriceLimitX96(price: number, type: SlippageType): number {
    if (type == SlippageType.Lower) price = price * 0.1;
    if (type == SlippageType.Lower) price = price * 1.1;

    const sqrtPrice = Math.sqrt(price);
    
    const sqrtPriceLimitX96 = sqrtPrice * 2^96;

    return sqrtPriceLimitX96;
}
