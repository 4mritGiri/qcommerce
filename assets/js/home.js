const SLIDES = [
   {
      theme: "slide-0",
      tag: "⚡ 10 Min Delivery",
      h2: "Freshness at <em>lightning speed</em>",
      p: "5,000+ products · zero waiting",
      cta: "Shop now",
      emoji: ["🛒", "🥦", "🍎"],
      products: [
         {
            e: "🥑",
            name: "Organic Avocado Pack of 3",
            time: "10 mins",
            price: "Rs. 89",
            old: "Rs. 120",
            badge: "NEW",
            w: "Pack of 3",
         },
         { e: "🫐", name: "Fresh Blueberries 125g", time: "10 mins", price: "Rs. 149", badge: "FRESH", w: "125g" },
         {
            e: "🥝",
            name: "Kiwi Fruit 4pcs",
            time: "10 mins",
            price: "Rs. 79",
            old: "Rs. 99",
            badge: "SALE",
            w: "4pcs",
         },
         { e: "🍓", name: "Strawberries 250g", time: "10 mins", price: "Rs. 119", w: "250g" },
         { e: "🥭", name: "Alphonso Mango 500g", time: "10 mins", price: "Rs. 189", badge: "HOT", w: "500g" },
      ],
   },
   {
      theme: "slide-1",
      tag: "🥛 Dairy Fresh",
      h2: "Farm fresh <em>dairy</em> every morning",
      p: "Delivered cold · certified organic",
      cta: "Explore dairy",
      emoji: ["🥛", "🧀", "🥚"],
      products: [
         { e: "🥛", name: "Farm Fresh Full Cream Milk 500ml", time: "10 mins", price: "Rs. 32", w: "500ml" },
         { e: "🧀", name: "Amul Processed Cheese 200g", time: "10 mins", price: "Rs. 89", w: "200g" },
         {
            e: "🥚",
            name: "Free Range Eggs Tray of 12",
            time: "10 mins",
            price: "Rs. 95",
            old: "Rs. 110",
            badge: "SALE",
            w: "12pcs",
         },
         { e: "🧈", name: "Amul Butter 100g", time: "10 mins", price: "Rs. 55", w: "100g" },
         { e: "🍦", name: "Greek Yogurt 400g", time: "10 mins", price: "Rs. 79", badge: "NEW", w: "400g" },
      ],
   },
   {
      theme: "slide-2",
      tag: "🍫 Snacks & Munchies",
      h2: "Late night <em>cravings</em> sorted",
      p: "Chocolates, chips & more · 1000+ options",
      cta: "Shop snacks",
      emoji: ["🍫", "🍿", "🧃"],
      products: [
         { e: "🍫", name: "Dairy Milk Silk 160g", time: "10 mins", price: "Rs. 139", w: "160g" },
         { e: "🍿", name: "Act II Popcorn Butter 30g", time: "10 mins", price: "Rs. 25", badge: "HOT", w: "30g" },
         { e: "🥨", name: "Pringles Original 107g", time: "10 mins", price: "Rs. 179", w: "107g" },
         {
            e: "🧃",
            name: "Real Fruit Mango 1L",
            time: "10 mins",
            price: "Rs. 75",
            old: "Rs. 90",
            badge: "SALE",
            w: "1L",
         },
         { e: "🍬", name: "Haribo Goldbears 200g", time: "10 mins", price: "Rs. 149", badge: "NEW", w: "200g" },
      ],
   },
   {
      theme: "slide-3",
      tag: "🥩 Meat & Seafood",
      h2: "Premium <em>proteins</em> delivered fresh",
      p: "Sourced daily · hygiene certified",
      cta: "Shop meat",
      emoji: ["🥩", "🐟", "🍗"],
      products: [
         {
            e: "🍗",
            name: "Chicken Breast 500g boneless",
            time: "10 mins",
            price: "Rs. 259",
            badge: "FRESH",
            w: "500g",
         },
         { e: "🥩", name: "Mutton Boneless 250g", time: "10 mins", price: "Rs. 349", w: "250g" },
         { e: "🐟", name: "Salmon Fillet 200g", time: "10 mins", price: "Rs. 449", badge: "HOT", w: "200g" },
         { e: "🦐", name: "Tiger Prawns 250g cleaned", time: "10 mins", price: "Rs. 299", w: "250g" },
         { e: "🥚", name: "Quail Eggs pack of 20", time: "10 mins", price: "Rs. 89", badge: "NEW", w: "20pcs" },
      ],
   },
   {
      theme: "slide-4",
      tag: "🧹 Home Essentials",
      h2: "Clean home, <em>happy life</em>",
      p: "Cleaning, personal care & baby products",
      cta: "Explore now",
      emoji: ["🧴", "🧹", "🪥"],
      products: [
         { e: "🧴", name: "Dettol Hand Sanitizer 500ml", time: "10 mins", price: "Rs. 185", w: "500ml" },
         { e: "🧹", name: "Scotch Brite Scrub Pad 3pcs", time: "10 mins", price: "Rs. 49", badge: "HOT", w: "3pcs" },
         {
            e: "🪥",
            name: "Colgate MaxFresh Toothpaste 150g",
            time: "10 mins",
            price: "Rs. 79",
            old: "Rs. 95",
            badge: "SALE",
            w: "150g",
         },
         { e: "🧼", name: "Dove Beauty Bar Soap 100g", time: "10 mins", price: "Rs. 55", w: "100g" },
         { e: "🪒", name: "Gillette Fusion 5 Razor 1pc", time: "10 mins", price: "Rs. 299", badge: "NEW", w: "1pc" },
      ],
   },
];

