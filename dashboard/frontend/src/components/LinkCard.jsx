import { 
  ExternalLink, 
  Cloud, 
  Code, 
  Database, 
  FileText, 
  Globe, 
  Lock, 
  Mail, 
  MessageSquare, 
  Monitor, 
  Settings, 
  Terminal,
  Folder,
  Link as LinkIcon,
  ChevronDown,
  ChevronRight
} from 'lucide-react'
import { useState } from 'react'

const iconMap = {
  cloud: Cloud,
  code: Code,
  database: Database,
  docs: FileText,
  globe: Globe,
  lock: Lock,
  mail: Mail,
  chat: MessageSquare,
  monitor: Monitor,
  settings: Settings,
  terminal: Terminal,
  folder: Folder,
  link: LinkIcon,
}

function LinkItem({ item }) {
  const Icon = iconMap[item.icon] || LinkIcon
  
  return (
    <a
      href={item.url}
      target="_blank"
      rel="noopener noreferrer"
      className="flex items-center gap-3 px-3 py-2.5 rounded-lg hover:bg-dashboard-hover transition-colors group"
    >
      <div className="p-1.5 bg-gray-800 rounded-md group-hover:bg-gray-700">
        <Icon className="w-4 h-4 text-gray-400 group-hover:text-gray-300" />
      </div>
      <div className="flex-1 min-w-0">
        <p className="text-sm font-medium text-gray-200 truncate">{item.name}</p>
        {item.description && (
          <p className="text-xs text-gray-500 truncate">{item.description}</p>
        )}
      </div>
      <ExternalLink className="w-3.5 h-3.5 text-gray-600 opacity-0 group-hover:opacity-100 transition-opacity" />
    </a>
  )
}

export default function LinkCard({ category }) {
  const [isExpanded, setIsExpanded] = useState(true)
  
  return (
    <div className="bg-dashboard-card border border-dashboard-border rounded-xl overflow-hidden">
      {/* Category Header */}
      <button
        onClick={() => setIsExpanded(!isExpanded)}
        className="w-full flex items-center justify-between px-4 py-3 hover:bg-dashboard-hover transition-colors"
      >
        <div className="flex items-center gap-2">
          <Folder className="w-4 h-4 text-gray-500" />
          <h3 className="font-medium text-gray-200">{category.category}</h3>
          <span className="text-xs text-gray-500 bg-gray-800 px-1.5 py-0.5 rounded">
            {category.items.length}
          </span>
        </div>
        {isExpanded ? (
          <ChevronDown className="w-4 h-4 text-gray-500" />
        ) : (
          <ChevronRight className="w-4 h-4 text-gray-500" />
        )}
      </button>
      
      {/* Links */}
      {isExpanded && (
        <div className="px-2 pb-2 space-y-0.5">
          {category.items.map((item, index) => (
            <LinkItem key={index} item={item} />
          ))}
        </div>
      )}
    </div>
  )
}
