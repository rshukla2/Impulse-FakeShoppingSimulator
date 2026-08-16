"""Shared conversion from cached ORM products to public API payloads."""


def product_payload(product):
    return {
        "id": product.id, "type": product.type, "name": product.name, "brand": product.brand,
        "category": product.category, "cuisine": product.cuisine, "description": product.description,
        "image_url": product.image_url, "source": product.source, "source_id": product.source_id,
        "restaurant_id": product.restaurant_id, "base_price_usd": product.base_price_usd,
        "original_price_usd": product.original_price_usd, "rating": product.rating,
        "review_count": product.review_count, "is_fictional": product.is_fictional,
        "image_license": product.image_license, "image_attribution": product.image_attribution,
        "image_license_url": product.image_license_url, "source_url": product.source_url,
        "image_source_url": product.image_source_url,
    }
