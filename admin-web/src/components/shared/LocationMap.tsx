import { ExternalLink } from 'lucide-react'

interface LocationMapProps {
  latitude: number
  longitude: number
  label?: string
}

/** Embeds an OpenStreetMap view centered on a point — no API key, no map SDK dependency. */
export function LocationMap({ latitude, longitude, label }: LocationMapProps) {
  const delta = 0.006
  const bbox = [longitude - delta, latitude - delta, longitude + delta, latitude + delta].join(',')
  const embedSrc = `https://www.openstreetmap.org/export/embed.html?bbox=${bbox}&marker=${latitude},${longitude}&layer=mapnik`
  const externalHref = `https://www.openstreetmap.org/?mlat=${latitude}&mlon=${longitude}#map=17/${latitude}/${longitude}`
  const googleHref = `https://www.google.com/maps/search/?api=1&query=${latitude},${longitude}`

  return (
    <div className="overflow-hidden rounded-xl border border-border">
      <iframe
        title={label ?? 'Location map'}
        src={embedSrc}
        className="h-56 w-full border-0"
        loading="lazy"
      />
      <div className="flex items-center justify-between gap-2 border-t border-border bg-muted/50 px-3 py-2 text-xs">
        <span className="font-mono text-muted-foreground">
          {latitude.toFixed(5)}, {longitude.toFixed(5)}
        </span>
        <div className="flex gap-3">
          <a
            href={externalHref}
            target="_blank"
            rel="noreferrer"
            className="flex items-center gap-1 text-primary hover:underline"
          >
            OpenStreetMap <ExternalLink className="h-3 w-3" />
          </a>
          <a
            href={googleHref}
            target="_blank"
            rel="noreferrer"
            className="flex items-center gap-1 text-primary hover:underline"
          >
            Google Maps <ExternalLink className="h-3 w-3" />
          </a>
        </div>
      </div>
    </div>
  )
}
