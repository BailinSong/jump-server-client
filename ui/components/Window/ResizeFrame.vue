<script setup lang="ts">
type ResizeDirection = "East" | "North" | "NorthEast" | "NorthWest" | "South" | "SouthEast" | "SouthWest" | "West";

const props = withDefaults(
  defineProps<{
    enabled?: boolean
    inset?: number
  }>(),
  {
    enabled: true,
    inset: 6
  }
);

const handles = computed(() => {
  const inset = `${props.inset}px`;

  return [
    { key: "north", direction: "North" as ResizeDirection, class: "absolute left-3 right-3 top-0 h-1.5 cursor-ns-resize" },
    { key: "south", direction: "South" as ResizeDirection, class: "absolute left-3 right-3 bottom-0 h-1.5 cursor-ns-resize" },
    { key: "west", direction: "West" as ResizeDirection, class: "absolute left-0 top-3 bottom-3 w-1.5 cursor-ew-resize" },
    { key: "east", direction: "East" as ResizeDirection, class: "absolute right-0 top-3 bottom-3 w-1.5 cursor-ew-resize" },
    { key: "north-west", direction: "NorthWest" as ResizeDirection, class: "absolute left-0 top-0 h-3 w-3 cursor-nwse-resize" },
    { key: "north-east", direction: "NorthEast" as ResizeDirection, class: "absolute right-0 top-0 h-3 w-3 cursor-nesw-resize" },
    { key: "south-west", direction: "SouthWest" as ResizeDirection, class: "absolute left-0 bottom-0 h-3 w-3 cursor-nesw-resize" },
    { key: "south-east", direction: "SouthEast" as ResizeDirection, class: "absolute right-0 bottom-0 h-3 w-3 cursor-nwse-resize" }
  ].map(handle => ({
    ...handle,
    style: { margin: inset }
  }));
});

async function startResize(direction: ResizeDirection) {
  if (!props.enabled) return;

  try {
    await useTauriWindowGetCurrentWindow().startResizeDragging(direction);
  } catch {
    // ignore outside desktop runtime
  }
}
</script>

<template>
  <div v-if="enabled" class="pointer-events-none absolute inset-0 z-40">
    <div
      v-for="handle of handles"
      :key="handle.key"
      class="pointer-events-auto select-none"
      :class="handle.class"
      :style="handle.style"
      @mousedown.left.prevent="startResize(handle.direction)"
    />
  </div>
</template>
