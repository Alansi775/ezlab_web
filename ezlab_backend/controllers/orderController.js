// ezlab_backend/controllers/orderController.js
const db = require('../config/db');

module.exports = {
  // --- Create Order ---
  createOrder: (req, res) => {
    const employeeId = req.user.id;
    const { customerName, companyName, customerEmail, customerPhone, notes } = req.body;
    if (!customerName) return res.status(400).json({ message: 'Customer name is required.' });
    db.query(
      'INSERT INTO orders (user_id, customer_name, company_name, customer_email, customer_phone, notes, status) VALUES (?, ?, ?, ?, ?, ?, "Pending")',
      [employeeId, customerName, companyName || null, customerEmail || null, customerPhone || null, notes || null],
      (err, result) => {
        if (err) {
            console.error('Error creating order:', err);
            return res.status(500).json({ message: 'Error creating order.' });
        }
        res.status(201).json({ message: 'Order created.', orderId: result.insertId });
      }
    );
  },

  // --- Add Item to Order ---
  addItemToOrder: (req, res) => {
    const { orderId } = req.params;
    const { productId, quantity } = req.body;
    if (!productId || quantity == null || quantity <= 0) {
      return res.status(400).json({ message: 'Product ID and valid quantity required.' });
    }
    db.beginTransaction((err) => {
      if (err) return res.status(500).json({ message: 'Failed to start transaction.' });
      db.query('SELECT name, price, quantity FROM products WHERE id = ?', [productId], (err, productResults) => {
        if (err) return db.rollback(() => res.status(500).json({ message: 'Error fetching product.' }));
        if (productResults.length === 0) return db.rollback(() => res.status(404).json({ message: 'Product not found.' }));
        const product = productResults[0];
        if (product.quantity < quantity) {
          return db.rollback(() => res.status(400).json({ message: `Insufficient stock for ${product.name}.` }));
        }
        db.query('SELECT id, quantity FROM order_items WHERE order_id = ? AND product_id = ?', [orderId, productId], (err, itemResults) => {
          let sql, params, oldQuantity = 0;
          if (itemResults.length > 0) {
            oldQuantity = itemResults[0].quantity;
            sql = 'UPDATE order_items SET quantity = ? WHERE id = ?';
            params = [oldQuantity + quantity, itemResults[0].id];
          } else {
            sql = 'INSERT INTO order_items (order_id, product_id, quantity, price_at_order) VALUES (?, ?, ?, ?)';
            params = [orderId, productId, quantity, product.price];
          }
          db.query(sql, params, (err) => {
            if (err) return db.rollback(() => res.status(500).json({ message: 'Error updating order item.' }));
            db.query('UPDATE products SET quantity = quantity - ? WHERE id = ?', [quantity, productId], (err) => {
              if (err) return db.rollback(() => res.status(500).json({ message: 'Error updating product stock.' }));
              db.query('UPDATE orders SET total_amount = (SELECT SUM(oi.quantity * oi.price_at_order) FROM order_items oi WHERE oi.order_id = ?) WHERE id = ?', [orderId, orderId], (err) => {
                if (err) return db.rollback(() => res.status(500).json({ message: 'Error updating order total.' }));
                db.commit((err) => {
                  if (err) return db.rollback(() => res.status(500).json({ message: 'Transaction failed.' }));
                  res.status(200).json({ message: 'Product added/updated in order.' });
                });
              });
            });
          });
        });
      });
    });
  },

  // --- Update Quantity of an Item in an Order ---
  updateOrderItemQuantity: (req, res) => {
    const { orderId, itemId } = req.params;
    const { quantity } = req.body;
    if (quantity == null || quantity < 0) return res.status(400).json({ message: 'Valid quantity required.' });
    db.beginTransaction((err) => {
      if (err) return res.status(500).json({ message: 'Failed to start transaction.' });
      db.query('SELECT product_id, quantity FROM order_items WHERE id = ? AND order_id = ?', [itemId, orderId], (err, itemResults) => {
        if (err) return db.rollback(() => res.status(500).json({ message: 'Error fetching order item.' }));
        if (itemResults.length === 0) return db.rollback(() => res.status(404).json({ message: 'Order item not found.' }));
        const { product_id, quantity: oldQuantity } = itemResults[0];
        const diff = quantity - oldQuantity;
        if (diff > 0) {
          db.query('SELECT quantity FROM products WHERE id = ?', [product_id], (err, productResults) => {
            if (err) return db.rollback(() => res.status(500).json({ message: 'Error fetching product stock.' }));
            if (productResults.length === 0) return db.rollback(() => res.status(404).json({ message: 'Product not found.' }));
            if (productResults[0].quantity < diff) {
              return db.rollback(() => res.status(400).json({ message: `Insufficient stock. Only ${productResults[0].quantity} available.` }));
            }
            continueUpdate();
          });
        } else {
          continueUpdate();
        }
        function continueUpdate() {
          db.query('UPDATE order_items SET quantity = ? WHERE id = ?', [quantity, itemId], (err) => {
            if (err) return db.rollback(() => res.status(500).json({ message: 'Error updating order item quantity.' }));
            if (quantity === 0) {
              db.query('DELETE FROM order_items WHERE id = ?', [itemId], (err) => {
                if (err) return db.rollback(() => res.status(500).json({ message: 'Error removing item.' }));
                updateProductAndOrderTotals();
              });
            } else {
              updateProductAndOrderTotals();
            }
            function updateProductAndOrderTotals() {
              db.query('UPDATE products SET quantity = quantity - ? WHERE id = ?', [diff, product_id], (err) => {
                if (err) return db.rollback(() => res.status(500).json({ message: 'Error adjusting product stock.' }));
                db.query('UPDATE orders SET total_amount = (SELECT COALESCE(SUM(oi.quantity * oi.price_at_order), 0) FROM order_items oi WHERE oi.order_id = ?) WHERE id = ?', [orderId, orderId], (err) => {
                  if (err) return db.rollback(() => res.status(500).json({ message: 'Error updating order total.' }));
                  db.commit((err) => {
                    if (err) return db.rollback(() => res.status(500).json({ message: 'Transaction failed.' }));
                    res.status(200).json({ message: 'Order item quantity updated.' });
                  });
                });
              });
            }
          });
        }
      });
    });
  },

  // --- Remove Item from Order ---
  removeItemFromOrder: (req, res) => {
    const { orderId, itemId } = req.params;
    db.beginTransaction((err) => {
      if (err) return res.status(500).json({ message: 'Failed to start transaction.' });
      db.query('SELECT product_id, quantity FROM order_items WHERE id = ? AND order_id = ?', [itemId, orderId], (err, itemResults) => {
        if (err) return db.rollback(() => res.status(500).json({ message: 'Error fetching order item.' }));
        if (itemResults.length === 0) return db.rollback(() => res.status(404).json({ message: 'Order item not found.' }));
        const { product_id, quantity: itemQuantity } = itemResults[0];
        db.query('DELETE FROM order_items WHERE id = ?', [itemId], (err, deleteResult) => {
          if (err) return db.rollback(() => res.status(500).json({ message: 'Error removing item.' }));
          db.query('UPDATE products SET quantity = quantity + ? WHERE id = ?', [itemQuantity, product_id], (err) => {
            if (err) return db.rollback(() => res.status(500).json({ message: 'Error reverting product stock.' }));
            db.query('UPDATE orders SET total_amount = (SELECT COALESCE(SUM(oi.quantity * oi.price_at_order), 0) FROM order_items oi WHERE oi.order_id = ?) WHERE id = ?', [orderId, orderId], (err) => {
              if (err) return db.rollback(() => res.status(500).json({ message: 'Error updating order total.' }));
              db.commit((err) => {
                if (err) return db.rollback(() => res.status(500).json({ message: 'Transaction failed.' }));
                res.status(200).json({ message: 'Product removed from order.' });
              });
            });
          });
        });
      });
    });
  },

  // --- Get Order Details ---
  getOrderDetails: (req, res) => {
    const { orderId } = req.params;
    db.query(
      `SELECT
        o.id AS order_id,
        o.customer_name,
        o.company_name,
        o.customer_email,
        o.customer_phone,
        o.createdAt AS order_date,
        o.status,
        o.total_amount,
        o.notes,
        oi.id AS item_id,
        p.id AS product_id,
        p.name AS product_name,
        p.description AS product_description,
        oi.quantity AS ordered_quantity,
        oi.price_at_order,
        (SELECT GROUP_CONCAT(pi.image_path ORDER BY pi.id ASC) FROM product_images pi WHERE pi.product_id = p.id) AS imageUrls
      FROM orders o
      JOIN order_items oi ON o.id = oi.order_id
      JOIN products p ON oi.product_id = p.id
      WHERE o.id = ?`,
      [orderId],
      (err, results) => {
        if (err) return res.status(500).json({ message: 'Error fetching order details.' });
        if (results.length === 0) return res.status(404).json({ message: 'Order not found.' });
        
        const order = {
          id: results[0].order_id,
          customerName: results[0].customer_name,
          companyName: results[0].company_name,
          customerEmail: results[0].customer_email,
          customerPhone: results[0].customer_phone,
          orderDate: results[0].order_date,
          status: results[0].status,
          totalAmount: results[0].total_amount,
          notes: results[0].notes,
          items: []
        };
        
        results.forEach(row => {
          let itemImageUrls = [];
          if (row.imageUrls) {
              itemImageUrls = row.imageUrls.split(',').map(url => url.trim()).filter(url => url !== '');
          }
          order.items.push({
            itemId: row.item_id,
            productId: row.product_id,
            name: row.product_name,
            description: row.product_description,
            quantity: row.ordered_quantity,
            priceAtOrder: row.price_at_order,
            imageUrls: itemImageUrls
          });
        });
        res.status(200).json(order);
      }
    );
  },

  // --- Get All Orders ---
  getAllOrders: (req, res) => {
    db.query(
      `SELECT
        o.id AS orderId,
        o.customer_name AS customerName,
        o.company_name AS companyName,
        o.customer_email AS customerEmail,
        o.customer_phone AS customerPhone,
        o.createdAt AS orderDate,
        o.status,
        o.total_amount AS totalAmount,
        GROUP_CONCAT(
            JSON_OBJECT(
                'itemId', oi.id,
                'productId', p.id,
                'name', p.name,
                'description', p.description,
                'priceAtOrder', oi.price_at_order,
                'quantity', oi.quantity,
                'imageUrls', (SELECT GROUP_CONCAT(pi.image_path ORDER BY pi.id ASC) FROM product_images pi WHERE pi.product_id = p.id)
            )
            ORDER BY oi.id ASC SEPARATOR '|||'
        ) AS items_json
      FROM orders o
      LEFT JOIN order_items oi ON o.id = oi.order_id
      LEFT JOIN products p ON oi.product_id = p.id
      GROUP BY o.id
      ORDER BY o.createdAt DESC, o.id`,
      (err, results) => {
        if (err) {
          console.error('Error fetching orders:', err);
          return res.status(500).json({ message: 'Error fetching orders.' });
        }

        const orders = results.map(orderRow => {
            const order = {
                id: orderRow.orderId,
                customerName: orderRow.customerName || 'Unknown Customer',
                companyName: orderRow.companyName || null,
                customerEmail: orderRow.customerEmail || null,
                customerPhone: orderRow.customerPhone || null,
                orderDate: orderRow.orderDate,
                status: orderRow.status,
                totalAmount: orderRow.totalAmount != null ? parseFloat(orderRow.totalAmount).toFixed(2) : '0.00',
                items: []
            };

            if (orderRow.items_json) {
                const rawItems = orderRow.items_json.split('|||').map(itemStr => {
                    try {
                        const parsedItem = JSON.parse(itemStr);
                        if (parsedItem.imageUrls) {
                            parsedItem.imageUrls = parsedItem.imageUrls.split(',').map(url => url.trim()).filter(url => url !== '');
                        } else {
                            parsedItem.imageUrls = [];
                        }
                        return parsedItem;
                    } catch (e) {
                        console.error('Error parsing order item JSON for order ID', orderRow.orderId, ':', e, 'Raw string:', itemStr);
                        return null;
                    }
                }).filter(item => item !== null);

                order.items.push(...rawItems);
            }
            return order;
        });

        res.status(200).json(orders);
      }
    );
  },

  // --- Update Order Status ---
  updateOrderStatus: async (req, res) => {
    const { orderId } = req.params;
    const { status } = req.body;
    const validStatuses = ['Draft', 'Pending', 'Confirmed', 'Shipped', 'Cancelled'];
    if (!validStatuses.includes(status)) return res.status(400).json({ message: 'Invalid order status.' });
    try {
      await db.promise().beginTransaction();
      const [[order]] = await db.promise().query('SELECT status FROM orders WHERE id = ?', [orderId]);
      const currentStatus = order?.status;
      if (status === 'Cancelled' && currentStatus !== 'Cancelled') {
        const [items] = await db.promise().query('SELECT product_id, quantity FROM order_items WHERE order_id = ?', [orderId]);
        for (const item of items) {
          await db.promise().query('UPDATE products SET quantity = quantity + ? WHERE id = ?', [item.quantity, item.product_id]);
        }
      }
      if (currentStatus === 'Cancelled' && status !== 'Cancelled') {
        const [items] = await db.promise().query('SELECT product_id, quantity FROM order_items WHERE order_id = ?', [orderId]);
        for (const item of items) {
          await db.promise().query('UPDATE products SET quantity = quantity - ? WHERE id = ?', [item.quantity, item.product_id]);
        }
      }
      await db.promise().query('UPDATE orders SET status = ? WHERE id = ?', [status, orderId]);
      await db.promise().commit();
      res.status(200).json({ message: `Order status updated to ${status}.` });
    } catch (error) {
      await db.promise().rollback();
      res.status(500).json({ message: 'Error updating order status.', error: error.message });
    }
  },

  // --- Delete Order ---
  deleteOrder: async (req, res) => {
    const { orderId } = req.params;
    try {
      await db.promise().beginTransaction();
      const [orderItems] = await db.promise().query('SELECT product_id, quantity FROM order_items WHERE order_id = ?', [orderId]);
      for (const item of orderItems) {
        await db.promise().query('UPDATE products SET quantity = quantity + ? WHERE id = ?', [item.quantity, item.product_id]);
      }
      await db.promise().query('DELETE FROM order_items WHERE order_id = ?', [orderId]);
      await db.promise().query('DELETE FROM orders WHERE id = ?', [orderId]);
      await db.promise().commit();
      res.status(200).json({ message: 'Order and its items deleted, stock reverted.' });
    } catch (error) {
      await db.promise().rollback();
      res.status(500).json({ message: 'Error deleting order.', error: error.message });
    }
  }
};