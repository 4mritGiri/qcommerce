# priv/repo/seeds/main_seed.exs
# Seeds categories, products, slides, default users, settings.

alias Qcommerce.Repo
alias Qcommerce.Catalog.{Category, Product, Slide, FlashSale}
alias Qcommerce.Platform.Branch
alias Qcommerce.Inventory.BranchInventory

IO.puts("🌱 Seeding QCommerce database products and settings...")

# =============================================================================
# BRANCH
# =============================================================================

branch =
  case Repo.get_by(Branch, code: "KTM-THAMEL-01") do
    nil ->
      %Branch{}
      |> Branch.changeset(%{
        code: "KTM-THAMEL-01",
        name: "Thamel Dark Store",
        address_line: "Thamel Marg, Ward 26",
        city: "Kathmandu",
        catchment_radius_m: 3000,
        is_active: true
      })
      |> Repo.insert!()

    existing ->
      existing
  end

IO.puts("  ✓ Branch: #{branch.name}")

# =============================================================================
# CATEGORIES
# =============================================================================

cats_data = [
  %{name: "Vegetables", slug: "vegetables", sort_order: 0, emoji: "🥬"},
  %{name: "Fruits", slug: "fruits", sort_order: 1, emoji: "🍎"},
  %{name: "Dairy & Eggs", slug: "dairy-eggs", sort_order: 2, emoji: "🥛"},
  %{name: "Bakery", slug: "bakery", sort_order: 3, emoji: "🍞"},
  %{name: "Meat & Fish", slug: "meat-fish", sort_order: 4, emoji: "🥩"},
  %{name: "Beverages", slug: "beverages", sort_order: 5, emoji: "🧃"},
  %{name: "Snacks", slug: "snacks", sort_order: 6, emoji: "🍫"},
  %{name: "Beauty", slug: "beauty", sort_order: 7, emoji: "🧴"},
  %{name: "Cleaning", slug: "cleaning", sort_order: 8, emoji: "🧹"},
  %{name: "Baby", slug: "baby", sort_order: 9, emoji: "👶"},
  %{name: "Pet Care", slug: "pet-care", sort_order: 10, emoji: "🐾"},
  %{name: "Frozen", slug: "frozen", sort_order: 11, emoji: "❄️"},
  %{name: "Breakfast", slug: "breakfast", sort_order: 12, emoji: "🍳"},
  %{name: "Organic", slug: "organic", sort_order: 13, emoji: "🌿"},
  %{name: "Health", slug: "health", sort_order: 14, emoji: "💊"}
]

cats =
  Enum.map(cats_data, fn attrs ->
    cat =
      case Repo.get_by(Category, slug: attrs.slug) do
        nil ->
          %Category{}
          |> Category.changeset(Map.put(attrs, :is_active, true))
          |> Repo.insert!()

        existing ->
          existing
          |> Category.changeset(attrs)
          |> Repo.update!()
      end

    {attrs.slug, cat}
  end)
  |> Map.new()

IO.puts("  ✓ #{map_size(cats)} categories")

# =============================================================================
# PRODUCTS
# =============================================================================

