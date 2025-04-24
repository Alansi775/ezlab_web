const express = require('express');
const router = express.Router();
const authController = require('../controllers/authController');

// Handle login logic
router.post('/login', authController.login);
router.post('/register', authController.register);

module.exports = router;
