<template>
  <div>
    <div>Datei: {{ file.name }}</div>
    <meter
      v-if="progress"
      min="0"
      max="100"
      :value="progress.toFixed(0)"
    ></meter>
  </div>
</template>

<script setup lang="ts">
import { DetailedError, Upload } from 'tus-js-client'

const props = defineProps<{
  file: File
}>()

const emit = defineEmits<{
  (e: 'complete', upload: Upload): void
  (e: 'error', error?: Error | DetailedError): void
  (e: 'progress', percentage?: number): void
}>()

const upload = ref<Upload>()
const progress = ref<number>()
const error = ref<Error | DetailedError>()

watch(upload, (newUpload) => {
  progress.value = newUpload ? 0 : undefined
  error.value = undefined
})

watch(progress, (newProgress) => emit('progress', newProgress))
watch(error, (newError) => emit('error', newError))

watch(
  () => props.file,
  (file, oldFile) => {
    // Do nothing, if file is still the same and an upload is already running.
    if (file === oldFile && upload.value) return

    // Terminate running upload, when the file changes.
    if (oldFile && file !== oldFile && upload.value) upload.value.abort(true)

    // Resume or start upload
    const u = new Upload(file, {
      // Endpoint is the upload creation URL from your tus server
      endpoint: new URL(
        '/backend/files',
        process.client ? window.location.href : process.env.ROOT_URL
      ).toString(),
      storeFingerprintForResuming: true,
      removeFingerprintOnSuccess: true,
      // Retry delays will enable tus-js-client to automatically retry on errors
      retryDelays: [0, 3000, 5000, 10000, 20000],
      // Attach additional meta-data about the file for the server
      metadata: {
        filename: file.name,
        filetype: file.type,
        filesize: file.size.toString(),
      },
      // Callback for errors which cannot be fixed using retries
      onError: function (e) {
        error.value = e
        console.error('Upload failed because: ' + error)
      },
      // Callback for reporting upload progress
      onProgress: function (bytesUploaded, bytesTotal) {
        progress.value = (bytesUploaded / bytesTotal) * 100
        console.debug(
          `Uploading file ${file.name}... ${progress.value.toFixed(2)}`
        )
      },
      // Callback for once the upload is completed
      onSuccess: function () {
        emit('complete', u)
        console.log('Download %s from %s', (u.file as File).name, u.url)
      },
    })

    upload.value = u

    // Check if there are any previous uploads to continue.
    u.findPreviousUploads().then((previousUploads) => {
      // Found previous uploads so we select the first one.
      if (previousUploads.length) {
        u.resumeFromPreviousUpload(previousUploads[0])
      }

      // Start the upload
      u.start()
    })
  },
  { immediate: true }
)
</script>
