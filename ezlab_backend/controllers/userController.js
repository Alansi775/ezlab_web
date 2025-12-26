const db = require('../config/db');

// Define the Super Admin username 
const SUPER_ADMIN_USERNAME = 'superadmin_ezlab'; 

module.exports = {
  getUsers: (req, res) => {
    db.query('SELECT id, username, role, isActive FROM users', (err, results) => {
      if (err){
        console.error('SQL Error:', err);
        return res.status(500).json({ message: 'Error fetching users' });
      }
      res.status(200).json(results);
    });
  },

  deleteUser: async (req, res) => {
    const userId = req.params.id;

    try {
      // First, get the user's details to check if they are the Super Admin
      const [userRows] = await db.promise().query('SELECT username FROM users WHERE id = ?', [userId]);

      if (userRows.length === 0) {
        return res.status(404).json({ message: 'User not found' });
      }

      if (userRows[0].username === SUPER_ADMIN_USERNAME) {
        return res.status(403).json({ message: 'Cannot delete the Super Admin user.' });
      }

      // Proceed with deletion if not Super Admin
      db.query('DELETE FROM users WHERE id = ?', [userId], (err, result) => {
        if (err) {
          console.error('SQL Error:', err);
          return res.status(500).json({ message: 'Error deleting user' });
        }
        res.status(200).json({ message: 'User deleted successfully' });
      });
    } catch (error) {
      console.error('Error in deleteUser:', error);
      res.status(500).json({ message: 'Internal server error during user deletion' });
    }
  },

  updateUserStatus: async (req, res) => {
    const userId = req.params.id;
    const { value } = req.body; // value should be 1 or 0

    try {
      // First, get the user's details to check if they are the Super Admin
      const [userRows] = await db.promise().query('SELECT username FROM users WHERE id = ?', [userId]);

      if (userRows.length === 0) {
        return res.status(404).json({ message: 'User not found' });
      }

      if (userRows[0].username === SUPER_ADMIN_USERNAME) {
        // Super Admin cannot be blocked
        if (value === 0) {
          return res.status(403).json({ message: 'Cannot block the Super Admin user.' });
        }
        // If someone tries to activate Super Admin (value = 1), it's fine, but effectively no-op as they are always active.
        // We can just let it proceed or add a message. For now, let it proceed to avoid over complication.
      }

      // Proceed with status update if not Super Admin or if trying to activate Super Admin
      db.query('UPDATE users SET isActive = ? WHERE id = ?', [value, userId], (err, result) => {
        if (err) {
          console.error('SQL Error:', err);
          return res.status(500).json({ message: 'Error updating user status' });
        }
        res.status(200).json({ message: 'User status updated successfully' });
      });
    } catch (error) {
      console.error('Error in updateUserStatus:', error);
      res.status(500).json({ message: 'Internal server error during user status update' });
    }
  },

  updateUserRole: async (req, res) => {
    const userId = req.params.id;
    const { value } = req.body; // value should be 'admin', 'user', or 'super_admin'

    try {
      // First, get the user's details to check if they are the Super Admin
      const [userRows] = await db.promise().query('SELECT username FROM users WHERE id = ?', [userId]);

      if (userRows.length === 0) {
        return res.status(404).json({ message: 'User not found' });
      }

      if (userRows[0].username === SUPER_ADMIN_USERNAME) {
        // Super Admin's role cannot be changed
        if (value !== 'super_admin') { // Only allow changing to 'super_admin' if it somehow got changed, effectively a no op
          return res.status(403).json({ message: 'Cannot change the role of the Super Admin user.' });
        }
        // If value is 'super_admin', just acknowledge, effectively no op
        return res.status(200).json({ message: 'Super Admin role cannot be changed.' });
      }

      // Prevent anyone from manually setting a role to 'super_admin' through this endpoint,
      // as 'super_admin' should only be the predefined one.
      if (value === 'super_admin') {
          return res.status(403).json({ message: 'Cannot assign "super_admin" role to other users.' });
      }

      // Proceed with role update if not Super Admin and not trying to assign 'super_admin' role
      db.query('UPDATE users SET role = ? WHERE id = ?', [value, userId], (err, result) => {
        if (err) {
          console.error('SQL Error:', err);
          return res.status(500).json({ message: 'Error updating user role' });
        }
        res.status(200).json({ message: 'User role updated successfully' });
      });
    } catch (error) {
      console.error('Error in updateUserRole:', error);
      res.status(500).json({ message: 'Internal server error during user role update' });
    }
  }
};