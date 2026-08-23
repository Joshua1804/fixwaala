import type { ReactNode } from 'react'
import { useNavigate, useLocation } from 'react-router-dom'
import { ArrowLeft } from 'lucide-react'
import { Button } from '@/components/ui/button'

interface PageScaffoldProps {
  title: string
  subtitle?: string
  actions?: ReactNode
  back?: boolean
  children: ReactNode
}

/** Consistent header (title + subtitle + trailing actions) above every admin screen's content. */
export function PageScaffold({ title, subtitle, actions, back, children }: PageScaffoldProps) {
  const navigate = useNavigate()
  const location = useLocation()
  const canGoBack = back ?? location.key !== 'default'

  return (
    <div key={location.pathname} className="animate-in fade-in slide-in-from-bottom-1 p-8 duration-300 ease-out">
      <div className="mb-8 flex items-start justify-between gap-4">
        <div className="flex items-start gap-1">
          {canGoBack && (
            <Button
              variant="ghost"
              size="icon"
              className="mt-0.5 -ml-2 transition-transform hover:-translate-x-0.5"
              onClick={() => navigate(-1)}
              title="Back"
            >
              <ArrowLeft className="h-5 w-5" />
            </Button>
          )}
          <div>
            <h1 className="text-2xl font-semibold text-foreground">{title}</h1>
            {subtitle && <p className="mt-1 text-sm text-muted-foreground">{subtitle}</p>}
          </div>
        </div>
        {actions && <div className="flex shrink-0 gap-2">{actions}</div>}
      </div>
      {children}
    </div>
  )
}
