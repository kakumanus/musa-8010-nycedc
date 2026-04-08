<template>
  <aside class="w-full h-full p-5">
    <button
      class="flex items-center gap-1.5 text-sm text-ferry-light-blue hover:text-white transition-colors"
      @click="$emit('back')"
    >
      Back
    </button>
  </aside>
</template>

<script setup lang="ts">
defineProps<{
  route?: string
  date?: string
}>()

defineEmits<{
  back: []
}>()
</script>
