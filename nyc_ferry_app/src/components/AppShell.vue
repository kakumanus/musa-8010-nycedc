<template>
  <div class="relative w-full h-full">
    <!-- Full-screen map (never unmounts) -->
    <MapContainer :view="view" :selected-route="selectedRoute" />

    <!-- Sidebar overlay -->
    <div
      class="absolute top-4 bottom-4 left-4 z-10 w-80 flex flex-col rounded-lg overflow-hidden bg-ferry-dark-blue/90 backdrop-blur-sm border border-white/10 shadow-xl"
    >
      <Transition name="sidebar" mode="out-in">
        <SidebarResults
          v-if="view === 'route'"
          :route="selectedRoute"
          :date="selectedDate"
          @back="goToSystem"
        />
        <SidebarInput
          v-else
          @submit="handleSystemSubmit"
        />
      </Transition>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref } from 'vue'
import MapContainer from './ui/MapContainer.vue'
import SidebarInput from './sections/SidebarInput.vue'
import SidebarResults from './sections/SidebarResults.vue'

type View = 'system' | 'route'

const view = ref<View>('system')
const selectedRoute = ref<string | undefined>(undefined)
const selectedDate = ref<string | undefined>(undefined)

function handleSystemSubmit(values: { route: string; date: string }) {
  selectedRoute.value = values.route || undefined
  selectedDate.value = values.date
  view.value = 'route'
}

function goToSystem() {
  view.value = 'system'
  selectedRoute.value = undefined
}
</script>

<style>
.sidebar-enter-active,
.sidebar-leave-active {
  transition: opacity 0.2s ease, transform 0.2s ease;
}
.sidebar-enter-from {
  opacity: 0;
  transform: translateX(-8px);
}
.sidebar-leave-to {
  opacity: 0;
  transform: translateX(-8px);
}
</style>
