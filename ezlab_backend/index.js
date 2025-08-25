// ezlab_backend/index.js
const express = require('express');
const dotenv = require('dotenv');
const cors = require('cors');

// Load environment variables from .env file
dotenv.config();

// Get IP_ADDRESS from environment variables, default to a common local IP
const IP_ADDRESS = process.env.IP_ADDRESS || '192.168.1.114';

// Initialize the Express app
const app = express();

// --- Body Parsers (using Express's built-in ones) ---
app.use(express.json()); // This middleware parses JSON request bodies
app.use(express.urlencoded({ extended: true })); // For parsing application/x-www-form-urlencoded

// --- CORS Configuration ---
app.use(cors({
  origin: '*', // Allows all origins. For production, specify your frontend URLs.
  methods: ['GET', 'POST', 'DELETE', 'PUT', 'PATCH', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
  credentials: true
}));

// ⭐ NEW: Serve static files from the 'uploads' directory
// This makes files in 'uploads/images' (or any other subfolder of 'uploads')
// accessible via a URL like: http://YOUR_IP:PORT/uploads/images/YOUR_IMAGE_NAME.jpg
app.use('/uploads', express.static('uploads')); // 

// --- Database Connection ---
const db = require('./config/db');

// Test the database connection (optional, but good for debugging startup)
db.query('SELECT 1 + 1 AS solution', (err, results) => {
  if (err) {
    console.error('Database test query failed:', err);
    process.exit(1); // Exit if DB connection test fails critically
  }
  console.log('Database test query result:', results[0].solution);
});

// Connect to MySQL
db.connect(err => {
  if (err) {
    console.error('Error connecting to the database:', err);
    process.exit(1); // Exit the process if connection fails
  }
  console.log('Connected to the MySQL database');
});

// --- Import your Routes ---
const authRoutes = require('./routes/authRoutes');
const productRoutes = require('./routes/productRoutes');
const userRoutes = require('./routes/userRoutes');
const orderRoutes = require('./routes/orderRoutes');
const cartRoutes = require('./routes/cartRoutes');

// --- Use your Routes ---
// API endpoints for different functionalities
app.use('/auth', authRoutes);
app.use('/api/products', productRoutes);
app.use('/api/users', userRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/cart', cartRoutes);

// Basic root route
app.get('/', (req, res) => {
  res.send('Welcome to Ezlab CRM Backend!');
});

// --- Error Handling ---
// Generic 404 handler for unmatched routes
app.use((req, res, next) => {
  res.status(404).send("Sorry, can't find that API endpoint!");
});

// Global error handling middleware (must have 4 arguments)
app.use((err, req, res, next) => {
  console.error('Unhandled Server Error:', err.stack);
  res.status(500).send('Something broke on the server! Please check logs.');
});

// --- Starting the server ---
const PORT = process.env.PORT || 5050;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`Server is running at http://${IP_ADDRESS}:${PORT}`);
  console.log(`Access the backend at http://localhost:${PORT}`);
});