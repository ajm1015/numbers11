import { useQuery, useMutation } from '@tanstack/react-query'

const API_BASE = '/api'

/**
 * Check status of a single TCP endpoint
 */
export function usePingStatus(host, port, options = {}) {
  return useQuery({
    queryKey: ['status', 'ping', host, port],
    queryFn: async () => {
      const response = await fetch(`${API_BASE}/status/ping`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ host, port, timeout: 5.0 }),
      })
      if (!response.ok) throw new Error('Failed to check status')
      return response.json()
    },
    enabled: !!host && !!port,
    refetchInterval: options.refetchInterval || 60000, // 1 minute default
    ...options,
  })
}

/**
 * Check status of a single HTTP endpoint
 */
export function useHttpStatus(url, options = {}) {
  return useQuery({
    queryKey: ['status', 'http', url],
    queryFn: async () => {
      const response = await fetch(`${API_BASE}/status/http`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ url, timeout: 10.0 }),
      })
      if (!response.ok) throw new Error('Failed to check status')
      return response.json()
    },
    enabled: !!url,
    refetchInterval: options.refetchInterval || 60000,
    ...options,
  })
}

/**
 * Batch check status of multiple machines
 */
export function useBatchStatus(machines, options = {}) {
  const checks = machines
    .filter(m => m.checkType && (m.checkPort || m.checkUrl))
    .map(machine => ({
      id: machine.id,
      type: machine.checkType,
      host: machine.host,
      port: machine.checkPort,
      url: machine.checkUrl,
    }))

  return useQuery({
    queryKey: ['status', 'batch', checks.map(c => c.id).join(',')],
    queryFn: async () => {
      if (checks.length === 0) return { results: {} }
      
      const response = await fetch(`${API_BASE}/status/batch`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ checks, timeout: 5.0 }),
      })
      if (!response.ok) throw new Error('Failed to batch check status')
      return response.json()
    },
    enabled: checks.length > 0,
    refetchInterval: options.refetchInterval || 60000,
    ...options,
  })
}

/**
 * Manual status check mutation
 */
export function useManualStatusCheck() {
  return useMutation({
    mutationFn: async ({ type, host, port, url }) => {
      const endpoint = type === 'http' || type === 'https' 
        ? `${API_BASE}/status/http`
        : `${API_BASE}/status/ping`
      
      const body = type === 'http' || type === 'https'
        ? { url: url || `${type}://${host}`, timeout: 10.0 }
        : { host, port, timeout: 5.0 }
      
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(body),
      })
      if (!response.ok) throw new Error('Failed to check status')
      return response.json()
    },
  })
}
