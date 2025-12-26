// ezlab_backend/routes/productRoutes.js
const express = require('express');
const router = express.Router();
const productController = require('../controllers/productController');

// Get all products
router.get('/', productController.getAllProducts);

// Add new product
router.post('/', productController.addProduct);

// Delete product
router.delete('/:id', productController.deleteProduct);

module.exports = router;