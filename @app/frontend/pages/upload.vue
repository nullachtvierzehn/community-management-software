<template>
  <button type="button" @click="open()">Choose file</button>
  <pre>{{ fileRef }}</pre>
  <button @click="upload()">Upload</button>
</template>

<script setup lang="ts">
import { Upload } from 'tus-js-client'

const { files, open, reset, onChange } = useFileDialog({
  accept: 'image/*', // Set to accept only image files
})

const fileRef = ref<File | undefined | null>()

onChange((filelist) => (fileRef.value = filelist?.item(0)))

function upload() {
  const file = toValue(fileRef)
  if (!file) return
  // Create a new tus upload
  const upload = new Upload(file, {
    // Endpoint is the upload creation URL from your tus server
    endpoint: new URL('/backend/files', process.client ? window.location.href : process.env.ROOT_URL).toString(),
    // Retry delays will enable tus-js-client to automatically retry on errors
    retryDelays: [0, 3000, 5000, 10000, 20000],
    // Attach additional meta data about the file for the server
    metadata: {
      filename: file.name,
      filetype: file.type,
    },
    // Callback for errors which cannot be fixed using retries
    onError: function (error) {
      console.log('Failed because: ' + error)
    },
    // Callback for reporting upload progress
    onProgress: function (bytesUploaded, bytesTotal) {
      const percentage = ((bytesUploaded / bytesTotal) * 100).toFixed(2)
      console.log(bytesUploaded, bytesTotal, percentage + '%')
    },
    // Callback for once the upload is completed
    onSuccess: function () {
      console.log('Download %s from %s', (upload.file as File).name, upload.url)
    },
  })
  upload.start()
}
</script>
