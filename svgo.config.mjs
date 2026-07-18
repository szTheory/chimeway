// svgo.config.mjs — Phase 83 Wave-0 SVGO optimizer config.
//
// Repo-root (NOT inside brandbook/ — this project is zero-build; nothing from
// node_modules is committed). Optimizes hand-authored brand SVGs before they
// are committed under brandbook/assets/**.
//
// Safe-plugin config verified in 83-RESEARCH.md (Pattern 1): -61.7% bytes with
// viewBox, token hex and a11y (role/aria) attributes all preserved.
//
// Pinned invocation (supply-chain control T-83-02 — svgo@4.0.2 is Approved in
// 83-RESEARCH.md §Package Legitimacy Audit; ephemeral npx, zero committed dep):
//
//   npx -y svgo@4.0.2 --config svgo.config.mjs -p 2 --multipass -i in.svg -o out.svg
//
export default {
  multipass: true,
  plugins: [
    {
      name: 'preset-default',
      params: {
        overrides: {
          // CRITICAL: keep viewBox — dropping it breaks scaling of every mark.
          removeViewBox: false,
          // Keep human-readable ids (e.g. keystone facet paths).
          cleanupIds: false,
          // Preserve accessibility attributes (role="img", aria-label).
          removeUnknownsAndDefaults: {
            keepAriaAttrs: true,
            keepRoleAttr: true,
          },
        },
      },
    },
  ],
};
