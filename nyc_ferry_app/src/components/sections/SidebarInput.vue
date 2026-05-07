<template>
  <aside class="flex flex-col gap-4 w-full h-full overflow-y-auto p-5">
    <div>
      <h2 class="font-heading text-2xl uppercase tracking-wide text-white">Delay Prediction Form</h2>
      <p class="text-xs text-ferry-light-gray mt-0.5">Enter conditions to predict excessive delay risk.</p>
    </div>

    <form class="flex flex-col gap-3" @submit.prevent="handleSubmit">
      <!-- Route selector -->
      <div class="flex flex-col gap-1">
        <div class="flex items-center justify-between">
          <label class="text-xs font-heading uppercase tracking-wider text-ferry-light-gray">
            Route (optional)
          </label>
          <button
            v-if="localSelected.length"
            class="text-xs text-ferry-light-gray hover:text-white"
            @mousedown.prevent="clearSelection"
          >
            Clear All
          </button>
        </div>

        <!-- search input -->
        <input
          v-model="routeSearch"
          type="text"
          placeholder="All Routes"
          class="bg-white/10 border border-white/20 rounded px-3 py-2 text-sm text-white placeholder-ferry-cool-gray focus:outline-none focus:border-ferry-light-blue"
          @focus="showRouteList = true"
          @blur="showRouteList = false"
          @keydown.enter.prevent
        />

        <!-- scrollable route list -->
        <div
          v-if="showRouteList"
          class="max-h-36 overflow-y-auto rounded border border-white/20 bg-white/5 mt-1"
        >
          <div
            class="px-3 py-2 text-sm cursor-pointer hover:bg-white/10 flex items-center justify-between"
            :class="localSelected.length === 0 ? 'text-white font-medium' : 'text-ferry-light-gray'"
            @mousedown.prevent="clearSelection"
          >
            All Routes
            <span v-if="localSelected.length === 0" class="text-ferry-light-blue text-xs">✓</span>
          </div>
          <div
            v-for="r in filteredRoutes"
            :key="r"
            class="px-3 py-2 text-sm cursor-pointer hover:bg-white/10 flex items-center justify-between"
            :class="localSelected.includes(r) ? 'text-white font-medium' : 'text-ferry-light-gray'"
            @mousedown.prevent="toggleRoute(r)"
          >
            {{ r }}
            <span v-if="localSelected.includes(r)" class="text-ferry-light-blue text-xs">✓</span>
          </div>
        </div>

        <!-- selected tags -->
        <div v-if="localSelected.length" class="flex flex-wrap gap-1 mt-1">
          <span
            v-for="r in localSelected"
            :key="r"
            class="flex items-center gap-1 px-2 py-0.5 bg-ferry-light-blue/20 border border-ferry-light-blue/40 rounded text-xs text-ferry-light-blue"
          >
            {{ r }}
            <button class="hover:text-white" @click.prevent="toggleRoute(r)">✕</button>
          </span>
        </div>
      </div>

      <!-- Date picker -->
      <div class="flex flex-col gap-1">
        <div class="flex items-center justify-between">
          <label class="text-xs font-heading uppercase tracking-wider text-ferry-light-gray">
            Date
          </label>
          <button
            type="button"
            class="text-xs text-ferry-light-gray hover:text-white"
            @click="fillMinDate"
          >
            In Two Days
          </button>
        </div>
        <input
          v-model="form.date"
          type="text"
          placeholder="MM/DD/YYYY"
          maxlength="10"
          class="bg-white/10 border border-white/20 rounded px-3 py-2 text-sm text-white placeholder-ferry-cool-gray focus:outline-none focus:border-ferry-light-blue"
          :class="{ 'border-red-400': errors.date }"
          @blur="onDateBlur"
          @keydown.enter.prevent="handleSubmit"
        />
        <p v-if="errors.date" class="text-xs text-red-400 mt-0.5">{{ errors.date }}</p>
      </div>

      <!-- Weather inputs -->
      <div class="grid grid-cols-2 gap-3">
        <div class="flex flex-col gap-1">
          <label class="text-xs font-heading uppercase tracking-wider text-ferry-light-gray">
            Temp (°F)
          </label>
          <input
            v-model.number="form.temp"
            type="number"
            placeholder="0"
            class="bg-white/10 border border-white/20 rounded px-3 py-2 text-sm text-white placeholder-ferry-cool-gray focus:outline-none focus:border-ferry-light-blue"
            :class="{ 'border-red-400': errors.temp }"
            @keydown.enter.prevent="handleSubmit"
          />
          <p v-if="errors.temp" class="text-xs text-red-400 mt-0.5">{{ errors.temp }}</p>
        </div>
        <div class="flex flex-col gap-1">
          <label class="text-xs font-heading uppercase tracking-wider text-ferry-light-gray">
            Precip (%)
          </label>
          <input
            v-model.number="form.precip"
            type="number"
            min="0"
            max="100"
            placeholder="0"
            class="bg-white/10 border border-white/20 rounded px-3 py-2 text-sm text-white placeholder-ferry-cool-gray focus:outline-none focus:border-ferry-light-blue"
            :class="{ 'border-red-400': errors.precip }"
            @keydown.enter.prevent="handleSubmit"
          />
          <p v-if="errors.precip" class="text-xs text-red-400 mt-0.5">{{ errors.precip }}</p>
        </div>
      </div>

      <!-- Advanced options -->
      <details class="group">
        <summary
          class="text-xs font-heading uppercase tracking-wider text-ferry-light-blue cursor-pointer select-none list-none flex items-center gap-1"
        >
          <span class="transition-transform group-open:rotate-90">▶</span>
          Advanced Options
        </summary>
        <div class="mt-2 flex flex-col gap-2 pl-3 border-l border-white/10">
          <p class="text-xs text-ferry-light-gray">Additional model parameters programmed here.</p>
        </div>
      </details>

      <button
        type="submit"
        class="mt-1 w-full py-2.5 font-heading uppercase tracking-widest text-sm bg-ferry-light-blue text-ferry-dark-blue rounded font-semibold hover:brightness-110 transition-all"
      >
        Go
      </button>
    </form>
  </aside>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue'

