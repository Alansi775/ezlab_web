// ezlab_backend/routes/cartRoutes.js جديد
const express = require('express');
const router = express.Router();
const cartController = require('../controllers/cartController');
const authMiddleware = require('../middleware/authMiddleware'); // For authentication

// All cart routes require authentication
router.use(authMiddleware.authenticateToken);

// Get user's cart
router.get('/', cartController.getCart);

// Add product to cart (or update quantity if exists)
router.post('/add', cartController.addItemToCart);

// Update quantity of a specific item in the cart
router.put('/update/:itemId', cartController.updateCartItemQuantity);

// Remove a specific item from the cart
router.delete('/remove/:itemId', cartController.removeItemFromCart);

// Clear the entire cart for the user
router.delete('/clear', cartController.clearCart);

module.exports = router;