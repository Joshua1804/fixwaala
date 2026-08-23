import { formatDistanceToNow } from 'date-fns'
import { Tooltip, TooltipContent, TooltipTrigger } from '@/components/ui/tooltip'

/** Relative time ("2 hours ago") with the absolute timestamp on hover. */
export function RelativeTime({ date, className }: { date: Date; className?: string }) {
  return (
    <Tooltip>
      <TooltipTrigger render={<span className={className} />}>
        {formatDistanceToNow(date, { addSuffix: true })}
      </TooltipTrigger>
      <TooltipContent>{date.toLocaleString()}</TooltipContent>
    </Tooltip>
  )
}
