// ezlab_backend/controllers/productController.js

const db = require('../config/db');
const multer = require('multer');
const path = require('path');
const fs = require('fs');

// Setup Multer for image storage
const storage = multer.diskStorage({
  destination: (req, file, cb) => {
    const uploadDir = 'uploads/images'; // Directory where images will be stored
    if (!fs.existsSync(uploadDir)) {
      fs.mkdirSync(uploadDir, { recursive: true });
    }
    cb(null, uploadDir);
  },
  filename: (req, file, cb) => {
    const uniqueSuffix = Date.now() + '-' + Math.round(Math.random() * 1E9);
    cb(null, file.fieldname + '-' + uniqueSuffix + path.extname(file.originalname));
  }
});

//  MODIFIED: Multer upload middleware to accept multiple files (array)
// 'images' is the name of the field in the form data that holds the files
// 5 is the maximum number of files that can be uploaded in one request
const upload = multer({
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB file size limit per file
  fileFilter: (req, file, cb) => {
    const allowedExtnames = /\.(jpeg|jpg|png|gif|webp)$/i; // Case-insensitive check for common image extensions
    const extnamePass = allowedExtnames.test(path.extname(file.originalname));

    console.log(`--- File Filter Check ---`);
    console.log(`Original Name: ${file.originalname}`);
    console.log(`Mime Type: ${file.mimetype} (ignoring this for web compatibility)`);
    console.log(`Extension: ${path.extname(file.originalname)}`);
    console.log(`Extension Pass: ${extnamePass}`);
    console.log(`-------------------------`);

    if (extnamePass) {
      return cb(null, true);
    }
    cb(new Error('Only image files (JPEG, JPG, PNG, GIF, WEBP) with valid extensions are allowed!'));
  }
}).array('images', 5); //  Changed from .single('image') to .array('images', 5)