prods_data = [
  # ── Popular / homepage grid ──
  {cats["dairy-eggs"], "DAI-MILK-500", "Farm Fresh Milk 500ml", "32", nil, "500ml", "🥛",
   "Full cream farm fresh milk"},
  {cats["bakery"], "BAK-BREAD-400", "Whole Wheat Bread 400g", "45", nil, "400g", "🍞",
   "Soft whole wheat sandwich bread"},
  {cats["dairy-eggs"], "DAI-EGGS-12", "Free Range Eggs 12pcs", "95", "110", "12pcs", "🥚",
   "Free range certified organic eggs"},
  {cats["fruits"], "FRT-BAN-6", "Bananas 6pcs Robusta", "39", nil, "6pcs", "🍌",
   "Sweet robusta bananas"},
  {cats["vegetables"], "VEG-TOM-250", "Cherry Tomatoes 250g", "79", "99", "250g", "🍅",
   "Juicy vine-ripened cherry tomatoes"},
  {cats["fruits"], "FRT-AVO-2", "Ripe Avocados 2pcs", "89", "120", "2pcs", "🥑",
   "Creamy ripe avocados"},
  {cats["vegetables"], "VEG-ONI-1K", "Red Onions 1kg", "29", nil, "1kg", "🧅", "Fresh red onions"},

  # ── Fresh produce ──
  {cats["vegetables"], "VEG-BRO-350", "Broccoli Fresh 350g", "69", "89", "350g", "🥦",
   "Fresh green broccoli, harvested daily"},
  {cats["organic"], "ORG-CAR-500", "Carrots Organic 500g", "45", nil, "500g", "🥕",
   "Sweet organic carrots"},
  {cats["vegetables"], "VEG-COR-2", "Sweet Corn 2pcs", "35", nil, "2pcs", "🌽",
   "Sweet golden corn"},
  {cats["vegetables"], "VEG-PEP-3", "Bell Peppers Mixed 3pcs", "89", "110", "3pcs", "🫑",
   "Red, yellow and green bell peppers"},
  {cats["fruits"], "FRT-LEM-6", "Lemon 6pcs", "29", nil, "6pcs", "🍋", "Fresh yellow lemons"},
  {cats["fruits"], "FRT-BLU-125", "Blueberries 125g", "149", "189", "125g", "🫐",
   "Antioxidant-rich blueberries"},
  {cats["fruits"], "FRT-GRP-500", "Black Grapes Seedless 500g", "99", nil, "500g", "🍇",
   "Sweet seedless black grapes"},

  # ── Dairy ──
  {cats["dairy-eggs"], "DAI-CHE-200", "Amul Cheddar Cheese 200g", "89", nil, "200g", "🧀",
   "Processed cheddar cheese slices"},
  {cats["dairy-eggs"], "DAI-YOG-400", "Amul Greek Yogurt 400g", "79", nil, "400g", "🍦",
   "Thick and creamy Greek yogurt"},
  {cats["dairy-eggs"], "DAI-BUT-500", "Amul Butter Unsalted 500g", "239", nil, "500g", "🧈",
   "Unsalted premium butter"},
  {cats["dairy-eggs"], "DAI-OAT-1L", "Oat Milk Unsweetened 1L", "139", nil, "1L", "🥛",
   "Plant-based oat milk"},
  {cats["dairy-eggs"], "DAI-PAN-200", "Paneer Fresh 200g", "69", nil, "200g", "🧆",
   "Fresh homemade-style paneer"},
  {cats["dairy-eggs"], "DAI-DOI-400", "Mishti Doi 400g", "89", nil, "400g", "🫙",
   "Bengali sweet yogurt"},
  {cats["dairy-eggs"], "DAI-QEG-20", "Quail Eggs 20pcs", "89", "109", "20pcs", "🥚",
   "Nutritious quail eggs"},

  # ── Slide 0 — Fruits ──
  {cats["fruits"], "FRT-AVO3-P3", "Organic Avocado Pack of 3", "89", "120", "Pack of 3", "🥑",
   "Organic ripe avocados"},
  {cats["fruits"], "FRT-BLU2-125", "Fresh Blueberries 125g", "149", nil, "125g", "🫐",
   "Fresh blueberries"},
  {cats["fruits"], "FRT-KIW-4", "Kiwi Fruit 4pcs", "79", "99", "4pcs", "🥝",
   "Vitamin C rich kiwis"},
  {cats["fruits"], "FRT-STR-250", "Strawberries 250g", "119", nil, "250g", "🍓",
   "Fresh strawberries"},
  {cats["fruits"], "FRT-MAN-500", "Alphonso Mango 500g", "189", nil, "500g", "🥭",
   "Premium Alphonso mangoes"},

  # ── Slide 1 — Dairy ──
  {cats["dairy-eggs"], "DAI-MLK2-500", "Farm Fresh Full Cream Milk 500ml", "32", nil, "500ml",
   "🥛", "Farm fresh milk"},
  {cats["dairy-eggs"], "DAI-PCH-200", "Amul Processed Cheese 200g", "89", nil, "200g", "🧀",
   "Processed cheese"},
  {cats["dairy-eggs"], "DAI-EGT-12", "Free Range Eggs Tray of 12", "95", "110", "12pcs", "🥚",
   "Free range eggs"},
  {cats["dairy-eggs"], "DAI-BUT2-100", "Amul Butter 100g", "55", nil, "100g", "🧈", "Amul butter"},
  {cats["dairy-eggs"], "DAI-GYO-400", "Greek Yogurt 400g", "79", nil, "400g", "🍦",
   "Greek yogurt"},

  # ── Slide 2 — Snacks ──
  {cats["snacks"], "SNK-DMS-160", "Dairy Milk Silk 160g", "139", nil, "160g", "🍫",
   "Smooth milk chocolate"},
  {cats["snacks"], "SNK-POP-30", "Act II Popcorn Butter 30g", "25", nil, "30g", "🍿",
   "Butter popcorn"},
  {cats["snacks"], "SNK-PRG-107", "Pringles Original 107g", "179", "199", "107g", "🥨",
   "Stacked potato chips"},
  {cats["beverages"], "BEV-MNG-1L", "Real Fruit Mango 1L", "75", "90", "1L", "🧃",
   "Real fruit mango juice"},
  {cats["snacks"], "SNK-HAR-200", "Haribo Goldbears 200g", "149", nil, "200g", "🍬",
   "Gummy bears"},

  # ── Slide 3 — Meat ──
  {cats["meat-fish"], "MEA-CHK-500", "Chicken Breast 500g boneless", "259", nil, "500g", "🍗",
   "Fresh boneless chicken breast"},
  {cats["meat-fish"], "MEA-MUT-250", "Mutton Boneless 250g", "349", nil, "250g", "🥩",
   "Fresh boneless mutton"},
  {cats["meat-fish"], "MEA-SAL-200", "Salmon Fillet 200g", "449", nil, "200g", "🐟",
   "Atlantic salmon fillet"},
  {cats["meat-fish"], "MEA-PRW-250", "Tiger Prawns 250g cleaned", "299", nil, "250g", "🦐",
   "Cleaned tiger prawns"},
  {cats["meat-fish"], "MEA-QEG-20", "Quail Eggs pack of 20", "89", nil, "20pcs", "🥚",
   "Nutritious quail eggs"},

  # ── Slide 4 — Home essentials ──
  {cats["beauty"], "BEA-DET-500", "Dettol Hand Sanitizer 500ml", "185", nil, "500ml", "🧴",
   "Antibacterial hand sanitizer"},
  {cats["cleaning"], "CLN-SCB-3", "Scotch Brite Scrub Pad 3pcs", "49", nil, "3pcs", "🧹",
   "Heavy duty scrub pads"},
  {cats["beauty"], "BEA-COL-150", "Colgate MaxFresh 150g", "79", "95", "150g", "🪥",
   "Cooling fresh toothpaste"},
  {cats["beauty"], "BEA-DOV-100", "Dove Beauty Bar 100g", "55", nil, "100g", "🧼",
   "Moisturizing beauty bar"},
  {cats["beauty"], "BEA-GIL-1", "Gillette Fusion 5 Razor", "299", nil, "1pc", "🪒",
   "5-blade razor"}
]

