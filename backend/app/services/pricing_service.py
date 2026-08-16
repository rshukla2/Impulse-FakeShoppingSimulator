import math
from typing import Dict, Any, Optional

def format_currency_amount(amount: float, currency: str, symbol: str) -> str:
    currency = currency.upper()
    if currency == "INR":
        # Indian Numbering system format: ₹4,149 or ₹48,291
        int_part = int(round(amount))
        s = str(int_part)
        if len(s) > 3:
            last_three = s[-3:]
            remaining = s[:-3]
            formatted_remaining = ""
            while len(remaining) > 2:
                formatted_remaining = "," + remaining[-2:] + formatted_remaining
                remaining = remaining[:-2]
            formatted_remaining = remaining + formatted_remaining
            return f"{symbol}{formatted_remaining},{last_three}"
        return f"{symbol}{int_part}"
        
    elif currency == "JPY":
        # Japanese Yen typically has no decimals
        return f"{symbol}{int(round(amount)):,}"
        
    elif currency in ["USD", "GBP", "EUR", "CAD", "AUD", "SGD"]:
        return f"{symbol}{amount:,.2f}"
    else:
        return f"{symbol}{amount:,.2f}"


def localize_product_pricing(product_dict: Dict[str, Any], target_currency: str, exchange_rate: float, symbol: str) -> Dict[str, Any]:
    base_usd = product_dict.get("base_price_usd", 10.0)
    orig_usd = product_dict.get("original_price_usd")
    
    converted_price = base_usd * exchange_rate
    
    # Clean psychological rounding
    if target_currency in ["INR", "JPY"]:
        display_price = float(round(converted_price))
    else:
        display_price = round(converted_price, 2)
        
    formatted_price = format_currency_amount(display_price, target_currency, symbol)
    
    orig_display_price = None
    formatted_orig = None
    if orig_usd:
        orig_conv = orig_usd * exchange_rate
        if target_currency in ["INR", "JPY"]:
            orig_display_price = float(round(orig_conv))
        else:
            orig_display_price = round(orig_conv, 2)
        formatted_orig = format_currency_amount(orig_display_price, target_currency, symbol)
        
    result = dict(product_dict)
    result["display_price"] = display_price
    result["original_display_price"] = orig_display_price
    result["formatted_price"] = formatted_price
    result["formatted_original_price"] = formatted_orig
    result["currency"] = target_currency
    result["currency_symbol"] = symbol
    return result
