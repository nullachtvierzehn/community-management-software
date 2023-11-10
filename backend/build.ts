const build = await Bun.build({
  entrypoints: ["./index.tsx"],
  outdir: "./build",
  loader: {
    ".mjml": "text",
  },
});

if (!build.success) {
  console.error("Build failed");
  for (const message of build.logs) {
    // Bun will pretty print the message object
    console.error(message);
  }
}
