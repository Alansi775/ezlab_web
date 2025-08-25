// ezlab_backend/middleware/authMiddleware.js
const jwt = require('jsonwebtoken');
const mysql = require('mysql2'); 

// Ensure this connection matches your config/db.js if possible,
// or just make sure it's correct for authMiddleware's specific use.
const db = mysql.createConnection({
  host: 'localhost',
  user: 'Alansi77',
  password: 'Alansi77@',
  database: 'myproject'
});

const JWT_SECRET = process.env.JWT_SECRET || 'your_super_secret_jwt_key';

// Define the authenticateToken middleware function
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers.authorization;
  const token = authHeader?.split(' ')[1]; // Using optional chaining for safety
  console.log('Auth Middleware: Received token:', token ? 'Token received' : 'No token');

  if (!token) {
    console.log('Auth Middleware: No token provided');
    return res.status(401).json({ message: 'Authentication required' });
  } 

  try {
    const decoded = jwt.verify(token, JWT_SECRET);
    console.log('Auth Middleware: Decoded token:', decoded); 
    req.user = decoded; // Attach decoded user info (id, role, lastLoginAt from token) to the request

    // Perform DB lookup to verify user status and lastLoginAt
    db.query('SELECT lastLoginAt, isLoggedIn FROM users WHERE id = ?', [decoded.id], (err, results) => {
      if (err) {
        console.error('Auth Middleware: DB error during user lookup:', err);
        return res.status(500).json({ message: 'Database error during authentication check' });
      }

      if (results.length === 0) {
        console.log(`Auth Middleware: User with ID ${decoded.id} not found in DB`);
        return res.status(401).json({ message: 'User not found' });
      }

      const userInDb = results[0];

      // Convert DB's lastLoginAt and token's lastLoginAt to a comparable format (milliseconds)
      const tokenLastLoginTime = new Date(decoded.lastLoginAt).getTime();
      const dbLastLoginTime = new Date(userInDb.lastLoginAt).getTime();

      console.log(`Auth Middleware: Token lastLoginAt: ${new Date(decoded.lastLoginAt).toISOString()}`);
      console.log(`Auth Middleware: DB lastLoginAt: ${new Date(userInDb.lastLoginAt).toISOString()}`);

      // If the token's lastLoginAt is significantly older than the one in the DB,
      // it means a newer login has occurred. This token is now invalid for single-session enforcement.
      if (tokenLastLoginTime < dbLastLoginTime - 1000) { // Add a small buffer for time discrepancies.
        console.warn(`Auth Middleware: User ${decoded.id} tried to use an old token (new login detected).`);
        return res.status(401).json({ message: 'Your session has expired. A newer login was detected.' });
      }

      console.log('Auth Middleware: Token and session are valid for general access.');
      next(); // Proceed to the next middleware or route handler
    });

  } catch (err) {
    console.error('Auth Middleware: Token verification failed:', err);
    if (err.name === 'TokenExpiredError') {
      return res.status(401).json({ message: 'Token expired. Please log in again.' });
    }
    res.status(401).json({ message: 'Invalid Token' });
  }
};

// Export the function as a named property
module.exports = {
  authenticateToken
};