const CATEGORIES = [
   { e: "🥬", name: "Vegetables" },
   { e: "🍎", name: "Fruits" },
   { e: "🥛", name: "Dairy" },
   { e: "🍞", name: "Bakery" },
   { e: "🥩", name: "Meat" },
   { e: "🧃", name: "Beverages" },
   { e: "🍫", name: "Snacks" },
   { e: "🧴", name: "Beauty" },
   { e: "🧹", name: "Cleaning" },
   { e: "👶", name: "Baby" },
   { e: "🐾", name: "Pet Care" },
   { e: "❄️", name: "Frozen" },
   { e: "🍳", name: "Breakfast" },
   { e: "🌿", name: "Organic" },
   { e: "💊", name: "Health" },
];

const POPULAR = [
   {
      e: "🥛",
      name: "Farm Fresh Milk 500ml",
      badge: "badge-new",
      b: "NEW",
      price: "Rs. 32",
      time: "10 mins",
      w: "500ml",
   },
   {
      e: "🍞",
      name: "Whole Wheat Bread 400g",
      badge: "badge-popular",
      b: "POPULAR",
      price: "Rs. 45",
      time: "10 mins",
      w: "400g",
   },
   {
      e: "🥚",
      name: "Free Range Eggs 12pcs",
      badge: "badge-sale",
      b: "SALE",
      price: "Rs. 95",
      old: "Rs. 110",
      time: "10 mins",
      w: "12pcs",
   },
   { e: "🍌", name: "Bananas 6pcs Robusta", price: "Rs. 39", time: "10 mins", w: "6pcs" },
   { e: "🍅", name: "Cherry Tomatoes 250g", badge: "badge-hot", b: "HOT", price: "Rs. 79", time: "10 mins", w: "250g" },
   {
      e: "🥑",
      name: "Ripe Avocados 2pcs",
      badge: "badge-new",
      b: "NEW",
      price: "Rs. 89",
      old: "Rs. 120",
      time: "10 mins",
      w: "2pcs",
   },
   { e: "🧅", name: "Red Onions 1kg", price: "Rs. 29", time: "10 mins", w: "1kg" },
];

const FRESH = [
   { e: "🥦", name: "Broccoli Fresh 350g", badge: "badge-new", b: "NEW", price: "Rs. 69", time: "10 mins", w: "350g" },
   { e: "🥕", name: "Carrots Organic 500g", price: "Rs. 45", time: "10 mins", w: "500g" },
   { e: "🌽", name: "Sweet Corn 2pcs", badge: "badge-hot", b: "HOT", price: "Rs. 35", time: "10 mins", w: "2pcs" },
   { e: "🫑", name: "Bell Peppers Mixed 3pcs", price: "Rs. 89", old: "Rs. 110", time: "10 mins", w: "3pcs" },
   { e: "🍋", name: "Lemon 6pcs", price: "Rs. 29", time: "10 mins", w: "6pcs" },
   {
      e: "🫐",
      name: "Blueberries 125g",
      badge: "badge-sale",
      b: "SALE",
      price: "Rs. 149",
      old: "Rs. 189",
      time: "10 mins",
      w: "125g",
   },
   { e: "🍇", name: "Black Grapes Seedless 500g", price: "Rs. 99", time: "10 mins", w: "500g" },
];

