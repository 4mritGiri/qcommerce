alias Qcommerce.Repo
alias Qcommerce.Store.{Category, Product, Slide, FlashSale}

# ── Categories ────────────────────────────────────────────────────────────
categories_data = [
  %{name: "Vegetables",  emoji: "🥬", slug: "vegetables",  position: 0},
  %{name: "Fruits",      emoji: "🍎", slug: "fruits",       position: 1},
  %{name: "Dairy",       emoji: "🥛", slug: "dairy",        position: 2},
  %{name: "Bakery",      emoji: "🍞", slug: "bakery",       position: 3},
  %{name: "Meat",        emoji: "🥩", slug: "meat",         position: 4},
  %{name: "Beverages",   emoji: "🧃", slug: "beverages",    position: 5},
  %{name: "Snacks",      emoji: "🍫", slug: "snacks",       position: 6},
  %{name: "Beauty",      emoji: "🧴", slug: "beauty",       position: 7},
  %{name: "Cleaning",    emoji: "🧹", slug: "cleaning",     position: 8},
  %{name: "Baby",        emoji: "👶", slug: "baby",         position: 9},
  %{name: "Pet Care",    emoji: "🐾", slug: "pet-care",     position: 10},
  %{name: "Frozen",      emoji: "❄️",  slug: "frozen",       position: 11},
  %{name: "Breakfast",   emoji: "🍳", slug: "breakfast",    position: 12},
  %{name: "Organic",     emoji: "🌿", slug: "organic",      position: 13},
  %{name: "Health",      emoji: "💊", slug: "health",       position: 14},
]

categories =
  Enum.map(categories_data, fn attrs ->
    %Category{}
    |> Category.changeset(attrs)
    |> Repo.insert!(on_conflict: :nothing, conflict_target: :slug)
  end)

cat = Enum.into(categories, %{}, &{&1.slug, &1.id})

