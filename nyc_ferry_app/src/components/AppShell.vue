<template>
  <div class="relative w-full h-full">
    <MapContainer
      ref="mapRef"
      :view="view"
      :selected-route="selectedRoute"
      :selected-routes="selectedRoutes"
      :active-tab-route="activeTabRoute"
      @update:selected-routes="selectedRoutes = $event"
      @update:all-routes="allRoutes = $event"
    />

    <div
      class="absolute top-4 bottom-4 left-4 z-10 w-80 flex flex-col rounded-lg overflow-hidden bg-ferry-dark-blue/90 backdrop-blur-sm border border-white/10 shadow-xl"
    >
      <Transition name="sidebar" mode="out-in">
        <SidebarResults
          v-if="view === 'route'"
          :route="selectedRoute"
          :date="selectedDate"
          :routes="selectedRoutes.length ? selectedRoutes : allRoutes"
          :temp="savedForm.temp"
          :precip="savedForm.precip"
          @update:active-route="activeTabRoute = $event"
          @back="goToSystem"
        />
        <SidebarInput
          v-else
          :selected-routes="selectedRoutes"
          :all-routes="allRoutes"
          :saved-form="savedForm"
          @update:selected-routes="selectedRoutes = $event"
          @update:saved-form="savedForm = $event"
          @submit="handleSystemSubmit"
        />
      </Transition>
    </div>

    <!-- learn more button -->
    <button
      class="absolute bottom-4 right-4 z-30 text-xs text-ferry-light-gray hover:text-white transition-colors"
      @click="showMethodology = true"
    >
      Learn more
    </button>

    <!-- methodology overlay -->
    <Transition name="overlay">
      <div
        v-if="showMethodology"
        class="absolute inset-0 z-30 bg-ferry-dark-blue/95 backdrop-blur-sm overflow-y-auto p-10"
      >
        <button
          class="flex items-center gap-1.5 text-sm text-ferry-light-blue hover:text-white transition-colors mb-6"
          @click="showMethodology = false"
        >
          ← Close
        </button>

        <div class="max-w-2xl mx-auto flex flex-col gap-6 text-ferry-light-gray">
          <h1 class="font-heading text-4xl uppercase tracking-wide text-white">Methodology</h1>

          <div class="flex flex-col gap-2">
            <h2 class="font-heading text-lg uppercase tracking-wider text-white">Overview</h2>
            <p class="text-sm leading-relaxed">
              Add your methodology text here. Explain how the delay risk model works,
              what data sources are used, and how predictions are generated.
            </p>
          </div>

          <div class="flex flex-col gap-2">
            <h2 class="font-heading text-lg uppercase tracking-wider text-white">Data Sources</h2>
            <p class="text-sm leading-relaxed">
              Describe your data sources here.
            </p>
          </div>

          <div class="flex flex-col gap-2">
            <h2 class="font-heading text-lg uppercase tracking-wider text-white">Model</h2>
            <p class="text-sm leading-relaxed">
              Describe your model here.
            </p>
          </div>
        </div>
      </div>
    </Transition>
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
const selectedRoutes = ref<string[]>([])
const allRoutes = ref<string[]>([])
const activeTabRoute = ref<string | null>(null)
const showMethodology = ref(false)
const mapRef = ref<InstanceType<typeof MapContainer> | null>(null)
const savedForm = ref({
  date: '',
  temp: null as number | null,
  precip: null as number | null,
})

function handleSystemSubmit(values: { route: string; routes: string[]; date: string; temp: number | null; precip: number | null }) {
  selectedRoute.value = values.routes[0] ?? values.route ?? undefined
  selectedDate.value = values.date
  view.value = 'route'
  mapRef.value?.fitToRoutes(values.routes)
}

function goToSystem() {
  view.value = 'system'
  selectedRoute.value = undefined
  activeTabRoute.value = null
  mapRef.value?.resetView()
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
.overlay-enter-active,
.overlay-leave-active {
  transition: opacity 0.2s ease;
}
.overlay-enter-from,
.overlay-leave-to {
  opacity: 0;
}
</style>