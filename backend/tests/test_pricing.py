from backend.app.services.pricing_service import format_currency_amount, localize_product_pricing

def test_indian_rupee_formatting():
    # Verify Indian numbering grouping (e.g. ₹4,149 and ₹48,291)
    res1 = format_currency_amount(4149.0, "INR", "₹")
    assert res1 == "₹4,149"
    
    res2 = format_currency_amount(48291.0, "INR", "₹")
    assert res2 == "₹48,291"

def test_usd_formatting():
    res = format_currency_amount(49.99, "USD", "$")
    assert res == "$49.99"

def test_jpy_formatting_no_decimals():
    res = format_currency_amount(7400.0, "JPY", "¥")
    assert res == "¥7,400"

def test_product_localization():
    item = {
        "id": "test_1",
        "name": "Test Product",
        "base_price_usd": 100.0,
        "original_price_usd": 150.0
    }
    localized = localize_product_pricing(item, "INR", 83.25, "₹")
    assert localized["currency"] == "INR"
    assert localized["display_price"] == 8325.0
    assert "₹" in localized["formatted_price"]