module.exports = {
  //  MODIFIED: getAllProducts to fetch multiple imageUrls from product_images table
  getAllProducts: (req, res) => {
    const query = `
      SELECT
          p.id,
          p.name,
          p.description,
          p.price,
          p.quantity,
          GROUP_CONCAT(pi.image_path ORDER BY pi.id ASC) AS imageUrls -- Get all image paths as a comma-separated string
      FROM products p
      LEFT JOIN product_images pi ON p.id = pi.product_id
      GROUP BY p.id
      ORDER BY p.name ASC;
    `;
    db.query(query, (err, results) => {
      if (err) {
        console.error('Error fetching products:', err);
        return res.status(500).json({ message: 'Error fetching products' });
      }

      const productsWithFullUrls = results.map(product => {
        let fullImageUrls = [];
        if (product.imageUrls) {
          // Split the comma-separated string back into an array of image paths
          fullImageUrls = product.imageUrls.split(',').map(imgPath => {
            // Construct full URLs for each image
            return `${req.protocol}://${req.get('host')}/${imgPath.replace(/\\/g, '/')}`;
          });
        }
        // Return product object with an array of image URLs (now 'imageUrls' not 'imageUrl')
        // Ensure imageUrls is an array, even if empty
        return { ...product, imageUrls: fullImageUrls };
      });
      res.status(200).json(productsWithFullUrls);
    });
  },

  //  MODIFIED: addProduct to handle multiple image uploads and save paths to product_images
  addProduct: (req, res) => {
    upload(req, res, async (err) => { // Made the callback async to use await for DB operations
      if (err instanceof multer.MulterError) {
        console.error('Multer error:', err);
        return res.status(400).json({ message: err.message });
      } else if (err) {
        console.error('Unknown upload error:', err);
        return res.status(500).json({ message: err.message });
      }

      //  Check req.files as it's an array of files now
      if (!req.files || req.files.length === 0) {
        return res.status(400).json({ message: 'No image files uploaded.' });
      }

      console.log('Add product attempt:', req.body);
      const { name, description } = req.body;
      let { price, quantity } = req.body;

      // Ensure price and quantity are never null or invalid
      if (price == null || isNaN(price)) {
        price = 0;
      }
      if (quantity == null || isNaN(quantity)) {
        quantity = 0;
      }

      // Start a database transaction for atomicity (all or nothing)
      db.beginTransaction(async (transactionErr) => {
        if (transactionErr) {
          console.error('Error starting database transaction:', transactionErr);
          return res.status(500).json({ message: 'Database transaction error' });
        }

        try {
          // 1. Insert product details into 'products' table
          const productInsertResult = await new Promise((resolve, reject) => {
            db.query(
              'INSERT INTO products (name, description, price, quantity) VALUES (?, ?, ?, ?)',
              [name, description, price, quantity],
              (err, result) => {
                if (err) return reject(err);
                resolve(result);
              }
            );
          });

          const productId = productInsertResult.insertId;
          const savedImageUrls = []; // To collect the paths that were saved

          // 2. Insert each uploaded image's path into the 'product_images' table
          for (const file of req.files) {
            const imagePath = file.path.replace(/\\/g, '/'); // Normalize path for URLs
            savedImageUrls.push(imagePath); // Store for response

            await new Promise((resolve, reject) => {
              db.query(
                'INSERT INTO product_images (product_id, image_path) VALUES (?, ?)',
                [productId, imagePath],
                (err, result) => {
                  if (err) return reject(err);
                  resolve(result);
                }
              );
            });
          }

          // Commit the transaction if all operations were successful
          db.commit((commitErr) => {
            if (commitErr) {
              console.error('Error committing transaction:', commitErr);
              // If commit fails, rollback all changes and delete uploaded files
              return db.rollback(() => {
                console.error('Transaction rolled back due to commit error.');
                req.files.forEach(file => {
                  fs.unlink(file.path, (unlinkErr) => {
                    if (unlinkErr) console.error('Error deleting uploaded file on commit rollback:', unlinkErr);
                  });
                });
                res.status(500).json({ message: 'Error saving product and images.' });
              });
            }
            res.status(200).json({ message: 'Product added successfully', productId: productId, imageUrls: savedImageUrls });
          });

        } catch (dbOperationError) {
          console.error('Error during database operation:', dbOperationError);
          // If any operation in the try block fails, rollback the transaction
          db.rollback(() => {
            console.error('Transaction rolled back due to operation error.');
            // Clean up uploaded files if DB insertion failed for any reason
            req.files.forEach(file => {
              fs.unlink(file.path, (unlinkErr) => {
                if (unlinkErr) console.error('Error deleting uploaded file on operation rollback:', unlinkErr);
              });
            });
            res.status(500).json({ message: 'Error adding product to database', error: dbOperationError.message });
          });
        }
      });
    });
  },

  //  MODIFIED: deleteProduct to also delete associated image files from the file system
  deleteProduct: (req, res) => {
    const { id } = req.params;

    db.beginTransaction(async (transactionErr) => {
      if (transactionErr) {
        console.error('Error starting transaction for delete:', transactionErr);
        return res.status(500).json({ message: 'Database transaction error' });
      }

      try {
        // 1. Get all image paths associated with the product from product_images table
        const imagePathsResult = await new Promise((resolve, reject) => {
          db.query('SELECT image_path FROM product_images WHERE product_id = ?', [id], (err, results) => {
            if (err) return reject(err);
            resolve(results.map(row => row.image_path)); // Extract just the paths
          });
        });

        // 2. Delete the product from the 'products' table.
        // Due to FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
        // all associated entries in 'product_images' will be automatically deleted.
        await new Promise((resolve, reject) => {
          db.query('DELETE FROM products WHERE id = ?', [id], (err, result) => {
            if (err) return reject(err);
            resolve(result);
          });
        });

        // 3. Delete the actual image files from the file system using the paths retrieved earlier
        for (const imagePath of imagePathsResult) {
          fs.unlink(imagePath, (unlinkErr) => {
            if (unlinkErr) {
              console.error(`Error deleting image file from file system: ${imagePath}`, unlinkErr);
            } else {
              console.log(`Image file ${imagePath} deleted successfully.`);
            }
          });
        }

        // Commit the transaction
        db.commit((commitErr) => {
          if (commitErr) {
            console.error('Error committing delete transaction:', commitErr);
            return db.rollback(() => {
              console.error('Delete transaction rolled back.');
              res.status(500).json({ message: 'Error deleting product and images.' });
            });
          }
          res.status(200).json({ message: 'Product deleted successfully' });
        });

      } catch (dbOperationError) {
        console.error('Error during delete database operation:', dbOperationError);
        db.rollback(() => {
          console.error('Delete transaction rolled back due to error.');
          res.status(500).json({ message: 'Error deleting product', error: dbOperationError.message });
        });
      }
    });
  }
};