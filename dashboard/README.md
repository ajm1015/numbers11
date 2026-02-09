# Dashboard Console

A modern, configuration-driven personal dashboard for managing machines, projects, and quick links with live status monitoring.

![Dashboard Preview](https://via.placeholder.com/800x400?text=Dashboard+Console)

## Features

- **Machine Management**: Monitor servers with live status indicators, quick SSH commands, and web UI links
- **Project Directory**: Organize projects with tech stack badges, GitHub links, and status tracking
- **Quick Links**: Categorized bookmarks for cloud consoles, DevOps tools, and services
- **Live Status Checking**: Backend API that pings machines and checks HTTP endpoints
- **Search & Filter**: Quick filtering across all sections
- **Dark Mode**: Beautiful dark-first design with responsive layout

## Tech Stack

- **Frontend**: React 18 + Vite + Tailwind CSS + React Query
- **Backend**: Python FastAPI with async status checking
- **Deployment**: Docker Compose ready

## Quick Start

### Option 1: Docker Compose (Recommended)

```bash
# Clone and start
cd dashboard
docker-compose up -d

# Access the dashboard
open http://localhost:3000
```

### Option 2: Local Development

**Backend:**

```bash
cd backend

# Create virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Run the server
uvicorn main:app --reload --port 8000
```

**Frontend:**

```bash
cd frontend

# Install dependencies
npm install

# Run dev server
npm run dev
```

Access the dashboard at http://localhost:3000

## Configuration

Edit `frontend/src/config/dashboard.json` to customize your dashboard:

### Machines

```json
{
  "machines": [
    {
      "id": "unique-id",
      "name": "Display Name",
      "host": "192.168.1.100",
      "description": "Optional description",
      "tags": ["homelab", "proxmox"],
      "actions": [
        {"type": "ssh", "user": "admin"},
        {"type": "web", "url": "https://192.168.1.100:8006"}
      ],
      "checkType": "tcp",
      "checkPort": 22
    }
  ]
}
```

### Projects

```json
{
  "projects": [
    {
      "id": "project-id",
      "name": "Project Name",
      "description": "What this project does",
      "tags": ["react", "python", "docker"],
      "links": {
        "github": "https://github.com/user/repo",
        "docs": "https://docs.example.com",
        "production": "https://example.com",
        "staging": "https://staging.example.com"
      },
      "status": "active"  // active, wip, archived
    }
  ]
}
```

### Quick Links

```json
{
  "links": [
    {
      "category": "Category Name",
      "items": [
        {
          "name": "Service Name",
          "url": "https://example.com",
          "icon": "cloud",  // cloud, code, database, docs, globe, lock, mail, chat, monitor, settings, terminal, folder, link
          "description": "Optional description"
        }
      ]
    }
  ]
}
```

### Settings

```json
{
  "settings": {
    "title": "My Dashboard",
    "refreshInterval": 60000,  // Status check interval in ms
    "theme": "dark"
  }
}
```

## API Endpoints

The backend provides these endpoints for status checking:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/health` | GET | Health check |
| `/api/status/ping` | POST | Check TCP port connectivity |
| `/api/status/http` | POST | Check HTTP endpoint health |
| `/api/status/batch` | POST | Check multiple targets at once |

### Example: Ping Request

```bash
curl -X POST http://localhost:8000/api/status/ping \
  -H "Content-Type: application/json" \
  -d '{"host": "192.168.1.100", "port": 22}'
```

### Example: HTTP Check

```bash
curl -X POST http://localhost:8000/api/status/http \
  -H "Content-Type: application/json" \
  -d '{"url": "https://example.com"}'
```

## Deployment

### Self-Hosted with Docker

1. Clone the repository
2. Edit `frontend/src/config/dashboard.json` with your machines/projects
3. Run `docker-compose up -d`
4. Access at http://your-server:3000

### Behind a Reverse Proxy (Nginx/Traefik)

The frontend container serves on port 80 and proxies `/api` to the backend. Configure your reverse proxy to point to the frontend container.

### Static Hosting (Frontend Only)

If you don't need live status checking:

1. Build the frontend: `cd frontend && npm run build`
2. Deploy the `dist` folder to any static host (GitHub Pages, Netlify, Vercel)

## Project Structure

```
dashboard/
├── frontend/
│   ├── src/
│   │   ├── components/    # React components
│   │   ├── pages/         # Page components
│   │   ├── config/        # Dashboard configuration
│   │   ├── hooks/         # React Query hooks
│   │   ├── App.jsx
│   │   └── main.jsx
│   ├── package.json
│   └── Dockerfile
├── backend/
│   ├── main.py           # FastAPI app
│   ├── status_checker.py # Status checking logic
│   ├── requirements.txt
│   └── Dockerfile
├── docker-compose.yml
└── README.md
```

## License

MIT
