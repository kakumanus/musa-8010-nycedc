<template>
  <aside class="flex flex-col gap-4 w-full h-full overflow-y-auto p-5">
    <div>
      <h2 class="font-heading text-2xl uppercase tracking-wide text-white">System Map</h2>
      <p class="text-xs text-ferry-light-gray mt-0.5">Enter conditions to predict delay risk</p>
    </div>

    <form class="flex flex-col gap-3" @submit.prevent="handleSubmit">
      <!-- Route selector -->
      <div class="flex flex-col gap-1">
        <label class="text-xs font-heading uppercase tracking-wider text-ferry-light-gray">
          Route (optional)
        </label>
        <select
          v-model="form.route"
          class="bg-white/10 border border-white/20 rounded px-3 py-2 text-sm text-white focus:outline-none focus:border-ferry-light-blue"
        >
          <option value="">All Routes</option>
          <option v-for="r in routes" :key="r" :value="r">{{ r }}</option>
        </select>
      </div>

      <!-- Date picker -->
      <div class="flex flex-col gap-1">
        <label class="text-xs font-heading uppercase tracking-wider text-ferry-light-gray">
          Date
        </label>
        <input
          v-model="form.date"
          type="date"
          class="bg-white/10 border border-white/20 rounded px-3 py-2 text-sm text-white focus:outline-none focus:border-ferry-light-blue [color-scheme:dark]"
        />
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
            placeholder="72"
            class="bg-white/10 border border-white/20 rounded px-3 py-2 text-sm text-white placeholder-ferry-cool-gray focus:outline-none focus:border-ferry-light-blue"
          />
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
            placeholder="10"
            class="bg-white/10 border border-white/20 rounded px-3 py-2 text-sm text-white placeholder-ferry-cool-gray focus:outline-none focus:border-ferry-light-blue"
          />
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
          <p class="text-xs text-ferry-light-gray">Additional model parameters coming soon.</p>
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
import { reactive } from 'vue'
import { FERRY_ROUTES } from '../../constants'

const routes = FERRY_ROUTES

const form = reactive({
  route: '',
  date: '',
  temp: null as number | null,
  precip: null as number | null,
})

const emit = defineEmits<{
  submit: [values: typeof form]
}>()

function handleSubmit() {
  emit('submit', { ...form })
}
</script>
