import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import './style.css'

// One-time cleanup for clients that are still displaying an older cached settings screen.
const RELEASE_CACHE_KEY = 'kos-manager-release'
const RELEASE_CACHE_VERSION = '2026-11-12-settings-cleanup'
try {
  if (localStorage.getItem(RELEASE_CACHE_KEY) !== RELEASE_CACHE_VERSION) {
    localStorage.setItem(RELEASE_CACHE_KEY, RELEASE_CACHE_VERSION)
    void (async () => {
      if ('serviceWorker' in navigator) {
        const registrations = await navigator.serviceWorker.getRegistrations()
        await Promise.all(registrations.map((registration) => registration.unregister()))
      }
      if ('caches' in window) {
        const keys = await caches.keys()
        await Promise.all(keys.map((key) => caches.delete(key)))
      }
      window.location.reload()
    })()
  }
} catch {
  // Continue loading normally when browser privacy settings block local storage or cache access.
}

// Trigger an immediate service-worker update when the app opens or returns to the foreground.
if ('serviceWorker' in navigator) {
  const checkForAppUpdate = () => {
    void navigator.serviceWorker.getRegistration()
      .then((registration) => registration?.update())
      .catch(() => undefined)
  }
  window.addEventListener('load', checkForAppUpdate, { once: true })
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') checkForAppUpdate()
  })
}
ReactDOM.createRoot(document.getElementById('root')!).render(<React.StrictMode><App/></React.StrictMode>)
