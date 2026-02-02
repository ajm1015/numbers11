import { FolderGit2, Github, FileText, ExternalLink, Globe } from 'lucide-react'
import StatusBadge from './StatusBadge'

const techColors = {
  python: 'bg-yellow-500/20 text-yellow-400 border-yellow-500/30',
  typescript: 'bg-blue-500/20 text-blue-400 border-blue-500/30',
  javascript: 'bg-yellow-400/20 text-yellow-300 border-yellow-400/30',
  react: 'bg-cyan-500/20 text-cyan-400 border-cyan-500/30',
  docker: 'bg-blue-400/20 text-blue-300 border-blue-400/30',
  rust: 'bg-orange-500/20 text-orange-400 border-orange-500/30',
  go: 'bg-cyan-400/20 text-cyan-300 border-cyan-400/30',
  powershell: 'bg-blue-600/20 text-blue-400 border-blue-600/30',
  bash: 'bg-green-500/20 text-green-400 border-green-500/30',
  automation: 'bg-purple-500/20 text-purple-400 border-purple-500/30',
  default: 'bg-gray-500/20 text-gray-400 border-gray-500/30',
}

export default function ProjectCard({ project }) {
  const getTechColor = (tech) => {
    return techColors[tech.toLowerCase()] || techColors.default
  }
  
  return (
    <div className="bg-dashboard-card border border-dashboard-border rounded-xl p-4 hover:border-gray-600 transition-colors group">
      {/* Header */}
      <div className="flex items-start justify-between mb-3">
        <div className="flex items-center gap-3">
          <div className="p-2 bg-purple-500/10 rounded-lg">
            <FolderGit2 className="w-5 h-5 text-purple-400" />
          </div>
          <div>
            <h3 className="font-semibold text-gray-100">{project.name}</h3>
          </div>
        </div>
        <StatusBadge status={project.status || 'active'} />
      </div>
      
      {/* Description */}
      {project.description && (
        <p className="text-sm text-gray-400 mb-3">{project.description}</p>
      )}
      
      {/* Tech Stack Tags */}
      {project.tags && project.tags.length > 0 && (
        <div className="flex flex-wrap gap-1.5 mb-4">
          {project.tags.map((tag) => (
            <span
              key={tag}
              className={`px-2 py-0.5 text-xs rounded-md border ${getTechColor(tag)}`}
            >
              {tag}
            </span>
          ))}
        </div>
      )}
      
      {/* Links */}
      {project.links && Object.keys(project.links).length > 0 && (
        <div className="flex items-center gap-2 pt-3 border-t border-dashboard-border">
          {project.links.github && (
            <a
              href={project.links.github}
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-1.5 px-3 py-1.5 text-sm bg-gray-800 hover:bg-gray-700 rounded-lg text-gray-300 transition-colors"
            >
              <Github className="w-3.5 h-3.5" />
              <span>GitHub</span>
            </a>
          )}
          {project.links.docs && (
            <a
              href={project.links.docs}
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-1.5 px-3 py-1.5 text-sm bg-gray-800 hover:bg-gray-700 rounded-lg text-gray-300 transition-colors"
            >
              <FileText className="w-3.5 h-3.5" />
              <span>Docs</span>
            </a>
          )}
          {project.links.production && (
            <a
              href={project.links.production}
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-1.5 px-3 py-1.5 text-sm bg-gray-800 hover:bg-gray-700 rounded-lg text-gray-300 transition-colors"
            >
              <Globe className="w-3.5 h-3.5" />
              <span>Live</span>
              <ExternalLink className="w-3 h-3 opacity-50" />
            </a>
          )}
          {project.links.staging && (
            <a
              href={project.links.staging}
              target="_blank"
              rel="noopener noreferrer"
              className="flex items-center gap-1.5 px-3 py-1.5 text-sm bg-gray-800 hover:bg-gray-700 rounded-lg text-gray-300 transition-colors"
            >
              <Globe className="w-3.5 h-3.5 text-orange-400" />
              <span>Staging</span>
            </a>
          )}
        </div>
      )}
    </div>
  )
}
