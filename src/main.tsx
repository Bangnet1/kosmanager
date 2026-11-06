import React from 'react'
import ReactDOM from 'react-dom/client'
import App from './App'
import './style.css'

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
