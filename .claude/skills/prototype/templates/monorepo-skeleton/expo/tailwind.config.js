/** @type {import('tailwindcss').Config} */
module.exports = {
  content: ["./app/**/*.{js,jsx,ts,tsx}"],
  presets: [require("nativewind/preset")],
  theme: {
    extend: {
      // tokens.css is consumed by Phase 4 stitch — tokens map into this config via the
      // skill substituting per-token entries here. Default keys mirror tokens.css semantic names.
      colors: {
        primary: "var(--color-primary, #2563eb)",
        secondary: "var(--color-secondary, #64748b)",
        accent: "var(--color-accent, #f59e0b)",
        background: "var(--color-background, #ffffff)",
        foreground: "var(--color-foreground, #0f172a)",
      },
      spacing: {
        xs: "var(--space-xs, 4px)",
        sm: "var(--space-sm, 8px)",
        md: "var(--space-md, 16px)",
        lg: "var(--space-lg, 24px)",
        xl: "var(--space-xl, 32px)",
      },
    },
  },
  plugins: [],
};
