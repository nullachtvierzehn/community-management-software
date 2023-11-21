<template>
  <MenuBar :editor="editor" />
  <EditorContent :editor="editor" />
  <RenderTiptap :content="content" />
</template>

<script lang="ts" setup>
import { useEditor, EditorContent } from "@tiptap/vue-3";
import StarterKit from "@tiptap/starter-kit";
import ImageExtension from "@tiptap/extension-image";
import DropCursorExtension from "@tiptap/extension-dropcursor";
import LinkExtension from "@tiptap/extension-link";

const content = {
  type: "doc",
  content: [
    {
      type: "heading",
      attrs: { level: 1 },
      content: [{ text: "Wie kann die App helfen?", type: "text" }],
    },
    {
      type: "paragraph",
      content: [
        {
          text: "Die App bietet dir die Möglichkeit Informationen zu Angsterkrankungen zu erhalten und frei zu wählen, welche persönlichen Ressourcen du durch das Ausführen von Gut-zu-mir-sein-Übungen verstärken möchtest. Die Stärkung deiner Ressourcen spielt bei der Überwindung deiner Angst eine wichtige Rolle. Ebenso dass du dich deiner Angst stellst. Hierfür kannst du die Mutig-Sein-Übungen nutzen. In beiden Bereichen kannst du eigene Gruppen gründen, bestehenden Gruppen beitreten und innerhalb dieser Unterstützung erhalten. Bist du eher der Einzelgänger? Dann kannst du deine selbst erstellten Gruppen privat halten und vielleicht erst später für andere Nutzer:innen zugänglich",
          type: "text",
        },
      ],
    },
  ],
};

const editor = useEditor({
  extensions: [StarterKit, ImageExtension, DropCursorExtension, LinkExtension],
  content,
});
</script>
