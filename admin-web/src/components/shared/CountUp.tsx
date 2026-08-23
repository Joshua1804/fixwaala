import { useEffect, useRef, useState } from 'react'

/** Animates a number counting up from 0 on mount — a small polish touch for dashboard stats. */
export function CountUp({ value, format, durationMs = 600 }: { value: number; format?: (n: number) => string; durationMs?: number }) {
  const [display, setDisplay] = useState(0)
  const startRef = useRef<number | null>(null)

  useEffect(() => {
    startRef.current = null
    let frame: number
    function step(timestamp: number) {
      if (startRef.current === null) startRef.current = timestamp
      const progress = Math.min((timestamp - startRef.current) / durationMs, 1)
      const eased = 1 - Math.pow(1 - progress, 3)
      setDisplay(value * eased)
      if (progress < 1) frame = requestAnimationFrame(step)
    }
    frame = requestAnimationFrame(step)
    return () => cancelAnimationFrame(frame)
  }, [value, durationMs])

  const rounded = Math.round(display)
  return <>{format ? format(rounded) : rounded.toLocaleString()}</>
}
