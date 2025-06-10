{
  "version": "1.50.0",
  "timestamp": "2024-01-01T00:00:00.000Z",
  "collection": {
    "name": "User Analytics Templates",
    "description": "PostgreSQL and MySQL user analytics dashboards"
  },
  "dashboards": [
    {
      "name": "PostgreSQL User Analytics",
      "description": "Real-time user analytics from PostgreSQL",
      "cards": [
        {
          "name": "Total PostgreSQL Users",
          "dataset_query": {
            "type": "native",
            "native": {
              "query": "SELECT COUNT(*) as total_users FROM users"
            }
          },
          "display": "scalar",
          "visualization_settings": {
            "scalar.field": "total_users"
          }
        },
        {
          "name": "PostgreSQL Daily Registrations",
          "dataset_query": {
            "type": "native", 
            "native": {
              "query": "SELECT DATE(created_at) as date, COUNT(*) as registrations FROM users GROUP BY DATE(created_at) ORDER BY date"
            }
          },
          "display": "line",
          "visualization_settings": {
            "graph.dimensions": ["date"],
            "graph.metrics": ["registrations"]
          }
        },
        {
          "name": "Recent PostgreSQL Users",
          "dataset_query": {
            "type": "native",
            "native": {
              "query": "SELECT name, email, created_at FROM users ORDER BY created_at DESC LIMIT 10"
            }
          },
          "display": "table"
        }
      ]
    },
    {
      "name": "MySQL User Analytics", 
      "description": "Real-time user analytics from MySQL",
      "cards": [
        {
          "name": "Total MySQL Users",
          "dataset_query": {
            "type": "native",
            "native": {
              "query": "SELECT COUNT(*) as total_users FROM users"
            }
          },
          "display": "scalar",
          "visualization_settings": {
            "scalar.field": "total_users"
          }
        },
        {
          "name": "MySQL Daily Registrations",
          "dataset_query": {
            "type": "native",
            "native": {
              "query": "SELECT DATE(created_at) as date, COUNT(*) as registrations FROM users GROUP BY DATE(created_at) ORDER BY date"
            }
          },
          "display": "line",
          "visualization_settings": {
            "graph.dimensions": ["date"],
            "graph.metrics": ["registrations"]
          }
        },
        {
          "name": "Recent MySQL Users",
          "dataset_query": {
            "type": "native",
            "native": {
              "query": "SELECT name, email, created_at FROM users ORDER BY created_at DESC LIMIT 10"
            }
          },
          "display": "table"
        }
      ]
    }
  ]
}