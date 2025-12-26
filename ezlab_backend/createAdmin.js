const bcrypt = require('bcryptjs');
const mysql = require('mysql2');

const db = mysql.createConnection({
  host: 'localhost',
  user: 'Alansi77',
  password: 'root',
  database: 'ezlab_database'
}); 

const username = 'Admin';
const password = '1234';
const role = 'admin';

bcrypt.hash(password, 10, (err, hashedPassword) => {
  if (err) throw err;

  db.query(
    'INSERT INTO users (username, password, role) VALUES (?, ?, ?)',
    [username, hashedPassword, role],
    (err, result) => {
      if (err) throw err;
      console.log('✅ Admin user inserted');
      db.end();
    }
  );
});
