// controllers/authController.js
const bcrypt = require('bcryptjs');
const mysql = require('mysql2');
const jwt = require('jsonwebtoken');


const db = mysql.createConnection({
  host: 'localhost',
  user: 'Alansi77',
  password: 'root',
  database: 'ezlab_database'
});

const JWT_SECRET = process.env.JWT_SECRET || 'your_super_secret_jwt_key';

exports.register = (req, res) => {
  console.log('Registration attempt:', req.body);
  const { username, password } = req.body;  

  if (!username || !password) {
    return res.status(400).json({ message: 'Username and password required' });
  }

  bcrypt.hash(password, 10, (err, hashedPassword) => {
    if (err) {
      console.error('Error hashing password:', err);
      return res.status(500).json({ message: 'Error hashing password' });
    }

    // When registering, isLoggedIn defaults to 0 (false)
    db.query(
      'INSERT INTO users (username, password, role, isActive, lastLoginAt, isLoggedIn) VALUES (?, ?, ?, ?, NOW(), 0)', // Added isLoggedIn
      [username, hashedPassword, 'user', true],
      (err, result) => {
        if (err) {
          console.error('Error creating user:', err);
          if (err.code === 'ER_DUP_ENTRY') {
              return res.status(409).json({ message: 'Username already exists' });
          }
          return res.status(500).json({ message: 'Error creating user' });
        }

        res.status(200).json({ message: 'User created successfully' });
      }
    );
  });
};

exports.login = (req, res) => {
  const { username, password } = req.body;
  console.log(`Login attempt for username: ${username}`);

  db.query('SELECT id, username, password, role, isActive, lastLoginAt, isLoggedIn FROM users WHERE username = ?', [username], (err, results) => {
    if (err) {
      console.error('Login DB error:', err);
      return res.status(500).send('Database error during login');
    }
    if (results.length === 0) {
      console.log(`Login failed: User ${username} not found.`);
      return res.status(401).send('Invalid credentials');
    }

    const user = results[0];
    console.log(`User found: ${user.username}, isActive: ${user.isActive}, isLoggedIn: ${user.isLoggedIn}`);

    if (user.isActive !== 1) {
      console.log(`Login failed: Account ${user.username} is blocked.`);
      return res.status(403).json({ message: 'Your account is blocked. Please contact admin.' });
    }

    // --- NEW LOGIC: Check isLoggedIn flag ---
    if (user.isLoggedIn === 1) { // If isLoggedIn is 1, a session is active
        console.log(`Login blocked for ${user.username}: Account is already logged in elsewhere.`);
        return res.status(409).json({ message: 'This account is currently active on another device. Please log out from that device first.' });
    }
    // --- END NEW LOGIC ---

    bcrypt.compare(password, user.password, (err, isMatch) => {
      if (err) {
        console.error('Error comparing password:', err);
        return res.status(500).send('Error checking password');
      }
      if (!isMatch) {
        console.log(`Login failed: Invalid password for user ${user.username}.`);
        return res.status(401).send('Invalid credentials');
      }

      const newLoginTime = new Date();
      console.log(`Attempting to update lastLoginAt and isLoggedIn for user ${user.username}.`);

      db.query(
        'UPDATE users SET lastLoginAt = ?, isLoggedIn = 1 WHERE id = ?', // Set isLoggedIn to 1
        [newLoginTime, user.id],
        (updateErr, updateResult) => {
          if (updateErr) {
            console.error('Error updating lastLoginAt and isLoggedIn:', updateErr);
            return res.status(500).send('Error updating login status');
          }
          console.log(`lastLoginAt updated and isLoggedIn set to 1 for user ${user.username}. Affected rows: ${updateResult.affectedRows}`);

          const token = jwt.sign(
            {
              id: user.id,
              role: user.role,
              lastLoginAt: newLoginTime.toISOString() // Keep lastLoginAt in token for old token invalidation
            },
            JWT_SECRET,
            { expiresIn: '7d' }
          );
          console.log(`New token generated. lastLoginAt in token payload: ${newLoginTime.toISOString()}`);

          res.status(200).json({
            message: 'Login successful',
            token,
            user: { 
              id: user.id,
              username: user.username, 
              role: user.role,
              isActive: user.isActive // Still useful for frontend to know
            }
          });
        }
      );
    });
  });
};

exports.logout = (req, res) => {
    // req.user is populated by authMiddleware
    const userId = req.user.id;
    console.log(`Logout attempt for user ID: ${userId}`);

    db.query(
        'UPDATE users SET isLoggedIn = 0 WHERE id = ?',
        [userId],
        (err, result) => {
            if (err) {
                console.error('Logout error: Failed to reset isLoggedIn for user:', userId, err);
                return res.status(500).json({ message: 'Error logging out' });
            }
            console.log(`User ${userId} logged out. isLoggedIn set to 0.`);
            res.status(200).json({ message: 'Logged out successfully' });
        }
    );
};

