// ezlab_backend/routes/authRoutes.js
const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');
const authMiddleware = require('../middleware/authMiddleware'); // Import the module

// Handle login logic
router.post('/login', authController.login);
router.post('/register', authController.register);

// For logout, use the named authenticateToken middleware
router.post('/logout', authMiddleware.authenticateToken, authController.logout);

module.exports = router;