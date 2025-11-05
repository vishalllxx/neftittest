// vite.config.ts
import { defineConfig } from "file:///C:/Users/ashaj/OneDrive/Desktop/Neftit_Auth_Blockchain_Backend-finalBranch/node_modules/vite/dist/node/index.js";
import react from "file:///C:/Users/ashaj/OneDrive/Desktop/Neftit_Auth_Blockchain_Backend-finalBranch/node_modules/@vitejs/plugin-react-swc/index.js";
import { fileURLToPath } from "node:url";
import { dirname, resolve } from "node:path";
import mdx from "file:///C:/Users/ashaj/OneDrive/Desktop/Neftit_Auth_Blockchain_Backend-finalBranch/node_modules/@mdx-js/rollup/index.js";
import remarkGfm from "file:///C:/Users/ashaj/OneDrive/Desktop/Neftit_Auth_Blockchain_Backend-finalBranch/node_modules/remark-gfm/index.js";
import rehypeSlug from "file:///C:/Users/ashaj/OneDrive/Desktop/Neftit_Auth_Blockchain_Backend-finalBranch/node_modules/rehype-slug/index.js";
import rehypeAutolinkHeadings from "file:///C:/Users/ashaj/OneDrive/Desktop/Neftit_Auth_Blockchain_Backend-finalBranch/node_modules/rehype-autolink-headings/index.js";
var __vite_injected_original_import_meta_url = "file:///C:/Users/ashaj/OneDrive/Desktop/Neftit_Auth_Blockchain_Backend-finalBranch/vite.config.ts";
var __filename = fileURLToPath(__vite_injected_original_import_meta_url);
var __dirname = dirname(__filename);
var ignoreModelViewerPlugin = () => {
  return {
    name: "ignore-model-viewer",
    resolveId(id) {
      if (id.includes("@google/model-viewer")) {
        return id;
      }
    },
    load(id) {
      if (id.includes("@google/model-viewer")) {
        return "export default {};";
      }
    }
  };
};
var vite_config_default = defineConfig(({ mode }) => {
  const isProd = mode === "production";
  return {
    plugins: [
      {
        ...mdx({
          remarkPlugins: [remarkGfm],
          rehypePlugins: [rehypeSlug, rehypeAutolinkHeadings]
        }),
        enforce: "pre"
        // run MDX before React
      },
      react(),
      ignoreModelViewerPlugin()
    ],
    server: {
      host: true,
      port: 3333,
      watch: {
        usePolling: true
        // helps on Windows/WSL to reload .mdx edits
      },
      // Allow external host access (for Codesandbox/Cloud dev)
      allowedHosts: ["y4gfpc-3333.csb.app"],
      // or 'all'
      proxy: {
        // Proxy IPFS requests to avoid CORS issues in development
        "/api/ipfs": {
          target: "https://ipfs.io",
          changeOrigin: true,
          rewrite: (path) => path.replace(/^\/api\/ipfs/, "/ipfs"),
          configure: (proxy, _options) => {
            proxy.on("error", (err, _req, _res) => {
              console.log("IPFS proxy error:", err);
            });
            proxy.on("proxyReq", (proxyReq, req, _res) => {
              console.log("IPFS proxy request:", req.method, req.url);
            });
          }
        },
        "/api/ipfs-pinata": {
          target: "https://gateway.pinata.cloud",
          changeOrigin: true,
          rewrite: (path) => path.replace(/^\/api\/ipfs-pinata/, "/ipfs")
        },
        "/api/ipfs-cloudflare": {
          target: "https://cloudflare-ipfs.com",
          changeOrigin: true,
          rewrite: (path) => path.replace(/^\/api\/ipfs-cloudflare/, "/ipfs")
        }
      }
    },
    resolve: {
      alias: {
        "@": resolve(__dirname, "./src")
      },
      extensions: [".js", ".ts", ".jsx", ".tsx", ".mdx"]
      // allow MDX imports
    },
    define: {
      "process.env": process.env,
      global: "globalThis"
    },
    css: {
      preprocessorOptions: {
        scss: {
          additionalData: `@import "./src/styles/font-reset.css";`
        }
      }
    },
    build: {
      minify: "terser",
      terserOptions: {
        compress: {
          drop_console: isProd,
          drop_debugger: isProd
        }
      },
      rollupOptions: {
        external: ["@google/model-viewer"],
        output: {
          manualChunks: {
            "vendor-react": ["react", "react-dom", "react-router-dom"],
            "vendor-ui": [
              "@radix-ui/react-dialog",
              "@radix-ui/react-dropdown-menu",
              "@radix-ui/react-tooltip",
              "class-variance-authority",
              "clsx",
              "tailwind-merge"
            ],
            "vendor-web3": [
              "@thirdweb-dev/react",
              "@thirdweb-dev/sdk",
              "@thirdweb-dev/auth",
              "ethers"
            ],
            "vendor-utils": ["date-fns", "framer-motion", "sonner"]
          }
        }
      },
      sourcemap: !isProd,
      reportCompressedSize: true,
      chunkSizeWarningLimit: 1e3
    },
    optimizeDeps: {
      include: [
        "react",
        "react-dom",
        "react-router-dom",
        "@thirdweb-dev/react",
        "ethers",
        "framer-motion",
        "buffer"
      ],
      // Exclude problematic packages
      exclude: ["@google/model-viewer"]
    }
  };
});
export {
  vite_config_default as default
};
//# sourceMappingURL=data:application/json;base64,ewogICJ2ZXJzaW9uIjogMywKICAic291cmNlcyI6IFsidml0ZS5jb25maWcudHMiXSwKICAic291cmNlc0NvbnRlbnQiOiBbImNvbnN0IF9fdml0ZV9pbmplY3RlZF9vcmlnaW5hbF9kaXJuYW1lID0gXCJDOlxcXFxVc2Vyc1xcXFxhc2hhalxcXFxPbmVEcml2ZVxcXFxEZXNrdG9wXFxcXE5lZnRpdF9BdXRoX0Jsb2NrY2hhaW5fQmFja2VuZC1maW5hbEJyYW5jaFwiO2NvbnN0IF9fdml0ZV9pbmplY3RlZF9vcmlnaW5hbF9maWxlbmFtZSA9IFwiQzpcXFxcVXNlcnNcXFxcYXNoYWpcXFxcT25lRHJpdmVcXFxcRGVza3RvcFxcXFxOZWZ0aXRfQXV0aF9CbG9ja2NoYWluX0JhY2tlbmQtZmluYWxCcmFuY2hcXFxcdml0ZS5jb25maWcudHNcIjtjb25zdCBfX3ZpdGVfaW5qZWN0ZWRfb3JpZ2luYWxfaW1wb3J0X21ldGFfdXJsID0gXCJmaWxlOi8vL0M6L1VzZXJzL2FzaGFqL09uZURyaXZlL0Rlc2t0b3AvTmVmdGl0X0F1dGhfQmxvY2tjaGFpbl9CYWNrZW5kLWZpbmFsQnJhbmNoL3ZpdGUuY29uZmlnLnRzXCI7Ly8gdml0ZS5jb25maWcudHNcbmltcG9ydCB7IGRlZmluZUNvbmZpZyB9IGZyb20gXCJ2aXRlXCI7XG5pbXBvcnQgcmVhY3QgZnJvbSBcIkB2aXRlanMvcGx1Z2luLXJlYWN0LXN3Y1wiO1xuaW1wb3J0IHsgZmlsZVVSTFRvUGF0aCB9IGZyb20gJ25vZGU6dXJsJztcbmltcG9ydCB7IGRpcm5hbWUsIHJlc29sdmUgfSBmcm9tICdub2RlOnBhdGgnO1xuaW1wb3J0IG1keCBmcm9tIFwiQG1keC1qcy9yb2xsdXBcIjtcblxuY29uc3QgX19maWxlbmFtZSA9IGZpbGVVUkxUb1BhdGgoaW1wb3J0Lm1ldGEudXJsKTtcbmNvbnN0IF9fZGlybmFtZSA9IGRpcm5hbWUoX19maWxlbmFtZSk7XG5cbi8vIE1hcmtkb3duIHBsdWdpbnNcbmltcG9ydCByZW1hcmtHZm0gZnJvbSBcInJlbWFyay1nZm1cIjtcbmltcG9ydCByZWh5cGVTbHVnIGZyb20gXCJyZWh5cGUtc2x1Z1wiO1xuaW1wb3J0IHJlaHlwZUF1dG9saW5rSGVhZGluZ3MgZnJvbSBcInJlaHlwZS1hdXRvbGluay1oZWFkaW5nc1wiO1xuXG4vLyBQbHVnaW4gdG8gaGFuZGxlIHByb2JsZW1hdGljIEBnb29nbGUvbW9kZWwtdmlld2VyIGltcG9ydHNcbmNvbnN0IGlnbm9yZU1vZGVsVmlld2VyUGx1Z2luID0gKCkgPT4ge1xuICByZXR1cm4ge1xuICAgIG5hbWU6ICdpZ25vcmUtbW9kZWwtdmlld2VyJyxcbiAgICByZXNvbHZlSWQoaWQ6IHN0cmluZykge1xuICAgICAgaWYgKGlkLmluY2x1ZGVzKCdAZ29vZ2xlL21vZGVsLXZpZXdlcicpKSB7XG4gICAgICAgIHJldHVybiBpZDtcbiAgICAgIH1cbiAgICB9LFxuICAgIGxvYWQoaWQ6IHN0cmluZykge1xuICAgICAgaWYgKGlkLmluY2x1ZGVzKCdAZ29vZ2xlL21vZGVsLXZpZXdlcicpKSB7XG4gICAgICAgIHJldHVybiAnZXhwb3J0IGRlZmF1bHQge307JztcbiAgICAgIH1cbiAgICB9XG4gIH07XG59O1xuXG4vLyBodHRwczovL3ZpdGVqcy5kZXYvY29uZmlnL1xuZXhwb3J0IGRlZmF1bHQgZGVmaW5lQ29uZmlnKCh7IG1vZGUgfSkgPT4ge1xuICBjb25zdCBpc1Byb2QgPSBtb2RlID09PSBcInByb2R1Y3Rpb25cIjtcblxuICByZXR1cm4ge1xuICAgIFxuICAgIHBsdWdpbnM6IFtcbiAgICAgIHtcbiAgICAgICAgLi4ubWR4KHtcbiAgICAgICAgICByZW1hcmtQbHVnaW5zOiBbcmVtYXJrR2ZtXSxcbiAgICAgICAgICByZWh5cGVQbHVnaW5zOiBbcmVoeXBlU2x1ZywgcmVoeXBlQXV0b2xpbmtIZWFkaW5nc10sXG4gICAgICAgIH0pLFxuICAgICAgICBlbmZvcmNlOiBcInByZVwiLCAvLyBydW4gTURYIGJlZm9yZSBSZWFjdFxuICAgICAgfSxcbiAgICAgIHJlYWN0KCksaWdub3JlTW9kZWxWaWV3ZXJQbHVnaW4oKVxuICAgIF0sXG4gICAgc2VydmVyOiB7XG4gICAgICBob3N0OiB0cnVlLFxuICAgICAgcG9ydDogMzMzMyxcbiAgICAgIHdhdGNoOiB7XG4gICAgICAgIHVzZVBvbGxpbmc6IHRydWUsIC8vIGhlbHBzIG9uIFdpbmRvd3MvV1NMIHRvIHJlbG9hZCAubWR4IGVkaXRzXG4gICAgICB9LFxuICAgICAgLy8gQWxsb3cgZXh0ZXJuYWwgaG9zdCBhY2Nlc3MgKGZvciBDb2Rlc2FuZGJveC9DbG91ZCBkZXYpXG4gICAgICBhbGxvd2VkSG9zdHM6IFtcInk0Z2ZwYy0zMzMzLmNzYi5hcHBcIl0sIC8vIG9yICdhbGwnXG4gICAgICBwcm94eToge1xuICAgICAgICAvLyBQcm94eSBJUEZTIHJlcXVlc3RzIHRvIGF2b2lkIENPUlMgaXNzdWVzIGluIGRldmVsb3BtZW50XG4gICAgICAgICcvYXBpL2lwZnMnOiB7XG4gICAgICAgICAgdGFyZ2V0OiAnaHR0cHM6Ly9pcGZzLmlvJyxcbiAgICAgICAgICBjaGFuZ2VPcmlnaW46IHRydWUsXG4gICAgICAgICAgcmV3cml0ZTogKHBhdGgpID0+IHBhdGgucmVwbGFjZSgvXlxcL2FwaVxcL2lwZnMvLCAnL2lwZnMnKSxcbiAgICAgICAgICBjb25maWd1cmU6IChwcm94eSwgX29wdGlvbnMpID0+IHtcbiAgICAgICAgICAgIHByb3h5Lm9uKCdlcnJvcicsIChlcnIsIF9yZXEsIF9yZXMpID0+IHtcbiAgICAgICAgICAgICAgY29uc29sZS5sb2coJ0lQRlMgcHJveHkgZXJyb3I6JywgZXJyKTtcbiAgICAgICAgICAgIH0pO1xuICAgICAgICAgICAgcHJveHkub24oJ3Byb3h5UmVxJywgKHByb3h5UmVxLCByZXEsIF9yZXMpID0+IHtcbiAgICAgICAgICAgICAgY29uc29sZS5sb2coJ0lQRlMgcHJveHkgcmVxdWVzdDonLCByZXEubWV0aG9kLCByZXEudXJsKTtcbiAgICAgICAgICAgIH0pO1xuICAgICAgICAgIH0sXG4gICAgICAgIH0sXG4gICAgICAgICcvYXBpL2lwZnMtcGluYXRhJzoge1xuICAgICAgICAgIHRhcmdldDogJ2h0dHBzOi8vZ2F0ZXdheS5waW5hdGEuY2xvdWQnLFxuICAgICAgICAgIGNoYW5nZU9yaWdpbjogdHJ1ZSxcbiAgICAgICAgICByZXdyaXRlOiAocGF0aCkgPT4gcGF0aC5yZXBsYWNlKC9eXFwvYXBpXFwvaXBmcy1waW5hdGEvLCAnL2lwZnMnKSxcbiAgICAgICAgfSxcbiAgICAgICAgJy9hcGkvaXBmcy1jbG91ZGZsYXJlJzoge1xuICAgICAgICAgIHRhcmdldDogJ2h0dHBzOi8vY2xvdWRmbGFyZS1pcGZzLmNvbScsXG4gICAgICAgICAgY2hhbmdlT3JpZ2luOiB0cnVlLFxuICAgICAgICAgIHJld3JpdGU6IChwYXRoKSA9PiBwYXRoLnJlcGxhY2UoL15cXC9hcGlcXC9pcGZzLWNsb3VkZmxhcmUvLCAnL2lwZnMnKSxcbiAgICAgICAgfVxuICAgICAgfVxuICAgIH0sXG4gICAgcmVzb2x2ZToge1xuICAgICAgYWxpYXM6IHtcbiAgICAgICAgXCJAXCI6IHJlc29sdmUoX19kaXJuYW1lLCBcIi4vc3JjXCIpLFxuICAgICAgfSxcbiAgICAgIGV4dGVuc2lvbnM6IFtcIi5qc1wiLCBcIi50c1wiLCBcIi5qc3hcIiwgXCIudHN4XCIsIFwiLm1keFwiXSwgLy8gYWxsb3cgTURYIGltcG9ydHNcbiAgICB9LFxuICAgIGRlZmluZToge1xuICAgICAgXCJwcm9jZXNzLmVudlwiOiBwcm9jZXNzLmVudixcbiAgICAgIGdsb2JhbDogXCJnbG9iYWxUaGlzXCIsXG4gICAgfSxcbiAgICBjc3M6IHtcbiAgICAgIHByZXByb2Nlc3Nvck9wdGlvbnM6IHtcbiAgICAgICAgc2Nzczoge1xuICAgICAgICAgIGFkZGl0aW9uYWxEYXRhOiBgQGltcG9ydCBcIi4vc3JjL3N0eWxlcy9mb250LXJlc2V0LmNzc1wiO2AsXG4gICAgICAgIH0sXG4gICAgICB9LFxuICAgIH0sXG4gICAgYnVpbGQ6IHtcbiAgICAgIG1pbmlmeTogXCJ0ZXJzZXJcIixcbiAgICAgIHRlcnNlck9wdGlvbnM6IHtcbiAgICAgICAgY29tcHJlc3M6IHtcbiAgICAgICAgICBkcm9wX2NvbnNvbGU6IGlzUHJvZCxcbiAgICAgICAgICBkcm9wX2RlYnVnZ2VyOiBpc1Byb2QsXG4gICAgICAgIH0sXG4gICAgICB9LFxuICAgICAgcm9sbHVwT3B0aW9uczoge1xuICAgICAgICBleHRlcm5hbDogWydAZ29vZ2xlL21vZGVsLXZpZXdlciddLFxuICAgICAgICBvdXRwdXQ6IHtcbiAgICAgICAgICBtYW51YWxDaHVua3M6IHtcbiAgICAgICAgICAgIFwidmVuZG9yLXJlYWN0XCI6IFtcInJlYWN0XCIsIFwicmVhY3QtZG9tXCIsIFwicmVhY3Qtcm91dGVyLWRvbVwiXSxcbiAgICAgICAgICAgIFwidmVuZG9yLXVpXCI6IFtcbiAgICAgICAgICAgICAgXCJAcmFkaXgtdWkvcmVhY3QtZGlhbG9nXCIsXG4gICAgICAgICAgICAgIFwiQHJhZGl4LXVpL3JlYWN0LWRyb3Bkb3duLW1lbnVcIixcbiAgICAgICAgICAgICAgXCJAcmFkaXgtdWkvcmVhY3QtdG9vbHRpcFwiLFxuICAgICAgICAgICAgICBcImNsYXNzLXZhcmlhbmNlLWF1dGhvcml0eVwiLFxuICAgICAgICAgICAgICBcImNsc3hcIixcbiAgICAgICAgICAgICAgXCJ0YWlsd2luZC1tZXJnZVwiLFxuICAgICAgICAgICAgXSxcbiAgICAgICAgICAgIFwidmVuZG9yLXdlYjNcIjogW1xuICAgICAgICAgICAgICBcIkB0aGlyZHdlYi1kZXYvcmVhY3RcIixcbiAgICAgICAgICAgICAgXCJAdGhpcmR3ZWItZGV2L3Nka1wiLFxuICAgICAgICAgICAgICBcIkB0aGlyZHdlYi1kZXYvYXV0aFwiLFxuICAgICAgICAgICAgICBcImV0aGVyc1wiLFxuICAgICAgICAgICAgXSxcbiAgICAgICAgICAgIFwidmVuZG9yLXV0aWxzXCI6IFtcImRhdGUtZm5zXCIsIFwiZnJhbWVyLW1vdGlvblwiLCBcInNvbm5lclwiXSxcbiAgICAgICAgICB9LFxuICAgICAgICB9LFxuICAgICAgfSxcbiAgICAgIHNvdXJjZW1hcDogIWlzUHJvZCxcbiAgICAgIHJlcG9ydENvbXByZXNzZWRTaXplOiB0cnVlLFxuICAgICAgY2h1bmtTaXplV2FybmluZ0xpbWl0OiAxMDAwLFxuICAgIH0sXG4gICAgb3B0aW1pemVEZXBzOiB7XG4gICAgICBpbmNsdWRlOiBbXG4gICAgICAgIFwicmVhY3RcIixcbiAgICAgICAgXCJyZWFjdC1kb21cIixcbiAgICAgICAgXCJyZWFjdC1yb3V0ZXItZG9tXCIsXG4gICAgICAgIFwiQHRoaXJkd2ViLWRldi9yZWFjdFwiLFxuICAgICAgICBcImV0aGVyc1wiLFxuICAgICAgICBcImZyYW1lci1tb3Rpb25cIixcbiAgICAgICAgXCJidWZmZXJcIixcbiAgICAgIF0sXG4gICAgICAvLyBFeGNsdWRlIHByb2JsZW1hdGljIHBhY2thZ2VzXG4gICAgICBleGNsdWRlOiBbJ0Bnb29nbGUvbW9kZWwtdmlld2VyJ11cbiAgICB9LFxuICB9O1xufSk7IFxuIl0sCiAgIm1hcHBpbmdzIjogIjtBQUNBLFNBQVMsb0JBQW9CO0FBQzdCLE9BQU8sV0FBVztBQUNsQixTQUFTLHFCQUFxQjtBQUM5QixTQUFTLFNBQVMsZUFBZTtBQUNqQyxPQUFPLFNBQVM7QUFNaEIsT0FBTyxlQUFlO0FBQ3RCLE9BQU8sZ0JBQWdCO0FBQ3ZCLE9BQU8sNEJBQTRCO0FBYm9PLElBQU0sMkNBQTJDO0FBT3hULElBQU0sYUFBYSxjQUFjLHdDQUFlO0FBQ2hELElBQU0sWUFBWSxRQUFRLFVBQVU7QUFRcEMsSUFBTSwwQkFBMEIsTUFBTTtBQUNwQyxTQUFPO0FBQUEsSUFDTCxNQUFNO0FBQUEsSUFDTixVQUFVLElBQVk7QUFDcEIsVUFBSSxHQUFHLFNBQVMsc0JBQXNCLEdBQUc7QUFDdkMsZUFBTztBQUFBLE1BQ1Q7QUFBQSxJQUNGO0FBQUEsSUFDQSxLQUFLLElBQVk7QUFDZixVQUFJLEdBQUcsU0FBUyxzQkFBc0IsR0FBRztBQUN2QyxlQUFPO0FBQUEsTUFDVDtBQUFBLElBQ0Y7QUFBQSxFQUNGO0FBQ0Y7QUFHQSxJQUFPLHNCQUFRLGFBQWEsQ0FBQyxFQUFFLEtBQUssTUFBTTtBQUN4QyxRQUFNLFNBQVMsU0FBUztBQUV4QixTQUFPO0FBQUEsSUFFTCxTQUFTO0FBQUEsTUFDUDtBQUFBLFFBQ0UsR0FBRyxJQUFJO0FBQUEsVUFDTCxlQUFlLENBQUMsU0FBUztBQUFBLFVBQ3pCLGVBQWUsQ0FBQyxZQUFZLHNCQUFzQjtBQUFBLFFBQ3BELENBQUM7QUFBQSxRQUNELFNBQVM7QUFBQTtBQUFBLE1BQ1g7QUFBQSxNQUNBLE1BQU07QUFBQSxNQUFFLHdCQUF3QjtBQUFBLElBQ2xDO0FBQUEsSUFDQSxRQUFRO0FBQUEsTUFDTixNQUFNO0FBQUEsTUFDTixNQUFNO0FBQUEsTUFDTixPQUFPO0FBQUEsUUFDTCxZQUFZO0FBQUE7QUFBQSxNQUNkO0FBQUE7QUFBQSxNQUVBLGNBQWMsQ0FBQyxxQkFBcUI7QUFBQTtBQUFBLE1BQ3BDLE9BQU87QUFBQTtBQUFBLFFBRUwsYUFBYTtBQUFBLFVBQ1gsUUFBUTtBQUFBLFVBQ1IsY0FBYztBQUFBLFVBQ2QsU0FBUyxDQUFDLFNBQVMsS0FBSyxRQUFRLGdCQUFnQixPQUFPO0FBQUEsVUFDdkQsV0FBVyxDQUFDLE9BQU8sYUFBYTtBQUM5QixrQkFBTSxHQUFHLFNBQVMsQ0FBQyxLQUFLLE1BQU0sU0FBUztBQUNyQyxzQkFBUSxJQUFJLHFCQUFxQixHQUFHO0FBQUEsWUFDdEMsQ0FBQztBQUNELGtCQUFNLEdBQUcsWUFBWSxDQUFDLFVBQVUsS0FBSyxTQUFTO0FBQzVDLHNCQUFRLElBQUksdUJBQXVCLElBQUksUUFBUSxJQUFJLEdBQUc7QUFBQSxZQUN4RCxDQUFDO0FBQUEsVUFDSDtBQUFBLFFBQ0Y7QUFBQSxRQUNBLG9CQUFvQjtBQUFBLFVBQ2xCLFFBQVE7QUFBQSxVQUNSLGNBQWM7QUFBQSxVQUNkLFNBQVMsQ0FBQyxTQUFTLEtBQUssUUFBUSx1QkFBdUIsT0FBTztBQUFBLFFBQ2hFO0FBQUEsUUFDQSx3QkFBd0I7QUFBQSxVQUN0QixRQUFRO0FBQUEsVUFDUixjQUFjO0FBQUEsVUFDZCxTQUFTLENBQUMsU0FBUyxLQUFLLFFBQVEsMkJBQTJCLE9BQU87QUFBQSxRQUNwRTtBQUFBLE1BQ0Y7QUFBQSxJQUNGO0FBQUEsSUFDQSxTQUFTO0FBQUEsTUFDUCxPQUFPO0FBQUEsUUFDTCxLQUFLLFFBQVEsV0FBVyxPQUFPO0FBQUEsTUFDakM7QUFBQSxNQUNBLFlBQVksQ0FBQyxPQUFPLE9BQU8sUUFBUSxRQUFRLE1BQU07QUFBQTtBQUFBLElBQ25EO0FBQUEsSUFDQSxRQUFRO0FBQUEsTUFDTixlQUFlLFFBQVE7QUFBQSxNQUN2QixRQUFRO0FBQUEsSUFDVjtBQUFBLElBQ0EsS0FBSztBQUFBLE1BQ0gscUJBQXFCO0FBQUEsUUFDbkIsTUFBTTtBQUFBLFVBQ0osZ0JBQWdCO0FBQUEsUUFDbEI7QUFBQSxNQUNGO0FBQUEsSUFDRjtBQUFBLElBQ0EsT0FBTztBQUFBLE1BQ0wsUUFBUTtBQUFBLE1BQ1IsZUFBZTtBQUFBLFFBQ2IsVUFBVTtBQUFBLFVBQ1IsY0FBYztBQUFBLFVBQ2QsZUFBZTtBQUFBLFFBQ2pCO0FBQUEsTUFDRjtBQUFBLE1BQ0EsZUFBZTtBQUFBLFFBQ2IsVUFBVSxDQUFDLHNCQUFzQjtBQUFBLFFBQ2pDLFFBQVE7QUFBQSxVQUNOLGNBQWM7QUFBQSxZQUNaLGdCQUFnQixDQUFDLFNBQVMsYUFBYSxrQkFBa0I7QUFBQSxZQUN6RCxhQUFhO0FBQUEsY0FDWDtBQUFBLGNBQ0E7QUFBQSxjQUNBO0FBQUEsY0FDQTtBQUFBLGNBQ0E7QUFBQSxjQUNBO0FBQUEsWUFDRjtBQUFBLFlBQ0EsZUFBZTtBQUFBLGNBQ2I7QUFBQSxjQUNBO0FBQUEsY0FDQTtBQUFBLGNBQ0E7QUFBQSxZQUNGO0FBQUEsWUFDQSxnQkFBZ0IsQ0FBQyxZQUFZLGlCQUFpQixRQUFRO0FBQUEsVUFDeEQ7QUFBQSxRQUNGO0FBQUEsTUFDRjtBQUFBLE1BQ0EsV0FBVyxDQUFDO0FBQUEsTUFDWixzQkFBc0I7QUFBQSxNQUN0Qix1QkFBdUI7QUFBQSxJQUN6QjtBQUFBLElBQ0EsY0FBYztBQUFBLE1BQ1osU0FBUztBQUFBLFFBQ1A7QUFBQSxRQUNBO0FBQUEsUUFDQTtBQUFBLFFBQ0E7QUFBQSxRQUNBO0FBQUEsUUFDQTtBQUFBLFFBQ0E7QUFBQSxNQUNGO0FBQUE7QUFBQSxNQUVBLFNBQVMsQ0FBQyxzQkFBc0I7QUFBQSxJQUNsQztBQUFBLEVBQ0Y7QUFDRixDQUFDOyIsCiAgIm5hbWVzIjogW10KfQo=
