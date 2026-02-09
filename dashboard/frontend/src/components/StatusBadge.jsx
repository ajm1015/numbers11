import { Circle } from 'lucide-react'

const statusConfig = {
  online: {
    color: 'text-green-500',
    bgColor: 'bg-green-500/10',
    borderColor: 'border-green-500/30',
    label: 'Online',
    pulse: true,
  },
  offline: {
    color: 'text-red-500',
    bgColor: 'bg-red-500/10',
    borderColor: 'border-red-500/30',
    label: 'Offline',
    pulse: false,
  },
  unknown: {
    color: 'text-yellow-500',
    bgColor: 'bg-yellow-500/10',
    borderColor: 'border-yellow-500/30',
    label: 'Unknown',
    pulse: false,
  },
  checking: {
    color: 'text-blue-500',
    bgColor: 'bg-blue-500/10',
    borderColor: 'border-blue-500/30',
    label: 'Checking...',
    pulse: true,
  },
  active: {
    color: 'text-green-500',
    bgColor: 'bg-green-500/10',
    borderColor: 'border-green-500/30',
    label: 'Active',
    pulse: false,
  },
  archived: {
    color: 'text-gray-500',
    bgColor: 'bg-gray-500/10',
    borderColor: 'border-gray-500/30',
    label: 'Archived',
    pulse: false,
  },
  wip: {
    color: 'text-orange-500',
    bgColor: 'bg-orange-500/10',
    borderColor: 'border-orange-500/30',
    label: 'WIP',
    pulse: false,
  },
}

export default function StatusBadge({ status, showLabel = true, size = 'sm', latency }) {
  const config = statusConfig[status] || statusConfig.unknown
  
  const sizeClasses = {
    xs: 'w-2 h-2',
    sm: 'w-2.5 h-2.5',
    md: 'w-3 h-3',
  }
  
  return (
    <div className={`inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full ${config.bgColor} border ${config.borderColor}`}>
      <Circle
        className={`${sizeClasses[size]} ${config.color} fill-current ${config.pulse ? 'status-pulse' : ''}`}
      />
      {showLabel && (
        <span className={`text-xs font-medium ${config.color}`}>
          {config.label}
          {latency !== undefined && latency !== null && status === 'online' && (
            <span className="text-gray-400 ml-1">({latency}ms)</span>
          )}
        </span>
      )}
    </div>
  )
}
