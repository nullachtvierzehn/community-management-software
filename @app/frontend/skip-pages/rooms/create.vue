<template>
  <h1>Raum anlegen</h1>
  <input type="nameOfNewRoom" />
  <button @click="createRoom()">anlegen</button>
</template>

<script lang="ts" setup>
import { useCreateRoomMutation } from '~/graphql'

const router = useRouter()

const nameOfNewRoom = ref('')
const { executeMutation: createRoomMutation } = useCreateRoomMutation()

async function createRoom() {
  const { data, error } = await createRoomMutation({
    room: { title: toValue(nameOfNewRoom) },
  })
  if (data?.createRoom?.room?.id && !error) {
    nameOfNewRoom.value = ''
    router.push({
      name: 'room/items',
      params: { id: data.createRoom.room.id },
    })
  }
}
</script>
