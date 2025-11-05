/// <reference types="vite/client" />

declare module "*.mdx" {
    let MDXComponent: (props: any) => JSX.Element;
    export default MDXComponent;
  }

interface ImportMetaEnv {
  readonly VITE_?: string
}

interface ImportMeta {
  readonly env: ImportMetaEnv
  glob<E = Record<string, any>>(pattern: string): Record<string, () => Promise<E>>
  globEager<E = Record<string, any>>(pattern: string): Record<string, E>
}
