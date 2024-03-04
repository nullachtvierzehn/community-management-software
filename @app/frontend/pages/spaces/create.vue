<template>
  <h1>Raum anlegen</h1>
  <input type="nameOfNewRoom" />
  <button @click="createRoom()">anlegen</button>
</template>

<script lang="ts" setup>
import { useCreateSpaceMutation } from '~/graphql'

const router = useRouter()

const nameOfNewRoom = ref('')
const { executeMutation: createRoomMutation } = useCreateSpaceMutation()

async function createRoom() {
  const { data, error } = await createRoomMutation({
    space: { name: toValue(nameOfNewRoom) },
  })
  if (data?.createSpace?.space?.id && !error) {
    nameOfNewRoom.value = ''
    router.push({
      name: 'space/items',
      params: { id: data.createSpace.space.id },
    })
  }
}
</script>