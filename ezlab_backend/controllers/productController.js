// Fix the addProduct method (remove duplicate exports and fix fields)
//const db = require('../index');
const db = require('../config/db');

module.exports = {
  getAllProducts: (req, res) => {
    db.query('SELECT * FROM products', (err, results) => {
      if (err) return res.status(500).json({ message: 'Error fetching products' });
      res.status(200).json(results);
    });
  },

  addProduct: (req, res) => {
    console.log('Add product attempt:', req.body);
    const { name, description, price, quantity } = req.body;
    db.query(
      'INSERT INTO products (name, description, price, quantity) VALUES (?, ?, ?, ?)',
      [name, description, price, quantity],
      (err, result) => {
        if (err) return res.status(500).json({ message: 'Error adding product' });
        res.status(200).json({ message: 'Product added successfully' });
      }
    );
  },

  deleteProduct: (req, res) => {
    const { id } = req.params;
    db.query('DELETE FROM products WHERE id = ?', [id], (err, result) => {
      if (err) return res.status(500).json({ message: 'Error deleting product' });
      res.status(200).json({ message: 'Product deleted successfully' });
    });
  }
};