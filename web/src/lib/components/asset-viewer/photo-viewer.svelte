<script lang="ts">
  import { fade } from 'svelte/transition';
  import { onDestroy, onMount } from 'svelte';
  import LoadingSpinner from '../shared-components/loading-spinner.svelte';
  import { api, AssetResponseDto } from '@api';
  import { notificationController, NotificationType } from '../shared-components/notification/notification';
  import { useZoomImageWheel } from '@zoom-image/svelte';
  import { photoZoomState } from '$lib/stores/zoom-image.store';
  import { getAssetRatio, isWebCompatibleImage } from '$lib/utils/asset-utils';
  import { shouldIgnoreShortcut } from '$lib/utils/shortcut';
  import { handleError } from '$lib/utils/handle-error';

  export let asset: AssetResponseDto;
  export let element: HTMLDivElement | undefined = undefined;
  export let haveFadeTransition = true;

  const getRotation = (value: string): number => {
    switch (value) {
      case '1':
        return 0;
      case '3':
        return 180;
      case '6':
        return 90;
      case '8':
        return 270;
      default:
        return 0;
    }
  };

  const getRotationString = (rotation: number): number => {
    switch (rotation % 360) {
      case 0:
        return 1;
      case 90:
        return 6;
      case 180:
        return 3;
      case 270:
        return 8;
      default:
        return 1;
    }
  };

  export const rotate = async () => {
    setZoomImageWheelState({ currentRotation: $zoomImageWheelState.currentRotation - 90 });
    console.log(getRotationString($zoomImageWheelState.currentRotation));
    try {
      await api.assetApi.updateAsset({
        id: asset.id,
        updateAssetDto: { orientation: getRotationString($zoomImageWheelState.currentRotation) },
      });
    } catch (error) {
      handleError(error, 'Unable to change orientation');
    }
  };

  let imgElement: HTMLDivElement;
  let assetData: string;
  let abortController: AbortController;
  let hasZoomed = false;
  let copyImageToClipboard: (src: string) => Promise<Blob>;
  let canCopyImagesToClipboard: () => boolean;

  onMount(async () => {
    // Import hack :( see https://github.com/vadimkorr/svelte-carousel/issues/27#issuecomment-851022295
    // TODO: Move to regular import once the package correctly supports ESM.
    const module = await import('copy-image-clipboard');
    copyImageToClipboard = module.copyImageToClipboard;
    canCopyImagesToClipboard = module.canCopyImagesToClipboard;
  });

  onDestroy(() => {
    abortController?.abort();
  });

  const loadAssetData = async ({ loadOriginal }: { loadOriginal: boolean }) => {
    try {
      abortController?.abort();
      abortController = new AbortController();

      const { data } = await api.assetApi.serveFile(
        { id: asset.id, isThumb: false, isWeb: !loadOriginal, key: api.getKey() },
        {
          responseType: 'blob',
          signal: abortController.signal,
        },
      );

      if (!(data instanceof Blob)) {
        return;
      }

      assetData = URL.createObjectURL(data);
    } catch {
      // Do nothing
    }
  };

  const handleKeypress = async (event: KeyboardEvent) => {
    if (shouldIgnoreShortcut(event)) {
      return;
    }
    if (window.getSelection()?.type === 'Range') {
      return;
    }
    if ((event.metaKey || event.ctrlKey) && event.key === 'c') {
      await doCopy();
    }
  };

  const doCopy = async () => {
    if (!canCopyImagesToClipboard()) {
      return;
    }

    try {
      await copyImageToClipboard(assetData);
      notificationController.show({
        type: NotificationType.Info,
        message: 'Copied image to clipboard.',
        timeout: 3000,
      });
    } catch (err) {
      console.error('Error [photo-viewer]:', err);
      notificationController.show({
        type: NotificationType.Error,
        message: 'Copying image to clipboard failed.',
      });
    }
  };

  const doZoomImage = async () => {
    setZoomImageWheelState({
      currentZoom: $zoomImageWheelState.currentZoom === 1 ? 2 : 1,
    });
  };

  const {
    createZoomImage: createZoomImageWheel,
    zoomImageState: zoomImageWheelState,
    setZoomImageState: setZoomImageWheelState,
  } = useZoomImageWheel();

  zoomImageWheelState.subscribe((state) => {
    photoZoomState.set(state);

    if (state.currentZoom > 1 && isWebCompatibleImage(asset) && !hasZoomed) {
      hasZoomed = true;
      loadAssetData({ loadOriginal: true });
    }
  });

  $: if (imgElement) {
    createZoomImageWheel(imgElement, {
      maxZoom: 10,
      wheelZoomRatio: 0.2,
    });
    if (asset.exifInfo?.orientation) {
      const { width, height } = getAssetRatio(asset);
      if (width > height && parseInt(asset.exifInfo?.orientation) != 1) {
        setZoomImageWheelState({ currentRotation: getRotation(asset.exifInfo?.orientation) });
      }

      if (width < height && parseInt(asset.exifInfo?.orientation) != 6) {
        setZoomImageWheelState({ currentRotation: getRotation(asset.exifInfo?.orientation) });
      }
    }
  }
</script>

<svelte:window on:keydown={handleKeypress} on:copyImage={doCopy} on:zoomImage={doZoomImage} />

<div
  bind:this={element}
  transition:fade={{ duration: haveFadeTransition ? 150 : 0 }}
  class="flex h-full select-none place-content-center place-items-center"
>
  {#await loadAssetData({ loadOriginal: false })}
    <LoadingSpinner />
  {:then}
    <div bind:this={imgElement} class="h-full w-full">
      <img
        transition:fade={{ duration: haveFadeTransition ? 150 : 0 }}
        src={assetData}
        alt={asset.id}
        class="h-full w-full object-contain"
        draggable="false"
      />
    </div>
  {/await}
</div>
