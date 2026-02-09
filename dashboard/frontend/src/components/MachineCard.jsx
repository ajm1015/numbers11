import { Server, Terminal, Globe, Copy, ExternalLink } from 'lucide-react'
import { useState } from 'react'
import StatusBadge from './StatusBadge'

export default function MachineCard({ machine, status }) {
  const [copied, setCopied] = useState(false)
  
  const handleCopySSH = () => {
    const sshAction = machine.actions?.find(a => a.type === 'ssh')
    if (sshAction) {
      const sshCommand = `ssh ${sshAction.user}@${machine.host}`
      navigator.clipboard.writeText(sshCommand)
      setCopied(true)
      setTimeout(() => setCopied(false), 2000)
    }
  }
  
  const handleOpenWeb = (url) => {
    window.open(url, '_blank')
  }
  
  const sshAction = machine.actions?.find(a => a.type === 'ssh')
  const webAction = machine.actions?.find(a => a.type === 'web')
  
  const currentStatus = status?.status || 'unknown'
  const latency = status?.latency_ms
  
  return (
    <div className="bg-dashboard-card border border-dashboard-border rounded-xl p-4 hover:border-gray-600 transition-colors group">
      {/* Header */}
      <div className="flex items-start justify-between mb-3">
        <div className="flex items-center gap-3">
          <div className="p-2 bg-blue-500/10 rounded-lg">
            <Server className="w-5 h-5 text-blue-400" />
          </div>
          <div>
            <h3 className="font-semibold text-gray-100">{machine.name}</h3>
            <p className="text-sm text-gray-500 font-mono">{machine.host}</p>
          </div>
        </div>
        <StatusBadge status={currentStatus} latency={latency} />
      </div>
      
      {/* Description */}
      {machine.description && (
        <p className="text-sm text-gray-400 mb-3">{machine.description}</p>
      )}
      
      {/* Tags */}
      {machine.tags && machine.tags.length > 0 && (
        <div className="flex flex-wrap gap-1.5 mb-4">
          {machine.tags.map((tag) => (
            <span
              key={tag}
              className="px-2 py-0.5 text-xs bg-gray-800 text-gray-400 rounded-md"
            >
              {tag}
            </span>
          ))}
        </div>
      )}
      
      {/* Actions */}
      <div className="flex items-center gap-2 pt-3 border-t border-dashboard-border">
        {sshAction && (
          <button
            onClick={handleCopySSH}
            className="flex items-center gap-1.5 px-3 py-1.5 text-sm bg-gray-800 hover:bg-gray-700 rounded-lg text-gray-300 transition-colors"
          >
            {copied ? (
              <>
                <Copy className="w-3.5 h-3.5 text-green-400" />
                <span className="text-green-400">Copied!</span>
              </>
            ) : (
              <>
                <Terminal className="w-3.5 h-3.5" />
                <span>SSH</span>
              </>
            )}
          </button>
        )}
        {webAction && (
          <button
            onClick={() => handleOpenWeb(webAction.url)}
            className="flex items-center gap-1.5 px-3 py-1.5 text-sm bg-gray-800 hover:bg-gray-700 rounded-lg text-gray-300 transition-colors"
          >
            <Globe className="w-3.5 h-3.5" />
            <span>Web UI</span>
            <ExternalLink className="w-3 h-3 opacity-50" />
          </button>
        )}
      </div>
    </div>
  )
}
