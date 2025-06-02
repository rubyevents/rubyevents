module.exports = {
  plugins: {
    '@tailwindcss/postcss': {},
    rfs: {
      twoDimensional: false,
      baseValue: 14,
      unit: 'rem',
      breakpoint: 1200,
      breakpointUnit: 'px',
      factor: 5,
      safariIframeResizeBugFix: false
    }
  }
}
