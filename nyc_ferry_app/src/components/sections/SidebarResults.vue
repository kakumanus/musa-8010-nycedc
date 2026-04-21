<template>
  <aside class="flex flex-col w-full h-full">
    <!-- scrollable content -->
    <div class="flex flex-col gap-4 flex-1 overflow-y-auto p-5">
      <button
        class="flex items-center gap-1.5 text-sm text-ferry-light-blue hover:text-white transition-colors"
        @click="$emit('back')"
      >
        ← Back
      </button>

      <!-- summary header -->
      <div>
        <h2 class="font-heading text-2xl uppercase tracking-wide text-white">
          {{ activeRoute ?? 'All Routes' }}
        </h2>
        <p class="text-xs text-ferry-light-gray mt-0.5">{{ formattedDate }}</p>
        <p class="text-xs text-ferry-light-gray mt-0.5"> Temperature: {{ temp !== null ? `${temp}°F` : '—' }}</p>
        <p class="text-xs text-ferry-light-gray mt-0.5"> Precipitation: {{ precip !== null ? `${precip}%` : '—' }}</p>
      </div>

      <!-- direction toggle -->
      <div class="flex rounded-md overflow-hidden border border-white/10 self-start">
        <button
          v-for="d in (['SB', 'NB'] as const)"
          :key="d"
          class="px-4 py-1.5 text-xs font-heading uppercase tracking-wider transition-colors"
          :class="direction === d
            ? 'bg-ferry-light-blue text-ferry-dark-blue'
            : 'text-ferry-light-gray hover:text-white'"
          @click="direction = d"
        >
          {{ d === 'SB' ? '↓ Southbound' : '↑ Northbound' }}
        </button>
      </div>

      <!-- info boxes -->
      <div class="flex flex-col gap-3">

        <!-- delay risk card -->
        <div class="rounded-lg bg-white/5 border border-white/10 p-4 flex flex-col gap-2">
          <p class="text-xs font-heading uppercase tracking-wider text-ferry-light-gray">Delay Risk</p>
          <p class="text-3xl font-heading text-white">—</p>
          <p class="text-xs text-ferry-light-gray">Prediction will appear here</p>
        </div>

      </div>
    </div>

    <!-- tabs at bottom -->
    <div
      v-if="routes?.length"
      class="border-t border-white/10 bg-ferry-dark-blue/80 flex overflow-x-auto"
    >
      <button
        class="flex-shrink-0 px-3 py-3 text-xs font-heading uppercase tracking-wider transition-colors border-b-2"
        :class="activeRoute === null
          ? 'text-white border-ferry-light-blue'
          : 'text-ferry-light-gray border-transparent hover:text-white'"
        @click="activeRoute = null"
      >
        All
      </button>
      <button
        v-for="r in routes"
        :key="r"
        class="flex-shrink-0 px-3 py-3 text-xs font-heading uppercase tracking-wider transition-colors border-b-2 whitespace-nowrap"
        :class="activeRoute === r
          ? 'text-white border-ferry-light-blue'
          : 'text-ferry-light-gray border-transparent hover:text-white'"
        @click="activeRoute = r"
      >
        {{ r }}
      </button>
    </div>
  </aside>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'

const props = defineProps<{
  route?: string
  date?: string
  routes?: string[]
  temp?: number | null
  precip?: number | null
}>()

const emit = defineEmits<{
  back: []
  'update:activeRoute': [route: string | null]
  'update:direction': [direction: 'NB' | 'SB']
}>()

const activeRoute = ref<string | null>(props.routes?.[0] ?? null)
const direction = ref<'NB' | 'SB'>('SB')

const formattedDate = computed(() => {
  if (!props.date) return '—'
  const [month, day, year] = props.date.split('/')
  if (!month || !day || !year) return props.date

  const d = new Date(+year, +month - 1, +day)
  return d.toLocaleDateString('en-US', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  })
})

watch(activeRoute, (val) => {
  emit('update:activeRoute', val)
}, { immediate: true })

watch(direction, (val) => {
  emit('update:direction', val)
}, { immediate: true })

watch(
  () => props.routes,
  (val) => {
    activeRoute.value = val?.[0] ?? null
  }
)
</script>