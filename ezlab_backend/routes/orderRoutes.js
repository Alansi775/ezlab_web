// ezlab_backend/routes/orderRoutes.js

const express = require('express');
const router = express.Router();
const orderController = require('../controllers/orderController');
const authMiddleware = require('../middleware/authMiddleware'); 

// All order routes will require authentication
router.use(authMiddleware.authenticateToken);

// Create a new draft order
router.post('/', orderController.createOrder); // POST /api/orders

// Get details of a specific order (with its items)
router.get('/:orderId', orderController.getOrderDetails); // GET /api/orders/:orderId

// Get all orders (for listing)
router.get('/', orderController.getAllOrders); // GET /api/orders

// Add item to an existing order (or update quantity if it exists)
router.post('/:orderId/items', orderController.addItemToOrder); // POST /api/orders/:orderId/items

// Update quantity of an item in an order
router.put('/:orderId/items/:itemId', orderController.updateOrderItemQuantity); // PUT /api/orders/:orderId/items/:itemId

// Remove item from an order
router.delete('/:orderId/items/:itemId', orderController.removeItemFromOrder); // DELETE /api/orders/:orderId/items/:itemId

//  ADD THIS ROUTE FOR DELETING THE WHOLE ORDER 
router.delete('/:orderId', orderController.deleteOrder); // DELETE /api/orders/:orderId

// Update the status of an order using PATCH
router.patch('/:orderId', orderController.updateOrderStatus); // PATCH /api/orders/:orderId

module.exports = router;