const DAIRY = [
   {
      e: "🧀",
      name: "Amul Cheddar Cheese 200g",
      badge: "badge-popular",
      b: "POPULAR",
      price: "Rs. 89",
      time: "10 mins",
      w: "200g",
   },
   { e: "🍦", name: "Amul Greek Yogurt 400g", price: "Rs. 79", time: "10 mins", w: "400g" },
   { e: "🧈", name: "Amul Butter Unsalted 500g", price: "Rs. 239", time: "10 mins", w: "500g" },
   {
      e: "🥛",
      name: "Oat Milk Unsweetened 1L",
      badge: "badge-new",
      b: "NEW",
      price: "Rs. 139",
      time: "10 mins",
      w: "1L",
   },
   { e: "🧆", name: "Paneer Fresh 200g", badge: "badge-hot", b: "HOT", price: "Rs. 69", time: "10 mins", w: "200g" },
   { e: "🫙", name: "Mishti Doi 400g", price: "Rs. 89", time: "10 mins", w: "400g" },
   {
      e: "🥚",
      name: "Quail Eggs 20pcs",
      badge: "badge-sale",
      b: "SALE",
      price: "Rs. 89",
      old: "Rs. 109",
      time: "10 mins",
      w: "20pcs",
   },
];

// State
let currentSlide = 0;
let cartItems = 0;
let cartTotal = 0;
let autoTimer;

// Build carousel
function buildCarousel() {
   const track = document.getElementById("track");
   const dots = document.getElementById("dots");
   track.innerHTML = "";
   dots.innerHTML = "";
   SLIDES.forEach((s, i) => {
      // products HTML
      let prods = s.products
         .map(
            (p) => `
         <div class="prod-chip" onclick="addToCart(event,this,'${p.name}','${p.price}')">
         <div class="prod-chip-img">
            ${p.badge ? `<div class="prod-chip-badge${p.badge === "SALE" ? " sale" : ""}">${p.badge}</div>` : ""}
            ${p.e}
            <button class="prod-chip-add">+</button>
         </div>
         <h4>${p.name}</h4>
         <div class="prod-chip-meta">
            <div class="prod-chip-time">⚡ ${p.time}</div>
            <div class="prod-chip-price">${p.price}</div>
         </div>
         </div>
      `,
         )
         .join("");
      prods += `<div class="prod-chip-see-more"><span>→</span><span>See More</span></div>`;

      track.innerHTML += `
         <div class="carousel-slide">
         <div class="slide-banner ${s.theme}">
            <div class="slide-banner-content">
               <div class="slide-banner-tag"><span class="slide-banner-tag-dot"></span>${s.tag}</div>
               <h2>${s.h2}</h2>
               <p>${s.p}</p>
               <button class="slide-banner-cta">${s.cta} →</button>
            </div>
            <div class="slide-banner-visual">${s.emoji.map((e) => `<span style="font-size:clamp(32px,6vw,72px);filter:drop-shadow(0 8px 16px rgba(0,0,0,0.3))">${e}</span>`).join("")}</div>
         </div>
         <div class="slide-products">${prods}</div>
         </div>`;

      const dot = document.createElement("div");
      dot.className = "dot" + (i === 0 ? " active" : "");
      dot.onclick = () => goTo(i);
      dots.appendChild(dot);
   });
}

function updateCarousel() {
   document.getElementById("track").style.transform = `translateX(-${currentSlide * 100}%)`;
   document.querySelectorAll(".dot").forEach((d, i) => d.classList.toggle("active", i === currentSlide));
}
function goTo(n) {
   currentSlide = (n + SLIDES.length) % SLIDES.length;
   updateCarousel();
   resetTimer();
}
function nextSlide() {
   goTo(currentSlide + 1);
}
function prevSlide() {
   goTo(currentSlide - 1);
}
function resetTimer() {
   clearInterval(autoTimer);
   autoTimer = setInterval(nextSlide, 4500);
}

