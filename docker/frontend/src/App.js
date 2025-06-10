import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';

function App() {
  const [users, setUsers] = useState([]);
  const [newUser, setNewUser] = useState({ name: '', email: '' });
  const [loading, setLoading] = useState(false);
  const [stats, setStats] = useState(null);
  const [deleteLoading, setDeleteLoading] = useState({});

  const API_URL = process.env.REACT_APP_API_URL || '';

  useEffect(() => {
    fetchUsers();
    fetchStats();
    
    // Auto-refresh every 30 seconds to show real-time updates
    const interval = setInterval(() => {
      fetchUsers();
      fetchStats();
    }, 30000);

    return () => clearInterval(interval);
  }, []);

  const fetchUsers = async () => {
    try {
      setLoading(true);
      const response = await axios.get(`${API_URL}/api/users`);
      setUsers(response.data);
    } catch (error) {
      console.error('Error fetching users:', error);
    } finally {
      setLoading(false);
    }
  };

  const fetchStats = async () => {
    try {
      const response = await axios.get(`${API_URL}/api/stats`);
      setStats(response.data);
    } catch (error) {
      console.error('Error fetching stats:', error);
    }
  };

  const addUser = async (e) => {
    e.preventDefault();
    try {
      setLoading(true);
      await axios.post(`${API_URL}/api/users`, newUser);
      setNewUser({ name: '', email: '' });
      await fetchUsers();
      await fetchStats();
    } catch (error) {
      console.error('Error adding user:', error);
      alert('Error adding user. Please check if email already exists.');
    } finally {
      setLoading(false);
    }
  };

  const deleteUser = async (userId, userName) => {
    if (!window.confirm(`Are you sure you want to delete ${userName}?`)) {
      return;
    }

    try {
      setDeleteLoading(prev => ({ ...prev, [userId]: true }));
      await axios.delete(`${API_URL}/api/users/${userId}`);
      await fetchUsers();
      await fetchStats();
    } catch (error) {
      console.error('Error deleting user:', error);
      alert('Error deleting user. Please try again.');
    } finally {
      setDeleteLoading(prev => ({ ...prev, [userId]: false }));
    }
  };

  const addSampleUsers = async () => {
    const sampleUsers = [
      { name: 'Alice Johnson', email: `alice.${Date.now()}@example.com` },
      { name: 'Bob Smith', email: `bob.${Date.now()}@example.com` },
      { name: 'Carol Davis', email: `carol.${Date.now()}@example.com` }
    ];

    try {
      setLoading(true);
      await axios.post(`${API_URL}/api/users/bulk`, { users: sampleUsers });
      await fetchUsers();
      await fetchStats();
    } catch (error) {
      console.error('Error adding sample users:', error);
      alert('Error adding sample users.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>Kamran Demo Application</h1>
        <p>Full-Stack Application with Auto Scaling, Load Balancer & RDS</p>
        <p>Real-time updates every 30 seconds</p>
      </header>

      <main className="App-main">
        <section className="user-form">
          <h2>Add New User</h2>
          <form onSubmit={addUser}>
            <input
              type="text"
              placeholder="Name"
              value={newUser.name}
              onChange={(e) => setNewUser({...newUser, name: e.target.value})}
              required
            />
            <input
              type="email"
              placeholder="Email"
              value={newUser.email}
              onChange={(e) => setNewUser({...newUser, email: e.target.value})}
              required
            />
            <button type="submit" disabled={loading}>
              {loading ? 'Adding...' : 'Add User'}
            </button>
            <button 
              type="button" 
              onClick={addSampleUsers} 
              disabled={loading}
              className="sample-btn"
            >
              Add Sample Users
            </button>
          </form>
        </section>

        <section className="user-list">
          <div className="user-list-header">
            <h2>Users ({users.length})</h2>
            <button onClick={fetchUsers} disabled={loading} className="refresh-btn">
              {loading ? 'Refreshing...' : 'Refresh'}
            </button>
          </div>
          
          {loading ? (
            <p>Loading...</p>
          ) : (
            <div className="users-grid">
              {users.map((user) => (
                <div key={user.id} className="user-card">
                  <div className="user-info">
                    <h3>{user.name}</h3>
                    <p>{user.email}</p>
                    <small>Added: {new Date(user.created_at).toLocaleDateString()}</small>
                  </div>
                  <div className="user-actions">
                    <button 
                      onClick={() => deleteUser(user.id, user.name)}
                      disabled={deleteLoading[user.id]}
                      className="delete-btn"
                    >
                      {deleteLoading[user.id] ? 'Deleting...' : '🗑️ Delete'}
                    </button>
                  </div>
                </div>
              ))}
              {users.length === 0 && (
                <div className="no-users">
                  <p>No users found. Add some users to get started!</p>
                </div>
              )}
            </div>
          )}
        </section>

        <section className="stats">
          <h2>Database Statistics</h2>
          {stats ? (
            <div className="stats-grid">
              <div className="stat-card">
                <h3>PostgreSQL Users</h3>
                <p>{stats.postgresql_users}</p>
              </div>
              <div className="stat-card">
                <h3>MySQL Users</h3>
                <p>{stats.mysql_users}</p>
              </div>
              <div className="stat-card">
                <h3>Server Uptime</h3>
                <p>{Math.floor(stats.server_uptime / 60)} minutes</p>
              </div>
              <div className="stat-card">
                <h3>Last Updated</h3>
                <p>{new Date(stats.last_updated).toLocaleTimeString()}</p>
              </div>
            </div>
          ) : (
            <p>Loading stats...</p>
          )}
        </section>

        <section className="stats">
          <h2>Infrastructure Status</h2>
          <div className="stats-grid">
            <div className="stat-card">
              <h3>Auto Scaling</h3>
              <p>1</p>
            </div>
            <div className="stat-card">s
              <h3>Load Balancer</h3>
              <p>2</p>
            </div>
            <div className="stat-card">
              <h3>RDS Database</h3>
              <p>✅ Connected</p>
            </div>
            <div className="stat-card">
              <h3>SSL/HTTPS</h3>
              <p>✅ Secured</p>
            </div>
          </div>
        </section>

        <section className="dashboard-info">
          <h2>BI Dashboard</h2>
          <p>
            Visit your Metabase dashboard at:  
            <a href="https://bi.kamranshahid.com" target="_blank" rel="noopener noreferrer">
              https://bi.kamranshahid.com
            </a>
          </p>
          <p>
            <strong>Login:</strong> kamiy2j@gmail.com / Password123!
          </p>
        </section>
      </main>
    </div>
  );
}

export default App;