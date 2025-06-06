// docker/backend/server.js
const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const mysql = require('mysql2/promise');

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(express.json());

// Database connections
const pgPool = new Pool({
  host: process.env.PG_HOST || 'localhost',
  port: process.env.PG_PORT || 5432,
  database: process.env.PG_DATABASE || 'kamranpgdb',
  user: process.env.PG_USER || 'kamranuser',
  password: process.env.PG_PASSWORD || 'Password123!',
});

const mysqlConfig = {
  host: process.env.MYSQL_HOST || 'localhost',
  port: process.env.MYSQL_PORT || 3306,
  database: process.env.MYSQL_DATABASE || 'kamranmysqldb',
  user: process.env.MYSQL_USER || 'kamranuser',
  password: process.env.MYSQL_PASSWORD || 'Password123!',
};

// Initialize database tables
async function initializeDatabases() {
  try {
    // PostgreSQL table
    await pgPool.query(`
      CREATE TABLE IF NOT EXISTS users (
        id SERIAL PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(100) UNIQUE NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // MySQL table
    const mysqlConnection = await mysql.createConnection(mysqlConfig);
    await mysqlConnection.execute(`
      CREATE TABLE IF NOT EXISTS users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(100) UNIQUE NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);
    await mysqlConnection.end();

    console.log('Database tables initialized successfully');
  } catch (error) {
    console.error('Database initialization error:', error);
  }
}

// Routes
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    version: '1.0.0',
    environment: process.env.NODE_ENV || 'development'
  });
});

// Get all users (from PostgreSQL)
app.get('/api/users', async (req, res) => {
  try {
    const result = await pgPool.query('SELECT * FROM users ORDER BY created_at DESC');
    res.json(result.rows);
  } catch (error) {
    console.error('Error fetching users:', error);
    res.status(500).json({ error: 'Failed to fetch users' });
  }
});

// Add new user (to PostgreSQL)
app.post('/api/users', async (req, res) => {
  const { name, email } = req.body;
  
  if (!name || !email) {
    return res.status(400).json({ error: 'Name and email are required' });
  }

  try {
    const result = await pgPool.query(
      'INSERT INTO users (name, email) VALUES ($1, $2) RETURNING *',
      [name, email]
    );
    
    // Also insert into MySQL for BI tool demonstration
    try {
      const mysqlConnection = await mysql.createConnection(mysqlConfig);
      await mysqlConnection.execute(
        'INSERT INTO users (name, email) VALUES (?, ?)',
        [name, email]
      );
      await mysqlConnection.end();
    } catch (mysqlError) {
      console.warn('MySQL insert failed (this is ok for demo):', mysqlError.message);
    }

    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('Error adding user:', error);
    if (error.code === '23505') { // Duplicate email
      res.status(409).json({ error: 'Email already exists' });
    } else {
      res.status(500).json({ error: 'Failed to add user' });
    }
  }
});

// Get users from MySQL (for BI tool)
app.get('/api/mysql/users', async (req, res) => {
  try {
    const connection = await mysql.createConnection(mysqlConfig);
    const [rows] = await connection.execute('SELECT * FROM users ORDER BY created_at DESC');
    await connection.end();
    res.json(rows);
  } catch (error) {
    console.error('Error fetching MySQL users:', error);
    res.status(500).json({ error: 'Failed to fetch users from MySQL' });
  }
});

// Database stats endpoint
app.get('/api/stats', async (req, res) => {
  try {
    const pgResult = await pgPool.query('SELECT COUNT(*) as count FROM users');
    const pgCount = parseInt(pgResult.rows[0].count);

    let mysqlCount = 0;
    try {
      const mysqlConnection = await mysql.createConnection(mysqlConfig);
      const [mysqlRows] = await mysqlConnection.execute('SELECT COUNT(*) as count FROM users');
      await mysqlConnection.end();
      mysqlCount = mysqlRows[0].count;
    } catch (mysqlError) {
      console.warn('MySQL stats failed (this is ok for demo):', mysqlError.message);
    }

    res.json({
      postgresql_users: pgCount,
      mysql_users: mysqlCount,
      total_users: pgCount,
      last_updated: new Date().toISOString(),
      server_uptime: process.uptime()
    });
  } catch (error) {
    console.error('Error fetching stats:', error);
    res.status(500).json({ error: 'Failed to fetch stats' });
  }
});

// Test database connections
app.get('/api/test-connections', async (req, res) => {
  const results = {
    postgresql: false,
    mysql: false,
    timestamp: new Date().toISOString()
  };

  // Test PostgreSQL
  try {
    await pgPool.query('SELECT 1');
    results.postgresql = true;
  } catch (error) {
    console.error('PostgreSQL connection test failed:', error.message);
  }

  // Test MySQL
  try {
    const mysqlConnection = await mysql.createConnection(mysqlConfig);
    await mysqlConnection.execute('SELECT 1');
    await mysqlConnection.end();
    results.mysql = true;
  } catch (error) {
    console.error('MySQL connection test failed:', error.message);
  }

  res.json(results);
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Kamran Demo API Server',
    version: '1.0.0',
    endpoints: [
      'GET /health - Health check',
      'GET /api/users - Get all users',
      'POST /api/users - Add new user',
      'GET /api/mysql/users - Get users from MySQL',
      'GET /api/stats - Get database statistics',
      'GET /api/test-connections - Test database connections'
    ],
    timestamp: new Date().toISOString()
  });
});

// Error handling middleware
app.use((error, req, res, next) => {
  console.error('Unhandled error:', error);
  res.status(500).json({ 
    error: 'Internal server error',
    timestamp: new Date().toISOString()
  });
});

// 404 handler
app.use('*', (req, res) => {
  res.status(404).json({ 
    error: 'Route not found',
    path: req.originalUrl,
    timestamp: new Date().toISOString()
  });
});

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('SIGTERM received, shutting down gracefully');
  await pgPool.end();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('SIGINT received, shutting down gracefully');
  await pgPool.end();
  process.exit(0);
});

// Start server
async function startServer() {
  try {
    await initializeDatabases();
    
    app.listen(PORT, '0.0.0.0', () => {
      console.log(`🚀 Server running on port ${PORT}`);
      console.log(`📊 Health check: http://localhost:${PORT}/health`);
      console.log(`👥 Users API: http://localhost:${PORT}/api/users`);
      console.log(`📈 Stats API: http://localhost:${PORT}/api/stats`);
      console.log(`🔍 Test connections: http://localhost:${PORT}/api/test-connections`);
      console.log(`🌍 Environment: ${process.env.NODE_ENV || 'development'}`);
    });
  } catch (error) {
    console.error('Failed to start server:', error);
    process.exit(1);
  }
}

startServer();