prods =
  Enum.map(prods_data, fn {category, sku, name, price, old_price, unit, emoji, desc} ->
    attrs = %{
      category_id: category.id,
      sku: sku,
      name: name,
      base_price: Decimal.new(price),
      old_price: if(old_price, do: Decimal.new(old_price), else: nil),
      unit: unit,
      emoji: emoji,
      description: desc,
      is_active: true
    }

    product =
      case Repo.get_by(Product, sku: sku) do
        nil ->
          %Product{} |> Product.changeset(attrs) |> Repo.insert!()

        existing ->
          existing |> Product.changeset(attrs) |> Repo.update!()
      end

    # Branch inventory
    case Repo.get_by(BranchInventory, branch_id: branch.id, product_id: product.id) do
      nil ->
        %BranchInventory{}
        |> BranchInventory.changeset(%{
          branch_id: branch.id,
          product_id: product.id,
          selling_price: Decimal.new(price),
          quantity_on_hand: :rand.uniform(80) + 20,
          reorder_threshold: 10,
          is_available: true
        })
        |> Repo.insert!()

      _ ->
        :ok
    end

    {sku, product}
  end)
  |> Map.new()

IO.puts("  ✓ #{map_size(prods)} products with branch inventory")

# =============================================================================
# SLIDES
# =============================================================================

