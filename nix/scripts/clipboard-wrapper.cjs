'use strict';

const shouldDisable = () => {
  if (process.env.OPENCLAW_DISABLE_CLIPBOARD === '1') {
    return true;
  }
  return !(
    process.env.DISPLAY ||
    process.env.WAYLAND_DISPLAY ||
    process.env.XDG_SESSION_TYPE
  );
};

const fallback = (reason) => {
  const stub = {
    availableFormats: () => [],
    getText: async () => '',
    setText: async () => {},
    hasText: () => false,
    getImageBinary: async () => [],
    getImageBase64: async () => '',
    setImageBinary: async () => {},
    setImageBase64: async () => {},
    hasImage: () => false,
    getHtml: async () => '',
    setHtml: async () => {},
    hasHtml: () => false,
    getRtf: async () => '',
    setRtf: async () => {},
    hasRtf: () => false,
    clear: async () => {},
    watch: () => {},
    callThreadsafeFunction: () => {},
    __fallbackReason: reason ? String(reason) : 'clipboard-disabled',
  };
  stub.default = stub;
  return stub;
};

if (shouldDisable()) {
  module.exports = fallback('DISPLAY not set');
} else {
  try {
    module.exports = require('./index.original.js');
  } catch (err) {
    module.exports = fallback(err);
  }
}
