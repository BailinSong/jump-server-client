/**
 * 平台检测 composable
 * 提供跨平台的平台检测功能
 */
export const usePlatform = () => {
  const platform = ref<string>("unknown");
  const isLoading = ref(true);

  // 计算属性：判断是否为 macOS
  const isMacOS = computed(() => platform.value === "darwin" || platform.value === "macos");

  // 计算属性：判断是否为 Windows
  const isWindows = computed(() => platform.value === "win32" || platform.value === "windows");

  // 计算属性：判断是否为 Linux
  const isLinux = computed(() => platform.value === "linux");

  const detectPlatformFromUserAgent = () => {
    if (typeof navigator === "undefined") return "unknown";

    const ua = navigator.userAgent.toLowerCase();
    if (ua.includes("windows")) return "win32";
    if (ua.includes("mac os") || ua.includes("macintosh")) return "darwin";
    if (ua.includes("linux")) return "linux";

    return "unknown";
  };

  // 获取平台信息，如果 Tauri OS 插件暂时不可用，则退回到浏览器环境判断
  const getPlatform = async () => {
    try {
      isLoading.value = true;
      const currentPlatform = await useTauriOsPlatform();
      platform.value = currentPlatform || detectPlatformFromUserAgent();
    } catch {
      platform.value = detectPlatformFromUserAgent();
    } finally {
      isLoading.value = false;
    }
  };

  // 组件挂载时自动获取平台信息
  onMounted(() => {
    getPlatform();
  });

  return {
    isMacOS,
    isLinux,
    isWindows,
    getPlatform,
    platform: readonly(platform),
    isLoading: readonly(isLoading)
  };
};
