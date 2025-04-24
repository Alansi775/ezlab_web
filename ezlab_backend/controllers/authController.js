
const bcrypt = require('bcryptjs');
const mysql = require('mysql2');
const jwt = require('jsonwebtoken');

// MySQL connection
const db = mysql.createConnection({
  host: 'localhost',
  user: 'Alansi77',
  password: 'Alansi77@',
  database: 'myproject'  // Replace with your real DB name
});

exports.register = (req, res) => {
  console.log('Registration attempt:', req.body);
  const { username, password } = req.body;

  // ✅ Add this check at the top
  if (!username || !password) {
    return res.status(400).json({ message: 'Username and password required' });
  }

  bcrypt.hash(password, 10, (err, hashedPassword) => {
    if (err) {
      return res.status(500).json({ message: 'Error hashing password' });
    }

    db.query(
      'INSERT INTO users (username, password, role) VALUES (?, ?, ?)',
      [username, hashedPassword, 'user'],
      (err, result) => {
        if (err) {
          return res.status(500).json({ message: 'Error creating user' });
        }

        res.status(200).json({ message: 'User created successfully' });
      }
    );
  });
};;

exports.login = (req, res) => {
  const { username, password } = req.body;

  db.query('SELECT * FROM users WHERE username = ?', [username], (err, results) => {
    if (err) return res.status(500).send('DB error');
    if (results.length === 0) return res.status(401).send('Invalid credentials');

    const user = results[0];

    bcrypt.compare(password, user.password, (err, isMatch) => {
      if (err) return res.status(500).send('Error checking password');
      if (!isMatch) return res.status(401).send('Invalid credentials');

      const token = jwt.sign({ id: user.id, role: user.role }, 'secret_key', { expiresIn: '1h' });

      res.status(200).json({
        message: 'Login successful',
        token,
        user: { id: user.id, username: user.username, role: user.role }
      });
    });
  });
};
// const bcrypt = require('bcryptjs');
// const mysql = require('mysql2');
// const jwt = require('jsonwebtoken');

// // MySQL connection
// const db = mysql.createConnection({
//   host: 'localhost',
//   user: 'Alansi77',
//   password: 'Alansi77@',
//   database: 'myproject'  // Replace with your real DB name
// });

// exports.login = (req, res) => {
//   const { username, password } = req.body;

//   db.query('SELECT * FROM users WHERE username = ?', [username], (err, results) => {
//     if (err) return res.status(500).send('DB error');
//     if (results.length === 0) return res.status(401).send('Invalid credentials');

//     const user = results[0];

//     bcrypt.compare(password, user.password, (err, isMatch) => {
//       if (err) return res.status(500).send('Error checking password');
//       if (!isMatch) return res.status(401).send('Invalid credentials');

//       const token = jwt.sign({ id: user.id, role: user.role }, 'secret_key', { expiresIn: '1h' });

//       res.status(200).json({
//         message: 'Login successful',
//         token,
//         user: { id: user.id, username: user.username, role: user.role }
//       });
//     });
//   });
// };