# ── Products ──────────────────────────────────────────────────────────────
products_data = [
  # Popular section
  %{name: "Farm Fresh Milk 500ml",     emoji: "🥛", price_paise: 32,  section: "popular", badge: "NEW",     weight: "500ml",  category_id: cat["dairy"]},
  %{name: "Whole Wheat Bread 400g",    emoji: "🍞", price_paise: 45,  section: "popular", badge: "POPULAR", weight: "400g",   category_id: cat["bakery"]},
  %{name: "Free Range Eggs 12pcs",     emoji: "🥚", price_paise: 95,  old_price_paise: 110, section: "popular", badge: "SALE", weight: "12pcs", category_id: cat["dairy"]},
  %{name: "Bananas 6pcs Robusta",      emoji: "🍌", price_paise: 39,  section: "popular", weight: "6pcs",   category_id: cat["fruits"]},
  %{name: "Cherry Tomatoes 250g",      emoji: "🍅", price_paise: 79,  section: "popular", badge: "HOT",     weight: "250g",  category_id: cat["vegetables"]},
  %{name: "Ripe Avocados 2pcs",        emoji: "🥑", price_paise: 89,  old_price_paise: 120, section: "popular", badge: "NEW", weight: "2pcs",  category_id: cat["fruits"]},
  %{name: "Red Onions 1kg",            emoji: "🧅", price_paise: 29,  section: "popular", weight: "1kg",    category_id: cat["vegetables"]},

  # Fresh section
  %{name: "Broccoli Fresh 350g",       emoji: "🥦", price_paise: 69,  section: "fresh",   badge: "NEW",   weight: "350g", category_id: cat["vegetables"]},
  %{name: "Carrots Organic 500g",      emoji: "🥕", price_paise: 45,  section: "fresh",   weight: "500g", category_id: cat["organic"]},
  %{name: "Sweet Corn 2pcs",           emoji: "🌽", price_paise: 35,  section: "fresh",   badge: "HOT",   weight: "2pcs", category_id: cat["vegetables"]},
  %{name: "Bell Peppers Mixed 3pcs",   emoji: "🫑", price_paise: 89,  old_price_paise: 110, section: "fresh", weight: "3pcs", category_id: cat["vegetables"]},
  %{name: "Lemon 6pcs",                emoji: "🍋", price_paise: 29,  section: "fresh",   weight: "6pcs", category_id: cat["fruits"]},
  %{name: "Blueberries 125g",          emoji: "🫐", price_paise: 149, old_price_paise: 189, section: "fresh", badge: "SALE", weight: "125g", category_id: cat["fruits"]},
  %{name: "Black Grapes Seedless 500g",emoji: "🍇", price_paise: 99,  section: "fresh",   weight: "500g", category_id: cat["fruits"]},

  # Dairy section
  %{name: "Amul Cheddar Cheese 200g",  emoji: "🧀", price_paise: 89,  section: "dairy",   badge: "POPULAR", weight: "200g", category_id: cat["dairy"]},
  %{name: "Amul Greek Yogurt 400g",    emoji: "🍦", price_paise: 79,  section: "dairy",   weight: "400g", category_id: cat["dairy"]},
  %{name: "Amul Butter Unsalted 500g", emoji: "🧈", price_paise: 239, section: "dairy",   weight: "500g", category_id: cat["dairy"]},
  %{name: "Oat Milk Unsweetened 1L",   emoji: "🥛", price_paise: 139, section: "dairy",   badge: "NEW",   weight: "1L",   category_id: cat["dairy"]},
  %{name: "Paneer Fresh 200g",         emoji: "🧆", price_paise: 69,  section: "dairy",   badge: "HOT",   weight: "200g", category_id: cat["dairy"]},
  %{name: "Mishti Doi 400g",           emoji: "🫙", price_paise: 89,  section: "dairy",   weight: "400g", category_id: cat["dairy"]},
  %{name: "Quail Eggs 20pcs",          emoji: "🥚", price_paise: 89,  old_price_paise: 109, section: "dairy", badge: "SALE", weight: "20pcs", category_id: cat["dairy"]},

  # Slide-specific products (no section — only shown in carousel)
  %{name: "Organic Avocado Pack of 3", emoji: "🥑", price_paise: 89, old_price_paise: 120, badge: "NEW",   weight: "Pack of 3", category_id: cat["fruits"]},
  %{name: "Fresh Blueberries 125g",    emoji: "🫐", price_paise: 149, badge: "FRESH", weight: "125g", category_id: cat["fruits"]},
  %{name: "Kiwi Fruit 4pcs",           emoji: "🥝", price_paise: 79,  old_price_paise: 99, badge: "SALE", weight: "4pcs", category_id: cat["fruits"]},
  %{name: "Strawberries 250g",         emoji: "🍓", price_paise: 119, weight: "250g", category_id: cat["fruits"]},
  %{name: "Alphonso Mango 500g",       emoji: "🥭", price_paise: 189, badge: "HOT",   weight: "500g", category_id: cat["fruits"]},
  %{name: "Farm Fresh Full Cream Milk 500ml", emoji: "🥛", price_paise: 32, weight: "500ml", category_id: cat["dairy"]},
  %{name: "Amul Processed Cheese 200g",emoji: "🧀", price_paise: 89, weight: "200g", category_id: cat["dairy"]},
  %{name: "Free Range Eggs Tray of 12",emoji: "🥚", price_paise: 95, old_price_paise: 110, badge: "SALE", weight: "12pcs", category_id: cat["dairy"]},
  %{name: "Amul Butter 100g",          emoji: "🧈", price_paise: 55, weight: "100g", category_id: cat["dairy"]},
  %{name: "Greek Yogurt 400g",         emoji: "🍦", price_paise: 79, badge: "NEW",  weight: "400g", category_id: cat["dairy"]},
  %{name: "Dairy Milk Silk 160g",      emoji: "🍫", price_paise: 139, weight: "160g", category_id: cat["snacks"]},
  %{name: "Act II Popcorn Butter 30g", emoji: "🍿", price_paise: 25, badge: "HOT",  weight: "30g",  category_id: cat["snacks"]},
  %{name: "Pringles Original 107g",    emoji: "🥨", price_paise: 179, weight: "107g", category_id: cat["snacks"]},
  %{name: "Real Fruit Mango 1L",       emoji: "🧃", price_paise: 75, old_price_paise: 90, badge: "SALE", weight: "1L", category_id: cat["beverages"]},
  %{name: "Haribo Goldbears 200g",     emoji: "🍬", price_paise: 149, badge: "NEW", weight: "200g", category_id: cat["snacks"]},
  %{name: "Chicken Breast 500g boneless", emoji: "🍗", price_paise: 259, badge: "FRESH", weight: "500g", category_id: cat["meat"]},
  %{name: "Mutton Boneless 250g",      emoji: "🥩", price_paise: 349, weight: "250g", category_id: cat["meat"]},
  %{name: "Salmon Fillet 200g",        emoji: "🐟", price_paise: 449, badge: "HOT", weight: "200g", category_id: cat["meat"]},
  %{name: "Tiger Prawns 250g cleaned", emoji: "🦐", price_paise: 299, weight: "250g", category_id: cat["meat"]},
  %{name: "Quail Eggs pack of 20",     emoji: "🥚", price_paise: 89, badge: "NEW", weight: "20pcs", category_id: cat["meat"]},
  %{name: "Dettol Hand Sanitizer 500ml",emoji: "🧴", price_paise: 185, weight: "500ml", category_id: cat["beauty"]},
  %{name: "Scotch Brite Scrub Pad 3pcs",emoji: "🧹", price_paise: 49, badge: "HOT", weight: "3pcs", category_id: cat["cleaning"]},
  %{name: "Colgate MaxFresh 150g",     emoji: "🪥", price_paise: 79, old_price_paise: 95, badge: "SALE", weight: "150g", category_id: cat["beauty"]},
  %{name: "Dove Beauty Bar 100g",      emoji: "🧼", price_paise: 55, weight: "100g", category_id: cat["beauty"]},
  %{name: "Gillette Fusion 5 Razor",   emoji: "🪒", price_paise: 299, badge: "NEW", weight: "1pc", category_id: cat["beauty"]},
]

