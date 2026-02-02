import { useState, useMemo } from 'react'
import { Server, FolderGit2, Link, RefreshCw, Moon, Sun, LayoutGrid } from 'lucide-react'
import { useBatchStatus } from '../hooks/useStatus'
import MachineCard from '../components/MachineCard'
import ProjectCard from '../components/ProjectCard'
import LinkCard from '../components/LinkCard'
import SearchFilter from '../components/SearchFilter'
import config from '../config/dashboard.json'

const tabs = [
  { id: 'all', label: 'All', icon: LayoutGrid },
  { id: 'machines', label: 'Machines', icon: Server },
  { id: 'projects', label: 'Projects', icon: FolderGit2 },
  { id: 'links', label: 'Links', icon: Link },
]

export default function Dashboard() {
  const [activeTab, setActiveTab] = useState('all')
  const [searchQuery, setSearchQuery] = useState('')
  const [isDark, setIsDark] = useState(true)
  
  // Fetch status for all machines
  const { 
    data: statusData, 
    isLoading: statusLoading,
    refetch: refetchStatus,
    isFetching: isRefetching,
  } = useBatchStatus(config.machines, {
    refetchInterval: config.settings?.refreshInterval || 60000,
  })
  
  const statusResults = statusData?.results || {}
  
  // Filter data based on search query
  const filteredData = useMemo(() => {
    const query = searchQuery.toLowerCase()
    
    const machines = config.machines.filter(machine => 
      machine.name.toLowerCase().includes(query) ||
      machine.host.toLowerCase().includes(query) ||
      machine.description?.toLowerCase().includes(query) ||
      machine.tags?.some(tag => tag.toLowerCase().includes(query))
    )
    
    const projects = config.projects.filter(project =>
      project.name.toLowerCase().includes(query) ||
      project.description?.toLowerCase().includes(query) ||
      project.tags?.some(tag => tag.toLowerCase().includes(query))
    )
    
    const links = config.links.filter(category =>
      category.category.toLowerCase().includes(query) ||
      category.items.some(item => 
        item.name.toLowerCase().includes(query) ||
        item.description?.toLowerCase().includes(query)
      )
    ).map(category => ({
      ...category,
      items: category.items.filter(item =>
        !query ||
        category.category.toLowerCase().includes(query) ||
        item.name.toLowerCase().includes(query) ||
        item.description?.toLowerCase().includes(query)
      )
    }))
    
    return { machines, projects, links }
  }, [searchQuery])
  
  // Count online machines
  const onlineMachines = config.machines.filter(
    m => statusResults[m.id]?.status === 'online'
  ).length
  
  return (
    <div className="min-h-screen bg-dashboard-bg">
      {/* Header */}
      <header className="sticky top-0 z-10 bg-dashboard-bg/80 backdrop-blur-lg border-b border-dashboard-border">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex items-center justify-between h-16">
            {/* Logo & Title */}
            <div className="flex items-center gap-3">
              <div className="p-2 bg-gradient-to-br from-blue-500 to-purple-600 rounded-lg">
                <LayoutGrid className="w-5 h-5 text-white" />
              </div>
              <div>
                <h1 className="text-lg font-semibold text-gray-100">
                  {config.settings?.title || 'Dashboard Console'}
                </h1>
                <p className="text-xs text-gray-500">
                  {onlineMachines}/{config.machines.length} machines online
                </p>
              </div>
            </div>
            
            {/* Actions */}
            <div className="flex items-center gap-2">
              <button
                onClick={() => refetchStatus()}
                disabled={isRefetching}
                className="p-2 rounded-lg hover:bg-dashboard-card text-gray-400 hover:text-gray-200 transition-colors disabled:opacity-50"
                title="Refresh status"
              >
                <RefreshCw className={`w-4 h-4 ${isRefetching ? 'animate-spin' : ''}`} />
              </button>
              <button
                onClick={() => setIsDark(!isDark)}
                className="p-2 rounded-lg hover:bg-dashboard-card text-gray-400 hover:text-gray-200 transition-colors"
                title="Toggle theme"
              >
                {isDark ? <Sun className="w-4 h-4" /> : <Moon className="w-4 h-4" />}
              </button>
            </div>
          </div>
        </div>
      </header>
      
      {/* Main Content */}
      <main className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-6">
        {/* Search & Tabs */}
        <div className="flex flex-col sm:flex-row gap-4 mb-6">
          <div className="flex-1">
            <SearchFilter 
              value={searchQuery}
              onChange={setSearchQuery}
              placeholder="Search machines, projects, links..."
            />
          </div>
          <div className="flex bg-dashboard-card rounded-lg p-1 border border-dashboard-border">
            {tabs.map((tab) => {
              const Icon = tab.icon
              return (
                <button
                  key={tab.id}
                  onClick={() => setActiveTab(tab.id)}
                  className={`flex items-center gap-1.5 px-3 py-1.5 rounded-md text-sm font-medium transition-colors ${
                    activeTab === tab.id
                      ? 'bg-blue-500/20 text-blue-400'
                      : 'text-gray-400 hover:text-gray-200 hover:bg-dashboard-hover'
                  }`}
                >
                  <Icon className="w-4 h-4" />
                  <span className="hidden sm:inline">{tab.label}</span>
                </button>
              )
            })}
          </div>
        </div>
        
        {/* Machines Section */}
        {(activeTab === 'all' || activeTab === 'machines') && filteredData.machines.length > 0 && (
          <section className="mb-8">
            <div className="flex items-center gap-2 mb-4">
              <Server className="w-5 h-5 text-blue-400" />
              <h2 className="text-lg font-semibold text-gray-100">Machines</h2>
              <span className="text-sm text-gray-500">({filteredData.machines.length})</span>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {filteredData.machines.map((machine) => (
                <MachineCard
                  key={machine.id}
                  machine={machine}
                  status={statusResults[machine.id]}
                />
              ))}
            </div>
          </section>
        )}
        
        {/* Projects Section */}
        {(activeTab === 'all' || activeTab === 'projects') && filteredData.projects.length > 0 && (
          <section className="mb-8">
            <div className="flex items-center gap-2 mb-4">
              <FolderGit2 className="w-5 h-5 text-purple-400" />
              <h2 className="text-lg font-semibold text-gray-100">Projects</h2>
              <span className="text-sm text-gray-500">({filteredData.projects.length})</span>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {filteredData.projects.map((project) => (
                <ProjectCard key={project.id} project={project} />
              ))}
            </div>
          </section>
        )}
        
        {/* Links Section */}
        {(activeTab === 'all' || activeTab === 'links') && filteredData.links.length > 0 && (
          <section className="mb-8">
            <div className="flex items-center gap-2 mb-4">
              <Link className="w-5 h-5 text-green-400" />
              <h2 className="text-lg font-semibold text-gray-100">Quick Links</h2>
            </div>
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
              {filteredData.links.map((category, index) => (
                <LinkCard key={index} category={category} />
              ))}
            </div>
          </section>
        )}
        
        {/* Empty State */}
        {filteredData.machines.length === 0 && 
         filteredData.projects.length === 0 && 
         filteredData.links.length === 0 && (
          <div className="text-center py-12">
            <p className="text-gray-500">No results found for "{searchQuery}"</p>
          </div>
        )}
      </main>
      
      {/* Footer */}
      <footer className="border-t border-dashboard-border py-4 mt-8">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <p className="text-center text-xs text-gray-600">
            Dashboard Console • Status refreshes every {Math.round((config.settings?.refreshInterval || 60000) / 1000)}s
          </p>
        </div>
      </footer>
    </div>
  )
}
