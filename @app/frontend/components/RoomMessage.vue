<template>
  <template v-if="!m">
    <div
      v-if="fetching"
      class="message message_loading"
    >
      Die Nachricht lädt.
    </div>
    <form
      v-else-if="createWithDefaults && currentUser"
      @submit.prevent="saveMessage({})"
    >
      <textarea v-model="newBody" />
      <button type="submit">
        ok
      </button>
      <button
        type="button"
        @click="saveMessage({ send: true })"
      >
        send
      </button>
    </form>
    <div
      v-else
      class="message message_missing"
    >
      Die Nachricht wurde nicht gefunden.
    </div>
  </template>
  <div
    v-if="m && !edit"
    class="message"
  >
    <div
      v-if="m.sender"
      class="message__sender"
    >
      {{ m.sender.username }}
    </div>
    <div
      v-else
      class="message__sender"
    >
      Nutzer:in unbekannt
    </div>
    <div class="message__body">
      {{ m.body }}
    </div>
  </div>
  <form
    v-if="m && edit"
    class="message message_edit"
    @submit.prevent="saveMessage({})"
  >
    <textarea v-model="newBody" />
    <button type="submit">
      ok
    </button>
    <button
      type="button"
      @click="saveMessage({ send: true })"
    >
      send
    </button>
  </form>
</template>

<script lang="ts" setup>
import { computed } from "vue";

import {
  type RoomMessageInput,
  useCreateRoomMessageMutation,
  useGetRoomMessageQuery,
  useUpdateRoomMessageMutation,
} from "~/graphql";

interface Message {
  id: string;
  body?: string | null;
  sender?: {
    username: string;
    id: string;
  } | null;
}

const props = defineProps<
  {
    createWithDefaults?: RoomMessageInput;
    editable?: boolean;
    edit?: boolean;
  } & (
    | {
        id?: string;
        message?: null;
      }
    | {
        id?: null;
        message?: Message;
      }
  )
>();

const emit = defineEmits<{
  (e: "update:id", value: string): void;
  (e: "update:message", value: Message): void;
  (e: "update:edit", value: boolean): void;
}>();

const id = useVModel(props, "id", emit, { passive: true });
const message = useVModel(props, "message", emit, { passive: true });
const edit = useVModel(props, "edit", emit, {
  passive: true,
  defaultValue: false,
});
const currentUser = await useCurrentUser();

const { data: dataOfMessage, fetching } = await useGetRoomMessageQuery({
  variables: computed(() => ({ id: id.value as string })),
  pause: computed(() => !id.value || !!props.message),
});

const m = computed(() => props.message ?? dataOfMessage.value?.roomMessage);

// creation of a new message
const { executeMutation: createMutation } = useCreateRoomMessageMutation();
const { executeMutation: updateMutation } = useUpdateRoomMessageMutation();
const newBody = ref("");

syncRef(
  computed(() => message.value?.body ?? ""),
  newBody,
  { direction: "ltr" }
);

async function saveMessage({ send = false }) {
  const oldId = m.value?.id;

  if (!oldId) {
    if (!props.createWithDefaults)
      throw new Error("Please provide `createWithDefaults`");
    const input = { ...props.createWithDefaults };
    input.body = newBody.value;
    input.senderId = currentUser.value?.id;
    if (send) input.sentAt = new Date().toISOString();
    const { data, error } = await createMutation({ message: input });
    if (error) throw error;
    else if (data?.createRoomMessage?.roomMessage) {
      message.value = data.createRoomMessage.roomMessage;
      id.value = data.createRoomMessage.roomMessage.id;
    }
  }

  if (oldId) {
    const { error } = await updateMutation({
      oldId,
      patch: {
        body: newBody.value,
        ...(send ? { sentAt: new Date().toISOString() } : undefined),
      },
    });
    if (error) throw error;
  }
}
</script>
