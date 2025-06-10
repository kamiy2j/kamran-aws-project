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
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    `);

    // MySQL table
    const mysqlConnection = await mysql.createConnection(mysqlConfig);
    await mysqlConnection.execute(`
      CREATE TABLE IF NOT EXISTS users (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100) NOT NULL,
        email VARCHAR(100) UNIQUE NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
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
  const os = require('os');
  res.json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    version: '1.0.1',
    environment: process.env.NODE_ENV || 'development',
    hostname: os.hostname(),
    instance_id: process.env.EC2_INSTANCE_ID || 'unknown'
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

// Add new user (to both databases)
app.post('/api/users', async (req, res) => {
  const { name, email } = req.body;
  
  if (!name || !email) {
    return res.status(400).json({ error: 'Name and email are required' });
  }

  try {
    // Insert into PostgreSQL
    const result = await pgPool.query(
      'INSERT INTO users (name, email) VALUES ($1, $2) RETURNING *',
      [name, email]
    );
    
    // Also insert into MySQL for BI tool
    try {
      const mysqlConnection = await mysql.createConnection(mysqlConfig);
      await mysqlConnection.execute(
        'INSERT INTO users (name, email) VALUES (?, ?)',
        [name, email]
      );
      await mysqlConnection.end();
      console.log('User added to both databases');
    } catch (mysqlError) {
      console.warn('MySQL insert failed:', mysqlError.message);
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

// Delete user (from both databases)
app.delete('/api/users/:id', async (req, res) => {
  const userId = parseInt(req.params.id);
  
  if (!userId || isNaN(userId)) {
    return res.status(400).json({ error: 'Valid user ID is required' });
  }

  try {
    // Get user details before deletion
    const userResult = await pgPool.query('SELECT * FROM users WHERE id = $1', [userId]);
    
    if (userResult.rows.length === 0) {
      return res.status(404).json({ error: 'User not found' });
    }

    const user = userResult.rows[0];

    // Delete from PostgreSQL
    await pgPool.query('DELETE FROM users WHERE id = $1', [userId]);
    
    // Also delete from MySQL
    try {
      const mysqlConnection = await mysql.createConnection(mysqlConfig);
      await mysqlConnection.execute(
        'DELETE FROM users WHERE email = ?',
        [user.email]
      );
      await mysqlConnection.end();
      console.log('User deleted from both databases');
    } catch (mysqlError) {
      console.warn('MySQL delete failed:', mysqlError.message);
    }

    res.json({ 
      message: 'User deleted successfully', 
      deleted_user: user 
    });
  } catch (error) {
    console.error('Error deleting user:', error);
    res.status(500).json({ error: 'Failed to delete user' });
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
      console.warn('MySQL stats failed:', mysqlError.message);
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

// Bulk operations for testing
app.post('/api/users/bulk', async (req, res) => {
  const { users } = req.body;
  
  if (!users || !Array.isArray(users)) {
    return res.status(400).json({ error: 'Users array is required' });
  }

  try {
    const results = [];
    for (const user of users) {
      if (user.name && user.email) {
        const result = await pgPool.query(
          'INSERT INTO users (name, email) VALUES ($1, $2) RETURNING *',
          [user.name, user.email]
        );
        results.push(result.rows[0]);
        
        // Also insert into MySQL
        try {
          const mysqlConnection = await mysql.createConnection(mysqlConfig);
          await mysqlConnection.execute(
            'INSERT INTO users (name, email) VALUES (?, ?)',
            [user.name, user.email]
          );
          await mysqlConnection.end();
        } catch (mysqlError) {
          console.warn('MySQL bulk insert failed for user:', user.email);
        }
      }
    }
    
    res.status(201).json({
      message: `${results.length} users added successfully`,
      users: results
    });
  } catch (error) {
    console.error('Error in bulk user creation:', error);
    res.status(500).json({ error: 'Failed to create users in bulk' });
  }
});

// Root endpoint
app.get('/', (req, res) => {
  res.json({
    message: 'Kamran Demo API Server',
    version: '1.0.1',
    endpoints: [
      'GET /health - Health check',
      'GET /api/users - Get all users',
      'POST /api/users - Add new user',
      'DELETE /api/users/:id - Delete user',
      'POST /api/users/bulk - Add multiple users',
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
      console.log(`❌ Delete API: http://localhost:${PORT}/api/users/:id`);
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