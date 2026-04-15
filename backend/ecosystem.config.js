module.exports = {
  apps: [{
    name: "society-backend",
    script: "./src/server.js",
    instances: 1,
    exec_mode: "cluster",
    watch: false,
    max_memory_restart: "1G",
    env: {
      NODE_ENV: "production",
    },
    env_development: {
      NODE_ENV: "development",
    },
    error_file: "./logs/err.log",
    out_file: "./logs/out.log",
    log_date_format: "YYYY-MM-DD HH:mm Z",
    merge_logs: true
  }]
};
