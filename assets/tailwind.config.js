// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require("tailwindcss/plugin");
const fs = require("fs");
const path = require("path");

function addLiveViewVariant(name) {
  return plugin(({ addVariant }) =>
    addVariant(name, [`.${name}&`, `.${name} &`]),
  );
}

module.exports = {
  theme: {
    extend: {
      colors: {
        brand: "#ED8B00",
      },
    },
  },
  plugins: [
    require("@tailwindcss/forms"),

    // Allows prefixing Tailwind classes with LiveView classes when those
    // classes are applied, for example: <div class="phx-click-loading:animate-ping">
    addLiveViewVariant("phx-no-feedback"),
    addLiveViewVariant("phx-click-loading"),
    addLiveViewVariant("phx-submit-loading"),
    addLiveViewVariant("phx-change-loading"),

    // Embeds Heroicons (https://heroicons.com) into your app.css bundle.
    // See your CoreComponents.icon/1 for more information.
    plugin(function ({ matchComponents, theme }) {
      let iconsDir = path.join(__dirname, "./vendor/heroicons/optimized");
      let values = {};
      let icons = [
        ["", "/24/outline"],
        ["-solid", "/24/solid"],
        ["-mini", "/20/solid"],
      ];

      icons.forEach(([suffix, dir]) => {
        fs.readdirSync(path.join(iconsDir, dir)).forEach((file) => {
          let name = path.basename(file, ".svg") + suffix;
          values[name] = { name, fullPath: path.join(iconsDir, dir, file) };
        });
      });

      matchComponents(
        {
          hero: ({ name, fullPath }) => {
            let content = fs
              .readFileSync(fullPath)
              .toString()
              .replace(/\r?\n|\r/g, "");

            return {
              [`--hero-${name}`]: `url('data:image/svg+xml;utf8,${content}')`,
              "-webkit-mask": `var(--hero-${name})`,
              mask: `var(--hero-${name})`,
              "mask-repeat": "no-repeat",
              "background-color": "currentColor",
              "vertical-align": "middle",
              display: "inline-block",
              width: theme("spacing.5"),
              height: theme("spacing.5"),
            };
          },
        },
        { values },
      );
    }),
  ],
};