slides_data = [
  %{
    theme: "slide-green",
    tag: "⚡ 10 Min Delivery",
    heading: "Freshness at <em>lightning speed</em>",
    sub: "5,000+ products · zero waiting",
    cta_label: "Shop now",
    emojis: ["🛒", "🥦", "🍎"],
    position: 0,
    skus: ["FRT-AVO3-P3", "FRT-BLU2-125", "FRT-KIW-4", "FRT-STR-250", "FRT-MAN-500"]
  },
  %{
    theme: "slide-blue",
    tag: "🥛 Dairy Fresh",
    heading: "Farm fresh <em>dairy</em> every morning",
    sub: "Delivered cold · certified organic",
    cta_label: "Explore dairy",
    emojis: ["🥛", "🧀", "🥚"],
    position: 1,
    skus: ["DAI-MLK2-500", "DAI-PCH-200", "DAI-EGT-12", "DAI-BUT2-100", "DAI-GYO-400"]
  },
  %{
    theme: "slide-amber",
    tag: "🍫 Snacks & Munchies",
    heading: "Late night <em>cravings</em> sorted",
    sub: "Chocolates, chips & more",
    cta_label: "Shop snacks",
    emojis: ["🍫", "🍿", "🧃"],
    position: 2,
    skus: ["SNK-DMS-160", "SNK-POP-30", "SNK-PRG-107", "BEV-MNG-1L", "SNK-HAR-200"]
  },
  %{
    theme: "slide-red",
    tag: "🥩 Meat & Seafood",
    heading: "Premium <em>proteins</em> delivered fresh",
    sub: "Sourced daily · hygiene certified",
    cta_label: "Shop meat",
    emojis: ["🥩", "🐟", "🍗"],
    position: 3,
    skus: ["MEA-CHK-500", "MEA-MUT-250", "MEA-SAL-200", "MEA-PRW-250", "MEA-QEG-20"]
  },
  %{
    theme: "slide-purple",
    tag: "🧹 Home Essentials",
    heading: "Clean home, <em>happy life</em>",
    sub: "Cleaning, personal care & baby products",
    cta_label: "Explore now",
    emojis: ["🧴", "🧹", "🪥"],
    position: 4,
    skus: ["BEA-DET-500", "CLN-SCB-3", "BEA-COL-150", "BEA-DOV-100", "BEA-GIL-1"]
  }
]

Enum.each(slides_data, fn data ->
  unless Repo.get_by(Slide, position: data.position) do
    slide_products = Enum.map(data.skus, fn sku -> prods[sku] end) |> Enum.reject(&is_nil/1)
    {skus, slide_attrs} = Map.pop(data, :skus)

    %Slide{}
    |> Slide.changeset(slide_attrs)
    |> Ecto.Changeset.put_assoc(:products, slide_products)
    |> Repo.insert!()
  end
end)

IO.puts("  ✓ #{length(slides_data)} carousel slides")

# =============================================================================
# FLASH SALE
# =============================================================================

unless Repo.get_by(FlashSale, label: "Flash Sale — Snacks & Drinks") do
  ends_at = DateTime.utc_now() |> DateTime.add(2 * 3600, :second)

  %FlashSale{}
  |> FlashSale.changeset(%{
    label: "Flash Sale — Snacks & Drinks",
    ends_at: ends_at,
    discount_pct: 30,
    is_active: true
  })
  |> Repo.insert!()
end

IO.puts("  ✓ Flash sale active (2 hours)")

# =============================================================================
# DEFAULT USERS
# =============================================================================

alias Qcommerce.Accounts
alias Qcommerce.Accounts.User
alias Qcommerce.Accounts.UserPasskey

user =
  case Repo.get_by(User, email: "customer@qcommerce.com") do
    nil ->
      {:ok, user} = Accounts.create_user(%{
        email: "customer@qcommerce.com",
        phone: "+9779876543210",
        full_name: "Amrit Giri",
        password: "password123",
        role: :customer
      })
      user

    existing ->
      existing
  end

IO.puts("  ✓ Default User: #{user.full_name} (#{user.email})")

unless Repo.get_by(UserPasskey, user_id: user.id) do
  ext_id = Base.url_encode64("demo_passkey_id", padding: false)
  pub_key = Base.url_encode64("demo_public_key_data", padding: false)
  Qcommerce.Accounts.PasskeyAuth.register_passkey(user, ext_id, pub_key, "Amrit's iPhone")
  IO.puts("  ✓ Seeded default Passkey for Amrit")
end

# =============================================================================
# SYSTEM SETTINGS
# =============================================================================

Qcommerce.Settings.seed_defaults()
IO.puts("  ✓ System settings seeded (auth: email=on, phone/qr/passkey=off)")

# =============================================================================
# ADMIN USER
# =============================================================================

alias Qcommerce.Accounts.User, as: UserSchema

admin =
  case Repo.get_by(UserSchema, email: "admin@qcommerce.com") do
    nil ->
      {:ok, a} = Qcommerce.Accounts.create_user(%{
        email: "admin@qcommerce.com",
        phone: "+9779800000000",
        full_name: "QCommerce Admin",
        password: "admin123456",
        role: :super_admin
      })
      a

    existing ->
      existing
  end

IO.puts("  ✓ Admin User: #{admin.email} (role: #{admin.role})")
IO.puts("🎉 Main seed complete!")
