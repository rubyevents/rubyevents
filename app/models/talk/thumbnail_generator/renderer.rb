require "nodo"

class Talk::ThumbnailGenerator::Renderer < Nodo::Core
  require satori: "satori"
  require satoriHtml: "satori-html"
  require resvg: "@resvg/resvg-js"

  script do
    <<~JS
      const __fs = require("fs");
      const __path = require("path");
      const __fontDir = __path.join(__path.dirname(require.resolve("@fontsource/inter/package.json")), "files");
      const __read = (file) => __fs.readFileSync(__path.join(__fontDir, file));
      const __SUBSET = { Inter: "latin", InterLatinExt: "latin-ext", InterCyrillic: "cyrillic", InterGreek: "greek", InterVietnamese: "vietnamese" };
      const __font = (name, weight) => ({ name, weight, style: "normal", data: __read(`inter-${__SUBSET[name]}-${weight}-normal.woff`) });

      globalThis.__FONTS__ = [
        ...[400, 600, 700, 800, 900].map((weight) => __font("Inter", weight)),
        ...["InterLatinExt", "InterCyrillic", "InterGreek", "InterVietnamese"].flatMap((family) =>
          [400, 700].map((weight) => __font(family, weight))
        )
      ];
    JS
  end

  function :render_png_base64, <<~'JS'
    async (html, width, height) => {
      const isHerbDebugSpan = (node) =>
        node && typeof node === "object" && node.type === "span" && node.props &&
        Object.keys(node.props).some((key) => key.startsWith("data-herb-debug"));

      const NAMED_ENTITIES = { amp: "&", lt: "<", gt: ">", quot: "\"", apos: "'", nbsp: " " };
      const decodeEntities = (text) =>
        text.replace(/&(#x?[0-9a-fA-F]+|[a-zA-Z][a-zA-Z0-9]*);/g, (match, body) => {
          if (body[0] === "#") {
            const code = (body[1] === "x" || body[1] === "X")
              ? parseInt(body.slice(2), 16)
              : parseInt(body.slice(1), 10);
            return Number.isFinite(code) ? String.fromCodePoint(code) : match;
          }
          return Object.prototype.hasOwnProperty.call(NAMED_ENTITIES, body) ? NAMED_ENTITIES[body] : match;
        });

      const collect = (out, child) => {
        if (child == null || child === false || child === true) return;
        if (Array.isArray(child)) { child.forEach((c) => collect(out, c)); return; }
        if (isHerbDebugSpan(child)) { collect(out, child.props.children); return; }
        out.push(typeof child === "object" ? sanitize(child) : decodeEntities(String(child)));
      };

      const sanitize = (node) => {
        if (!node || typeof node !== "object" || !node.props) return node;
        if (node.props.children === undefined) return node;

        const collected = [];
        collect(collected, node.props.children);

        const merged = [];
        for (const child of collected) {
          const last = merged[merged.length - 1];
          if (typeof child === "string" && typeof last === "string") {
            merged[merged.length - 1] = last + child;
          } else {
            merged.push(child);
          }
        }

        const cleaned = merged.filter((child) => !(typeof child === "string" && child.trim() === ""));
        node.props.children = cleaned.length === 0 ? undefined
          : cleaned.length === 1 ? cleaned[0]
          : cleaned;

        const children = node.props.children;

        if (node.type === "div" && children != null && typeof children !== "string") {
          const style = node.props.style || (node.props.style = {});

          if (style.display !== "flex" && style.display !== "none" && style.display !== "contents") {
            style.display = "flex";
          }
        }
        return node;
      };

      const fontCache = (globalThis.__FALLBACK_FONT_CACHE__ ||= new Map());

      const googleFamilyForText = (text) => {
        if (/[　-ヿ㐀-䶿一-鿿豈-﫿＀-￯]/.test(text)) return "Noto Sans JP";
        if (/[가-힯ᄀ-ᇿ]/.test(text)) return "Noto Sans KR";
        if (/[฀-๿]/.test(text)) return "Noto Sans Thai";
        if (/[؀-ۿ]/.test(text)) return "Noto Sans Arabic";
        return "Noto Sans";
      };

      const fetchGoogleFont = async (family, text) => {
        const key = family + "::" + text;
        if (fontCache.has(key)) return fontCache.get(key);

        const cssUrl = `https://fonts.googleapis.com/css2?family=${encodeURIComponent(family)}:wght@700&text=${encodeURIComponent(text)}`;
        const css = await (await fetch(cssUrl, { headers: { "User-Agent": "Mozilla/5.0" } })).text();
        const match = css.match(/src:\s*url\(([^)]+)\)\s*format\(['"]?(?:truetype|opentype|woff)/);
        const data = match ? Buffer.from(await (await fetch(match[1])).arrayBuffer()) : null;

        fontCache.set(key, data);
        return data;
      };

      const loadAdditionalAsset = async (code, text) => {
        if (code === "emoji") return undefined;
        try {
          const data = await fetchGoogleFont(googleFamilyForText(text), text);
          return data ? [{ name: `fallback-${code}`, data, weight: 700, style: "normal" }] : [];
        } catch (error) {
          return [];
        }
      };

      const svg = await satori.default(sanitize(satoriHtml.html(html)), {
        width,
        height,
        fonts: globalThis.__FONTS__,
        loadAdditionalAsset
      });

      const png = new resvg.Resvg(svg, {
        fitTo: { mode: "width", value: width },
        font: { loadSystemFonts: false }
      }).render().asPng();

      return png.toString("base64");
    }
  JS

  class_function :render_png_base64
end