// Build categories
function buildCategories() {
   const row = document.getElementById("catsRow");
   CATEGORIES.forEach((c) => {
      row.innerHTML += `<div class="cat-item" onclick="showToast('Browsing ${c.name}')">
         <div class="cat-icon">${c.e}</div>
         <div class="cat-name">${c.name}</div>
      </div>`;
   });
}

// Build product grid
function buildGrid(id, data) {
   const el = document.getElementById(id);
   el.innerHTML = data
      .map(
         (p) => `
      <div class="prod-card" onclick="addToCart(event,this,'${p.name}','${p.price}')">
         <div class="prod-card-img">
         ${p.badge ? `<div class="prod-card-badge ${p.badge}">${p.b}</div>` : ""}
         ${p.e}
         <button class="prod-card-add" onclick="addToCart(event,this.parentElement.parentElement,this.parentElement.parentElement.dataset.name,'${p.price}')">+</button>
         </div>
         <div class="prod-card-body">
         <div class="prod-card-name">${p.name}</div>
         <div class="prod-card-info">
            <div class="prod-card-time">⚡ ${p.time}</div>
            <div class="prod-card-weight">${p.w}</div>
         </div>
         <div class="prod-card-price">
            <strong>${p.price}</strong>
            ${p.old ? `<del>${p.old}</del>` : ""}
            ${p.old ? `<span class="disc">${Math.round((1 - parseInt(p.price.replace("Rs. ", "")) / parseInt(p.old.replace("Rs. ", ""))) * 100)}% off</span>` : ""}
         </div>
         </div>
      </div>`,
      )
      .join("");
}

// Add to cart
function addToCart(e, cardEl, name, priceStr) {
   e.stopPropagation();
   const price = parseInt(priceStr.replace(/[^0-9]/g, ""));
   cartItems++;
   cartTotal += price;
   document.getElementById("cartCount").textContent = cartItems;
   document.getElementById("cartBarCount").textContent = cartItems + " item" + (cartItems > 1 ? "s" : "");
   document.getElementById("cartBarTotal").textContent = "Rs. " + cartTotal;
   document.getElementById("cartBar").classList.add("visible");
   // Mark add buttons
   const addBtns = cardEl.querySelectorAll(".prod-card-add,.prod-chip-add");
   addBtns.forEach((b) => {
      b.textContent = "✓";
      b.classList.add("added");
   });
   setTimeout(
      () =>
         addBtns.forEach((b) => {
            b.textContent = "+";
            b.classList.remove("added");
         }),
      900,
   );
   showToast(name.substring(0, 30) + "... added to cart");
}

function showToast(msg) {
   const t = document.getElementById("toast");
   t.textContent = msg;
   t.classList.add("show");
   setTimeout(() => t.classList.remove("show"), 2500);
}

// Search
function handleSearch(val) {
   if (val.length > 2) showToast('Searching for "' + val + '"...');
}

// Mobile nav
function openMobileNav() {
   document.getElementById("mobileNav").classList.add("open");
   document.body.style.overflow = "hidden";
}
function closeMobileNav() {
   document.getElementById("mobileNav").classList.remove("open");
   document.body.style.overflow = "";
}

// Touch swipe on carousel
let touchX = 0;
document.addEventListener(
   "touchstart",
   (e) => {
      touchX = e.touches[0].clientX;
   },
   { passive: true },
);
document.addEventListener(
   "touchend",
   (e) => {
      const dx = e.changedTouches[0].clientX - touchX;
      if (Math.abs(dx) > 50) {
         dx < 0 ? nextSlide() : prevSlide();
      }
   },
   { passive: true },
);

//  Open mobile nav on hamburger button click
window.addEventListener("DOMContentLoaded", () => {
   document.getElementById("hamburgerBtn")?.addEventListener("click", openMobileNav);
   // etc.
});

// Init
buildCarousel();
buildCategories();
buildGrid("popularGrid", POPULAR);
buildGrid("freshGrid", FRESH);
buildGrid("dairyGrid", DAIRY);
resetTimer();
