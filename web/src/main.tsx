import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import { App } from '@/App'
import { syncSessionAcrossTabs } from '@/auth/session'
import { TooltipProvider } from '@/components/ui/tooltip'
import { followSystemTheme } from '@/lib/theme'
import { clearListSearchOnSignOut } from '@/pages/routegen/employees/list-store'
import './index.css'

followSystemTheme()
syncSessionAcrossTabs()
clearListSearchOnSignOut()

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <TooltipProvider>
      <App />
    </TooltipProvider>
  </StrictMode>,
)
