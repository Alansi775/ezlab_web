const express = require('express');
const mysql = require('mysql2');
const dotenv = require('dotenv');
const cors = require('cors');
const bodyParser = require('body-parser');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const authRoutes = require('./routes/authRoutes');
const productRoutes = require('./routes/productRoutes');

// Load environment variables
dotenv.config();

console.log(process.env.DB_HOST, process.env.DB_USER, process.env.DB_PASSWORD, process.env.DB_NAME);

// Initialize the app
const app = express();

// app.use(cors({
//  // origin: 'http://localhost:50935',
//   origin: 'http://192.168.1.108:5050',
//   credentials: true
// }));
app.use(cors({
  // origin: 'http://192.168.1.108:52761', // same IP and port as Flutter web
  //origin: ['http://192.168.1.108:5051', 'http://192.168.1.108:52761'],
  origin: '*',
  methods: ['GET', 'POST', 'DELETE', 'PUT'],
  credentials: true
}));
app.use(bodyParser.json());

const db = require('./config/db');

// // Database connection
// const db = mysql.createConnection({
//   host: process.env.DB_HOST,
//   user: process.env.DB_USER,
//   password: process.env.DB_PASSWORD,
//   database: process.env.DB_NAME
// });

// Test the database connection
db.query('SELECT 1 + 1 AS solution', (err, results) => {
  if (err) throw err;
  console.log('Database test query result:', results[0].solution);
});

// Connect to MySQL
db.connect(err => {
  if (err) {
    console.error('Error connecting to the database:', err);
    process.exit(1);
  }
  console.log('Connected to the MySQL database');
});

// Routes
// here we will define routes later here

// Should have:
app.use('/api/products', productRoutes);
app.use('/auth', authRoutes);

// Starting the server
const PORT = process.env.PORT || 5050;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server is running at http://192.168.1.108:${PORT}`);
});

// Using the routes
// app.use('/auth', authRoutes);
// app.use('/products', productRoutes);