products =
  Enum.map(products_data, fn attrs ->
    %Product{}
    |> Product.changeset(attrs)
    |> Repo.insert!()
  end)

by_name = Enum.into(products, %{}, &{&1.name, &1})

# ── Slides ────────────────────────────────────────────────────────────────
slides_data = [
  %{
    theme: "slide-0", tag: "⚡ 10 Min Delivery",
    heading: "Freshness at <em>lightning speed</em>",
    sub: "5,000+ products · zero waiting", cta_label: "Shop now",
    emojis: ["🛒", "🥦", "🍎"], position: 0,
    product_names: ["Organic Avocado Pack of 3","Fresh Blueberries 125g","Kiwi Fruit 4pcs","Strawberries 250g","Alphonso Mango 500g"]
  },
  %{
    theme: "slide-1", tag: "🥛 Dairy Fresh",
    heading: "Farm fresh <em>dairy</em> every morning",
    sub: "Delivered cold · certified organic", cta_label: "Explore dairy",
    emojis: ["🥛", "🧀", "🥚"], position: 1,
    product_names: ["Farm Fresh Full Cream Milk 500ml","Amul Processed Cheese 200g","Free Range Eggs Tray of 12","Amul Butter 100g","Greek Yogurt 400g"]
  },
  %{
    theme: "slide-2", tag: "🍫 Snacks & Munchies",
    heading: "Late night <em>cravings</em> sorted",
    sub: "Chocolates, chips & more · 1000+ options", cta_label: "Shop snacks",
    emojis: ["🍫", "🍿", "🧃"], position: 2,
    product_names: ["Dairy Milk Silk 160g","Act II Popcorn Butter 30g","Pringles Original 107g","Real Fruit Mango 1L","Haribo Goldbears 200g"]
  },
  %{
    theme: "slide-3", tag: "🥩 Meat & Seafood",
    heading: "Premium <em>proteins</em> delivered fresh",
    sub: "Sourced daily · hygiene certified", cta_label: "Shop meat",
    emojis: ["🥩", "🐟", "🍗"], position: 3,
    product_names: ["Chicken Breast 500g boneless","Mutton Boneless 250g","Salmon Fillet 200g","Tiger Prawns 250g cleaned","Quail Eggs pack of 20"]
  },
  %{
    theme: "slide-4", tag: "🧹 Home Essentials",
    heading: "Clean home, <em>happy life</em>",
    sub: "Cleaning, personal care & baby products", cta_label: "Explore now",
    emojis: ["🧴", "🧹", "🪥"], position: 4,
    product_names: ["Dettol Hand Sanitizer 500ml","Scotch Brite Scrub Pad 3pcs","Colgate MaxFresh 150g","Dove Beauty Bar 100g","Gillette Fusion 5 Razor"]
  },
]

Enum.each(slides_data, fn attrs ->
  {product_names, slide_attrs} = Map.pop(attrs, :product_names)
  slide = %Slide{} |> Slide.changeset(slide_attrs) |> Repo.insert!()

  product_ids = Enum.map(product_names, &by_name[&1].id)
  Enum.each(Enum.with_index(product_ids), fn {pid, pos} ->
    Repo.insert_all("slide_products", [%{slide_id: slide.id, product_id: pid, position: pos}])
  end)
end)

# ── Flash Sale ────────────────────────────────────────────────────────────
%FlashSale{}
|> FlashSale.changeset(%{
  label: "Flash Sale — Snacks & Drinks",
  ends_at: DateTime.utc_now() |> DateTime.add(2 * 3600 + 14 * 60, :second) |> DateTime.truncate(:second),
  discount_pct: 30,
  active: true
})
|> Repo.insert!()

IO.puts("✅  Seeds complete.")
