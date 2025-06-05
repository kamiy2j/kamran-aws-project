import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './App.css';

function App() {
  const [users, setUsers] = useState([]);
  const [newUser, setNewUser] = useState({ name: '', email: '' });
  const [loading, setLoading] = useState(false);

  const API_URL = process.env.REACT_APP_API_URL || '';

  useEffect(() => {
    fetchUsers();
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

  const addUser = async (e) => {
    e.preventDefault();
    try {
      setLoading(true);
      await axios.post(`${API_URL}/api/users`, newUser);
      setNewUser({ name: '', email: '' });
      fetchUsers();
    } catch (error) {
      console.error('Error adding user:', error);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="App">
      <header className="App-header">
        <h1>Kamran Demo Application</h1>
        <p>Full-Stack Application with Auto Scaling, Load Balancer & RDS</p>
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
          </form>
        </section>

        <section className="user-list">
          <h2>Users ({users.length})</h2>
          {loading ? (
            <p>Loading...</p>
          ) : (
            <div className="users-grid">
              {users.map((user) => (
                <div key={user.id} className="user-card">
                  <h3>{user.name}</h3>
                  <p>{user.email}</p>
                  <small>Added: {new Date(user.created_at).toLocaleDateString()}</small>
                </div>
              ))}
            </div>
          )}
        </section>

        <section className="stats">
          <h2>Infrastructure Status</h2>
          <div className="stats-grid">
            <div className="stat-card">
              <h3>Auto Scaling</h3>
              <p>✅ Active</p>
            </div>
            <div className="stat-card">
              <h3>Load Balancer</h3>
              <p>✅ Healthy</p>
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
      </main>
    </div>
  );
}

export default App;