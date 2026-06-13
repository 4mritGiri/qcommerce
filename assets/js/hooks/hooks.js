// assets/js/hooks.js
//
// LiveView JS hooks for QCommerce HomeLive.
// Import and register these in app.js:
//
//   import Hooks from "./hooks"
//   let liveSocket = new LiveSocket("/live", Socket, { hooks: Hooks, ... })
//

const Hooks = {}

// ─────────────────────────────────────────────────────────────────────────────
// GuestCartBridge
// Saves the serialised guest cart into the browser session cookie via a
// hidden form POST before redirecting to login.
//
// Server sends:  push_event("save_guest_cart", %{cart: json_or_nil, redirect: url})
// JS response:   submits a hidden form that sets the cookie, then navigates.
// ─────────────────────────────────────────────────────────────────────────────
Hooks.GuestCartBridge = {
  mounted() {
    this.handleEvent("save_guest_cart", ({ cart, redirect }) => {
      if (!cart) {
        // No cart to save — just redirect
        window.location.href = redirect
        return
      }

      // POST to /session/save_guest_cart which stores the cart in Plug.Session
      // and then redirects to the auth endpoint.
      const form = document.createElement("form")
      form.method = "POST"
      form.action = "/session/save_guest_cart"
      form.style.display = "none"

      const csrfInput = document.createElement("input")
      csrfInput.name  = "_csrf_token"
      csrfInput.value = document.querySelector("meta[name='csrf-token']")?.content || ""
      form.appendChild(csrfInput)

      const cartInput = document.createElement("input")
      cartInput.name  = "guest_cart"
      cartInput.value = cart
      form.appendChild(cartInput)

      const redirectInput = document.createElement("input")
      redirectInput.name  = "redirect_to"
      redirectInput.value = redirect
      form.appendChild(redirectInput)

      document.body.appendChild(form)
      form.submit()
    })

    // Clipboard copy
    this.handleEvent("copy_to_clipboard", ({ text }) => {
      navigator.clipboard.writeText(text).catch(() => {
        // Fallback for older browsers
        const el = document.createElement("textarea")
        el.value = text
        document.body.appendChild(el)
        el.select()
        document.execCommand("copy")
        document.body.removeChild(el)
      })
    })
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PasskeyHook
// Handles the full WebAuthn navigator.credentials.create() / .get() flow.
//
// Events FROM server:
//   "webauthn_authenticate" %{options_url: "/session/passkey/authentication_options"}
//   "webauthn_register"     %{options_url: "/session/passkey/registration_options"}
//   "passkey_submit_credential" %{credential: json_string, cart: json_or_nil}
//
// Events TO server:
//   "passkey_credential" %{credential: <credential object>}
//   "passkey_error"      %{message: "string"}
// ─────────────────────────────────────────────────────────────────────────────
Hooks.PasskeyHook = {
  mounted() {
    // ── Authentication flow ─────────────────────────────────────────────────
    this.handleEvent("webauthn_authenticate", async ({ options_url }) => {
      try {
        // 1. Get options from server (also sets challenge in session cookie)
        const optRes = await fetch(options_url, {
          credentials: "same-origin",
          headers: { "x-csrf-token": getCSRF() }
        })
        if (!optRes.ok) throw new Error("Failed to get passkey options")
        const options = await optRes.json()

        // 2. Convert base64url challenge to ArrayBuffer for the browser API
        options.challenge = base64urlToBuffer(options.challenge)

        if (options.allowCredentials) {
          options.allowCredentials = options.allowCredentials.map(c => ({
            ...c,
            id: base64urlToBuffer(c.id)
          }))
        }

        // 3. Call WebAuthn get()
        const credential = await navigator.credentials.get({ publicKey: options })

        // 4. Serialise and send to server
        const serialised = serializeCredential(credential)
        this.pushEvent("passkey_credential", { credential: serialised })

      } catch (err) {
        const msg = err.name === "NotAllowedError"
          ? "Passkey authentication was cancelled or timed out."
          : err.message || "Passkey authentication failed."
        this.pushEvent("passkey_error", { message: msg })
      }
    })

    // ── Registration flow ───────────────────────────────────────────────────
    this.handleEvent("webauthn_register", async ({ options_url }) => {
      try {
        // 1. Get options
        const optRes = await fetch(options_url, {
          credentials: "same-origin",
          headers: { "x-csrf-token": getCSRF() }
        })
        if (!optRes.ok) throw new Error("Failed to get registration options")
        const options = await optRes.json()

        // 2. Convert fields
        options.challenge = base64urlToBuffer(options.challenge)
        options.user.id   = base64urlToBuffer(options.user.id)

        // 3. Call WebAuthn create()
        const credential = await navigator.credentials.create({ publicKey: options })

        // 4. POST credential to server verification endpoint
        const serialised = serializeCredential(credential)
        const regRes = await fetch("/session/passkey/register", {
          method: "POST",
          credentials: "same-origin",
          headers: {
            "content-type": "application/json",
            "x-csrf-token": getCSRF()
          },
          body: JSON.stringify({ credential: serialised, nickname: "My Passkey" })
        })
        const result = await regRes.json()

        if (result.ok) {
          this.pushEvent("passkey_registered", { message: "Passkey registered!" })
        } else {
          this.pushEvent("passkey_error", { message: result.error || "Registration failed" })
        }

      } catch (err) {
        const msg = err.name === "NotAllowedError"
          ? "Passkey registration was cancelled."
          : err.message || "Passkey registration failed."
        this.pushEvent("passkey_error", { message: msg })
      }
    })

    // ── Submit credential (after auth, post to session controller) ──────────
    this.handleEvent("passkey_submit_credential", ({ credential, cart }) => {
      // We need a real POST to set the session cookie, so use a hidden form.
      const form = document.createElement("form")
      form.method = "POST"
      form.action = "/session/passkey/authenticate"
      form.style.display = "none"

      addHidden(form, "_csrf_token", getCSRF())
      addHidden(form, "credential",  credential)
      if (cart) addHidden(form, "guest_cart", cart)

      document.body.appendChild(form)
      form.submit()
    })
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GPSHook
// Handles GPS detection triggered by push_event("detect_gps")
// ─────────────────────────────────────────────────────────────────────────────
Hooks.GPSHook = {
  mounted() {
    this.handleEvent("detect_gps", () => {
      if (!navigator.geolocation) {
        this.pushEvent("gps_denied", {})
        return
      }
      navigator.geolocation.getCurrentPosition(
        (pos) => {
          const { latitude: lat, longitude: lng } = pos.coords
          fetch(`https://nominatim.openstreetmap.org/reverse?lat=${lat}&lon=${lng}&format=json`)
            .then(r => r.json())
            .then(data => {
              const a = data.address || {}
              const label = [a.suburb, a.city_district, a.city || a.town || a.village]
                .filter(Boolean).join(", ")
              this.pushEvent("gps_location", { lat, lng, address: label })
            })
            .catch(() => this.pushEvent("gps_location", { lat, lng, address: "" }))
        },
        () => this.pushEvent("gps_denied", {})
      )
    })
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Utilities
// ─────────────────────────────────────────────────────────────────────────────

function getCSRF() {
  return document.querySelector("meta[name='csrf-token']")?.content
    || document.querySelector("[name='_csrf_token']")?.value
    || ""
}

function base64urlToBuffer(b64url) {
  const padding = "=".repeat((4 - (b64url.length % 4)) % 4)
  const b64     = (b64url + padding).replace(/-/g, "+").replace(/_/g, "/")
  const binary  = atob(b64)
  const bytes   = new Uint8Array(binary.length)
  for (let i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i)
  return bytes.buffer
}

function bufferToBase64url(buffer) {
  const bytes  = new Uint8Array(buffer)
  let binary   = ""
  bytes.forEach(b => binary += String.fromCharCode(b))
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "")
}

function serializeCredential(credential) {
  const response = credential.response
  const result = {
    id:   credential.id,
    rawId: bufferToBase64url(credential.rawId),
    type: credential.type,
    response: {}
  }

  // ClientDataJSON is always present
  if (response.clientDataJSON) {
    result.response.clientDataJSON = bufferToBase64url(response.clientDataJSON)
  }

  // Registration specific
  if (response.attestationObject) {
    result.response.attestationObject = bufferToBase64url(response.attestationObject)
  }

  // Authentication specific
  if (response.authenticatorData) {
    result.response.authenticatorData = bufferToBase64url(response.authenticatorData)
  }
  if (response.signature) {
    result.response.signature = bufferToBase64url(response.signature)
  }
  if (response.userHandle) {
    result.response.userHandle = bufferToBase64url(response.userHandle)
  }

  return result
}

function addHidden(form, name, value) {
  const input = document.createElement("input")
  input.type  = "hidden"
  input.name  = name
  input.value = value
  form.appendChild(input)
}

// ─────────────────────────────────────────────────────────────────────────────
// SortHeader
// Detects Shift+click on sortable column headers to enable multi-column sort.
// Normal click → pushEvent("sort", {field})
// Shift+click  → pushEvent("sort", {field, multi: "true"})
// ─────────────────────────────────────────────────────────────────────────────
Hooks.SortHeader = {
  mounted() {
    this.el.addEventListener("click", (e) => {
      e.preventDefault()
      e.stopPropagation()
      const field = this.el.dataset.field
      if (!field) return
      if (e.shiftKey) {
        this.pushEvent("sort", { field, multi: "true" })
      } else {
        this.pushEvent("sort", { field })
      }
    })
  }
}

export default Hooks