'use strict';

const config = require('./config');

const LEVELS = { error: 0, warn: 1, info: 2, debug: 3 };

function write(level, msg, fields) {
  if (LEVELS[level] > (LEVELS[config.logLevel] ?? LEVELS.info)) return;
  const line = JSON.stringify({
    timestamp: new Date().toISOString(),
    level,
    msg,
    ...fields,
  });
  (level === 'error' ? process.stderr : process.stdout).write(`${line}\n`);
}

module.exports = {
  error: (msg, fields) => write('error', msg, fields),
  warn: (msg, fields) => write('warn', msg, fields),
  info: (msg, fields) => write('info', msg, fields),
  debug: (msg, fields) => write('debug', msg, fields),
};
