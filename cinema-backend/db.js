const mysql = require("mysql2");

// Create a connection pool (more efficient than single connections)
const pool = mysql.createPool({
  host:     "localhost",   // your MySQL host
  port:     3306,          // default MySQL port
  user:     "root",        // your MySQL username
  password: "Kingisme#28", // your MySQL password
  database: "cinemamanagement",
  waitForConnections: true,
  connectionLimit: 10,
  queueLimit: 0,
});

// Promisify for async/await usage
const db = pool.promise();

// Test connection on startup
(async () => {
  try {
    await db.query("SELECT 1");
    console.log("✅ MySQL connected successfully");
  } catch (err) {
    console.error("❌ MySQL connection failed:", err.message);
    process.exit(1);
  }
})();

module.exports = db;