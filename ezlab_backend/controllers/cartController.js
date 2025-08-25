// ezlab_backend/controllers/cartController.js
const db = require('../config/db');

module.exports = {
  // --- Get User's Cart (and create if not exists) ---
  getCart: (req, res) => {
    const userId = req.user.id; // User ID from authenticated token
    db.query('SELECT c.id AS cart_id FROM carts c WHERE c.user_id = ?', [userId], (err, cartResults) => {
      if (err) {
        console.error('Error fetching cart for user:', err);
        return res.status(500).json({ message: 'Error fetching cart.' });
      }

      let cartId;
      if (cartResults.length > 0) {
        cartId = cartResults[0].cart_id;
        // Fetch cart items
        db.query(
          `SELECT
            ci.id AS item_id,
            p.id AS product_id,
            p.name AS product_name,
            p.description AS product_description,
            p.quantity AS product_stock, -- Current stock from products table
            ci.quantity AS cart_quantity, -- Quantity in the cart
            ci.price_at_add,
            -- ⭐ MODIFIED: Join with product_images and GROUP_CONCAT to get all image paths
            GROUP_CONCAT(pi.image_path ORDER BY pi.id ASC) AS imageUrls
           FROM cart_items ci
           JOIN products p ON ci.product_id = p.id
           LEFT JOIN product_images pi ON p.id = pi.product_id -- ⭐ NEW JOIN
           WHERE ci.cart_id = ?
           GROUP BY ci.id, p.id, p.name, p.description, p.quantity, ci.quantity, ci.price_at_add`, // ⭐ NEW GROUP BY
          [cartId],
          (err, items) => {
            if (err) {
              console.error('Error fetching cart items:', err);
              return res.status(500).json({ message: 'Error fetching cart items.' });
            }

            const processedItems = items.map(item => {
                let fullImageUrls = [];
                if (item.imageUrls) {
                    // Split the comma-separated string back into an array of image paths
                    // Note: In productController.js, the full URL is constructed here.
                    // We need to do the same if imageUrls from DB are relative.
                    fullImageUrls = item.imageUrls.split(',').map(imgPath => {
                        // Ensure imgPath is trimmed to remove any extra spaces
                        const cleanedPath = imgPath.trim();
                        // Construct full URLs for each image (assuming req.protocol and req.get('host') are available)
                        // If not, use fixed baseUrl from constants.dart in Flutter (preferred).
                        // For backend response, it's better to send full URLs if possible.
                        // However, since Flutter expects relative paths to be combined with baseUrl,
                        // let's stick to sending only the relative path here unless it's full.

                        // ⭐ Determine if the path is already a full URL or needs baseUrl prepended
                        if (cleanedPath.startsWith('http://') || cleanedPath.startsWith('https://')) {
                            return cleanedPath; // It's already a full URL
                        } else {
                            // It's a relative path, prepend server details
                            // This part is for the backend response only.
                            // The Flutter app will handle baseUrl concatenation.
                            // So, we can just return the cleanedPath if it's already relative.
                            // If you want full URLs from backend, you'd need req.protocol and req.get('host')
                            // which are not available outside the main request handler context directly.
                            // For simplicity, let's return the relative path. Flutter will add baseUrl.
                            return cleanedPath;
                        }
                    });
                }
                // Return product object with an array of image URLs
                return { ...item, imageUrls: fullImageUrls };
            });

            res.status(200).json({ cartId, items: processedItems });
          }
        );
      } else {
        // No cart found, create one
        db.query('INSERT INTO carts (user_id) VALUES (?)', [userId], (err, result) => {
          if (err) {
            console.error('Error creating new cart:', err);
            return res.status(500).json({ message: 'Error creating cart.' });
          }
          cartId = result.insertId;
          res.status(200).json({ cartId, items: [] }); // Return empty cart
        });
      }
    });
  },

  // ... rest of your code (addItemToCart, updateCartItemQuantity, removeItemFromCart, clearCart) remains unchanged
  // This part of the file is lengthy, so it's omitted for brevity. Make sure to keep it.
  addItemToCart: (req, res) => {
    const userId = req.user.id;
    const { productId, quantity = 1 } = req.body;

    if (!productId || quantity <= 0) {
      return res.status(400).json({ message: 'Product ID and a valid quantity are required.' });
    }

    db.beginTransaction(err => {
      if (err) return res.status(500).json({ message: 'Failed to start transaction.' });

      db.query('SELECT id FROM carts WHERE user_id = ?', [userId], (err, cartResults) => {
        if (err) return db.rollback(() => res.status(500).json({ message: 'Error finding user cart.' }));

        let cartId;
        if (cartResults.length > 0) {
          cartId = cartResults[0].id;
          continueAddItem(cartId);
        } else {
          db.query('INSERT INTO carts (user_id) VALUES (?)', [userId], (err, result) => {
            if (err) return db.rollback(() => res.status(500).json({ message: 'Error creating new cart.' }));
            cartId = result.insertId;
            continueAddItem(cartId);
          });
        }
      });

      function continueAddItem(cartId) {
        db.query('SELECT name, price, quantity FROM products WHERE id = ?', [productId], (err, productResults) => {
          if (err) return db.rollback(() => res.status(500).json({ message: 'Error fetching product details.' }));
          if (productResults.length === 0) return db.rollback(() => res.status(404).json({ message: 'Product not found.' }));

          const product = productResults[0];
          const priceAtAdd = product.price;

          db.query('SELECT id, quantity FROM cart_items WHERE cart_id = ? AND product_id = ?', [cartId, productId], (err, itemResults) => {
            if (err) return db.rollback(() => res.status(500).json({ message: 'Error checking cart item.' }));

            let sql;
            let params;
            let currentCartQuantity = 0;

            if (itemResults.length > 0) {
              const existingItem = itemResults[0];
              currentCartQuantity = existingItem.quantity;
              const newTotalQuantity = currentCartQuantity + quantity;

              if (newTotalQuantity > product.quantity) {
                return db.rollback(() => res.status(400).json({
                  message: `Cannot add more ${product.name}. Only ${product.quantity} in stock, ${currentCartQuantity} already in cart.`
                }));
              }

              sql = 'UPDATE cart_items SET quantity = ?, price_at_add = ? WHERE id = ?';
              params = [newTotalQuantity, priceAtAdd, existingItem.id];
            } else {
              if (quantity > product.quantity) {
                return db.rollback(() => res.status(400).json({
                  message: `Cannot add ${product.name}. Only ${product.quantity} in stock.`
                }));
              }
              sql = 'INSERT INTO cart_items (cart_id, product_id, quantity, price_at_add) VALUES (?, ?, ?, ?)';
              params = [cartId, productId, quantity, priceAtAdd];
            }

            db.query(sql, params, (err) => {
              if (err) return db.rollback(() => res.status(500).json({ message: 'Error adding/updating cart item.' }));

              db.commit(err => {
                if (err) return db.rollback(() => res.status(500).json({ message: 'Transaction failed.' }));
                res.status(200).json({ message: 'Product added/updated in cart successfully.' });
              });
            });
          });
        });
      }
    });
  },

  updateCartItemQuantity: (req, res) => {
    const userId = req.user.id;
    const { itemId } = req.params;
    const { quantity } = req.body;

    if (quantity === undefined || quantity < 0) {
      return res.status(400).json({ message: 'Valid quantity is required (0 to remove).' });
    }

    db.beginTransaction(err => {
      if (err) return res.status(500).json({ message: 'Failed to start transaction.' });

      db.query(
        'SELECT ci.id, ci.product_id, ci.quantity AS cart_quantity, p.quantity AS product_stock FROM cart_items ci JOIN products p ON ci.product_id = p.id JOIN carts c ON ci.cart_id = c.id WHERE ci.id = ? AND c.user_id = ?',
        [itemId, userId],
        (err, results) => {
          if (err) return db.rollback(() => res.status(500).json({ message: 'Error fetching cart item details.' }));
          if (results.length === 0) return db.rollback(() => res.status(404).json({ message: 'Cart item not found or does not belong to user.' }));

          const { product_id, cart_quantity, product_stock } = results[0];

          if (quantity === 0) {
            db.query('DELETE FROM cart_items WHERE id = ?', [itemId], (err) => {
              if (err) return db.rollback(() => res.status(500).json({ message: 'Error removing item from cart.' }));
              db.commit(err => {
                if (err) return db.rollback(() => res.status(500).json({ message: 'Transaction failed.' }));
                res.status(200).json({ message: 'Item removed from cart.' });
              });
            });
          } else {
            if (quantity > product_stock) {
              return db.rollback(() => res.status(400).json({ message: `Desired quantity (${quantity}) exceeds current product stock (${product_stock}).` }));
            }

            db.query(
              'UPDATE cart_items SET quantity = ? WHERE id = ?',
              [quantity, itemId],
              (err) => {
                if (err) return db.rollback(() => res.status(500).json({ message: 'Error updating cart item quantity.' }));
                db.commit(err => {
                  if (err) return db.rollback(() => res.status(500).json({ message: 'Transaction failed.' }));
                  res.status(200).json({ message: 'Cart item quantity updated.' });
                });
              }
            );
          }
        }
      );
    });
  },

  removeItemFromCart: (req, res) => {
    const userId = req.user.id;
    const { itemId } = req.params;

    db.query(
      'DELETE ci FROM cart_items ci JOIN carts c ON ci.cart_id = c.id WHERE ci.id = ? AND c.user_id = ?',
      [itemId, userId],
      (err, result) => {
        if (err) {
          console.error('Error removing item from cart:', err);
          return res.status(500).json({ message: 'Error removing item from cart.' });
        }
        if (result.affectedRows === 0) {
          return res.status(404).json({ message: 'Cart item not found or does not belong to user.' });
        }
        res.status(200).json({ message: 'Item removed from cart successfully.' });
      }
    );
  },

  clearCart: (req, res) => {
    const userId = req.user.id;
    db.query('DELETE ci FROM cart_items ci JOIN carts c ON ci.cart_id = c.id WHERE c.user_id = ?', [userId], (err, result) => {
      if (err) {
        console.error('Error clearing cart:', err);
        return res.status(500).json({ message: 'Error clearing cart.' });
      }
      res.status(200).json({ message: 'Cart cleared successfully.' });
    });
  }
};