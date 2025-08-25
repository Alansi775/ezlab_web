// ezlab_backend/routes/userRoutes.js
const express = require('express');
const router = express.Router();
const userController = require('../controllers/userController');
const authMiddleware = require('../middleware/authMiddleware'); // authMiddleware is now an object { authenticateToken: fn }
const adminAuth = require('../middleware/adminAuth'); // Assuming this exports the middleware directly, like module.exports = (req,res,next)=>{...}

// GET /api/users - Only authenticated users can get users list
// Use authMiddleware.authenticateToken here
router.get('/', authMiddleware.authenticateToken, userController.getUsers);

// DELETE /api/users/:id - Requires authentication AND admin/super_admin role
// Use authMiddleware.authenticateToken here
router.delete('/:id', authMiddleware.authenticateToken, adminAuth, userController.deleteUser);

// PUT /api/users/:id/role - Requires authentication AND admin/super_admin role
// Use authMiddleware.authenticateToken here
router.put('/:id/role', authMiddleware.authenticateToken, adminAuth, userController.updateUserRole);

// PUT /api/users/:id/status - Requires authentication AND admin/super_admin role
// Use authMiddleware.authenticateToken here
router.put('/:id/status', authMiddleware.authenticateToken, adminAuth, userController.updateUserStatus);

module.exports = router;