const props = defineProps<{
  selectedRoutes?: string[]
  allRoutes?: string[]
  savedForm?: { date: string; temp: number | null; precip: number | null }
}>()

const emit = defineEmits<{
  submit: [values: {
    route: string
    routes: string[]
    date: string
    temp: number | null
    precip: number | null
  }]
  'update:selectedRoutes': [routes: string[]]
  'update:savedForm': [form: { date: string; temp: number | null; precip: number | null }]
}>()

const routeSearch = ref('')
const showRouteList = ref(false)
const localSelected = ref<string[]>(props.selectedRoutes ? [...props.selectedRoutes] : [])

const filteredRoutes = computed(() =>
  (props.allRoutes ?? []).filter(r =>
    r.toLowerCase().includes(routeSearch.value.toLowerCase())
  )
)

watch(
  () => props.selectedRoutes,
  (val) => {
    if (val) localSelected.value = [...val]
  },
  { deep: true }
)

function toggleRoute(r: string) {
  if (localSelected.value.includes(r)) {
    localSelected.value = localSelected.value.filter(id => id !== r)
  } else {
    localSelected.value = [...localSelected.value, r]
  }
  emit('update:selectedRoutes', localSelected.value)
}

function clearSelection() {
  localSelected.value = []
  emit('update:selectedRoutes', [])
}

const form = ref({
  date: props.savedForm?.date ?? '',
  temp: props.savedForm?.temp ?? null as number | null,
  precip: props.savedForm?.precip ?? null as number | null,
})

const errors = ref({ date: '', temp: '', precip: '' })

watch(form, (val) => {
  emit('update:savedForm', { ...val })
}, { deep: true })

// Format date only on blur so the user can freely edit any part of the field
function onDateBlur() {
  const raw = form.value.date.replace(/\D/g, '')
  if (!raw.length) return
  if (raw.length >= 8) {
    form.value.date = raw.slice(0, 2) + '/' + raw.slice(2, 4) + '/' + raw.slice(4, 8)
  } else if (raw.length >= 4) {
    form.value.date = raw.slice(0, 2) + '/' + raw.slice(2, 4) + '/' + raw.slice(4)
  } else if (raw.length >= 2) {
    form.value.date = raw.slice(0, 2) + '/' + raw.slice(2)
  }
}

function getMinDate(): Date {
  const d = new Date()
  d.setHours(0, 0, 0, 0)
  d.setDate(d.getDate() + 2)
  return d
}

function fillMinDate() {
  const d = getMinDate()
  const month = String(d.getMonth() + 1).padStart(2, '0')
  const day = String(d.getDate()).padStart(2, '0')
  const year = d.getFullYear()
  form.value.date = `${month}/${day}/${year}`
}

function handleSubmit() {
  errors.value = { date: '', temp: '', precip: '' }

  if (!form.value.date || form.value.date.length < 10) {
    errors.value.date = 'Required.'
  } else {
    const [month, day, year] = form.value.date.split('/').map(Number)

    const entered = new Date(year, month - 1, day)
    const isRealDate =
      entered.getFullYear() === year &&
      entered.getMonth() === month - 1 &&
      entered.getDate() === day

    if (!isRealDate) {
      errors.value.date = 'Please enter a valid date.'
    } else {
      entered.setHours(0, 0, 0, 0)
      if (entered < getMinDate()) {
        errors.value.date = 'Date must be at least two days from today'
      }
    }
  }

  if (form.value.temp === null || form.value.temp === undefined) errors.value.temp = 'Required.'
  if (form.value.precip === null || form.value.precip === undefined) errors.value.precip = 'Required.'

  if (Object.values(errors.value).some(e => e)) return

  emit('submit', {
    route: localSelected.value[0] ?? '',
    routes: localSelected.value,
    date: form.value.date,
    temp: form.value.temp,
    precip: form.value.precip,
  })
}
</script>
