// middleware/adminAuth.js
module.exports = (req, res, next) => {
    // This assumes req.user is populated by a preceding auth middleware
    if (req.user && (req.user.role === 'admin' || req.user.role === 'super_admin')) {
        next(); // User is admin or super_admin, proceed
    } else {
        res.status(403).json({ message: 'Access denied: Requires Admin or Super Admin role' });
    }
};